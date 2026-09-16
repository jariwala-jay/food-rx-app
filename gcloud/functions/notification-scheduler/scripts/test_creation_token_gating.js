// Regression check for the 2026-09-16 stale-token-backlog fix:
// checkMealReminderFallbacks() and checkMealLoggingInactivityReminders()
// must not manufacture a new pending (undeliverable) notification every day
// for a user with no FCM token -- both have an unbounded, daily-recurring
// notification kind (the meal fallback itself; tracker_reminder's "daily
// d0" branch) that otherwise piles up forever for a tokenless account. The
// doc is still created (so it still shows in the in-app Notification Center
// via GET /notifications, which doesn't filter on deliverySkippedAt) but
// pre-stamped as terminally skipped so notification-delivery's
// pendingNotificationsQuery() never picks it up.
//
// checkExpiringIngredients / checkExpiredItems / checkAppInactivityReminders
// are deliberately NOT covered here -- they're lower priority (naturally
// bounded or gated on real pantry/tracker data existing) and haven't been
// changed yet; see the 2026-09-16 audit for the reasoning.
//
// noTokenSkipReason() is the one pure decision function shared by both
// creators; each insert site just applies whatever it returns to the doc
// before insertOne(), same pattern as decideMealReminderFallback() /
// decideTrackerReminder().
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_meal_reminder_fallback.js); run with:
//   node scripts/test_creation_token_gating.js

const assert = require("assert");
const schedulerTestables = require("../index.js").__testables;
const deliveryTestables = require("../../notification-delivery/index.js").__testables;

const { noTokenSkipReason, DELIVERY_SKIP_REASON_NO_FCM_TOKEN } = schedulerTestables;
const { pendingNotificationsQuery } = deliveryTestables;

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
// notification-delivery's own tests.
function matchesExistsQuery(doc, query) {
  return Object.entries(query).every(([field, cond]) => {
    const present = Object.prototype.hasOwnProperty.call(doc, field);
    return cond.$exists ? present : !present;
  });
}

// --- noTokenSkipReason: the shared pure decision -----------------------

check("noTokenSkipReason: user has no fcmToken at all -> no_fcm_token", () => {
  assert.strictEqual(noTokenSkipReason({ _id: "u1" }), DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
});

check("noTokenSkipReason: fcmToken is null/empty -> still no_fcm_token", () => {
  assert.strictEqual(noTokenSkipReason({ fcmToken: null }), DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
  assert.strictEqual(noTokenSkipReason({ fcmToken: "" }), DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
});

check("noTokenSkipReason: user has a real token -> null (create as normal pending)", () => {
  assert.strictEqual(noTokenSkipReason({ fcmToken: "abc123" }), null);
});

// --- checkMealReminderFallbacks doc shaping -----------------------------

// Mirrors the exact doc-shaping logic in checkMealReminderFallbacks():
//   const doc = { userId, type, title, message, createdAt };
//   const skipReason = noTokenSkipReason(user);
//   if (skipReason) { doc.deliverySkippedAt = ...; doc.deliverySkippedReason = skipReason; }
function buildFallbackDoc(user) {
  const doc = {
    userId: "u1",
    type: "lunch_reminder_fallback",
    title: "Time to log your meal",
    message: "...",
    createdAt: new Date(),
  };
  const skipReason = noTokenSkipReason(user);
  if (skipReason) {
    doc.deliverySkippedAt = new Date();
    doc.deliverySkippedReason = skipReason;
  }
  return doc;
}

check("a fallback reminder created for a tokenless user is pre-skipped, not pending", () => {
  const doc = buildFallbackDoc({ _id: "u1" });
  assert.strictEqual(doc.deliverySkippedReason, DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a fallback reminder created for a user WITH a token is left pending as before", () => {
  const doc = buildFallbackDoc({ fcmToken: "abc123" });
  assert.strictEqual(doc.deliverySkippedAt, undefined);
  assert.strictEqual(doc.deliverySkippedReason, undefined);
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), true);
});

check("a fallback doc is still created (title/message/createdAt intact) even when pre-skipped -- Notification Center visibility is preserved", () => {
  const doc = buildFallbackDoc({ _id: "u1" });
  assert.strictEqual(doc.type, "lunch_reminder_fallback");
  assert.ok(doc.title);
  assert.ok(doc.message);
  assert.ok(doc.createdAt instanceof Date);
});

// --- checkMealLoggingInactivityReminders (tracker_reminder) doc shaping --

// Mirrors the exact doc-shaping logic in checkMealLoggingInactivityReminders():
//   const doc = { userId, type: "tracker_reminder", title, message, bucketKey, createdAt };
//   if (decision.daysSinceLastLog !== undefined) doc.daysSinceLastLog = ...;
//   const skipReason = noTokenSkipReason(user);
//   if (skipReason) { doc.deliverySkippedAt = ...; doc.deliverySkippedReason = skipReason; }
function buildTrackerReminderDoc(user, decision) {
  const doc = {
    userId: "u1",
    type: "tracker_reminder",
    title: decision.title,
    message: decision.message,
    bucketKey: decision.bucketKey,
    createdAt: new Date(),
  };
  if (decision.daysSinceLastLog !== undefined) {
    doc.daysSinceLastLog = decision.daysSinceLastLog;
  }
  const skipReason = noTokenSkipReason(user);
  if (skipReason) {
    doc.deliverySkippedAt = new Date();
    doc.deliverySkippedReason = skipReason;
  }
  return doc;
}

const DAILY_DECISION = { kind: "daily", bucketKey: "d0", title: "Ready to log today's meals?", message: "..." };
const INACTIVITY_DECISION = {
  kind: "inactivity",
  bucketKey: "d3",
  daysSinceLastLog: 3,
  title: "Your nutrition log is waiting",
  message: "...",
};

check("the recurring daily (d0) tracker reminder is pre-skipped for a tokenless user -- this is the unbounded-growth case the fix targets", () => {
  const doc = buildTrackerReminderDoc({ _id: "u1" }, DAILY_DECISION);
  assert.strictEqual(doc.deliverySkippedReason, DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("an inactivity-milestone tracker reminder is also pre-skipped for a tokenless user", () => {
  const doc = buildTrackerReminderDoc({ _id: "u1" }, INACTIVITY_DECISION);
  assert.strictEqual(doc.deliverySkippedReason, DELIVERY_SKIP_REASON_NO_FCM_TOKEN);
  assert.strictEqual(doc.daysSinceLastLog, 3);
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a tracker reminder created for a user WITH a token is left pending as before, for both decision kinds", () => {
  const dailyDoc = buildTrackerReminderDoc({ fcmToken: "abc123" }, DAILY_DECISION);
  const inactivityDoc = buildTrackerReminderDoc({ fcmToken: "abc123" }, INACTIVITY_DECISION);
  assert.strictEqual(dailyDoc.deliverySkippedAt, undefined);
  assert.strictEqual(matchesExistsQuery(dailyDoc, pendingNotificationsQuery()), true);
  assert.strictEqual(inactivityDoc.deliverySkippedAt, undefined);
  assert.strictEqual(matchesExistsQuery(inactivityDoc, pendingNotificationsQuery()), true);
});

check("a tracker reminder doc keeps its bucketKey/title/message even when pre-skipped -- Notification Center visibility is preserved", () => {
  const doc = buildTrackerReminderDoc({ _id: "u1" }, DAILY_DECISION);
  assert.strictEqual(doc.bucketKey, "d0");
  assert.ok(doc.title);
  assert.ok(doc.message);
  assert.ok(doc.createdAt instanceof Date);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
