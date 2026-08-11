"""
Regression tests: the password-reset token must never be transmitted to
the backend via GET /auth/reset-password/open. It travels in the URL
*fragment* (#token=...) instead of a query string, since browsers never
send the fragment to the server — a query string would land in Cloud Run's
platform-level request logs regardless of any response header, since that
logging happens before the FastAPI app layer runs at all.

Proves two things: (1) the emailed link never puts the token in a query
string, and (2) the GET route's response doesn't depend on the query
string at all, so even a client that appends ?token=... leaks nothing.

Run:
    cd backend && python3 -m unittest tests.test_password_reset_token_not_logged -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch
from urllib.parse import urlparse

from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.auth_password import hash_password  # noqa: E402
from app.routers import auth as auth_router  # noqa: E402

# Minimal app around just auth.router — see test_forgot_reset_password_endpoints.py
# for why (avoids app.main's chromadb-dependent chatbot router entirely).
app = FastAPI()
app.include_router(auth_router.router)

USER_ID = ObjectId("507f1f77bcf86cd799439011")
USER_EMAIL = "reset.user@example.com"


def _seed_user() -> dict:
    return {
        "_id": USER_ID,
        "email": USER_EMAIL,
        "password": hash_password("OldPass1!"),
        "name": "Resetta User",
        "failedLoginAttempts": 0,
        "isLocked": False,
        "lockUntil": None,
    }


class _FakeCollection:
    def __init__(self) -> None:
        self.docs: list[dict] = []

    async def find_one(self, query: dict) -> dict | None:
        for doc in self.docs:
            if all(doc.get(k) == v for k, v in query.items() if not isinstance(v, dict)):
                return doc
        return None

    def find(self, query: dict, sort=None):
        class _Cursor:
            async def to_list(self_inner, length=None):
                return []

        return _Cursor()

    async def insert_one(self, doc: dict):
        self.docs.append(doc)
        return type("Result", (), {"inserted_id": doc.get("_id")})()

    async def update_many(self, query: dict, update: dict) -> None:
        pass


class _FakeDB:
    def __init__(self, seed_users: list[dict] | None = None) -> None:
        self._collections: dict[str, _FakeCollection] = {}
        if seed_users:
            self["users"].docs.extend(seed_users)

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection()
        return self._collections[name]


class TestResetLinkNeverCarriesTokenInQueryString(unittest.TestCase):
    """The emailed link must never put the token where a browser would
    transmit it to the server."""

    def test_reset_link_has_no_query_string_and_carries_token_only_in_fragment(self) -> None:
        db = _FakeDB(seed_users=[_seed_user()])
        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
             patch("app.routers.auth.send_password_reset_email", new_callable=AsyncMock, return_value=True) as send_mock:
            with TestClient(app) as client:
                resp = client.post("/auth/forgot-password", json={"email": USER_EMAIL})
                self.assertEqual(resp.status_code, 200)

        send_mock.assert_awaited_once()
        reset_link = send_mock.call_args.args[1]
        parsed = urlparse(reset_link)

        # A GET request only ever sends scheme+host+path+query to the
        # server, never the fragment — an empty query string here means the
        # token can't reach (or be logged by) the backend.
        self.assertEqual(
            parsed.query, "",
            "reset_link must not carry a query string — anything here would "
            "be transmitted to the server and captured in Cloud Run's "
            "automatic request logs",
        )
        self.assertTrue(
            parsed.fragment.startswith("token="),
            f"expected '#token=...' fragment, got fragment={parsed.fragment!r}",
        )
        self.assertGreater(len(parsed.fragment), len("token="))  # actually has a value

    def test_reset_link_path_is_unchanged(self) -> None:
        # The App Links intent-filter (AndroidManifest.xml) and associated
        # domains entitlement (Runner.entitlements) match on this exact
        # path — confirm the fragment-only change didn't also move the path.
        db = _FakeDB(seed_users=[_seed_user()])
        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
             patch("app.routers.auth.send_password_reset_email", new_callable=AsyncMock, return_value=True) as send_mock:
            with TestClient(app) as client:
                client.post("/auth/forgot-password", json={"email": USER_EMAIL})

        reset_link = send_mock.call_args.args[1]
        self.assertEqual(urlparse(reset_link).path, "/auth/reset-password/open")


class TestBridgeRouteIsStaticAndTokenIndependent(unittest.TestCase):
    """Even if a token-shaped value arrives in the query string (old-format
    link, or a probe), the route must not read, use, or reflect it."""

    def test_response_identical_with_and_without_a_query_string(self) -> None:
        with TestClient(app) as client:
            bare = client.get("/auth/reset-password/open")
            with_bogus_token = client.get(
                "/auth/reset-password/open", params={"token": "SHOULD-NOT-APPEAR-ANYWHERE"}
            )
        self.assertEqual(bare.status_code, 200)
        self.assertEqual(with_bogus_token.status_code, 200)
        self.assertEqual(
            bare.text, with_bogus_token.text,
            "the bridge page must be byte-identical regardless of any query "
            "string — proves the route doesn't read/use it at all",
        )

    def test_response_never_echoes_a_query_string_token(self) -> None:
        with TestClient(app) as client:
            resp = client.get(
                "/auth/reset-password/open", params={"token": "SHOULD-NOT-APPEAR-ANYWHERE"}
            )
        self.assertNotIn("SHOULD-NOT-APPEAR-ANYWHERE", resp.text)

    def test_response_contains_client_side_fragment_reader_not_a_server_rendered_token(self) -> None:
        with TestClient(app) as client:
            resp = client.get("/auth/reset-password/open")
        # The page must read the token from location.hash client-side...
        self.assertIn("location.hash", resp.text)
        self.assertIn("URLSearchParams", resp.text)
        # ...and never contain a server-embedded foodrx://...?token=<value>
        # redirect — only the dynamic 'foodrx://reset-password?token=' +
        # encodeURIComponent(token) construction should be present.
        self.assertIn(
            "'foodrx://reset-password?token=' + encodeURIComponent(token)",
            resp.text,
        )

    def test_two_different_forgot_password_requests_yield_the_same_bridge_page(self) -> None:
        """Different users, different tokens issued server-side — the GET
        /auth/reset-password/open response must not vary with either,
        because it's requested with no token at all (it's in the fragment,
        which never reaches the server)."""
        db = _FakeDB(seed_users=[_seed_user(), {**_seed_user(), "_id": ObjectId("507f1f77bcf86cd799439099"), "email": "second@example.com"}])
        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
             patch("app.routers.auth.send_password_reset_email", new_callable=AsyncMock, return_value=True):
            with TestClient(app) as client:
                client.post("/auth/forgot-password", json={"email": USER_EMAIL})
                client.post("/auth/forgot-password", json={"email": "second@example.com"})
                first = client.get("/auth/reset-password/open")
                second = client.get("/auth/reset-password/open")
        self.assertEqual(first.text, second.text)

    def test_bridge_route_headers_still_present(self) -> None:
        with TestClient(app) as client:
            resp = client.get("/auth/reset-password/open")
        self.assertEqual(resp.headers.get("cache-control"), "no-store")
        self.assertEqual(resp.headers.get("referrer-policy"), "no-referrer")


if __name__ == "__main__":
    unittest.main()
