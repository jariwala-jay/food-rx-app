from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Body, Depends, Header, HTTPException, Query

from app.config import settings
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


def _parse_iso_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        v = value.strip()
        if v.endswith("Z"):
            v = v[:-1] + "+00:00"
        return datetime.fromisoformat(v)
    except Exception:
        return None


def _require_reset_secret(x_reset_secret: str | None = Header(None, alias="X-Reset-Secret")):
    """Require a shared secret for reset endpoints. Set TRACKER_RESET_SECRET in .env."""
    if not settings.tracker_reset_secret:
        raise HTTPException(status_code=501, detail="Reset not configured (TRACKER_RESET_SECRET)")
    if not x_reset_secret or x_reset_secret != settings.tracker_reset_secret:
        raise HTTPException(status_code=403, detail="Invalid or missing X-Reset-Secret")
    return True


def _tracker_period_value(is_weekly: bool) -> str:
    return "weekly" if is_weekly else "daily"


async def _save_progress_snapshot_for_docs(db, trackers: list[dict], is_weekly: bool) -> int:
    """Persist tracker snapshots to tracker_progress before reset."""
    if not trackers:
        return 0
    now = datetime.now(timezone.utc).isoformat()
    period = _tracker_period_value(is_weekly)
    docs = []
    for t in trackers:
        achieved = float(t.get("currentValue") or 0.0)
        if achieved <= 0:
            continue
        tracker_id = t.get("_id")
        docs.append(
            {
                "_id": ObjectId(),
                "userId": t.get("userId"),
                "trackerId": str(tracker_id) if tracker_id is not None else "",
                "trackerName": t.get("name") or "",
                "trackerCategory": t.get("category") or "",
                "targetValue": float(t.get("goalValue") or 0.0),
                "achievedValue": achieved,
                "progressDate": now,
                "periodType": period,
                "dietType": t.get("dietType") or "",
                "unit": t.get("unit") or "",
                "createdAt": now,
            }
        )
    if docs:
        await db[PROGRESS].insert_many(docs)
    return len(docs)


async def _reset_trackers(
    db,
    *,
    is_weekly: bool,
    user_id: str | None = None,
    diet_type: str | None = None,
    dry_run: bool = False,
) -> dict:
    q = {"isWeeklyGoal": is_weekly}
    if user_id:
        q = {**q, **_user_match(user_id)}
    if diet_type:
        q["dietType"] = diet_type

    trackers = await db[TRACKERS].find(q).to_list(length=None)
    snapshots_saved = await _save_progress_snapshot_for_docs(db, trackers, is_weekly)
    tracker_count = len(trackers)

    if dry_run or tracker_count == 0:
        return {
            "ok": True,
            "period": _tracker_period_value(is_weekly),
            "trackersMatched": tracker_count,
            "snapshotsSaved": snapshots_saved,
            "trackersReset": 0,
            "dryRun": dry_run,
        }

    ids = [t["_id"] for t in trackers if "_id" in t]
    result = await db[TRACKERS].update_many(
        {"_id": {"$in": ids}},
        {"$set": {"currentValue": 0.0, "lastUpdated": datetime.now(timezone.utc).isoformat()}},
    )
    return {
        "ok": True,
        "period": _tracker_period_value(is_weekly),
        "trackersMatched": tracker_count,
        "snapshotsSaved": snapshots_saved,
        "trackersReset": result.modified_count,
        "dryRun": False,
    }


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
    start_dt = _parse_iso_datetime(startDate)
    end_dt = _parse_iso_datetime(endDate)

    # Use parsed date filtering/sorting so mixed ISO formats (with/without timezone)
    # are handled correctly and history charts stay accurate across time zones.
    if start_dt or end_dt:
        date_match = {}
        if start_dt:
            date_match["$gte"] = start_dt
        if end_dt:
            date_match["$lte"] = end_dt
        pipeline = [
            {"$match": q},
            {"$addFields": {"progressDateParsed": {"$toDate": "$progressDate"}}},
            {"$match": {"progressDateParsed": date_match}},
            {"$sort": {"progressDateParsed": -1}},
            {"$limit": 200},
        ]
        docs = await db[PROGRESS].aggregate(pipeline).to_list(length=200)
    else:
        # No explicit date bounds: still sort by parsed date for consistency.
        pipeline = [
            {"$match": q},
            {"$addFields": {"progressDateParsed": {"$toDate": "$progressDate"}}},
            {"$sort": {"progressDateParsed": -1}},
            {"$limit": 200},
        ]
        docs = await db[PROGRESS].aggregate(pipeline).to_list(length=200)
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


@router.post("/reset/daily")
async def reset_daily_trackers(
    body: dict | None = Body(default=None),
    _: bool = Depends(_require_reset_secret),
):
    """
    Reset daily trackers for all users or a filtered subset.
    Body (optional): { "userId": "...", "dietType": "DASH", "dryRun": true }
    Requires header: X-Reset-Secret: <TRACKER_RESET_SECRET from .env>.
    """
    db = await get_database()
    body = body or {}
    return await _reset_trackers(
        db,
        is_weekly=False,
        user_id=body.get("userId"),
        diet_type=body.get("dietType"),
        dry_run=bool(body.get("dryRun", False)),
    )


@router.post("/reset/weekly")
async def reset_weekly_trackers(
    body: dict | None = Body(default=None),
    _: bool = Depends(_require_reset_secret),
):
    """
    Reset weekly trackers for all users or a filtered subset.
    Body (optional): { "userId": "...", "dietType": "DASH", "dryRun": true }
    Requires header: X-Reset-Secret: <TRACKER_RESET_SECRET from .env>.
    """
    db = await get_database()
    body = body or {}
    return await _reset_trackers(
        db,
        is_weekly=True,
        user_id=body.get("userId"),
        diet_type=body.get("dietType"),
        dry_run=bool(body.get("dryRun", False)),
    )
