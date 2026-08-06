import logging
from contextlib import asynccontextmanager
from bson import ObjectId
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse, Response
from pymongo.errors import AutoReconnect, ConnectionFailure, ServerSelectionTimeoutError

from app.database import ensure_database_indexes, get_database, close_database, reset_database
from app.routers import auth, chatbot, education, pantry, recipes, trackers, notifications, tips
from app.services.rag_service import rag_service

logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s %(name)s: %(message)s",
)
logging.getLogger("app").setLevel(logging.INFO)

logger = logging.getLogger(__name__)

_DB_UNAVAILABLE_DETAIL = (
    "Could not connect to the server. Check your internet connection and try again."
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_database()
    await ensure_database_indexes()
    await rag_service.initialize()
    yield
    await close_database()


app = FastAPI(
    title="Food Rx API",
    description="Backend API for Food Rx Flutter app. Replaces direct MongoDB access.",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def _mongo_connection_unavailable_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """Return 503 when Atlas is unreachable (e.g. device offline) instead of 500."""
    logger.warning(
        "Database unavailable for %s %s: %s",
        request.method,
        request.url.path,
        exc,
    )
    await reset_database()
    return JSONResponse(
        status_code=503,
        content={"detail": _DB_UNAVAILABLE_DETAIL},
    )


for _mongo_exc in (
    ServerSelectionTimeoutError,
    AutoReconnect,
    ConnectionFailure,
):
    app.add_exception_handler(_mongo_exc, _mongo_connection_unavailable_handler)

app.include_router(auth.router)
app.include_router(education.router)
app.include_router(pantry.router)
app.include_router(recipes.router)
app.include_router(trackers.router)
app.include_router(notifications.router)
app.include_router(tips.router)
app.include_router(chatbot.router)


@app.get("/")
async def root():
    return RedirectResponse(url="/docs")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/profile-photos/{photo_id}")
async def api_profile_photo(photo_id: str):
    """Serve profile photo by ID (used by Flutter profile photo URL)."""
    try:
        oid = ObjectId(photo_id)
    except Exception:
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Invalid photo id")
    db = await get_database()
    chunk = await db["profile_photos.chunks"].find_one({"files_id": oid})
    if not chunk or "data" not in chunk:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Photo not found")
    data = chunk["data"]
    return Response(content=bytes(data) if not isinstance(data, bytes) else data, media_type="image/jpeg")
