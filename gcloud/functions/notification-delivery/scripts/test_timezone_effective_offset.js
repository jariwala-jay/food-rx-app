// Regression check for this file's copy of getOffsetMinutesForZone()/
// effectiveOffsetMinutes() -- confirms quiet hours, pantry collision, and
// the Tier-2 local-day check all read from the same DST-safe source.
// Mirrors notification-scheduler/scripts/test_timezone_local_time.js.
//
// No test framework dependency by design; run with:
//   node scripts/test_timezone_effective_offset.js

const assert = require("assert");
const {
  getOffsetMinutesForZone,
  effectiveOffsetMinutes,
  localHourOf,
  localMinutesOfDay,
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

check("New York: EST in winter, EDT in summer", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "America/New_York"), -300);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "America/New_York"), -240);
});

check("India: fixed +330, no DST", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "Asia/Kolkata"), 330);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "Asia/Kolkata"), 330);
});

check("Sydney: DST is opposite-season from the US/UK (AEDT +660 in January, AEST +600 in July)", () => {
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-01-15T12:00:00Z"), "Australia/Sydney"), 660);
  assert.strictEqual(getOffsetMinutesForZone(new Date("2026-07-15T12:00:00Z"), "Australia/Sydney"), 600);
});

check("effectiveOffsetMinutes prefers IANA over a stale stored offset", () => {
  const now = new Date("2026-01-15T12:00:00Z"); // EST instant
  const user = { timezoneId: "America/New_York", timezoneOffsetMinutes: -240 }; // stale summer value
  assert.strictEqual(effectiveOffsetMinutes(now, user), -300);
});

check("effectiveOffsetMinutes falls back to stored offset for an invalid timezoneId, then to 0 for neither", () => {
  const now = new Date("2026-01-15T12:00:00Z");
  assert.strictEqual(effectiveOffsetMinutes(now, { timezoneId: "Not/Real", timezoneOffsetMinutes: -300 }), -300);
  assert.strictEqual(effectiveOffsetMinutes(now, {}), 0);
  assert.strictEqual(effectiveOffsetMinutes(now, null), 0);
});

check("quiet-hours localHourOf and pantry localMinutesOfDay stay correct with an IANA-resolved offset", () => {
  // 14:30 UTC = 20:00 IST (+5:30).
  const now = new Date("2026-01-15T14:30:00Z");
  const offset = effectiveOffsetMinutes(now, { timezoneId: "Asia/Kolkata" });
  assert.strictEqual(localHourOf(now, offset), 20);
  assert.strictEqual(localMinutesOfDay(now, offset), 20 * 60);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
