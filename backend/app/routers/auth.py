from datetime import date, datetime, timezone, timedelta
import base64
import hashlib
import json
import secrets
from html import escape
from urllib.parse import quote

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import HTMLResponse, Response

from app.database import get_database
from app.auth_password import hash_password, verify_password
from app.auth_jwt import ACCESS_TOKEN_EXPIRE_HOURS, create_access_token
from app.deps import get_current_user_id
from app.refresh_tokens import (
    issue_refresh_token,
    revoke_all_refresh_tokens_for_user,
    revoke_refresh_token,
    rotate_refresh_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])

USERS = "users"
PASSWORD_RESET_TOKENS = "passwordResetTokens"
PROFILE_PHOTOS_FILES = "profile_photos.files"
PROFILE_PHOTOS_CHUNKS = "profile_photos.chunks"
LOCK_THRESHOLD = 5
LOCK_MINUTES = 30
MINIMUM_AGE_YEARS = 18


def _serialize_user(doc: dict) -> dict:
    out = dict(doc)
    if "_id" in out:
        out["_id"] = str(out["_id"])
    return out


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


async def _auth_token_response(db, user_id: ObjectId, email: str, user: dict) -> dict:
    """Access + refresh token pair for login/register/refresh."""
    uid = str(user_id)
    access = create_access_token(uid)
    refresh = await issue_refresh_token(db, uid)
    return {
        "access_token": access,
        "refresh_token": refresh,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_HOURS * 3600,
        "user_id": uid,
        "email": email,
        "user": _serialize_user(user),
    }


def _password_reset_bridge_html(token: str) -> str:
    """Minimal HTTPS page: tries to open the app via custom scheme; fallback button for mail clients."""
    token_js = json.dumps(token)
    deep = f"foodrx://reset-password?token={quote(token, safe='')}"
    href_escaped = escape(deep, quote=True)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Reset password — MyFoodRx</title>
  <style>
    body {{ font-family: system-ui, sans-serif; margin: 0; padding: 24px; background: #f7f7f8; color: #2c2c2c; }}
    .card {{ max-width: 420px; margin: 40px auto; background: #fff; border-radius: 12px;
      padding: 28px; box-shadow: 0 2px 8px rgba(0,0,0,.06); }}
    a.btn {{ display: inline-block; background: #FF6A00; color: #fff !important;
      text-decoration: none; padding: 14px 28px; border-radius: 24px; font-weight: 600; margin-top: 16px; }}
    p.note {{ color: #90909a; font-size: 14px; line-height: 1.5; margin-top: 20px; }}
  </style>
</head>
<body>
  <div class="card">
    <h1 style="font-size: 22px; margin: 0 0 12px;">Open MyFoodRx</h1>
    <p>We’re opening the app so you can finish resetting your password.</p>
    <p>If nothing happens, tap the button below. MyFoodRx must be installed on this phone.</p>
    <p><a class="btn" href="{href_escaped}">Open MyFoodRx</a></p>
    <p class="note">You can close this tab after the app opens or after you’ve set a new password.</p>
  </div>
  <script>
    (function() {{
      var token = {token_js};
      window.location.replace('foodrx://reset-password?token=' + encodeURIComponent(token));
    }})();
  </script>
</body>
</html>"""


def _parse_iso_datetime(value: str | None) -> datetime | None:
    if not value:
        return None
    try:
        v = value.strip()
        if v.endswith("Z"):
            v = v[:-1] + "+00:00"
        dt = datetime.fromisoformat(v)
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _parse_date_of_birth(value) -> date | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, str):
        v = value.strip()
        if not v:
            return None
        if v.endswith("Z"):
            v = v[:-1] + "+00:00"
        try:
            return datetime.fromisoformat(v).date()
        except Exception:
            return None
    return None


def _is_at_least_minimum_age(dob: date, minimum_years: int = MINIMUM_AGE_YEARS) -> bool:
    today = datetime.now(timezone.utc).date()
    age = today.year - dob.year
    if (today.month, today.day) < (dob.month, dob.day):
        age -= 1
    return age >= minimum_years


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

    if "dateOfBirth" in body:
        dob = _parse_date_of_birth(body.get("dateOfBirth"))
        if dob is None:
            raise HTTPException(status_code=400, detail="Invalid dateOfBirth format")
        if not _is_at_least_minimum_age(dob):
            raise HTTPException(status_code=400, detail="You must be at least 18 years old")

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
        "lastActiveAt": now,
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

    return await _auth_token_response(db, user_id, email, user_doc)


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
    return await _auth_token_response(db, user["_id"], user["email"], user)


@router.post("/refresh")
async def refresh_session(body: dict):
    """Exchange a valid refresh token for a new access + refresh pair (rotation)."""
    raw = (body.get("refresh_token") or "").strip()
    if not raw:
        raise HTTPException(status_code=400, detail="refresh_token required")

    db = await get_database()
    rotated = await rotate_refresh_token(db, raw)
    if not rotated:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    user_id, new_refresh = rotated
    users = db[USERS]
    if len(user_id) != 24:
        raise HTTPException(status_code=401, detail="Invalid user")
    user = await users.find_one({"_id": ObjectId(user_id)})
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    now = datetime.now(timezone.utc).isoformat()
    await users.update_one(
        {"_id": user["_id"]},
        {"$set": {"lastActiveAt": now, "updatedAt": now}},
    )

    access = create_access_token(user_id)
    return {
        "access_token": access,
        "refresh_token": new_refresh,
        "token_type": "bearer",
        "expires_in": ACCESS_TOKEN_EXPIRE_HOURS * 3600,
        "user_id": user_id,
        "email": user["email"],
    }


@router.post("/logout")
async def logout_session(body: dict):
    """Revoke the refresh token for this device. Body: { \"refresh_token\": \"...\" }."""
    raw = (body.get("refresh_token") or "").strip()
    if raw:
        db = await get_database()
        await revoke_refresh_token(db, raw)
    return {"success": True}


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
                "lastActiveAt": now,
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
        "fcmToken", "lastActiveAt",
    }
    updates = {k: v for k, v in body.items() if k in allowed}
    if not updates:
        return {"ok": True}
    if "dateOfBirth" in updates:
        dob = _parse_date_of_birth(updates.get("dateOfBirth"))
        if dob is None:
            raise HTTPException(status_code=400, detail="Invalid dateOfBirth format")
        if not _is_at_least_minimum_age(dob):
            raise HTTPException(status_code=400, detail="You must be at least 18 years old")
    # Enforce one-device-token-per-user to avoid cross-account push delivery
    # on shared devices. If this token exists on other users, remove it there.
    if "fcmToken" in updates and updates.get("fcmToken"):
        try:
            await users.update_many(
                {
                    "fcmToken": updates["fcmToken"],
                    "_id": {"$ne": ObjectId(user_id)},
                },
                {"$unset": {"fcmToken": ""}},
            )
        except Exception:
            pass
    updates["updatedAt"] = datetime.now(timezone.utc).isoformat()
    await users.update_one({"_id": ObjectId(user_id)}, {"$set": updates})
    # If the app just registered an FCM token, only send a welcome tray push for
    # truly new accounts (prevents legacy users from seeing welcome on re-login).
    if "fcmToken" in updates and updates.get("fcmToken"):
        try:
            user = await users.find_one({"_id": ObjectId(user_id)})
            created_at = _parse_iso_datetime((user or {}).get("createdAt"))
            now_dt = datetime.now(timezone.utc)
            is_new_account = (
                created_at is not None
                and (now_dt - created_at) <= timedelta(hours=24)
                and (now_dt - created_at) >= timedelta(seconds=0)
            )
            if user and not user.get("welcomePushSentAt") and is_new_account:
                from app.push import send_push_to_fcm_token

                res = await send_push_to_fcm_token(
                    token=str(updates["fcmToken"]),
                    title="Welcome to MyFoodRx",
                    body="We're glad you're here. Start by adding items to your pantry!",
                    data={"type": "admin", "deeplink": "notifications"},
                )
                if res.get("ok"):
                    now_iso = now_dt.isoformat()
                    await users.update_one(
                        {"_id": ObjectId(user_id)},
                        {"$set": {"welcomePushSentAt": now_iso}},
                    )
                    # Mark welcome notification as sent so legacy notification-delivery
                    # Cloud Function will not send the same welcome message again later.
                    await db["notifications"].update_one(
                        {
                            **({"$or": [{"userId": str(user_id)}, {"userId": ObjectId(user_id)}]}),
                            "type": "admin",
                            "title": "Welcome to MyFoodRx",
                            "sentAt": {"$exists": False},
                        },
                        {"$set": {"sentAt": now_iso}},
                    )
        except Exception:
            pass
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


@router.get("/reset-password/open")
async def reset_password_open(token: str = ""):
    """Email-friendly HTTPS link: opens MyFoodRx via foodrx:// (see Flutter deep link handler)."""
    token = (token or "").strip()
    if not token:
        return HTMLResponse(
            content="<html><body><p>Missing reset token. Request a new reset link from the app.</p></body></html>",
            status_code=400,
        )
    return HTMLResponse(content=_password_reset_bridge_html(token), media_type="text/html")


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
    expires = _parse_iso_datetime(doc.get("expiresAt"))
    if expires is None or datetime.now(timezone.utc) > expires:
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
    expires = _parse_iso_datetime(doc.get("expiresAt"))
    if expires is None or datetime.now(timezone.utc) > expires:
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    user_id = doc["userId"]
    await users.update_one(
        {"_id": user_id},
        {"$set": {"password": hash_password(new_password), "updatedAt": datetime.now(timezone.utc).isoformat()}},
    )
    await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
    await revoke_all_refresh_tokens_for_user(db, str(user_id))
    return {"success": True}
