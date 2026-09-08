// Regression check for the delivery-time notification-preference gate: the
// authoritative backstop that must prevent an FCM push for any notification
// type whose corresponding Notification Settings toggle is off, no matter
// which of several paths created the underlying document.
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_inactivity_bucket.js); run with:
//   node scripts/test_notification_preferences.js

const assert = require("assert");
const { isNotificationTypeEnabled, NOTIFICATION_TYPE_TO_PREF_KEY } =
  require("../index.js").__testables;

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

check("no user doc => enabled (fail-open default)", () => {
  assert.strictEqual(isNotificationTypeEnabled(null, "expiring_ingredient"), true);
});

check("user with no notificationTypePrefs field => enabled", () => {
  assert.strictEqual(isNotificationTypeEnabled({}, "tracker_reminder"), true);
});

check("expiringIngredients:false disables both expiring_ingredient and expired_items", () => {
  const user = { notificationTypePrefs: { expiringIngredients: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "expiring_ingredient"), false);
  assert.strictEqual(isNotificationTypeEnabled(user, "expired_items"), false);
  assert.strictEqual(isNotificationTypeEnabled(user, "tracker_reminder"), true);
});

check("trackerReminders:false disables tracker_reminder only", () => {
  const user = { notificationTypePrefs: { trackerReminders: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "tracker_reminder"), false);
  assert.strictEqual(isNotificationTypeEnabled(user, "expiring_ingredient"), true);
});

check("education:false disables education", () => {
  const user = { notificationTypePrefs: { education: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "education"), false);
});

check("adminUpdates:false disables admin", () => {
  const user = { notificationTypePrefs: { adminUpdates: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "admin"), false);
});

check("app_inactivity_reminder has no mapped preference => always enabled", () => {
  const allOff = {
    notificationTypePrefs: {
      expiringIngredients: false,
      trackerReminders: false,
      education: false,
      adminUpdates: false,
    },
  };
  assert.strictEqual(isNotificationTypeEnabled(allOff, "app_inactivity_reminder"), true);
  assert.strictEqual(NOTIFICATION_TYPE_TO_PREF_KEY.app_inactivity_reminder, undefined);
});

check("explicit true and an absent sub-key both mean enabled", () => {
  const explicitTrue = { notificationTypePrefs: { education: true } };
  const absentKey = { notificationTypePrefs: { adminUpdates: false } }; // no 'education' key
  assert.strictEqual(isNotificationTypeEnabled(explicitTrue, "education"), true);
  assert.strictEqual(isNotificationTypeEnabled(absentKey, "education"), true);
});

check("welcome push never reaches this gate: type 'admin' with adminUpdates off would be caught if it did", () => {
  // Documents the invariant relied on in index.js's comment: the Welcome
  // push is sent synchronously from auth.py and its doc gets sentAt stamped
  // in the same request, so it never reaches sendScheduledNotifications().
  // This just confirms the generic 'admin' mapping itself is correct so
  // that invariant is the only thing keeping Welcome from being gated.
  const user = { notificationTypePrefs: { adminUpdates: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "admin"), false);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
