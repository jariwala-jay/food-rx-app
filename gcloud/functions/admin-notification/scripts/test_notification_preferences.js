// Regression check for the per-recipient notification-preference gate in
// the manual admin-broadcast tool: a recipient who disabled the relevant
// Notification Settings toggle must not get a notification document created
// for them, even though this Cloud Function is invoked directly by an admin
// operator rather than through any of the automated trigger paths.
//
// No test framework dependency by design (matches
// notification-scheduler/scripts/test_inactivity_bucket.js); run with:
//   node scripts/test_notification_preferences.js

const assert = require("assert");
const { ObjectId } = require("mongodb");
const {
  isNotificationTypeEnabled,
  NOTIFICATION_TYPE_TO_PREF_KEY,
  parseObjectId,
  fetchPreferencesById,
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

async function checkAsync(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`ok - ${name}`);
  } catch (err) {
    console.error(`FAIL - ${name}`);
    console.error(`       ${err.message}`);
    process.exitCode = 1;
  }
}

check("adminUpdates:false disables the default 'admin' broadcast type", () => {
  const user = { notificationTypePrefs: { adminUpdates: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "admin"), false);
});

check("education:false disables an explicit type:'education' broadcast", () => {
  const user = { notificationTypePrefs: { education: false } };
  assert.strictEqual(isNotificationTypeEnabled(user, "education"), false);
});

check("recipient lookup failure (null user) defaults to enabled, not silently dropped", () => {
  // Mirrors index.js's behavior when an invalid/unresolvable uid is passed:
  // the recipient lookup returns null and the broadcast still goes out,
  // rather than a lookup error silently suppressing a legitimate send.
  assert.strictEqual(isNotificationTypeEnabled(null, "admin"), true);
});

check("no prefs set => enabled (existing accounts unaffected)", () => {
  assert.strictEqual(isNotificationTypeEnabled({}, "admin"), true);
});

check("mapping matches the notification-delivery copy exactly (no drift)", () => {
  const deliveryMap =
    require("../../notification-delivery/index.js").__testables.NOTIFICATION_TYPE_TO_PREF_KEY;
  assert.deepStrictEqual(NOTIFICATION_TYPE_TO_PREF_KEY, deliveryMap);
});

check("parseObjectId returns an ObjectId for a valid hex id", () => {
  const id = new ObjectId();
  const parsed = parseObjectId(id.toHexString());
  assert.ok(parsed instanceof ObjectId);
  assert.strictEqual(parsed.toHexString(), id.toHexString());
});

check("parseObjectId returns null for a malformed id instead of throwing", () => {
  assert.strictEqual(parseObjectId("not-a-valid-object-id"), null);
});

async function main() {
  await checkAsync("fetchPreferencesById returns an empty map for no ids", async () => {
    const map = await fetchPreferencesById({ find: () => { throw new Error("should not be called"); } }, []);
    assert.strictEqual(map.size, 0);
  });

  await checkAsync("fetchPreferencesById batches into one find() call, keyed by hex id", async () => {
    const id1 = new ObjectId();
    const id2 = new ObjectId();
    let findCalls = 0;
    const fakeCollection = {
      find(query, options) {
        findCalls++;
        assert.deepStrictEqual(query, { _id: { $in: [id1, id2] } });
        assert.deepStrictEqual(options, {
          projection: { notificationTypePrefs: 1 },
        });
        return {
          toArray: async () => [
            { _id: id1, notificationTypePrefs: { adminUpdates: false } },
          ],
        };
      },
    };

    const map = await fetchPreferencesById(fakeCollection, [id1, id2]);
    assert.strictEqual(findCalls, 1);
    assert.strictEqual(map.size, 1);
    assert.deepStrictEqual(map.get(id1.toHexString()).notificationTypePrefs, {
      adminUpdates: false,
    });
    assert.strictEqual(map.get(id2.toHexString()), undefined);
  });

  await checkAsync(
    "fetchPreferencesById propagates a real query failure instead of swallowing it",
    async () => {
      const fakeCollection = {
        find() {
          return {
            toArray: async () => {
              throw new Error("connection reset");
            },
          };
        },
      };

      await assert.rejects(
        () => fetchPreferencesById(fakeCollection, [new ObjectId()]),
        /connection reset/
      );
    }
  );

  console.log(`\n${passed} check(s) passed.`);
  if (process.exitCode) {
    console.error("Some checks FAILED.");
  } else {
    console.log("All checks passed.");
  }
}

main();
