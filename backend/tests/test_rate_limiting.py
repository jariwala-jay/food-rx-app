"""
Regression test for the per-IP rate limit on POST /auth/register (finding
#7 in the 2026-08 audit: no rate limiting anywhere in the backend). Register
is a representative example — every public auth endpoint gets the same
@limiter.limit(...) treatment in routers/auth.py.

Uses FastAPI TestClient with a mocked in-memory MongoDB — no live database
required. TestClient requests all share one fixed host ("testclient"), which
is exactly what lets this test observe the limiter treating them as a single
client.

Run:
    cd backend && python3 -m unittest tests.test_rate_limiting -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.rate_limit import limiter, rate_limit_exceeded_handler  # noqa: E402
from app.routers import auth as auth_router  # noqa: E402
from slowapi.errors import RateLimitExceeded  # noqa: E402

app = FastAPI()
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)
app.include_router(auth_router.router)

REGISTER_LIMIT_PER_MINUTE = 5  # must match the @limiter.limit(...) on /auth/register


class _FakeCollection:
    def __init__(self) -> None:
        self.docs: list[dict] = []

    async def find_one(self, query: dict) -> dict | None:
        email = query.get("email")
        for doc in self.docs:
            if doc.get("email") == email:
                return doc
        return None

    async def insert_one(self, doc: dict):
        self.docs.append(doc)
        return type("Result", (), {"inserted_id": doc.get("_id")})()


class _FakeDB:
    def __init__(self) -> None:
        self._collections: dict[str, _FakeCollection] = {}

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection()
        return self._collections[name]


class TestRegisterRateLimit(unittest.TestCase):
    def setUp(self) -> None:
        # Each test gets a clean counter — otherwise call counts would carry
        # over between test methods sharing this process (the limiter's
        # in-memory storage is a module-level singleton).
        limiter.reset()

    def _register(self, client: TestClient, email: str):
        return client.post(
            "/auth/register",
            json={"email": email, "password": "ValidPass1!"},
        )

    def test_requests_under_the_limit_all_succeed(self) -> None:
        db = _FakeDB()
        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
                patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"):
            with TestClient(app) as client:
                for i in range(REGISTER_LIMIT_PER_MINUTE):
                    resp = self._register(client, f"user{i}@example.com")
                    self.assertEqual(resp.status_code, 200, resp.text)

    def test_requests_over_the_limit_are_rejected_with_429(self) -> None:
        db = _FakeDB()
        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
                patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"):
            with TestClient(app) as client:
                for i in range(REGISTER_LIMIT_PER_MINUTE):
                    resp = self._register(client, f"user{i}@example.com")
                    self.assertEqual(resp.status_code, 200, resp.text)

                blocked = self._register(client, "one-too-many@example.com")
                self.assertEqual(blocked.status_code, 429)
                # Must be {"detail": ...} — the same shape every other error
                # response in this API uses — not slowapi's default
                # {"error": ...}, which the Flutter client doesn't parse (see
                # ApiClient._throwFromResponse).
                self.assertIsInstance(blocked.json().get("detail"), str)


if __name__ == "__main__":
    unittest.main()
