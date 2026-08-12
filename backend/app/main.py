import asyncio
import logging
from contextlib import asynccontextmanager
from bson import ObjectId
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, RedirectResponse, Response
from pymongo.errors import AutoReconnect, ConnectionFailure, ServerSelectionTimeoutError
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

from app.database import ensure_database_indexes, get_database, close_database, reset_database
from app.deps import get_current_user_id
from app.rate_limit import limiter, rate_limit_exceeded_handler
from app.routers import auth, chatbot, education, pantry, recipes, trackers, notifications, tips, well_known
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
    # Loading chromadb + embeddings is slow (multi-second) and only the chatbot
    # needs it — run it in the background so auth/pantry/tracker requests aren't
    # blocked behind it on a cold start. rag_service.chat() already degrades
    # gracefully (self._ready check) if hit before this finishes.
    asyncio.create_task(rag_service.initialize())
    yield
    await close_database()


app = FastAPI(
    title="Food Rx API",
    description="Backend API for Food Rx Flutter app. Replaces direct MongoDB access.",
    version="0.1.0",
    lifespan=lifespan,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# The Flutter app authenticates with a Bearer JWT (Authorization header), not
# cookies, so allow_credentials brings no functional benefit here — and
# combining it with a wildcard origin is a known anti-pattern (it defeats the
# purpose of an origin allowlist for any credentialed request). CORS itself
# only matters for the handful of browser-rendered surfaces this API serves
# (Swagger UI, the password-reset bridge page); the Flutter HTTP client
# ignores CORS entirely.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
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
app.include_router(well_known.router)


@app.get("/")
async def root():
    return RedirectResponse(url="/docs")


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/api/profile-photos/{photo_id}")
async def api_profile_photo(photo_id: str, user_id: str = Depends(get_current_user_id)):
    """Serve profile photo by ID. Every current caller only ever fetches its
    own photo (see AuthController's home-page/avatar loaders), so this is
    scoped to the caller's own profilePhotoId rather than any ID reachable by
    a logged-in user — photo IDs are ordinary (guessable) ObjectIds, not
    capability tokens."""
    try:
        oid = ObjectId(photo_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid photo id")
    db = await get_database()
    owner = await db["users"].find_one({"_id": ObjectId(user_id), "profilePhotoId": photo_id})
    if not owner:
        raise HTTPException(status_code=404, detail="Photo not found")
    chunk = await db["profile_photos.chunks"].find_one({"files_id": oid})
    if not chunk or "data" not in chunk:
        raise HTTPException(status_code=404, detail="Photo not found")
    data = chunk["data"]
    return Response(content=bytes(data) if not isinstance(data, bytes) else data, media_type="image/jpeg")
