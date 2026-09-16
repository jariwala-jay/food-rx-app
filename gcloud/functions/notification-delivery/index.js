// Google Cloud Function for Notification Delivery
// Simplified version - just sends FCM notifications

const { MongoClient, ObjectId } = require("mongodb");
const admin = require("firebase-admin");

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";

let client;
let firebaseApp;

async function initializeFirebase() {
  if (firebaseApp) return;

  try {
    // Prefer explicit service account if provided (via env/secret),
    // fallback to application default credentials.
    const saBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
    const projectIdOverride = process.env.FIREBASE_PROJECT_ID;
    if (saBase64) {
      const saJson = JSON.parse(
        Buffer.from(saBase64, "base64").toString("utf8")
      );
      const options = { credential: admin.credential.cert(saJson) };
      if (projectIdOverride) options.projectId = projectIdOverride;
      firebaseApp = admin.initializeApp(options);
      console.log("Firebase Admin initialized with explicit service account");
    } else {
      const options = { credential: admin.credential.applicationDefault() };
      if (projectIdOverride) options.projectId = projectIdOverride;
      firebaseApp = admin.initializeApp(options);
      console.log(
        "Firebase Admin initialized with application default credentials"
      );
    }
    console.log("Firebase Admin SDK initialized");
  } catch (error) {
    console.error("Error initializing Firebase Admin SDK:", error);
    throw error;
  }
}

async function connectToMongo() {
  if (!MONGODB_URI) {
    throw new Error("MONGODB_URI environment variable is not set");
  }

  if (client && client.topology && client.topology.isConnected()) {
    console.log("Reusing existing MongoDB connection");
    return client.db(DB_NAME);
  }

  try {
    console.log("Attempting to connect to MongoDB...");
    client = new MongoClient(MONGODB_URI, {
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000,
    });
    await client.connect();
    console.log("Successfully connected to MongoDB");
    return client.db(DB_NAME);
  } catch (error) {
    console.error("Failed to connect to MongoDB:", error);
    if (client) {
      await client.close();
      client = null;
    }
    throw new Error("Database connection failed");
  }
}

// Tier 1 (actionable/urgent) beats Tier 2 (behavioral nudge) for the daily
// push budget: at most one push per tier reaches a device per user per
// local day. `admin`/`education` broadcasts are exempt from this budget
// (they're already rate-limited by their own dedupe window and are
// typically deliberate) but are still subject to the onboarding gate,
// which is enforced upstream at notification-creation time.
const TIER1_TYPES = ["expired_items", "expiring_ingredient"];
// lunch/dinner_reminder_fallback share Tier 2 with tracker_reminder and
// app_inactivity_reminder -- all four are behavioral nudges under the same
// one-push-per-user-per-local-day budget.
const TIER2_TYPES = [
  "tracker_reminder",
  "app_inactivity_reminder",
  "lunch_reminder_fallback",
  "dinner_reminder_fallback",
];
const QUIET_HOURS_START_LOCAL = 8; // no push before 8am local
const QUIET_HOURS_END_LOCAL = 21; // no push at/after 9pm local

// Preferred (not mandatory) local delivery time-of-day for pantry pushes,
// in minutes since local midnight. Once this passes, the notification is
// eligible any time it doesn't collide with a meal reminder — it is not
// held back further while waiting for a specific sweep.
const PANTRY_PREFERRED_LOCAL_MINUTES = {
  expiring_ingredient: 9 * 60, // ~9:00 AM
  expired_items: 11 * 60, // ~11:00 AM
};

// How close (in minutes, either side) a pantry push may not land to an
// enabled meal reminder. A fixed absolute window around each meal time,
// checked against the current instant — deliberately cadence-independent,
// so behavior doesn't change depending on how often this sweep runs.
const MEAL_COLLISION_BUFFER_MINUTES = 45;

// Final delivery-time preference gate, regardless of which code path
// created the document. Mirrors notification_eligibility.NOTIFICATION_TYPE_TO_PREF_KEY
// (Python) and the equivalent map in notification-scheduler/index.js.
//
// The one-time Welcome push is sent synchronously from auth.py and never
// reaches this sweep (sentAt is stamped in that same request), so it's
// unaffected even though its type is "admin". app_inactivity_reminder has
// no per-type preference yet and is intentionally absent here.
const NOTIFICATION_TYPE_TO_PREF_KEY = {
  expiring_ingredient: "expiringIngredients",
  expired_items: "expiringIngredients",
  tracker_reminder: "trackerReminders",
  education: "education",
  admin: "adminUpdates",
};

function isNotificationTypeEnabled(user, type) {
  const prefKey = NOTIFICATION_TYPE_TO_PREF_KEY[type];
  if (!prefKey) return true;
  const prefs = user?.notificationTypePrefs || {};
  return prefs[prefKey] !== false;
}

function getTier(type) {
  if (TIER1_TYPES.includes(type)) return 1;
  if (TIER2_TYPES.includes(type)) return 2;
  return null;
}

// Stamped on `deliverySkippedAt` when a notification loses the Tier-2
// daily budget to another notification created the same local day. Unlike
// the other gates below, this one can't become true again until local
// midnight, so it's dropped for good here instead of sitting unset and
// eventually going out hours later, divorced from why it was created.
const DELIVERY_SKIP_REASON_TIER_BUDGET_EXHAUSTED = "tier_budget_exhausted";

// The referenced user document no longer exists (account deleted after the
// notification was created). Can never become deliverable.
const DELIVERY_SKIP_REASON_USER_DELETED = "user_deleted";

// User exists but has never registered (or has cleared) an FCM token.
// Terminal rather than retried -- otherwise a stale test/dev account with
// no token accumulates one undeliverable notification per sweep forever
// (see the 2026-09-16 backlog audit). The notification doc itself is left
// alone and still shows in the in-app Notification Center
// (notifications.py's list_notifications does not filter on
// deliverySkippedAt) -- only the push retry loop is affected.
const DELIVERY_SKIP_REASON_NO_FCM_TOKEN = "no_fcm_token";

// FCM confirmed the token is permanently invalid (see
// FCM_PERMANENT_TOKEN_ERROR_CODE below) -- retrying it would never succeed.
const DELIVERY_SKIP_REASON_TOKEN_INVALID = "token_invalid";

// The only FCM error code observed in 90 days of staging + prod delivery
// logs (2026-09-16 audit) -- Firebase Admin normalizes both the legacy
// "NotRegistered" response and an APNs "device token is disabled"
// rejection to this same code. It means the token is permanently invalid
// and will never succeed again, so on this specific code the token is
// cleared and the notification is terminally skipped instead of retried.
// Any other error code (rate limits, transient server errors, etc.) is
// left alone and retried on the next sweep, same as before.
const FCM_PERMANENT_TOKEN_ERROR_CODE = "messaging/registration-token-not-registered";

// Pure classification of why a notification can't be delivered right now,
// based on the user lookup alone -- separated from the DB update so it's
// unit-testable without mocking Mongo. Returns null when delivery should
// proceed to the send attempt.
function terminalSkipReasonForUser(user) {
  if (!user) return DELIVERY_SKIP_REASON_USER_DELETED;
  if (!user.fcmToken) return DELIVERY_SKIP_REASON_NO_FCM_TOKEN;
  return null;
}

// Whether an FCM send error means the token is permanently invalid (see
// FCM_PERMANENT_TOKEN_ERROR_CODE's doc comment) as opposed to a transient
// failure (rate limit, server-unavailable, etc.) that should still be
// retried on the next sweep.
function isPermanentTokenError(error) {
  return error?.code === FCM_PERMANENT_TOKEN_ERROR_CODE;
}

// Pure: the exact filter used to clear a permanently-invalid token from the
// user doc. Scoped to the specific token that just failed (`attemptedToken`,
// not just the user id) -- if the client re-synced a fresh token in the
// narrow window between the failed send and this update (e.g.
// onTokenRefresh firing from a reinstall), fcmToken on the user doc no
// longer matches attemptedToken and the update becomes a no-op instead of
// wiping out the new, valid token.
function permanentTokenClearFilter(userId, attemptedToken) {
  return { _id: new ObjectId(userId), fcmToken: attemptedToken };
}

// Shared by the count and batch `find()` below so they can't drift apart.
// A notification leaves this set either by being sent (`sentAt` set) or
// permanently dropped (`deliverySkippedAt` set).
function pendingNotificationsQuery() {
  return {
    sentAt: { $exists: false },
    deliverySkippedAt: { $exists: false },
  };
}

function tierTypes(tier) {
  return tier === 1 ? TIER1_TYPES : TIER2_TYPES;
}

// Sort so that when a user has multiple pending notifications in the same
// batch, the higher-priority one (lower tier, then earlier in its tier's
// type list) is evaluated and sent first, making "highest eligible
// priority wins" deterministic instead of dependent on find() order.
function sortByPriority(notifications) {
  const priorityOf = (type) => {
    const tier = getTier(type);
    if (tier === null) return [99, 0];
    return [tier, tierTypes(tier).indexOf(type)];
  };
  return [...notifications].sort((a, b) => {
    const [tierA, subA] = priorityOf(a.type);
    const [tierB, subB] = priorityOf(b.type);
    return tierA !== tierB ? tierA - tierB : subA - subB;
  });
}

// Current UTC offset (minutes) for IANA zone `timeZoneId` at `nowUtc`,
// via Intl's built-in ICU timezone database -- correct across DST since
// the zone name doesn't change, only the offset it resolves to. Formats
// `nowUtc` in `timeZoneId`, reinterprets those wall-clock parts as UTC,
// and diffs against the real instant. Mirrors notification-scheduler/index.js.
// Returns null for an unresolvable identifier; caller falls back to the
// stored numeric offset.
function getOffsetMinutesForZone(nowUtc, timeZoneId) {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: timeZoneId,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    })
      .formatToParts(nowUtc)
      .reduce((acc, part) => {
        acc[part.type] = part.value;
        return acc;
      }, {});
    const asIfUtc = Date.UTC(
      parseInt(parts.year, 10),
      parseInt(parts.month, 10) - 1,
      parseInt(parts.day, 10),
      parseInt(parts.hour, 10) % 24,
      parseInt(parts.minute, 10),
      parseInt(parts.second, 10)
    );
    return Math.round((asIfUtc - nowUtc.getTime()) / 60000);
  } catch (err) {
    return null;
  }
}

// Prefers the DST-correct offset derived from `user.timezoneId`; falls
// back to the stored `user.timezoneOffsetMinutes` (or 0/UTC) when the id
// is missing or unresolvable. Used by quiet hours, pantry collision, and
// the Tier-2 local-day check below.
function effectiveOffsetMinutes(nowUtc, user) {
  const timeZoneId = user?.timezoneId;
  if (typeof timeZoneId === "string" && timeZoneId.length > 0) {
    const resolved = getOffsetMinutesForZone(nowUtc, timeZoneId);
    if (resolved !== null) return resolved;
  }
  const stored = user?.timezoneOffsetMinutes;
  return Number.isFinite(stored) ? stored : 0;
}

// Resolves the UTC-offset-minutes that actually applies at `instant` --
// prefers the IANA `timezoneId` (correct across DST) and falls back to
// the legacy stored scalar `timezoneOffsetMinutes` when the id is
// missing/unresolvable. Mirrors notification-scheduler/index.js's helper
// of the same name.
function resolveOffsetMinutesAt(instant, timezoneOffsetMinutes, timezoneId) {
  if (typeof timezoneId === "string" && timezoneId.length > 0) {
    const resolved = getOffsetMinutesForZone(instant, timezoneId);
    if (resolved !== null) return resolved;
  }
  return Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0;
}

// Start of the user's local calendar day, expressed back in UTC.
// `timezoneOffsetMinutes` follows the Dart `DateTime.timeZoneOffset` /
// JS `-Date.getTimezoneOffset()` convention: minutes to ADD to UTC to get
// local time -- used as the legacy fallback when `timezoneId` is absent
// or unresolvable. When `timezoneId` IS available, resolves the DST-
// correct offset at `nowUtc` for the calendar date and, separately, at
// the candidate local midnight itself for the conversion back to UTC --
// those can differ by up to an hour on a DST transition day, and blindly
// reusing the offset-at-`nowUtc` for both (the previous implementation)
// shifted the returned instant by that same hour. Mirrors
// `notification_eligibility.local_day_start_utc` (Python) and the
// equivalent helper in notification-scheduler/index.js.
function localDayStartUtc(nowUtc, timezoneOffsetMinutes, timezoneId) {
  const offsetAtNow = resolveOffsetMinutesAt(nowUtc, timezoneOffsetMinutes, timezoneId);
  const localNow = new Date(nowUtc.getTime() + offsetAtNow * 60000);
  const year = localNow.getUTCFullYear();
  const month = localNow.getUTCMonth();
  const day = localNow.getUTCDate();

  const guessMs = offsetAtNow * 60 * 1000;
  const candidateInstant = new Date(Date.UTC(year, month, day) - guessMs);
  const offsetAtMidnight = resolveOffsetMinutesAt(candidateInstant, offsetAtNow, timezoneId);
  return new Date(Date.UTC(year, month, day) - offsetAtMidnight * 60 * 1000);
}

function localHourOf(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  return new Date(nowUtc.getTime() + offsetMs).getUTCHours();
}

function localMinutesOfDay(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const local = new Date(nowUtc.getTime() + offsetMs);
  return local.getUTCHours() * 60 + local.getUTCMinutes();
}

// Mirrors lib/core/utils/meal_reminder_prefs.dart's isMealRemindersMasterEnabled
// / mealReminderOwnEnabled / isMealReminderEnabled. `enabled` at the top
// level is the master switch -- off means every meal is off regardless of
// its own flag. A meal with its own `enabled` key is authoritative once
// the master is on, even overriding a stale top-level `enabled: true`. An
// old-format doc with no per-meal key falls back to the top-level flag.
function isMealRemindersMasterEnabled(prefs) {
  return prefs != null && prefs.enabled === true;
}

function mealReminderOwnEnabled(prefs, meal) {
  const mealPrefs = prefs ? prefs[meal] : null;
  if (
    mealPrefs &&
    typeof mealPrefs === "object" &&
    Object.prototype.hasOwnProperty.call(mealPrefs, "enabled")
  ) {
    return mealPrefs.enabled === true;
  }
  return prefs != null && prefs.enabled === true;
}

function isPersonalizedMealReminderEnabled(prefs, meal) {
  return isMealRemindersMasterEnabled(prefs) && mealReminderOwnEnabled(prefs, meal);
}

// Enabled meal reminder times for today, in minutes since local midnight,
// so pantry pushes can steer around them. Reads only the saved preference
// (`mealLoggingReminderPrefs`) -- personalized reminders are scheduled
// client-side and never pass through this pipeline. Each meal is checked
// independently, so a user with only Dinner enabled gets collision
// avoidance around dinner only.
function getEnabledMealMinutes(user) {
  const prefs = user?.mealLoggingReminderPrefs;
  const minutes = [];
  for (const meal of ["breakfast", "lunch", "dinner"]) {
    if (!isPersonalizedMealReminderEnabled(prefs, meal)) continue;
    const m = prefs[meal];
    if (m && Number.isInteger(m.hour) && Number.isInteger(m.minute)) {
      minutes.push(m.hour * 60 + m.minute);
    }
  }
  return minutes;
}

function isWithinMealCollisionWindow(nowMinutes, mealMinutesList) {
  return mealMinutesList.some(
    (mealMinutes) => Math.abs(nowMinutes - mealMinutes) <= MEAL_COLLISION_BUFFER_MINUTES
  );
}

// Pantry-only delivery gate: preferred time is a floor, not a fixed slot,
// and once past it the push waits only for an actual meal-time collision
// to clear (never for a fixed cutoff), so it's independent of how often
// this sweep runs. Non-pantry types are untouched by this gate entirely.
function pantryDeliveryDeferralReason(type, nowMinutes, user) {
  const preferred = PANTRY_PREFERRED_LOCAL_MINUTES[type];
  if (preferred === undefined) return null;
  if (nowMinutes < preferred) return "preferred_time";
  if (isWithinMealCollisionWindow(nowMinutes, getEnabledMealMinutes(user))) {
    return "meal_collision";
  }
  return null;
}

exports.notificationDelivery = async (req, res) => {
  try {
    const { type } = req.body || {};

    console.log(`[Notification Delivery] Processing ${type} delivery`);

    let result;

    switch (type) {
      case "scheduled":
        result = await sendScheduledNotifications();
        break;
      case "test":
        result = {
          status: "success",
          message: "Test notification delivery is working!",
        };
        break;
      default:
        return res.status(400).json({
          error: "Invalid delivery type. Use: scheduled or test",
        });
    }

    res.status(200).json(result);
  } catch (error) {
    console.error("Error in notification delivery:", error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Send notifications that haven't been sent yet
 */
async function sendScheduledNotifications() {
  let db;
  try {
    await initializeFirebase();
    db = await connectToMongo();

    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log(
      "[Notification Delivery] Starting scheduled notification delivery"
    );

    // Get total count of unsent notifications
    const totalUnsentCount = await notificationsCollection.countDocuments(
      pendingNotificationsQuery()
    );
    console.log(
      `[Notification Delivery] Total unsent notifications: ${totalUnsentCount}`
    );

    if (totalUnsentCount === 0) {
      console.log("[Notification Delivery] No notifications to process");
      return {
        status: "success",
        notificationsProcessed: 0,
        successfulDeliveries: 0,
        failedDeliveries: 0,
        usersWithToken: 0,
        usersWithoutToken: 0,
        results: [],
      };
    }

    // Process all notifications in batches to avoid memory issues
    // Process in batches of 1000, but continue until all are processed
    const BATCH_SIZE = 1000;
    const deliveryResults = [];
    let usersWithToken = 0;
    let usersWithoutToken = 0;
    let totalProcessed = 0;
    let hasMore = true;

    while (hasMore) {
      // Get next batch of notifications
      const scheduledNotifications = await notificationsCollection
        .find(pendingNotificationsQuery())
        .limit(BATCH_SIZE)
        .toArray();

      if (scheduledNotifications.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Notification Delivery] Processing batch: ${
          scheduledNotifications.length
        } notifications (${
          totalProcessed + scheduledNotifications.length
        }/${totalUnsentCount} total)`
      );

      const now = new Date();
      const prioritized = sortByPriority(scheduledNotifications);

      for (const notification of prioritized) {
        // Declared outside the try block (not just inside it) so the catch
        // block below can still see which token was actually attempted --
        // a `const` inside `try {}` is not visible in the sibling `catch`.
        let attemptedFcmToken = null;
        try {
          // Get user's FCM token
          const user = await usersCollection.findOne(
            { _id: new ObjectId(notification.userId) },
            {
              projection: {
                fcmToken: 1,
                name: 1,
                timezoneOffsetMinutes: 1,
                timezoneId: 1,
                mealLoggingReminderPrefs: 1,
                notificationTypePrefs: 1,
              },
            }
          );

          const skipReason = terminalSkipReasonForUser(user);
          if (skipReason) {
            if (skipReason === DELIVERY_SKIP_REASON_NO_FCM_TOKEN) usersWithoutToken++;
            console.log(
              `[Notification Delivery] Permanently skipping ${notification._id.toHexString()} for user ${notification.userId}: ${skipReason}`
            );
            await notificationsCollection.updateOne(
              { _id: notification._id },
              {
                $set: {
                  deliverySkippedAt: new Date(),
                  deliverySkippedReason: skipReason,
                },
              }
            );
            continue;
          }

          const offsetMinutes = effectiveOffsetMinutes(now, user);

          // Final preference gate: never push a type the user has turned
          // off, no matter which path created this document. Left unsent
          // (not marked with a terminal status) so it retries automatically
          // if the user re-enables the preference later.
          if (!isNotificationTypeEnabled(user, notification.type)) {
            console.log(
              `[Notification Delivery] Skipping ${notification._id.toHexString()} for user ${notification.userId}: type ${notification.type} disabled by notification preference`
            );
            continue;
          }

          // Quiet hours: leave unsent (retried on a later sweep) rather
          // than waking the user's device outside 8am-9pm local time.
          const localHour = localHourOf(now, offsetMinutes);
          if (localHour < QUIET_HOURS_START_LOCAL || localHour >= QUIET_HOURS_END_LOCAL) {
            console.log(
              `[Notification Delivery] Deferring ${notification._id.toHexString()} for user ${notification.userId}: outside quiet hours (local hour ${localHour})`
            );
            continue;
          }

          // Pantry preferred-time / meal-collision gate. Only expiring_ingredient
          // and expired_items are affected; every other type skips this
          // entirely and falls straight through to the tier budget check below.
          const nowMinutes = localMinutesOfDay(now, offsetMinutes);
          const pantryDeferralReason = pantryDeliveryDeferralReason(
            notification.type,
            nowMinutes,
            user
          );
          if (pantryDeferralReason) {
            console.log(
              `[Notification Delivery] Deferred pantry notification: reason=${pantryDeferralReason} id=${notification._id.toHexString()} userId=${notification.userId} type=${notification.type}`
            );
            continue;
          }

          // Daily push budget: at most one push per tier per user per local
          // day. Keyed off the *content* date (createdAt), not sentAt -- a
          // notification can sit unsent for a while and go out on a later
          // day than it was created; keying off sentAt let a late delivery
          // consume the wrong day's budget and suppress that day's real
          // alert. `createdAt` may be a native Date or an ISO string
          // (written by the Python backend), hence the $convert.
          const tier = getTier(notification.type);
          if (tier !== null) {
            const todayLocal = localDayStartUtc(now, offsetMinutes, user.timezoneId);
            const alreadySentThisTier = await notificationsCollection
              .aggregate([
                {
                  $match: {
                    userId: notification.userId,
                    type: { $in: tierTypes(tier) },
                    sentAt: { $exists: true },
                  },
                },
                {
                  $addFields: {
                    createdAtParsed: {
                      $convert: {
                        input: "$createdAt",
                        to: "date",
                        onError: new Date(0),
                        onNull: new Date(0),
                      },
                    },
                  },
                },
                { $match: { createdAtParsed: { $gte: todayLocal } } },
                { $limit: 1 },
              ])
              .toArray();
            if (alreadySentThisTier.length > 0) {
              console.log(
                `[Notification Delivery] Dropping ${notification._id.toHexString()} for user ${notification.userId}: tier ${tier} push budget already used today (will not carry over to a later day)`
              );
              await notificationsCollection.updateOne(
                { _id: notification._id },
                {
                  $set: {
                    deliverySkippedAt: new Date(),
                    deliverySkippedReason: DELIVERY_SKIP_REASON_TIER_BUDGET_EXHAUSTED,
                  },
                }
              );
              continue;
            }
          }

          usersWithToken++;

          // Prepare notification payload
          attemptedFcmToken = user.fcmToken;
          const message = {
            token: user.fcmToken,
            notification: {
              title: notification.title,
              body: notification.message,
            },
            data: {
              notificationId: notification._id.toHexString(),
              type: notification.type,
            },
            android: {
              notification: {
                icon: "ic_notification",
                color: getNotificationColor(notification.type),
                priority: "high",
              },
            },
            apns: {
              payload: {
                aps: {
                  badge: 1,
                  sound: "default",
                },
              },
            },
          };

          // Send notification
          const response = await admin.messaging().send(message);
          console.log(
            `[Notification Delivery] Sent notification ${notification._id.toHexString()} to user ${
              notification.userId
            }`
          );

          // Update notification as sent
          await notificationsCollection.updateOne(
            { _id: notification._id },
            {
              $set: {
                sentAt: new Date(),
              },
            }
          );

          deliveryResults.push({
            notificationId: notification._id.toHexString(),
            userId: notification.userId,
            status: "sent",
            fcmMessageId: response,
          });
        } catch (error) {
          console.error(
            `[Notification Delivery] Error sending notification ${notification._id.toHexString()}:`,
            error
          );

          const isPermanentTokenFailure = isPermanentTokenError(error);

          if (isPermanentTokenFailure) {
            console.log(
              `[Notification Delivery] Token permanently invalid for user ${notification.userId}; clearing fcmToken and skipping ${notification._id.toHexString()}`
            );
            await usersCollection.updateOne(
              permanentTokenClearFilter(notification.userId, attemptedFcmToken),
              { $unset: { fcmToken: "" } }
            );
            await notificationsCollection.updateOne(
              { _id: notification._id },
              {
                $set: {
                  deliverySkippedAt: new Date(),
                  deliverySkippedReason: DELIVERY_SKIP_REASON_TOKEN_INVALID,
                },
              }
            );
          }

          deliveryResults.push({
            notificationId: notification._id.toHexString(),
            userId: notification.userId,
            status: isPermanentTokenFailure ? "skipped_invalid_token" : "failed",
            error: error.message,
          });
        }
      }

      totalProcessed += scheduledNotifications.length;

      // If we got fewer notifications than the batch size, we've processed all
      if (scheduledNotifications.length < BATCH_SIZE) {
        hasMore = false;
      }

      // Log progress
      console.log(
        `[Notification Delivery] Batch complete. Progress: ${totalProcessed}/${totalUnsentCount} notifications processed`
      );
    }

    console.log(
      `[Notification Delivery] Completed delivery of all ${totalProcessed} notifications. Users with token: ${usersWithToken}, Users without token: ${usersWithoutToken}`
    );
    console.log(`[Notification Delivery] Results:`, deliveryResults);

    return {
      status: "success",
      notificationsProcessed: totalProcessed,
      successfulDeliveries: deliveryResults.filter((r) => r.status === "sent")
        .length,
      failedDeliveries: deliveryResults.filter((r) => r.status === "failed")
        .length,
      usersWithToken: usersWithToken,
      usersWithoutToken: usersWithoutToken,
      results: deliveryResults,
    };
  } catch (error) {
    console.error("Error in notification delivery:", error);
    throw new Error(`Notification delivery failed: ${error.message}`);
  }
}

function getNotificationColor(type) {
  const colors = {
    expiring_ingredient: "#FF9800", // Orange
    expired_items: "#FF9800", // Orange
    tracker_reminder: "#4CAF50", // Green
    app_inactivity_reminder: "#5C6BC0", // Indigo
    admin: "#9E9E9E", // Grey
    education: "#2196F3", // Blue
    lunch_reminder_fallback: "#FF7043", // Deep orange
    dinner_reminder_fallback: "#FF7043", // Deep orange
  };
  return colors[type] || "#9E9E9E";
}

// Exposed only for scripts/test_*.js so tests exercise the real logic
// instead of a reimplementation. Not used by the runtime itself.
exports.__testables = {
  getTier,
  tierTypes,
  sortByPriority,
  localDayStartUtc,
  resolveOffsetMinutesAt,
  localHourOf,
  localMinutesOfDay,
  getEnabledMealMinutes,
  isWithinMealCollisionWindow,
  pantryDeliveryDeferralReason,
  isNotificationTypeEnabled,
  NOTIFICATION_TYPE_TO_PREF_KEY,
  isMealRemindersMasterEnabled,
  mealReminderOwnEnabled,
  isPersonalizedMealReminderEnabled,
  pendingNotificationsQuery,
  DELIVERY_SKIP_REASON_TIER_BUDGET_EXHAUSTED,
  DELIVERY_SKIP_REASON_USER_DELETED,
  DELIVERY_SKIP_REASON_NO_FCM_TOKEN,
  DELIVERY_SKIP_REASON_TOKEN_INVALID,
  FCM_PERMANENT_TOKEN_ERROR_CODE,
  terminalSkipReasonForUser,
  isPermanentTokenError,
  permanentTokenClearFilter,
  getOffsetMinutesForZone,
  effectiveOffsetMinutes,
};
