from datetime import datetime, timezone
from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException

from app.database import get_database
from app.deps import get_current_user_id

router = APIRouter(prefix="/recipes", tags=["recipes"])
SAVED = "saved_recipes"
COOKED = "cooked_recipes"
PREPARED = "prepared_recipes"


@router.get("/saved")
async def get_saved(user_id: str = Depends(get_current_user_id)):
    db = await get_database()
    cursor = db[SAVED].find({"userId": user_id})
    docs = await cursor.to_list(length=None)
    return [{"recipeId": d.get("recipeId"), "recipe": d.get("recipe"), "savedAt": d.get("savedAt")} for d in docs]


@router.post("/saved")
async def save_recipe(body: dict, user_id: str = Depends(get_current_user_id)):
    """Body: { recipeId, recipe (full recipe object) }."""
    db = await get_database()
    recipe = body.get("recipe") or body
    recipe_id = body.get("recipeId") or recipe.get("id")
    if recipe_id is None:
        raise HTTPException(status_code=400, detail="recipeId or recipe.id required")
    now = datetime.now(timezone.utc).isoformat()
    await db[SAVED].update_one(
        {"userId": user_id, "recipeId": recipe_id},
        {"$set": {"userId": user_id, "recipeId": recipe_id, "recipe": recipe, "savedAt": now}},
        upsert=True,
    )
    return {"ok": True}


@router.delete("/saved/{recipe_id}")
async def unsave_recipe(
    recipe_id: str,
    user_id: str = Depends(get_current_user_id),
):
    try:
        rid = int(recipe_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="recipe_id must be integer")
    db = await get_database()
    result = await db[SAVED].delete_one({"userId": user_id, "recipeId": rid})
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Saved recipe not found")
    return {"ok": True}


@router.post("/cooked")
async def cook_recipe(body: dict, user_id: str = Depends(get_current_user_id)):
    """Body: { recipeId, recipe }."""
    db = await get_database()
    recipe = body.get("recipe") or body
    recipe_id = body.get("recipeId") or recipe.get("id")
    if recipe_id is None:
        raise HTTPException(status_code=400, detail="recipeId or recipe.id required")
    now = datetime.now(timezone.utc).isoformat()
    await db[COOKED].insert_one({
        "userId": user_id,
        "recipeId": recipe_id,
        "recipe": recipe,
        "cookedAt": now,
    })
    return {"ok": True}


@router.post("/prepared/cook")
async def prepared_cook(body: dict, user_id: str = Depends(get_current_user_id)):
    """
    Body: recipeId, recipe, totalServings (float), consumedServings (float).
    Stores or updates prepared recipe with remaining servings (leftover).
    """
    db = await get_database()
    recipe = body.get("recipe") or body
    recipe_id = body.get("recipeId") or recipe.get("id")
    if recipe_id is None:
        raise HTTPException(status_code=400, detail="recipeId or recipe.id required")
    try:
        total = float(body.get("totalServings"))
        consumed = float(body.get("consumedServings"))
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="totalServings and consumedServings must be numbers",
        )
    remaining = max(0.0, total - consumed)
    now = datetime.now(timezone.utc).isoformat()
    coll = db[PREPARED]
    existing = await coll.find_one({"userId": user_id, "recipeId": recipe_id})
    if existing:
        prev_remaining = float(existing.get("remainingServings") or 0.0)
        prev_total = float(existing.get("totalServings") or 0.0)
        prev_consumed = float(existing.get("consumedServings") or 0.0)
        new_remaining = prev_remaining + remaining
        new_total = prev_total + total
        new_consumed = prev_consumed + consumed
        await coll.update_one(
            {"_id": existing["_id"]},
            {
                "$set": {
                    "recipe": recipe,
                    "totalServings": new_total,
                    "consumedServings": new_consumed,
                    "remainingServings": new_remaining,
                    "updatedAt": now,
                }
            },
        )
        remaining = new_remaining
    else:
        await coll.insert_one(
            {
                "userId": user_id,
                "recipeId": recipe_id,
                "recipe": recipe,
                "totalServings": total,
                "consumedServings": consumed,
                "remainingServings": remaining,
                "createdAt": now,
                "updatedAt": now,
            }
        )
    return {"ok": True, "remainingServings": remaining}


@router.post("/prepared/consume")
async def prepared_consume(body: dict, user_id: str = Depends(get_current_user_id)):
    """
    Body: recipeId, servingsConsumed (float).
    Decreases remaining servings for that prepared recipe.
    """
    db = await get_database()
    recipe_id = body.get("recipeId")
    if recipe_id is None:
        raise HTTPException(status_code=400, detail="recipeId is required")
    try:
        servings = float(body.get("servingsConsumed"))
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail="servingsConsumed must be a number",
        )
    coll = db[PREPARED]
    doc = await coll.find_one({"userId": user_id, "recipeId": recipe_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Prepared recipe not found")
    remaining = float(doc.get("remainingServings") or 0.0)
    if remaining <= 0:
        raise HTTPException(status_code=400, detail="No servings remaining")
    used = min(servings, remaining)
    new_remaining = remaining - used
    new_consumed = float(doc.get("consumedServings") or 0.0) + used
    now = datetime.now(timezone.utc).isoformat()
    await coll.update_one(
        {"_id": doc["_id"]},
        {
            "$set": {
                "remainingServings": new_remaining,
                "consumedServings": new_consumed,
                "updatedAt": now,
            }
        },
    )
    return {"ok": True, "remainingServings": new_remaining, "used": used}


@router.get("/prepared")
async def get_prepared(user_id: str = Depends(get_current_user_id)):
    """List prepared recipes that have remaining servings (leftover)."""
    db = await get_database()
    cursor = db[PREPARED].find(
        {"userId": user_id, "remainingServings": {"$gt": 0}}
    )
    docs = await cursor.to_list(length=None)
    return [
        {
            "id": str(d.get("_id")),
            "recipeId": d.get("recipeId"),
            "recipe": d.get("recipe"),
            "totalServings": d.get("totalServings"),
            "consumedServings": d.get("consumedServings"),
            "remainingServings": d.get("remainingServings"),
            "createdAt": d.get("createdAt"),
            "updatedAt": d.get("updatedAt"),
        }
        for d in docs
    ]
