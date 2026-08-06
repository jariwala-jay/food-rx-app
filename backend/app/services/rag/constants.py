"""
rag/constants.py — all numeric thresholds, model IDs, collection names,
regex patterns, message strings, and shared data structures.

Nothing in this module does I/O or imports from other app modules.
"""

from __future__ import annotations

import re
import time
from typing import Any

# ---------------------------------------------------------------------------
# Embedding + generation model config
# ---------------------------------------------------------------------------

EMBEDDING_MODEL = "models/gemini-embedding-001"
EMBEDDING_DIM_FALLBACK = 3072
COLLECTION_NAME = "myfoodrx_chunks"
# Retries when embed API returns 429 (free tier often rate-limits per minute/day).
_EMBED_MAX_ATTEMPTS = 4
# Space out document embedding calls to avoid hitting per-minute embed quotas at startup.
_EMBED_CHUNK_INTERVAL_SEC = 0.55

# Pinned model IDs only (avoid *-latest aliases — behavior can change without notice).
GENERATION_MODELS = [
    "models/gemini-2.5-flash",
    "models/gemini-2.0-flash",
    "models/gemini-2.0-flash-lite",
]

# Groq fallback — used when all Gemini generation models return 429.
GROQ_FALLBACK_MODEL = "llama-3.3-70b-versatile"

# ---------------------------------------------------------------------------
# Retrieval + scoring thresholds
# ---------------------------------------------------------------------------

# Rank this many chunks by similarity; only RAG_CONTEXT_DOC_COUNT go to LLM.
RETRIEVAL_CANDIDATES_K = 8
RAG_CONTEXT_DOC_COUNT = 5
LLM_MAX_OUTPUT_TOKENS = 768
LLM_TEMPERATURE = 0.3  # Lower for plan-consistent, safety-critical replies

# ---------------------------------------------------------------------------
# Cache config
# ---------------------------------------------------------------------------

RAG_CACHE_COLLECTION = "rag_response_cache"
# Bump when cache row shape or system-prompt guardrails change materially.
RAG_CACHE_VERSION = 7
RAG_CACHE_EMBED_SIMILARITY_ENABLED = True
RAG_CACHE_EMBED_THRESHOLD = 0.93
RAG_CACHE_EMBED_SCAN_LIMIT = 80

# ---------------------------------------------------------------------------
# Conversation history + relevance thresholds
# ---------------------------------------------------------------------------

MAX_HISTORY = 6  # conversation turns kept in context (pairs)
MIN_RELEVANCE = 0.42  # cosine-similarity floor (Layer 2)
MIN_RELEVANCE_DIET_WHITELIST = 0.25  # lowered floor for basic food-list queries
# When we restrict retrieval to inferred KB categories (sleep, exercise, hydration, etc.).
MIN_RELEVANCE_TOPIC = 0.32
# Sleep queries often embed weakly vs chunks; still require topic-focused retrieval.
MIN_RELEVANCE_TOPIC_SLEEP = 0.28

# ---------------------------------------------------------------------------
# Chunking config
# ---------------------------------------------------------------------------

CHUNK_MAX_CHARS = 1000  # max chars per chunk (Layer 1 indexing)
CHUNK_OVERLAP_SENTENCES = 1  # overlap between chunks (Layer 1)

# ---------------------------------------------------------------------------
# Rate limiting + security
# ---------------------------------------------------------------------------

MAX_INPUT_CHARS = 1500  # user message length cap (abuse + injection mitigation)
RATE_LIMIT_WINDOW_SECONDS = 60
RATE_LIMIT_MAX_MESSAGES = 10

_user_message_timestamps: dict[str, list[float]] = {}

SECURITY_EVENTS_COLLECTION = "security_events"

# ---------------------------------------------------------------------------
# Security + classification regex patterns
# ---------------------------------------------------------------------------

_INJECTION_PATTERNS = re.compile(
    r"\b("
    r"ignore\s+(all\s+)?(previous|prior|above|your)\s+(instructions?|rules?|guidelines?|constraints?|prompt)|"
    r"disregard\s+(all\s+)?(previous|prior|your\s+)?(safety\s+)?(instructions?|rules?|constraints?|guidelines?)|"
    r"forget\s+(everything|all|your\s+instructions)|"
    r"override\s+(your\s+)?(instructions?|safety|rules?|guidelines?)|"
    r"bypass\s+(your\s+)?(safety|restrictions?|rules?|guidelines?|filters?)|"
    r"disable\s+(safety|filters?|restrictions?|guidelines?)|"
    r"you\s+are\s+now\s+(a\s+)?(general|unrestricted|different|new|free)\b|"
    r"pretend\s+(you\s+are|to\s+be)|"
    r"act\s+as\s+(if\s+you\s+are|a\s+different|an?\s+unrestricted)|"
    r"roleplay\s+as\s+(a\s+)?(doctor|physician|unrestricted)|"
    r"(show|tell|reveal|print|repeat|display)\s+(me\s+)?(your\s+)?(system\s+prompt|instructions?|prompt)|"
    r"what\s+are\s+your\s+(instructions?|rules?|guidelines?|constraints?)|"
    r"repeat\s+(everything|all\s+text)\s+(above|before)|"
    r"\bDAN\b|do\s+anything\s+now|jailbreak|developer\s+mode|god\s+mode|"
    r"(admin|developer)\s+(mode|access|override)"
    r")\b",
    re.IGNORECASE,
)

_EMBEDDED_INSTRUCTION_PATTERNS = re.compile(
    r"(\[SYSTEM\]|\[INST\]|\[PROMPT\]|<system>|</system>|<instructions?>|"
    r"###\s*System|###\s*Instructions?|"
    r"---\s*NEW\s*INSTRUCTIONS?\s*---|"
    r"IGNORE\s+ABOVE|NEW\s+TASK:|ACTUAL\s+TASK:)",
    re.IGNORECASE,
)

_EMERGENCY_PATTERNS = re.compile(
    r"\b("
    r"chest\s*pain|heart\s*attack|cardiac\s*arrest|stroke|can'?t\s*breath|"
    r"difficulty\s*breath|not\s*breath|stop\s*breath|seizure|convuls|"
    r"unconscious|faint|pass(ed)?\s*out|overdos\w*|suicid\w*|kill\s*(my)?self|"
    r"bleed(ing)?\s*heavy|severe\s*bleed|anaphylax|epi\s*pen|throat\s*(clos|swell)|"
    r"911|emergency\s*room|\bER\b|ambulance|"
    r"blood\s*sugar\s*(is\s*)?(very\s*)?(high|low|dropping|crashing)|"
    r"blood\s*pressure\s*(is\s*)?(very\s*)?(high|low)|"
    r"diabetic\s*(keto)?acidosis|\bdka\b|"
    r"diabetic\s*(shock|coma)|insulin\s*shock|"
    r"stroke\s*symptoms?|"
    r"can'?t\s*(move|speak|see)|"
    r"sudden\s*(numbness|weakness|confusion|headache)|"
    r"heart\s+is\s+(racing|pounding|flutter)|heart\s*(racing|pounding|flutter)|palpitation|"
    r"hypoglycemi(c\s+(attack|episode|emergency))|"
    r"hyperglycemi(c\s+(attack|episode|emergency))|"
    r"(feel(ing)?|having|experiencing|think\s+i\s+(have|am\s+having))\s+.{0,40}hypoglycemi|"
    r"(feel(ing)?|having|experiencing|think\s+i\s+(have|am\s+having))\s+.{0,40}hyperglycemi"
    r")\b",
    re.IGNORECASE,
)

_FOOD_DRUG_INTERACTION = re.compile(
    r"\b("
    r"grapefruit|"
    r"food(s)?\s+(that\s+)?(affect|interact|interfere)|"
    r"eat\s+(with|while\s+taking)|"
    r"foods?\s+(to\s+)?(avoid|limit)\s+(with|when\s+taking)|"
    r"interact(s)?\s+with\s+my\s+medication|"
    r"interact(s)?\s+with\s+(my\s+)?(medicine|meds|pills?|prescription)"
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
    r"my\s*(doctor|physician|specialist)\s*(said|told|prescribed|recommend)|"
    r"maximum\s+(amount\s+of\s+)?(sugar|carb(ohydrate)?s?|glucose|calories?)\s+(i\s+can|before)|"
    r"how\s+much\s+(sugar|carb(ohydrate)?s?|glucose)\s+(can\s+i\s+eat\s+before|before\s+i)"
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

_ALWAYS_ANSWER_PATTERNS = re.compile(
    r"\b(what foods|which foods|what should i eat|what can i eat|"
    r"foods (that|to|for)|good foods|best foods)\b",
    re.IGNORECASE,
)

_FOLLOWUP_QUERY_PATTERN = re.compile(
    r"\b("
    r"those|that|more about|tell me more|what about|"
    r"the ones you|you mentioned|"
    r"specific foods?|include in my (meals?|diet|plan)|"
    r"more (foods?|ideas?|examples?|options?)|give me more|"
    r"any others?|what else|expand on|elaborate"
    r")\b",
    re.IGNORECASE,
)

_EXERCISE_INTENT = re.compile(
    r"\b("
    r"exercise|exercises|exercising|workout|work\s*outs?|working\s*out|"
    r"aerobic|cardio|cardiovascular|physical\s*activity|"
    r"strength\s*train(?:ing)?|resistance\s*train(?:ing)?|weight\s*lift|lifting\b|"
    r"\bgym\b|fitness|move\s*more|walking\s*program"
    r")\b",
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Canned guardrail messages
# ---------------------------------------------------------------------------

_MSG_EMERGENCY = (
    "This may be a medical emergency. Please call 911 or go to the nearest emergency room right away."
)

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

_MSG_LOW_RELEVANCE_NUTRITION = (
    "I don't have specific details on that right now. "
    "In general, focus on vegetables, lean protein, and whole grains. "
    "Try asking about a specific meal or food and I can give you better guidance."
)

_MSG_INPUT_TOO_LONG = (
    "Your message is too long. Please ask one question at a time.\n\n"
    "I'm here to help with food, nutrition, and healthy habits."
)

_MSG_RATE_LIMITED = (
    "You're sending messages too quickly. Please wait a moment before asking another question.\n\n"
    "I'm here to help with food, nutrition, and healthy habits."
)

# LLM prompt notes injected into system prompt for special turn types.
_POLITE_CHAT_NOTE = (
    "\n\nNOTE — NO KNOWLEDGE EXCERPT THIS TURN: The user's message is only conversation "
    "management (greeting, thanks, or closing — see CONVERSATION MANAGEMENT). "
    "Do not invent nutrition facts. Follow CONVERSATION MANAGEMENT for tone and length."
)

_HOW_ARE_YOU_NOTE = (
    "\n\nTHIS TURN — USER ASKED HOW YOU ARE: Your first sentence must directly say how you are "
    "(e.g. doing well / great / good) and thank them or acknowledge the question. "
    "Forbidden as an opening: 'I'm here to help,' 'I'm ready to help,' or jumping straight to "
    "nutrition before answering. After you answer, then pivot to how you can help with meals or diet. "
    "CRITICAL: When pivoting, reference ONLY the health conditions listed in the USER PROFILE above — "
    "name each condition explicitly (e.g. 'blood sugar and blood pressure' for diabetes+hypertension). "
    "Do NOT substitute the plan name (like 'Diabetes Plate') for the conditions, and do NOT add "
    "goals like 'weight loss' or 'weight management' unless obesity is explicitly in the profile."
)

# ---------------------------------------------------------------------------
# Guardrail prefix detection (used by should_suggest_follow_ups)
# ---------------------------------------------------------------------------


def _first_nonempty_line(text: str) -> str:
    for line in (text or "").splitlines():
        s = line.strip()
        if s:
            return s
    return ""


# First lines of canned guardrail strings — stays in sync when _MSG_* wording changes.
_CANNED_GUARDRAIL_PREFIXES: tuple[str, ...] = tuple(
    _first_nonempty_line(m)
    for m in (
        _MSG_EMERGENCY,
        _MSG_MEDICAL,
        _MSG_OFFTOPIC,
        _MSG_LOW_RELEVANCE,
        _MSG_LOW_RELEVANCE_NUTRITION,
    )
)

# Other fixed replies from chat() / generators that should not attach follow-up chips.
_EXTRA_NO_FOLLOWUP_PREFIXES: tuple[str, ...] = (
    "I am having trouble connecting right now",
    "I am having trouble processing your question",
    "I'm having trouble responding right now",
    "The AI service is currently at capacity",
    "I ran into a technical issue",
    "I cannot advise on medications",
    _first_nonempty_line(_MSG_INPUT_TOO_LONG),
    _first_nonempty_line(_MSG_RATE_LIMITED),
)

_NO_FOLLOWUP_PREFIXES: tuple[str, ...] = (
    _CANNED_GUARDRAIL_PREFIXES + _EXTRA_NO_FOLLOWUP_PREFIXES
)

# ---------------------------------------------------------------------------
# Plan data (used by cache helpers)
# ---------------------------------------------------------------------------

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
