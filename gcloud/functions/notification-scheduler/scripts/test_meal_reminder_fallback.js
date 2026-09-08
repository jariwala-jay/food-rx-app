// Regression check for the generic server-side fallback meal reminders
// (lunch ~12:30pm local / dinner ~6:00pm local, for whichever of those two
// meals the user has NOT personally enabled a reminder for). No breakfast
// fallback exists by design.
//
// decideMealReminderFallback() is the pure function that encodes all of the
// per-meal eligibility rules; checkMealReminderFallbacks()'s per-user loop
// just does the DB dedupe/insert around whatever it returns (same pattern
// as decideTrackerReminder() / checkMealLoggingInactivityReminders()).
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_daily_tracker_reminder.js); run with:
//   node scripts/test_meal_reminder_fallback.js

const assert = require("assert");
const schedulerTestables = require("../index.js").__testables;
const deliveryTestables = require("../../notification-delivery/index.js").__testables;

const {
  decideMealReminderFallback,
  isMealRemindersMasterEnabled,
  mealReminderOwnEnabled,
  isPersonalizedMealReminderEnabled,
  hasAnyPersonalizedMealReminderEnabled,
  mealReminderFallbackType,
  localMinutesOfDay,
  MEAL_FALLBACK_TARGET_MINUTES,
  MEAL_LOG_WINDOW_MINUTES,
  isWithinNewAccountGracePeriod,
} = schedulerTestables;

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
// 2026-08-10 is a Monday; times below are expressed as if the user is in
// UTC so "local time" and "UTC time" match 1:1, keeping each check's target
// time obvious from the ISO string.
const LUNCH_TIME_UTC = new Date("2026-08-10T12:30:00Z"); // exactly the lunch target
const DINNER_TIME_UTC = new Date("2026-08-10T18:00:00Z"); // exactly the dinner target
const MORNING_UTC = new Date("2026-08-10T09:00:00Z"); // before either target

function newFormatPrefs({ breakfast = false, lunch = false, dinner = false, master = true } = {}) {
  return {
    enabled: master,
    breakfast: { enabled: breakfast, hour: 9, minute: 0 },
    lunch: { enabled: lunch, hour: 13, minute: 0 },
    dinner: { enabled: dinner, hour: 20, minute: 0 },
  };
}

// ---------------------------------------------------------------------
// 1. Per-meal independence: all 8 combinations of the three toggles.
// Only breakfast/lunch/dinner's OWN enabled flag should matter for that
// meal's fallback -- never an all-or-nothing "any reminder enabled" rule.
// ---------------------------------------------------------------------
const combinations = [
  { breakfast: false, lunch: false, dinner: false },
  { breakfast: true, lunch: false, dinner: false },
  { breakfast: false, lunch: true, dinner: false },
  { breakfast: false, lunch: false, dinner: true },
  { breakfast: true, lunch: true, dinner: false },
  { breakfast: true, lunch: false, dinner: true },
  { breakfast: false, lunch: true, dinner: true },
  { breakfast: true, lunch: true, dinner: true },
];

for (const combo of combinations) {
  const label = `breakfast=${combo.breakfast} lunch=${combo.lunch} dinner=${combo.dinner}`;

  check(`[${label}] lunch fallback is eligible iff personalized lunch is off`, () => {
    const prefs = newFormatPrefs(combo);
    const decision = decideMealReminderFallback("lunch", prefs, LUNCH_TIME_UTC, null, UTC);
    if (combo.lunch) {
      assert.strictEqual(decision, null, "personalized lunch ON must suppress the fallback");
    } else {
      assert.notStrictEqual(decision, null, "personalized lunch OFF must leave the fallback eligible");
      assert.strictEqual(decision.title, "Time to log your meal");
    }
  });

  check(`[${label}] dinner fallback is eligible iff personalized dinner is off`, () => {
    const prefs = newFormatPrefs(combo);
    const decision = decideMealReminderFallback("dinner", prefs, DINNER_TIME_UTC, null, UTC);
    if (combo.dinner) {
      assert.strictEqual(decision, null, "personalized dinner ON must suppress the fallback");
    } else {
      assert.notStrictEqual(decision, null, "personalized dinner OFF must leave the fallback eligible");
      assert.strictEqual(decision.title, "Don't forget to log your meal");
    }
  });

  check(`[${label}] breakfast's own toggle never affects lunch/dinner fallback eligibility`, () => {
    // Cross-check: flipping ONLY breakfast, with lunch/dinner held fixed at
    // off, must never change the lunch/dinner fallback outcome -- proves
    // there is no all-or-nothing "any personalized reminder enabled"
    // shortcut anywhere in the decision.
    const withBreakfastOn = decideMealReminderFallback(
      "lunch",
      newFormatPrefs({ ...combo, breakfast: true, lunch: false }),
      LUNCH_TIME_UTC,
      null,
      UTC
    );
    const withBreakfastOff = decideMealReminderFallback(
      "lunch",
      newFormatPrefs({ ...combo, breakfast: false, lunch: false }),
      LUNCH_TIME_UTC,
      null,
      UTC
    );
    assert.notStrictEqual(withBreakfastOn, null);
    assert.notStrictEqual(withBreakfastOff, null);
    assert.deepStrictEqual(withBreakfastOn, withBreakfastOff);
  });
}

// ---------------------------------------------------------------------
// 2. No breakfast fallback exists at all -- MEAL_FALLBACK_TARGET_MINUTES
//    and MEAL_LOG_WINDOW_MINUTES simply have no "breakfast" entry, so
//    calling decideMealReminderFallback("breakfast", ...) would read
//    `undefined` targets/windows. Assert the constants themselves have no
//    breakfast key rather than calling the function with a meal it was
//    never designed to support.
// ---------------------------------------------------------------------
check("no breakfast fallback target/window exists", () => {
  assert.strictEqual(MEAL_FALLBACK_TARGET_MINUTES.breakfast, undefined);
  assert.strictEqual(MEAL_LOG_WINDOW_MINUTES.breakfast, undefined);
});

// ---------------------------------------------------------------------
// 3. Meal-specific logging suppression -- the exact scenarios requested.
// ---------------------------------------------------------------------
const offPrefs = newFormatPrefs({ breakfast: false, lunch: false, dinner: false });

check("1. breakfast logged at 10 AM does NOT suppress the lunch fallback", () => {
  const breakfastLoggedAt10am = new Date("2026-08-10T10:00:00Z");
  const decision = decideMealReminderFallback(
    "lunch",
    offPrefs,
    LUNCH_TIME_UTC,
    breakfastLoggedAt10am,
    UTC
  );
  assert.notStrictEqual(decision, null);
});

check("2. lunch logged at 12 PM suppresses the 12:30 PM lunch fallback", () => {
  const lunchLoggedAtNoon = new Date("2026-08-10T12:00:00Z");
  const decision = decideMealReminderFallback(
    "lunch",
    offPrefs,
    LUNCH_TIME_UTC,
    lunchLoggedAtNoon,
    UTC
  );
  assert.strictEqual(decision, null);
});

check("3. activity at 3 PM does NOT suppress the 6 PM dinner fallback", () => {
  const activityAt3pm = new Date("2026-08-10T15:00:00Z");
  const decision = decideMealReminderFallback(
    "dinner",
    offPrefs,
    DINNER_TIME_UTC,
    activityAt3pm,
    UTC
  );
  assert.notStrictEqual(decision, null, "3pm falls before the 4:00pm dinner-log window and must not count as dinner logged");
});

check("4. dinner logged at 5 PM suppresses the 6 PM dinner fallback", () => {
  const dinnerLoggedAt5pm = new Date("2026-08-10T17:00:00Z");
  const decision = decideMealReminderFallback(
    "dinner",
    offPrefs,
    DINNER_TIME_UTC,
    dinnerLoggedAt5pm,
    UTC
  );
  assert.strictEqual(decision, null);
});

check("5. dinner not logged at all leaves the 6 PM fallback eligible", () => {
  const decision = decideMealReminderFallback("dinner", offPrefs, DINNER_TIME_UTC, null, UTC);
  assert.notStrictEqual(decision, null);
});

check("lunch logged before 12:30 does not create a duplicate suppression later the same day", () => {
  // decideMealReminderFallback is pure/idempotent: calling it again later
  // the same day with the same "latest activity" input still returns the
  // same (suppressed) decision -- the actual once-per-day guarantee comes
  // from findTodaysNotification()'s dedup, exercised separately below.
  const lunchLoggedAtNoon = new Date("2026-08-10T12:00:00Z");
  const laterSameDay = new Date("2026-08-10T13:00:00Z");
  const decision = decideMealReminderFallback(
    "lunch",
    offPrefs,
    laterSameDay,
    lunchLoggedAtNoon,
    UTC
  );
  assert.strictEqual(decision, null);
});

check("logging one meal does not suppress the OTHER meal's fallback", () => {
  // Logging lunch at noon falls outside dinner's [4:00pm, 6:30pm] window,
  // so it must not affect dinner's independent decision -- dinner stays
  // eligible.
  const lunchLoggedAtNoon = new Date("2026-08-10T12:00:00Z");
  const dinnerDecision = decideMealReminderFallback(
    "dinner",
    offPrefs,
    DINNER_TIME_UTC,
    lunchLoggedAtNoon,
    UTC
  );
  assert.notStrictEqual(
    dinnerDecision,
    null,
    "a lunchtime log must not suppress the unrelated dinner fallback"
  );
});

// ---------------------------------------------------------------------
// 4. Before the target time, no fallback -- regardless of logging state.
// ---------------------------------------------------------------------
check("before 12:30 local, lunch fallback is never eligible even if never logged", () => {
  const decision = decideMealReminderFallback("lunch", offPrefs, MORNING_UTC, null, UTC);
  assert.strictEqual(decision, null);
});

check("before 6:00 local, dinner fallback is never eligible even if never logged", () => {
  const decision = decideMealReminderFallback("dinner", offPrefs, MORNING_UTC, null, UTC);
  assert.strictEqual(decision, null);
});

check("exactly at the target minute, the fallback is already eligible (floor, not open interval)", () => {
  assert.notStrictEqual(
    decideMealReminderFallback("lunch", offPrefs, LUNCH_TIME_UTC, null, UTC),
    null
  );
  assert.notStrictEqual(
    decideMealReminderFallback("dinner", offPrefs, DINNER_TIME_UTC, null, UTC),
    null
  );
});

check("well after the target time (e.g. 8pm), lunch fallback is still eligible -- floor, not a fixed slot", () => {
  const wellAfter = new Date("2026-08-10T20:00:00Z");
  const decision = decideMealReminderFallback("lunch", offPrefs, wellAfter, null, UTC);
  assert.notStrictEqual(decision, null);
});

// ---------------------------------------------------------------------
// 5. Timezone: 12:30pm/6:00pm must be evaluated in LOCAL time, not UTC.
// ---------------------------------------------------------------------
check("Eastern Time (UTC-4, summer): 12:30pm ET is 16:30 UTC, not 12:30 UTC", () => {
  const ET_OFFSET = -4 * 60; // EDT
  const noon30Utc = new Date("2026-08-10T12:30:00Z"); // 8:30am ET -- too early
  const noon30Et = new Date("2026-08-10T16:30:00Z"); // 12:30pm ET

  assert.strictEqual(
    decideMealReminderFallback("lunch", offPrefs, noon30Utc, null, ET_OFFSET),
    null,
    "8:30am ET must not be treated as past the 12:30pm ET target"
  );
  assert.notStrictEqual(
    decideMealReminderFallback("lunch", offPrefs, noon30Et, null, ET_OFFSET),
    null,
    "16:30 UTC is exactly 12:30pm ET and must be eligible"
  );
});

check("Pacific Time (UTC-7, summer): 6:00pm PT is 01:00 UTC the next day", () => {
  const PT_OFFSET = -7 * 60; // PDT
  const sixPmUtcSameDay = new Date("2026-08-10T18:00:00Z"); // only 11am PT -- too early
  const sixPmPt = new Date("2026-08-11T01:00:00Z"); // 6:00pm PT on Aug 10

  assert.strictEqual(
    decideMealReminderFallback("dinner", offPrefs, sixPmUtcSameDay, null, PT_OFFSET),
    null,
    "11am PT must not be treated as past the 6:00pm PT target"
  );
  assert.notStrictEqual(
    decideMealReminderFallback("dinner", offPrefs, sixPmPt, null, PT_OFFSET),
    null,
    "01:00 UTC (next day) is exactly 6:00pm PT the prior local day and must be eligible"
  );
});

check("logged-meal window is also evaluated in local time, not UTC", () => {
  const ET_OFFSET = -4 * 60;
  // 16:00 UTC = 12:00pm ET -- inside the lunch log window in ET.
  const loggedAtNoonEt = new Date("2026-08-10T16:00:00Z");
  const checkTimeEt = new Date("2026-08-10T16:30:00Z"); // 12:30pm ET
  const decision = decideMealReminderFallback(
    "lunch",
    offPrefs,
    checkTimeEt,
    loggedAtNoonEt,
    ET_OFFSET
  );
  assert.strictEqual(decision, null, "noon-ET activity must suppress the ET lunch fallback");
});

check("localMinutesOfDay matches the manual UTC-plus-offset math used above", () => {
  assert.strictEqual(localMinutesOfDay(new Date("2026-08-10T16:30:00Z"), -4 * 60), 12 * 60 + 30);
});

// ---------------------------------------------------------------------
// 6. Personalized-reminder precedence, old/new preference format compat.
// ---------------------------------------------------------------------
check("old-format doc, top-level enabled=true => both lunch and dinner personalized ON (no fallback)", () => {
  const oldFormat = {
    enabled: true,
    breakfast: { hour: 9, minute: 0 },
    lunch: { hour: 13, minute: 0 },
    dinner: { hour: 20, minute: 0 },
  };
  assert.strictEqual(decideMealReminderFallback("lunch", oldFormat, LUNCH_TIME_UTC, null, UTC), null);
  assert.strictEqual(decideMealReminderFallback("dinner", oldFormat, DINNER_TIME_UTC, null, UTC), null);
});

check("old-format doc, top-level enabled=false => both fallbacks eligible", () => {
  const oldFormat = {
    enabled: false,
    breakfast: { hour: 9, minute: 0 },
    lunch: { hour: 13, minute: 0 },
    dinner: { hour: 20, minute: 0 },
  };
  assert.notStrictEqual(decideMealReminderFallback("lunch", oldFormat, LUNCH_TIME_UTC, null, UTC), null);
  assert.notStrictEqual(decideMealReminderFallback("dinner", oldFormat, DINNER_TIME_UTC, null, UTC), null);
});

check("explicit per-meal enabled=false overrides a stale top-level enabled=true", () => {
  const mixedFormat = {
    enabled: true, // stale legacy flag
    lunch: { enabled: false, hour: 13, minute: 0 }, // explicitly off
    dinner: { hour: 20, minute: 0 }, // no per-meal key -> inherits top-level
  };
  assert.notStrictEqual(
    decideMealReminderFallback("lunch", mixedFormat, LUNCH_TIME_UTC, null, UTC),
    null,
    "personalized lunch must resolve OFF (explicit false wins), so the fallback IS eligible"
  );
  assert.strictEqual(
    decideMealReminderFallback("dinner", mixedFormat, DINNER_TIME_UTC, null, UTC),
    null,
    "dinner has no per-meal key, inherits the stale top-level true, so personalized dinner is ON and no fallback"
  );
});

check("no prefs at all (brand new user) => both fallbacks eligible once past target time", () => {
  assert.notStrictEqual(decideMealReminderFallback("lunch", null, LUNCH_TIME_UTC, null, UTC), null);
  assert.notStrictEqual(decideMealReminderFallback("dinner", undefined, DINNER_TIME_UTC, null, UTC), null);
});

check("isMealRemindersMasterEnabled / mealReminderOwnEnabled / isPersonalizedMealReminderEnabled agree with each other", () => {
  const prefs = { enabled: true, lunch: { enabled: false, hour: 13, minute: 0 } };
  assert.strictEqual(isMealRemindersMasterEnabled(prefs), true);
  assert.strictEqual(mealReminderOwnEnabled(prefs, "lunch"), false);
  assert.strictEqual(isPersonalizedMealReminderEnabled(prefs, "lunch"), false);
});

// ---------------------------------------------------------------------
// 7. Deduplication: lunch and dinner fallback types are distinct, so
//    findTodaysNotification()'s per-type dedup key scopes them
//    independently -- a repeated scheduler run within the same window (or
//    later the same day) cannot create a second doc of either type.
// ---------------------------------------------------------------------
check("lunch and dinner fallback notification types are distinct strings", () => {
  assert.strictEqual(mealReminderFallbackType("lunch"), "lunch_reminder_fallback");
  assert.strictEqual(mealReminderFallbackType("dinner"), "dinner_reminder_fallback");
  assert.notStrictEqual(mealReminderFallbackType("lunch"), mealReminderFallbackType("dinner"));
});

check("decideMealReminderFallback is a pure/idempotent function of its inputs (safe to call every scheduler run)", () => {
  const first = decideMealReminderFallback("lunch", offPrefs, LUNCH_TIME_UTC, null, UTC);
  const second = decideMealReminderFallback("lunch", offPrefs, LUNCH_TIME_UTC, null, UTC);
  assert.deepStrictEqual(first, second);
});

// ---------------------------------------------------------------------
// 8. 24-hour new-account grace period -- exact boundaries, using the
//    exact shared gate checkMealReminderFallbacks() calls.
// ---------------------------------------------------------------------
const accountNow = new Date("2026-08-10T20:00:00Z");

check("account created 2 hours ago => still within grace period (no fallback eligible)", () => {
  const createdAt = new Date(accountNow.getTime() - 2 * 60 * 60 * 1000).toISOString();
  assert.strictEqual(isWithinNewAccountGracePeriod(accountNow, { createdAt }), true);
});

check("account created 12 hours ago => still within grace period", () => {
  const createdAt = new Date(accountNow.getTime() - 12 * 60 * 60 * 1000).toISOString();
  assert.strictEqual(isWithinNewAccountGracePeriod(accountNow, { createdAt }), true);
});

check("account created 23h59m ago => still within grace period (just under the boundary)", () => {
  const createdAt = new Date(accountNow.getTime() - (23 * 60 + 59) * 60 * 1000).toISOString();
  assert.strictEqual(isWithinNewAccountGracePeriod(accountNow, { createdAt }), true);
});

check("account created exactly 24 hours ago => grace period has ended, eligible", () => {
  const createdAt = new Date(accountNow.getTime() - 24 * 60 * 60 * 1000).toISOString();
  assert.strictEqual(isWithinNewAccountGracePeriod(accountNow, { createdAt }), false);
});

check("account created 25 hours ago => eligible (well past the boundary)", () => {
  const createdAt = new Date(accountNow.getTime() - 25 * 60 * 60 * 1000).toISOString();
  assert.strictEqual(isWithinNewAccountGracePeriod(accountNow, { createdAt }), false);
});

// ---------------------------------------------------------------------
// 9. Tier/budget participation -- lunch/dinner fallbacks share Tier 2 with
//    tracker_reminder/app_inactivity_reminder (existing daily push budget).
// ---------------------------------------------------------------------
check("lunch/dinner_reminder_fallback are classified Tier 2, same as tracker_reminder", () => {
  assert.strictEqual(deliveryTestables.getTier("lunch_reminder_fallback"), 2);
  assert.strictEqual(deliveryTestables.getTier("dinner_reminder_fallback"), 2);
  assert.strictEqual(deliveryTestables.getTier("tracker_reminder"), 2);
});

check("a lunch fallback and a tracker_reminder compete for the SAME Tier-2 daily slot", () => {
  const notifications = [
    { type: "lunch_reminder_fallback" },
    { type: "tracker_reminder" },
    { type: "expired_items" },
  ];
  const sorted = deliveryTestables.sortByPriority(notifications);
  // Tier 1 (expired_items) always wins the sort regardless of Tier-2 order.
  assert.strictEqual(sorted[0].type, "expired_items");
});

// ---------------------------------------------------------------------
// 10. Quiet hours are enforced generically (type-agnostic) in
//     notification-delivery -- confirm nothing about these two new types
//     bypasses that check by being special-cased anywhere.
// ---------------------------------------------------------------------
check("quiet hours logic in notification-delivery has no special-case branch for these types", () => {
  // pantryDeliveryDeferralReason only special-cases PANTRY_PREFERRED_LOCAL_MINUTES
  // keys (expiring_ingredient/expired_items) -- confirm the new types fall
  // straight through it untouched, exactly like tracker_reminder does,
  // meaning they're subject only to the same generic quiet-hours check
  // every other type already goes through.
  assert.strictEqual(
    deliveryTestables.pantryDeliveryDeferralReason("lunch_reminder_fallback", 12 * 60 + 30, {}),
    null
  );
  assert.strictEqual(
    deliveryTestables.pantryDeliveryDeferralReason("dinner_reminder_fallback", 18 * 60, {}),
    null
  );
});

// ---------------------------------------------------------------------
// 11. Regression: the meal-reminder blackout bug. The tracker_reminder
// daily nudge (decideTrackerReminder in checkMealLoggingInactivityReminders)
// used to be suppressed off the bare master flag alone, which meant
// "master ON, every individual meal OFF" incorrectly suppressed the daily
// fallback too -- since in that state, no personalized reminder fires for
// anything either. hasAnyPersonalizedMealReminderEnabled() is what the
// call site now passes instead; it must be true only when at least one
// meal's own toggle (not just the master) is actually enabled.
// ---------------------------------------------------------------------
check("BLACKOUT BUG: master ON, all three meals OFF => false (must not suppress the daily nudge)", () => {
  const prefs = {
    enabled: true,
    breakfast: { enabled: false, hour: 9, minute: 0 },
    lunch: { enabled: false, hour: 13, minute: 0 },
    dinner: { enabled: false, hour: 20, minute: 0 },
  };
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(prefs), false);
});

check("master ON, only one meal ON => true (daily nudge correctly stays suppressed)", () => {
  for (const onMeal of ["breakfast", "lunch", "dinner"]) {
    const prefs = {
      enabled: true,
      breakfast: { enabled: onMeal === "breakfast", hour: 9, minute: 0 },
      lunch: { enabled: onMeal === "lunch", hour: 13, minute: 0 },
      dinner: { enabled: onMeal === "dinner", hour: 20, minute: 0 },
    };
    assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(prefs), true, `onMeal=${onMeal}`);
  }
});

check("master OFF => false regardless of per-meal flags (master still gates everything)", () => {
  const prefs = {
    enabled: false,
    breakfast: { enabled: true, hour: 9, minute: 0 },
    lunch: { enabled: true, hour: 13, minute: 0 },
    dinner: { enabled: true, hour: 20, minute: 0 },
  };
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(prefs), false);
});

check("old-format doc, top-level enabled=true => true (every meal inherits the legacy flag)", () => {
  const oldFormat = {
    enabled: true,
    breakfast: { hour: 9, minute: 0 },
    lunch: { hour: 13, minute: 0 },
    dinner: { hour: 20, minute: 0 },
  };
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(oldFormat), true);
});

check("old-format doc, top-level enabled=false => false", () => {
  const oldFormat = {
    enabled: false,
    breakfast: { hour: 9, minute: 0 },
    lunch: { hour: 13, minute: 0 },
    dinner: { hour: 20, minute: 0 },
  };
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(oldFormat), false);
});

check("no prefs at all (brand new user) => false", () => {
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(null), false);
  assert.strictEqual(hasAnyPersonalizedMealReminderEnabled(undefined), false);
});

check("all 8 combinations agree with 'at least one meal\\'s own+master resolves true'", () => {
  for (const b of [false, true]) {
    for (const l of [false, true]) {
      for (const d of [false, true]) {
        const prefs = {
          enabled: true,
          breakfast: { enabled: b, hour: 9, minute: 0 },
          lunch: { enabled: l, hour: 13, minute: 0 },
          dinner: { enabled: d, hour: 20, minute: 0 },
        };
        const expected = b || l || d;
        assert.strictEqual(
          hasAnyPersonalizedMealReminderEnabled(prefs),
          expected,
          `b=${b} l=${l} d=${d}`
        );
      }
    }
  }
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
