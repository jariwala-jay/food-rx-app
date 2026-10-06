import asyncio
import logging

import certifi
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo.errors import ConnectionFailure, InvalidOperation
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
SECURITY_EVENTS_COLLECTION = "security_events"


async def _ensure_rag_cache_index(db) -> None:
    # Matches find_one on user_key + query_norm + condition_key (exact cache hit).
    await db[RAG_RESPONSE_CACHE_COLLECTION].create_index(
        [
            ("user_key", 1),
            ("query_norm", 1),
            ("condition_key", 1),
        ],
        name="rag_cache_user_query_condition",
    )


async def _ensure_security_events_index(db) -> None:
    await db[SECURITY_EVENTS_COLLECTION].create_index(
        [("timestamp", -1), ("event_type", 1)],
        name="security_events_time_type",
    )


# Single list of startup index setup; add new collections here.
_INDEX_STEPS = (
    ("rag_response_cache", _ensure_rag_cache_index),
    ("security_events", _ensure_security_events_index),
    ("refreshTokens", ensure_refresh_token_indexes),
)

# Only connectivity failures can resolve themselves; InvalidOperation covers a
# client closed by reset_database() mid-task. Anything else (e.g. an index
# options conflict or duplicate data) is logged once and not retried.
_RETRYABLE = (ConnectionFailure, InvalidOperation)
_INDEX_RETRY_DELAYS = (5, 30, 120)


async def ensure_database_indexes() -> None:
    """Idempotent index setup for hot paths (e.g. RAG response cache exact lookup)."""
    if not settings.mongodb_url:
        return
    try:
        db = await get_database()
    except Exception as exc:
        logger.warning("ensure_database_indexes: could not connect: %s", exc)
        return
    for label, step in _INDEX_STEPS:
        try:
            await step(db)
        except Exception as exc:
            logger.warning("ensure_database_indexes: %s index: %s", label, exc)


async def ensure_indexes_in_background() -> None:
    """Runs off the readiness path so an unreachable Atlas can't stall startup.

    Never raises; the work is idempotent and nothing on the request path
    depends on these indexes existing.
    """
    if not settings.mongodb_url:
        return
    try:
        pending = list(_INDEX_STEPS)
        for delay in (0, *_INDEX_RETRY_DELAYS):
            if delay:
                await asyncio.sleep(delay)
            deferred = []
            for i, (label, step) in enumerate(pending):
                try:
                    await step(await get_database())
                except _RETRYABLE as exc:
                    # Atlas unreachable: the remaining steps would each wait out
                    # the full server-selection timeout too, so defer them all.
                    logger.warning("ensure_indexes: %s index unreachable, will retry: %s", label, exc)
                    deferred = pending[i:]
                    break
                except Exception as exc:
                    logger.warning("ensure_indexes: %s index: %s", label, exc)
            pending = deferred
            if not pending:
                logger.info("ensure_indexes: done")
                return
        logger.warning("ensure_indexes: gave up on %s", [label for label, _ in pending])
    except Exception:
        logger.exception("ensure_indexes: unexpected failure")


async def close_database():
    """Close the Mongo client and clear the cached database handle."""
    global _client, _db
    if _client is not None:
        _client.close()
        _client = None
        _db = None


async def reset_database() -> None:
    """Drop the cached connection so the next request opens a fresh client."""
    await close_database()
