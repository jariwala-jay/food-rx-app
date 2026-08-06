"""
MyFoodRx Personalization Evaluation
====================================
Runs profile-to-plan regression cases from personalization_test_cases.json.

Validates plan resolution, user-context injection, and canned plan responses.
No API keys required.

Usage:
    cd backend
    python3 evaluation/run_personalization_eval.py
"""

from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path
from unittest.mock import MagicMock

BACKEND_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from app.services.rag.cache import _build_plan_response  # noqa: E402
from app.services.rag.profile_helpers import (  # noqa: E402
    _build_multi_condition_note,
    _resolve_plan_for_profile,
)
from app.services.rag_service import RAGService, rag_service  # noqa: E402

CASES_FILE = Path(__file__).parent / "personalization_test_cases.json"


def main() -> None:
    cases = json.loads(CASES_FILE.read_text(encoding="utf-8"))["cases"]
    failures: list[str] = []
    passed = 0
    total = 0

    print(f"\n{'='*60}")
    print(f"MyFoodRx Personalization Evaluation — {len(cases)} cases")
    print(f"{'='*60}\n")

    for case in cases:
        case_id = case["id"]
        total += 1
        ok = True

        if "expected_plan" in case:
            actual = _resolve_plan_for_profile(case["profile"])
            if actual != case["expected_plan"]:
                ok = False
                failures.append(
                    f"  [plan] {case_id}: expected {case['expected_plan']}, got {actual}"
                )

        if "context_must_contain" in case:
            context = RAGService._build_user_context(
                case["profile"], case.get("pantry", [])
            ).lower()
            for phrase in case["context_must_contain"]:
                if phrase.lower() not in context:
                    ok = False
                    failures.append(f"  [context] {case_id}: missing {phrase!r}")
            for phrase in case.get("context_must_not_contain", []):
                if phrase.lower() in context:
                    ok = False
                    failures.append(
                        f"  [context] {case_id}: unexpectedly contains {phrase!r}"
                    )

        if case.get("multi_condition_note_must_contain"):
            note = (_build_multi_condition_note(case["profile"]) or "").lower()
            for phrase in case["multi_condition_note_must_contain"]:
                if phrase.lower() not in note:
                    ok = False
                    failures.append(f"  [overlay] {case_id}: note missing {phrase!r}")

        if case.get("question") and case.get("response_must_contain"):
            rag_service._ready = True
            rag_service._client = MagicMock()
            reply = asyncio.run(
                rag_service.chat(
                    case["question"], history=[], user_profile=case["profile"]
                )
            ).lower()
            plan = _resolve_plan_for_profile(case["profile"])
            if reply != _build_plan_response(plan).lower():
                ok = False
                failures.append(f"  [plan-query] {case_id}: not canned plan response")
            else:
                for phrase in case["response_must_contain"]:
                    if phrase.lower() not in reply:
                        ok = False
                        failures.append(
                            f"  [plan-query] {case_id}: response missing {phrase!r}"
                        )

        if ok:
            passed += 1
            print(f"  ✓ {case_id}")
        else:
            print(f"  ✗ {case_id}")

    print(f"\nOverall: {passed}/{total} passed")
    if failures:
        print(f"\n{'='*60}")
        print("FAILURES")
        print(f"{'='*60}")
        for line in failures:
            print(line)
        print()
        sys.exit(1)

    print(f"\n✓ All personalization checks passed\n{'='*60}\n")


if __name__ == "__main__":
    main()
