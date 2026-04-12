"""
RAG service — MyFoodRx chatbot.

Uses Ollama (local) for embeddings and generation via its REST API.
Three-layer guard: keyword pre-filter → similarity threshold → hardened system prompt.

EMBEDDING CACHE: After the first successful embed run, vectors are saved under
``backend/app/knowledge/`` as ``embeddings_cache.npy`` (float32 matrix) and
``embeddings_cache_meta.json`` (fingerprint). Later startups load from disk and skip
embedding API calls. Cache invalidates if chunk count, content hash, or model changes.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
import math
import re
import unicodedata
from pathlib import Path
from typing import Any

import httpx
import numpy as np

from app.config import settings
from app.knowledge.food_knowledge import KNOWLEDGE_DOCS

logger = logging.getLogger(__name__)

EMBEDDING_MODEL = settings.ollama_embed_model  # default: "nomic-embed-text" (768 dims)
EMBEDDING_DIM_FALLBACK = 768
_EMBED_MAX_ATTEMPTS = 3

# On-disk cache (alongside food_knowledge.py)
_CACHE_DIR = Path(__file__).resolve().parent.parent / "knowledge"
_CACHE_NPY = _CACHE_DIR / "embeddings_cache.npy"
_CACHE_META = _CACHE_DIR / "embeddings_cache_meta.json"

_EMBEDDING_FALLBACK_NOTE = (
    "\n\nNOTE — KNOWLEDGE SEARCH UNAVAILABLE: There are NO retrieved knowledge excerpts this turn. "
    "Say clearly that you could not search the program's reference materials. "
    "Give only brief, non-specific lifestyle guidance (food, activity, sleep, hydration) aligned with the USER PROFILE if present. "
    "Do NOT invent numbers, food lists, thresholds, medication or device details, or study claims. "
    "Tell the user to ask again later or speak with their clinician for specifics."
)


TOP_K = 4 # knowledge chunks returned per query
MAX_HISTORY = 6 # conversation turns kept in context (pairs)
MIN_RELEVANCE = 0.42 # cosine-similarity floor (Layer 2)
# When we restrict retrieval to inferred KB categories (sleep, exercise, hydration, etc.).
MIN_RELEVANCE_TOPIC = 0.32
# Sleep queries often embed weakly vs chunks; still require topic-focused retrieval.
MIN_RELEVANCE_TOPIC_SLEEP = 0.28
CHUNK_MAX_CHARS = 1000 # max chars per chunk (Layer 1)
CHUNK_OVERLAP_SENTENCES = 1 # overlap between chunks (Layer 1)

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

_MSG_EMERGENCY = (
    "This sounds like a medical emergency.\n\n"
    "Please call 911 or go to the nearest emergency room right away.\n\n"
    "Once you are safe, I am happy to help with food and nutrition questions."
)

_MSG_MEDICAL = (
    "That sounds like a medical question, and I am not able to give medical advice.\n\n"
    "Please speak with your doctor, pharmacist, or healthcare provider — "
    "they are the right people to help with medications, test results, diagnoses, or symptoms.\n\n"
    "I can help with questions about food, diet, and healthy eating. "
    'Try asking: "What foods are good for my blood pressure?"'
)

_MSG_OFFTOPIC = (
    "I am the MyFoodRx nutrition assistant, so I can only help with questions about "
    "food, diet, and healthy eating.\n\n"
    "I cannot help with that topic. Try asking:\n"
    '- "What should I eat on the DASH diet?"\n'
    '- "What are good low-sodium snacks?"\n'
    '- "How do I manage blood sugar through food?"'
)

_MSG_LOW_RELEVANCE = (
    "I am not sure how to connect that question to food or nutrition.\n\n"
    "I am here to help with diet, healthy eating, and food choices. "
    "Could you rephrase, or ask something more specific about food or your diet plan?\n\n"
    'For example: "What foods help lower blood pressure?" or '
    '"What can I eat for breakfast on the Diabetes Plate plan?"'
)

# Suggested questions (starter / follow-up) when JSON generation fails or RAG is offline.
# Order: condition → hydration → sleep → exercise → food (matches UI contract).
_DEFAULT_SUGGESTED_QUESTIONS: list[str] = [
    "What foods fit my diet plan best?",
    "How much water should I drink daily?",
    "Does poor sleep affect my health?",
    "Is walking enough for my goals?",
    "What breakfast fits my plan?",
]

_JSON_SUGGESTIONS_SYSTEM = (
    "You are the MyFoodRx nutrition assistant. "
    "Output ONLY valid JSON — a single array of exactly 5 strings in the order specified. "
    "No markdown code fences, no commentary, no extra keys. "
    "Each string must be a question the user would ask in first person (I, my, me) — not 'you/your'."
)

# Prompt block: five scaffolded questions tied to USER PROFILE (conditions, diet, goals).
_STRUCTURED_SUGGESTION_RULES = """
You MUST return exactly 5 questions in this FIXED ORDER. Each must match the PROFILE ANCHOR below
(only conditions and diet plans that actually appear — do not invent hypertension or DASH for a
Diabetes Plate user who has no blood pressure diagnosis).

Use plain, friendly wording (4th–5th grade reading level).
Each question MUST be short enough for a phone chip: at most 8 words AND at most 70 characters (including spaces).
Prefer one short line; no long clauses.

VOICING (required):
- Write every question as if the USER is asking it (first person: I, my, me).
- Do NOT use "you", "your", or "do you" (wrong: "How much water do you drink?" right: "How much water should I drink?").
- Do NOT address the user as "you" in any chip.

Order (one question each):
1) CONDITION — Their real listed condition(s) or clearest need from profile/diet (no extra diseases).
2) HYDRATION — Fluids/water tied to their condition or assigned diet plan only.
3) SLEEP — Sleep tied to what their profile actually involves (e.g. blood sugar for diabetes; not BP unless allowed below).
4) EXERCISE — Movement tied to their conditions/goals only.
5) FOOD — Must reference ONLY their assigned diet plan from PROFILE ANCHOR (use a readable name like
   "Diabetes Plate" or "DASH" exactly matching that assignment). Never name a different plan (no DASH if they are on Diabetes Plate).

Do not repeat the same topic in two slots. Do not use identical wording in two questions.
"""


def _suggestion_profile_anchor(user_profile: dict[str, Any] | None) -> str:
    """
    Hard constraints so chips do not mention diseases/plans the user does not have
    (e.g. no blood pressure prompts for Diabetes Plate-only users without hypertension).
    """
    if not user_profile:
        return (
            "PROFILE ANCHOR:\n"
            "- No profile loaded. Use neutral healthy-eating questions only.\n"
            "- Do not name hypertension, diabetes, DASH, or a specific plan unless USER PROFILE lists them.\n"
        )

    conds = [
        str(c).strip()
        for c in (user_profile.get("medicalConditions") or [])
        if str(c).strip()
    ]
    diet_raw = user_profile.get("dietType") or user_profile.get("myPlanType") or ""
    diet = str(diet_raw).strip()
    blob = ", ".join(conds).lower()
    diet_l = diet.lower()

    has_htn = bool(
        re.search(r"hypertension|high blood pressure|\bhbp\b", blob, re.I)
    )
    has_diabetes = bool(
        re.search(
            r"diabetes|diabetic|prediabetes|pre-diabetes|"
            r"\btype\s*1\b|\btype\s*2\b|blood sugar|glucose",
            blob,
            re.I,
        )
    )
    has_obesity = bool(re.search(r"obesity|overweight", blob, re.I))

    is_dash_plan = "dash" in diet_l
    is_diabetes_plan = "diabetes" in diet_l
    # DASH is blood-pressure-oriented; Diabetes* plans are glucose-oriented.
    if is_dash_plan:
        has_htn = True
    if is_diabetes_plan:
        has_diabetes = True

    lines = [
        "PROFILE ANCHOR (obey before all other examples):",
        f"- Listed health conditions (name ONLY these if any): {', '.join(conds) if conds else '(none listed)'}",
        f"- Assigned diet plan from app (use this exact label in question 5): {diet or '(none listed)'}",
    ]

    may_use: list[str] = []
    must_not: list[str] = []

    if has_diabetes:
        may_use.append("diabetes, blood sugar, carbs, Diabetes Plate wording if that is their plan")
    if has_htn or is_dash_plan:
        may_use.append("blood pressure, sodium, DASH-style eating when plan or conditions match")
    if has_obesity:
        may_use.append("weight or healthy weight habits")

    if not has_htn and not is_dash_plan:
        must_not.append(
            "blood pressure, hypertension, DASH diet, or sodium-focused questions "
            "(user has no BP diagnosis and no DASH plan)."
        )
    if not has_diabetes and not is_diabetes_plan:
        must_not.append(
            "diabetes or blood sugar as the main angle (not in conditions and not a diabetes-type plan)."
        )

    if may_use:
        lines.append("- You MAY tie questions to: " + "; ".join(may_use) + ".")
    else:
        lines.append(
            "- No specific chronic angle detected — use general healthy eating and any health goals in profile."
        )
    for rule in must_not:
        lines.append(f"- MUST NOT: {rule}")

    lines.append(
        "- If the diet plan is Diabetes Plate (or similar), every question should still fit diabetes/blood "
        "sugar or that plan — not heart/BP unless hypertension is also listed."
    )
    if diet:
        lines.append(
            f"- Question 5 must mention only this diet plan (or 'my plan' tied to it): {diet}. "
            "Do not say DASH unless that label includes DASH."
        )

    return "\n".join(lines) + "\n"


def _structured_suggestion_user_message(
    *,
    ctx: str,
    intro: str,
    extra_context: str = "",
    user_profile: dict[str, Any] | None = None,
) -> str:
    anchor = _suggestion_profile_anchor(user_profile)
    body = f"{intro.strip()}\n\n{anchor}\nUSER PROFILE:\n{ctx or '(not available)'}\n"
    if extra_context.strip():
        body += f"\n{extra_context.strip()}\n"
    body += _STRUCTURED_SUGGESTION_RULES
    body += (
        '\nReturn ONLY a JSON array of 5 strings in that order, first person, e.g. '
        '["How do I manage my diabetes daily?", "How much water should I drink?", '
        '"Does poor sleep hurt my blood sugar?", "Is walking enough for me?", '
        '"What foods fit my Diabetes Plate plan?"]\n'
    )
    return body


def _clamp_suggestion_text(s: str, max_chars: int = 72) -> str:
    """Keep chip text readable on narrow phones if the model ignores length limits."""
    s = " ".join((s or "").split())
    if len(s) <= max_chars:
        return s
    cut = s[: max_chars].rsplit(" ", 1)[0]
    if len(cut) < 12:
        cut = s[:max_chars]
    return cut.rstrip(" ,;:") + "…"


def _parse_json_string_array(raw: str) -> list[str]:
    """Parse model output into a list of non-empty strings."""
    clean = (raw or "").strip()
    if clean.startswith("```"):
        clean = clean.removeprefix("```json").removeprefix("```JSON").removeprefix("```")
        clean = clean.strip()
        if "```" in clean:
            clean = clean.split("```", 1)[0].strip()
    try:
        data = json.loads(clean)
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []
    out: list[str] = []
    for item in data:
        if isinstance(item, str):
            s = _clamp_suggestion_text(item.strip())
            if s:
                out.append(s)
    return out[:5]


def should_suggest_follow_ups(answer: str) -> bool:
    """
    Skip follow-up question generation for canned guardrails, errors, and very short replies.
    """
    t = (answer or "").strip()
    if len(t) < 24:
        return False
    prefixes = (
        "This sounds like a medical emergency",
        "That sounds like a medical question",
        "I am the MyFoodRx nutrition assistant, so I can only help",
        "I am not sure how to connect that question",
        "I am having trouble connecting right now",
        "I am having trouble processing your question",
        "The AI service is currently at capacity",
        "I ran into a technical issue",
        "I cannot advise on medications",
    )
    return not any(t.startswith(p) for p in prefixes)


SYSTEM_PROMPT = """You are the MyFoodRx nutrition assistant. Your ONLY job is to answer questions
about food, diet, nutrition, and healthy eating related to the conditions in the user's profile.

STRICT SCOPE — you must ONLY answer questions about:
- Food choices, meal planning, and diet plans (DASH, MyPlate, Diabetes Plate)
- Nutrition concepts (calories, macronutrients, fiber, sodium, sugar, vitamins, minerals)
- Healthy eating habits and cooking methods
- Hydration and healthy beverages (including how much water to aim for)
- Sleep as it relates to energy, blood sugar patterns, and healthy routines alongside diet
- Physical activity and exercise (aerobic, strength, walking, daily movement) as they support blood sugar, blood pressure, weight, heart health, and the same conditions below — this is IN SCOPE. Use RELEVANT KNOWLEDGE for exercise; do not refuse exercise questions that connect to these goals.
- Managing diabetes, hypertension, obesity, and pre-diabetes through food and diet choices, plus the lifestyle topics above. You do NOT diagnose, prescribe medications, or replace a doctor; "diet only" here means you stay in your lane on clinical care, NOT that you ignore exercise when the knowledge base covers it.
- Pantry management, grocery shopping, reading nutrition labels
- Food allergies and dietary intolerances

CONVERSATION MANAGEMENT (greetings, gratitude, and closing — keep these short):
- Greetings: For "Hi" or "Hello," be warm in one line, then offer help with diet or meals.
- "How are you?" / "How's it going?": You MUST answer the question first in one short, friendly sentence (e.g. "I'm doing well, thank you for asking!" or "I'm great — thanks for checking in!"). Do not skip this. Do not open with "I'm here to help" or "I'm ready to help" before you answer. Optional: add "How are things on your end?" Then add one sentence pivoting to food or nutrition (how you can help with meals or their plan).
- Gratitude ONLY (when the user's message is thanks and not a new question): Respond warmly. You MAY include one short encouraging line and invite more questions — this is the ONLY turn where that is allowed. Example tone (vary wording): "You're very welcome! Remember, every healthy food choice you make today is a win for your long-term health. Do you have more questions about your meal plan or healthy eating?" Use the user's name from the profile if it is provided. Do not use that encouraging line on factual answers to other questions.
- Ending the chat: If they say they have no more questions, "Goodbye," "Bye," "That's all I needed" (with or without "thanks"), or similar, wish them well on their health journey and close warmly. Do not repeat the "I can only help with food..." disclaimer at the end of a successful session.
- Do not engage in long conversations about feelings or personal life unrelated to food and nutrition.

Exercise, sleep, and hydration that support healthy eating and chronic-condition management are IN SCOPE — never use the refusal line below for those; answer from RELEVANT KNOWLEDGE (or general scope rules if a NOTE says retrieval failed).

IF the user asks about ANYTHING outside this scope — other than CONVERSATION MANAGEMENT above — respond with exactly:
"I can only help with food and nutrition questions. Please ask me about your diet, meals, or healthy eating."

ABSOLUTE RULES — never break these:
1. NEVER provide medical advice, diagnose any condition, or suggest any medication or dose.
2. NEVER interpret lab results, prescriptions, or test reports.
3. If a user mentions specific medications, respond: "I cannot advise on medications. Please speak with your doctor or pharmacist."
4. If a user describes symptoms or asks about diagnoses, respond: "For symptoms or diagnoses, please consult your doctor. I can help with diet questions."
5. If someone appears to be in a medical emergency, immediately say: "Please call 911 or go to the emergency room."
6. NEVER discuss: weather, sports teams/scores, movies, politics, technology, finance, or relationships. Exercise and physical activity for health are allowed (see STRICT SCOPE); do not lump them with "sports" refusals. Small talk is limited to CONVERSATION MANAGEMENT (brief greetings, thanks, and goodbyes) only.

LANGUAGE RULES (many users have low reading literacy — keep everything very easy to read):
- Write at about a 4th- to 5th-grade reading level. Use very short sentences (one idea each). Use common, everyday words.
- Avoid medical jargon. If you must use a health term, say it in simple words right after (e.g. "blood pressure — the force of blood in your arteries").
- Use short bullet points for lists (a few words per line when possible). Be clear and friendly, but stay factual.
- Keep the main answer to about 2-4 short sentences, or a small bullet list, unless the user clearly needs more steps.
- For food, nutrition, sleep, exercise, or health-education answers: STOP when you have answered the question. Do NOT add motivational closings, cheerleading, or invitations like "Keep up the great work," "Feel free to enjoy it often," "Do you have any other questions about…?" — those belong ONLY in Gratitude (thank-you) or Ending-the-chat in CONVERSATION MANAGEMENT, not after every reply.

ONLY use information from the RELEVANT KNOWLEDGE section below. Do not make up facts.

KNOWLEDGE FAITHFULNESS (critical — reduces hallucination):
- The RELEVANT KNOWLEDGE excerpts are your only source for specific facts (numbers, study results, thresholds, food lists, mechanisms, device or medication names). Ground your answer in that text.
- If the excerpts do NOT contain enough detail to answer the question precisely, say so plainly (e.g. that this assistant's materials don't cover that specific point). Offer only what the excerpts DO support, or suggest discussing specifics with their doctor or care team.
- Do NOT invent: statistics, percentages, dosages, lab cutoffs, brand names, or details about machines/devices (e.g. CPAP), therapies (e.g. CBT-I), or drugs unless they appear in the excerpts.
- Do NOT cite fake studies, authors, or "research says" unless the excerpt names a source. You may describe general principles that appear in the excerpts in your own words.
- If the question mixes several topics and only some are in the excerpts, answer the parts you can support and acknowledge what is not in the materials.
- Short, honest answers are better than long confident guesses.

If a NOTE says there is no knowledge excerpt for this turn (conversation management only), follow CONVERSATION MANAGEMENT instead — do not fabricate nutrition facts.
If a NOTE says knowledge search was unavailable, give only high-level, non-specific guidance and tell the user your knowledge excerpts were not loaded for that turn — do not fill in precise numbers or lists."""


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
    }
)

_POLITE_CHAT_REGEX = tuple(
    re.compile(p, re.IGNORECASE)
    for p in (
        r"^(thank you|thanks|thx|ty|thnx|thank u)(\s+(so|very)\s+much)?$",
        r"^(no|nothing)\s+(more|else)(\s+thanks?|\s+thank you)?$",
        r"^i\s*(have|'ve)\s+no\s+more\s+questions$",
        # "that's all", "that's all thanks", "that's all i needed thanks", etc.
        r"^that\s*'?s\s+all(\s+i\s+needed)?(\s+thanks?|\s+thank you|\s+thx|\s+ty)?$",
        r"^how\s+are\s+you(\s+doing)?$",
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
        hints.append("physical activity aerobic strength exercise safety blood pressure diabetes")
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


def is_session_closing(message: str) -> bool:
    """
    True when the user is ending small talk (thanks, bye, ok, etc.).

    Same behavior as :func:`_skip_rag_polite_chat` — one implementation so
    routers and clients stay aligned with the RAG fast path.
    """
    return _skip_rag_polite_chat(message)


def _history_to_contents(history: list[dict[str, Any]]) -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for turn in history[-(MAX_HISTORY * 2) :]:
        role = turn.get("role") or "user"
        parts_raw = turn.get("parts") or []
        texts = [p for p in parts_raw if isinstance(p, str) and p.strip()]
        if not texts:
            continue
        result.append({"role": role, "content": " ".join(texts)})
    return result


def classify_query(message: str) -> str:
    if _EMERGENCY_PATTERNS.search(message):
        return _QueryClass.EMERGENCY
    if _HARD_MEDICAL_PATTERNS.search(message):
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
    clean_text = _clean_content(doc["content"])
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


def _load_embedding_cache(
    chunks: list[dict[str, str | int]],
) -> list[list[float]] | None:
    if not _CACHE_NPY.exists() or not _CACHE_META.exists():
        logger.info("Embedding cache: not found — will embed from scratch.")
        return None
    try:
        meta = json.loads(_CACHE_META.read_text(encoding="utf-8"))
        fp = _cache_fingerprint(chunks)
        if meta.get("count") != fp["count"]:
            logger.warning(
                "Embedding cache invalid: chunk count changed (%s → %s). Re-embedding.",
                meta.get("count"),
                fp["count"],
            )
            return None
        if meta.get("chunks_sha256") != fp["chunks_sha256"]:
            logger.warning(
                "Embedding cache invalid: knowledge chunks changed. Re-embedding.",
            )
            return None
        if meta.get("embedding_model") != fp["embedding_model"]:
            logger.warning(
                "Embedding cache invalid: model changed (%s → %s). Re-embedding.",
                meta.get("embedding_model"),
                fp["embedding_model"],
            )
            return None
        matrix = np.load(str(_CACHE_NPY))
        if matrix.shape[0] != len(chunks):
            logger.warning(
                "Embedding cache invalid: row count mismatch (%s vs %s). Re-embedding.",
                matrix.shape[0],
                len(chunks),
            )
            return None
        embeddings = [matrix[i].tolist() for i in range(matrix.shape[0])]
        logger.info(
            "Embedding cache loaded from disk — %d embeddings, shape %s. "
            "No Ollama embedding calls needed at startup.",
            len(embeddings),
            matrix.shape,
        )
        return embeddings
    except Exception as exc:
        logger.warning("Embedding cache load failed (%s). Will re-embed.", exc)
        return None


def _save_embedding_cache(
    chunks: list[dict[str, str | int]],
    embeddings: list[list[float]],
) -> None:
    try:
        _CACHE_DIR.mkdir(parents=True, exist_ok=True)
        matrix = np.array(embeddings, dtype=np.float32)
        np.save(str(_CACHE_NPY), matrix)
        _CACHE_META.write_text(
            json.dumps(_cache_fingerprint(chunks), indent=2),
            encoding="utf-8",
        )
        logger.info(
            "Embedding cache saved → %s  shape=%s",
            _CACHE_NPY,
            matrix.shape,
        )
    except Exception as exc:
        logger.error("Failed to save embedding cache: %s", exc)


def _ollama_embed(text: str) -> list[float]:
    """Call Ollama /api/embeddings synchronously (run via asyncio.to_thread)."""
    resp = httpx.post(
        f"{settings.ollama_base_url}/api/embeddings",
        json={"model": settings.ollama_embed_model, "prompt": text},
        timeout=60.0,
    )
    resp.raise_for_status()
    return resp.json()["embedding"]


def _ollama_chat(messages: list[dict[str, str]], system: str) -> str:
    """Call Ollama /api/chat synchronously. System prompt is prepended as a system message."""
    full_messages = [{"role": "system", "content": system}] + messages
    resp = httpx.post(
        f"{settings.ollama_base_url}/api/chat",
        json={
            "model": settings.ollama_generation_model,
            "messages": full_messages,
            "stream": False,
        },
        timeout=120.0,
    )
    resp.raise_for_status()
    return resp.json()["message"]["content"]


class RAGService:
    """Singleton RAG service. Call initialize() once at app startup via lifespan."""

    def __init__(self) -> None:
        self._ready = False
        self._chunks: list[dict[str, str | int]] = []
        self._chunk_embeddings: list[list[float]] = []

    async def initialize(self) -> None:
        if not KNOWLEDGE_DOCS:
            logger.warning(
                "KNOWLEDGE_DOCS is empty in food_knowledge.py — add documents before using RAG."
            )
            return

        # Verify Ollama is reachable before doing any work.
        try:
            httpx.get(f"{settings.ollama_base_url}/api/tags", timeout=5.0).raise_for_status()
        except Exception as exc:
            logger.warning(
                "Ollama not reachable at %s: %s — chatbot will use fallback responses.",
                settings.ollama_base_url,
                exc,
            )
            return

        self._chunks = build_chunks(KNOWLEDGE_DOCS)
        _log_chunk_preview(self._chunks, sample_per_doc=2)

        cached = _load_embedding_cache(self._chunks)
        if cached is not None:
            self._chunk_embeddings = cached
            self._ready = True
            logger.info(
                "RAG service ready (from cache) — %d chunks across %d documents.",
                len(self._chunks),
                len(KNOWLEDGE_DOCS),
            )
            return

        logger.info(
            "Embedding %d chunks from %d docs with %s …",
            len(self._chunks),
            len(KNOWLEDGE_DOCS),
            EMBEDDING_MODEL,
        )

        embeddings: list[list[float]] = []
        for idx, chunk in enumerate(self._chunks):
            text = f"{chunk['title']}. {chunk['text']}"
            vec: list[float] | None = None
            for attempt in range(_EMBED_MAX_ATTEMPTS):
                try:
                    vec = await asyncio.to_thread(_ollama_embed, text)
                    break
                except Exception as exc:
                    if attempt < _EMBED_MAX_ATTEMPTS - 1:
                        delay = 2.0 ** attempt
                        logger.warning(
                            "Embedding chunk '%s[%s]' failed (attempt %s/%s), "
                            "retrying in %.1fs: %s",
                            chunk.get("doc_id"),
                            chunk.get("chunk_index"),
                            attempt + 1,
                            _EMBED_MAX_ATTEMPTS,
                            delay,
                            exc,
                        )
                        await asyncio.sleep(delay)
                        continue
                    logger.error(
                        "Failed to embed chunk '%s[%s]': %s",
                        chunk.get("doc_id"),
                        chunk.get("chunk_index"),
                        exc,
                    )
            embeddings.append(vec if vec else [0.0] * EMBEDDING_DIM_FALLBACK)

        self._chunk_embeddings = embeddings
        _save_embedding_cache(self._chunks, embeddings)

        self._ready = True
        logger.info(
            "RAG service ready — %d chunks embedded across %d documents.",
            len(self._chunks),
            len(KNOWLEDGE_DOCS),
        )

    def _retrieve(
        self, query_embedding: list[float]
    ) -> tuple[list[dict[str, str]], float]:
        if not self._chunk_embeddings or not self._chunks:
            return [], 0.0
        scores = [
            (i, _cosine(query_embedding, emb))
            for i, emb in enumerate(self._chunk_embeddings)
        ]
        scores.sort(key=lambda x: x[1], reverse=True)
        best_score = scores[0][1] if scores else 0.0
        chunks = [self._chunks[i] for i, _ in scores[:TOP_K]]
        # Downcast chunk fields used in generation context.
        return [dict(c) for c in chunks], best_score

    def _retrieve_for_categories(
        self,
        query_embedding: list[float],
        categories_lower: frozenset[str],
    ) -> tuple[list[dict[str, str]], float]:
        """Like _retrieve but only chunks whose category (lowercased) is in the set."""
        if not self._chunk_embeddings or not self._chunks:
            return [], 0.0
        pairs: list[tuple[int, float]] = []
        for i, emb in enumerate(self._chunk_embeddings):
            cat = str(self._chunks[i].get("category", "")).lower()
            if cat not in categories_lower:
                continue
            pairs.append((i, _cosine(query_embedding, emb)))
        if not pairs:
            return [], 0.0
        pairs.sort(key=lambda x: x[1], reverse=True)
        best_score = pairs[0][1]
        chunks = [self._chunks[i] for i, _ in pairs[:TOP_K]]
        return [dict(c) for c in chunks], best_score

    @staticmethod
    def _build_user_context(
        user_profile: dict[str, Any] | None,
        pantry_items: list[dict],
    ) -> str:
        if not user_profile:
            return ""

        lines: list[str] = []

        name = user_profile.get("name") or user_profile.get("firstName")
        if name:
            lines.append(f"User's name: {name}")

        conditions = user_profile.get("medicalConditions") or []
        if conditions:
            lines.append(f"Health conditions: {', '.join(str(c) for c in conditions)}")

        allergies = user_profile.get("allergies") or []
        if allergies:
            lines.append(
                f"Food allergies/intolerances: {', '.join(str(a) for a in allergies)}"
            )

        diet_type = user_profile.get("dietType") or user_profile.get("myPlanType")
        if diet_type:
            lines.append(f"Assigned diet plan: {diet_type}")

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
        history_contents: list[dict[str, str]],
    ) -> str:
        messages = list(history_contents) + [{"role": "user", "content": message}]
        try:
            out = _ollama_chat(messages, full_system).strip()
            if not out:
                logger.error("Empty generation from Ollama model %s", settings.ollama_generation_model)
                return "I ran into a technical issue. Please try again."
            logger.debug("Generated with Ollama model: %s", settings.ollama_generation_model)
            return out
        except Exception as exc:
            logger.error("Generation error with Ollama model %s: %s", settings.ollama_generation_model, exc)
            return "I ran into a technical issue. Please try again."

    async def chat(
        self,
        message: str,
        history: list[dict[str, Any]],
        user_profile: dict[str, Any] | None = None,
        pantry_items: list[dict] | None = None,
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

        if not self._ready:
            return "I am having trouble connecting right now. Please try again in a moment."

        history_contents = _history_to_contents(history)
        user_context = self._build_user_context(user_profile, pantry_items or [])

        if _skip_rag_polite_chat(message):
            logger.info("Polite chat turn — skipping query embedding")
            full_system = SYSTEM_PROMPT
            if user_context:
                full_system += f"\n\nUSER PROFILE:\n{user_context}"
            full_system += _POLITE_CHAT_NOTE
            if _is_how_are_you_turn(message):
                full_system += _HOW_ARE_YOU_NOTE
            return self._generate_reply(message, full_system, history_contents)

        text_for_embed = _embedding_text_for_retrieval(message)
        query_embedding: list[float] | None = None
        use_embedding_fallback = False
        for attempt in range(_EMBED_MAX_ATTEMPTS):
            try:
                query_embedding = await asyncio.to_thread(_ollama_embed, text_for_embed)
                break
            except Exception as exc:
                if attempt < _EMBED_MAX_ATTEMPTS - 1:
                    delay = 2.0 ** attempt
                    logger.warning(
                        "Query embedding failed (attempt %s/%s), retrying in %.1fs: %s",
                        attempt + 1,
                        _EMBED_MAX_ATTEMPTS,
                        delay,
                        exc,
                    )
                    await asyncio.sleep(delay)
                    continue
                logger.error("Embedding error after retries: %s", exc)
                use_embedding_fallback = True
                break

        if query_embedding is None:
            if use_embedding_fallback:
                logger.warning("Answering without RAG — embedding unavailable for this request.")
                full_system = SYSTEM_PROMPT
                if user_context:
                    full_system += f"\n\nUSER PROFILE:\n{user_context}"
                full_system += _EMBEDDING_FALLBACK_NOTE
                return self._generate_reply(message, full_system, history_contents)
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

        knowledge_context = "\n\n".join(
            f"[{chunk['title']} — {chunk['category']} — Source: {chunk['source']}]\n"
            f"{chunk['text']}"
            for chunk in relevant_docs
        )

        full_system = SYSTEM_PROMPT
        if user_context:
            full_system += f"\n\nUSER PROFILE:\n{user_context}"
        full_system += f"\n\nRELEVANT KNOWLEDGE (use ONLY this):\n{knowledge_context}"

        return self._generate_reply(message, full_system, history_contents)

    def generate_starter_questions(
        self,
        user_profile: dict[str, Any] | None,
        pantry_items: list[dict],
    ) -> list[str]:
        """Profile-based starters: condition, hydration, sleep, exercise, food (fixed order)."""
        if not self._ready:
            return list(_DEFAULT_SUGGESTED_QUESTIONS)

        ctx = self._build_user_context(user_profile, pantry_items)
        user_msg = _structured_suggestion_user_message(
            ctx=ctx,
            intro=(
                "Generate 5 starter questions for someone opening the MyFoodRx chat. "
                "They want help with eating and lifestyle for their health."
            ),
            user_profile=user_profile,
        )
        try:
            raw = self._generate_reply(
                user_msg,
                _JSON_SUGGESTIONS_SYSTEM,
                [],
            )
            parsed = _parse_json_string_array(raw)
            return parsed if len(parsed) >= 3 else list(_DEFAULT_SUGGESTED_QUESTIONS)
        except Exception as exc:
            logger.warning("Starter question generation failed: %s", exc)
            return list(_DEFAULT_SUGGESTED_QUESTIONS)

    def generate_follow_up_questions(
        self,
        original_question: str,
        answer: str,
        user_profile: dict[str, Any] | None,
    ) -> list[str]:
        """Follow-ups after a reply: same five-bucket scaffold, tied to profile + conversation."""
        if not self._ready:
            return list(_DEFAULT_SUGGESTED_QUESTIONS)

        ctx = self._build_user_context(user_profile, [])
        snippet = (answer or "")[:500]
        extra = (
            f'Recent user question: "{original_question.strip()}"\n'
            f"Recent assistant answer (excerpt):\n{snippet}\n"
            "Where it fits naturally, align questions with this topic — but still cover all five buckets "
            "in order (condition, hydration, sleep, exercise, food) and stay anchored to the USER PROFILE."
        )
        user_msg = _structured_suggestion_user_message(
            ctx=ctx,
            intro="Generate the user's next 5 suggested questions after this exchange.",
            extra_context=extra,
            user_profile=user_profile,
        )
        try:
            raw = self._generate_reply(
                user_msg,
                _JSON_SUGGESTIONS_SYSTEM,
                [],
            )
            parsed = _parse_json_string_array(raw)
            return parsed if len(parsed) >= 3 else list(_DEFAULT_SUGGESTED_QUESTIONS)
        except Exception as exc:
            logger.warning("Follow-up question generation failed: %s", exc)
            return list(_DEFAULT_SUGGESTED_QUESTIONS)


rag_service = RAGService()
