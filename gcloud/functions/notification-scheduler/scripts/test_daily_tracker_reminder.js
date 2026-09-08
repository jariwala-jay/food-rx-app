// Regression check for the Daily Tracker Reminder ("haven't logged today")
// and its priority rule against the existing longer-horizon inactivity
// ladder: a user must never receive both a daily reminder and an inactivity
// reminder on the same day -- the inactivity ladder always wins when both
// would otherwise apply. decideTrackerReminder() is the pure function that
// encodes this rule; the per-user loop in checkMealLoggingInactivityReminders
// just does the DB dedupe/insert around whatever it returns.
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_inactivity_bucket.js); run with:
//   node scripts/test_daily_tracker_reminder.js

const assert = require("assert");
const { decideTrackerReminder, hasAnyPersonalizedMealReminderEnabled } =
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

const UTC = 0;
const now = new Date("2026-08-10T20:00:00Z"); // 8pm UTC "now" used throughout

check("no activity ever recorded (latestDate null) => daily reminder", () => {
  const decision = decideTrackerReminder(now, null, false, UTC);
  assert.deepStrictEqual(decision, {
    kind: "daily",
    bucketKey: "d0",
    title: "Ready to log today's meals?",
    message: "You haven't logged anything today. Take a moment to update your nutrition record.",
  });
});

check("logged today, no inactivity milestone due => no reminder at all", () => {
  const loggedThisMorning = new Date("2026-08-10T09:00:00Z");
  const decision = decideTrackerReminder(now, loggedThisMorning, false, UTC);
  assert.strictEqual(decision, null);
});

check("hasn't logged today, no milestone due (e.g. day 10, between milestones) => daily reminder", () => {
  // 10 days since last log: not on the [1,2,3,4,5,6,7,14,21,28,...] ladder,
  // so getInactivityBucket returns null, but the user still hasn't logged
  // today -- the daily nudge should still fire.
  const tenDaysAgo = new Date("2026-07-31T20:00:00Z");
  const decision = decideTrackerReminder(now, tenDaysAgo, false, UTC);
  assert.strictEqual(decision.kind, "daily");
});

check("exactly at the d1 milestone, meal reminders OFF => inactivity reminder, with new copy", () => {
  const yesterday = new Date("2026-08-09T20:00:00Z");
  const decision = decideTrackerReminder(now, yesterday, false, UTC);
  assert.strictEqual(decision.kind, "inactivity");
  assert.strictEqual(decision.bucketKey, "d1");
  assert.strictEqual(decision.title, "Your nutrition log is waiting");
  assert.strictEqual(
    decision.message,
    "It's been a day since you last logged a meal. Check in when you're ready."
  );
});

check("d1 milestone + meal reminders ON => no notification at all (not the daily reminder either)", () => {
  // The d1-skip-if-meal-reminders-enabled exception suppresses the ladder
  // notification for that bucket, and the daily reminder is separately
  // suppressed whenever meal reminders are enabled -- so a user with meal
  // reminders on gets neither a d1 ladder ping nor the daily ping; their
  // own configured meal reminder already covers "haven't logged today".
  const yesterday = new Date("2026-08-09T20:00:00Z");
  const decision = decideTrackerReminder(now, yesterday, true, UTC);
  assert.strictEqual(decision, null);
});

check("meal reminders ON suppresses the daily reminder even with no milestone due", () => {
  const tenDaysAgo = new Date("2026-07-31T20:00:00Z"); // not on the ladder (see earlier check)
  const decision = decideTrackerReminder(now, tenDaysAgo, true, UTC);
  assert.strictEqual(decision, null);
});

check("meal reminders OFF still gets the daily reminder (baseline, unaffected by this suppression)", () => {
  const tenDaysAgo = new Date("2026-07-31T20:00:00Z");
  const decision = decideTrackerReminder(now, tenDaysAgo, false, UTC);
  assert.strictEqual(decision.kind, "daily");
});

check("d2 milestone (past the d1 exception) fires regardless of meal reminders", () => {
  const twoDaysAgo = new Date("2026-08-08T20:00:00Z");
  const decision = decideTrackerReminder(now, twoDaysAgo, true, UTC);
  assert.strictEqual(decision.kind, "inactivity");
  assert.strictEqual(decision.bucketKey, "d2");
});

check("PRIORITY RULE: inactivity milestone due => never also the daily reminder", () => {
  // This is the core "no duplicate same-day notification" guarantee: for
  // every day count that lands on a milestone, decideTrackerReminder must
  // return exactly one decision (the inactivity one), never both/neither.
  const milestoneDaysAgo = [1, 2, 3, 4, 5, 6, 7, 14, 21, 28];
  for (const days of milestoneDaysAgo) {
    const latest = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
    const decision = decideTrackerReminder(now, latest, false, UTC);
    assert.strictEqual(
      decision.kind,
      "inactivity",
      `expected inactivity reminder at ${days} days, got ${JSON.stringify(decision)}`
    );
  }
});

check("week milestone (w2) uses the new reason-first copy", () => {
  const fourteenDaysAgo = new Date(now.getTime() - 14 * 24 * 60 * 60 * 1000);
  const decision = decideTrackerReminder(now, fourteenDaysAgo, false, UTC);
  assert.strictEqual(decision.bucketKey, "w2");
  assert.strictEqual(
    decision.message,
    "It's been 2 weeks since you last logged a meal. Check in when you're ready."
  );
});

// ---------------------------------------------------------------------
// REGRESSION: the meal-reminder blackout bug. checkMealLoggingInactivityReminders
// passes decideTrackerReminder's mealRemindersEnabled parameter as
// hasAnyPersonalizedMealReminderEnabled(user.mealLoggingReminderPrefs) --
// NOT the bare master `enabled` flag. Before this fix, a user with the
// master switch ON but every individual meal OFF would have the daily
// nudge wrongly suppressed (the code assumed master-on meant a
// personalized reminder was covering it), while in reality nothing fires
// for that user anywhere -- breakfast has no fallback, and the tracker
// reminder was the last line of defense. This proves the fix closes that
// gap end-to-end through the real decision function, not just the helper
// in isolation (see test_meal_reminder_fallback.js for that).
// ---------------------------------------------------------------------
check(
  "BLACKOUT BUG FIXED: master ON, all three meals OFF, not logged today => daily reminder still fires",
  () => {
    const prefsMasterOnAllMealsOff = {
      enabled: true,
      breakfast: { enabled: false, hour: 9, minute: 0 },
      lunch: { enabled: false, hour: 13, minute: 0 },
      dinner: { enabled: false, hour: 20, minute: 0 },
    };
    const mealRemindersEnabled = hasAnyPersonalizedMealReminderEnabled(
      prefsMasterOnAllMealsOff
    );
    const decision = decideTrackerReminder(now, null, mealRemindersEnabled, UTC);
    assert.notStrictEqual(
      decision,
      null,
      "the daily reminder must not be suppressed when no meal is actually personalized"
    );
    assert.strictEqual(decision.kind, "daily");
  }
);

check(
  "master ON with at least one meal actually ON still correctly suppresses the daily reminder",
  () => {
    const prefsOneMealOn = {
      enabled: true,
      breakfast: { enabled: true, hour: 9, minute: 0 },
      lunch: { enabled: false, hour: 13, minute: 0 },
      dinner: { enabled: false, hour: 20, minute: 0 },
    };
    const mealRemindersEnabled = hasAnyPersonalizedMealReminderEnabled(prefsOneMealOn);
    const decision = decideTrackerReminder(now, null, mealRemindersEnabled, UTC);
    assert.strictEqual(
      decision,
      null,
      "with a real personalized reminder configured, the generic daily nudge should stay suppressed"
    );
  }
);

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
