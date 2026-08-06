"""
Personalization regression tests driven by personalization_test_cases.json.

Validates profile → plan resolution, user-context injection, and canned plan
responses. No API keys required.

Run:
    cd backend && python3 -m unittest tests.test_personalization_regression -v
"""

from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import MagicMock

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.rag.cache import _build_plan_response  # noqa: E402
from app.services.rag.profile_helpers import (  # noqa: E402
    _build_multi_condition_note,
    _resolve_plan_for_profile,
)
from app.services.rag_service import RAGService, rag_service  # noqa: E402

CASES_FILE = BACKEND_ROOT / "evaluation" / "personalization_test_cases.json"


def _load_cases() -> list[dict]:
    data = json.loads(CASES_FILE.read_text(encoding="utf-8"))
    return list(data["cases"])


class TestPersonalizationPlanResolution(unittest.TestCase):
    def test_all_cases_resolve_expected_plan(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            if "expected_plan" not in case:
                continue
            profile = case["profile"]
            expected = case["expected_plan"]
            actual = _resolve_plan_for_profile(profile)
            if actual != expected:
                failures.append(
                    f"{case['id']}: expected plan {expected!r}, got {actual!r}"
                )
        if failures:
            self.fail("\n".join(failures))


class TestPersonalizationUserContext(unittest.TestCase):
    def test_context_contains_profile_signals(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            if "context_must_contain" not in case:
                continue
            profile = case["profile"]
            pantry = case.get("pantry", [])
            context = RAGService._build_user_context(profile, pantry).lower()
            for phrase in case["context_must_contain"]:
                if phrase.lower() not in context:
                    failures.append(
                        f"{case['id']}: context missing {phrase!r}"
                    )
            for phrase in case.get("context_must_not_contain", []):
                if phrase.lower() in context:
                    failures.append(
                        f"{case['id']}: context unexpectedly contains {phrase!r}"
                    )
        if failures:
            self.fail("\n".join(failures))


class TestPersonalizationMultiConditionNote(unittest.TestCase):
    def test_multi_condition_overlay(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            phrases = case.get("multi_condition_note_must_contain")
            if not phrases:
                continue
            note = (_build_multi_condition_note(case["profile"]) or "").lower()
            if not note:
                failures.append(f"{case['id']}: expected multi-condition note, got none")
                continue
            for phrase in phrases:
                if phrase.lower() not in note:
                    failures.append(
                        f"{case['id']}: note missing {phrase!r}"
                    )
        if failures:
            self.fail("\n".join(failures))


class TestPersonalizationPlanQueryResponses(unittest.TestCase):
    def setUp(self) -> None:
        self._prev_ready = rag_service._ready
        self._prev_client = rag_service._client
        rag_service._ready = True
        rag_service._client = MagicMock()

    def tearDown(self) -> None:
        rag_service._ready = self._prev_ready
        rag_service._client = self._prev_client

    def test_plan_queries_return_canned_plan_copy(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            question = case.get("question")
            phrases = case.get("response_must_contain")
            if not question or not phrases:
                continue
            profile = case["profile"]
            reply = asyncio.run(
                rag_service.chat(question, history=[], user_profile=profile)
            ).lower()
            plan = _resolve_plan_for_profile(profile)
            expected = _build_plan_response(plan).lower()
            if reply != expected:
                failures.append(
                    f"{case['id']}: plan query did not return canned plan response"
                )
                continue
            for phrase in phrases:
                if phrase.lower() not in reply:
                    failures.append(
                        f"{case['id']}: response missing {phrase!r}"
                    )
        if failures:
            self.fail("\n".join(failures))


if __name__ == "__main__":
    unittest.main()
