// DST-correctness check for getOffsetMinutesForZone()/effectiveOffsetMinutes(),
// the timezoneId-aware offset resolution used by tracker_reminder,
// app_inactivity_reminder, expiring_ingredients, and expired_items to
// reach their local-time targets. Covers DST transitions, half-hour
// zones, and missing/invalid timezone data.
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_meal_reminder_fallback.js); run with:
//   node scripts/test_timezone_local_time.js

const assert = require("assert");
const {
  getOffsetMinutesForZone,
  effectiveOffsetMinutes,
  localMinutesOfDay,
  localDayStartUtc,
  TRACKER_REMINDER_TARGET_MINUTES,
  APP_INACTIVITY_TARGET_MINUTES,
  EXPIRING_INGREDIENTS_TARGET_MINUTES,
  EXPIRED_ITEMS_TARGET_MINUTES,
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

// ---------------------------------------------------------------------
// 0. Target-minute constants themselves.
// ---------------------------------------------------------------------
check("target minutes: tracker 7pm, app-inactivity 9am, expiring/expired 8am", () => {
  assert.strictEqual(TRACKER_REMINDER_TARGET_MINUTES, 19 * 60);
  assert.strictEqual(APP_INACTIVITY_TARGET_MINUTES, 9 * 60);
  assert.strictEqual(EXPIRING_INGREDIENTS_TARGET_MINUTES, 8 * 60);
  assert.strictEqual(EXPIRED_ITEMS_TARGET_MINUTES, 8 * 60);
});

// ---------------------------------------------------------------------
// 1. New York -- winter (EST, UTC-5), summer (EDT, UTC-4), and both 2026
//    DST transition instants (spring-forward Mar 8, fall-back Nov 1).
// ---------------------------------------------------------------------
check("New York winter (EST): offset is -300 (UTC-5)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "America/New_York"), -300);
});

check("New York summer (EDT): offset is -240 (UTC-4)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "America/New_York"), -240);
});

check("New York spring-forward (2026-03-08 2am EST -> 3am EDT): offset flips at the transition instant", () => {
  // 2:00am EST is 07:00 UTC. One minute before, still EST (-300); at and
  // after, EDT (-240) -- clocks skip 2:00-2:59am local entirely that day.
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-03-08T06:59:00Z"), "America/New_York"), -300);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-03-08T07:00:00Z"), "America/New_York"), -240);
});

check("New York fall-back (2026-11-01 2am EDT -> 1am EST): offset flips at the transition instant", () => {
  // 2:00am EDT is 06:00 UTC. One minute before, still EDT (-240); at and
  // after, EST (-300) -- clocks repeat 1:00-1:59am local that day.
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-11-01T05:59:00Z"), "America/New_York"), -240);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-11-01T06:00:00Z"), "America/New_York"), -300);
});

// ---------------------------------------------------------------------
// 2. California -- winter (PST, UTC-8), summer (PDT, UTC-7). Same US DST
//    rule dates as New York, verified independently.
// ---------------------------------------------------------------------
check("California winter (PST): offset is -480 (UTC-8)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "America/Los_Angeles"), -480);
});

check("California summer (PDT): offset is -420 (UTC-7)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "America/Los_Angeles"), -420);
});

// ---------------------------------------------------------------------
// 3. London -- winter (GMT, UTC+0), summer (BST, UTC+1).
// ---------------------------------------------------------------------
check("London winter (GMT): offset is 0", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "Europe/London"), 0);
});

check("London summer (BST): offset is +60 (UTC+1)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "Europe/London"), 60);
});

// ---------------------------------------------------------------------
// 4. India -- no DST ever, fixed UTC+5:30 (a half-hour offset -- proves
//    the minute-granularity arithmetic doesn't round or truncate).
// ---------------------------------------------------------------------
check("India: fixed +330 (UTC+5:30) year-round, no DST in either season", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "Asia/Kolkata"), 330);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "Asia/Kolkata"), 330);
});

// ---------------------------------------------------------------------
// 5. Sydney -- Australian DST runs opposite season from the US/UK: AEDT
//    (+660) in their summer, AEST (+600) in their winter.
// ---------------------------------------------------------------------
check("Sydney in January (their DST summer, AEDT): offset is +660 (UTC+11)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "Australia/Sydney"), 660);
});

check("Sydney in July (their non-DST winter, AEST): offset is +600 (UTC+10)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "Australia/Sydney"), 600);
});

// ---------------------------------------------------------------------
// 6. effectiveOffsetMinutes() fallback precedence: IANA > stored offset > 0.
// ---------------------------------------------------------------------
check("effectiveOffsetMinutes prefers a valid IANA id over a stale/wrong stored offset", () => {
  const now = new Date("2026-07-15T12:00:00Z"); // EDT instant
  const user = { timezoneId: "America/New_York", timezoneOffsetMinutes: 9999 };
  assert.strictEqual(effectiveOffsetMinutes(now, user), -240);
});

check("effectiveOffsetMinutes falls back to the stored offset when timezoneId is absent", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  const user = { timezoneOffsetMinutes: -240 };
  assert.strictEqual(effectiveOffsetMinutes(now, user), -240);
});

check("effectiveOffsetMinutes falls back to the stored offset when timezoneId is invalid/unresolvable", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  const user = { timezoneId: "Not/ARealZone", timezoneOffsetMinutes: -240 };
  assert.strictEqual(effectiveOffsetMinutes(now, user), -240);
});

check("effectiveOffsetMinutes falls back to the stored offset when timezoneId is the wrong type", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  const user = { timezoneId: 12345, timezoneOffsetMinutes: -240 };
  assert.strictEqual(effectiveOffsetMinutes(now, user), -240);
});

check("effectiveOffsetMinutes falls back to 0/UTC when neither field is usable (brand new/never-synced user)", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  assert.strictEqual(effectiveOffsetMinutes(now, {}), 0);
  assert.strictEqual(effectiveOffsetMinutes(now, { timezoneOffsetMinutes: "not a number" }), 0);
  assert.strictEqual(effectiveOffsetMinutes(now, null), 0);
  assert.strictEqual(effectiveOffsetMinutes(now, undefined), 0);
});

check("effectiveOffsetMinutes returns the current offset, not a stale synced one", () => {
  const winterNow = new Date("2026-01-15T12:00:00Z");
  const user = { timezoneId: "America/New_York", timezoneOffsetMinutes: -240 };
  assert.strictEqual(effectiveOffsetMinutes(winterNow, user), -300);
});

// ---------------------------------------------------------------------
// 7. Travel: a changed timezoneId resolves to the new zone immediately.
// ---------------------------------------------------------------------
check("travel: changing timezoneId between calls changes the resolved offset accordingly", () => {
  const now = new Date("2026-07-15T12:00:00Z");
  const nyOffset = effectiveOffsetMinutes(now, { timezoneId: "America/New_York" });
  const laOffset = effectiveOffsetMinutes(now, { timezoneId: "America/Los_Angeles" });
  assert.strictEqual(nyOffset, -240);
  assert.strictEqual(laOffset, -420);
  assert.notStrictEqual(nyOffset, laOffset);
});

// ---------------------------------------------------------------------
// 8. Local-time targets reached in each region: tracker (7pm), app
//    inactivity (9am), expiring/expired (8am).
// ---------------------------------------------------------------------
const REGIONS = [
  // [label, IANA id, a representative summer/local-standard-adjacent date,
  //  UTC hour:minute of local midnight that day]
  { label: "New York", zone: "America/New_York", date: "2026-07-15", utcMidnightHour: 4 }, // EDT -4
  { label: "California", zone: "America/Los_Angeles", date: "2026-07-15", utcMidnightHour: 7 }, // PDT -7
  { label: "London", zone: "Europe/London", date: "2026-07-15", utcMidnightHour: 23, prevDay: true }, // BST +1 -> local midnight is 23:00 UTC the PREVIOUS day
  { label: "India", zone: "Asia/Kolkata", date: "2026-07-15", utcMidnightHour: 18, prevDay: true, utcMidnightMinute: 30 }, // +5:30 -> 18:30 UTC previous day
  { label: "Sydney", zone: "Australia/Sydney", date: "2026-07-15", utcMidnightHour: 14, prevDay: true }, // AEST +10 (winter there) -> 14:00 UTC previous day
];

function utcInstantForLocalMinutes(region, targetMinutes) {
  const [y, m, d] = region.date.split("-").map(Number);
  const dayOffset = region.prevDay ? -1 : 0;
  const baseUtcMs = Date.UTC(y, m - 1, d + dayOffset, region.utcMidnightHour, region.utcMidnightMinute || 0, 0);
  return new Date(baseUtcMs + targetMinutes * 60 * 1000);
}

for (const region of REGIONS) {
  for (const [name, targetMinutes] of [
    ["tracker (7pm)", TRACKER_REMINDER_TARGET_MINUTES],
    ["app inactivity (9am)", APP_INACTIVITY_TARGET_MINUTES],
    ["expiring/expired (8am)", EXPIRING_INGREDIENTS_TARGET_MINUTES],
  ]) {
    check(`${region.label}: local time reaches the ${name} target exactly, not one minute early`, () => {
      const atTarget = utcInstantForLocalMinutes(region, targetMinutes);
      const oneMinuteEarly = utcInstantForLocalMinutes(region, targetMinutes - 1);
      const offsetAtTarget = effectiveOffsetMinutes(atTarget, { timezoneId: region.zone });
      const offsetEarly = effectiveOffsetMinutes(oneMinuteEarly, { timezoneId: region.zone });
      assert.strictEqual(localMinutesOfDay(atTarget, offsetAtTarget), targetMinutes);
      assert.ok(
        localMinutesOfDay(oneMinuteEarly, offsetEarly) < targetMinutes,
        `${region.label} one minute before the target must not already read as past it`
      );
    });
  }
}

// ---------------------------------------------------------------------
// 9. Local-day boundary stays correct for a user far ahead of UTC.
// ---------------------------------------------------------------------
check("Sydney: local calendar day is already 'tomorrow' relative to UTC", () => {
  // Still July 15 in UTC, but Sydney (AEST +600) is 10 hours ahead: July 16 local.
  const now = new Date("2026-07-15T20:00:00Z");
  const offset = effectiveOffsetMinutes(now, { timezoneId: "Australia/Sydney" });
  const localDayStart = localDayStartUtc(now, offset);
  assert.strictEqual(localDayStart.toISOString(), "2026-07-15T14:00:00.000Z");
});

// ---------------------------------------------------------------------
// 10. Missing timezone data resolves to plain UTC without crashing.
// ---------------------------------------------------------------------
check("a user document with no timezone fields resolves to UTC (0)", () => {
  const now = new Date();
  assert.strictEqual(effectiveOffsetMinutes(now, { email: "no-timezone-yet@example.com" }), 0);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
