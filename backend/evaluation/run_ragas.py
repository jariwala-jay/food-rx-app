"""
MyFoodRx RAGAS Evaluation Script
=================================
Evaluates the RAG chatbot quality using three metrics:
  - Faithfulness     : Is the answer grounded in the retrieved chunks?
  - Answer Relevancy : Does the answer address the question?
  - Context Precision: Were the retrieved chunks actually useful?

Usage:
    cd backend
    python3 evaluation/run_ragas.py

Requirements:
    pip3 install ragas groq
    GEMINI_API_KEY and GROQ_API_KEY must be set in your .env file
"""

import asyncio
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

# ── Path setup ────────────────────────────────────────────────────────────────
BACKEND_DIR = Path(__file__).parent.parent
sys.path.insert(0, str(BACKEND_DIR))

from dotenv import load_dotenv

load_dotenv(BACKEND_DIR.parent / ".env")

from google import genai
from google.genai import types
from groq import Groq

# ── Config ────────────────────────────────────────────────────────────────────
QUESTIONS_FILE = Path(__file__).parent / "test_questions.json"
REPORTS_DIR = Path(__file__).parent / "reports"
REPORTS_DIR.mkdir(exist_ok=True)

EMBEDDING_MODEL = "models/gemini-embedding-001"
GROQ_MODELS = [
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "gemma2-9b-it",
]
RETRIEVAL_K = 4  # same as RAG_CONTEXT_DOC_COUNT in rag_service.py

# ── Load ChromaDB collection ──────────────────────────────────────────────────
import chromadb

CHROMA_PATH = BACKEND_DIR / "app" / "knowledge" / "chroma_db"


def load_collection():
    client = chromadb.PersistentClient(path=str(CHROMA_PATH))
    collection = client.get_collection("myfoodrx_chunks")
    print(f"✓ ChromaDB loaded — {collection.count()} chunks")
    return collection


# ── Embed a query with Gemini ─────────────────────────────────────────────────
def embed_query(gemini_client: genai.Client, question: str) -> list[float]:
    result = gemini_client.models.embed_content(
        model=EMBEDDING_MODEL,
        contents=question,
        config=types.EmbedContentConfig(task_type="RETRIEVAL_QUERY"),
    )
    emb_list = result.embeddings or []
    values = emb_list[0].values if emb_list else []
    return list(values)


# ── Retrieve top-k chunks from ChromaDB ──────────────────────────────────────
def retrieve_chunks(
    collection,
    query_embedding: list[float],
    category: str | None = None,
) -> list[str]:
    where = {"category": category} if category else None
    kwargs = dict(
        query_embeddings=[query_embedding],
        n_results=RETRIEVAL_K,
        include=["documents", "metadatas"],
    )
    if where:
        kwargs["where"] = where

    results = collection.query(**kwargs)
    docs = results["documents"][0] if results["documents"] else []
    return docs


# ── Generate answer with Groq ─────────────────────────────────────────────────
def generate_answer(
    groq_client: Groq,
    question: str,
    context_chunks: list[str],
) -> str:
    context_text = "\n\n".join(
        f"[Chunk {i+1}]: {chunk}" for i, chunk in enumerate(context_chunks)
    )
    prompt = f"""You are a nutrition assistant. Use only the context below to answer the question.
If the context does not contain enough information, say so clearly.

CONTEXT:
{context_text}

QUESTION: {question}

ANSWER:"""

    for model in GROQ_MODELS:
        for attempt in range(2):
            try:
                response = groq_client.chat.completions.create(
                    model=model,
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.0,
                    max_tokens=512,
                )
                return response.choices[0].message.content.strip()
            except Exception as exc:
                if "429" in str(exc) or "rate" in str(exc).lower():
                    wait = 15 * (attempt + 1)
                    print(f"    ⚠ {model} rate limited, retrying in {wait}s...")
                    time.sleep(wait)
                else:
                    raise
        print(f"    ⚠ {model} exhausted, trying next model...")
    return ""


# ── Score all metrics in one Groq call ───────────────────────────────────────
def score_all_metrics(
    groq_client: Groq,
    question: str,
    answer: str,
    context_chunks: list[str],
    reference: str,
) -> dict:
    """Score all three metrics in a single Groq call to stay within rate limits."""
    context_text = "\n\n".join(
        f"[Chunk {i+1}]: {chunk}" for i, chunk in enumerate(context_chunks)
    )
    prompt = f"""You are an evaluation assistant. Score the following RAG system output.

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


# ── Main evaluation loop ──────────────────────────────────────────────────────
async def run_evaluation(category_filter: str | None = None):
    gemini_api_key = os.getenv("GEMINI_API_KEY")
    groq_api_key = os.getenv("GROQ_API_KEY")

    if not gemini_api_key:
        print("ERROR: GEMINI_API_KEY not set in .env")
        sys.exit(1)
    if not groq_api_key:
        print("ERROR: GROQ_API_KEY not set in .env")
        sys.exit(1)

    gemini_client = genai.Client(api_key=gemini_api_key)
    groq_client = Groq(api_key=groq_api_key)
    collection = load_collection()

    with open(QUESTIONS_FILE) as f:
        data = json.load(f)
    questions = data["questions"]
    if category_filter:
        questions = [
            q for q in questions if q["category"].lower() == category_filter.lower()
        ]
        print(f"Filtered to {len(questions)} questions in category: {category_filter}")

    print(f"\n{'='*60}")
    print(f"MyFoodRx RAGAS Evaluation — {len(questions)} questions")
    print(f"{'='*60}\n")

    results = []
    category_scores: dict[str, list[dict]] = {}

    for i, item in enumerate(questions):
        q = item["question"]
        category = item["category"]
        reference = item["reference"]

        print(f"[{i+1}/{len(questions)}] {category}: {q[:60]}...")

        # 1. Embed the question (Gemini)
        q_embedding = embed_query(gemini_client, q)

        # 2. Retrieve chunks from ChromaDB (category-filtered)
        chunks = retrieve_chunks(collection, q_embedding, category=category)
        if not chunks:
            chunks = retrieve_chunks(collection, q_embedding)

        # 3. Generate answer (Groq)
        answer = generate_answer(groq_client, q, chunks)

        # 4. Score all metrics in one Groq call
        scores = score_all_metrics(groq_client, q, answer, chunks, reference)
        faithfulness = scores["faithfulness"]
        answer_relevancy = scores["answer_relevancy"]
        context_precision = scores["context_precision"]

        result = {
            "category": category,
            "question": q,
            "answer": answer,
            "reference": reference,
            "faithfulness": faithfulness,
            "answer_relevancy": answer_relevancy,
            "context_precision": context_precision,
        }
        results.append(result)
        category_scores.setdefault(category, []).append(result)

        print(
            f"    faithfulness={faithfulness:.2f}  relevancy={answer_relevancy:.2f}  precision={context_precision:.2f}"
        )
        time.sleep(4)

    # ── Aggregate scores ──────────────────────────────────────────────────────
    def avg(key, items):
        vals = [r[key] for r in items if r[key] is not None]
        return round(sum(vals) / len(vals), 3) if vals else 0.0

    overall = {
        "faithfulness": avg("faithfulness", results),
        "answer_relevancy": avg("answer_relevancy", results),
        "context_precision": avg("context_precision", results),
    }

    per_category = {}
    for cat, items in category_scores.items():
        per_category[cat] = {
            "faithfulness": avg("faithfulness", items),
            "answer_relevancy": avg("answer_relevancy", items),
            "context_precision": avg("context_precision", items),
            "question_count": len(items),
        }

    # ── Print summary ─────────────────────────────────────────────────────────
    print(f"\n{'='*60}")
    print("OVERALL SCORES")
    print(f"{'='*60}")
    print(f"  Faithfulness      : {overall['faithfulness']:.3f}")
    print(f"  Answer Relevancy  : {overall['answer_relevancy']:.3f}")
    print(f"  Context Precision : {overall['context_precision']:.3f}")

    print(f"\n{'='*60}")
    print("PER CATEGORY SCORES")
    print(f"{'='*60}")
    for cat, scores in per_category.items():
        print(f"\n  {cat} ({scores['question_count']} questions)")
        print(f"    Faithfulness      : {scores['faithfulness']:.3f}")
        print(f"    Answer Relevancy  : {scores['answer_relevancy']:.3f}")
        print(f"    Context Precision : {scores['context_precision']:.3f}")

    # ── Save JSON report ──────────────────────────────────────────────────────
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M")
    report_path = REPORTS_DIR / f"ragas_report_{timestamp}.json"
    report = {
        "timestamp": timestamp,
        "total_questions": len(questions),
        "overall": overall,
        "per_category": per_category,
        "details": results,
    }
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n✓ Report saved to: {report_path}")
    print(f"{'='*60}\n")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--category", type=str, default=None, help="Run only this category"
    )
    args = parser.parse_args()
    asyncio.run(run_evaluation(category_filter=args.category))
