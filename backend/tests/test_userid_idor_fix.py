"""
Regression tests: POST /trackers, POST /trackers/progress, and
POST /notifications must ignore a client-supplied "userId" in the request
body and always write under the authenticated caller's id.

Builds a minimal app around just the trackers/notifications routers (no
chromadb dependency, unlike app.main) with a fake in-memory Mongo
collection and an overridden get_current_user_id dependency.

Run:
    cd backend && python3 -m unittest tests.test_userid_idor_fix -v
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

from app.deps import get_current_user_id  # noqa: E402
from app.routers import notifications, trackers  # noqa: E402

AUTHENTICATED_USER_ID = "507f1f77bcf86cd799439011"  # whoever the JWT actually belongs to
ATTACKER_TARGET_USER_ID = "507f1f77bcf86cd799439099"  # id an attacker tries to write under


class _FakeCollection:
    """Captures inserted docs; only the operations these two routers use."""

    def __init__(self) -> None:
        self.docs: list[dict] = []

    async def insert_one(self, doc: dict):
        self.docs.append(doc)
        return type("Result", (), {"inserted_id": doc.get("_id")})()

    async def insert_many(self, docs: list[dict]):
        self.docs.extend(docs)
        return type("Result", (), {"inserted_ids": [d.get("_id") for d in docs]})()

    async def find_one(self, query: dict):
        return None

    def find(self, query: dict):
        class _Cursor:
            async def to_list(self_inner, length=None):
                return []

        return _Cursor()


class _FakeDB:
    def __init__(self) -> None:
        self._collections: dict[str, _FakeCollection] = {}

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection()
        return self._collections[name]


def _make_app() -> FastAPI:
    app = FastAPI()
    app.include_router(trackers.router)
    app.include_router(notifications.router)
    app.dependency_overrides[get_current_user_id] = lambda: AUTHENTICATED_USER_ID
    return app


class TestTrackerUserIdOverrideFixed(unittest.TestCase):
    def test_create_tracker_ignores_client_supplied_user_id(self) -> None:
        db = _FakeDB()
        with patch("app.routers.trackers.get_database", new_callable=AsyncMock, return_value=db):
            with TestClient(_make_app()) as client:
                resp = client.post(
                    "/trackers",
                    json={
                        "name": "Water",
                        "goalValue": 8,
                        "userId": ATTACKER_TARGET_USER_ID,  # attacker-supplied
                    },
                )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["userId"], AUTHENTICATED_USER_ID)
        stored = db["user_trackers"].docs[0]
        self.assertEqual(stored["userId"], AUTHENTICATED_USER_ID)
        self.assertNotEqual(stored["userId"], ATTACKER_TARGET_USER_ID)

    def test_save_progress_single_doc_ignores_client_supplied_user_id(self) -> None:
        db = _FakeDB()
        with patch("app.routers.trackers.get_database", new_callable=AsyncMock, return_value=db):
            with TestClient(_make_app()) as client:
                resp = client.post(
                    "/trackers/progress",
                    json={
                        "trackerId": "abc",
                        "achievedValue": 5,
                        "userId": ATTACKER_TARGET_USER_ID,
                    },
                )
        self.assertEqual(resp.status_code, 200)
        stored = db["tracker_progress"].docs[0]
        self.assertEqual(stored["userId"], AUTHENTICATED_USER_ID)

    def test_save_progress_list_body_ignores_client_supplied_user_id(self) -> None:
        db = _FakeDB()
        with patch("app.routers.trackers.get_database", new_callable=AsyncMock, return_value=db):
            with TestClient(_make_app()) as client:
                resp = client.post(
                    "/trackers/progress",
                    json=[
                        {"trackerId": "abc", "achievedValue": 5, "userId": ATTACKER_TARGET_USER_ID},
                        {"trackerId": "def", "achievedValue": 2, "userId": ATTACKER_TARGET_USER_ID},
                    ],
                )
        self.assertEqual(resp.status_code, 200)
        stored_docs = db["tracker_progress"].docs
        self.assertEqual(len(stored_docs), 2)
        for doc in stored_docs:
            self.assertEqual(doc["userId"], AUTHENTICATED_USER_ID)


class TestNotificationUserIdOverrideFixed(unittest.TestCase):
    def test_create_notification_ignores_client_supplied_user_id(self) -> None:
        db = _FakeDB()
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db), \
             patch(
                 "app.routers.notifications.is_eligible_for_non_welcome_notification",
                 new_callable=AsyncMock,
                 return_value=True,
             ):
            with TestClient(_make_app()) as client:
                resp = client.post(
                    "/notifications",
                    json={
                        "type": "admin",
                        "title": "Security alert",
                        "message": "Click here to verify your account",
                        "userId": ATTACKER_TARGET_USER_ID,  # attacker trying to plant this in someone else's inbox
                    },
                )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()["userId"], AUTHENTICATED_USER_ID)
        stored = db["notifications"].docs[0]
        self.assertEqual(stored["userId"], AUTHENTICATED_USER_ID)
        self.assertNotEqual(stored["userId"], ATTACKER_TARGET_USER_ID)


if __name__ == "__main__":
    unittest.main()
