from fastapi import APIRouter, Query

from app.database import get_database

router = APIRouter(prefix="/tips", tags=["tips"])
COLL = "tips"


def _serialize(doc: dict) -> dict:
    if not doc:
        return doc
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    return out


@router.get("")
async def get_tips(category: str | None = Query(None)):
    """Get tips. Optional category filter."""
    db = await get_database()
    q = {} if not category else {"category": category}
    cursor = db[COLL].find(q)
    docs = await cursor.to_list(length=None)
    return [_serialize(d) for d in docs]
