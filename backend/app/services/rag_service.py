"""
RAG service — MyFoodRx chatbot.

Uses the google-genai SDK for Gemini embeddings and generation.
Three-layer guard: keyword pre-filter → similarity threshold → hardened system prompt.

VECTOR STORE: Knowledge chunks are embedded once using Gemini and stored persistently
in ChromaDB (``backend/app/knowledge/chroma_db/``). Restarts skip re-embedding when
the collection fingerprint (chunk count + SHA-256 content hash + embedding model)
matches. The collection is rebuilt automatically when the knowledge base or model changes.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import math
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import chromadb
from google import genai
from google.genai import types
from google.genai.errors import ClientError

from app.config import settings
from app.database import get_database
from app.knowledge.food_knowledge import KNOWLEDGE_DOCS

logger = logging.getLogger(__name__)

EMBEDDING_MODEL = "models/gemini-embedding-001"
EMBEDDING_DIM_FALLBACK = 3072
COLLECTION_NAME = "myfoodrx_chunks"
# Retries when embed API returns 429 (free tier often rate-limits per minute/day).
_EMBED_MAX_ATTEMPTS = 4
# Space out document embedding calls to avoid hitting per-minute embed quotas at startup.
_EMBED_CHUNK_INTERVAL_SEC = 0.55

_EMBEDDING_FALLBACK_NOTE = (
    "\n\nNOTE — KNOWLEDGE SEARCH UNAVAILABLE: There are NO retrieved knowledge excerpts this turn. "
    "Say clearly that you could not search the program's reference materials. "
    "Give only brief, non-specific lifestyle guidance (food, activity, sleep, hydration) aligned with the USER PROFILE if present. "
    "Do NOT invent numbers, food lists, thresholds, medication or device details, or study claims. "
    "Tell the user to ask again later or speak with their clinician for specifics."
)

# Pinned model IDs only (avoid *-latest aliases — behavior can change without notice).
GENERATION_MODELS = [
    "models/gemini-2.5-flash",
    "models/gemini-2.0-flash",
    "models/gemini-2.0-flash-lite",
]

# Rank this many chunks by similarity; only RAG_CONTEXT_DOC_COUNT go to the LLM prompt.
RETRIEVAL_CANDIDATES_K = 8
RAG_CONTEXT_DOC_COUNT = 4
# Gemini 2.5+ may count internal "thinking" tokens against this cap; pair with
# thinking_budget=0 in _generate_reply so user-visible text is not starved.
LLM_MAX_OUTPUT_TOKENS = 768
LLM_TEMPERATURE = 0.5
RAG_CACHE_COLLECTION = "rag_response_cache"
# Bump when cache row shape changes (plan_key, intent_key, etc.).
RAG_CACHE_VERSION = 4
# Similar questions only; guarded by keyword overlap + intent match (see _rag_cache_get_similar_embedding).
RAG_CACHE_EMBED_SIMILARITY_ENABLED = True
RAG_CACHE_EMBED_THRESHOLD = 0.93
RAG_CACHE_EMBED_SCAN_LIMIT = 80
MAX_HISTORY = 6  # conversation turns kept in context (pairs)
MIN_RELEVANCE = 0.42  # cosine-similarity floor (Layer 2)
# When we restrict retrieval to inferred KB categories (sleep, exercise, hydration, etc.).
MIN_RELEVANCE_TOPIC = 0.32
# Sleep queries often embed weakly vs chunks; still require topic-focused retrieval.
MIN_RELEVANCE_TOPIC_SLEEP = 0.28
CHUNK_MAX_CHARS = 1000  # max chars per chunk (Layer 1 indexing)
CHUNK_OVERLAP_SENTENCES = 1  # overlap between chunks (Layer 1)

_EMERGENCY_PATTERNS = re.compile(
    r"\b("
    r"chest\s*pain|heart\s*attack|cardiac\s*arrest|stroke|can'?t\s*breath|"
    r"difficulty\s*breath|not\s*breath|stop\s*breath|seizure|convuls|"
    r"unconscious|faint|pass(ed)?\s*out|overdos\w*|suicid\w*|kill\s*(my)?self|"
    r"bleed(ing)?\s*heavy|severe\s*bleed|anaphylax|epi\s*pen|throat\s*(clos|swell)|"
    r"911|emergency\s*room|\bER\b|ambulance"
    r")\b",
    re.IGNORECASE,
)

_HARD_MEDICAL_PATTERNS = re.compile(
    r"\b("
    r"medication|prescri(be|ption)|"
    r"metformin|insulin\s*(dose|unit|inject)|aspirin|ibuprofen|lisinopril|"
    r"atorvastatin|ozempic|wegovy|mounjaro|semaglutide|tirzepatide|"
    r"antibiotic|"
    r"pill|tablet|capsule|inhaler|suppository|"
    r"OTC\s*drug|over.the.counter\s*drug|"
    r"should\s*I\s*take\s*(a\s*)?(pill|tablet|medication|medicine|drug)|"
    r"can\s*I\s*take\s*(a\s*)?(pill|tablet|medication|medicine|drug)|"
    r"safe\s*to\s*take\s*(a\s*)?(pill|tablet|medication|medicine)|"
    r"blood\s*test|lab\s*result|test\s*result|biopsy|"
    r"MRI|CT\s*scan|x.ray|ultrasound|colonoscopy|endoscopy|"
    r"A1C|HbA1c|hemoglobin\s*A1|"
    r"diagnos(e|is|ed)|clinical\s*trial|"
    r"surgery|procedure|operation|"
    r"medical\s*advice|clinical\s*advice|"
    r"my\s*(doctor|physician|specialist)\s*(said|told|prescribed|recommend)"
    r")\b",
    re.IGNORECASE,
)

_SOFT_MEDICAL_PATTERNS = re.compile(
    r"\b("
    r"symptom|nausea|vomit|diarrhea|constipat|"
    r"headache|migraine|dizzy|vertigo|fever|chills|infection|"
    r"rash|itch|swelling|inflammation|ache|sore\s+\w+|"
    r"blurr(ed)?\s*vision|numbness|tingling|"
    r"chemotherapy|chemo\b|"
    r"treatment|therapy|cure|heal|remedy|"
    r"my\s*(doctor|physician|nurse)|doctor\s*(said|told)"
    r")\b",
    re.IGNORECASE,
)

_UNSUPPORTED_CONDITION_PATTERNS = re.compile(
    r"\b("
    r"cancer|tumou?r|oncolog|"
    r"kidney\s*disease|renal|ckd\b|"
    r"liver\s*disease|cirrhosis|hepatitis|"
    r"thyroid|hypothyroid|hyperthyroid|"
    r"pcos|endometriosis|"
    r"asthma|copd|emphysema|"
    r"arthritis|lupus|fibromyalgia|"
    r"alzheimers?|dementia|parkinsons?|"
    r"epilepsy|seizure\s*disorder|"
    r"hiv|aids|"
    r"crohn'?s|ulcerative\s*colitis|ibs\b"
    r")\b",
    re.IGNORECASE,
)

_MEDICATION_DECISION_CUES = re.compile(
    r"\b("
    r"is\s+it\s+safe|is\s+this\s+safe|"
    r"is\s+it\s+okay|is\s+this\s+okay|"
    r"can\s+i|should\s+i|"
    r"do\s+i\s+need\s+to|"
    r"am\s+i\s+allowed\s+to|"
    r"any\s+side\s+effects?|"
    r"interaction(s)?|contraindicat"
    r")\b",
    re.IGNORECASE,
)

_MEDICATION_ACTION_TERMS = re.compile(
    r"\b("
    r"take|taking|start|starting|stop|stopping|continue|continuing|"
    r"use|using|used|"
    r"dose|dosage|mg|milligram|"
    r"pill|tablet|capsule|medicine|medication|drug|injection|inject"
    r")\b",
    re.IGNORECASE,
)


def _looks_like_medication_decision_query(message: str) -> bool:
    """
    Catch varied medication-advice phrasings that might miss _HARD_MEDICAL_PATTERNS.
    """
    text = (message or "").strip()
    if not text:
        return False
    low = text.lower()
    if _HARD_MEDICAL_PATTERNS.search(low):
        return True
    if _MEDICATION_DECISION_CUES.search(low) and _MEDICATION_ACTION_TERMS.search(low):
        return True
    return False


_OFFTOPIC_PATTERNS = re.compile(
    r"\b("
    r"weather|forecast|temperature\s*outside|"
    r"football|basketball|baseball|soccer|cricket|tennis|golf|"
    r"nfl|nba|mlb|nhl|fifa|movie|film|show|series|netflix|"
    r"music|song|album|artist|singer|band|concert|"
    r"celebrity|actor|actress|influencer|"
    r"javascript|typescript|python\s*script|java\b|c\+\+|rust\s*lang|"
    r"algorithm|machine\s*learning\s*model|neural\s*network|"
    r"how\s*to\s*code|programming|debug|software\s*bug|"
    r"website|web\s*dev|mobile\s*app\s*build|"
    r"stock\s*market|invest|crypto|bitcoin|ethereum|NFT|"
    r"election|president|congress|senator|politic|government\s*policy|"
    r"war|military|protest|"
    r"hotel|flight|airline|travel\s*to|vacation|tourism|"
    r"fashion|clothes|outfit|makeup|"
    r"girlfriend|boyfriend|marriage|divorce|dating|"
    r"homework|essay\s*write|thesis\s*write|exam\s*help|"
    r"lottery|gambling|casino|"
    r"ghost|spirit|paranormal|astrology|horoscope"
    r")\b",
    re.IGNORECASE,
)

_DIET_SIGNALS = re.compile(
    r"(?<!\w)("
    r"eat|food|diet|nutrition|meal|recipe|calorie|carb|protein|fat|fiber|"
    r"vitamin|mineral|sodium|sugar|salt|portion|serving|snack|drink|water|"
    r"vegetable|fruit|grain|dairy|pantry|ingredient|cook|health|weight|"
    r"blood\s*sugar|blood\s*pressure|DASH|diabet|hypertension|obesity|"
    r"MyPlate|prediabet|glucose|cholesterol|potassium|allerg|intoleran|"
    r"gluten|lactose|vegan|vegetarian|keto|mediterranean|whole\s*grain|"
    r"breakfast|lunch|dinner|hydrat|fast(ing)?|nutrient|sleep|exercise"
    r")",
    re.IGNORECASE,
)

_MSG_EMERGENCY = "This may be a medical emergency. Please call 911 or go to the nearest emergency room right away."

_MSG_MEDICAL = (
    "I'm sorry, I can't help with medical advice.\n\n"
    "Please contact your doctor or pharmacist.\n\n"
    "I can only guide you on food and healthy eating to support your health."
)

_MSG_OFFTOPIC = (
    "I am the MyFoodRx wellness assistant. I can help with food, nutrition, hydration, sleep, and exercise habits.\n\n"
    "Please ask a question about healthy habits or your health goals."
)

_MSG_LOW_RELEVANCE = (
    "I'm not sure how that relates to healthy habits.\n\n"
    "Please ask about food, hydration, sleep, exercise, or daily routines."
)


def _first_nonempty_line(text: str) -> str:
    for line in (text or "").splitlines():
        s = line.strip()
        if s:
            return s
    return ""


# First lines of canned guardrail strings — stays in sync when _MSG_* wording changes.
_CANNED_GUARDRAIL_PREFIXES: tuple[str, ...] = tuple(
    _first_nonempty_line(m)
    for m in (_MSG_EMERGENCY, _MSG_MEDICAL, _MSG_OFFTOPIC, _MSG_LOW_RELEVANCE)
)

# Other fixed replies from chat() / generators that should not attach follow-up chips.
_EXTRA_NO_FOLLOWUP_PREFIXES: tuple[str, ...] = (
    "I am having trouble connecting right now",
    "I am having trouble processing your question",
    "The AI service is currently at capacity",
    "I ran into a technical issue",
    "I cannot advise on medications",
)

_NO_FOLLOWUP_PREFIXES: tuple[str, ...] = (
    _CANNED_GUARDRAIL_PREFIXES + _EXTRA_NO_FOLLOWUP_PREFIXES
)

PLAN_INFO: dict[str, dict[str, str]] = {
    "DiabetesPlate": {
        "definition": "The Diabetes Plate is a simple way to plan meals for blood sugar control.",
        "portion": "Fill half your plate with vegetables, one quarter with protein, and one quarter with carbs.",
        "why": "This helps keep your blood sugar steady.",
    },
    "DASH": {
        "definition": "The DASH diet is a low-sodium eating plan that helps lower blood pressure.",
        "portion": "Fill your meals with fruits, vegetables, whole grains, and lean protein.",
        "why": "This helps keep your heart healthy.",
    },
    "MyPlate": {
        "definition": "MyPlate is a simple guide for balanced meals.",
        "portion": "Fill half your plate with fruits and vegetables, and the other half with grains and protein.",
        "why": "This helps you eat healthy and balanced meals.",
    },
}

_PLAN_QUERY_HINTS: tuple[str, ...] = (
    "what is diabetes plate",
    "what is the diabetes plate",
    "diabetes plate info",
    "how does diabetes plate work",
    "explain diabetes plate",
    "what is dash",
    "what is the dash diet",
    "dash diet info",
    "tell me about dash",
    "explain dash",
    "what is myplate",
    "what is my plate",
    "myplate info",
    "my plate info",
    "tell me about myplate",
    "tell me about my plate",
    "explain myplate",
    "explain my plate",
)


def should_suggest_follow_ups(answer: str) -> bool:
    """
    Skip follow-up question generation for canned guardrails, errors, and very short replies.
    """
    t = (answer or "").strip()
    if len(t) < 24:
        return False
    return not any(t.startswith(p) for p in _NO_FOLLOWUP_PREFIXES)


def _clip_text_for_rag_prompt(text: str) -> str:
    return text[:200]


def _build_rag_user_message(
    *, context_from_documents: str, question: str, resolved_plan: str | None = None
) -> str:
    """Runtime RAG payload: document context plus question (see SYSTEM_PROMPT for role rules)."""
    question_text = question.strip()
    if "portion" in question_text.lower():
        question_text += "\nFocus on portion sizes and plate structure."
    if resolved_plan == "DiabetesPlate":
        question_text += "\nUse Diabetes Plate structure and portions."
    return (
        "Use the context provided below when it applies to the question.\n"
        "Do not invent medical facts, study claims, exact numbers, or citations that are not in the context.\n\n"
        "IMPORTANT RULE:\n"
        "- If the question is about a general nutrition concept (such as fiber, glycemic index, nutrient-dense foods, blood sugar), "
        "ALWAYS give a short, simple explanation in plain language.\n"
        "- Do NOT say that the information is missing for these basic concepts.\n\n"
        "LIMITATION RULE:\n"
        "- Only say that details are missing when the user asks for specific numbers, clinical thresholds, or exact medical values.\n"
        "- In those cases, briefly say you do not have that detail and give safe, general guidance.\n\n"
        "If the question has multiple parts, answer each part you can.\n"
        "Do not start your response by saying information is missing unless the entire answer depends on missing details.\n\n"
        f"Context from documents:\n{context_from_documents.strip()}\n\n"
        f"Question:\n{question_text}"
    )


# Whole-line or inline echoes of legacy UI copy (do not swallow paragraph breaks).
_EXPLORE_MORE_BELOW_LINE = re.compile(
    r"^\s*\*?\s*you can explore more below[\.\!…]*\*?\s*$",
    re.IGNORECASE | re.MULTILINE,
)
_EXPLORE_MORE_BELOW_INLINE = re.compile(
    r"[ \t\*_]*you can explore more below[\.\!…]*[ \t\*_]*",
    re.IGNORECASE,
)


def _strip_llm_ui_phrases(text: str) -> str:
    """Remove UI-only phrases that must not appear in assistant replies."""
    t = (text or "").strip()
    t = _EXPLORE_MORE_BELOW_LINE.sub("", t)
    t = _EXPLORE_MORE_BELOW_INLINE.sub("", t)
    # Normalize a few common model quirks before the user sees them.
    t = re.sub(r"\bDiabetesPlate\b", "Diabetes Plate", t)
    t = re.sub(
        r"(?i)\byou want foods that help\b",
        "These foods help",
        t,
    )
    t = re.sub(
        r"(?i)\bthe diabetes plate helps you do this\b",
        "The Diabetes Plate is a simple way to plan this",
        t,
    )
    t = re.sub(
        r"(?i)\bdiabetes plate helps you do this\b",
        "The Diabetes Plate is a simple way to plan this",
        t,
    )
    t = re.sub(r"\n{3,}", "\n\n", t)
    return t.strip()


def _extract_text_from_generate_response(response: Any) -> str:
    """
    Aggregate assistant text from all candidates and parts.

    ``response.text`` alone can miss text when the model returns multiple
    ``parts`` (e.g. thinking models: skip ``part.thought`` reasoning blocks).
    """
    chunks: list[str] = []
    try:
        for candidate in getattr(response, "candidates", None) or []:
            content = getattr(candidate, "content", None)
            if content is None:
                continue
            for part in getattr(content, "parts", None) or []:
                # User-visible answer text only; skip internal reasoning parts.
                if getattr(part, "thought", None) is True:
                    continue
                t = getattr(part, "text", None)
                if isinstance(t, str) and t:
                    chunks.append(t)
    except Exception as exc:
        logger.debug("Candidate parts text walk failed: %s", exc)
    joined = "".join(chunks).strip()
    if joined:
        return joined
    fallback = getattr(response, "text", None)
    return (fallback or "").strip() if isinstance(fallback, str) else ""


SYSTEM_PROMPT = """You are the MyFoodRx nutrition assistant.

ROLE
- Be a friendly, supportive nutrition coach.
- Use simple, everyday language.
- Help users make practical food choices based on their profile and question.

SCOPE
- Answer about food, meals, nutrition, hydration, sleep, exercise, and healthy daily habits.
- Support meal planning (DASH, MyPlate, Diabetes Plate), grocery choices, cooking, pantry use, food labels, allergies, and preferences.
- Condition-specific guidance is limited to diabetes, prediabetes, hypertension, and obesity.
- For sleep and exercise questions, provide brief non-medical guidance and practical habits. You may connect guidance to blood sugar, blood pressure, weight, or heart health when helpful.

SAFETY
- Do not provide medical diagnosis, treatment, or medication advice.
- If the user asks about medical conditions outside diabetes, prediabetes, hypertension, or obesity, briefly say this chatbot cannot provide condition-specific guidance for that condition and direct them to their clinician.
- If symptoms or diagnosis are asked, direct the user to a healthcare professional and then continue with food-related guidance if appropriate.
- If medications are asked: "I cannot advise on medications. Please speak with your doctor or pharmacist."
- If emergency symptoms are mentioned, say it may be an emergency and advise calling local emergency services (911 in the U.S.) or going to the nearest emergency room.

OFF-TOPIC
- If the request is not related to nutrition, healthy habits, or wellness, reply briefly that you can only help with food, hydration, sleep, exercise, and healthy routines.

PLAN TYPE (STRICT)
- The USER PROFILE block includes a line: "Resolved plan (must use exactly this): <key>".
- That key is always one of: DiabetesPlate, DASH, or MyPlate. Obey it for this turn. Do not pick a different plan from memory or from conditions if that line is present.
- Map keys to user-visible names: DiabetesPlate → "Diabetes Plate"; keep "DASH" and "MyPlate" as usual.
- Use exactly one plan per response. Do not combine DASH and Diabetes Plate (or any two plans) in the same answer.
- If the resolved-plan line is missing, infer in this order:
  (1) diabetes or prediabetes present (with or without obesity, with or without hypertension) → Diabetes Plate
  (2) hypertension present with or without obesity (no diabetes/prediabetes) → DASH
  (3) obesity only or no condition → MyPlate
- Never ask the user to pick a plan when USER PROFILE already gives the resolved plan.

PLAN RULES (STRICT)
- Diabetes Plate:
  - Structure: half non-starchy vegetables, one-quarter protein, one-quarter carbohydrates.
  - Focus on blood sugar balance using fiber and steady carbohydrate intake.
  - Sodium target: 1500 mg/day unless USER PROFILE or retrieved context says otherwise.
  - GI target: ≤ 69 (educational). Prefer lower-GI carb choices (e.g. oats, sweet potato, legumes).
  - Only state a specific GI number for a food if USER PROFILE or retrieved context includes it.

- DASH:
  - Focus on low sodium, fruits, vegetables, whole grains, and lean protein.
  - Sodium target: 1500 mg/day unless USER PROFILE or retrieved context says otherwise.

- MyPlate:
  - Focus on balanced meals, portion control, and healthy habits.
  - Sodium target: 2300 mg/day unless USER PROFILE or retrieved context says otherwise.

KNOWLEDGE USE
- Use the provided knowledge context as the primary source when it is relevant to the question.
- For general nutrition concepts (such as fiber, glycemic index, nutrient-dense foods), always give a short, simple explanation in plain language.
- Do NOT say information is missing for basic nutrition concepts.
- Only say details are missing when the user asks for specific numbers, limits, or clinical values.
- In that case, briefly state that the exact detail is not available and give safe, general guidance.
- Do not invent facts, numbers, studies, or citations.

RESPONSE STYLE
- Use simple, everyday words only.
- Write at a 2nd to 3rd grade reading level.
- Use active voice. Start sentences with the subject.
- Write one idea per sentence. Keep sentences short.
- Avoid: "rather than", "instead", "however", "impact", "this can lead to", "helps with", "in order to".
- No comparisons. Use direct statements.
- Never open with "You want food" or "You want foods." Prefer direct guidance (for example, "These foods help ...").
- Always write "Diabetes Plate" (two words). Never write "DiabetesPlate".
- Use the user's first name only in closing messages. Never use it in regular responses.
- Never mention internal rules, system behavior, or app UI.

FORMAT
- Keep responses to 2–6 sentences for simple questions.
- For multi-part answers (for example, meal plans, food lists, step-by-step tips):
  - Open with 1–2 short sentences.
  - Use a short bullet list (3–5 items max).
  - Close with 1 short sentence.
- Explain any term the first time you use it.
- Vary sentence starters. Do not repeat the same opener twice in a row.

CLOSING BEHAVIOR
- If the user says thanks, okay, or goodbye:
  - Start with a brief acknowledgment (for example: "You're welcome." or "Glad to help.").
  - Include the user's first name only if it appears in USER PROFILE.
  - Keep to 2–3 short sentences total.
  - You may add one short encouraging sentence.
  - Do not introduce new nutrition advice, new suggestions, or new factual content.

NUMBERS RULE
- Avoid specific clinical numbers unless they come from provided context.
- Common educational ranges (for example, glycemic index ranges) are allowed when clearly labeled educational.

EXPLANATION STYLE EXAMPLE
- "Fiber helps slow sugar absorption. This means your blood sugar rises more slowly after eating."

STYLE EXAMPLES
Bad:
"Rather than focusing on glycemic index, it is better to choose balanced meals."

Good:
"GI shows how fast food raises blood sugar.
Balanced meals help keep it steady."
"""


def _resolve_plan_for_profile(user_profile: dict[str, Any] | None) -> str | None:
    """Resolve chatbot plan key: diabetes override, then myPlanType, then condition inference."""
    if not isinstance(user_profile, dict):
        return None

    conditions = (
        user_profile.get("medicalConditions") or user_profile.get("conditions") or []
    )
    if isinstance(conditions, str):
        conditions = [conditions]
    normalized = [str(c).lower() for c in conditions]
    if any("prediabetes" in c or "diabetes" in c for c in normalized):
        return "DiabetesPlate"

    raw_plan = user_profile.get("myPlanType")
    if raw_plan:
        plan_text = str(raw_plan).strip().lower().replace("-", " ")
        compact = plan_text.replace(" ", "")
        if compact in {"diabetesplate", "diabetes"} or "diabetes plate" in plan_text:
            return "DiabetesPlate"
        if compact in {"dash", "dashdiet"} or "dash" in plan_text:
            return "DASH"
        if (
            compact in {"myplate", "plate"}
            or "myplate" in plan_text
            or "my plate" in plan_text
        ):
            return "MyPlate"

    if any("hypertension" in c or "blood pressure" in c for c in normalized):
        return "DASH"
    return "MyPlate"


class _QueryClass:
    EMERGENCY = "emergency"
    MEDICAL = "medical"
    OFF_TOPIC = "off_topic"
    DIET = "diet"


def _normalize_chat_line(message: str) -> str:
    """Normalize user text for matching short greetings/thanks/goodbyes (NBSP, smart quotes)."""
    t = unicodedata.normalize("NFKC", message.strip())
    t = (
        t.replace("\u2018", "'")
        .replace("\u2019", "'")
        .replace("\u201c", '"')
        .replace("\u201d", '"')
        .replace("\xa0", " ")
    )
    while len(t) >= 2 and t[0] == t[-1] and t[0] in "'\"":
        t = t[1:-1].strip()
    t = t.lower()
    # Keep apostrophes for "that's", "i'm"; strip other punctuation to spaces.
    t = re.sub(r'[\s!.,?"…:;–—\-]+', " ", t)
    return re.sub(r"\s+", " ", t).strip()


# After [_normalize_chat_line], exact match only (no extra words).
_POLITE_CHAT_EXACT = frozenset(
    {
        "hi",
        "hello",
        "hey",
        "yo",
        "hiya",
        "howdy",
        "hi there",
        "hello there",
        "hey there",
        "thanks",
        "thank you",
        "thankyou",
        "thx",
        "ty",
        "thnx",
        "thank u",
        "thank you so much",
        "thanks so much",
        "thank you very much",
        "thanks very much",
        "thanks a lot",
        "many thanks",
        "good morning",
        "good afternoon",
        "good evening",
        "good day",
        "greetings",
        "morning",
        "evening",
        "goodbye",
        "bye",
        "good bye",
        "see you",
        "see you later",
        "see you soon",
        "no more questions",
        "i have no more questions",
        "thats all",
        "that's all",
        "nothing else",
        "nothing else thanks",
        "nothing else thank you",
        "all set",
        "im good",
        "i'm good",
        "no thanks",
        "talk soon",
        "talk later",
        "how are you",
        "how are you doing",
        "how is it going",
        "how's it going",
        "hows it going",
        # Greeting + "how are you" (normalized comma → space)
        "hi how are you",
        "hello how are you",
        "hey how are you",
        "good morning how are you",
        "good afternoon how are you",
        "good evening how are you",
    }
)

_POLITE_CHAT_REGEX = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^(thank you|thanks|thx|ty|thnx|thank u)(\s+(so|very)\s+much)?$",
        r"^(no|nothing)\s+(more|else)(\s+thanks?|\s+thank you)?$",
        r"^i\s*(have|'ve)\s+no\s+more\s+questions$",
        r"^that\s*'?s\s+all(\s+i\s+needed)?(\s+thanks?|\s+thank you|\s+thx|\s+ty)?$",
        r"^how\s+are\s+you(\s+doing)?$",
        r"^(hi|hello|hey|good\s+(morning|afternoon|evening))\s+how\s+are\s+you(\s+doing)?$",
        r"^how'?s\s+it\s+going$",
        r"^(good\s*)?bye[\s!.]*$",
        r"^see\s+ya[\s!.]*$",
        r"^have\s+a\s+good\s+(day|one)[\s!.]*$",
    )
)

_POLITE_CHAT_NOTE = (
    "\n\nNOTE — NO KNOWLEDGE EXCERPT THIS TURN: The user's message is only conversation "
    "management (greeting, thanks, or closing — see CONVERSATION MANAGEMENT). "
    "Do not invent nutrition facts. Follow CONVERSATION MANAGEMENT for tone and length."
)

_HOW_ARE_YOU_EXACT = frozenset(
    {
        "how are you",
        "how are you doing",
        "how is it going",
        "how's it going",
        "hows it going",
    }
)

_HOW_ARE_YOU_NOTE = (
    "\n\nTHIS TURN — USER ASKED HOW YOU ARE: Your first sentence must directly say how you are "
    "(e.g. doing well / great / good) and thank them or acknowledge the question. "
    "Forbidden as an opening: 'I'm here to help,' 'I'm ready to help,' or jumping straight to "
    "nutrition before answering. After you answer, then pivot to how you can help with meals or diet."
)


def _is_how_are_you_turn(message: str) -> bool:
    if _DIET_SIGNALS.search(message):
        return False
    return _normalize_chat_line(message) in _HOW_ARE_YOU_EXACT


_EXERCISE_INTENT = re.compile(
    r"\b("
    r"exercise|exercises|exercising|workout|work\s*outs?|working\s*out|"
    r"aerobic|cardio|cardiovascular|physical\s*activity|"
    r"strength\s*train(?:ing)?|resistance\s*train(?:ing)?|weight\s*lift|lifting\b|"
    r"\bgym\b|fitness|move\s*more|walking\s*program"
    r")\b",
    re.IGNORECASE,
)


def _is_exercise_intent(message: str) -> bool:
    return bool(_EXERCISE_INTENT.search(message))


_OVER_RESTRICTIVE_SCOPE_REPLY = re.compile(
    r"(only\s+help\s+with\s+food|cannot\s+give\s+advice\s+on\s+exercise|cannot\s+tell\s+you\s+how\s+much\s+sleep)",
    re.IGNORECASE,
)


def _rewrite_lifestyle_scope_refusal(message: str, reply: str) -> str:
    """
    Replace over-restrictive food-only refusals for allowed lifestyle topics.

    This also fixes stale cached responses created before scope rules were widened.
    """
    text = (reply or "").strip()
    if not text or not _OVER_RESTRICTIVE_SCOPE_REPLY.search(text):
        return reply
    cats = _infer_kb_categories(message) or frozenset()
    if "exercise" in cats:
        return (
            "Safe exercise can start with low-impact options like walking, easy cycling, "
            "or chair exercises.\n\n"
            "Start with short sessions, go slow, and stop if you feel pain, dizziness, or chest symptoms.\n\n"
            "If you have a medical condition, ask your doctor before starting a new workout plan."
        )
    if "sleep" in cats:
        return (
            "Most adults need about 7 to 9 hours of sleep each night.\n\n"
            "Try a regular sleep schedule, avoid caffeine late in the day, and keep your room dark and quiet.\n\n"
            "If sleep problems continue for weeks, talk with your doctor."
        )
    return reply


def _infer_kb_categories(message: str) -> frozenset[str] | None:
    """
    Map user wording to food_knowledge chunk categories (lowercased).
    Used to restrict retrieval when global cosine similarity is often too low for lifestyle questions.
    """
    lc = message.lower()
    cats: set[str] = set()
    if re.search(
        r"\b("
        r"sleep|sleeping|insomnia|bedtime|nap\b|lack of sleep|sleep deprivation|"
        r"sleep-deprived|sleep deprived|poor sleep|sleep loss|not enough sleep|"
        r"melatonin|tryptophan|circadian|"
        r"can'?t sleep|restful|sleep quality"
        r")\b",
        lc,
    ):
        cats.add("sleep")
    if _EXERCISE_INTENT.search(message):
        cats.add("exercise")
    if re.search(
        r"\b("
        r"water|hydrat|fluid|dehydrat|thirst|ounces|\bliters?\b|"
        r"drink\s+when|when\s+exercising|while\s+exercising|during\s+exercise|"
        r"how\s+much\s+.*\s+drink"
        r")\b",
        lc,
    ):
        cats.add("hydration")
    if re.search(
        r"\b("
        r"blood\s*pressure|hypertension|\bhbp\b|\bsalt\b|sodium|"
        r"dash\s+diet|dash\b"
        r")\b",
        lc,
    ):
        cats.add("hypertension")
    if re.search(
        r"\b(prediabetes|pre-diabetes|prediabetic|borderline\s+diabetes)\b",
        lc,
    ):
        cats.add("pre-diabetes")
    if re.search(
        r"\b("
        r"diabetes|type\s*1|type\s*2|blood\s*sugar|glucose|a1c|hba1c|"
        r"insulin|carb(ohydrate)?|glycemic|plate method|diabetes plate"
        r")\b",
        lc,
    ):
        cats.add("diabetes")
    if re.search(r"\b(obesity|overweight|weight\s+loss|lose\s+weight|\bbmi\b)\b", lc):
        cats.add("obesity")
    if not cats:
        return None
    return frozenset(cats)


def _embedding_text_for_retrieval(message: str) -> str:
    cats = _infer_kb_categories(message)
    if not cats:
        return message
    hints: list[str] = []
    if "sleep" in cats:
        hints.append(
            "sleep melatonin tryptophan appetite calories ghrelin leptin diet nutrition "
            "sleep hygiene insomnia blood sugar blood pressure"
        )
    if "exercise" in cats:
        hints.append(
            "physical activity aerobic strength exercise safety blood pressure diabetes"
        )
    if "hydration" in cats:
        hints.append("water fluid hydration dehydration exercise sweating")
    if "hypertension" in cats:
        hints.append("blood pressure hypertension DASH sodium exercise safety")
    if "pre-diabetes" in cats:
        hints.append("prediabetes blood sugar insulin resistance diet")
    if "diabetes" in cats:
        hints.append("diabetes blood glucose insulin carbohydrate glycemic")
    if "obesity" in cats:
        hints.append("obesity weight management calories diet exercise")
    if not hints:
        return message
    return message + "\n\nTopic keywords: " + " ".join(hints)


def _skip_rag_polite_chat(message: str) -> bool:
    """True for short greetings/thanks/goodbyes — skip embedding (very short strings often fail)."""
    if _DIET_SIGNALS.search(message):
        return False
    normalized = _normalize_chat_line(message)
    if not normalized:
        return False
    if normalized in _POLITE_CHAT_EXACT:
        return True
    return any(rx.fullmatch(normalized) for rx in _POLITE_CHAT_REGEX)


def is_polite_chat_turn(message: str) -> bool:
    """True for greeting/thanks/goodbye turns — chat router uses this for starter chips."""
    return _skip_rag_polite_chat(message)


# Closing-only — must NOT match greetings ("hi", "how are you") or the router
# mis-fires session_closing and strips follow-up chips.
_SESSION_CLOSING_EXACT = frozenset(
    {
        "ok thanks",
        "ok thank you",
        "okay thanks",
        "okay thank you",
        "thanks",
        "thank you",
        "thankyou",
        "thx",
        "ty",
        "thnx",
        "thank u",
        "thank you so much",
        "thanks so much",
        "thank you very much",
        "thanks very much",
        "thanks a lot",
        "many thanks",
        "goodbye",
        "bye",
        "good bye",
        "see you",
        "see you later",
        "see you soon",
        "no more questions",
        "i have no more questions",
        "thats all",
        "that's all",
        "nothing else",
        "nothing else thanks",
        "nothing else thank you",
        "all set",
        "im good",
        "i'm good",
        "no thanks",
        "talk soon",
        "talk later",
    }
)

_SESSION_CLOSING_REGEX = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^(ok|okay)\s+(thanks?|thank you)(\s+(so|very)\s+much)?$",
        r"^(thank you|thanks|thx|ty|thnx|thank u)(\s+(so|very)\s+much)?$",
        r"^(no|nothing)\s+(more|else)(\s+thanks?|\s+thank you)?$",
        r"^i\s*(have|'ve)\s+no\s+more\s+questions$",
        r"^that\s*'?s\s+all(\s+i\s+needed)?(\s+thanks?|\s+thank you|\s+thx|\s+ty)?$",
        r"^(good\s*)?bye[\s!.]*$",
        r"^see\s+ya[\s!.]*$",
        r"^have\s+a\s+good\s+(day|one)[\s!.]*$",
    )
)


def is_session_closing(message: str) -> bool:
    """
    True when the user is clearly ending the chat (thanks, bye, that's all, …).

    Not the same as polite-chat / RAG-skip: greetings and "how are you?" are False here.
    """
    if _DIET_SIGNALS.search(message):
        return False
    normalized = _normalize_chat_line(message)
    if not normalized:
        return False
    if normalized in _SESSION_CLOSING_EXACT:
        return True
    return any(rx.fullmatch(normalized) for rx in _SESSION_CLOSING_REGEX)


def _history_to_contents(history: list[dict[str, Any]]) -> list[types.Content]:
    history_contents: list[types.Content] = []
    for turn in history[-(MAX_HISTORY * 2) :]:
        role = turn.get("role") or "user"
        parts_raw = turn.get("parts") or []
        texts = [p for p in parts_raw if isinstance(p, str) and p.strip()]
        if not texts:
            continue
        history_contents.append(
            types.Content(
                role=role,
                parts=[types.Part(text=p) for p in texts],
            )
        )
    return history_contents


def classify_query(message: str) -> str:
    if _looks_like_medication_decision_query(message):
        return _QueryClass.MEDICAL

    if _EMERGENCY_PATTERNS.search(message):
        return _QueryClass.EMERGENCY
    if _HARD_MEDICAL_PATTERNS.search(message):
        return _QueryClass.MEDICAL
    if _UNSUPPORTED_CONDITION_PATTERNS.search(message):
        # Scope guard: only diabetes/prediabetes/hypertension/obesity are supported.
        return _QueryClass.MEDICAL

    has_diet = bool(_DIET_SIGNALS.search(message))

    if _SOFT_MEDICAL_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet else _QueryClass.MEDICAL
    if _OFFTOPIC_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet else _QueryClass.OFF_TOPIC

    return _QueryClass.DIET


def _dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def _norm(v: list[float]) -> float:
    return math.sqrt(sum(x * x for x in v))


def _cosine(a: list[float], b: list[float]) -> float:
    denom = _norm(a) * _norm(b)
    return 0.0 if denom == 0 else _dot(a, b) / denom


def _normalize_content(content: Any, *, doc_id: str) -> str:
    """Return a safe string for chunking, with guardrails for malformed docs."""
    if isinstance(content, str):
        return content
    if isinstance(content, (tuple, list)):
        parts = [str(part) for part in content if str(part).strip()]
        logger.warning(
            "Knowledge doc %s has %s content; coercing to string.",
            doc_id,
            type(content).__name__,
        )
        return " ".join(parts)
    raise TypeError(
        f"Knowledge doc '{doc_id}' has unsupported content type: {type(content).__name__}"
    )


def _clean_content(content: str) -> str:
    """Normalize PDF line-wrap artifacts before chunking."""
    # Remove leaked section marker if it appears in content blobs.
    content = content.replace("\n\nCategory: Exercise", "")
    # Join hard-wrapped lines that are likely continuation lines.
    content = re.sub(r"\n(?=[a-z(\"'])", " ", content)
    content = re.sub(r"(?<![.!?])\n(?=[A-Z])", " ", content)
    # Keep explicit paragraph breaks, normalize internal spacing.
    content = re.sub(r"[ \t]+", " ", content)
    return content.strip()


def _split_sentences(text: str) -> list[str]:
    """
    Sentence splitter with lightweight abbreviation protection.
    Keeps behavior deterministic and dependency-free.
    """
    # Protect a few common period abbreviations we use in docs.
    replacements = {
        "U.S.": "U<dot>S<dot>",
        "A1C.": "A1C<dot>",
        "HbA1c.": "HbA1c<dot>",
    }
    for src, dst in replacements.items():
        text = text.replace(src, dst)

    parts = re.split(r"(?<=[.!?])\s+", text)
    out: list[str] = []
    for part in parts:
        if not part:
            continue
        restored = part
        for src, dst in replacements.items():
            restored = restored.replace(dst, src)
        restored = restored.strip()
        if restored:
            out.append(restored)
    return out


def _chunk_doc(doc: dict[str, str]) -> list[dict[str, str | int]]:
    """Build sentence-aware chunks for one knowledge document."""
    raw_content = _normalize_content(
        doc.get("content"), doc_id=str(doc.get("id", "unknown"))
    )
    clean_text = _clean_content(raw_content)
    sentences = _split_sentences(clean_text)
    if not sentences:
        sentences = [clean_text]

    chunks: list[str] = []
    current: list[str] = []
    current_len = 0

    for sentence in sentences:
        sentence_len = len(sentence) + 1
        if current and current_len + sentence_len > CHUNK_MAX_CHARS:
            chunks.append(" ".join(current).strip())
            current = (
                current[-CHUNK_OVERLAP_SENTENCES:]
                if CHUNK_OVERLAP_SENTENCES > 0
                else []
            )
            current_len = sum(len(s) + 1 for s in current)
        current.append(sentence)
        current_len += sentence_len

    if current:
        chunks.append(" ".join(current).strip())

    total_chunks = len(chunks)
    return [
        {
            "doc_id": doc["id"],
            "title": doc["title"],
            "category": doc["category"],
            "source": doc["source"],
            "chunk_index": i,
            "total_chunks": total_chunks,
            "text": text,
        }
        for i, text in enumerate(chunks)
    ]


def build_chunks(docs: list[dict[str, str]]) -> list[dict[str, str | int]]:
    """Chunk all knowledge documents."""
    all_chunks: list[dict[str, str | int]] = []
    for doc in docs:
        all_chunks.extend(_chunk_doc(doc))
    return all_chunks


def _log_chunk_preview(
    chunks: list[dict[str, str | int]], sample_per_doc: int = 2
) -> None:
    """Log chunk counts and short previews for quick verification."""
    if not chunks:
        logger.info("Chunk preview: no chunks generated.")
        return

    grouped: dict[str, list[dict[str, str | int]]] = {}
    for chunk in chunks:
        doc_id = str(chunk["doc_id"])
        grouped.setdefault(doc_id, []).append(chunk)

    total_docs = len(grouped)
    logger.info(
        "Chunk preview: %d docs -> %d chunks.",
        total_docs,
        len(chunks),
    )
    for doc_id, doc_chunks in grouped.items():
        logger.info("Chunk count: %s -> %d", doc_id, len(doc_chunks))

    for doc_id, doc_chunks in grouped.items():
        logger.debug("Doc %s has %d chunks.", doc_id, len(doc_chunks))
        for chunk in doc_chunks[:sample_per_doc]:
            chunk_index = chunk["chunk_index"]
            total_chunks = chunk["total_chunks"]
            text = str(chunk["text"]).strip().replace("\n", " ")
            snippet = text[:140] + ("..." if len(text) > 140 else "")
            logger.debug(
                "Chunk %s[%s/%s]: %s",
                doc_id,
                int(chunk_index) + 1,
                total_chunks,
                snippet,
            )


def _chunks_content_sha256(chunks: list[dict[str, str | int]]) -> str:
    """Stable hash of all chunk identities + text — invalidates cache on any KB edit."""
    h = hashlib.sha256()
    for c in chunks:
        h.update(str(c["doc_id"]).encode())
        h.update(b"\0")
        h.update(str(c.get("chunk_index", 0)).encode())
        h.update(b"\0")
        h.update(str(c.get("text", "")).encode())
        h.update(b"\n")
    return h.hexdigest()


def _cache_fingerprint(chunks: list[dict[str, str | int]]) -> dict[str, Any]:
    return {
        "count": len(chunks),
        "chunks_sha256": _chunks_content_sha256(chunks),
        "embedding_model": EMBEDDING_MODEL,
    }


def _normalize_query_for_cache(message: str) -> str:
    return " ".join((message or "").lower().split())


def _cache_profile_condition_key(user_profile: dict[str, Any] | None) -> str:
    """Aligns with chatbot condition buckets for cache keys."""
    if not isinstance(user_profile, dict):
        return "none"
    conds = user_profile.get("medicalConditions") or []
    text = " ".join(str(c).lower() for c in conds)
    if any(
        k in text for k in ("diabetes", "prediabetes", "pre-diabetes", "blood sugar")
    ):
        return "diabetes"
    if any(k in text for k in ("hypertension", "high blood pressure", "hbp")):
        return "hypertension"
    if any(k in text for k in ("obesity", "overweight", "weight")):
        return "obesity"
    return "none"


def _chunk_matches_condition_priority(chunk: dict[str, Any], priority: str) -> bool:
    """Soft boost: chunk text/title/category hints at the user's primary condition theme."""
    blob = (
        f"{chunk.get('title', '')} {chunk.get('category', '')} "
        f"{str(chunk.get('text', ''))[:240]}"
    ).lower()
    if priority == "diabetes":
        return any(
            x in blob
            for x in (
                "diabetes",
                "diabetes plate",
                "glycemic",
                "blood sugar",
                "glucose",
                "carb",
                "insulin",
                "a1c",
            )
        )
    if priority == "hypertension":
        return any(
            x in blob
            for x in (
                "hypertension",
                "blood pressure",
                "dash",
                "sodium",
                "salt",
                "heart",
            )
        )
    if priority == "obesity":
        return any(
            x in blob
            for x in (
                "obesity",
                "overweight",
                "weight",
                "myplate",
                "my plate",
                "portion",
                "calorie",
            )
        )
    return False


def _prioritize_chunks_for_profile(
    chunks: list[dict[str, Any]], user_profile: dict[str, Any] | None
) -> list[dict[str, Any]]:
    """Prefer condition-aligned chunks; keep relative score order within each group."""
    pri = _cache_profile_condition_key(user_profile)
    if pri == "none" or not chunks:
        return list(chunks)
    preferred = [c for c in chunks if _chunk_matches_condition_priority(c, pri)]
    pref_ids = {id(c) for c in preferred}
    rest = [c for c in chunks if id(c) not in pref_ids]
    return preferred + rest


def _safe_rag_fallback_response() -> str:
    return (
        "Here are some general tips based on your question: aim for balanced meals "
        "with vegetables, lean protein, and whole grains when you can; sip water through the day; "
        "add light movement most days; and keep portions steady. For guidance tailored to you, "
        "try again shortly or speak with your clinician."
    )


def _cache_user_key(user_id: str | None) -> str:
    return (user_id or "").strip() or "anon"


def _cache_plan_key(user_profile: dict[str, Any] | None) -> str:
    return _resolve_plan_for_profile(user_profile) or "MyPlate"


def _is_plan_query(message: str) -> bool:
    q = _normalize_query_for_cache(message)
    return any(hint in q for hint in _PLAN_QUERY_HINTS)


def _build_plan_response(plan: str | None) -> str:
    info = PLAN_INFO.get(plan or "")
    if not info:
        return ""
    return f"{info['definition']}\n\n{info['portion']}\n\n{info['why']}"


def _is_truncation_finish_reason(finish_reason: Any) -> bool:
    """True when the model stopped because of an output length/token cap (unsafe to cache)."""
    fr = str(finish_reason) if finish_reason is not None else ""
    u = fr.upper()
    return "MAX" in u or "LENGTH" in u or "TOKEN" in u


async def _rag_cache_get_exact(
    query_norm: str, condition_key: str, user_key: str, plan_key: str
) -> str | None:
    try:
        db = await get_database()
    except Exception:
        return None
    try:
        hit = await db[RAG_CACHE_COLLECTION].find_one(
            {
                "query_norm": query_norm,
                "condition_key": condition_key,
                "user_key": user_key,
                "plan_key": plan_key,
                "cache_version": RAG_CACHE_VERSION,
            }
        )
        if hit and hit.get("response"):
            logger.info("Cache hit (exact) — skipping LLM")
            return str(hit["response"])
    except Exception as exc:
        logger.warning("RAG response cache read failed: %s", exc)
    return None


def _is_cache_safe(query: str, cached_query_norm: str) -> bool:
    """
    Guard semantic cache hits to avoid repeating the same answer on loosely-related queries.

    Requires stronger lexical overlap than a single token:
    - exact normalized query always allowed
    - otherwise require at least 2 meaningful shared tokens
    """
    qn = _normalize_query_for_cache(query)
    cn = _normalize_query_for_cache(cached_query_norm)
    if not cn:
        return False
    if qn and qn == cn:
        return True

    stop = {
        "what",
        "which",
        "when",
        "where",
        "why",
        "how",
        "can",
        "could",
        "should",
        "would",
        "please",
        "tell",
        "about",
        "for",
        "with",
        "my",
        "me",
        "i",
        "to",
        "the",
        "a",
        "an",
        "is",
        "are",
        "of",
        "in",
        "on",
    }

    def _tokens(text: str) -> set[str]:
        out: set[str] = set()
        for raw in text.split():
            w = re.sub(r"[^a-z0-9]", "", raw.lower())
            if len(w) < 3 or w in stop:
                continue
            out.add(w)
        return out

    q_tokens = _tokens(qn or query or "")
    c_tokens = _tokens(cn)
    if not q_tokens or not c_tokens:
        return False
    return len(q_tokens & c_tokens) >= 2


def _suggestion_intent_key(message: str) -> str:
    """
    Must match chatbot._detect_suggestion_intent ordering (exercise → meal_plan → tips → foods → general).
    Used for RAG response cache embedding hits.
    """
    low = (message or "").lower()
    if re.search(
        r"\b(workouts?|exercise|exercises|walking|walk\b|jog|runner|gym|cardio|aerobic|yoga|pilates|"
        r"physical activity|strength training|lifting|steps\b)\b",
        low,
    ):
        return "exercise"
    if re.search(
        r"\b(meal\s*plan|menu\s*plan|weekly\s*plan|meal\s*prep|grocery\s*list|shopping\s*list|"
        r"batch\s*cook|plan\s*my\s*meals)\b",
        low,
    ) or ("grocery" in low and "list" in low):
        return "meal_plan"
    if re.search(
        r"\b(tips?|advice|suggest|ideas|how\s+(can|do|should)|what\s+should|help\s+me|"
        r"tell\s+me\s+more|best\s+way|learn\s+more)\b",
        low,
    ):
        return "tips"
    if re.search(
        r"\b(foods?|eat|eating|meals?\b|meal\b|snacks?|breakfast|lunch|dinner|fruits?|vegetables?|"
        r"ingredients?|carbs?|what\s+can\s+i\s+eat)\b",
        low,
    ):
        return "foods"
    return "general"


async def _rag_cache_get_similar_embedding(
    query_embedding: list[float],
    condition_key: str,
    user_key: str,
    plan_key: str,
    query: str,
    intent_key: str,
) -> str | None:
    try:
        db = await get_database()
    except Exception:
        return None
    try:
        cursor = (
            db[RAG_CACHE_COLLECTION]
            .find(
                {
                    "condition_key": condition_key,
                    "user_key": user_key,
                    "plan_key": plan_key,
                    "cache_version": RAG_CACHE_VERSION,
                }
            )
            .sort("created_at", -1)
            .limit(RAG_CACHE_EMBED_SCAN_LIMIT)
        )
        docs = await cursor.to_list(length=RAG_CACHE_EMBED_SCAN_LIMIT)
    except Exception as exc:
        logger.warning("RAG response cache scan failed: %s", exc)
        return None
    best_score = 0.0
    best_text: str | None = None
    for doc in docs:
        emb = doc.get("embedding")
        if not isinstance(emb, list) or len(emb) < 8:
            continue
        try:
            s = _cosine(query_embedding, [float(x) for x in emb])
        except (TypeError, ValueError):
            continue
        if s < RAG_CACHE_EMBED_THRESHOLD:
            continue
        qn = doc.get("query_norm")
        if not isinstance(qn, str) or not _is_cache_safe(query, qn):
            continue
        if doc.get("intent_key") != intent_key:
            continue
        if s > best_score:
            best_score = s
            raw = doc.get("response")
            best_text = str(raw) if raw else None
    if best_score > 0 and best_text:
        logger.info(
            "Cache hit (embedding sim=%.3f ≥ %.2f, intent=%s) — skipping LLM",
            best_score,
            RAG_CACHE_EMBED_THRESHOLD,
            intent_key,
        )
        return best_text
    return None


async def _rag_cache_put(
    query_norm: str,
    condition_key: str,
    user_key: str,
    plan_key: str,
    query_embedding: list[float],
    response: str,
    intent_key: str,
) -> None:
    try:
        db = await get_database()
    except Exception:
        return
    try:
        await db[RAG_CACHE_COLLECTION].insert_one(
            {
                "query_norm": query_norm,
                "condition_key": condition_key,
                "user_key": user_key,
                "plan_key": plan_key,
                "cache_version": RAG_CACHE_VERSION,
                "intent_key": intent_key,
                "embedding": query_embedding,
                "response": response,
                "created_at": datetime.now(timezone.utc),
            }
        )
    except Exception as exc:
        logger.warning("RAG response cache write failed: %s", exc)


def _log_gemini_generation_usage(
    usage_metadata: Any | None, model_name: str | None = None
) -> None:
    """Backend-only token logging; never attach to API responses."""
    if not usage_metadata:
        return
    um = usage_metadata
    thoughts = getattr(um, "thoughts_token_count", None)
    if thoughts:
        logger.info(
            "Tokens (model=%s) → input: %s, output: %s, thoughts: %s, total: %s",
            model_name or "?",
            getattr(um, "prompt_token_count", None),
            getattr(um, "candidates_token_count", None),
            thoughts,
            getattr(um, "total_token_count", None),
        )
    else:
        logger.info(
            "Tokens (model=%s) → input: %s, output: %s, total: %s",
            model_name or "?",
            getattr(um, "prompt_token_count", None),
            getattr(um, "candidates_token_count", None),
            getattr(um, "total_token_count", None),
        )


class RAGService:
    """Singleton RAG service. Call initialize() once at app startup via lifespan."""

    def __init__(self) -> None:
        self._ready = False
        self._client: genai.Client | None = None
        self._chunks: list[dict[str, str | int]] = []
        self._chromadb_client = None
        self._collection = None

    async def initialize(self) -> None:
        api_key = settings.gemini_api_key
        if not api_key:
            logger.warning(
                "GEMINI_API_KEY not set — chatbot will use fallback responses."
            )
            return
        if not KNOWLEDGE_DOCS:
            logger.warning(
                "KNOWLEDGE_DOCS is empty in food_knowledge.py — add documents before using RAG."
            )
            return

        self._client = genai.Client(api_key=api_key)
        self._chunks = build_chunks(KNOWLEDGE_DOCS)
        _log_chunk_preview(self._chunks, sample_per_doc=2)

        # ── ChromaDB persistent collection ──────────────────────────────
        chroma_path = Path(__file__).parent.parent / "knowledge" / "chroma_db"
        self._chroma_client = chromadb.PersistentClient(path=str(chroma_path))
        current_fp = _cache_fingerprint(self._chunks)

        # Try to load existing collection and verify fingerprint
        try:
            self._collection = self._chroma_client.get_collection(name=COLLECTION_NAME)
            col_meta = self._collection.metadata or {}
            fingerprint_matches = (
                col_meta.get("chunks_sha256") == current_fp["chunks_sha256"]
                and col_meta.get("embedding_model") == current_fp["embedding_model"]
                and col_meta.get("chunk_count") == str(current_fp["count"])
            )
            if fingerprint_matches:
                logger.info(
                    "ChromaDB fingerprint matches — skipping embedding (%d chunks).",
                    self._collection.count(),
                )
                self._ready = True
                logger.info(
                    "RAG service ready (from ChromaDB) — %d chunks across %d documents.",
                    len(self._chunks),
                    len(KNOWLEDGE_DOCS),
                )
                return
            logger.info("ChromaDB fingerprint changed — rebuilding collection.")
            self._chroma_client.delete_collection(COLLECTION_NAME)
        except Exception:
            logger.info("ChromaDB collection not found — will create.")

        # Create fresh collection with fingerprint stored in metadata
        self._collection = self._chroma_client.get_or_create_collection(
            name=COLLECTION_NAME,
            metadata={
                "hnsw:space": "cosine",
                "chunks_sha256": current_fp["chunks_sha256"],
                "embedding_model": current_fp["embedding_model"],
                "chunk_count": str(current_fp["count"]),
            },
        )

        # First run — embed all chunks and store in ChromaDB
        logger.info(
            "Embedding %d chunks from %d docs with %s …",
            len(self._chunks),
            len(KNOWLEDGE_DOCS),
            EMBEDDING_MODEL,
        )

        ids: list[str] = []
        embeddings: list[list[float]] = []
        metadatas: list[dict] = []
        documents: list[str] = []

        client = self._client
        assert client is not None
        for idx, chunk in enumerate(self._chunks):
            text = f"{chunk['title']}. {chunk['text']}"
            vec: list[float] | None = None
            for attempt in range(6):
                try:
                    if idx > 0 and attempt == 0:
                        await asyncio.sleep(_EMBED_CHUNK_INTERVAL_SEC)
                    result = client.models.embed_content(
                        model=EMBEDDING_MODEL,
                        contents=text,
                        config=types.EmbedContentConfig(
                            task_type="RETRIEVAL_DOCUMENT",
                        ),
                    )
                    emb_list = result.embeddings or []
                    values = emb_list[0].values if emb_list else None
                    if values:
                        vec = list(values)
                    else:
                        logger.error(
                            "No embedding values for chunk '%s[%s]'",
                            chunk.get("doc_id"),
                            chunk.get("chunk_index"),
                        )
                    break
                except Exception as exc:
                    err_str = str(exc)
                    is_429 = "429" in err_str or "RESOURCE_EXHAUSTED" in err_str
                    if is_429 and attempt < 5:
                        delay = min(120.0, 15.0 * (2**attempt))
                        logger.warning(
                            "Embedding chunk '%s[%s]' rate limited (attempt %s/6), "
                            "retrying in %.0fs…",
                            chunk.get("doc_id"),
                            chunk.get("chunk_index"),
                            attempt + 1,
                            delay,
                        )
                        await asyncio.sleep(delay)
                        continue
                    logger.error(
                        "Failed to embed chunk '%s[%s]': %s",
                        chunk.get("doc_id"),
                        chunk.get("chunk_index"),
                        exc,
                    )
                    break

            final_vec = vec if vec else [0.0] * EMBEDDING_DIM_FALLBACK
            chunk_id = f"{chunk.get('doc_id', 'unknown')}_{idx}"

            ids.append(chunk_id)
            embeddings.append(final_vec)
            metadatas.append(
                {
                    "doc_id": str(chunk.get("doc_id", "")),
                    "title": str(chunk.get("title", "")),
                    "category": str(chunk.get("category", "")),
                    "source": str(chunk.get("source", "")),
                    "chunk_index": int(chunk.get("chunk_index", 0)),
                }
            )
            documents.append(chunk.get("text", ""))

        # Store everything in ChromaDB in one batch
        self._collection.add(
            ids=ids,
            embeddings=embeddings,
            metadatas=metadatas,
            documents=documents,
        )

        self._ready = True
        logger.info(
            "RAG service ready — %d chunks embedded and stored in ChromaDB.",
            len(self._chunks),
        )

    def _retrieve(
        self, query_embedding: list[float]
    ) -> tuple[list[dict[str, str]], float]:
        if self._collection is None or not self._chunks:
            return [], 0.0
        results = self._collection.query(
            query_embeddings=[query_embedding],
            n_results=RETRIEVAL_CANDIDATES_K,
            include=["metadatas", "documents", "distances"],
        )
        if not results["ids"] or not results["ids"][0]:
            return [], 0.0
        # ChromaDB cosine distance = 1 - similarity; convert back
        distances = results["distances"][0]
        best_score = 1.0 - distances[0] if distances else 0.0
        chunks = []
        for meta, doc in zip(results["metadatas"][0], results["documents"][0]):
            chunk = dict(meta)
            chunk["text"] = doc
            chunks.append(chunk)
        return chunks, best_score

    def _retrieve_for_categories(
        self,
        query_embedding: list[float],
        categories_lower: frozenset[str],
    ) -> tuple[list[dict[str, str]], float]:
        """Like _retrieve but only chunks whose category (lowercased) is in the set."""
        if self._collection is None or not self._chunks:
            return [], 0.0
        # Build ChromaDB where filter for categories
        category_list = [
            c.title() for c in categories_lower
        ]  # e.g. ["Sleep", "Diabetes"]
        where = {"category": {"$in": category_list}}
        results = self._collection.query(
            query_embeddings=[query_embedding],
            n_results=RETRIEVAL_CANDIDATES_K,
            where=where,
            include=["metadatas", "documents", "distances"],
        )
        if not results["ids"] or not results["ids"][0]:
            return [], 0.0
        distances = results["distances"][0]
        best_score = 1.0 - distances[0] if distances else 0.0
        chunks = []
        for meta, doc in zip(results["metadatas"][0], results["documents"][0]):
            chunk = dict(meta)
            chunk["text"] = doc
            chunks.append(chunk)
        return chunks, best_score

    @staticmethod
    def _build_user_context(
        user_profile: dict[str, Any] | None,
        pantry_items: list[dict],
    ) -> str:
        if not user_profile:
            return ""

        lines: list[str] = []

        # Optional first name for greeting/closing tone only.
        raw_name = user_profile.get("name")
        if raw_name and str(raw_name).strip():
            first_name = str(raw_name).strip().split()[0]
            first_name = re.sub(r"^[^\w]+|[^\w]+$", "", first_name, flags=re.UNICODE)
            if first_name and len(first_name) <= 48:
                lines.append(
                    f"User first name (optional; use mainly for greeting/closing): {first_name}"
                )

        conditions = user_profile.get("medicalConditions") or []
        if conditions:
            lines.append(f"Health conditions: {', '.join(str(c) for c in conditions)}")

        allergies = user_profile.get("allergies") or []
        if allergies:
            lines.append(
                f"Food allergies/intolerances: {', '.join(str(a) for a in allergies)}"
            )

        resolved_plan = _resolve_plan_for_profile(user_profile)
        if resolved_plan:
            lines.append(f"Resolved plan (must use exactly this): {resolved_plan}")

        goals = user_profile.get("healthGoals") or []
        if goals:
            lines.append(f"Health goals: {', '.join(str(g) for g in goals)}")

        calories = user_profile.get("targetCalories")
        if calories:
            lines.append(f"Daily calorie target: {calories} kcal")

        if pantry_items:
            items = [str(p.get("name", "")) for p in pantry_items if p.get("name")][:15]
            if items:
                lines.append(f"Current pantry items: {', '.join(items)}")

        return "\n".join(lines)

    def _generate_reply(
        self,
        message: str,
        full_system: str,
        history_contents: list[types.Content],
        *,
        max_output_tokens: int = LLM_MAX_OUTPUT_TOKENS,
        temperature: float = LLM_TEMPERATURE,
    ) -> tuple[str, Any | None, bool]:
        client = self._client
        assert client is not None
        last_exc: Exception | None = None
        for model_name in GENERATION_MODELS:
            try:
                chat_session = client.chats.create(
                    model=model_name,
                    config=types.GenerateContentConfig(
                        system_instruction=full_system,
                        max_output_tokens=max_output_tokens,
                        temperature=temperature,
                        response_modalities=["TEXT"],
                        # Without this, 2.5 Flash can spend most of max_output_tokens on
                        # internal reasoning and return MAX_TOKENS with a tiny visible reply.
                        thinking_config=types.ThinkingConfig(thinking_budget=0),
                    ),
                    history=history_contents,
                )
                response = chat_session.send_message(message)
                usage_meta = getattr(response, "usage_metadata", None)
                extracted = _extract_text_from_generate_response(response)
                rt = (getattr(response, "text", None) or "").strip()
                if rt and extracted != rt:
                    logger.debug(
                        "LLM text: aggregated parts len=%d vs response.text len=%d",
                        len(extracted),
                        len(rt),
                    )
                out = _strip_llm_ui_phrases(extracted)
                if not out:
                    logger.error("Empty generation from %s", model_name)
                    return _safe_rag_fallback_response(), None, False
                candidates = getattr(response, "candidates", None) or []
                finish_reason = None
                if candidates:
                    finish_reason = getattr(candidates[0], "finish_reason", None)
                fr_str = str(finish_reason) if finish_reason is not None else ""
                truncated = _is_truncation_finish_reason(finish_reason)
                logger.info("LLM finish_reason=%s model=%s", fr_str or "—", model_name)
                if truncated:
                    logger.warning(
                        "LLM output may be truncated (finish_reason=%s, chars=%d, model=%s)",
                        fr_str,
                        len(out),
                        model_name,
                    )
                logger.debug(
                    "LLM reply chars=%d finish_reason=%s",
                    len(out),
                    fr_str or "—",
                )
                if usage_meta is not None:
                    _log_gemini_generation_usage(usage_meta, model_name)
                else:
                    logger.info(
                        "Gemini returned no usage_metadata (model=%s, chars=%d)",
                        model_name,
                        len(out),
                    )
                logger.debug("LLM final response chars=%d", len(out))
                return out, usage_meta, truncated
            except Exception as exc:
                err_str = str(exc)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    logger.warning("Quota hit on %s, trying next model.", model_name)
                    last_exc = exc
                    continue
                code = getattr(exc, "code", None)
                if isinstance(exc, ClientError) and code == 404:
                    logger.warning(
                        "Model not available (%s): %s — trying next model.",
                        model_name,
                        exc,
                    )
                    last_exc = exc
                    continue
                # High demand / transient outage — same as "try another model in the list"
                if code == 503 or "503" in err_str or "UNAVAILABLE" in err_str.upper():
                    logger.warning(
                        "Model overloaded or unavailable (%s): %s — trying next model.",
                        model_name,
                        exc,
                    )
                    last_exc = exc
                    continue
                logger.error("Generation error with %s: %s", model_name, exc)
                return _safe_rag_fallback_response(), None, False

        logger.error("All generation models exhausted. Last error: %s", last_exc)
        return _safe_rag_fallback_response(), None, False

    async def chat(
        self,
        message: str,
        history: list[dict[str, Any]],
        user_profile: dict[str, Any] | None = None,
        pantry_items: list[dict] | None = None,
        user_id: str | None = None,
    ) -> str:
        query_class = classify_query(message)
        if query_class == _QueryClass.EMERGENCY:
            logger.info("Query blocked: EMERGENCY")
            return _MSG_EMERGENCY
        if query_class == _QueryClass.MEDICAL:
            logger.info("Query blocked: MEDICAL")
            return _MSG_MEDICAL
        if query_class == _QueryClass.OFF_TOPIC:
            logger.info("Query blocked: OFF_TOPIC")
            return _MSG_OFFTOPIC

        if not self._ready or self._client is None:
            return "I am having trouble connecting right now. Please try again in a moment."

        history_contents = _history_to_contents(history)
        user_context = self._build_user_context(user_profile, pantry_items or [])
        query_norm = _normalize_query_for_cache(message)
        condition_key = _cache_profile_condition_key(user_profile)
        user_key = _cache_user_key(user_id)
        plan_key = _cache_plan_key(user_profile)

        if _skip_rag_polite_chat(message):
            logger.info("Polite chat turn — skipping query embedding")
            full_system = SYSTEM_PROMPT
            if user_context:
                full_system += f"\n\nUSER PROFILE:\n{user_context}"
            full_system += _POLITE_CHAT_NOTE
            if _is_how_are_you_turn(message):
                full_system += _HOW_ARE_YOU_NOTE
            reply, _, _ = self._generate_reply(message, full_system, history_contents)
            return reply

        if _is_plan_query(message):
            plan_response = _build_plan_response(plan_key)
            if plan_response:
                return plan_response

        cached_exact = await _rag_cache_get_exact(
            query_norm, condition_key, user_key, plan_key
        )
        if cached_exact is not None:
            return _rewrite_lifestyle_scope_refusal(message, cached_exact)

        client = self._client
        text_for_embed = _embedding_text_for_retrieval(message)
        query_embedding: list[float] | None = None
        use_embedding_fallback = False
        for attempt in range(_EMBED_MAX_ATTEMPTS):
            try:
                q_result = client.models.embed_content(
                    model=EMBEDDING_MODEL,
                    contents=text_for_embed,
                    config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
                )
                q_emb = q_result.embeddings or []
                vec = q_emb[0].values if q_emb else None
                if vec:
                    query_embedding = list(vec)
                else:
                    logger.error("Query embedding returned no values")
                    use_embedding_fallback = True
                break
            except Exception as exc:
                err_str = str(exc)
                is_429 = "429" in err_str or "RESOURCE_EXHAUSTED" in err_str
                if is_429 and attempt < _EMBED_MAX_ATTEMPTS - 1:
                    delay = min(8.0, 2.0**attempt)
                    logger.warning(
                        "Embedding rate limited (attempt %s/%s), retrying in %.1fs…",
                        attempt + 1,
                        _EMBED_MAX_ATTEMPTS,
                        delay,
                    )
                    await asyncio.sleep(delay)
                    continue
                if is_429:
                    logger.error("Embedding quota exhausted after retries: %s", exc)
                    use_embedding_fallback = True
                else:
                    logger.error("Embedding error: %s", exc)
                break

        if query_embedding is None:
            if use_embedding_fallback:
                logger.warning(
                    "Answering without RAG — embedding unavailable for this request."
                )
                full_system = SYSTEM_PROMPT
                if user_context:
                    full_system += f"\n\nUSER PROFILE:\n{user_context}"
                full_system += _EMBEDDING_FALLBACK_NOTE
                reply, _, _ = self._generate_reply(
                    message, full_system, history_contents
                )
                return _rewrite_lifestyle_scope_refusal(message, reply)
            return "I am having trouble processing your question. Please try again."

        topic_cats = _infer_kb_categories(message)
        if topic_cats:
            relevant_docs, best_score = self._retrieve_for_categories(
                query_embedding, topic_cats
            )
            min_rel = MIN_RELEVANCE_TOPIC
            if "sleep" in topic_cats:
                min_rel = min(min_rel, MIN_RELEVANCE_TOPIC_SLEEP)
            logger.debug(
                "Topic-focused retrieval %s: best similarity=%.3f (min=%.2f)",
                topic_cats,
                best_score,
                min_rel,
            )
        else:
            relevant_docs, best_score = self._retrieve(query_embedding)
            min_rel = MIN_RELEVANCE
            logger.debug("Best similarity: %.3f (min=%.2f)", best_score, min_rel)

        if best_score < min_rel:
            logger.info(
                "Query blocked: LOW_RELEVANCE (score=%.3f, min=%.2f)",
                best_score,
                min_rel,
            )
            return _MSG_LOW_RELEVANCE

        cached_vec: str | None = None
        if RAG_CACHE_EMBED_SIMILARITY_ENABLED:
            cached_vec = await _rag_cache_get_similar_embedding(
                query_embedding,
                condition_key,
                user_key,
                plan_key,
                message,
                _suggestion_intent_key(message),
            )
        if cached_vec is not None:
            return _rewrite_lifestyle_scope_refusal(message, cached_vec)

        prioritized = _prioritize_chunks_for_profile(relevant_docs, user_profile)
        top_docs = prioritized[:RAG_CONTEXT_DOC_COUNT]
        logger.info("Using %d docs for RAG context", len(top_docs))

        knowledge_context = "\n\n".join(
            f"[{chunk['title']} — {chunk['category']} — Source: {chunk['source']}]\n"
            f"{_clip_text_for_rag_prompt(str(chunk.get('text', '')))}"
            for chunk in top_docs
        )

        full_system = SYSTEM_PROMPT
        if user_context:
            full_system += f"\n\nUSER PROFILE:\n{user_context}"
        rag_user_message = _build_rag_user_message(
            context_from_documents=knowledge_context,
            question=message,
            resolved_plan=plan_key,
        )

        reply, _, truncated = self._generate_reply(
            rag_user_message, full_system, history_contents
        )
        safe_fb = _safe_rag_fallback_response()
        if (
            reply
            and len(reply.strip()) > 24
            and reply != safe_fb
            and reply != _MSG_LOW_RELEVANCE
            and not truncated
        ):
            await _rag_cache_put(
                query_norm,
                condition_key,
                user_key,
                plan_key,
                query_embedding,
                reply,
                _suggestion_intent_key(message),
            )
        elif truncated:
            logger.info("Skipping RAG cache write (truncated LLM output).")
        return _rewrite_lifestyle_scope_refusal(message, reply)


rag_service = RAGService()
