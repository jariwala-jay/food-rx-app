from datetime import date, datetime, timezone, timedelta
import base64
import hashlib
import math
import re
import secrets
import warnings
from urllib.parse import quote

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from fastapi.responses import HTMLResponse, Response

from app.database import get_database
from app.auth_password import hash_password, verify_password
from app.auth_jwt import ACCESS_TOKEN_EXPIRE_HOURS, create_access_token
from app.config import settings
from app.deps import get_current_user_id
from app.email_service import send_google_signin_notice_email, send_password_reset_email
from app.firebase_admin_app import verify_google_id_token
from app.notification_eligibility import NEW_ACCOUNT_GRACE_HOURS, parse_iso_datetime
from app.refresh_tokens import (
    issue_refresh_token,
    revoke_all_refresh_tokens_for_user,
    revoke_refresh_token,
    rotate_refresh_token,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# Warn loudly at startup if the JWT secret is still the insecure default.
# A weak/default secret allows anyone to forge valid access tokens.
if settings.secret_key in ("", "change-me-in-production"):
    warnings.warn(
        "SECRET_KEY is not set or is using the default value. "
        "Set a strong random SECRET_KEY in your .env file before deploying.",
        stacklevel=1,
    )

MAX_PHOTO_SIZE_BYTES = 5 * 1024 * 1024  # 5 MB

# Dummy hash so a missing-email login still runs verify_password, keeping
# response time constant to prevent email enumeration via timing.
_DUMMY_HASH = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=:" + "0" * 64

USERS = "users"
PASSWORD_RESET_TOKENS = "passwordResetTokens"
PROFILE_PHOTOS_FILES = "profile_photos.files"
PROFILE_PHOTOS_CHUNKS = "profile_photos.chunks"
LOCK_THRESHOLD = 5
LOCK_MINUTES = 30
MINIMUM_AGE_YEARS = 18


_SENSITIVE_FIELDS = {"password", "failedLoginAttempts", "isLocked", "lockUntil"}

_PASSWORD_RULES = [
    (lambda p: len(p) >= 8,                          "Password must be at least 8 characters"),
    (lambda p: bool(re.search(r"[A-Z]", p)),          "Password must contain at least one uppercase letter"),
    (lambda p: bool(re.search(r"[a-z]", p)),          "Password must contain at least one lowercase letter"),
    (lambda p: bool(re.search(r"[0-9]", p)),          "Password must contain at least one number"),
    (lambda p: bool(re.search(r'[!@#$%^&*(),.?":{}|<>]', p)), "Password must contain at least one special character"),
]

def _validate_password_complexity(password: str) -> str | None:
    """Return an error message if password fails complexity rules, else None."""
    for check, message in _PASSWORD_RULES:
        if not check(password):
            return message
    return None


def _serialize_user(doc: dict) -> dict:
    out = {k: v for k, v in doc.items() if k not in _SENSITIVE_FIELDS}
    if "_id" in out:
        out["_id"] = str(out["_id"])
    return out


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _is_google_only_account(user: dict) -> bool:
    """Google-linked accounts (see /auth/google/complete) have no password —
    they must never receive a reset token or have a password field written
    via the unauthenticated forgot-password/reset-password flow."""
    return user.get("authProvider") == "google"


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


# Static HTML — same response for every request. The token is only ever in
# the URL fragment (#token=...), which browsers never send to the server,
# so this page reads it client-side via location.hash instead of the server
# rendering it in. See forgot_password() for the link construction.
_PASSWORD_RESET_BRIDGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="referrer" content="no-referrer">
  <title>Reset password — MyFoodRx</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 0; padding: 24px; background: #f7f7f8; color: #2c2c2c; }
    .card { max-width: 420px; margin: 40px auto; background: #fff; border-radius: 12px;
      padding: 28px; box-shadow: 0 2px 8px rgba(0,0,0,.06); text-align: center; }
    a.btn { display: inline-block; background: #FF6A00; color: #fff !important;
      text-decoration: none; padding: 14px 28px; border-radius: 24px; font-weight: 600; margin-top: 16px; }
    p.note { color: #90909a; font-size: 14px; line-height: 1.5; margin-top: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <h1 style="font-size: 22px; margin: 0 0 12px;">Open MyFoodRx</h1>
    <p id="status">We’re opening the app so you can finish resetting your password.</p>
    <p id="fallback-note" style="display:none;">If nothing happens, tap the button below. MyFoodRx must be installed on this phone.</p>
    <p id="btn-container"></p>
    <p class="note">You can close this tab after the app opens or after you’ve set a new password.</p>
  </div>
  <script>
    (function() {
      // The token lives only in the fragment — never sent to this server.
      var hash = window.location.hash || '';
      var token = new URLSearchParams(hash.replace(/^#/, '')).get('token');
      if (!token) {
        document.getElementById('status').textContent =
          'Missing reset token. Request a new reset link from the app.';
        return;
      }
      var deepLink = 'foodrx://reset-password?token=' + encodeURIComponent(token);
      var btn = document.createElement('a');
      btn.className = 'btn';
      btn.href = deepLink;
      btn.textContent = 'Open MyFoodRx';
      document.getElementById('btn-container').appendChild(btn);
      document.getElementById('fallback-note').style.display = 'block';
      window.location.replace(deepLink);
    })();
  </script>
</body>
</html>"""


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
    raw_email = body.get("email")
    raw_password = body.get("password")
    if not isinstance(raw_email, str) or not isinstance(raw_password, str):
        raise HTTPException(status_code=400, detail="email and password required")
    email = raw_email.strip().lower()
    password = raw_password
    if not email or not password:
        raise HTTPException(status_code=400, detail="email and password required")

    pw_error = _validate_password_complexity(password)
    if pw_error:
        raise HTTPException(status_code=400, detail=pw_error)

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
        "message": "We're glad you're here. Start by adding ingredients to your pantry to get personalized recommendations.",
        "createdAt": now,
    })

    return await _auth_token_response(db, user_id, email, user_doc)


@router.post("/login")
async def login(body: dict):
    """Login with email and password. Returns JWT and user."""
    db = await get_database()
    users = db[USERS]
    raw_email = body.get("email")
    raw_password = body.get("password")
    # Reject non-string inputs early to prevent type-confusion errors downstream.
    if not isinstance(raw_email, str) or not isinstance(raw_password, str):
        raise HTTPException(status_code=400, detail="email and password required")
    email = raw_email.strip().lower()
    password = raw_password
    if not email or not password:
        raise HTTPException(status_code=400, detail="email and password required")

    user = await users.find_one({"email": email})
    if not user:
        # Dummy verification keeps response time constant regardless of
        # whether the email exists, to prevent enumeration via timing.
        verify_password("_dummy_", _DUMMY_HASH)
        raise HTTPException(status_code=401, detail="Invalid email or password")

    if user.get("authProvider") == "google":
        # Constant-time dummy so this path takes the same time as a real check.
        verify_password("_dummy_", _DUMMY_HASH)
        raise HTTPException(
            status_code=400,
            detail="This account uses Google Sign-In. Please tap 'Continue with Google' to sign in.",
        )

    if user.get("isLocked"):
        lock_until = user.get("lockUntil")
        if lock_until:
            try:
                until = datetime.fromisoformat(lock_until.replace("Z", "+00:00"))
                now = datetime.now(timezone.utc)
                if until > now:
                    remaining_secs = (until - now).total_seconds()
                    minutes = max(1, int(remaining_secs // 60) + (1 if remaining_secs % 60 > 0 else 0))
                    unit = "minute" if minutes == 1 else "minutes"
                    raise HTTPException(
                        status_code=403,
                        detail=f"Account temporarily locked after too many failed attempts. Try again in {minutes} {unit}.",
                    )
                else:
                    # Lock has expired — reset so the user gets a fresh set of attempts.
                    # Without this, failedLoginAttempts stays at LOCK_THRESHOLD and the
                    # very next wrong password would re-lock them immediately.
                    await users.update_one(
                        {"_id": user["_id"]},
                        {"$set": {"isLocked": False, "lockUntil": None, "failedLoginAttempts": 0}},
                    )
                    user["isLocked"] = False
                    user["failedLoginAttempts"] = 0
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


@router.post("/google")
async def google_sign_in(body: dict):
    """
    Authenticate via Google Sign-In. Body: { "idToken": "<google-id-token>" }.
    See app.firebase_admin_app.verify_google_id_token for signature/audience
    verification.

    Existing account: logs in and returns the same JWT + refresh-token payload
    as /login, plus "isNewUser": false.

    Brand-new email: does NOT create a user document or issue a session — the
    account is only created once onboarding actually completes (see
    /auth/google/complete). Returns the decoded Google profile and
    "isNewUser": true instead, so the client can hold onto it through the
    health-profile steps without a half-finished account sitting in the DB if
    onboarding is abandoned.
    """
    id_token_str = (body.get("idToken") or "").strip()
    if not id_token_str:
        raise HTTPException(status_code=400, detail="idToken required")

    try:
        decoded = await verify_google_id_token(id_token_str)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Google token")

    email = (decoded.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="Google account has no email address")

    name = decoded.get("name") or ""
    picture = decoded.get("picture") or ""

    db = await get_database()
    users = db[USERS]

    user = await users.find_one({"email": email})

    if user is None:
        # Truly new — nothing to log into yet. Client proceeds to onboarding
        # and finalizes account creation via /auth/google/complete.
        return {
            "isNewUser": True,
            "email": email,
            "name": name,
            "profilePhotoUrl": picture,
        }

    if user.get("password") and not user.get("authProvider"):
        # Existing email/password account — do not silently merge.
        raise HTTPException(
            status_code=400,
            detail="An account with this email already exists. Please sign in with your email and password.",
        )
    await _handle_successful_login(users, user["_id"])

    response = await _auth_token_response(db, user["_id"], user["email"], user)
    response["isNewUser"] = False
    return response


@router.post("/google/complete")
async def google_sign_in_complete(body: dict):
    """
    Finalizes a brand-new Google account at the end of onboarding ("Let's get
    started"). Body: { "idToken": "<google-id-token>", ...health profile
    fields (same keys as /auth/register) }.

    Re-verifies the Google token (it may be ~minutes old by now) and creates
    the user document with the full profile in one atomic write — mirroring
    /auth/register, so there's never a partial account in the database.
    """
    id_token_str = (body.get("idToken") or "").strip()
    if not id_token_str:
        raise HTTPException(status_code=400, detail="idToken required")

    try:
        decoded = await verify_google_id_token(id_token_str)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired Google token")

    email = (decoded.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="Google account has no email address")

    db = await get_database()
    users = db[USERS]

    existing = await users.find_one({"email": email})
    if existing:
        raise HTTPException(
            status_code=400,
            detail="An account with this email already exists. Please sign in instead.",
        )

    user_id = ObjectId()
    now = datetime.now(timezone.utc).isoformat()
    user_doc = {
        "_id": user_id,
        "email": email,
        "name": decoded.get("name") or body.get("name") or "",
        "profilePhotoUrl": decoded.get("picture") or body.get("profilePhotoUrl") or "",
        "authProvider": "google",
        "createdAt": now,
        "updatedAt": now,
        "lastLoginAt": now,
        "lastActiveAt": now,
        "failedLoginAttempts": 0,
        "isLocked": False,
        "lockUntil": None,
    }
    allowed = {
        "firstName", "lastName", "age", "dateOfBirth", "sex",
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

    await users.insert_one(user_doc)

    notifications = db["notifications"]
    await notifications.insert_one({
        "_id": ObjectId(),
        "userId": str(user_id),
        "type": "admin",
        "title": "Welcome to MyFoodRx",
        "message": "We're glad you're here. Start by adding ingredients to your pantry to get personalized recommendations.",
        "createdAt": now,
    })

    response = await _auth_token_response(db, user_id, email, user_doc)
    response["isNewUser"] = True
    return response


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
        "fcmToken", "lastActiveAt", "timezoneOffsetMinutes", "mealLoggingReminderPrefs",
    }
    updates = {k: v for k, v in body.items() if k in allowed}
    if not updates:
        return {"ok": True}
    # Prevent clients from setting lastActiveAt to a future timestamp to bypass
    # the 90-day idle-logout check. Clamp to server time if the value is ahead of now.
    if "lastActiveAt" in updates:
        provided = parse_iso_datetime(str(updates["lastActiveAt"]))
        server_now = datetime.now(timezone.utc)
        if provided is None or provided > server_now + timedelta(minutes=5):
            updates["lastActiveAt"] = server_now.isoformat()
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
            created_at = parse_iso_datetime((user or {}).get("createdAt"))
            now_dt = datetime.now(timezone.utc)
            is_new_account = (
                created_at is not None
                and timedelta(seconds=0) <= (now_dt - created_at) <= timedelta(hours=NEW_ACCOUNT_GRACE_HOURS)
            )
            if user and not user.get("welcomePushSentAt") and is_new_account:
                from app.push import send_push_to_fcm_token

                res = await send_push_to_fcm_token(
                    token=str(updates["fcmToken"]),
                    title="Welcome to MyFoodRx",
                    body="We're glad you're here. Start by adding ingredients to your pantry to get personalized recommendations.",
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
    if len(content) > MAX_PHOTO_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="Profile photo must be under 5 MB")
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


_BRIDGE_RESPONSE_HEADERS = {
    "Cache-Control": "no-store",
    "Referrer-Policy": "no-referrer",
}


@router.get("/reset-password/open")
async def reset_password_open():
    """Email-friendly HTTPS link: opens MyFoodRx via foodrx:// (see Flutter deep link handler)."""
    return HTMLResponse(
        content=_PASSWORD_RESET_BRIDGE_HTML,
        media_type="text/html",
        headers=_BRIDGE_RESPONSE_HEADERS,
    )


# Password reset (no auth required for request; token in body for reset)
@router.post("/forgot-password")
async def forgot_password(body: dict):
    """
    Request a password-reset email. Body: { \"email\" }.
    Always returns { \"success\": true } — never reveals whether the email is
    registered or which auth provider it uses, and never returns the reset
    token itself: only the email (sent server-side, below) proves ownership
    of the account.
    """
    db = await get_database()
    users = db[USERS]
    tokens_coll = db[PASSWORD_RESET_TOKENS]
    email = (body.get("email") or "").strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="email required")
    user = await users.find_one({"email": email})
    if not user:
        return {"success": True}
    if _is_google_only_account(user):
        # No password to reset — never issue a token or touch the password
        # field for this account. Tell them how to actually sign in instead.
        await send_google_signin_notice_email(email, user.get("name"))
        return {"success": True}
    one_hour_ago = (datetime.now(timezone.utc) - timedelta(hours=1)).isoformat()
    recent_tokens = await tokens_coll.find(
        {"userId": user["_id"], "createdAt": {"$gte": one_hour_ago}},
        sort=[("createdAt", 1)],
    ).to_list(length=None)
    if len(recent_tokens) >= 3:
        oldest_created = parse_iso_datetime(recent_tokens[0]["createdAt"])
        retry_at = (oldest_created or datetime.now(timezone.utc)) + timedelta(hours=1)
        wait_minutes = max(1, math.ceil((retry_at - datetime.now(timezone.utc)).total_seconds() / 60))
        unit = "minute" if wait_minutes == 1 else "minutes"
        raise HTTPException(
            status_code=429,
            detail=f"Too many reset requests. Please try again in {wait_minutes} {unit}.",
        )
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
    # Fragment (#token=...), not a query string: browsers never send the
    # fragment to the server, so it never ends up in access logs. Built from
    # settings.public_base_url, not the request's Host header — see config.py.
    reset_link = f"{settings.public_base_url.rstrip('/')}/auth/reset-password/open#token={quote(token, safe='')}"
    await send_password_reset_email(email, reset_link, user.get("name"))
    return {"success": True}


@router.post("/validate-reset-token")
async def validate_reset_token(body: dict):
    """Validate reset token. Body: { \"token\" }. Returns { \"valid\": true } or { \"valid\": false }."""
    db = await get_database()
    tokens_coll = db[PASSWORD_RESET_TOKENS]
    token = body.get("token") or ""
    if not token:
        return {"valid": False}
    hashed = _hash_token(token)
    doc = await tokens_coll.find_one({"token": hashed, "used": False})
    if not doc:
        return {"valid": False}
    expires = parse_iso_datetime(doc.get("expiresAt"))
    if expires is None or datetime.now(timezone.utc) > expires:
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        return {"valid": False}
    return {"valid": True}


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

    pw_error = _validate_password_complexity(new_password)
    if pw_error:
        raise HTTPException(status_code=400, detail=pw_error)

    hashed = _hash_token(token)
    doc = await tokens_coll.find_one({"token": hashed, "used": False})
    if not doc:
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    expires = parse_iso_datetime(doc.get("expiresAt"))
    if expires is None or datetime.now(timezone.utc) > expires:
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        raise HTTPException(status_code=400, detail="Invalid or expired token")
    user_id = doc["userId"]
    user = await users.find_one({"_id": user_id})
    if user and _is_google_only_account(user):
        # Defense in depth: forgot-password no longer issues tokens for
        # Google-only accounts, but never write a password for one even if a
        # token somehow still validates (e.g. one issued before this fix).
        await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
        raise HTTPException(
            status_code=400,
            detail="This account uses Google Sign-In. Please tap 'Continue with Google' to sign in.",
        )
    if user and verify_password(new_password, user.get("password") or ""):
        # A validation failure, not a successful reset — leave the token
        # usable so the user can retry with an actually different password
        # on the same link instead of requesting a new email.
        raise HTTPException(
            status_code=400,
            detail="New password must be different from your current password.",
        )
    await users.update_one(
        {"_id": user_id},
        {"$set": {"password": hash_password(new_password), "updatedAt": datetime.now(timezone.utc).isoformat()}},
    )
    await tokens_coll.update_one({"token": hashed}, {"$set": {"used": True}})
    await revoke_all_refresh_tokens_for_user(db, str(user_id))
    return {"success": True}
