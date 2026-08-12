"""
Regression tests for GET /api/profile-photos/{photo_id} (finding #8 in the
2026-08 audit: this endpoint was fully unauthenticated, and photo IDs are
ordinary MongoDB ObjectIds — guessable/enumerable, not capability tokens).
It's now scoped to the caller's own profilePhotoId.

Uses app.main.app directly (chromadb is deferred into RAGService.initialize()
as of the 2026-08-11 cold-start fix, so importing it no longer requires
chromadb to be installed). Deliberately never enters TestClient as a context
manager — that would run main.py's lifespan hook and kick off the real
(slow) ChromaDB load, which this test has no need for.

Run:
    cd backend && python3 -m unittest tests.test_profile_photo_auth -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from bson import ObjectId
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.deps import get_current_user_id  # noqa: E402
from app.main import app  # noqa: E402

OWNER_USER_ID = ObjectId("507f1f77bcf86cd799439011")
OTHER_USER_ID = ObjectId("507f1f77bcf86cd799439099")
PHOTO_ID = ObjectId("507f1f77bcf86cd799439abc")


class _FakeCollection:
    def __init__(self, docs: list[dict]) -> None:
        self.docs = docs

    async def find_one(self, query: dict) -> dict | None:
        for doc in self.docs:
            if all(doc.get(k) == v for k, v in query.items()):
                return doc
        return None


class _FakeDB:
    def __init__(self) -> None:
        self._collections = {
            "users": _FakeCollection([
                {"_id": OWNER_USER_ID, "profilePhotoId": str(PHOTO_ID)},
                {"_id": OTHER_USER_ID, "profilePhotoId": None},
            ]),
            "profile_photos.chunks": _FakeCollection([
                {"files_id": PHOTO_ID, "data": b"fake-jpeg-bytes"},
            ]),
        }

    def __getitem__(self, name: str) -> _FakeCollection:
        return self._collections[name]


class TestProfilePhotoAuth(unittest.TestCase):
    def _client_as(self, user_id: ObjectId) -> TestClient:
        app.dependency_overrides[get_current_user_id] = lambda: str(user_id)
        return TestClient(app)

    def tearDown(self) -> None:
        app.dependency_overrides.pop(get_current_user_id, None)

    def test_requires_authentication(self) -> None:
        app.dependency_overrides.pop(get_current_user_id, None)
        resp = TestClient(app).get(f"/api/profile-photos/{PHOTO_ID}")
        self.assertEqual(resp.status_code, 401)

    def test_owner_can_fetch_their_own_photo(self) -> None:
        db = _FakeDB()
        with patch("app.main.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._client_as(OWNER_USER_ID).get(f"/api/profile-photos/{PHOTO_ID}")
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.content, b"fake-jpeg-bytes")

    def test_another_authenticated_user_cannot_fetch_someone_elses_photo(self) -> None:
        db = _FakeDB()
        with patch("app.main.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._client_as(OTHER_USER_ID).get(f"/api/profile-photos/{PHOTO_ID}")
        self.assertEqual(resp.status_code, 404)

    def test_invalid_photo_id_is_a_400(self) -> None:
        db = _FakeDB()
        with patch("app.main.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._client_as(OWNER_USER_ID).get("/api/profile-photos/not-an-object-id")
        self.assertEqual(resp.status_code, 400)


if __name__ == "__main__":
    unittest.main()
