from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/trackers", tags=["trackers"])
TRACKERS = "user_trackers"
PROGRESS = "tracker_progress"


def _user_match(user_id: str) -> dict:
    """Match userId whether stored as string or ObjectId (e.g. legacy MongoDB rows)."""
    if not user_id or len(user_id) != 24:
        return {"userId": user_id}
    try:
        return {"$or": [{"userId": user_id}, {"userId": ObjectId(user_id)}]}
    except Exception:
        return {"userId": user_id}


def _serialize_doc(doc: dict) -> dict:
    if not doc:
        return doc
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    for key in ("userId", "trackerId"):
        if key in out and hasattr(out.get(key), "binary"):
            out[key] = str(out[key])
    return out


@router.get("")
async def list_trackers(
    dietType: str | None = Query(None),
    isWeeklyGoal: bool | None = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    q = {**_user_match(user_id)}
    if dietType:
        q["dietType"] = dietType
    if isWeeklyGoal is not None:
        q["isWeeklyGoal"] = isWeeklyGoal
    cursor = db[TRACKERS].find(q)
    docs = await cursor.to_list(length=None)
    return [_serialize_doc(d) for d in docs]


@router.post("")
async def create_tracker(body: dict, user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    tid = ObjectId()
    now = datetime.now(timezone.utc).isoformat()
    doc = {"_id": tid, "userId": user_id, **body, "lastUpdated": now, "createdAt": now}
    await db[TRACKERS].insert_one(doc)
    return _serialize_doc(doc)


# Progress (must be before /{tracker_id} so "progress" is not matched as tracker_id)
@router.get("/progress")
async def get_progress(
    userId: str | None = Query(None),
    trackerId: str | None = Query(None),
    periodType: str | None = Query(None),
    startDate: str | None = Query(None, description="ISO date or datetime, inclusive"),
    endDate: str | None = Query(None, description="ISO date or datetime, inclusive"),
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    uid = userId or user_id
    q = {**_user_match(uid)}
    if trackerId:
        q["trackerId"] = trackerId
    if periodType:
        q["periodType"] = periodType
    if startDate or endDate:
        date_filter = {}
        if startDate:
            date_filter["$gte"] = startDate
        if endDate:
            date_filter["$lte"] = endDate
        q["progressDate"] = date_filter
    cursor = db[PROGRESS].find(q).sort("progressDate", -1)
    docs = await cursor.to_list(length=200)
    return [_serialize_doc(d) for d in docs]


@router.post("/progress")
async def save_progress(body: dict | list, user_id: str = Depends(get_current_user_id)):
    """Body: single progress doc or list of progress docs (snapshot)."""
    db = await get_database()
    now = datetime.now(timezone.utc)
    items = body if isinstance(body, list) else [body]
    docs = []
    for item in items:
        item = dict(item)
        item.setdefault("userId", user_id)
        item["_id"] = ObjectId()
        if "progressDate" not in item:
            item["progressDate"] = now.isoformat()
        docs.append(item)
    if docs:
        await db[PROGRESS].insert_many(docs)
    return {"ok": True, "count": len(docs)}


@router.get("/{tracker_id}")
async def get_tracker(
    tracker_id: str,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    try:
        oid = ObjectId(tracker_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid tracker id")
    doc = await db[TRACKERS].find_one({"_id": oid, **_user_match(user_id)})
    if not doc:
        raise HTTPException(status_code=404, detail="Tracker not found")
    return _serialize_doc(doc)


@router.patch("/{tracker_id}")
async def update_tracker(
    tracker_id: str,
    body: dict,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    now = datetime.now(timezone.utc).isoformat()
    updates = {**body, "lastUpdated": now}
    result = await db[TRACKERS].update_one(
        {"_id": ObjectId(tracker_id), **_user_match(user_id)},
        {"$set": updates},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Tracker not found")
    doc = await db[TRACKERS].find_one(
        {"_id": ObjectId(tracker_id), **_user_match(user_id)},
    )
    return _serialize_doc(doc)


@router.delete("/{tracker_id}")
async def delete_tracker(
    tracker_id: str,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    result = await db[TRACKERS].delete_one(
        {"_id": ObjectId(tracker_id), **_user_match(user_id)},
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Tracker not found")
    return {"ok": True}
