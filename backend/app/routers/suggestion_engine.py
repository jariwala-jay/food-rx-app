"""
suggestion_engine.py — follow-up chip generation for the chatbot.

Contains:
  - _seen_follow_up_questions  (in-memory rotation state)
  - _pick_follow_ups_with_rotation()
  - _ordered_condition_candidates()
  - _generate_suggestions()     ← main entry point called by chatbot.py
  - Profile condition helpers: _all_conditions, _primary_condition_multi,
    _all_conditions, _rag_category_label, _is_generic_meal_scope_query

Imports from question_banks (data) and rag_service (query classification).
No FastAPI, no DB, no I/O.
"""

from __future__ import annotations

import logging
import re
from datetime import datetime, timezone
from typing import Any

logger = logging.getLogger(__name__)

from app.routers.question_banks import (
    COMBINATION_PAIR_PRIORITY,
    COMBINATION_QUESTION_BANK,
    QUESTION_BANK,
)
from app.services.rag_service import (
    _infer_kb_categories,
    _is_followup_query,
    _resolve_plan_for_profile,
    should_suggest_follow_ups,
)

# Session rotation state, in-memory per (user_id, conversation_id); resets on restart.

_seen_follow_up_questions: dict[tuple[str, str], set[str]] = {}


_CHIP_ROTATION_COLLECTION = "chip_rotation"
# TTL: documents older than this (seconds) are auto-deleted by MongoDB.
_CHIP_ROTATION_TTL_SECONDS = 86_400  # 24 hours


def clear_suggestion_memory(user_id: str, conversation_id: str) -> None:
    """Remove rotation state from in-memory store (call on session reset or close)."""
    _seen_follow_up_questions.pop((user_id, conversation_id), None)


async def clear_suggestion_memory_db(
    db: Any, user_id: str, conversation_id: str
) -> None:
    """Remove rotation state from both memory and MongoDB."""
    clear_suggestion_memory(user_id, conversation_id)
    try:
        await db[_CHIP_ROTATION_COLLECTION].delete_one(
            {"user_id": user_id, "conversation_id": conversation_id}
        )
    except Exception as exc:
        logger.warning("chip_rotation delete failed — stale rotation may persist: %s", exc)


# ---------------------------------------------------------------------------
# Candidate ordering + rotation
# ---------------------------------------------------------------------------


def _ordered_condition_candidates(
    bucket: dict[str, list[str]], question_type: str
) -> list[str]:
    """
    Return all questions in a QUESTION_BANK bucket, with the requested
    question_type sub-bucket first for relevance, then the rest.
    """
    order: list[str] = []
    seen: set[str] = set()
    preferred = bucket.get(question_type)
    if preferred:
        for q in preferred:
            t = (q or "").strip()
            if t and t not in seen:
                seen.add(t)
                order.append(t)
    for key, lst in bucket.items():
        if key == question_type:
            continue
        for q in lst:
            t = (q or "").strip()
            if t and t not in seen:
                seen.add(t)
                order.append(t)
    return order


def _pick_follow_ups_with_rotation(
    session_key: tuple[str, str],
    candidates: list[str],
    k: int = 2,
) -> list[str]:
    """
    Pick k follow-up questions, preferring ones not yet shown this session.
    Resets rotation memory when the pool is exhausted so chips cycle again.
    """
    if k <= 0:
        return []

    # Deduplicate while preserving order.
    deduped: list[str] = []
    dup: set[str] = set()
    for q in candidates:
        t = (q or "").strip()
        if not t or t in dup:
            continue
        dup.add(t)
        deduped.append(t)
    if not deduped:
        return []

    seen = _seen_follow_up_questions.setdefault(session_key, set())
    available = [q for q in deduped if q not in seen]
    if len(available) < k:
        seen.clear()
        available = list(deduped)

    out = available[:k]
    seen.update(out)
    return out


# ---------------------------------------------------------------------------
# Profile condition helpers
# ---------------------------------------------------------------------------


def _all_conditions(user_profile: dict[str, Any] | None) -> list[str]:
    """
    Normalise profile conditions to canonical lowercase keys used in
    QUESTION_BANK: 'diabetes', 'hypertension', 'obesity'.
    """
    if not isinstance(user_profile, dict):
        return []

    raw = user_profile.get("conditions") or user_profile.get("medicalConditions") or []
    if isinstance(raw, str):
        raw = [raw]

    out: set[str] = set()
    for condition in raw:
        text = str(condition).lower()
        if "prediabetes" in text:
            out.add("diabetes")
        elif "diabetes" in text:
            out.add("diabetes")
        elif "hypertension" in text or "blood pressure" in text:
            out.add("hypertension")
        elif "obesity" in text or "overweight" in text:
            out.add("obesity")

    return sorted(out)


def _has_prediabetes_only(user_profile: dict[str, Any] | None) -> bool:
    """
    True when the user has prediabetes but NOT full diabetes.
    Used to route to the softer prediabetes+hypertension chip bank instead
    of the full-diabetes+hypertension bank that references the Diabetes Plate.
    """
    if not isinstance(user_profile, dict):
        return False
    raw = user_profile.get("conditions") or user_profile.get("medicalConditions") or []
    if isinstance(raw, str):
        raw = [raw]
    norm = [str(c).lower() for c in raw]
    has_prediabetes = any("prediabetes" in c or "pre-diabetes" in c for c in norm)
    has_full_diabetes = any(
        "diabetes" in c and "prediabetes" not in c and "pre-diabetes" not in c
        for c in norm
    )
    return has_prediabetes and not has_full_diabetes


def _primary_condition_multi(conditions: list[str]) -> str | None:
    """Return the highest-priority single condition for fallback chip selection."""
    if "diabetes" in conditions:
        return "diabetes"
    if "hypertension" in conditions:
        return "hypertension"
    if "obesity" in conditions:
        return "obesity"
    return None


def _normalized_plan_key(user_profile: dict[str, Any] | None) -> str | None:
    """
    Resolve the user's assigned plan to a QUESTION_BANK key.

    Prediabetes-only users get 'PreDiabetes' so they see prevention-framed
    chips rather than the full Diabetes Plate management bank.
    """
    if not isinstance(user_profile, dict):
        return None

    raw = user_profile.get("conditions") or user_profile.get("medicalConditions") or []
    if isinstance(raw, str):
        raw = [raw]
    norm = [str(c).lower() for c in raw]
    has_prediabetes = any("prediabetes" in c or "pre-diabetes" in c for c in norm)
    has_full_diabetes = any(
        "diabetes" in c and "prediabetes" not in c and "pre-diabetes" not in c
        for c in norm
    )
    if has_prediabetes and not has_full_diabetes:
        return "PreDiabetes"

    return _resolve_plan_for_profile(user_profile)


# ---------------------------------------------------------------------------
# Query topic classification
# ---------------------------------------------------------------------------


def _rag_category_label(query: str) -> str | None:
    """
    Map a user query to a QUESTION_BANK top-level key using KB category
    inference from rag_service. Returns None when no category matches.
    """
    cats = _infer_kb_categories(query)
    if not cats:
        return None
    if "exercise" in cats:
        return "exercise"
    if "sleep" in cats:
        return "sleep"
    if "hydration" in cats:
        return "hydration"
    if "diabetes" in cats or "pre-diabetes" in cats:
        return "diabetes"
    if "hypertension" in cats:
        return "hypertension"
    if "obesity" in cats:
        return "obesity"
    return None


_GENERIC_MEAL_TOPIC_HINT = re.compile(
    r"\b("
    r"glycemic|glucose|insulin|blood\s*sugar|diabetes|prediabetes|a1c|hba1c|"
    r"sodium|salt|blood\s*pressure|hypertension|\bdash\b|"
    r"sleep|insomnia|hydrat|exercise|workout|activity|weight|calorie|\bbmi\b|"
    r"heart|kidney|plate method|diabetes plate"
    r")\b",
    re.IGNORECASE,
)


def _is_generic_meal_scope_query(query: str) -> bool:
    """
    True for short "what should I eat?" style prompts with no specific health
    topic. Used to decide whether plan-based chips take priority over category chips.
    """
    q = (query or "").strip()
    if len(q) > 120:
        return False
    if _GENERIC_MEAL_TOPIC_HINT.search(q):
        return False
    return bool(
        re.match(
            r"^\s*(what|which|how)\s+(should|can|could|do|may)\s+(i|we)\s+(eat|have)\b",
            q,
            re.IGNORECASE,
        )
    )


# ---------------------------------------------------------------------------
# Special-case follow-ups
# ---------------------------------------------------------------------------


def _normalize_followup_trigger_query(message: str) -> str:
    """Lowercase, single-spaced, trailing-punctuation-stripped (for exact chip matching)."""
    q = " ".join((message or "").strip().lower().split())
    return q.rstrip("?.!")


def _followups_after_steady_blood_sugar_foods_question(query: str) -> list[str] | None:
    """
    When the user taps the diabetes starter chip asking which foods steady
    blood sugar, pin the next two chips to snacks + adjacent food follow-up.
    """
    if (
        _normalize_followup_trigger_query(query)
        == "what foods help keep my blood sugar steady"
    ):
        return [
            "What snacks are good for managing my blood sugar?",
            "What meals are good for blood sugar control?",
        ]
    return None


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------



# Lifestyle and follow-up categories that should bypass the combination bank.
# When a user with 2+ conditions asks about sleep, exercise, hydration, or sends
# a follow-up ("tell me more"), show topic-relevant chips — not food combination chips.
_BYPASS_COMBINATION_BANK: frozenset[str] = frozenset(
    {"sleep", "exercise", "hydration"}
)


def _generate_suggestions(
    query: str,
    response: str,
    user_profile: dict[str, Any] | None,
    user_id: str,
    conversation_id: str,
) -> list[str]:
    """
    Return 2 follow-up question chips for display after an assistant turn.

    Priority order:
      1. Pinned special-case (e.g. blood-sugar foods starter chip)
      2. Multi-condition combination bank  (skipped for lifestyle/follow-up queries)
      3. Query/response topic category (QUESTION_BANK category key)
      4. Assigned diet plan (QUESTION_BANK plan key)
      5. Primary condition
      6. General fallback
    """
    if not should_suggest_follow_ups(response):
        return []

    session_key = (user_id, conversation_id)

    # 1. Pinned special-case.
    steady_pair = _followups_after_steady_blood_sugar_foods_question(query)
    if steady_pair is not None:
        seen = _seen_follow_up_questions.setdefault(session_key, set())
        seen.update(steady_pair)
        return steady_pair

    conditions = _all_conditions(user_profile)
    primary = _primary_condition_multi(conditions)
    # Resolve category early — needed to decide whether to bypass the combination bank.
    category = _rag_category_label(query)
    category_from_response = False
    plan = _normalized_plan_key(user_profile)
    response_lower = (response or "").lower()
    is_followup = _is_followup_query(query)

    # 2. Multi-condition combination bank.
    # Bypass when the query is about a lifestyle topic (sleep/exercise/hydration)
    # or is a vague follow-up ("tell me more") — those deserve topic-specific chips.
    use_combination_bank = (
        len(conditions) >= 2
        and category not in _BYPASS_COMBINATION_BANK
        and not is_followup
    )
    if use_combination_bank:
        # Check triple-condition bank first when all three are present.
        if len(conditions) == 3:
            triple_key = tuple(sorted(conditions))
            triple_questions = COMBINATION_QUESTION_BANK.get(triple_key)
            if triple_questions:
                return _pick_follow_ups_with_rotation(
                    session_key, list(triple_questions), 2
                )
        # Prediabetes + hypertension: use prevention-framed bank before the
        # full-diabetes+hypertension bank (which mentions the Diabetes Plate).
        if "hypertension" in conditions and _has_prediabetes_only(user_profile):
            prediab_htn = COMBINATION_QUESTION_BANK.get(("hypertension", "prediabetes"))
            if prediab_htn:
                return _pick_follow_ups_with_rotation(session_key, list(prediab_htn), 2)
        # Fall through to best-matching pair.
        for combo_key in COMBINATION_PAIR_PRIORITY:
            questions = COMBINATION_QUESTION_BANK.get(combo_key)
            if questions and all(c in conditions for c in combo_key):
                return _pick_follow_ups_with_rotation(session_key, list(questions), 2)

    # 3. Infer topic from response text when the query had no clear topic.
    question_type = "food"
    if category is None:
        if any(k in response_lower for k in ["exercise", "walk", "activity"]):
            question_type = "general"
            category = "exercise"
            category_from_response = True
        elif "sleep" in response_lower:
            question_type = "general"
            category = "sleep"
            category_from_response = True
        elif any(k in response_lower for k in ["water", "hydration"]):
            question_type = "general"
            category = "hydration"
            category_from_response = True

    # 4. Category / query intent (chips should match what the user just asked).
    use_query_category = (
        category is not None
        and category in QUESTION_BANK
        and (
            category_from_response
            or not plan
            or not _is_generic_meal_scope_query(query)
        )
    )
    if use_query_category:
        bucket = QUESTION_BANK[category]
        candidates = _ordered_condition_candidates(bucket, question_type)
        return _pick_follow_ups_with_rotation(session_key, candidates, 2)

    # 5. Plan-based chips for generic meal queries.
    if plan and plan in QUESTION_BANK:
        bucket = QUESTION_BANK[plan]
        candidates = _ordered_condition_candidates(bucket, question_type)
        return _pick_follow_ups_with_rotation(session_key, candidates, 2)

    # 6. Condition-based fallback.
    if primary and primary in QUESTION_BANK:
        bucket = QUESTION_BANK[primary]
        candidates = _ordered_condition_candidates(bucket, question_type)
        return _pick_follow_ups_with_rotation(session_key, candidates, 2)

    # 7. General fallback.
    return _pick_follow_ups_with_rotation(
        session_key,
        list(QUESTION_BANK["general"]["general"]),
        2,
    )


# ---------------------------------------------------------------------------
# Async entry point — persists chip rotation to MongoDB
# ---------------------------------------------------------------------------


async def generate_followup_chips(
    db: Any,
    query: str,
    response: str,
    user_profile: dict[str, Any] | None,
    user_id: str,
    conversation_id: str,
) -> list[str]:
    """
    Async wrapper around _generate_suggestions that loads and saves chip
    rotation state to MongoDB so it survives server restarts.

    Falls back silently to in-memory rotation if MongoDB is unavailable.
    """
    session_key = (user_id, conversation_id)

    # Load persisted seen-chips into in-memory dict before generating.
    try:
        doc = await db[_CHIP_ROTATION_COLLECTION].find_one(
            {"user_id": user_id, "conversation_id": conversation_id}
        )
        if doc and doc.get("seen_chips"):
            _seen_follow_up_questions[session_key] = set(doc["seen_chips"])
    except Exception as exc:
        logger.warning("chip_rotation load failed — using in-memory rotation: %s", exc)

    chips = _generate_suggestions(
        query=query,
        response=response,
        user_profile=user_profile,
        user_id=user_id,
        conversation_id=conversation_id,
    )

    # Persist updated seen set back to MongoDB.
    try:
        seen = list(_seen_follow_up_questions.get(session_key, set()))
        await db[_CHIP_ROTATION_COLLECTION].update_one(
            {"user_id": user_id, "conversation_id": conversation_id},
            {
                "$set": {
                    "seen_chips": seen,
                    "updated_at": datetime.now(timezone.utc),
                }
            },
            upsert=True,
        )
    except Exception as exc:
        logger.warning("chip_rotation save failed — rotation state not persisted: %s", exc)

    return chips
