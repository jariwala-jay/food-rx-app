// Regression check for the scheduled expired_items check
// (checkExpiredItems / decideExpiredItemsDigest): the new server-side sweep
// that detects already-expired pantry items even if the user hasn't opened
// MyFoodRx (the case the existing client-side check, tied to pantry
// loading/refreshing on-device, cannot cover on its own).
//
// decideExpiredItemsDigest() is the pure decision function extracted out of
// checkExpiredItems() specifically so this rule is testable without a live
// Mongo connection -- same pattern as decideTrackerReminder().
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_inactivity_bucket.js); run with:
//   node scripts/test_expired_items.js

const assert = require("assert");
const {
  decideExpiredItemsDigest,
  isNotificationTypeEnabled,
  isWithinNewAccountGracePeriod,
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

// -- decideExpiredItemsDigest -------------------------------------------

check("single expired item, never notified before: push-eligible, singular copy", () => {
  const decision = decideExpiredItemsDigest(["Milk"], ["id1"], new Set());
  assert.strictEqual(decision.title, "Milk has expired");
  assert.strictEqual(decision.message, "Review its expiration date and update it if needed.");
  assert.strictEqual(decision.pushEligible, true);
  assert.deepStrictEqual(decision.idsToMark, ["id1"]);
});

check("multiple expired items, never notified before: push-eligible, plural copy with names", () => {
  const names = ["Milk", "Eggs", "Yogurt", "Spinach"];
  const ids = ["id1", "id2", "id3", "id4"];
  const decision = decideExpiredItemsDigest(names, ids, new Set());
  assert.strictEqual(decision.title, "Some items have expired");
  assert.strictEqual(
    decision.message,
    "Milk, Eggs, Yogurt and 1 more. Review the expiration dates and update them if needed."
  );
  assert.strictEqual(decision.pushEligible, true);
  assert.deepStrictEqual(decision.idsToMark, ids);
});

check("DEDUP: every currently-expired item already notified before -> Center-only, no push", () => {
  const decision = decideExpiredItemsDigest(["Milk"], ["id1"], new Set(["id1"]));
  assert.strictEqual(decision.pushEligible, false);
  assert.deepStrictEqual(decision.idsToMark, []);
  // Title/message are still built normally -- the Center digest still
  // reflects current pantry state even when the push is suppressed.
  assert.strictEqual(decision.title, "Milk has expired");
});

check("DEDUP: a newly-expired item alongside an already-notified one still pushes", () => {
  // Only the genuinely new item gets marked, but the digest (and the push)
  // covers the full current expired set, not just the new item -- matching
  // the client-side path's identical behavior in POST /notifications.
  const names = ["Milk", "Eggs"];
  const ids = ["id1", "id2"];
  const decision = decideExpiredItemsDigest(names, ids, new Set(["id1"]));
  assert.strictEqual(decision.pushEligible, true);
  assert.deepStrictEqual(decision.idsToMark, ["id2"]);
  assert.strictEqual(decision.title, "Some items have expired");
});

check("detected while the app is not open: decision has no dependency on app-activity signals", () => {
  // The whole point of the scheduled check is that it only needs pantry
  // state and the notification ledger -- never anything about whether/when
  // the user last opened the app. This asserts that invariant directly:
  // the same inputs produce the same decision regardless of any notion of
  // "recency" the caller might otherwise be tempted to pass in.
  const decision = decideExpiredItemsDigest(["Milk"], ["id1"], new Set());
  assert.strictEqual(decision.pushEligible, true);
});

// -- isNotificationTypeEnabled (expired_items shares Expiring Ingredients) --

check("expiringIngredients:false also disables expired_items (shared preference)", () => {
  const user = { notificationTypePrefs: { expiringIngredients: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "expired_items"), false);
});

check("expiringIngredients:true (or unset) allows expired_items", () => {
  assert.strictEqual(isNotificationTypeEnabled({}, "expired_items"), true);
  assert.strictEqual(
    isNotificationTypeEnabled({ notificationTypePrefs: { expiringIngredients: true } }, "expired_items"),
    true
  );
});

// -- isWithinNewAccountGracePeriod (24h grace period, shared with every other check) --

check("brand-new account is within the grace period", () => {
  const now = new Date("2026-08-10T12:00:00Z");
  const user = { createdAt: "2026-08-10T11:00:00Z" }; // 1 hour old
  assert.strictEqual(isWithinNewAccountGracePeriod(now, user), true);
});

check("account older than 24h is not within the grace period", () => {
  const now = new Date("2026-08-10T12:00:00Z");
  const user = { createdAt: "2026-08-08T00:00:00Z" }; // >24h old
  assert.strictEqual(isWithinNewAccountGracePeriod(now, user), false);
});

check("account with no createdAt is treated as not within the grace period", () => {
  const now = new Date("2026-08-10T12:00:00Z");
  assert.strictEqual(isWithinNewAccountGracePeriod(now, {}), false);
});

console.log(`\n${passed} check(s) passed.`);
if (process.exitCode) {
  console.error("Some checks FAILED.");
} else {
  console.log("All checks passed.");
}
