"""
Regression tests for the bcrypt migration (finding #5 in the 2026-08 audit:
password hashing was HMAC-SHA256, not bcrypt/argon2). Covers both the
hashing primitives directly (app.auth_password) and the transparent
re-hash-on-login behavior in POST /auth/login, which upgrades an account off
the legacy scheme the next time its owner signs in successfully — no forced
password reset.

Run:
    cd backend && python3 -m unittest tests.test_password_hash_migration -v
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.auth_password import hash_password, needs_rehash, verify_password  # noqa: E402
from app.rate_limit import limiter  # noqa: E402
from app.routers import auth as auth_router  # noqa: E402

app = FastAPI()
app.state.limiter = limiter
app.include_router(auth_router.router)

USER_ID = ObjectId("507f1f77bcf86cd799439011")
EMAIL = "legacy.user@example.com"
PASSWORD = "OldPass1!"


def _legacy_hmac_hash(password: str) -> str:
    """Reimplements the pre-migration HMAC-SHA256 scheme directly, so this
    test doesn't depend on hash_password() still being able to produce it."""
    salt = secrets.token_bytes(32)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    digest = hmac.new(password.encode("utf-8"), salt, hashlib.sha256).hexdigest()
    return f"{salt_b64}:{digest}"


class _FakeCollection:
    def __init__(self, docs: list[dict]) -> None:
        self.docs = docs

    async def find_one(self, query: dict) -> dict | None:
        for doc in self.docs:
            if all(doc.get(k) == v for k, v in query.items()):
                return doc
        return None

    async def update_one(self, query: dict, update: dict) -> None:
        for doc in self.docs:
            if all(doc.get(k) == v for k, v in query.items()):
                if "$set" in update:
                    doc.update(update["$set"])
                if "$inc" in update:
                    for k, v in update["$inc"].items():
                        doc[k] = doc.get(k, 0) + v


class _FakeDB:
    def __init__(self, users: list[dict]) -> None:
        self._collections = {"users": _FakeCollection(users)}

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection([])
        return self._collections[name]


class TestHashingPrimitives(unittest.TestCase):
    def test_new_hashes_are_bcrypt_not_legacy(self) -> None:
        stored = hash_password(PASSWORD)
        self.assertTrue(stored.startswith(("$2a$", "$2b$", "$2y$")))
        self.assertFalse(needs_rehash(stored))

    def test_bcrypt_hash_roundtrip(self) -> None:
        stored = hash_password(PASSWORD)
        self.assertTrue(verify_password(PASSWORD, stored))
        self.assertFalse(verify_password("wrong-password", stored))

    def test_legacy_hmac_hash_still_verifies_and_flagged_for_rehash(self) -> None:
        stored = _legacy_hmac_hash(PASSWORD)
        self.assertTrue(needs_rehash(stored))
        self.assertTrue(verify_password(PASSWORD, stored))
        self.assertFalse(verify_password("wrong-password", stored))


class TestTransparentRehashOnLogin(unittest.TestCase):
    def setUp(self) -> None:
        limiter.reset()

    def test_successful_login_upgrades_legacy_hash_to_bcrypt(self) -> None:
        legacy_hash = _legacy_hmac_hash(PASSWORD)
        user = {
            "_id": USER_ID,
            "email": EMAIL,
            "password": legacy_hash,
            "failedLoginAttempts": 0,
            "isLocked": False,
            "lockUntil": None,
        }
        db = _FakeDB([user])

        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
                patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"):
            with TestClient(app) as client:
                resp = client.post("/auth/login", json={"email": EMAIL, "password": PASSWORD})
                self.assertEqual(resp.status_code, 200, resp.text)

        stored_now = db["users"].docs[0]["password"]
        self.assertNotEqual(stored_now, legacy_hash)
        self.assertFalse(needs_rehash(stored_now))
        self.assertTrue(verify_password(PASSWORD, stored_now))

    def test_failed_login_does_not_touch_legacy_hash(self) -> None:
        legacy_hash = _legacy_hmac_hash(PASSWORD)
        user = {
            "_id": USER_ID,
            "email": EMAIL,
            "password": legacy_hash,
            "failedLoginAttempts": 0,
            "isLocked": False,
            "lockUntil": None,
        }
        db = _FakeDB([user])

        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
                patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"):
            with TestClient(app) as client:
                resp = client.post("/auth/login", json={"email": EMAIL, "password": "wrong-password"})
                self.assertEqual(resp.status_code, 401)

        self.assertEqual(db["users"].docs[0]["password"], legacy_hash)


if __name__ == "__main__":
    unittest.main()
