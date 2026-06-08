#!/usr/bin/env python3
"""
Clear chatbot RAG caches in one command.

What it clears:
1) ChromaDB vector store (backend/app/knowledge/chroma_db/)
   — delete this to force re-embedding on next startup
2) MongoDB response cache collection (rag_response_cache)

Usage:
  python3 backend/clear_rag_cache.py
  python3 backend/clear_rag_cache.py --skip-db
  python3 backend/clear_rag_cache.py --skip-chroma
"""

from __future__ import annotations

import argparse
import asyncio
import shutil
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.database import get_database
from app.services.rag_service import RAG_CACHE_COLLECTION

CHROMA_DIR = BACKEND_ROOT / "app" / "knowledge" / "chroma_db"


def _clear_chroma() -> None:
    if CHROMA_DIR.exists():
        shutil.rmtree(CHROMA_DIR)
        print(f"deleted ChromaDB vector store: {CHROMA_DIR}")
    else:
        print(f"ChromaDB not found (already clean): {CHROMA_DIR}")


async def _clear_mongo_response_cache() -> int | None:
    try:
        db = await get_database()
    except Exception as exc:
        print(f"skip Mongo cache clear: {exc}")
        return None
    try:
        result = await db[RAG_CACHE_COLLECTION].delete_many({})
        print(
            f"cleared Mongo collection '{RAG_CACHE_COLLECTION}': "
            f"deleted={result.deleted_count}"
        )
        return int(result.deleted_count)
    except Exception as exc:
        print(f"failed Mongo cache clear: {exc}")
        return None


async def _main() -> int:
    parser = argparse.ArgumentParser(description="Clear MyFoodRx RAG caches.")
    parser.add_argument(
        "--skip-db",
        action="store_true",
        help="Skip clearing MongoDB rag_response_cache.",
    )
    parser.add_argument(
        "--skip-chroma",
        action="store_true",
        help="Skip deleting ChromaDB vector store.",
    )
    args = parser.parse_args()

    print("== Clearing RAG caches ==")

    if not args.skip_chroma:
        _clear_chroma()
    else:
        print("skip ChromaDB deletion")

    if not args.skip_db:
        await _clear_mongo_response_cache()
    else:
        print("skip Mongo cache clear")

    print("== Done ==")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_main()))
