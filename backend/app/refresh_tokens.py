"""Opaque refresh tokens stored hashed in MongoDB (rotation on use)."""

from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from bson import ObjectId

REFRESH_TOKENS = "refreshTokens"
REFRESH_TOKEN_EXPIRE_DAYS = 90
MAX_IDLE_DAYS = 90


def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _parse_iso(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        v = value.strip()
        if v.endswith("Z"):
            v = v[:-1] + "+00:00"
        dt = datetime.fromisoformat(v)
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


async def ensure_refresh_token_indexes(db) -> None:
    coll = db[REFRESH_TOKENS]
    await coll.create_index("tokenHash", unique=True)
    await coll.create_index([("userId", 1), ("revokedAt", 1)])
    await coll.create_index("expiresAt")


async def issue_refresh_token(db, user_id: str) -> str:
    """Create a new refresh token for the user. Returns the raw token (send to client once)."""
    raw = generate_refresh_token()
    now = datetime.now(timezone.utc)
    expires = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    await db[REFRESH_TOKENS].insert_one(
        {
            "userId": user_id,
            "tokenHash": hash_refresh_token(raw),
            "createdAt": _now_iso(),
            "expiresAt": expires.isoformat(),
            "lastUsedAt": _now_iso(),
            "revokedAt": None,
        }
    )
    return raw


async def revoke_refresh_token(db, raw_token: str) -> bool:
    if not raw_token:
        return False
    result = await db[REFRESH_TOKENS].update_one(
        {"tokenHash": hash_refresh_token(raw_token), "revokedAt": None},
        {"$set": {"revokedAt": _now_iso()}},
    )
    return result.modified_count > 0


async def revoke_all_refresh_tokens_for_user(db, user_id: str) -> None:
    await db[REFRESH_TOKENS].update_many(
        {"userId": user_id, "revokedAt": None},
        {"$set": {"revokedAt": _now_iso()}},
    )


async def _user_within_idle_limit(user: dict) -> bool:
    raw = user.get("lastActiveAt") or user.get("lastLoginAt") or user.get("updatedAt")
    last = _parse_iso(raw if isinstance(raw, str) else None)
    if last is None:
        return True
    return datetime.now(timezone.utc) - last <= timedelta(days=MAX_IDLE_DAYS)


async def rotate_refresh_token(db, raw_token: str) -> tuple[str, str, str] | None:
    """
    Validate refresh token, revoke it, issue a new one.
    Returns (user_id, new_raw_refresh) or None if invalid.
    On reuse of a revoked token, revokes all tokens for that user.
    """
    if not raw_token:
        return None

    token_hash = hash_refresh_token(raw_token)
    coll = db[REFRESH_TOKENS]
    doc = await coll.find_one({"tokenHash": token_hash})

    if not doc:
        return None

    user_id = doc.get("userId")
    if not user_id:
        return None

    if doc.get("revokedAt"):
        await revoke_all_refresh_tokens_for_user(db, user_id)
        return None

    expires = _parse_iso(doc.get("expiresAt"))
    if expires is None or datetime.now(timezone.utc) > expires:
        await coll.update_one(
            {"_id": doc["_id"]},
            {"$set": {"revokedAt": _now_iso()}},
        )
        return None

    users = db["users"]
    user = None
    try:
        user = await users.find_one({"_id": ObjectId(user_id)})
    except Exception:
        user = await users.find_one({"_id": user_id})

    if not user:
        return None

    if not await _user_within_idle_limit(user):
        await revoke_all_refresh_tokens_for_user(db, user_id)
        return None

    now = datetime.now(timezone.utc)
    new_expires = now + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    new_raw = generate_refresh_token()

    await coll.update_one(
        {"_id": doc["_id"]},
        {"$set": {"revokedAt": _now_iso(), "lastUsedAt": _now_iso()}},
    )
    await coll.insert_one(
        {
            "userId": user_id,
            "tokenHash": hash_refresh_token(new_raw),
            "createdAt": _now_iso(),
            "expiresAt": new_expires.isoformat(),
            "lastUsedAt": _now_iso(),
            "revokedAt": None,
        }
    )

    return user_id, new_raw
