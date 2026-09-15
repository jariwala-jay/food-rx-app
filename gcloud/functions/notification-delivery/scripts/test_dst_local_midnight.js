// Regression check for the DST/local-midnight bug fixed in this file's
// localDayStartUtc() -- mirrors
// notification-scheduler/scripts/test_dst_local_midnight.js (same bug,
// same fix, same worked-by-hand expected values), scoped to what this
// file actually uses localDayStartUtc() for: the Tier-2 daily push
// budget's "already sent today" cutoff.
//
// The bug: localDayStartUtc() resolved the timezone offset once, at
// `nowUtc`, and reused that same offset to convert the local calendar
// date's midnight back to UTC. On a DST transition day the offset that
// actually applies AT local midnight can differ from the offset at
// `nowUtc` by up to an hour, so the returned instant was off by that much
// -- shifting the Tier-2 budget window's boundary by an hour on transition
// days.
//
// No test framework dependency by design; run with:
//   node scripts/test_dst_local_midnight.js

const assert = require("assert");
const { localDayStartUtc } = require("../index.js").__testables;

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

function iso(date) {
  return date.toISOString();
}

check("New York: spring-forward transition day (Mar 8, 2026) -- local midnight is 05:00Z, still EST", () => {
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(
    iso(start),
    "2026-03-08T05:00:00.000Z",
    "buggy implementation reused the offset-at-now (EDT -240) and returned 04:00Z instead"
  );
});

check("New York: fall-back transition day (Nov 1, 2026) -- local midnight is 04:00Z, still EDT", () => {
  const start = localDayStartUtc(new Date("2026-11-01T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(
    iso(start),
    "2026-11-01T04:00:00.000Z",
    "buggy implementation reused the offset-at-now (EST -300) and returned 05:00Z instead"
  );
});

check("New York: normal (non-transition) day is unaffected -- 04:00Z in EDT", () => {
  const start = localDayStartUtc(new Date("2026-07-15T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-07-15T04:00:00.000Z");
});

check("Adelaide (half-hour DST zone): spring-forward transition day (Oct 4, 2026) -- local midnight is Oct3 14:30Z", () => {
  const start = localDayStartUtc(new Date("2026-10-04T12:00:00Z"), undefined, "Australia/Adelaide");
  assert.strictEqual(iso(start), "2026-10-03T14:30:00.000Z");
});

check("Kolkata (no DST): normal day -- local midnight is the previous day 18:30Z (+5:30)", () => {
  const start = localDayStartUtc(new Date("2026-06-15T12:00:00Z"), undefined, "Asia/Kolkata");
  assert.strictEqual(iso(start), "2026-06-14T18:30:00.000Z");
});

check("UTC: normal day -- local midnight equals the UTC calendar date", () => {
  const start = localDayStartUtc(new Date("2026-06-15T12:00:00Z"), undefined, "UTC");
  assert.strictEqual(iso(start), "2026-06-15T00:00:00.000Z");
});

check("legacy scalar offset (no timezoneId) on a DST transition day: unchanged from prior fixed-offset behavior", () => {
  const EST = -300;
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), EST, undefined);
  assert.strictEqual(iso(start), "2026-03-08T05:00:00.000Z");
});

check("an unresolvable timezoneId falls back to the stored scalar offset", () => {
  const EST = -300;
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), EST, "Not/ARealZone");
  assert.strictEqual(iso(start), "2026-03-08T05:00:00.000Z");
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
