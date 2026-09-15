// Regression check: a notification that loses the Tier-2 daily budget gets
// stamped with `deliverySkippedAt` and dropped for good via
// pendingNotificationsQuery(), instead of sitting unset and eventually
// going out on a later day.
//
// No test framework dependency by design (matches
// notification-delivery/scripts/test_meal_collision_prefs.js); run with:
//   node scripts/test_tier_budget_suppression.js

const assert = require("assert");
const {
  pendingNotificationsQuery,
  DELIVERY_SKIP_REASON_TIER_BUDGET_EXHAUSTED,
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

// A tiny in-memory stand-in for Mongo's query matching, just for the
// $exists checks pendingNotificationsQuery() actually uses -- enough to
// prove the query shape behaves as intended without a live database.
function matchesExistsQuery(doc, query) {
  return Object.entries(query).every(([field, cond]) => {
    const present = Object.prototype.hasOwnProperty.call(doc, field);
    return cond.$exists ? present : !present;
  });
}

check("pendingNotificationsQuery requires both sentAt and deliverySkippedAt to be absent", () => {
  const query = pendingNotificationsQuery();
  assert.deepStrictEqual(query, {
    sentAt: { $exists: false },
    deliverySkippedAt: { $exists: false },
  });
});

check("a freshly created, never-touched notification is still pending", () => {
  const doc = { type: "dinner_reminder_fallback", createdAt: new Date() };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), true);
});

check("a notification with sentAt set is no longer pending", () => {
  const doc = { type: "lunch_reminder_fallback", createdAt: new Date(), sentAt: new Date() };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

check("a notification skipped for tier-budget exhaustion is no longer pending (does not carry to the next day)", () => {
  const doc = {
    type: "dinner_reminder_fallback",
    createdAt: new Date(),
    deliverySkippedAt: new Date(),
    deliverySkippedReason: DELIVERY_SKIP_REASON_TIER_BUDGET_EXHAUSTED,
  };
  assert.strictEqual(matchesExistsQuery(doc, pendingNotificationsQuery()), false);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
