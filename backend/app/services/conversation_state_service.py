from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from app.database import get_database

COLL = "conversation_state"
STATE_TTL = timedelta(hours=24)


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _default_state(user_id: str, conversation_id: str) -> dict[str, Any]:
    return {
        "user_id": user_id,
        "conversation_id": conversation_id,
        "stage": "free_chat",
        "selected_topic": "",
        "step": 0,
        "answers": {},
        "updated_at": _now_utc(),
    }


def _state_filter(user_id: str, conversation_id: str) -> dict[str, Any]:
    # Backward compatibility: support older docs that used `session_id`.
    return {
        "user_id": user_id,
        "$or": [
            {"conversation_id": conversation_id},
            {"session_id": conversation_id},
        ],
    }


async def get_state(user_id: str, conversation_id: str) -> dict[str, Any]:
    """Fetch state, auto-resetting stale records to a safe default."""
    db = await get_database()
    doc = await db[COLL].find_one(_state_filter(user_id, conversation_id))
    if not doc:
        return _default_state(user_id, conversation_id)

    updated_at = doc.get("updated_at")
    if isinstance(updated_at, datetime):
        # Handle both naive and timezone-aware datetimes from Mongo.
        ts = updated_at if updated_at.tzinfo else updated_at.replace(tzinfo=timezone.utc)
        if _now_utc() - ts > STATE_TTL:
            await reset_state(user_id, conversation_id)
            return _default_state(user_id, conversation_id)

    return {
        "user_id": user_id,
        "conversation_id": str(
            doc.get("conversation_id") or doc.get("session_id") or conversation_id
        ),
        "stage": str(doc.get("stage") or "free_chat"),
        "selected_topic": str(doc.get("selected_topic") or ""),
        "step": int(doc.get("step") or 0),
        "answers": doc.get("answers") if isinstance(doc.get("answers"), dict) else {},
        "updated_at": doc.get("updated_at") or _now_utc(),
    }


async def update_state(user_id: str, conversation_id: str, updates: dict[str, Any]) -> None:
    db = await get_database()
    payload = dict(updates)
    payload["conversation_id"] = conversation_id
    payload["updated_at"] = _now_utc()
    await db[COLL].update_one(
        _state_filter(user_id, conversation_id),
        {"$set": payload, "$setOnInsert": {"user_id": user_id, "conversation_id": conversation_id}},
        upsert=True,
    )


async def reset_state(user_id: str, conversation_id: str) -> None:
    db = await get_database()
    await db[COLL].delete_one(_state_filter(user_id, conversation_id))
