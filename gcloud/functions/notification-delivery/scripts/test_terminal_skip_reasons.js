// Regression check for the 2026-09-16 stale-token-backlog fix: notifications
// for a deleted user, a user with no FCM token, or a token FCM has confirmed
// is permanently invalid must all be terminally skipped (deliverySkippedAt
// set) rather than left pending forever -- while a genuinely transient send
// error must still be left retryable.
//
// No test framework dependency by design (matches
// notification-delivery/scripts/test_tier_budget_suppression.js); run with:
//   node scripts/test_terminal_skip_reasons.js

const assert = require("assert");
const { ObjectId } = require("mongodb");
const {
  pendingNotificationsQuery,
  terminalSkipReasonForUser,
  isPermanentTokenError,
  permanentTokenClearFilter,
  DELIVERY_SKIP_REASON_USER_DELETED,
  DELIVERY_SKIP_REASON_NO_FCM_TOKEN,
  DELIVERY_SKIP_REASON_TOKEN_INVALID,
  FCM_PERMANENT_TOKEN_ERROR_CODE,
} = require("../index.js").__testables;

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

// Same tiny in-memory stand-in for Mongo's $exists matching used by
// test_tier_budget_suppression.js.
function matchesExistsQuery(doc, query) {
  return Object.entries(query).every(([field, cond]) => {
    const present = Object.prototype.hasOwnProperty.call(doc, field);
    return cond.$exists ? present : !present;
  });
}

// --- terminalSkipReasonForUser -------------------------------------------

check("terminalSkipReasonForUser: user doc not found (deleted account) -> user_deleted", () => {
  assert.strictEqual(terminalSkipReasonForUser(null), DELIVERY_SKIP_REASON_USER_DELETED);
});

check("terminalSkipReasonForUser: user exists but has no fcmToken -> no_fcm_token", () => {
  assert.strictEqual(
    terminalSkipReasonForUser({ _id: "u1", name: "Test" }),
    DELIVERY_SKIP_REASON_NO_FCM_TOKEN
  );
});

check("terminalSkipReasonForUser: fcmToken explicitly null/empty string still counts as no token", () => {
  assert.strictEqual(terminalSkipReasonForUser({ fcmToken: null }), DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
  assert.strictEqual(terminalSkipReasonForUser({ fcmToken: "" }), DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
});

check("terminalSkipReasonForUser: user has a token -> null (proceed to send)", () => {
  assert.strictEqual(terminalSkipReasonForUser({ fcmToken: "abc123" }), null);
});

// --- isPermanentTokenError -------------------------------------------------

check("isPermanentTokenError: matches the confirmed FCM code (NotRegistered / APNs disabled)", () => {
  assert.strictEqual(
    isPermanentTokenError({ code: FCM_PERMANENT_TOKEN_ERROR_CODE, message: "NotRegistered" }),
    true
  );
  assert.strictEqual(
    isPermanentTokenError({
      code: FCM_PERMANENT_TOKEN_ERROR_CODE,
      message: "APNs device token is disabled.",
    }),
    true
  );
});

check("isPermanentTokenError: a transient FCM code is NOT treated as permanent (stays retryable)", () => {
  assert.strictEqual(isPermanentTokenError({ code: "messaging/server-unavailable" }), false);
  assert.strictEqual(isPermanentTokenError({ code: "messaging/internal-error" }), false);
  assert.strictEqual(isPermanentTokenError({ code: "messaging/message-rate-exceeded" }), false);
});

check("isPermanentTokenError: a non-FCM / network error is NOT treated as permanent", () => {
  assert.strictEqual(isPermanentTokenError(new Error("connect ETIMEDOUT")), false);
  assert.strictEqual(isPermanentTokenError(undefined), false);
});

// --- pendingNotificationsQuery interaction ---------------------------------

check("a notification terminally skipped for user_deleted is no longer pending", () => {
  const doc = {
    type: "tracker_reminder",
    createdAt: new Date(),
    deliverySkippedAt: new Date(),
    deliverySkippedReason: DELIVERY_SKIP_REASON_USER_DELETED,
  };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a notification terminally skipped for no_fcm_token is no longer pending", () => {
  const doc = {
    type: "lunch_reminder_fallback",
    createdAt: new Date(),
    deliverySkippedAt: new Date(),
    deliverySkippedReason: DELIVERY_SKIP_REASON_NO_FCM_TOKEN,
  };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a notification terminally skipped for token_invalid is no longer pending", () => {
  const doc = {
    type: "dinner_reminder_fallback",
    createdAt: new Date(),
    deliverySkippedAt: new Date(),
    deliverySkippedReason: DELIVERY_SKIP_REASON_TOKEN_INVALID,
  };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a notification with a transient send failure (no deliverySkippedAt stamped) is STILL pending", () => {
  // Mirrors what the catch block actually does on a non-permanent error:
  // it pushes to deliveryResults but never touches the doc, so sentAt and
  // deliverySkippedAt both stay unset.
  const doc = { type: "expired_items", createdAt: new Date() };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), true);
});

// --- permanentTokenClearFilter: race-safe token clearing -------------------
//
// Regression check for the token-clearing race condition: clearing fcmToken
// on a permanent FCM failure must be scoped to the exact token that failed,
// not just the user id -- otherwise a fresh token registered between the
// failed send and this update (e.g. onTokenRefresh firing right after a
// reinstall) would get wiped out by a cleanup meant for the OLD, already-
// dead token.

// Tiny in-memory stand-in for Mongo's equality matching on a filter object
// (as opposed to matchesExistsQuery's $exists matching above) -- enough to
// prove the filter shape behaves as intended without a live database.
function matchesEqualityFilter(doc, filter) {
  return Object.entries(filter).every(([field, expected]) => {
    const actual = doc[field];
    if (expected instanceof ObjectId || actual instanceof ObjectId) {
      return String(actual) === String(expected);
    }
    return actual === expected;
  });
}

check("permanentTokenClearFilter: filters on both _id and the exact attempted token", () => {
  const userId = new ObjectId().toHexString();
  const filter = permanentTokenClearFilter(userId, "dead-token-abc");
  assert.deepStrictEqual(Object.keys(filter).sort(), ["_id", "fcmToken"]);
  assert.strictEqual(filter._id.toHexString(), userId);
  assert.strictEqual(filter.fcmToken, "dead-token-abc");
});

check("race-safe: a user doc still holding the token that just failed DOES match -> clear proceeds", () => {
  const userId = new ObjectId();
  const attemptedToken = "dead-token-abc"; // the token sendScheduledNotifications actually tried
  const userDocAtUpdateTime = { _id: userId, fcmToken: "dead-token-abc" }; // unchanged since the send attempt
  const filter = permanentTokenClearFilter(userId.toHexString(), attemptedToken);
  assert.strictEqual(matchesEqualityFilter(userDocAtUpdateTime, filter), true);
});

check("race-safe: a user doc whose token changed since the failed send does NOT match -> clear is a no-op, new token survives", () => {
  const userId = new ObjectId();
  const attemptedToken = "dead-token-abc"; // the token that failed
  // Simulates onTokenRefresh firing (e.g. a reinstall) between the failed
  // FCM send and this cleanup running -- the user doc now holds a
  // different, presumably-valid token.
  const userDocAtUpdateTime = { _id: userId, fcmToken: "fresh-token-xyz" };
  const filter = permanentTokenClearFilter(userId.toHexString(), attemptedToken);
  assert.strictEqual(matchesEqualityFilter(userDocAtUpdateTime, filter), false);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
