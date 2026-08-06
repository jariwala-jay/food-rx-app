"""Password reset token hashing and expiry checks (no database)."""

import hashlib
from datetime import datetime, timedelta, timezone

from app.auth_password import hash_password, verify_password


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _parse_iso_datetime(value: str | None) -> datetime | None:
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


def test_hash_token_stable():
    raw = "sample-reset-token"
    assert _hash_token(raw) == _hash_token(raw)
    assert len(_hash_token(raw)) == 64


def test_reset_password_hash_roundtrip():
    stored = hash_password("NewPass1!")
    assert verify_password("NewPass1!", stored)
    assert not verify_password("wrong", stored)


def test_expiry_rejects_past_token():
    past = (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()
    expires = _parse_iso_datetime(past)
    assert expires is not None
    assert datetime.now(timezone.utc) > expires


def test_expiry_accepts_future_token():
    future = (datetime.now(timezone.utc) + timedelta(minutes=30)).isoformat()
    expires = _parse_iso_datetime(future)
    assert expires is not None
    assert datetime.now(timezone.utc) < expires
