"""
End-to-end API contract tests for /auth/forgot-password and
/auth/reset-password: the Google-only-account edge case (a Google-linked
account must never receive a reset token or have its password changed
through the unauthenticated forgot-password flow), and the same-password
hygiene check (resetting to your current password is rejected without
consuming the token).

Uses FastAPI TestClient with a mocked in-memory MongoDB — no live database
or SMTP credentials required (email sending is mocked).

Run:
    cd backend && python3 -m unittest tests.test_forgot_reset_password_endpoints -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import AsyncMock, patch
from urllib.parse import parse_qs, unquote, urlparse

from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.auth_password import hash_password  # noqa: E402
from app.routers import auth as auth_router  # noqa: E402

# Minimal app around just auth.router, not app.main.app: app.main pulls in
# chromadb via the chatbot router, which these tests don't need and isn't
# always installed. Also means no app.main lifespan hooks to patch.
app = FastAPI()
app.include_router(auth_router.router)

PASSWORD_USER_ID = ObjectId("507f1f77bcf86cd799439011")
GOOGLE_USER_ID = ObjectId("507f1f77bcf86cd799439022")
PASSWORD_USER_EMAIL = "password.user@example.com"
GOOGLE_USER_EMAIL = "google.user@example.com"
UNKNOWN_EMAIL = "nobody@example.com"
OLD_PASSWORD = "OldPass1!"
NEW_PASSWORD = "NewPass1!"


def _password_user() -> dict:
    return {
        "_id": PASSWORD_USER_ID,
        "email": PASSWORD_USER_EMAIL,
        "password": hash_password(OLD_PASSWORD),
        "name": "Pat Password",
        "failedLoginAttempts": 0,
        "isLocked": False,
        "lockUntil": None,
    }


def _google_user() -> dict:
    return {
        "_id": GOOGLE_USER_ID,
        "email": GOOGLE_USER_EMAIL,
        "authProvider": "google",
        "name": "Gerry Google",
        "failedLoginAttempts": 0,
        "isLocked": False,
        "lockUntil": None,
    }


class _FakeCursor:
    def __init__(self, docs: list[dict]) -> None:
        self._docs = docs

    async def to_list(self, length: int | None = None) -> list[dict]:
        return self._docs if length is None else self._docs[:length]


class _FakeCollection:
    """Minimal in-memory Mongo collection covering exactly the operations
    auth.py's forgot-password/reset-password/login handlers use."""

    def __init__(self) -> None:
        self.docs: list[dict] = []

    @staticmethod
    def _match(doc: dict, query: dict) -> bool:
        for key, expected in query.items():
            if isinstance(expected, dict):
                # Operator queries (e.g. createdAt: {"$gte": ...}) — the
                # store starts empty for every test here, so treating these
                # as always-matching never changes an assertion.
                continue
            if doc.get(key) != expected:
                return False
        return True

    @staticmethod
    def _apply_update(doc: dict, update: dict) -> None:
        if "$set" in update:
            doc.update(update["$set"])
        if "$unset" in update:
            for k in update["$unset"]:
                doc.pop(k, None)
        if "$inc" in update:
            for k, v in update["$inc"].items():
                doc[k] = doc.get(k, 0) + v

    async def find_one(self, query: dict) -> dict | None:
        for doc in self.docs:
            if self._match(doc, query):
                return doc
        return None

    def find(self, query: dict, sort: list[tuple[str, int]] | None = None) -> _FakeCursor:
        matched = [doc for doc in self.docs if self._match(doc, query)]
        if sort:
            for key, direction in reversed(sort):
                matched.sort(key=lambda d: d.get(key), reverse=(direction < 0))
        return _FakeCursor(matched)

    async def insert_one(self, doc: dict):
        self.docs.append(doc)
        return type("Result", (), {"inserted_id": doc.get("_id")})()

    async def update_one(self, query: dict, update: dict) -> None:
        for doc in self.docs:
            if self._match(doc, query):
                self._apply_update(doc, update)
                return

    async def update_many(self, query: dict, update: dict) -> None:
        for doc in self.docs:
            if self._match(doc, query):
                self._apply_update(doc, update)

    async def count_documents(self, query: dict) -> int:
        return sum(1 for doc in self.docs if self._match(doc, query))


class _FakeDB:
    def __init__(self, seed_users: list[dict] | None = None) -> None:
        self._collections: dict[str, _FakeCollection] = {}
        if seed_users:
            self["users"].docs.extend(seed_users)

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection()
        return self._collections[name]


def _extract_token(reset_link: str) -> str:
    # Token lives in the URL fragment (#token=...), not the query string —
    # see forgot_password() in auth.py.
    fragment = urlparse(reset_link).fragment
    query = parse_qs(fragment)
    return unquote(query["token"][0])


class TestForgotResetPasswordEndpoints(unittest.TestCase):
    def _client(self) -> TestClient:
        return TestClient(app)

    def _patches(self, db: _FakeDB):
        """Common patch set for every test: router DB swapped for our fake,
        email sends mocked, refresh-token issuance mocked."""
        return [
            patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db),
            patch("app.routers.auth.send_password_reset_email", new_callable=AsyncMock, return_value=True),
            patch("app.routers.auth.send_google_signin_notice_email", new_callable=AsyncMock, return_value=True),
            patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"),
            patch("app.routers.auth.revoke_all_refresh_tokens_for_user", new_callable=AsyncMock),
        ]

    def _run(self, db: _FakeDB, fn):
        """Apply all patches, yield the started mocks by name to fn."""
        patches = self._patches(db)
        mocks = [p.start() for p in patches]
        try:
            names = [
                "router_get_db", "send_reset_email", "send_google_notice",
                "issue_refresh", "revoke_refresh",
            ]
            return fn(dict(zip(names, mocks)))
        finally:
            for p in reversed(patches):
                p.stop()

    # 1. Email/password account -> forgot password -> reset works.
    def test_password_account_forgot_password_then_reset_works(self) -> None:
        db = _FakeDB(seed_users=[_password_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                resp = client.post("/auth/forgot-password", json={"email": PASSWORD_USER_EMAIL})
                self.assertEqual(resp.status_code, 200)
                self.assertEqual(resp.json(), {"success": True})
                mocks["send_reset_email"].assert_awaited_once()
                mocks["send_google_notice"].assert_not_awaited()

                reset_link = mocks["send_reset_email"].call_args.args[1]
                token = _extract_token(reset_link)

                valid = client.post("/auth/validate-reset-token", json={"token": token})
                self.assertEqual(valid.json(), {"valid": True})

                reset = client.post(
                    "/auth/reset-password",
                    json={"token": token, "newPassword": NEW_PASSWORD},
                )
                self.assertEqual(reset.status_code, 200)
                self.assertEqual(reset.json(), {"success": True})

                old_login = client.post(
                    "/auth/login", json={"email": PASSWORD_USER_EMAIL, "password": OLD_PASSWORD}
                )
                self.assertEqual(old_login.status_code, 401)

                new_login = client.post(
                    "/auth/login", json={"email": PASSWORD_USER_EMAIL, "password": NEW_PASSWORD}
                )
                self.assertEqual(new_login.status_code, 200)

        self._run(db, body)

    # Same password as current -> rejected as a hygiene check, and the token
    # is NOT consumed so the user can retry with a different password on the
    # same link instead of requesting a new email.
    def test_reset_password_same_as_current_is_rejected_without_consuming_token(self) -> None:
        db = _FakeDB(seed_users=[_password_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                client.post("/auth/forgot-password", json={"email": PASSWORD_USER_EMAIL})
                reset_link = mocks["send_reset_email"].call_args.args[1]
                token = _extract_token(reset_link)

                same_password = client.post(
                    "/auth/reset-password",
                    json={"token": token, "newPassword": OLD_PASSWORD},
                )
                self.assertEqual(same_password.status_code, 400)
                self.assertIn(
                    "different from your current password",
                    same_password.json()["detail"],
                )

                # Token must still be usable — this was a validation failure,
                # not a successful (token-consuming) reset.
                still_valid = client.post("/auth/validate-reset-token", json={"token": token})
                self.assertEqual(still_valid.json(), {"valid": True})

                retry = client.post(
                    "/auth/reset-password",
                    json={"token": token, "newPassword": NEW_PASSWORD},
                )
                self.assertEqual(retry.status_code, 200)

                old_login = client.post(
                    "/auth/login", json={"email": PASSWORD_USER_EMAIL, "password": OLD_PASSWORD}
                )
                self.assertEqual(old_login.status_code, 401)

                new_login = client.post(
                    "/auth/login", json={"email": PASSWORD_USER_EMAIL, "password": NEW_PASSWORD}
                )
                self.assertEqual(new_login.status_code, 200)

        self._run(db, body)

    # 2. Google-only account -> forgot password -> no reset token generated,
    #    no password changed, notice email sent instead.
    def test_google_only_account_forgot_password_sends_notice_and_leaves_password_unchanged(self) -> None:
        db = _FakeDB(seed_users=[_google_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                resp = client.post("/auth/forgot-password", json={"email": GOOGLE_USER_EMAIL})
                self.assertEqual(resp.status_code, 200)
                self.assertEqual(resp.json(), {"success": True})

                mocks["send_google_notice"].assert_awaited_once()
                mocks["send_reset_email"].assert_not_awaited()

                stored_user = db["users"].docs[0]
                self.assertNotIn("password", stored_user)

        self._run(db, body)

    # 3. Unknown email -> generic response, no email sent either way.
    def test_unknown_email_returns_generic_response(self) -> None:
        db = _FakeDB(seed_users=[_password_user(), _google_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                resp = client.post("/auth/forgot-password", json={"email": UNKNOWN_EMAIL})
                self.assertEqual(resp.status_code, 200)
                self.assertEqual(resp.json(), {"success": True})
                mocks["send_reset_email"].assert_not_awaited()
                mocks["send_google_notice"].assert_not_awaited()

        self._run(db, body)

    # 4. Google-only account -> email/password login remains rejected.
    def test_google_only_account_login_with_password_rejected(self) -> None:
        db = _FakeDB(seed_users=[_google_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                resp = client.post(
                    "/auth/login", json={"email": GOOGLE_USER_EMAIL, "password": "AnyPass1!"}
                )
                self.assertEqual(resp.status_code, 400)
                self.assertIn("Google Sign-In", resp.json()["detail"])

        self._run(db, body)

    # 5. Google-only account -> "Continue with Google" remains the correct
    #    login path (untouched by this fix — regression check).
    def test_google_only_account_continue_with_google_still_works(self) -> None:
        db = _FakeDB(seed_users=[_google_user()])

        def body(mocks: dict[str, Any]):
            with patch(
                "app.routers.auth.verify_google_id_token",
                new_callable=AsyncMock,
                return_value={"email": GOOGLE_USER_EMAIL, "name": "Gerry Google", "picture": ""},
            ):
                with self._client() as client:
                    resp = client.post("/auth/google", json={"idToken": "fake-token"})
            self.assertEqual(resp.status_code, 200)
            body_json = resp.json()
            self.assertFalse(body_json["isNewUser"])
            self.assertIn("access_token", body_json)

        self._run(db, body)

    # 6. Reset tokens cannot be generated for Google-only accounts.
    def test_google_only_account_generates_no_reset_token(self) -> None:
        db = _FakeDB(seed_users=[_google_user()])

        def body(mocks: dict[str, Any]):
            with self._client() as client:
                resp = client.post("/auth/forgot-password", json={"email": GOOGLE_USER_EMAIL})
                self.assertEqual(resp.status_code, 200)
                self.assertEqual(len(db["passwordResetTokens"].docs), 0)

        self._run(db, body)


if __name__ == "__main__":
    unittest.main()
