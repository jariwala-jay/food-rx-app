// Regression check for the creation-time notification-preference gate used
// by checkExpiringIngredients() and checkMealLoggingInactivityReminders():
// a user who has turned off the corresponding Notification Settings toggle
// must be skipped before a notification document is even created, saving a
// document that the delivery-time gate (notification-delivery/index.js)
// would just filter out later.
//
// Also guards against the four independent copies of this mapping (here,
// notification-delivery, admin-notification, and the Python backend's
// notification_eligibility.py -- each Cloud Function is a separately
// deployable unit with no shared package to import from, and the backend is
// a different language entirely) drifting out of sync with each other.
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_inactivity_bucket.js); run with:
//   node scripts/test_notification_preferences.js

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const { isNotificationTypeEnabled, NOTIFICATION_TYPE_TO_PREF_KEY } =
  require("../index.js").__testables;

// There's no runtime import across the Python/Node boundary, so this parses
// the literal dict out of the .py source text instead -- good enough to
// catch a key added/renamed/removed on one side and not the other, which is
// the actual failure mode this guards against (not a general Python parser).
function parsePythonPrefMap(pyFilePath) {
  const source = fs.readFileSync(pyFilePath, "utf8");
  const blockMatch = source.match(
    /NOTIFICATION_TYPE_TO_PREF_KEY\s*=\s*\{([\s\S]*?)\}/
  );
  if (!blockMatch) {
    throw new Error(`Could not find NOTIFICATION_TYPE_TO_PREF_KEY in ${pyFilePath}`);
  }
  const map = {};
  const entryPattern = /"([^"]+)"\s*:\s*"([^"]+)"/g;
  let entryMatch;
  while ((entryMatch = entryPattern.exec(blockMatch[1])) !== null) {
    map[entryMatch[1]] = entryMatch[2];
  }
  return map;
}

let passed = 0;
function check(name, fn) {
  try {
    fn();
    passed++;
    console.log(`ok - ${name}`);
  } catch (err) {
    console.error(`FAIL - ${name}`);
    console.error(`       ${err.message}`);
    process.exitCode = 1;
  }
}

check("expiringIngredients:false disables expiring_ingredient creation", () => {
  const user = { notificationTypePrefs: { expiringIngredients: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "expiring_ingredient"), false);
});

check("trackerReminders:false disables tracker_reminder creation", () => {
  const user = { notificationTypePrefs: { trackerReminders: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "tracker_reminder"), false);
});

check("no prefs set => both remain enabled (existing accounts unaffected)", () => {
  assert.strictEqual(isNotificationTypeEnabled({}, "expiring_ingredient"), true);
  assert.strictEqual(isNotificationTypeEnabled({}, "tracker_reminder"), true);
});

check("app_inactivity_reminder intentionally has no mapping here either", () => {
  assert.strictEqual(NOTIFICATION_TYPE_TO_PREF_KEY.app_inactivity_reminder, undefined);
  assert.strictEqual(isNotificationTypeEnabled(
    { notificationTypePrefs: { trackerReminders: false } },
    "app_inactivity_reminder"
  ), true);
});

check("lunch/dinner_reminder_fallback intentionally have no mapping either -- users control them directly via the per-meal Meal Reminders switches, not a Notification Settings toggle", () => {
  assert.strictEqual(NOTIFICATION_TYPE_TO_PREF_KEY.lunch_reminder_fallback, undefined);
  assert.strictEqual(NOTIFICATION_TYPE_TO_PREF_KEY.dinner_reminder_fallback, undefined);
  const user = { notificationTypePrefs: { trackerReminders: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "lunch_reminder_fallback"), true);
  assert.strictEqual(isNotificationTypeEnabled(user, "dinner_reminder_fallback"), true);
});

check("mapping matches the notification-delivery copy exactly (no drift)", () => {
  const deliveryMap =
    require("../../notification-delivery/index.js").__testables.NOTIFICATION_TYPE_TO_PREF_KEY;
  assert.deepStrictEqual(NOTIFICATION_TYPE_TO_PREF_KEY, deliveryMap);
});

check("mapping matches the admin-notification copy exactly (no drift)", () => {
  const adminMap =
    require("../../admin-notification/index.js").__testables.NOTIFICATION_TYPE_TO_PREF_KEY;
  assert.deepStrictEqual(NOTIFICATION_TYPE_TO_PREF_KEY, adminMap);
});

check("mapping matches the Python backend's copy exactly (no drift)", () => {
  const pythonMap = parsePythonPrefMap(
    path.join(__dirname, "../../../../backend/app/notification_eligibility.py")
  );
  assert.deepStrictEqual(NOTIFICATION_TYPE_TO_PREF_KEY, pythonMap);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
