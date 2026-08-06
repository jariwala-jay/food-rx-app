"""
End-to-end API contract tests for chatbot endpoints.

Uses FastAPI TestClient with mocked MongoDB and RAG service — no API keys or
live database required.

Run:
    cd backend && python3 -m unittest tests.test_chatbot_e2e -v
"""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import AsyncMock, MagicMock, patch

from bson import ObjectId
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.deps import get_chatbot_user_id  # noqa: E402
from app.main import app  # noqa: E402

TEST_USER_ID = "507f1f77bcf86cd799439011"


class _FakeCursor:
    def limit(self, _n: int) -> "_FakeCursor":
        return self

    async def to_list(self, length: int) -> list[dict]:
        return []


class _FakeCollection:
    def __init__(self, docs: dict[str, Any] | None = None) -> None:
        self._docs = docs or {}

    async def find_one(self, query: dict) -> dict | None:
        if "_id" in query:
            return self._docs.get("user")
        return None

    def find(self, query: dict) -> _FakeCursor:
        return _FakeCursor()


class _FakeDB:
    def __init__(self, user_profile: dict | None = None) -> None:
        self._user_profile = user_profile

    def __getitem__(self, name: str) -> _FakeCollection:
        if name == "users":
            return _FakeCollection({"user": self._user_profile})
        return _FakeCollection()


def _diabetes_profile() -> dict:
    return {
        "_id": ObjectId(TEST_USER_ID),
        "name": "Test User",
        "medicalConditions": ["diabetes"],
        "myPlanType": "Diabetes Plate",
    }


class TestChatbotE2E(unittest.TestCase):
    def setUp(self) -> None:
        app.dependency_overrides[get_chatbot_user_id] = lambda: TEST_USER_ID

    def tearDown(self) -> None:
        app.dependency_overrides.clear()

    def _client(self) -> TestClient:
        return TestClient(app)

    @patch("app.main.close_database", new_callable=AsyncMock)
    @patch("app.main.ensure_database_indexes", new_callable=AsyncMock)
    @patch("app.main.get_database", new_callable=AsyncMock)
    @patch("app.main.rag_service.initialize", new_callable=AsyncMock)
    def test_health_endpoint(self, *_mocks: Any) -> None:
        with self._client() as client:
            response = client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})

    @patch("app.routers.chatbot.clear_history", new_callable=AsyncMock)
    @patch("app.routers.chatbot.clear_suggestion_memory_db", new_callable=AsyncMock)
    @patch("app.routers.chatbot.reset_state", new_callable=AsyncMock)
    @patch("app.routers.chatbot.get_database", new_callable=AsyncMock)
    @patch("app.main.close_database", new_callable=AsyncMock)
    @patch("app.main.ensure_database_indexes", new_callable=AsyncMock)
    @patch("app.main.get_database", new_callable=AsyncMock)
    @patch("app.main.rag_service.initialize", new_callable=AsyncMock)
    def test_starter_questions_returns_five(
        self, _init: Any, _main_db: Any, _idx: Any, _close: Any, router_db: Any, *_rest: Any
    ) -> None:
        router_db.return_value = _FakeDB(_diabetes_profile())
        with self._client() as client:
            response = client.get("/chatbot/starter-questions")
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("questions", body)
        self.assertEqual(len(body["questions"]), 5)

    @patch("app.routers.chatbot.generate_followup_chips", new_callable=AsyncMock)
    @patch("app.routers.chatbot.save_message", new_callable=AsyncMock)
    @patch("app.routers.chatbot.load_history", new_callable=AsyncMock, return_value=[])
    @patch("app.routers.chatbot.get_state", new_callable=AsyncMock, return_value={})
    @patch("app.routers.chatbot.get_database", new_callable=AsyncMock)
    @patch("app.services.rag_service.rag_service.chat", new_callable=AsyncMock)
    @patch("app.main.close_database", new_callable=AsyncMock)
    @patch("app.main.ensure_database_indexes", new_callable=AsyncMock)
    @patch("app.main.get_database", new_callable=AsyncMock)
    @patch("app.main.rag_service.initialize", new_callable=AsyncMock)
    def test_chat_returns_response_contract(
        self,
        _init: Any,
        _main_db: Any,
        _idx: Any,
        _close: Any,
        mock_chat: AsyncMock,
        router_db: Any,
        *_rest: Any,
    ) -> None:
        mock_chat.return_value = (
            "Fill half your plate with non-starchy vegetables and add lean protein."
        )
        router_db.return_value = _FakeDB(_diabetes_profile())

        with self._client() as client:
            response = client.post(
                "/chatbot/chat",
                json={"message": "What should I eat for dinner?"},
            )

        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertIn("response", body)
        self.assertIn("follow_up_questions", body)
        self.assertIn("session_closing", body)
        self.assertIsInstance(body["follow_up_questions"], list)
        self.assertFalse(body["session_closing"])
        mock_chat.assert_awaited_once()

    @patch("app.routers.chatbot.clear_history", new_callable=AsyncMock)
    @patch("app.routers.chatbot.clear_suggestion_memory_db", new_callable=AsyncMock)
    @patch("app.routers.chatbot.reset_state", new_callable=AsyncMock)
    @patch("app.routers.chatbot.get_database", new_callable=AsyncMock)
    @patch("app.main.close_database", new_callable=AsyncMock)
    @patch("app.main.ensure_database_indexes", new_callable=AsyncMock)
    @patch("app.main.get_database", new_callable=AsyncMock)
    @patch("app.main.rag_service.initialize", new_callable=AsyncMock)
    def test_start_handshake_returns_greeting_and_starters(
        self, _init: Any, _main_db: Any, _idx: Any, _close: Any, router_db: Any, *_rest: Any
    ) -> None:
        router_db.return_value = _FakeDB(_diabetes_profile())
        with self._client() as client:
            response = client.post("/chatbot/chat", json={"message": "start"})
        self.assertEqual(response.status_code, 200)
        body = response.json()
        self.assertTrue(body["response"])
        self.assertEqual(len(body["follow_up_questions"]), 5)
        self.assertFalse(body["session_closing"])


if __name__ == "__main__":
    unittest.main()
