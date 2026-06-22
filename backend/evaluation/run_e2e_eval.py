"""
MyFoodRx Production E2E Evaluation
===================================
Evaluates the real chatbot path via rag_service.chat():
  profile → safety routing → plan resolution → retrieval → Gemini → answer

Groq (llama-3.3-70b-versatile) acts as LLM judge for diet cases only.
Blocked safety cases are checked against expected guardrail routing.

Usage:
    cd backend
    python3 evaluation/run_e2e_eval.py
    python3 evaluation/run_e2e_eval.py --id realistic_canned_soup_multi

Requirements:
    GEMINI_API_KEY and GROQ_API_KEY in .env
    ChromaDB must be built (run the backend once or call rag_service.initialize())
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import time
import uuid
from datetime import datetime
from pathlib import Path

BACKEND_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from dotenv import load_dotenv

load_dotenv(BACKEND_DIR.parent / ".env")

from groq import Groq

from app.services.rag_service import rag_service  # noqa: E402

CASES_FILE = Path(__file__).parent / "e2e_test_cases.json"
REPORTS_DIR = Path(__file__).parent / "reports"
REPORTS_DIR.mkdir(exist_ok=True)

GROQ_MODELS = [
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "gemma2-9b-it",
]
QUESTION_DELAY_SEC = 6


def score_all_metrics(
    groq_client: Groq,
    question: str,
    answer: str,
    context_chunks: list[str],
    reference: str,
) -> dict:
    context_text = "\n\n".join(
        f"[Chunk {i+1}]: {chunk}" for i, chunk in enumerate(context_chunks)
    )
    prompt = f"""You are an evaluation assistant. Score the following RAG chatbot output.

QUESTION: {question}

REFERENCE ANSWER: {reference}

RETRIEVED CONTEXT:
{context_text}

GENERATED ANSWER: {answer}

Score each metric from 0.0 to 1.0 and return ONLY a JSON object, no explanation, no markdown:

{{"faithfulness": <0.0-1.0, is the answer grounded in the retrieved context?>, "answer_relevancy": <0.0-1.0, does the answer address the question?>, "context_precision": <0.0-1.0, were the retrieved chunks useful for answering?>}}"""

    for model in GROQ_MODELS:
        for attempt in range(2):
            try:
                response = groq_client.chat.completions.create(
                    model=model,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.0,
                    max_tokens=100,
                )
                raw = response.choices[0].message.content.strip()
                raw = raw.replace("```json", "").replace("```", "")
                scores = json.loads(raw)
                return {
                    "faithfulness": round(float(scores.get("faithfulness", 0.5)), 3),
                    "answer_relevancy": round(
                        float(scores.get("answer_relevancy", 0.5)), 3
                    ),
                    "context_precision": round(
                        float(scores.get("context_precision", 0.5)), 3
                    ),
                }
            except Exception as exc:
                if "429" in str(exc) or "rate" in str(exc).lower():
                    wait = 15 * (attempt + 1)
                    print(f"    ⚠ {model} rate limited, retrying in {wait}s...")
                    time.sleep(wait)
                else:
                    print(f"    ⚠ Scoring error: {exc}")
                    break
        print(f"    ⚠ {model} exhausted, trying next model...")
    return {"faithfulness": 0.5, "answer_relevancy": 0.5, "context_precision": 0.5}


def _chunk_texts(retrieved: list[dict]) -> list[str]:
    return [str(c.get("text", "")) for c in retrieved if c.get("text")]


async def run_case(case: dict, groq_client: Groq) -> dict:
    case_id = case["id"]
    question = case["question"]
    profile = case.get("profile")
    pantry = case.get("pantry", [])
    eval_meta: dict = {}

    # Unique user_id avoids RAG cache collisions between cases.
    user_id = f"e2e-eval-{case_id}-{uuid.uuid4().hex[:8]}"

    answer = await rag_service.chat(
        question,
        history=[],
        user_profile=profile,
        pantry_items=pantry,
        user_id=user_id,
        eval_meta_out=eval_meta,
    )

    result: dict = {
        "id": case_id,
        "category": case.get("category", ""),
        "question": question,
        "answer": answer,
        "profile": profile,
        "plan": eval_meta.get("plan"),
        "model_used": eval_meta.get("model_used"),
        "blocked": eval_meta.get("blocked"),
        "retrieval_score": eval_meta.get("score"),
        "cache": eval_meta.get("cache"),
        "retrieved_doc_ids": [
            c.get("doc_id") for c in eval_meta.get("retrieved_chunks", [])
        ],
    }

    if case.get("expect_blocked"):
        expected = case["expected_blocked"]
        actual = eval_meta.get("blocked")
        # prompt_injection counts as off_topic routing for weather-style cases
        if expected == "off_topic" and actual == "prompt_injection":
            actual = "off_topic"
        passed = actual == expected
        result["safety_check"] = "pass" if passed else "fail"
        result["expected_blocked"] = expected
        print(
            f"    safety={'PASS' if passed else 'FAIL'} "
            f"(expected={expected}, actual={actual})"
        )
        return result

    reference = case.get("reference", "")
    chunks = _chunk_texts(eval_meta.get("retrieved_chunks", []))
    if not chunks and eval_meta.get("plan_canned"):
        result["note"] = "canned_plan_response"
    elif not chunks and eval_meta.get("cache") != "none":
        result["note"] = f"cache_hit_{eval_meta.get('cache')}"

    scores = score_all_metrics(groq_client, question, answer, chunks, reference)
    result.update(scores)
    print(
        f"    faithfulness={scores['faithfulness']:.2f}  "
        f"relevancy={scores['answer_relevancy']:.2f}  "
        f"precision={scores['context_precision']:.2f}  "
        f"model={eval_meta.get('model_used') or '—'}"
    )
    return result


async def run_evaluation(case_id_filter: str | None = None) -> None:
    gemini_key = os.getenv("GEMINI_API_KEY")
    groq_key = os.getenv("GROQ_API_KEY")
    if not gemini_key:
        print("ERROR: GEMINI_API_KEY not set in .env")
        sys.exit(1)
    if not groq_key:
        print("ERROR: GROQ_API_KEY not set in .env")
        sys.exit(1)

    await rag_service.initialize()
    if not rag_service._ready:
        print("ERROR: RAG service not ready — check GEMINI_API_KEY and ChromaDB.")
        sys.exit(1)

    cases = json.loads(CASES_FILE.read_text(encoding="utf-8"))["cases"]
    if case_id_filter:
        cases = [c for c in cases if c["id"] == case_id_filter]
        if not cases:
            print(f"ERROR: no case with id {case_id_filter!r}")
            sys.exit(1)

    groq_client = Groq(api_key=groq_key)

    print(f"\n{'='*60}")
    print(f"MyFoodRx E2E Evaluation — {len(cases)} cases (production chat path)")
    print(f"{'='*60}\n")

    results: list[dict] = []
    for i, case in enumerate(cases):
        print(f"[{i+1}/{len(cases)}] {case['id']}: {case['question'][:55]}...")
        results.append(await run_case(case, groq_client))
        time.sleep(QUESTION_DELAY_SEC)

    scored = [r for r in results if "faithfulness" in r]
    safety = [r for r in results if r.get("safety_check")]

    def avg(key: str, items: list[dict]) -> float:
        vals = [r[key] for r in items if r.get(key) is not None]
        return round(sum(vals) / len(vals), 3) if vals else 0.0

    overall = {
        "faithfulness": avg("faithfulness", scored),
        "answer_relevancy": avg("answer_relevancy", scored),
        "context_precision": avg("context_precision", scored),
    }
    safety_passed = sum(1 for r in safety if r.get("safety_check") == "pass")

    print(f"\n{'='*60}")
    print("OVERALL (diet cases, Groq judge)")
    print(f"{'='*60}")
    print(f"  Scored cases     : {len(scored)}")
    print(f"  Faithfulness     : {overall['faithfulness']:.3f}")
    print(f"  Answer Relevancy : {overall['answer_relevancy']:.3f}")
    print(f"  Context Precision: {overall['context_precision']:.3f}")
    if safety:
        print(f"\n  Safety checks    : {safety_passed}/{len(safety)} passed")

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
    report_path = REPORTS_DIR / f"e2e_eval_report_{timestamp}.json"
    report = {
        "timestamp": timestamp,
        "eval_type": "production_e2e",
        "generator": "gemini (rag_service.chat)",
        "judge": "groq " + GROQ_MODELS[0],
        "total_cases": len(cases),
        "scored_cases": len(scored),
        "safety_cases": len(safety),
        "safety_passed": safety_passed,
        "overall": overall,
        "details": results,
    }
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\n✓ Report saved to: {report_path}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", type=str, default=None, help="Run a single case id")
    args = parser.parse_args()
    asyncio.run(run_evaluation(case_id_filter=args.id))
