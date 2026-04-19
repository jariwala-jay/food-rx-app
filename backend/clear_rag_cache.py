#!/usr/bin/env python3
"""
Clear chatbot RAG caches in one command.

What it clears:
1) On-disk KB embedding cache files:
   - backend/app/knowledge/embeddings_cache.npy
   - backend/app/knowledge/embeddings_cache_meta.json
2) MongoDB response cache collection:
   - rag_response_cache

Usage:
  python3 backend/clear_rag_cache.py
  python3 backend/clear_rag_cache.py --skip-db
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path


BACKEND_ROOT = Path(__file__).resolve().parent
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.database import get_database
from app.services.rag_service import RAG_CACHE_COLLECTION


EMBED_CACHE_FILES = [
    BACKEND_ROOT / "app" / "knowledge" / "embeddings_cache.npy",
    BACKEND_ROOT / "app" / "knowledge" / "embeddings_cache_meta.json",
]


def _clear_embedding_cache_files() -> tuple[int, int]:
    deleted = 0
    missing = 0
    for path in EMBED_CACHE_FILES:
        if path.exists():
            path.unlink()
            deleted += 1
            print(f"deleted file: {path}")
        else:
            missing += 1
            print(f"missing file: {path}")
    return deleted, missing


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
        "--skip-embeddings",
        action="store_true",
        help="Skip deleting on-disk embedding cache files.",
    )
    args = parser.parse_args()

    print("== Clearing RAG caches ==")

    if not args.skip_embeddings:
        _clear_embedding_cache_files()
    else:
        print("skip embedding cache file deletion")

    if not args.skip_db:
        await _clear_mongo_response_cache()
    else:
        print("skip Mongo cache clear")

    print("== Done ==")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(_main()))
