"""
RAG (Retrieval-Augmented Generation) service for the MyFoodRx chatbot.

Uses the new `google-genai` SDK (replaces deprecated `google-generativeai`).

Three-layer guard system
────────────────────────
Layer 1 — Keyword pre-filter (no LLM call)
    Classifies every message as:
      "emergency"  → 911 redirect
      "medical"    → redirect to doctor
      "off_topic"  → polite out-of-scope refusal
      "diet"       → proceed to RAG pipeline

Layer 2 — Similarity threshold (semantic scope check)
    Best cosine-similarity against 25 nutrition chunks must be >= MIN_RELEVANCE.
    Below threshold → generic "I can only help with food/nutrition" refusal.

Layer 3 — Hardened system prompt
    LLM receives an explicit scope contract forbidding medical advice and
    off-topic responses, and is told to use ONLY the retrieved knowledge.
"""

from __future__ import annotations

import logging
import math
import re
from typing import Any

from google import genai
from google.genai import types

from app.config import settings
from app.knowledge.food_knowledge import KNOWLEDGE_DOCS

logger = logging.getLogger(__name__)

# ─── Model names ─────────────────────────────────────────────────────────────

EMBEDDING_MODEL   = "models/gemini-embedding-001"
# Ordered list — service tries each in sequence until one succeeds (quota failover)
GENERATION_MODELS = [
    "models/gemini-2.5-flash",
    "models/gemini-2.0-flash-lite",
    "models/gemini-2.0-flash",
    "models/gemini-flash-latest",
    "models/gemini-flash-lite-latest",
]
TOP_K         = 4     # knowledge chunks returned per query
MAX_HISTORY   = 6     # conversation turns kept in context (pairs)
MIN_RELEVANCE = 0.42  # cosine-similarity floor (Layer 2)

# ─── Layer 1: keyword / pattern sets ─────────────────────────────────────────

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

# Hard medical: always blocked, even when a diet word is present.
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

# Soft medical: blocked unless a diet signal is also present.
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

# Presence of any of these overrides soft-medical / off-topic blocks.
_DIET_SIGNALS = re.compile(
    r"(?<!\w)("
    r"eat|food|diet|nutrition|meal|recipe|calorie|carb|protein|fat|fiber|"
    r"vitamin|mineral|sodium|sugar|salt|portion|serving|snack|drink|water|"
    r"vegetable|fruit|grain|dairy|pantry|ingredient|cook|health|weight|"
    r"blood\s*sugar|blood\s*pressure|DASH|diabet|hypertension|obesity|"
    r"MyPlate|prediabet|glucose|cholesterol|potassium|allerg|intoleran|"
    r"gluten|lactose|vegan|vegetarian|keto|mediterranean|whole\s*grain|"
    r"breakfast|lunch|dinner|hydrat|fast(ing)?|nutrient"
    r")",
    re.IGNORECASE,
)

# ─── Canned refusal messages ──────────────────────────────────────────────────

_MSG_EMERGENCY = (
    "This sounds like a medical emergency.\n\n"
    "Please call 911 or go to the nearest emergency room right away.\n\n"
    "Once you are safe, I am happy to help with food and nutrition questions."
)

_MSG_MEDICAL = (
    "That sounds like a medical question, and I am not able to give medical advice.\n\n"
    "Please speak with your doctor, pharmacist, or healthcare provider - "
    "they are the right people to help with medications, test results, diagnoses, or symptoms.\n\n"
    "I can help with questions about food, diet, and healthy eating. "
    "Try asking: \"What foods are good for my blood pressure?\""
)

_MSG_OFFTOPIC = (
    "I am the MyFoodRx nutrition assistant, so I can only help with questions about "
    "food, diet, and healthy eating.\n\n"
    "I cannot help with that topic. Try asking:\n"
    "- \"What should I eat on the DASH diet?\"\n"
    "- \"What are good low-sodium snacks?\"\n"
    "- \"How do I manage blood sugar through food?\""
)

_MSG_LOW_RELEVANCE = (
    "I am not sure how to connect that question to food or nutrition.\n\n"
    "I am here to help with diet, healthy eating, and food choices. "
    "Could you rephrase, or ask something more specific about food or your diet plan?\n\n"
    "For example: \"What foods help lower blood pressure?\" or "
    "\"What can I eat for breakfast on the Diabetes Plate plan?\""
)

# ─── System prompt (Layer 3) ──────────────────────────────────────────────────

SYSTEM_PROMPT = """You are the MyFoodRx nutrition assistant. Your ONLY job is to answer questions
about food, diet, nutrition, and healthy eating related to the conditions in the user's profile.

STRICT SCOPE - you must ONLY answer questions about:
- Food choices, meal planning, and diet plans (DASH, MyPlate, Diabetes Plate)
- Nutrition concepts (calories, macronutrients, fiber, sodium, sugar, vitamins, minerals)
- Healthy eating habits and cooking methods
- Managing health conditions (diabetes, hypertension, obesity) THROUGH DIET ONLY
- Pantry management, grocery shopping, reading nutrition labels
- Food allergies and dietary intolerances
- Hydration and healthy beverages

IF the user asks about ANYTHING outside this scope, respond with exactly:
  "I can only help with food and nutrition questions. Please ask me about your diet, meals, or healthy eating."

ABSOLUTE RULES - never break these:
1. NEVER provide medical advice, diagnose any condition, or suggest any medication or dose.
2. NEVER interpret lab results, prescriptions, or test reports.
3. If a user mentions specific medications, respond: "I cannot advise on medications. Please speak with your doctor or pharmacist."
4. If a user describes symptoms or asks about diagnoses, respond: "For symptoms or diagnoses, please consult your doctor. I can help with diet questions."
5. If someone appears to be in a medical emergency, immediately say: "Please call 911 or go to the emergency room."
6. NEVER discuss: weather, sports, movies, politics, technology, finance, relationships, or any topic unrelated to food and nutrition.

LANGUAGE RULES:
- Write at an 8th-grade reading level. Short sentences. No medical jargon.
- Use bullet points for lists. Be warm and encouraging.
- Keep answers to 3-6 sentences or a short list.
- Always end with one positive, motivating sentence.

ONLY use information from the RELEVANT KNOWLEDGE section below. Do not make up facts."""


# ─── Query classifier ─────────────────────────────────────────────────────────

class _QueryClass:
    EMERGENCY = "emergency"
    MEDICAL   = "medical"
    OFF_TOPIC = "off_topic"
    DIET      = "diet"


def classify_query(message: str) -> str:
    """
    Layer 1: fast rule-based classification.

    Priority order:
      emergency > hard_medical > [diet_signal check] > soft_medical / off_topic > diet

    Hard-medical keywords (medications, lab tests, prescriptions, diagnoses)
    are ALWAYS blocked even when the message also contains food/diet words.
    Soft-medical and off-topic ARE overridden when a diet signal is present.
    """
    if _EMERGENCY_PATTERNS.search(message):
        return _QueryClass.EMERGENCY

    if _HARD_MEDICAL_PATTERNS.search(message):
        return _QueryClass.MEDICAL

    has_diet_signal = bool(_DIET_SIGNALS.search(message))

    if _SOFT_MEDICAL_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet_signal else _QueryClass.MEDICAL

    if _OFFTOPIC_PATTERNS.search(message):
        return _QueryClass.DIET if has_diet_signal else _QueryClass.OFF_TOPIC

    return _QueryClass.DIET


# ─── Embedding helpers ────────────────────────────────────────────────────────

def _dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))

def _norm(a: list[float]) -> float:
    return math.sqrt(sum(x * x for x in a))

def _cosine(a: list[float], b: list[float]) -> float:
    denom = _norm(a) * _norm(b)
    return 0.0 if denom == 0 else _dot(a, b) / denom


# ─── RAG Service ─────────────────────────────────────────────────────────────

class RAGService:
    """Singleton RAG service. Call `initialize()` once at app startup."""

    def __init__(self) -> None:
        self._ready  = False
        self._client: genai.Client | None = None
        self._doc_embeddings: list[list[float]] = []

    # ── Startup ──────────────────────────────────────────────────────────────

    async def initialize(self) -> None:
        """Configure the Gemini client and pre-compute document embeddings."""
        api_key = settings.gemini_api_key
        if not api_key:
            logger.warning("GEMINI_API_KEY not set — chatbot will use fallback responses.")
            return

        self._client = genai.Client(api_key=api_key)
        logger.info("Embedding %d knowledge documents with %s …",
                    len(KNOWLEDGE_DOCS), EMBEDDING_MODEL)

        embeddings: list[list[float]] = []
        for doc in KNOWLEDGE_DOCS:
            text = f"{doc['title']}. {doc['content']}"
            try:
                result = self._client.models.embed_content(
                    model=EMBEDDING_MODEL,
                    contents=text,
                    config=types.EmbedContentConfig(
                        task_type="RETRIEVAL_DOCUMENT",
                    ),
                )
                embeddings.append(result.embeddings[0].values)
            except Exception as exc:
                logger.error("Failed to embed '%s': %s", doc["id"], exc)
                embeddings.append([0.0] * 3072)  # gemini-embedding-001 dim

        self._doc_embeddings = embeddings
        self._ready = True
        logger.info("RAG service ready (%d docs embedded).", len(KNOWLEDGE_DOCS))

    # ── Retrieval ────────────────────────────────────────────────────────────

    def _retrieve(self, query_embedding: list[float]) -> tuple[list[dict], float]:
        """Return (top-k docs, best_score)."""
        scores = [
            (i, _cosine(query_embedding, emb))
            for i, emb in enumerate(self._doc_embeddings)
        ]
        scores.sort(key=lambda x: x[1], reverse=True)
        best_score = scores[0][1] if scores else 0.0
        docs = [KNOWLEDGE_DOCS[i] for i, _ in scores[:TOP_K]]
        return docs, best_score

    # ── User context ─────────────────────────────────────────────────────────

    @staticmethod
    def _build_user_context(
        user_profile: dict[str, Any] | None, pantry_items: list[dict]
    ) -> str:
        if not user_profile:
            return ""
        lines: list[str] = []
        name = user_profile.get("name") or user_profile.get("firstName")
        if name:
            lines.append(f"User's name: {name}")
        conditions = user_profile.get("medicalConditions") or []
        if conditions:
            lines.append(f"Health conditions: {', '.join(conditions)}")
        allergies = user_profile.get("allergies") or []
        if allergies:
            lines.append(f"Food allergies/intolerances: {', '.join(allergies)}")
        diet_type = user_profile.get("dietType") or user_profile.get("myPlanType")
        if diet_type:
            lines.append(f"Assigned diet plan: {diet_type}")
        goals = user_profile.get("healthGoals") or []
        if goals:
            lines.append(f"Health goals: {', '.join(goals)}")
        calories = user_profile.get("targetCalories")
        if calories:
            lines.append(f"Daily calorie target: {calories} kcal")
        if pantry_items:
            items = [p.get("name", "") for p in pantry_items if p.get("name")][:15]
            if items:
                lines.append(f"Current pantry items: {', '.join(items)}")
        return "\n".join(lines)

    # ── Main chat entry point ────────────────────────────────────────────────

    async def chat(
        self,
        message: str,
        history: list[dict[str, str]],
        user_profile: dict[str, Any] | None = None,
        pantry_items: list[dict] | None = None,
    ) -> str:
        """Three-layer guard → RAG generation."""

        # ── Layer 1: keyword pre-filter ──────────────────────────────────────
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
            return (
                "I am having trouble connecting right now. "
                "Please try again in a moment."
            )

        # ── Embed the query ──────────────────────────────────────────────────
        try:
            q_result = self._client.models.embed_content(
                model=EMBEDDING_MODEL,
                contents=message,
                config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
            )
            query_embedding = q_result.embeddings[0].values
        except Exception as exc:
            logger.error("Embedding error: %s", exc)
            return "I am having trouble processing your question. Please try again."

        # ── Layer 2: semantic similarity threshold ───────────────────────────
        relevant_docs, best_score = self._retrieve(query_embedding)
        logger.debug("Best similarity: %.3f (min=%.2f)", best_score, MIN_RELEVANCE)

        if best_score < MIN_RELEVANCE:
            logger.info("Query blocked: LOW_RELEVANCE (score=%.3f)", best_score)
            return _MSG_LOW_RELEVANCE

        # ── Build prompt ─────────────────────────────────────────────────────
        knowledge_context = "\n\n".join(
            f"[{doc['title']} - Source: {doc['source']}]\n{doc['content']}"
            for doc in relevant_docs
        )
        user_context = self._build_user_context(user_profile, pantry_items or [])

        full_system = SYSTEM_PROMPT
        if user_context:
            full_system += f"\n\nUSER PROFILE:\n{user_context}"
        full_system += f"\n\nRELEVANT KNOWLEDGE (use ONLY this):\n{knowledge_context}"

        # ── Layer 3: LLM generation with hardened system prompt ──────────────
        # Convert history list[dict] → list[types.Content]
        history_contents = [
            types.Content(
                role=turn["role"],
                parts=[types.Part(text=p) for p in turn.get("parts", [])],
            )
            for turn in history[-(MAX_HISTORY * 2):]
        ]

        last_exc: Exception | None = None
        for model_name in GENERATION_MODELS:
            try:
                chat_session = self._client.chats.create(
                    model=model_name,
                    config=types.GenerateContentConfig(
                        system_instruction=full_system,
                    ),
                    history=history_contents,
                )
                response = chat_session.send_message(message)
                logger.debug("Generated with model: %s", model_name)
                return response.text.strip()
            except Exception as exc:
                err_str = str(exc)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    logger.warning("Quota hit on %s, trying next model.", model_name)
                    last_exc = exc
                    continue
                # Non-quota error — log and surface immediately
                logger.error("Generation error with %s: %s", model_name, exc)
                return "I ran into a technical issue. Please try again."

        logger.error("All generation models exhausted. Last error: %s", last_exc)
        return (
            "The AI service is currently at capacity. "
            "Please wait a moment and try again."
        )


# ── Module-level singleton ────────────────────────────────────────────────────
rag_service = RAGService()
