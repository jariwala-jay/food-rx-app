// Lightweight regression check for the timezone-aware milestone math in
// getInactivityBucket() / dayDiffFloor() / addMonthsLocalDayStartUtc().
//
// This exists to guard against reintroducing the bug those functions were
// written to fix: computing "days since last log/active" against the
// server runtime's (UTC) calendar day instead of the user's own local
// calendar day. That bug produced no syntax error and no runtime failure —
// only silently wrong milestone timing for any user not in the runtime's
// timezone — which is exactly the kind of regression that's easy to
// reintroduce later without a check like this one.
//
// No test framework dependency by design (see notification-scheduler has
// none configured project-wide); run directly with:
//   node scripts/test_inactivity_bucket.js

const assert = require("assert");
const { localDayStartUtc, dayDiffFloor, addMonthsLocalDayStartUtc, getInactivityBucket } =
  require("../index.js").__testables;

const IST = 330; // UTC+5:30
const ET_DST = -240; // America/New_York during EDT
const EST = -300; // America/New_York during EST (standard time)
const PT = -480; // America/Los_Angeles during PST

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

check("India local day boundary: two local midnights crossed -> 2-day gap", () => {
  // Last logged Aug 1, 23:30 IST; evaluated Aug 3, 04:30 IST.
  const lastLogged = new Date("2026-08-01T18:00:00Z");
  const evaluatedAt = new Date("2026-08-02T23:00:00Z");
  assert.strictEqual(dayDiffFloor(evaluatedAt, lastLogged, IST), 2);
});

check("Same UTC instant, different offsets -> different day counts", () => {
  // Last logged Aug 1, 23:30 ET (EDT); "now" is Aug 2, 00:15 ET -- just
  // after ET midnight, but still before PT midnight the same instant.
  const lastLogged = new Date("2026-08-02T03:30:00Z");
  const now = new Date("2026-08-02T04:15:00Z");
  assert.strictEqual(
    dayDiffFloor(now, lastLogged, ET_DST),
    1,
    "ET user should already be 1 day past their local midnight"
  );
  assert.strictEqual(
    dayDiffFloor(now, lastLogged, PT),
    0,
    "PT user's local midnight hasn't happened yet at the same instant"
  );
});

check("Month-end clamping: Jan 31 local + 1 month -> Feb 28 local midnight (non-leap year)", () => {
  const jan31LocalMidnight = new Date("2026-01-31T05:00:00Z"); // 00:00 EST (UTC-5)
  const target = addMonthsLocalDayStartUtc(jan31LocalMidnight, 1, EST);
  assert.strictEqual(target.toISOString(), "2026-02-28T05:00:00.000Z");
});

check("getInactivityBucket: day milestone matches using the user's local day count", () => {
  const lastLogged = new Date("2026-08-01T18:00:00Z"); // Aug 1, 23:30 IST
  const evaluatedAt = new Date("2026-08-03T05:00:00Z"); // Aug 3, 10:30 IST -> 2 local days
  const bucket = getInactivityBucket(evaluatedAt, lastLogged, [1, 2, 3, 4, 5, 6], [7, 14, 21, 28], [], IST);
  assert.deepStrictEqual(bucket, { key: "d2", days: 2 });
});

check("getInactivityBucket: month milestone matches on the user's local calendar anniversary", () => {
  const lastLogged = new Date("2026-01-31T05:00:00Z"); // Jan 31, 00:00 EST
  const evaluatedAt = new Date("2026-02-28T05:00:00Z"); // Feb 28, 00:00 EST
  const bucket = getInactivityBucket(evaluatedAt, lastLogged, [], [], [1, 2, 3], EST);
  assert.strictEqual(bucket.key, "m1");
});

check("localDayStartUtc: sanity check, offset applied and reversible", () => {
  const instant = new Date("2026-08-02T04:15:00Z");
  const start = localDayStartUtc(instant, ET_DST);
  // Aug 2, 04:15 UTC = Aug 2, 00:15 ET -> local midnight is Aug 2 00:00 ET = Aug 2 04:00 UTC.
  assert.strictEqual(start.toISOString(), "2026-08-02T04:00:00.000Z");
});

console.log(`\n${passed} passed${process.exitCode ? ", with failures above" : ""}`);
