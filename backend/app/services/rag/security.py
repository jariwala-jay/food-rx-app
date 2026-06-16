"""
rag/security.py — rate limiting, injection detection, and audit logging.
"""

from __future__ import annotations

import logging
import time
from datetime import datetime, timezone
from typing import Any

from app.services.rag.constants import (
    _EMBEDDED_INSTRUCTION_PATTERNS,
    _FOOD_DRUG_INTERACTION,
    _HARD_MEDICAL_PATTERNS,
    _INJECTION_PATTERNS,
    _MEDICATION_ACTION_TERMS,
    _MEDICATION_DECISION_CUES,
    RATE_LIMIT_MAX_MESSAGES,
    RATE_LIMIT_WINDOW_SECONDS,
    SECURITY_EVENTS_COLLECTION,
    _user_message_timestamps,
)

logger = logging.getLogger(__name__)


def _looks_like_food_drug_interaction_query(message: str) -> bool:
    text = (message or "").strip()
    if not text:
        return False
    return bool(_FOOD_DRUG_INTERACTION.search(text))


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


def _contains_embedded_instructions(message: str) -> bool:
    text = (message or "").strip()
    if not text:
        return False
    return bool(_EMBEDDED_INSTRUCTION_PATTERNS.search(text))


def _log_rag_audit(audit: dict[str, Any]) -> None:
    score = audit.get("score")
    score_str = f"{score:.3f}" if isinstance(score, (int, float)) else "none"
    logger.info(
        "RAG_AUDIT query_class=%s plan=%s condition=%s score=%s cached=%s blocked=%s chars=%d",
        audit.get("query_class", "unknown"),
        audit.get("plan", "unknown"),
        audit.get("condition", "unknown"),
        score_str,
        audit.get("cache", "none"),
        audit.get("blocked") or "none",
        int(audit.get("chars") or 0),
    )


def _is_rate_limited(user_id: str) -> bool:
    """Return True if user_id exceeded RATE_LIMIT_MAX_MESSAGES in the sliding window."""
    now = time.time()
    window_start = now - RATE_LIMIT_WINDOW_SECONDS
    timestamps = _user_message_timestamps.get(user_id, [])
    timestamps = [t for t in timestamps if t > window_start]
    if len(timestamps) >= RATE_LIMIT_MAX_MESSAGES:
        _user_message_timestamps[user_id] = timestamps
        return True
    timestamps.append(now)
    _user_message_timestamps[user_id] = timestamps
    return False


async def _log_security_event(
    event_type: str,
    message: str,
    user_id: str | None,
) -> None:
    from app.database import get_database  # deferred to avoid circular imports at startup
    try:
        db = await get_database()
        await db[SECURITY_EVENTS_COLLECTION].insert_one(
            {
                "event_type": event_type,
                "message_preview": (message or "")[:200],
                "user_id": user_id or "anon",
                "timestamp": datetime.now(timezone.utc),
            }
        )
    except Exception as exc:
        logger.warning("Failed to log security event (%s): %s", event_type, exc)
