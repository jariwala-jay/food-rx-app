from datetime import datetime

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, model_validator

from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/tips", tags=["tips"])
COLL = "tips"


def _tip_id_filter(tip_id: str) -> dict:
    """Match tips by string `id`, string `_id`, or ObjectId `_id`."""
    clauses: list[dict] = [{"id": tip_id}, {"_id": tip_id}]
    try:
        oid = ObjectId(tip_id)
        clauses.append({"_id": oid})
    except Exception:
        pass
    return {"$or": clauses}


def _serialize(doc: dict) -> dict:
    if not doc:
        return doc
    out = dict(doc)
    if "_id" in out:
        oid = str(out["_id"])
        out["_id"] = oid
        # Flutter Tip model expects `id` (not only Mongo `_id`).
        if "id" not in out:
            out["id"] = oid
    return out


@router.get("")
async def get_tips(category: str | None = Query(None)):
    """Get tips. Optional category filter."""
    db = await get_database()
    q = {} if not category else {"category": category}
    cursor = db[COLL].find(q)
    docs = await cursor.to_list(length=None)
    return [_serialize(d) for d in docs]


class TipEngagementPatch(BaseModel):
    """Update only the authenticated user's engagement fields on a tip."""

    lastShownAt: str | None = None
    viewCount: int | None = None

    @model_validator(mode="after")
    def require_field(self):
        if self.lastShownAt is None and self.viewCount is None:
            raise ValueError("Provide lastShownAt and/or viewCount")
        return self


@router.patch("/{tip_id}")
async def patch_tip_engagement(
    tip_id: str,
    body: TipEngagementPatch,
    user_id: str = Depends(get_current_user_id),
):
    """Merge lastShownToUsers / viewCountByUser for the current user only."""
    db = await get_database()
    flt = _tip_id_filter(tip_id)
    exists = await db[COLL].find_one(flt, projection={"_id": 1})
    if not exists:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tip not found")

    set_fields: dict = {}
    if body.lastShownAt is not None:
        try:
            # fromisoformat handles "2026-04-09T12:00:00.000" from Dart
            raw = body.lastShownAt.replace("Z", "+00:00")
            dt = datetime.fromisoformat(raw)
        except ValueError as e:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Invalid lastShownAt: {e}",
            ) from e
        set_fields[f"lastShownToUsers.{user_id}"] = dt
    if body.viewCount is not None:
        if body.viewCount < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="viewCount must be >= 0",
            )
        set_fields[f"viewCountByUser.{user_id}"] = body.viewCount

    await db[COLL].update_one(flt, {"$set": set_fields})
    doc = await db[COLL].find_one(flt)
    return _serialize(doc)
