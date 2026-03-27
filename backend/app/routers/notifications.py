from datetime import datetime, timedelta, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, Header, HTTPException

from app.config import settings
from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/notifications", tags=["notifications"])
COLL = "notifications"
USERS = "users"


def _serialize(doc: dict) -> dict:
    if not doc:
        return doc
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    if "userId" in out and hasattr(out.get("userId"), "binary"):
        out["userId"] = str(out["userId"])
    return out


def _user_match(user_id: str):
    """Match userId whether stored as string or ObjectId (e.g. from manual MongoDB insert)."""
    if not user_id or len(user_id) != 24:
        return {"userId": user_id}
    try:
        return {"$or": [{"userId": user_id}, {"userId": ObjectId(user_id)}]}
    except Exception:
        return {"userId": user_id}


@router.get("")
async def list_notifications(user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    q = _user_match(user_id)
    cursor = db[COLL].find(q).sort("createdAt", -1).limit(50)
    docs = await cursor.to_list(length=None)
    return [_serialize(d) for d in docs]


@router.post("")
async def create_notification(body: dict, user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    users = db[USERS]
    type_ = body.get("type") or "info"
    title = body.get("title") or ""
    message = body.get("message") or ""
    dedupe_raw = body.get("dedupeWindowHours")
    dedupe_hours = 24 if dedupe_raw is None else int(dedupe_raw)
    send_push = bool(body.get("sendPush", False))

    if type_ in ("admin", "education"):
        cutoff = (datetime.now(timezone.utc) - timedelta(hours=dedupe_hours)).isoformat()
        existing = await db[COLL].find_one(
            {
                **_user_match(user_id),
                "type": type_,
                "title": title,
                "message": message,
                "createdAt": {"$gte": cutoff},
            }
        )
        if existing:
            return _serialize(dict(existing))

    nid = ObjectId()
    now = datetime.now(timezone.utc).isoformat()
    clean = dict(body)
    clean.pop("dedupeWindowHours", None)
    clean.pop("sendPush", None)
    doc = {"_id": nid, "userId": user_id, **clean, "createdAt": now}
    await db[COLL].insert_one(doc)
    if send_push:
        push_updates = {"pushStatus": "skipped", "pushAttemptedAt": datetime.now(timezone.utc).isoformat()}
        try:
            user = await users.find_one({"_id": ObjectId(user_id)})
            token = (user or {}).get("fcmToken")
            if token:
                from app.push import send_push_to_fcm_token

                result = await send_push_to_fcm_token(
                    token=str(token),
                    title=title or "MyFoodRx",
                    body=message or "",
                    data={"type": str(type_), "deeplink": "notifications"},
                )
                if result.get("ok"):
                    push_updates["pushStatus"] = "sent"
                    if result.get("messageId"):
                        push_updates["pushMessageId"] = str(result.get("messageId"))
                else:
                    push_updates["pushStatus"] = "failed"
                    # Keep errors small and safe for debugging in app/admin views.
                    push_updates["pushError"] = str(result.get("error", "unknown_error"))[:500]
            else:
                push_updates["pushError"] = "missing_fcm_token"
        except Exception:
            push_updates["pushStatus"] = "failed"
            push_updates["pushError"] = "push_send_exception"
        await db[COLL].update_one({"_id": nid}, {"$set": push_updates})
        doc.update(push_updates)
    return _serialize(doc)


@router.patch("/{notification_id}/read")
async def mark_read(
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    now = datetime.now(timezone.utc).isoformat()
    user_q = _user_match(user_id)
    filter_q = {"_id": ObjectId(notification_id), **user_q}
    result = await db[COLL].update_one(
        filter_q,
        {"$set": {"readAt": now}},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"ok": True}


@router.post("/mark-all-read")
async def mark_all_read(user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    now = datetime.now(timezone.utc).isoformat()
    await db[COLL].update_many(
        _user_match(user_id),
        {"$set": {"readAt": now}},
    )
    return {"ok": True}


@router.delete("/{notification_id}")
async def delete_notification(
    notification_id: str,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    user_q = _user_match(user_id)
    filter_q = {"_id": ObjectId(notification_id), **user_q}
    result = await db[COLL].delete_one(filter_q)
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"ok": True}


@router.delete("")
async def delete_all_notifications(user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    await db[COLL].delete_many(_user_match(user_id))
    return {"ok": True}


def _require_broadcast_secret(x_broadcast_secret: str | None = Header(None, alias="X-Broadcast-Secret")):
    """Require a shared secret to call broadcast. Set BROADCAST_SECRET in .env."""
    if not settings.broadcast_secret:
        raise HTTPException(status_code=501, detail="Broadcast not configured (BROADCAST_SECRET)")
    if not x_broadcast_secret or x_broadcast_secret != settings.broadcast_secret:
        raise HTTPException(status_code=403, detail="Invalid or missing X-Broadcast-Secret")
    return True


@router.post("/broadcast")
async def broadcast_notification(
    body: dict,
    _: bool = Depends(_require_broadcast_secret),
):
    """
    Create the same notification for every user. For admin/cron use.
    Body: { "title", "message", "type" (optional, default "admin") }.
    Requires header: X-Broadcast-Secret: <BROADCAST_SECRET from .env>.
    """
    db = await get_database()
    title = body.get("title") or "Update"
    message = body.get("message") or ""
    type_ = body.get("type") or "admin"
    now = datetime.now(timezone.utc).isoformat()
    dedupe_hours = int(body.get("dedupeWindowHours", 24))
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=dedupe_hours)).isoformat()

    cursor = db[USERS].find({}, {"_id": 1})
    user_ids = [str(doc["_id"]) for doc in await cursor.to_list(length=None)]
    inserted = 0
    skipped = 0
    for uid in user_ids:
        if type_ in ("admin", "education"):
            existing = await db[COLL].find_one(
                {
                    **_user_match(uid),
                    "type": type_,
                    "title": title,
                    "message": message,
                    "createdAt": {"$gte": cutoff},
                }
            )
            if existing:
                skipped += 1
                continue
        await db[COLL].insert_one({
            "_id": ObjectId(),
            "userId": uid,
            "type": type_,
            "title": title,
            "message": message,
            "createdAt": now,
        })
        inserted += 1
    return {
        "ok": True,
        "usersNotified": inserted,
        "usersSkippedDuplicate": skipped,
    }
