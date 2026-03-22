from contextlib import asynccontextmanager
from bson import ObjectId
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse, Response

from app.database import get_database, close_database
from app.routers import auth, education, pantry, recipes, trackers, notifications, tips


@asynccontextmanager
async def lifespan(app: FastAPI):
    await get_database()
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

app.include_router(auth.router)
app.include_router(education.router)
app.include_router(pantry.router)
app.include_router(recipes.router)
app.include_router(trackers.router)
app.include_router(notifications.router)
app.include_router(tips.router)


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
