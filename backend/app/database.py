import certifi
from motor.motor_asyncio import AsyncIOMotorClient
from app.config import settings

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


async def close_database():
    global _client, _db
    if _client is not None:
        _client.close()
        _client = None
        _db = None
