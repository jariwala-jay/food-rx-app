// Regression check for getEnabledMealMinutes()'s preference resolution.
//
// Bug fixed here: getEnabledMealMinutes() used to gate ALL THREE meals on
// a single top-level `prefs.enabled` flag -- the old, pre-per-meal-toggle
// preference format. Since Meal Reminders became three independent
// breakfast/lunch/dinner toggles, that meant a user with e.g. only Dinner
// enabled would still get pantry-collision avoidance around breakfast/lunch
// times too (false positives, deferring a pantry push for a meal reminder
// that isn't even on), while a user with the master flag off but one meal
// individually on got NO collision avoidance at all around that meal (false
// negative -- exactly the kind of disagreement between actual Meal Reminder
// settings and this pantry-deferral behavior this fix closes).
//
// getEnabledMealMinutes() now resolves each meal via
// isPersonalizedMealReminderEnabled() -- the same per-meal/master
// resolution used by notification-scheduler/index.js's fallback-reminder
// eligibility check and mirrored from
// lib/core/utils/meal_reminder_prefs.dart -- so collision avoidance always
// agrees with whatever the user's actual Meal Reminder toggles say.
//
// No test framework dependency by design (matches
// notification-delivery/scripts/test_notification_preferences.js); run with:
//   node scripts/test_meal_collision_prefs.js

const assert = require("assert");
const {
  getEnabledMealMinutes,
  isWithinMealCollisionWindow,
  isMealRemindersMasterEnabled,
  mealReminderOwnEnabled,
  isPersonalizedMealReminderEnabled,
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

function newFormatUser({ master = true, breakfast = false, lunch = false, dinner = false } = {}) {
  return {
    mealLoggingReminderPrefs: {
      enabled: master,
      breakfast: { enabled: breakfast, hour: 8, minute: 0 },
      lunch: { enabled: lunch, hour: 13, minute: 0 },
      dinner: { enabled: dinner, hour: 19, minute: 0 },
    },
  };
}

// ---------------------------------------------------------------------
// Old-format preferences (no per-meal `enabled` key at all).
// ---------------------------------------------------------------------
check("old-format, top-level enabled=true => all three meal times included", () => {
  const user = {
    mealLoggingReminderPrefs: {
      enabled: true,
      breakfast: { hour: 8, minute: 0 },
      lunch: { hour: 13, minute: 0 },
      dinner: { hour: 19, minute: 0 },
    },
  };
  assert.deepStrictEqual(
    getEnabledMealMinutes(user).sort((a, b) => a - b),
    [8 * 60, 13 * 60, 19 * 60].sort((a, b) => a - b)
  );
});

check("old-format, top-level enabled=false => no meal times (preserves prior behavior)", () => {
  const user = {
    mealLoggingReminderPrefs: {
      enabled: false,
      breakfast: { hour: 8, minute: 0 },
      lunch: { hour: 13, minute: 0 },
      dinner: { hour: 19, minute: 0 },
    },
  };
  assert.deepStrictEqual(getEnabledMealMinutes(user), []);
});

// ---------------------------------------------------------------------
// New-format preferences, per-meal combinations.
// ---------------------------------------------------------------------
check("new-format: Breakfast ON / Lunch OFF / Dinner OFF => only breakfast's minute included", () => {
  const user = newFormatUser({ breakfast: true, lunch: false, dinner: false });
  assert.deepStrictEqual(getEnabledMealMinutes(user), [8 * 60]);
});

check("new-format: Breakfast OFF / Lunch ON / Dinner OFF => only lunch's minute included", () => {
  const user = newFormatUser({ breakfast: false, lunch: true, dinner: false });
  assert.deepStrictEqual(getEnabledMealMinutes(user), [13 * 60]);
});

check("new-format: all three ON => all three minutes included", () => {
  const user = newFormatUser({ breakfast: true, lunch: true, dinner: true });
  assert.deepStrictEqual(
    getEnabledMealMinutes(user).sort((a, b) => a - b),
    [8 * 60, 13 * 60, 19 * 60]
  );
});

check("new-format: no meal reminders enabled (master on, all three off) => empty list", () => {
  const user = newFormatUser({ master: true, breakfast: false, lunch: false, dinner: false });
  assert.deepStrictEqual(getEnabledMealMinutes(user), []);
});

check("new-format: master off => empty list regardless of per-meal flags (master still gates everything)", () => {
  const user = newFormatUser({ master: false, breakfast: true, lunch: true, dinner: true });
  assert.deepStrictEqual(getEnabledMealMinutes(user), []);
});

check("no mealLoggingReminderPrefs at all => empty list, no crash", () => {
  assert.deepStrictEqual(getEnabledMealMinutes({}), []);
  assert.deepStrictEqual(getEnabledMealMinutes(null), []);
});

// ---------------------------------------------------------------------
// The exact backward-compatibility requirement: explicit per-meal false
// must override a stale top-level true.
// ---------------------------------------------------------------------
check("explicit per-meal enabled=false overrides a stale top-level enabled=true", () => {
  const user = {
    mealLoggingReminderPrefs: {
      enabled: true, // stale legacy flag
      breakfast: { enabled: false, hour: 8, minute: 0 }, // explicitly off
      lunch: { hour: 13, minute: 0 }, // no per-meal key -> inherits top-level (on)
      dinner: { enabled: true, hour: 19, minute: 0 }, // explicitly on
    },
  };
  assert.deepStrictEqual(
    getEnabledMealMinutes(user).sort((a, b) => a - b),
    [13 * 60, 19 * 60].sort((a, b) => a - b)
  );
});

check("isPersonalizedMealReminderEnabled agrees with getEnabledMealMinutes for the same doc", () => {
  const prefs = {
    enabled: true,
    breakfast: { enabled: false, hour: 8, minute: 0 },
    lunch: { hour: 13, minute: 0 },
    dinner: { enabled: true, hour: 19, minute: 0 },
  };
  assert.strictEqual(isMealRemindersMasterEnabled(prefs), true);
  assert.strictEqual(mealReminderOwnEnabled(prefs, "breakfast"), false);
  assert.strictEqual(mealReminderOwnEnabled(prefs, "lunch"), true); // inherited
  assert.strictEqual(isPersonalizedMealReminderEnabled(prefs, "breakfast"), false);
  assert.strictEqual(isPersonalizedMealReminderEnabled(prefs, "lunch"), true);
  assert.strictEqual(isPersonalizedMealReminderEnabled(prefs, "dinner"), true);
});

// ---------------------------------------------------------------------
// Preserve existing collision-avoidance behavior: getEnabledMealMinutes'
// output still feeds isWithinMealCollisionWindow exactly as before -- this
// fix only changes WHICH minutes are included, not how they're used.
// ---------------------------------------------------------------------
check("collision avoidance still works end-to-end with the corrected minute list", () => {
  const user = newFormatUser({ breakfast: false, lunch: true, dinner: false }); // lunch at 13:00
  const minutes = getEnabledMealMinutes(user);
  assert.strictEqual(isWithinMealCollisionWindow(13 * 60 + 10, minutes), true, "10 min after lunch is within the 45-min buffer");
  assert.strictEqual(isWithinMealCollisionWindow(9 * 60, minutes), false, "9am has no enabled meal nearby (breakfast is off)");
});

check("a meal that is off contributes no collision window even if it has a saved time", () => {
  // Breakfast has a saved 8:00 time but is OFF -- must not create a
  // collision window around 8:00.
  const user = newFormatUser({ breakfast: false, lunch: false, dinner: false });
  const minutes = getEnabledMealMinutes(user);
  assert.strictEqual(isWithinMealCollisionWindow(8 * 60, minutes), false);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
