from datetime import datetime, timezone, timedelta
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/pantry", tags=["pantry"])
PANTRY = "pantry_items"


def _serialize_item(doc: dict) -> dict:
    if not doc:
        return doc
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    if "userId" in out and hasattr(out.get("userId"), "binary"):
        out["userId"] = str(out["userId"])
    return out


@router.get("/items")
async def get_items(
    isPantryItem: bool | None = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    """Get pantry items for current user. Optional isPantryItem filter."""
    db = await get_database()
    q = {"userId": ObjectId(user_id)}
    if isPantryItem is not None:
        q["isPantryItem"] = isPantryItem
    cursor = db[PANTRY].find(q)
    items = await cursor.to_list(length=None)
    return [_serialize_item(i) for i in items]


@router.post("/items")
async def add_item(body: dict, user_id: str = Depends(get_current_user_id)):
    """Add pantry item. Returns id."""
    db = await get_database()
    item_id = ObjectId()
    now = datetime.now(timezone.utc).isoformat()
    doc = {
        "_id": item_id,
        "userId": ObjectId(user_id),
        **body,
        "addedDate": now,
        "updatedAt": now,
    }
    await db[PANTRY].insert_one(doc)
    return {"id": str(item_id)}


@router.patch("/items/{item_id}")
async def update_item(
    item_id: str,
    body: dict,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    now = datetime.now(timezone.utc).isoformat()
    updates = {**body, "updatedAt": now}
    result = await db[PANTRY].update_one(
        {"_id": ObjectId(item_id), "userId": ObjectId(user_id)},
        {"$set": updates},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"ok": True}


@router.delete("/items/{item_id}")
async def delete_item(
    item_id: str,
    user_id: str = Depends(get_current_user_id),
):
    db = await get_database()
    result = await db[PANTRY].delete_one(
        {"_id": ObjectId(item_id), "userId": ObjectId(user_id)},
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"ok": True}


@router.get("/expiring")
async def get_expiring(
    daysThreshold: int = 7,
    user_id: str = Depends(get_current_user_id),
):
    """Get items expiring within daysThreshold."""
    db = await get_database()
    threshold = (datetime.now(timezone.utc) + timedelta(days=daysThreshold)).isoformat()
    cursor = db[PANTRY].find({
        "userId": ObjectId(user_id),
        "expiryDate": {"$exists": True, "$ne": None, "$lte": threshold},
    })
    items = await cursor.to_list(length=None)
    return [_serialize_item(i) for i in items]
