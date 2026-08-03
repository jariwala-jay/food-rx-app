import logging
from datetime import datetime, timedelta, timezone

from bson import ObjectId
from bson.errors import InvalidId

logger = logging.getLogger(__name__)

# Single source of truth for the new-account onboarding grace period. New
# accounts receive the Welcome notification only; all other notification
# types (pantry alerts, tracker/inactivity reminders, admin/education
# broadcasts) are suppressed until the account clears this window.
NEW_ACCOUNT_GRACE_HOURS = 24


def parse_iso_datetime(value: str | None) -> datetime | None:
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


def resolve_created_at_from_user_doc(user_doc: dict | None) -> datetime | None:
    """
    Resolve the account-creation time from the most trustworthy source
    available in an already-fetched user document. Prefers the explicit
    `createdAt` field; falls back to the creation time embedded in the
    Mongo ObjectId itself (always present, set by the server at insert
    time, never client-suppliable) if that field is missing or unparseable.
    """
    if not user_doc:
        return None
    parsed = parse_iso_datetime(user_doc.get("createdAt"))
    if parsed is not None:
        return parsed
    raw_id = user_doc.get("_id")
    if raw_id is None:
        return None
    try:
        oid = raw_id if isinstance(raw_id, ObjectId) else ObjectId(str(raw_id))
        return oid.generation_time.astimezone(timezone.utc)
    except (InvalidId, TypeError):
        return None


async def get_trusted_account_created_at(db, user_id: str) -> datetime | None:
    user = await db["users"].find_one({"_id": ObjectId(user_id)}, {"createdAt": 1})
    return resolve_created_at_from_user_doc(user)


def is_within_onboarding_grace_period(created_at: datetime | None, now: datetime | None = None) -> bool:
    if created_at is None:
        return False
    now = now or datetime.now(timezone.utc)
    return timedelta(0) <= (now - created_at) < timedelta(hours=NEW_ACCOUNT_GRACE_HOURS)


def is_eligible_given_created_at(created_at: datetime | None, user_id_for_log: str = "") -> bool:
    """
    Fails closed: if account age can't be established from any trusted
    source, the user is treated as still onboarding (suppressed) rather
    than eligible, and a warning is logged so the underlying data problem
    can be investigated.
    """
    if created_at is None:
        logger.warning(
            "notification_eligibility: no trusted createdAt for user %s; suppressing non-Welcome notifications",
            user_id_for_log,
        )
        return False
    return not is_within_onboarding_grace_period(created_at)


async def is_eligible_for_non_welcome_notification(db, user_id: str) -> bool:
    """True once an account is >= NEW_ACCOUNT_GRACE_HOURS old."""
    created_at = await get_trusted_account_created_at(db, user_id)
    return is_eligible_given_created_at(created_at, user_id)


def local_day_start_utc(now_utc: datetime, timezone_offset_minutes: int) -> datetime:
    """
    Start of the user's local calendar day, expressed back in UTC.
    `timezone_offset_minutes` follows the JS `Date.getTimezoneOffset()` /
    Dart `DateTime.timeZoneOffset` convention: minutes to ADD to UTC to get
    local time (e.g. UTC-5 => -300... note callers pass +/- consistently;
    see `users.timezoneOffsetMinutes`, populated as local-minus-UTC).
    """
    local_now = now_utc + timedelta(minutes=timezone_offset_minutes)
    local_midnight = local_now.replace(hour=0, minute=0, second=0, microsecond=0)
    return local_midnight - timedelta(minutes=timezone_offset_minutes)
