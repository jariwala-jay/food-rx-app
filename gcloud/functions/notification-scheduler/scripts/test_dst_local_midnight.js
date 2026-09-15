// Regression check for the DST/local-midnight bug fixed in
// localDayStartUtc() / dayDiffFloor() / addMonthsLocalDayStartUtc().
//
// The bug: these helpers resolved the timezone offset ONCE (at "now", or
// at whatever instant the caller happened to pass in) and reused that
// single offset for every date/midnight calculation involved -- including
// midnights and activity instants that fall on a DIFFERENT side of a DST
// transition, where the real offset differs by up to an hour. That
// produced two distinct failure modes, both reproduced below:
//
//   1. localDayStartUtc() itself could compute the wrong UTC instant for
//      a DST-transition day's local midnight (off by exactly the DST
//      shift, in either direction).
//   2. dayDiffFloor() could misclassify a 2-local-calendar-day gap as 1
//      day (or vice versa) whenever the gap spans a transition, because
//      it used to diff two local-midnight UTC *timestamps* and divide by
//      a fixed 24h -- which isn't valid on a day that's actually 23 or 25
//      real hours long.
//
// Expected values below are worked out by hand from the DST transition
// rules (verified independently via getOffsetMinutesForZone(), which is
// a distinct, separately-tested primitive -- not the functions under
// test here) rather than by calling localDayStartUtc()/dayDiffFloor()
// themselves to produce their own expected output.
//
// No test framework dependency by design; run with:
//   node scripts/test_dst_local_midnight.js

const assert = require("assert");
const {
  localDayStartUtc,
  dayDiffFloor,
  addMonthsLocalDayStartUtc,
  getInactivityBucket,
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

function iso(date) {
  return date.toISOString();
}

// ---------------------------------------------------------------------
// 1. localDayStartUtc() -- local midnight, expressed in UTC, for a
//    representative "now" on each kind of day.
// ---------------------------------------------------------------------

// America/New_York: EST (UTC-5) in winter, EDT (UTC-4) in summer.
// 2026 transitions: spring-forward at 2026-03-08T07:00:00Z (2am EST ->
// 3am EDT), fall-back at 2026-11-01T06:00:00Z (2am EDT -> 1am EST).
check("New York: normal winter day -- local midnight is 05:00Z (EST)", () => {
  const start = localDayStartUtc(new Date("2026-01-15T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-01-15T05:00:00.000Z");
});

check("New York: normal summer day -- local midnight is 04:00Z (EDT)", () => {
  const start = localDayStartUtc(new Date("2026-07-15T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-07-15T04:00:00.000Z");
});

check("New York: spring-forward transition day (Mar 8) -- local midnight is 05:00Z, still EST (the day STARTS before the 2am transition)", () => {
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(
    iso(start),
    "2026-03-08T05:00:00.000Z",
    "buggy implementation reused the offset-at-now (EDT -240) and returned 04:00Z instead"
  );
});

check("New York: fall-back transition day (Nov 1) -- local midnight is 04:00Z, still EDT (the day STARTS before the 2am transition)", () => {
  const start = localDayStartUtc(new Date("2026-11-01T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(
    iso(start),
    "2026-11-01T04:00:00.000Z",
    "buggy implementation reused the offset-at-now (EST -300) and returned 05:00Z instead"
  );
});

check("New York: day immediately BEFORE spring-forward (Mar 7) -- ordinary EST day, 05:00Z", () => {
  const start = localDayStartUtc(new Date("2026-03-07T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-03-07T05:00:00.000Z");
});

check("New York: day immediately AFTER spring-forward (Mar 9) -- ordinary EDT day, 04:00Z", () => {
  const start = localDayStartUtc(new Date("2026-03-09T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-03-09T04:00:00.000Z");
});

check("New York: day immediately BEFORE fall-back (Oct 31) -- ordinary EDT day, 04:00Z", () => {
  const start = localDayStartUtc(new Date("2026-10-31T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-10-31T04:00:00.000Z");
});

check("New York: day immediately AFTER fall-back (Nov 2) -- ordinary EST day, 05:00Z", () => {
  const start = localDayStartUtc(new Date("2026-11-02T12:00:00Z"), undefined, "America/New_York");
  assert.strictEqual(iso(start), "2026-11-02T05:00:00.000Z");
});

// Europe/London: GMT (UTC+0) in winter, BST (UTC+1) in summer. 2026
// transitions at 2026-03-29T01:00:00Z (spring-forward) and
// 2026-10-25T01:00:00Z (fall-back) -- both at 1am UTC, the EU-wide rule.
check("London: spring-forward transition day (Mar 29) -- local midnight is 00:00Z, still GMT", () => {
  const start = localDayStartUtc(new Date("2026-03-29T12:00:00Z"), undefined, "Europe/London");
  assert.strictEqual(iso(start), "2026-03-29T00:00:00.000Z");
});

check("London: fall-back transition day (Oct 25) -- local midnight is Oct24 23:00Z, still BST", () => {
  const start = localDayStartUtc(new Date("2026-10-25T12:00:00Z"), undefined, "Europe/London");
  assert.strictEqual(
    iso(start),
    "2026-10-24T23:00:00.000Z",
    "buggy implementation reused the offset-at-now (GMT +0) and returned Oct25 00:00Z instead"
  );
});

// Australia/Sydney: AEST (UTC+10) in their winter, AEDT (UTC+11) in
// their summer -- DST season is opposite the Northern Hemisphere.
// 2026: spring-forward (DST start) at local 2am->3am on Oct 4;
// fall-back (DST end) at local 3am->2am on Apr 5.
check("Sydney: spring-forward transition day (Oct 4) -- local midnight is Oct3 14:00Z, still AEST", () => {
  const start = localDayStartUtc(new Date("2026-10-04T12:00:00Z"), undefined, "Australia/Sydney");
  assert.strictEqual(iso(start), "2026-10-03T14:00:00.000Z");
});

check("Sydney: fall-back transition day (Apr 5) -- local midnight is Apr4 13:00Z, still AEDT", () => {
  const start = localDayStartUtc(new Date("2026-04-05T12:00:00Z"), undefined, "Australia/Sydney");
  assert.strictEqual(iso(start), "2026-04-04T13:00:00.000Z");
});

// Australia/Adelaide: ACST (UTC+9:30) / ACDT (UTC+10:30) -- same 2026
// transition days as Sydney, but a half-hour base offset, proving the
// fix isn't accidentally hardcoded around whole-hour arithmetic.
check("Adelaide: spring-forward transition day (Oct 4) -- local midnight is Oct3 14:30Z, still ACST (+9:30)", () => {
  const start = localDayStartUtc(new Date("2026-10-04T12:00:00Z"), undefined, "Australia/Adelaide");
  assert.strictEqual(iso(start), "2026-10-03T14:30:00.000Z");
});

check("Adelaide: fall-back transition day (Apr 5) -- local midnight is Apr4 13:30Z, still ACDT (+10:30)", () => {
  const start = localDayStartUtc(new Date("2026-04-05T12:00:00Z"), undefined, "Australia/Adelaide");
  assert.strictEqual(iso(start), "2026-04-04T13:30:00.000Z");
});

// Asia/Kolkata: fixed +330 (UTC+5:30) year-round, no DST -- confirms an
// ordinary half-hour zone with no transitions is untouched by the fix.
check("Kolkata: normal day -- local midnight is the previous day 18:30Z (+5:30)", () => {
  const start = localDayStartUtc(new Date("2026-06-15T12:00:00Z"), undefined, "Asia/Kolkata");
  assert.strictEqual(iso(start), "2026-06-14T18:30:00.000Z");
});

// UTC: offset 0, the trivial case.
check("UTC: normal day -- local midnight equals the UTC calendar date", () => {
  const start = localDayStartUtc(new Date("2026-06-15T12:00:00Z"), undefined, "UTC");
  assert.strictEqual(iso(start), "2026-06-15T00:00:00.000Z");
});

// ---------------------------------------------------------------------
// 1b. Legacy scalar-offset fallback (no timezoneId) -- must remain
//     exactly the old fixed-offset behavior, DST correction included.
// ---------------------------------------------------------------------
check("legacy scalar offset (no timezoneId): behaves like a plain fixed UTC-5 offset, no DST awareness", () => {
  const EST = -300;
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), EST, undefined);
  // No timezoneId means no DST correction is possible -- this is expected
  // to differ from the timezoneId-aware New York result above (which
  // returns 05:00Z); a legacy user without a synced IANA zone simply
  // doesn't get the DST fix, same as before.
  assert.strictEqual(iso(start), "2026-03-08T05:00:00.000Z");
});

check("legacy scalar offset with an unresolvable timezoneId falls back to the scalar, unaffected by DST", () => {
  const EST = -300;
  const start = localDayStartUtc(new Date("2026-03-08T12:00:00Z"), EST, "Not/ARealZone");
  assert.strictEqual(iso(start), "2026-03-08T05:00:00.000Z");
});

// ---------------------------------------------------------------------
// 2. dayDiffFloor() -- the exact reproduced bug, plus its fall-back
//    mirror image, plus non-DST regression coverage.
// ---------------------------------------------------------------------
check("dayDiffFloor: March 7 11pm EST activity vs March 9 check (spans spring-forward) -- 2 local days, not 1", () => {
  // Mar 7, 11:00 PM EST = Mar 8, 04:00 UTC.
  const activity = new Date("2026-03-08T04:00:00Z");
  // Some afternoon instant on Mar 9, well after the spring-forward transition.
  const checkedAt = new Date("2026-03-09T15:00:00Z");
  assert.strictEqual(dayDiffFloor(checkedAt, activity, undefined, "America/New_York"), 2);
});

check("dayDiffFloor: fall-back mirror -- activity just after Nov 1 midnight EDT vs Nov 2 check -- 1 local day, not 2", () => {
  // Nov 1, 00:15 AM EDT (just after local midnight, still EDT since the
  // 2am->1am transition hasn't happened yet) = Nov 1, 04:15 UTC. The old
  // implementation, reusing the offset resolved at the LATER "now" (EST,
  // after the transition), would misread this instant as Oct 31, 11:15 PM
  // -- one calendar day too early -- inflating the gap to Nov2 by 2 days
  // instead of the true 1.
  const activity = new Date("2026-11-01T04:15:00Z");
  const checkedAt = new Date("2026-11-02T15:00:00Z");
  assert.strictEqual(dayDiffFloor(checkedAt, activity, undefined, "America/New_York"), 1);
});

check("dayDiffFloor: a 7-day gap spanning spring-forward still counts as exactly 7 local days (not 6, from dividing a 167h real gap by 24h)", () => {
  const weekAgo = new Date("2026-03-01T05:00:00Z"); // Mar 1, 00:00 EST
  const now = new Date("2026-03-08T13:00:00Z"); // well after the Mar 8 transition
  assert.strictEqual(dayDiffFloor(now, weekAgo, undefined, "America/New_York"), 7);
});

check("dayDiffFloor: normal non-DST regression (India) -- unaffected by the fix", () => {
  const lastLogged = new Date("2026-06-01T18:00:00Z"); // Jun 1, 23:30 IST
  const evaluatedAt = new Date("2026-06-03T04:30:00Z"); // Jun 3, 10:00 IST
  assert.strictEqual(dayDiffFloor(evaluatedAt, lastLogged, undefined, "Asia/Kolkata"), 2);
});

check("dayDiffFloor: same-instant sanity check -- 0 days when both are the same local day", () => {
  const morning = new Date("2026-06-15T10:00:00Z");
  const evening = new Date("2026-06-15T22:00:00Z");
  assert.strictEqual(dayDiffFloor(evening, morning, undefined, "America/New_York"), 0);
});

// ---------------------------------------------------------------------
// 3. Milestone bucket regression -- getInactivityBucket() built on top
//    of the corrected dayDiffFloor()/localDayStartUtc()/
//    addMonthsLocalDayStartUtc(). The March 7 -> March 9 case is the
//    most important: it must classify as d2, never d1.
// ---------------------------------------------------------------------
check("getInactivityBucket: March 7 -> March 9 (spring-forward) classifies as d2, NOT d1", () => {
  const activity = new Date("2026-03-08T04:00:00Z"); // Mar7 11pm EST
  const checkedAt = new Date("2026-03-09T15:00:00Z");
  const bucket = getInactivityBucket(
    checkedAt,
    activity,
    [1, 2, 3, 4, 5, 6],
    [7, 14, 21, 28],
    [],
    undefined,
    "America/New_York"
  );
  assert.deepStrictEqual(bucket, { key: "d2", days: 2 });
});

check("getInactivityBucket: weekly milestone still lands on w1 across a spring-forward-spanning week", () => {
  const activity = new Date("2026-03-01T05:00:00Z"); // Mar1 00:00 EST
  const checkedAt = new Date("2026-03-08T13:00:00Z");
  const bucket = getInactivityBucket(
    checkedAt,
    activity,
    [1, 2, 3, 4, 5, 6],
    [7, 14, 21, 28],
    [],
    undefined,
    "America/New_York"
  );
  assert.deepStrictEqual(bucket, { key: "w1", days: 7 });
});

check("getInactivityBucket: monthly milestone lands on m1 exactly one calendar month later, spanning spring-forward", () => {
  const activity = new Date("2026-02-15T05:00:00Z"); // Feb15 00:00 EST
  const checkedAt = new Date("2026-03-15T04:00:00Z"); // Mar15 00:00 EDT local midnight, exactly
  const bucket = getInactivityBucket(checkedAt, activity, [], [], [1, 2, 3], undefined, "America/New_York");
  assert.strictEqual(bucket.key, "m1");
});

// ---------------------------------------------------------------------
// 4. addMonthsLocalDayStartUtc() -- month/local-date correctness across
//    DST, clamping, and year boundaries.
// ---------------------------------------------------------------------
check("addMonthsLocalDayStartUtc: Feb15 EST + 1 month -> Mar15 local midnight, now correctly in EDT", () => {
  const feb15 = new Date("2026-02-15T05:00:00Z"); // Feb15 00:00 EST
  const target = addMonthsLocalDayStartUtc(feb15, 1, undefined, "America/New_York");
  assert.strictEqual(
    iso(target),
    "2026-03-15T04:00:00.000Z",
    "buggy implementation reused Feb's EST offset for March's EDT midnight and returned 05:00Z instead"
  );
});

check("addMonthsLocalDayStartUtc: Mar1 EST + 1 month -> Apr1 EDT local midnight, local calendar date unshifted by DST", () => {
  const mar1 = new Date("2026-03-01T05:00:00Z");
  const target = addMonthsLocalDayStartUtc(mar1, 1, undefined, "America/New_York");
  assert.strictEqual(iso(target), "2026-04-01T04:00:00.000Z");
});

check("addMonthsLocalDayStartUtc: month-end clamping still works with a timezoneId (Jan31 -> Feb28, non-leap year)", () => {
  const jan31 = new Date("2026-01-31T05:00:00Z"); // Jan31 00:00 EST
  const target = addMonthsLocalDayStartUtc(jan31, 1, undefined, "America/New_York");
  assert.strictEqual(iso(target), "2026-02-28T05:00:00.000Z");
});

check("addMonthsLocalDayStartUtc: year boundary -- Dec15 + 1 month -> Jan15 the following year", () => {
  const dec15 = new Date("2025-12-15T05:00:00Z");
  const target = addMonthsLocalDayStartUtc(dec15, 1, undefined, "America/New_York");
  assert.strictEqual(iso(target), "2026-01-15T05:00:00.000Z");
});

check("addMonthsLocalDayStartUtc: non-DST, fractional-offset zone (Kolkata) unaffected", () => {
  const jan15 = new Date("2026-01-14T18:30:00Z"); // Jan15 00:00 IST
  const target = addMonthsLocalDayStartUtc(jan15, 1, undefined, "Asia/Kolkata");
  assert.strictEqual(iso(target), "2026-02-14T18:30:00.000Z");
});

check("addMonthsLocalDayStartUtc: legacy scalar offset (no timezoneId) unchanged from prior fixed-offset behavior", () => {
  const EST = -300;
  const jan31 = new Date("2026-01-31T05:00:00Z");
  const target = addMonthsLocalDayStartUtc(jan31, 1, EST, undefined);
  assert.strictEqual(iso(target), "2026-02-28T05:00:00.000Z");
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
