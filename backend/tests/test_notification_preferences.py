"""
Regression tests for the notification-preferences fix: the four Notification
Settings toggles (Expiring Ingredients, Tracker Reminders, Education,
Administrative Updates) previously only changed local Flutter UI state and
had no effect on what was actually created/delivered. These tests cover the
backend enforcement added in notification_eligibility.is_notification_type_enabled
and its use in POST /notifications and POST /notifications/broadcast.

Uses FastAPI TestClient with a mocked in-memory MongoDB — no live database
required. Deliberately never enters TestClient as a context manager for the
notifications-only tests (no lifespan hook needed there); the broadcast/
register tests that need `with TestClient(app) as client:` match the pattern
used by test_rate_limiting.py.

Run:
    cd backend && python3 -m unittest tests.test_notification_preferences -v
"""

from __future__ import annotations

import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import AsyncMock, patch

from bson import ObjectId
from fastapi import FastAPI
from fastapi.testclient import TestClient

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.deps import get_current_user_id  # noqa: E402
from app.notification_eligibility import (  # noqa: E402
    get_trusted_account_created_at,
    is_notification_type_enabled,
)
from app.routers import notifications as notifications_router  # noqa: E402

USER_ID = ObjectId("507f1f77bcf86cd799439011")
OLD_ENOUGH_CREATED_AT = (datetime.now(timezone.utc) - timedelta(hours=48)).isoformat()
BRAND_NEW_CREATED_AT = datetime.now(timezone.utc).isoformat()


def _matches(doc: dict, query: dict) -> bool:
    for key, cond in query.items():
        if key == "$or":
            if not any(_matches(doc, sub) for sub in cond):
                return False
            continue
        val = doc.get(key)
        if isinstance(cond, dict):
            for op, opval in cond.items():
                if op == "$exists":
                    if opval and key not in doc:
                        return False
                    if not opval and key in doc:
                        return False
                elif op == "$gte":
                    if val is None or val < opval:
                        return False
                else:
                    raise NotImplementedError(f"Unsupported operator in fake: {op}")
        else:
            if val != cond:
                return False
    return True


class _FakeCursor:
    def __init__(self, docs: list[dict]) -> None:
        self._docs = docs

    async def to_list(self, length=None):
        return list(self._docs) if length is None else list(self._docs)[:length]


class _FakeCollection:
    def __init__(self, docs: list[dict] | None = None) -> None:
        self.docs: list[dict] = list(docs or [])

    async def find_one(self, query: dict, projection=None):
        for doc in self.docs:
            if _matches(doc, query):
                return doc
        return None

    async def insert_one(self, doc: dict):
        self.docs.append(doc)
        return type("Result", (), {"inserted_id": doc.get("_id")})()

    def find(self, query: dict | None = None, projection=None):
        query = query or {}
        return _FakeCursor([d for d in self.docs if _matches(d, query)])


class _FakeDB:
    def __init__(self) -> None:
        self._collections: dict[str, _FakeCollection] = {}

    def set(self, name: str, collection: _FakeCollection) -> None:
        self._collections[name] = collection

    def __getitem__(self, name: str) -> _FakeCollection:
        if name not in self._collections:
            self._collections[name] = _FakeCollection()
        return self._collections[name]


class TestIsNotificationTypeEnabled(unittest.TestCase):
    """Pure-function coverage of the type -> preference-key mapping and its
    fail-open (absent => enabled) default, used by every enforcement point."""

    def test_no_user_doc_defaults_enabled(self) -> None:
        self.assertTrue(is_notification_type_enabled(None, "expiring_ingredient"))

    def test_no_prefs_field_defaults_enabled(self) -> None:
        self.assertTrue(is_notification_type_enabled({}, "tracker_reminder"))

    def test_expiring_ingredients_off_covers_both_expiring_and_expired(self) -> None:
        user = {"notificationTypePrefs": {"expiringIngredients": False}}
        self.assertFalse(is_notification_type_enabled(user, "expiring_ingredient"))
        self.assertFalse(is_notification_type_enabled(user, "expired_items"))
        # Unrelated types are unaffected.
        self.assertTrue(is_notification_type_enabled(user, "tracker_reminder"))

    def test_tracker_reminders_off(self) -> None:
        user = {"notificationTypePrefs": {"trackerReminders": False}}
        self.assertFalse(is_notification_type_enabled(user, "tracker_reminder"))
        self.assertTrue(is_notification_type_enabled(user, "expiring_ingredient"))

    def test_education_off(self) -> None:
        user = {"notificationTypePrefs": {"education": False}}
        self.assertFalse(is_notification_type_enabled(user, "education"))

    def test_admin_updates_off(self) -> None:
        user = {"notificationTypePrefs": {"adminUpdates": False}}
        self.assertFalse(is_notification_type_enabled(user, "admin"))

    def test_unmapped_type_always_enabled_regardless_of_prefs(self) -> None:
        # app_inactivity_reminder has no defined per-type preference yet
        # (see Part 4 implementation notes) -- must never be silently gated.
        user = {"notificationTypePrefs": {
            "expiringIngredients": False, "trackerReminders": False,
            "education": False, "adminUpdates": False,
        }}
        self.assertTrue(is_notification_type_enabled(user, "app_inactivity_reminder"))

    def test_explicit_true_and_absent_key_both_mean_enabled(self) -> None:
        user_explicit = {"notificationTypePrefs": {"education": True}}
        user_absent_key = {"notificationTypePrefs": {"adminUpdates": False}}  # 'education' key absent
        self.assertTrue(is_notification_type_enabled(user_explicit, "education"))
        self.assertTrue(is_notification_type_enabled(user_absent_key, "education"))


class TestCreateNotificationPreferenceGate(unittest.TestCase):
    """POST /notifications must not create a document for a disabled type,
    but must still respect the (unrelated, pre-existing) 24h onboarding gate
    ahead of the preference check."""

    def setUp(self) -> None:
        app = FastAPI()
        app.include_router(notifications_router.router)
        app.dependency_overrides[get_current_user_id] = lambda: str(USER_ID)
        self.app = app
        self.client = TestClient(app)

    def _post(self, body: dict):
        return self.client.post("/notifications", json=body)

    def test_disabled_preference_blocks_expiring_ingredient_creation(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"expiringIngredients": False}},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "expiring_ingredient", "title": "x", "message": "y"})
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {"ok": True, "skipped": "preference_disabled"})
        self.assertEqual(db["notifications"].docs, [])

    def test_disabled_expiring_ingredients_also_blocks_expired_items(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"expiringIngredients": False}},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "expired_items", "title": "x", "message": "y"})
        self.assertEqual(resp.json().get("skipped"), "preference_disabled")
        self.assertEqual(db["notifications"].docs, [])

    def test_disabled_tracker_reminders_blocks_creation(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"trackerReminders": False}},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "tracker_reminder", "title": "x", "message": "y"})
        self.assertEqual(resp.json().get("skipped"), "preference_disabled")
        self.assertEqual(db["notifications"].docs, [])

    def test_enabled_preference_allows_normal_creation(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"trackerReminders": False}},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "expiring_ingredient", "title": "x", "message": "y"})
        self.assertEqual(resp.status_code, 200)
        self.assertNotIn("skipped", resp.json())
        self.assertEqual(len(db["notifications"].docs), 1)
        self.assertEqual(db["notifications"].docs[0]["type"], "expiring_ingredient")

    def test_no_prefs_set_allows_normal_creation(self) -> None:
        """An account that has never touched Notification Settings must keep
        getting everything it already gets today."""
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "tracker_reminder", "title": "x", "message": "y"})
        self.assertNotIn("skipped", resp.json())
        self.assertEqual(len(db["notifications"].docs), 1)

    def test_onboarding_grace_period_still_takes_priority_over_preference(self) -> None:
        """A brand-new account is suppressed by the 24h grace period
        regardless of its (in this case, enabled) preference -- the grace
        check must still run first, unchanged."""
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": BRAND_NEW_CREATED_AT},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "tracker_reminder", "title": "x", "message": "y"})
        self.assertEqual(resp.json(), {"ok": True, "skipped": "onboarding_grace_period"})
        self.assertEqual(db["notifications"].docs, [])

    def test_education_type_creation_respects_preference(self) -> None:
        """No current trigger calls this with type=education, but the gate
        must already be correct for when one does (Part 4)."""
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"education": False}},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self._post({"type": "education", "title": "New article", "message": "y"})
        self.assertEqual(resp.json().get("skipped"), "preference_disabled")


class TestGetTrustedAccountCreatedAtMalformedUserId(unittest.IsolatedAsyncioTestCase):
    """Regression: a malformed user_id (not a valid 24-hex-char ObjectId)
    used to raise bson.errors.InvalidId out of ObjectId(user_id) here,
    turning what should be a graceful "can't verify" into a 500 for the
    caller. Must return None instead, same as any other unresolvable
    account-age source."""

    async def test_malformed_user_id_returns_none_instead_of_raising(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT},
        ]))
        result = await get_trusted_account_created_at(db, "not-a-valid-object-id")
        self.assertIsNone(result)

    async def test_valid_user_id_still_resolves_normally(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT},
        ]))
        result = await get_trusted_account_created_at(db, str(USER_ID))
        self.assertIsNotNone(result)


class TestCreateNotificationMalformedUserId(unittest.TestCase):
    """POST /notifications must not 500 when the authenticated user_id
    (e.g. from a stale/corrupted token) isn't a valid Mongo ObjectId --
    it should degrade to the same fail-closed 'can't verify account age'
    behavior already used when createdAt can't be established at all."""

    def setUp(self) -> None:
        app = FastAPI()
        app.include_router(notifications_router.router)
        app.dependency_overrides[get_current_user_id] = lambda: "not-a-valid-object-id"
        self.app = app
        self.client = TestClient(app)

    def test_malformed_user_id_does_not_500(self) -> None:
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": USER_ID, "createdAt": OLD_ENOUGH_CREATED_AT},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self.client.post(
                "/notifications",
                json={"type": "tracker_reminder", "title": "x", "message": "y"},
            )
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json(), {"ok": True, "skipped": "onboarding_grace_period"})
        self.assertEqual(db["notifications"].docs, [])


class TestBroadcastPreferenceGate(unittest.TestCase):
    """POST /notifications/broadcast (admin/cron broadcast tool) must skip
    recipients who disabled the relevant type, per-user."""

    def setUp(self) -> None:
        app = FastAPI()
        app.include_router(notifications_router.router)
        self.app = app
        self.client = TestClient(app)
        self._secret_patch = patch.object(notifications_router.settings, "broadcast_secret", "test-secret")
        self._secret_patch.start()
        self.addCleanup(self._secret_patch.stop)

    def test_admin_broadcast_skips_users_who_disabled_admin_updates(self) -> None:
        opted_out = ObjectId("507f1f77bcf86cd799439001")
        opted_in = ObjectId("507f1f77bcf86cd799439002")
        db = _FakeDB()
        db.set("users", _FakeCollection([
            {"_id": opted_out, "createdAt": OLD_ENOUGH_CREATED_AT,
             "notificationTypePrefs": {"adminUpdates": False}},
            {"_id": opted_in, "createdAt": OLD_ENOUGH_CREATED_AT},
        ]))
        with patch("app.routers.notifications.get_database", new_callable=AsyncMock, return_value=db):
            resp = self.client.post(
                "/notifications/broadcast",
                json={"title": "Heads up", "message": "New feature!", "type": "admin"},
                headers={"X-Broadcast-Secret": "test-secret"},
            )
        self.assertEqual(resp.status_code, 200)
        body = resp.json()
        self.assertEqual(body["usersNotified"], 1)
        self.assertEqual(body["usersSkippedPreference"], 1)
        recipients = {d["userId"] for d in db["notifications"].docs}
        self.assertEqual(recipients, {str(opted_in)})


class TestWelcomeNotificationUnaffected(unittest.TestCase):
    """Welcome is a special onboarding notification created via a direct
    Mongo insert in register(), not through create_notification() -- so it
    must be completely unaffected by the adminUpdates preference gate."""

    def test_register_still_creates_the_welcome_notification(self) -> None:
        from app.routers import auth as auth_router

        app = FastAPI()
        app.include_router(auth_router.router)
        db = _FakeDB()
        db.set("users", _FakeCollection())

        with patch("app.routers.auth.get_database", new_callable=AsyncMock, return_value=db), \
                patch("app.routers.auth.issue_refresh_token", new_callable=AsyncMock, return_value="fake-refresh"):
            with TestClient(app) as client:
                resp = client.post(
                    "/auth/register",
                    json={"email": "new-user@example.com", "password": "ValidPass1!"},
                )
        self.assertEqual(resp.status_code, 200, resp.text)
        welcome_docs = [d for d in db["notifications"].docs if d.get("title") == "Welcome to MyFoodRx"]
        self.assertEqual(len(welcome_docs), 1)
        self.assertEqual(welcome_docs[0]["type"], "admin")
        # No notificationTypePrefs check of any kind gated this insert.


if __name__ == "__main__":
    unittest.main()
