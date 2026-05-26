"""Unit tests for refresh token helpers (no database required)."""

from app.refresh_tokens import (
    REFRESH_TOKEN_EXPIRE_DAYS,
    generate_refresh_token,
    hash_refresh_token,
)


def test_hash_refresh_token_deterministic():
    raw = "test-token-value"
    assert hash_refresh_token(raw) == hash_refresh_token(raw)
    assert hash_refresh_token(raw) != hash_refresh_token("other")


def test_generate_refresh_token_unique():
    a = generate_refresh_token()
    b = generate_refresh_token()
    assert a != b
    assert len(a) >= 32


def test_refresh_expire_days_sane():
    assert REFRESH_TOKEN_EXPIRE_DAYS >= 30
