"""
MyFoodRx Safety Evaluation
============================
Runs regression cases from safety_test_cases.json and prints a pass/fail report.

This validates safety routing (emergency, medical, off-topic, injection) — not
retrieval quality. For retrieval metrics, use run_rag_eval.py.

Usage:
    cd backend
    python3 evaluation/run_safety_eval.py

No API keys required — blocked paths return canned guardrails without calling
Gemini or Groq.
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(BACKEND_DIR))

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

CASES_FILE = Path(__file__).parent / "safety_test_cases.json"

_CLASS_BY_NAME = {
    "emergency": _QueryClass.EMERGENCY,
    "medical": _QueryClass.MEDICAL,
    "off_topic": _QueryClass.OFF_TOPIC,
    "diet": _QueryClass.DIET,
}

_BLOCKED_REPLY = {
    _QueryClass.EMERGENCY: _MSG_EMERGENCY,
    _QueryClass.MEDICAL: _MSG_MEDICAL,
    _QueryClass.OFF_TOPIC: _MSG_OFFTOPIC,
}


def _run_classification(cases: list[dict]) -> tuple[int, list[str]]:
    passed = 0
    failures: list[str] = []
    for case in cases:
        expected = _CLASS_BY_NAME[case["expected_class"]]
        actual = classify_query(case["message"])
        if actual == expected:
            passed += 1
        else:
            failures.append(
                f"  [classify] {case['id']}: expected {expected}, got {actual}"
            )
    return passed, failures


async def _run_blocked_chat(cases: list[dict]) -> tuple[int, list[str]]:
    passed = 0
    failures: list[str] = []
    for case in cases:
        if not case.get("blocked_before_llm"):
            continue
        reply = await rag_service.chat(case["message"], history=[], user_profile=None)
        if case.get("blocked_reason") == "embedded_instruction":
            expected = _MSG_OFFTOPIC
        else:
            expected = _BLOCKED_REPLY[_CLASS_BY_NAME[case["expected_class"]]]

        ok = reply == expected
        for phrase in case.get("must_not_contain", []):
            if phrase.lower() in reply.lower():
                ok = False
                failures.append(
                    f"  [chat] {case['id']}: guardrail contains forbidden {phrase!r}"
                )

        if ok:
            passed += 1
        elif not any(case["id"] in f for f in failures):
            failures.append(f"  [chat] {case['id']}: unexpected reply")

    # input too long
    long_msg = "x" * (MAX_INPUT_CHARS + 1)
    reply = await rag_service.chat(long_msg, history=[], user_profile=None)
    if reply == _MSG_INPUT_TOO_LONG:
        passed += 1
    else:
        failures.append("  [chat] input_too_long: did not return canned message")

    return passed, failures


def main() -> None:
    cases = json.loads(CASES_FILE.read_text(encoding="utf-8"))["cases"]
    blocked_count = sum(1 for c in cases if c.get("blocked_before_llm")) + 1

    print(f"\n{'='*60}")
    print(f"MyFoodRx Safety Evaluation — {len(cases)} classification cases")
    print(f"{'='*60}\n")

    class_passed, class_failures = _run_classification(cases)
    chat_passed, chat_failures = asyncio.run(_run_blocked_chat(cases))

    total = len(cases) + blocked_count
    passed = class_passed + chat_passed
    failures = class_failures + chat_failures

    print(f"Classification : {class_passed}/{len(cases)} passed")
    print(f"Blocked chat   : {chat_passed}/{blocked_count} passed")
    print(f"Overall        : {passed}/{total} passed")

    if failures:
        print(f"\n{'='*60}")
        print("FAILURES")
        print(f"{'='*60}")
        for line in failures:
            print(line)
        print()
        sys.exit(1)

    print(f"\n✓ All safety checks passed\n{'='*60}\n")


if __name__ == "__main__":
    main()
