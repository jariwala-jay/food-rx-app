// Regression check for two things:
//
// 1. The "which activity signal counts as last logged" bug: the meal
//    reminder used to look ONLY at tracker_progress, a once-a-day reset
//    snapshot that's structurally ~1 day stale even for a user logging
//    meals right now. resolveLatestActivityDate() is what fixes that by
//    also considering user_trackers.lastUpdated (updated live on every
//    log) and taking whichever is fresher — this file proves that fix
//    holds, including the exact false-positive scenario it was written for.
//
// 2. The notification copy itself: bucketLabel()'s singular/plural wording
//    and formatMessageWithReason()'s call-to-action-first, reason-last
//    ordering, so a future copy tweak can't silently drop the "since ..."
//    clause or revert the ordering without a test failing.
//
// No test framework dependency by design (see notification-scheduler has
// none configured project-wide); run directly with:
//   node scripts/test_notification_content.js

const assert = require("assert");
const { bucketLabel, formatMessageWithReason, resolveLatestActivityDate, getInactivityBucket } =
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

// -- bucketLabel ------------------------------------------------------------

check("bucketLabel: singular day/week/month reads as prose", () => {
  assert.strictEqual(bucketLabel("d1"), "a day");
  assert.strictEqual(bucketLabel("w1"), "a week");
  assert.strictEqual(bucketLabel("m1"), "a month");
});

check("bucketLabel: plural day/week/month reads as a numeral", () => {
  assert.strictEqual(bucketLabel("d3"), "3 days");
  assert.strictEqual(bucketLabel("w2"), "2 weeks");
  assert.strictEqual(bucketLabel("m6"), "6 months");
});

check("bucketLabel: unrecognized key returns empty string", () => {
  assert.strictEqual(bucketLabel(""), "");
  assert.strictEqual(bucketLabel("x1"), "");
});

// -- formatMessageWithReason --------------------------------------------------

check("formatMessageWithReason: call-to-action first, reason clause last", () => {
  const msg = formatMessageWithReason(
    "Log your food to stay on track with your nutrition goals.",
    "you last logged your meals",
    "d3"
  );
  assert.strictEqual(
    msg,
    "Log your food to stay on track with your nutrition goals. It's been 3 days since you last logged your meals."
  );
});

check("formatMessageWithReason: app inactivity wording", () => {
  const msg = formatMessageWithReason(
    "Open MyFoodRx to review your pantry, trackers and recommendations.",
    "you last opened MyFoodRx",
    "w2"
  );
  assert.strictEqual(
    msg,
    "Open MyFoodRx to review your pantry, trackers and recommendations. It's been 2 weeks since you last opened MyFoodRx."
  );
});

check("formatMessageWithReason: missing/invalid bucket key falls back to the call to action alone", () => {
  const cta = "Open MyFoodRx to review your pantry, trackers and recommendations.";
  assert.strictEqual(formatMessageWithReason(cta, "you last opened MyFoodRx", null), cta);
  assert.strictEqual(formatMessageWithReason(cta, "you last opened MyFoodRx", "bogus"), cta);
});

// -- resolveLatestActivityDate ----------------------------------------------

check("resolveLatestActivityDate: picks the fresher of two valid dates, either order", () => {
  const older = "2026-08-01T00:00:00Z";
  const newer = "2026-08-02T00:00:00Z";
  assert.strictEqual(resolveLatestActivityDate(older, newer).toISOString(), "2026-08-02T00:00:00.000Z");
  assert.strictEqual(resolveLatestActivityDate(newer, older).toISOString(), "2026-08-02T00:00:00.000Z");
});

check("resolveLatestActivityDate: tolerates missing, null, and invalid values", () => {
  const valid = "2026-08-02T00:00:00Z";
  assert.strictEqual(resolveLatestActivityDate(undefined, valid).toISOString(), "2026-08-02T00:00:00.000Z");
  assert.strictEqual(resolveLatestActivityDate(null, valid).toISOString(), "2026-08-02T00:00:00.000Z");
  assert.strictEqual(resolveLatestActivityDate("not-a-date", valid).toISOString(), "2026-08-02T00:00:00.000Z");
  assert.strictEqual(resolveLatestActivityDate(undefined, null), null);
});

check(
  "REGRESSION (meal reminder false positive): same-day live tracker update beats a stale tracker_progress row",
  () => {
    // Exactly the bug scenario reported: tracker_progress's latest row is
    // always yesterday's closed day (reset runs right after local
    // midnight), but the user has already logged meals today via
    // user_trackers, which updates lastUpdated live. Before the fix, only
    // progressDate was checked, so this always looked like exactly 1 day
    // of inactivity and fired "Don't forget to log your meals" regardless
    // of same-day logging.
    const now = new Date("2026-08-02T20:00:00Z"); // 8pm UTC, tracker-reminder check time
    const progressDateYesterday = "2026-08-01T04:00:00Z"; // last night's closed-day snapshot
    const trackerUpdatedToday = "2026-08-02T13:00:00Z"; // user logged a meal this afternoon

    const latest = resolveLatestActivityDate(progressDateYesterday, trackerUpdatedToday);
    const bucket = getInactivityBucket(now, latest, [1, 2, 3, 4, 5, 6], [7, 14, 21, 28], [], 0);

    assert.strictEqual(bucket, null, "no reminder should fire for a user who logged today");
  }
);

check(
  "REGRESSION (meal reminder true positive still works): no live tracker update, only a stale progress row",
  () => {
    // Same shape, but the user genuinely hasn't logged anything live today
    // either -- the d1 bucket should still fire as before.
    const now = new Date("2026-08-02T20:00:00Z");
    const progressDateYesterday = "2026-08-01T04:00:00Z";

    const latest = resolveLatestActivityDate(progressDateYesterday, undefined);
    const bucket = getInactivityBucket(now, latest, [1, 2, 3, 4, 5, 6], [7, 14, 21, 28], [], 0);

    assert.deepStrictEqual(bucket, { key: "d1", days: 1 });
  }
);

console.log(`\n${passed} passed${process.exitCode ? ", with failures above" : ""}`);
