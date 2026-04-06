"""
RAG service — MyFoodRx chatbot.

Uses the google-genai SDK for Gemini embeddings and generation.
Three-layer guard: keyword pre-filter → similarity threshold → hardened system prompt.
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

EMBEDDING_MODEL = "models/gemini-embedding-001"
EMBEDDING_DIM_FALLBACK = 3072

GENERATION_MODELS = [
    "models/gemini-2.0-flash",
    "models/gemini-2.0-flash-lite",
    "models/gemini-1.5-flash",
    "models/gemini-flash-latest",
]

TOP_K = 4
MAX_HISTORY = 6
MIN_RELEVANCE = 0.42
CHUNK_MAX_CHARS = 1000
CHUNK_OVERLAP_SENTENCES = 1

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

SYSTEM_PROMPT = """You are the MyFoodRx nutrition assistant. Your ONLY job is to answer questions
about food, diet, nutrition, and healthy eating related to the conditions in the user's profile.

STRICT SCOPE — you must ONLY answer questions about:
- Food choices, meal planning, and diet plans (DASH, MyPlate, Diabetes Plate)
- Nutrition concepts (calories, macronutrients, fiber, sodium, sugar, vitamins, minerals)
- Healthy eating habits and cooking methods
- Sleep, exercise, and hydration as they relate to nutrition and health management
- Managing health conditions (diabetes, hypertension, obesity, pre-diabetes) THROUGH DIET ONLY
- Pantry management, grocery shopping, reading nutrition labels
- Food allergies and dietary intolerances
- Hydration and healthy beverages

IF the user asks about ANYTHING outside this scope, respond with exactly:
"I can only help with food and nutrition questions. Please ask me about your diet, meals, or healthy eating."

ABSOLUTE RULES — never break these:
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


class _QueryClass:
    EMERGENCY = "emergency"
    MEDICAL = "medical"
    OFF_TOPIC = "off_topic"
    DIET = "diet"


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


class RAGService:
    """Singleton RAG service. Call initialize() once at app startup via lifespan."""

    def __init__(self) -> None:
        self._ready = False
        self._client: genai.Client | None = None
        self._chunks: list[dict[str, str | int]] = []
        self._chunk_embeddings: list[list[float]] = []

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
        logger.info(
            "Embedding %d chunks from %d docs with %s …",
            len(self._chunks),
            len(KNOWLEDGE_DOCS),
            EMBEDDING_MODEL,
        )

        embeddings: list[list[float]] = []
        for chunk in self._chunks:
            text = f"{chunk['title']}. {chunk['text']}"
            try:
                result = self._client.models.embed_content(
                    model=EMBEDDING_MODEL,
                    contents=text,
                    config=types.EmbedContentConfig(task_type="RETRIEVAL_DOCUMENT"),
                )
                emb_list = result.embeddings or []
                values = emb_list[0].values if emb_list else None
                if values:
                    embeddings.append(list(values))
                else:
                    logger.error(
                        "No embedding values for chunk '%s[%s]'",
                        chunk.get("doc_id"),
                        chunk.get("chunk_index"),
                    )
                    embeddings.append([0.0] * EMBEDDING_DIM_FALLBACK)
            except Exception as exc:
                logger.error(
                    "Failed to embed chunk '%s[%s]': %s",
                    chunk.get("doc_id"),
                    chunk.get("chunk_index"),
                    exc,
                )
                embeddings.append([0.0] * EMBEDDING_DIM_FALLBACK)

        self._chunk_embeddings = embeddings
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

        if not self._ready or self._client is None:
            return "I am having trouble connecting right now. Please try again in a moment."

        try:
            q_result = self._client.models.embed_content(
                model=EMBEDDING_MODEL,
                contents=message,
                config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
            )
            q_emb = q_result.embeddings or []
            query_embedding = q_emb[0].values if q_emb else None
            if not query_embedding:
                logger.error("Query embedding returned no values")
                return "I am having trouble processing your question. Please try again."
            query_embedding = list(query_embedding)
        except Exception as exc:
            logger.error("Embedding error: %s", exc)
            return "I am having trouble processing your question. Please try again."

        relevant_docs, best_score = self._retrieve(query_embedding)
        logger.debug("Best similarity: %.3f (min=%.2f)", best_score, MIN_RELEVANCE)
        if best_score < MIN_RELEVANCE:
            logger.info("Query blocked: LOW_RELEVANCE (score=%.3f)", best_score)
            return _MSG_LOW_RELEVANCE

        knowledge_context = "\n\n".join(
            f"[{chunk['title']} — {chunk['category']} — Source: {chunk['source']}]\n"
            f"{chunk['text']}"
            for chunk in relevant_docs
        )

        user_context = self._build_user_context(user_profile, pantry_items or [])

        full_system = SYSTEM_PROMPT
        if user_context:
            full_system += f"\n\nUSER PROFILE:\n{user_context}"
        full_system += f"\n\nRELEVANT KNOWLEDGE (use ONLY this):\n{knowledge_context}"

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
                out = (response.text or "").strip()
                if not out:
                    logger.error("Empty generation from %s", model_name)
                    return "I ran into a technical issue. Please try again."
                logger.debug("Generated with model: %s", model_name)
                return out
            except Exception as exc:
                err_str = str(exc)
                if "429" in err_str or "RESOURCE_EXHAUSTED" in err_str:
                    logger.warning("Quota hit on %s, trying next model.", model_name)
                    last_exc = exc
                    continue
                logger.error("Generation error with %s: %s", model_name, exc)
                return "I ran into a technical issue. Please try again."

        logger.error("All generation models exhausted. Last error: %s", last_exc)
        return "The AI service is currently at capacity. Please wait a moment and try again."


rag_service = RAGService()
