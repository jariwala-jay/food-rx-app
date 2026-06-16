"""
conversation_history_service.py — server-side chat history persistence.

Saves every user/model turn to MongoDB so sessions are resumable across
backend restarts and devices.  Anon users are skipped (no user_id to key on).

Collection: ``conversation_messages``
Schema:
  {
    user_id:         str,
    conversation_id: str,
    role:            "user" | "model",
    text:            str,
    created_at:      datetime (UTC),
  }

TTL index (run once on your DB to auto-expire old messages):
  db.conversation_messages.createIndex(
    { created_at: 1 },
    { expireAfterSeconds: 604800 }   # 7 days
  )
"""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Any

logger = logging.getLogger(__name__)

COLL = "conversation_messages"
HISTORY_TTL = timedelta(days=7)
_MAX_LOAD = 12  # max messages returned to RAG (6 user + 6 model turns)


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


async def save_message(
    db: Any,
    user_id: str,
    conversation_id: str,
    role: str,
    text: str,
) -> None:
    """
    Append one message to the conversation history.
    Silently skips anon users, empty text, or DB errors.
    """
    if user_id == "anon" or not (text or "").strip():
        return
    try:
        await db[COLL].insert_one(
            {
                "user_id": user_id,
                "conversation_id": conversation_id,
                "role": role,
                "text": text.strip(),
                "created_at": _now_utc(),
            }
        )
    except Exception as exc:
        logger.debug("save_message skipped: %s", exc)


async def load_history(
    db: Any,
    user_id: str,
    conversation_id: str,
    limit: int = _MAX_LOAD,
) -> list[dict[str, Any]]:
    """
    Return the last ``limit`` messages for this conversation in
    ``{role, parts: [text]}`` format (compatible with rag_service.chat).

    Only messages younger than HISTORY_TTL (7 days) are returned.
    Returns [] for anon users or on any DB error.
    """
    if user_id == "anon":
        return []
    try:
        cutoff = _now_utc() - HISTORY_TTL
        cursor = (
            db[COLL]
            .find(
                {
                    "user_id": user_id,
                    "conversation_id": conversation_id,
                    "created_at": {"$gte": cutoff},
                }
            )
            .sort("created_at", 1)
            .limit(limit)
        )
        docs = await cursor.to_list(length=limit)
        return [{"role": doc["role"], "parts": [doc["text"]]} for doc in docs]
    except Exception as exc:
        logger.debug("load_history skipped: %s", exc)
        return []


async def clear_history(
    db: Any,
    user_id: str,
    conversation_id: str,
) -> None:
    """
    Delete all messages for this conversation (call on handshake reset
    or explicit session close so the next session starts fresh).
    Silently skips anon users or DB errors.
    """
    if user_id == "anon":
        return
    try:
        await db[COLL].delete_many(
            {"user_id": user_id, "conversation_id": conversation_id}
        )
    except Exception as exc:
        logger.debug("clear_history skipped: %s", exc)
