from datetime import datetime
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query

from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/education", tags=["education"])
EDUCATIONAL = "educational_content"
USER_BOOKMARKS = "user_bookmarks"


def _make_json_serializable(obj):
    """Recursively convert MongoDB types (ObjectId, datetime) to JSON-serializable types."""
    if obj is None:
        return None
    if isinstance(obj, ObjectId):
        return str(obj)
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, dict):
        return {k: _make_json_serializable(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_make_json_serializable(v) for v in obj]
    return obj


def _serialize_doc(doc: dict) -> dict:
    if not doc:
        return doc
    return _make_json_serializable(doc)


@router.get("/articles")
async def get_articles(
    category: str | None = Query(None),
    userId: str | None = Query(None),
    bookmarksOnly: bool = Query(False),
    searchQuery: str | None = Query(None),
    user_id: str = Depends(get_current_user_id),
):
    """Get articles. Optionally filter by category, bookmarks, search."""
    db = await get_database()
    coll = db[EDUCATIONAL]
    uid = userId or user_id
    selector = {}
    if bookmarksOnly and uid:
        bookmarks = db[USER_BOOKMARKS]
        cursor = bookmarks.find({"userId": ObjectId(uid)})
        article_ids = [doc["articleId"] for doc in await cursor.to_list(length=None) if "articleId" in doc]
        selector["_id"] = {"$in": [ObjectId(aid) if isinstance(aid, str) else aid for aid in article_ids]}
    elif category and category != "All":
        selector["category"] = category
    if searchQuery:
        selector["title"] = {"$regex": searchQuery, "$options": "i"}
    cursor = coll.find(selector)
    articles = await cursor.to_list(length=None)
    out = [_serialize_doc(a) for a in articles]
    if uid:
        bookmarks = db[USER_BOOKMARKS]
        cursor = bookmarks.find({"userId": ObjectId(uid)})
        bookmarked_ids = {str(doc["articleId"]) for doc in await cursor.to_list(length=None) if "articleId" in doc}
        for a in out:
            a["isBookmarked"] = a.get("_id") in bookmarked_ids
    return out


@router.get("/categories")
async def get_categories():
    """Get distinct categories from educational content."""
    db = await get_database()
    values = await db[EDUCATIONAL].distinct("category")
    return [{"name": v} for v in sorted(values) if v]


@router.put("/articles/{article_id}/bookmark")
async def set_article_bookmark(
    article_id: str,
    body: dict,
    user_id: str = Depends(get_current_user_id),
):
    """Set bookmark. Body: { \"isBookmarked\": true|false }."""
    db = await get_database()
    bookmarks = db[USER_BOOKMARKS]
    uid = ObjectId(user_id)
    aid = ObjectId(article_id)
    is_bookmarked = body.get("isBookmarked", False)
    if is_bookmarked:
        await bookmarks.update_one(
            {"userId": uid, "articleId": aid},
            {"$set": {"userId": uid, "articleId": aid, "savedAt": __import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()}},
            upsert=True,
        )
    else:
        await bookmarks.delete_one({"userId": uid, "articleId": aid})
    return {"ok": True}
