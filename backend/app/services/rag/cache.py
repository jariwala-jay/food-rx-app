"""
rag/cache.py — RAG response cache (exact + embedding-similarity lookups),
cache-key helpers, plan response helpers, and chunk-prioritization helpers.
"""

from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from typing import Any

from app.services.rag.chunker import _cosine
from app.services.rag.constants import (
    PLAN_INFO,
    RAG_CACHE_COLLECTION,
    RAG_CACHE_EMBED_SCAN_LIMIT,
    RAG_CACHE_EMBED_THRESHOLD,
    RAG_CACHE_VERSION,
    _PLAN_QUERY_HINTS,
)
from app.services.rag.profile_helpers import _resolve_plan_for_profile

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Cache-key helpers
# ---------------------------------------------------------------------------


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


def _cache_user_key(user_id: str | None) -> str:
    return (user_id or "").strip() or "anon"


def _cache_plan_key(user_profile: dict[str, Any] | None) -> str:
    return _resolve_plan_for_profile(user_profile) or "MyPlate"


# ---------------------------------------------------------------------------
# Plan query / response helpers
# ---------------------------------------------------------------------------


def _is_plan_query(message: str) -> bool:
    q = _normalize_query_for_cache(message)
    return any(hint in q for hint in _PLAN_QUERY_HINTS)


def _build_plan_response(plan: str | None) -> str:
    info = PLAN_INFO.get(plan or "")
    if not info:
        return ""
    return f"{info['definition']}\n\n{info['portion']}\n\n{info['why']}"


# ---------------------------------------------------------------------------
# Chunk-prioritization helpers
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# Fallback response
# ---------------------------------------------------------------------------


def _safe_rag_fallback_response() -> str:
    return "I'm having trouble responding right now. Please wait a moment and try again."


# ---------------------------------------------------------------------------
# Semantic cache safety guard
# ---------------------------------------------------------------------------


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
        "what", "which", "when", "where", "why", "how", "can", "could",
        "should", "would", "please", "tell", "about", "for", "with",
        "my", "me", "i", "to", "the", "a", "an", "is", "are", "of", "in", "on",
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
    Must match chatbot._detect_suggestion_intent ordering
    (exercise → meal_plan → tips → foods → general).
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


# ---------------------------------------------------------------------------
# Async cache I/O
# ---------------------------------------------------------------------------


async def _rag_cache_get_exact(
    query_norm: str, condition_key: str, user_key: str, plan_key: str
) -> str | None:
    from app.database import get_database  # deferred to avoid circular imports at startup
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


async def _rag_cache_get_similar_embedding(
    query_embedding: list[float],
    condition_key: str,
    user_key: str,
    plan_key: str,
    query: str,
    intent_key: str,
) -> str | None:
    from app.database import get_database  # deferred to avoid circular imports at startup
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
    model_used: str | None = None,
) -> None:
    from app.database import get_database  # deferred to avoid circular imports at startup
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
                "model_used": model_used or "unknown",
                "created_at": datetime.now(timezone.utc),
            }
        )
    except Exception as exc:
        logger.warning("RAG response cache write failed: %s", exc)
