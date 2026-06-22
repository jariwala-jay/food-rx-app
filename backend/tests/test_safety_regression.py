"""
Safety regression tests driven by backend/evaluation/safety_test_cases.json.

Validates:
  1. classify_query() routes each message to the expected safety class.
  2. Blocked messages return canned guardrail replies from rag_service.chat()
     without reaching the LLM (no API keys required for blocked paths).

Run:
    cd backend && python3 -m unittest tests.test_safety_regression -v
"""

from __future__ import annotations

import asyncio
import json
import sys
import unittest
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.services.rag_service import (  # noqa: E402
    MAX_INPUT_CHARS,
    _MSG_EMERGENCY,
    _MSG_INPUT_TOO_LONG,
    _MSG_MEDICAL,
    _MSG_OFFTOPIC,
    _QueryClass,
    classify_query,
    rag_service,
)

CASES_FILE = BACKEND_ROOT / "evaluation" / "safety_test_cases.json"

_CLASS_BY_NAME = {
    "emergency": _QueryClass.EMERGENCY,
    "medical": _QueryClass.MEDICAL,
    "off_topic": _QueryClass.OFF_TOPIC,
    "diet": _QueryClass.DIET,
}

_BLOCKED_REPLY_BY_CLASS = {
    _QueryClass.EMERGENCY: _MSG_EMERGENCY,
    _QueryClass.MEDICAL: _MSG_MEDICAL,
    _QueryClass.OFF_TOPIC: _MSG_OFFTOPIC,
}


def _load_cases() -> list[dict]:
    data = json.loads(CASES_FILE.read_text(encoding="utf-8"))
    return list(data["cases"])


class TestSafetyClassificationRegression(unittest.TestCase):
    """Every JSON case must classify to expected_class."""

    def test_all_cases_classify_correctly(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            message = case["message"]
            expected = _CLASS_BY_NAME[case["expected_class"]]
            actual = classify_query(message)
            if actual != expected:
                failures.append(
                    f"{case['id']}: expected {expected}, got {actual} "
                    f"for message: {message!r}"
                )
        if failures:
            self.fail("\n".join(failures))


class TestSafetyChatBlockedRegression(unittest.TestCase):
    """Blocked cases must return canned guardrails from rag_service.chat()."""

    def test_blocked_cases_return_guardrails(self) -> None:
        failures: list[str] = []
        for case in _load_cases():
            if not case.get("blocked_before_llm"):
                continue

            message = case["message"]
            reply = asyncio.run(
                rag_service.chat(message, history=[], user_profile=None)
            )

            blocked_reason = case.get("blocked_reason")
            if blocked_reason == "embedded_instruction":
                expected = _MSG_OFFTOPIC
            else:
                expected_class = _CLASS_BY_NAME[case["expected_class"]]
                expected = _BLOCKED_REPLY_BY_CLASS[expected_class]

            if reply != expected:
                failures.append(
                    f"{case['id']}: expected canned guardrail, got: {reply[:120]!r}..."
                )
                continue

            for phrase in case.get("must_not_contain", []):
                if phrase.lower() in reply.lower():
                    failures.append(
                        f"{case['id']}: guardrail unexpectedly contains {phrase!r}"
                    )

        if failures:
            self.fail("\n".join(failures))

    def test_input_too_long_returns_canned_message(self) -> None:
        long_message = "x" * (MAX_INPUT_CHARS + 1)
        reply = asyncio.run(
            rag_service.chat(long_message, history=[], user_profile=None)
        )
        self.assertEqual(reply, _MSG_INPUT_TOO_LONG)


class TestSafetyDietCasesNotBlockedEarly(unittest.TestCase):
    """Diet-scope cases must not hit emergency/medical/off-topic guardrails."""

    def test_diet_cases_not_canned_guardrails(self) -> None:
        canned = {_MSG_EMERGENCY, _MSG_MEDICAL, _MSG_OFFTOPIC}
        for case in _load_cases():
            if case.get("blocked_before_llm"):
                continue
            message = case["message"]
            self.assertEqual(
                classify_query(message),
                _QueryClass.DIET,
                msg=f"{case['id']} should classify as DIET",
            )
            for phrase in case.get("must_not_contain", []):
                self.assertNotIn(
                    phrase.lower(),
                    message.lower(),
                    msg=f"{case['id']} fixture should not embed forbidden phrase",
                )
            # Classification-only: diet cases proceed past guardrails in chat().
            # Full answer quality is covered by run_rag_eval.py, not here.
            _ = canned  # document intent — chat() may need LLM for diet replies


if __name__ == "__main__":
    unittest.main()
