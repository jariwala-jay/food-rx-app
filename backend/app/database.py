import logging

import certifi
from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings
from app.refresh_tokens import ensure_refresh_token_indexes

logger = logging.getLogger(__name__)

_client: AsyncIOMotorClient | None = None
_db = None


async def get_database():
    global _client, _db
    if _db is not None:
        return _db
    if not settings.mongodb_url:
        raise RuntimeError("MONGODB_URL is not set")
    # Use certifi's CA bundle so SSL verification works on macOS (avoids
    # "unable to get local issuer certificate" with Python 3.13 / Atlas).
    _client = AsyncIOMotorClient(
        settings.mongodb_url,
        tls=True,
        tlsCAFile=certifi.where(),
        serverSelectionTimeoutMS=10000,
    )
    _db = _client.get_default_database()
    return _db


RAG_RESPONSE_CACHE_COLLECTION = "rag_response_cache"


async def ensure_database_indexes() -> None:
    """Idempotent index setup for hot paths (e.g. RAG response cache exact lookup)."""
    if not settings.mongodb_url:
        return
    try:
        db = await get_database()
    except Exception as exc:
        logger.warning("ensure_database_indexes: could not connect: %s", exc)
        return
    try:
        # Matches find_one on user_key + query_norm + condition_key (exact cache hit).
        await db[RAG_RESPONSE_CACHE_COLLECTION].create_index(
            [
                ("user_key", 1),
                ("query_norm", 1),
                ("condition_key", 1),
            ],
            name="rag_cache_user_query_condition",
        )
    except Exception as exc:
        logger.warning("ensure_database_indexes: rag_response_cache index: %s", exc)
    try:
        await ensure_refresh_token_indexes(db)
    except Exception as exc:
        logger.warning("ensure_database_indexes: refreshTokens index: %s", exc)


async def close_database():
    global _client, _db
    if _client is not None:
        _client.close()
        _client = None
        _db = None
