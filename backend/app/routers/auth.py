from datetime import datetime, timezone, timedelta
import base64
import hashlib
import secrets
from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import Response

from app.database import get_database
from app.auth_password import hash_password, verify_password
from app.auth_jwt import create_access_token
from app.deps import get_current_user_id

router = APIRouter(prefix="/auth", tags=["auth"])

USERS = "users"
PASSWORD_RESET_TOKENS = "passwordResetTokens"
PROFILE_PHOTOS_FILES = "profile_photos.files"
PROFILE_PHOTOS_CHUNKS = "profile_photos.chunks"
LOCK_THRESHOLD = 5
LOCK_MINUTES = 30


def _serialize_user(doc: dict) -> dict:
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    return out


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


@router.post("/check-email")
async def check_email(body: dict):
    """
    Check if an email is already registered. Body: { "email": "user@example.com" }.
    Returns { "exists": true } or { "exists": false }. No auth required.
    """
    db = await get_database()
    users = db[USERS]
    email = (body.get("email") or "").strip().lower()
    if not email:
        return {"exists": False}
    existing = await users.find_one({"email": email})
    return {"exists": existing is not None}


@router.post("/register")
async def register(body: dict):
    """
    Register a new user. Body must include: email, password.
    Any other keys (firstName, lastName, dietType, etc.) are stored as user profile.
    """
    db = await get_database()
    users = db[USERS]
    email = (body.get("email") or "").strip().lower()
    password = body.get("password")
    if not email or not password:
        raise HTTPException(status_code=400, detail="email and password required")

    existing = await users.find_one({"email": email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = ObjectId()
    now = datetime.now(timezone.utc).isoformat()
    user_doc = {
        "_id": user_id,
        "email": email,
        "password": hash_password(password),
        "createdAt": now,
        "updatedAt": now,
        "lastLoginAt": None,
        "failedLoginAttempts": 0,
        "isLocked": False,
        "lockUntil": None,
    }
    allowed = {
        "firstName", "lastName", "name", "age", "dateOfBirth", "sex",
        "height", "heightUnit", "heightFeet", "heightInches", "weight", "weightUnit",
        "activityLevel", "medicalConditions", "allergies", "dietType", "myPlanType",
        "showGlycemicIndex", "excludedIngredients", "foodRestrictions", "favoriteCuisines",
        "dailyFruitIntake", "dailyVegetableIntake", "dailyWaterIntake",
        "preferredMealPrepTime", "cookingForPeople", "cookingSkill",
        "selectedDietPlan", "targetCalories", "macroNutrients", "mealTimings",
        "requiresGroceryList", "diagnostics", "healthGoals", "hasCompletedTour",
    }
    for key, value in body.items():
        if key in allowed and key not in user_doc:
            user_doc[key] = value
    if "profilePhotoId" in body:
        user_doc["profilePhotoId"] = body["profilePhotoId"]

    await users.insert_one(user_doc)

    # Create welcome notification for the new user
    notifications = db["notifications"]
    await notifications.insert_one({
        "_id": ObjectId(),
        "userId": str(user_id),
        "type": "admin",
        "title": "Welcome to MyFoodRx",
        "message": "We're glad you're here. Start by adding items to your pantry!",
        "createdAt": now,
    })

    token = create_access_token(str(user_id))
    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": str(user_id),
        "email": email,
        "user": _serialize_user(user_doc),
    }


@router.post("/login")
async def login(body: dict):
    """Login with email and password. Returns JWT and user."""
    db = await get_database()
    users = db[USERS]
    email = (body.get("email") or "").strip().lower()
    password = body.get("password")
    if not email or not password:
        raise HTTPException(status_code=400, detail="email and password required")

    user = await users.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if user.get("isLocked"):
        lock_until = user.get("lockUntil")
        if lock_until:
            try:
                until = datetime.fromisoformat(lock_until.replace("Z", "+00:00"))
                if until > datetime.now(timezone.utc):
                    raise HTTPException(
                        status_code=403,
                        detail="Account temporarily locked. Try again later.",
                    )
            except (ValueError, TypeError):
                pass

    if not verify_password(password, user.get("password") or ""):
        await _handle_failed_login(users, user["_id"])
        raise HTTPException(status_code=401, detail="Invalid email or password")

    await _handle_successful_login(users, user["_id"])
    token = create_access_token(str(user["_id"]))
    return {
        "access_token": token,
        "token_type": "bearer",
        "user_id": str(user["_id"]),
        "email": user["email"],
        "user": _serialize_user(user),
    }


async def _handle_failed_login(users, user_id: ObjectId):
    now = datetime.now(timezone.utc).isoformat()
    await users.update_one(
        {"_id": user_id},
        {"$inc": {"failedLoginAttempts": 1}, "$set": {"updatedAt": now}},
    )
    u = await users.find_one({"_id": user_id})
    if u and u.get("failedLoginAttempts", 0) >= LOCK_THRESHOLD:
        from datetime import timedelta
        lock_until = (datetime.now(timezone.utc) + timedelta(minutes=LOCK_MINUTES)).isoformat()
        await users.update_one(
            {"_id": user_id},
            {"$set": {"isLocked": True, "lockUntil": lock_until, "updatedAt": now}},
        )


async def _handle_successful_login(users, user_id: ObjectId):
    now = datetime.now(timezone.utc).isoformat()
    await users.update_one(
        {"_id": user_id},
        {
            "$set": {
                "failedLoginAttempts": 0,
                "isLocked": False,
                "lockUntil": None,
                "lastLoginAt": now,
                "updatedAt": now,
            }
        },
    )


@router.get("/me")
async def me(user_id: str = Depends(get_current_user_id)):
    """Return current user by JWT. Flutter can use this to restore session."""
    db = await get_database()
    users = db[USERS]
    if len(user_id) != 24:
        raise HTTPException(status_code=401, detail="Invalid user id")
    user = await users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return _serialize_user(user)


@router.patch("/profile")
async def update_profile(body: dict, user_id: str = Depends(get_current_user_id)):
    """Update current user profile. Body: any allowed user fields."""
    db = await get_database()
    users = db[USERS]
    if len(user_id) != 24:
        raise HTTPException(status_code=401, detail="Invalid user id")
    allowed = {
        "firstName", "lastName", "name", "age", "dateOfBirth", "sex",
        "height", "heightUnit", "heightFeet", "heightInches", "weight", "weightUnit",
        "activityLevel", "medicalConditions", "allergies", "dietType", "myPlanType",
        "showGlycemicIndex", "excludedIngredients", "foodRestrictions", "favoriteCuisines",
        "dailyFruitIntake", "dailyVegetableIntake", "dailyWaterIntake",
        "preferredMealPrepTime", "cookingForPeople", "cookingSkill",
        "selectedDietPlan", "targetCalories", "macroNutrients", "mealTimings",
        "requiresGroceryList", "diagnostics", "healthGoals", "hasCompletedTour", "profilePhotoId",
        "fcmToken",
    }
    updates = {k: v for k, v in body.items() if k in allowed}
    if not updates:
        return {"ok": True}
    updates["updatedAt"] = datetime.now(timezone.utc).isoformat()
    await users.update_one({"_id": ObjectId(user_id)}, {"$set": updates})
    user = await users.find_one({"_id": ObjectId(user_id)})
    return _serialize_user(user)


@router.post("/profile-photo")
async def upload_profile_photo(
    file: UploadFile = File(...),
    user_id: str = Depends(get_current_user_id),
):
    """Upload profile photo. Returns profilePhotoId."""
    db = await get_database()
    content = await file.read()
    photo_id = ObjectId()
    files = db[PROFILE_PHOTOS_FILES]
    chunks = db[PROFILE_PHOTOS_CHUNKS]
    await files.insert_one({
        "_id": photo_id,
        "filename": f"profile_photo_{photo_id}.jpg",
        "contentType": file.content_type or "image/jpeg",
        "length": len(content),
        "uploadDate": datetime.now(timezone.utc).isoformat(),
    })
    await chunks.insert_one({"files_id": photo_id, "n": 0, "data": content})
    await db[USERS].update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"profilePhotoId": str(photo_id), "updatedAt": datetime.now(timezone.utc).isoformat()}},
    )
    return {"profilePhotoId": str(photo_id)}


@router.get("/profile-photos/{photo_id}")
async def get_profile_photo(photo_id: str):
    """Return profile photo bytes (image/jpeg)."""
    db = await get_database()
    try:
        oid = ObjectId(photo_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid photo id")
    chunk = await db[PROFILE_PHOTOS_CHUNKS].find_one({"files_id": oid})
    if not chunk or "data" not in chunk:
        raise HTTPException(status_code=404, detail="Photo not found")
    data = chunk["data"]
    if isinstance(data, bytes):
        return Response(content=data, media_type="image/jpeg")
    return Response(content=bytes(data), media_type="image/jpeg")


# Password reset (no auth required for request; token in body for reset)
@router.post("/forgot-password")
async def forgot_password(body: dict):
    """Generate password reset token. Body: { \"email\" }. Returns { \"success\": true } (never reveal if email exists)."""
    db = await get_database()
    users = db[USERS]
    tokens_coll = db[PASSWORD_RESET_TOKENS]
    email = (body.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="email required")
    user = await users.find_one({"email": email})
    if not user:
        return {"success": True}
    one_hour_ago = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    recent = await tokens_coll.count_documents({"userId": user["_id"], "createdAt": {"$gte": one_hour_ago}})
    if recent >= 3:
        raise HTTPException(status_code=429, detail="Too many reset requests. Try again later.")
    await tokens_coll.update_many({"userId": user["_id"], "used": False}, {"$set": {"used": True}})
    token = base64.b64encode(secrets.token_bytes(32)).decode()
    hashed = _hash_token(token)
    expires = (datetime.now(timezone.utc) + timedelta(hours=1)).isoformat()
    now = datetime.now(timezone.utc).isoformat()
    await tokens_coll.insert_one({
        "userId": user["_id"],
        "token": hashed,
        "expiresAt": expires,
        "used": False,
        "createdAt": now,
    })
    out = {"success": True, "token": token}
    if user.get("name"):
        out["userName"] = user["name"]
    return out


@router.post("/validate-reset-token")
async def validate_reset_token(body: dict):
    """Validate reset token. Body: { \"token\" }. Returns { \"valid\": true, \"userId\": \"...\" } or valid: false."""
    db = await get_database()
    tokens_coll = db[PASSWORD_RESET_TOKENS]
    token = body.get("token") or ""
    if not token:
        return {"valid": False}
    hashed = _hash_token(token)
    doc = await tokens_coll.find_one({"token": hashed, "used": False})
    if not doc:
        return {"valid": False}
    if datetime.now(timezone.utc) > datetime.fromisoformat(doc["expiresAt"].replace("Z", "+00:00")):
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        return {"valid": False}
    return {"valid": True, "userId": str(doc["userId"])}


@router.post("/reset-password")
async def reset_password(body: dict):
    """Reset password. Body: { \"token\", \"newPassword\" }."""
    db = await get_database()
    users = db[USERS]
    tokens_coll = db[PASSWORD_RESET_TOKENS]
    token = body.get("token") or ""
    new_password = body.get("newPassword") or ""
    if not token or not new_password:
        raise HTTPException(status_code=400, detail="token and newPassword required")
    hashed = _hash_token(token)
    doc = await tokens_coll.find_one({"token": hashed, "used": False})
    if not doc:
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    if datetime.now(timezone.utc) > datetime.fromisoformat(doc["expiresAt"].replace("Z", "+00:00")):
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    user_id = doc["userId"]
    await users.update_one(
        {"_id": user_id},
        {"$set": {"password": hash_password(new_password), "updatedAt": datetime.now(timezone.utc).isoformat()}},
    )
    await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
    return {"success": True}
