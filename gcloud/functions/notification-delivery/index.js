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
const TIER2_TYPES = ["tracker_reminder", "app_inactivity_reminder"];
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

function getTier(type) {
  if (TIER1_TYPES.includes(type)) return 1;
  if (TIER2_TYPES.includes(type)) return 2;
  return null;
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

// Mirrors `notification_eligibility.local_day_start_utc` (Python) and the
// equivalent helper in notification-scheduler/index.js.
function localDayStartUtc(nowUtc, timezoneOffsetMinutes) {
  const offsetMs = (Number.isFinite(timezoneOffsetMinutes) ? timezoneOffsetMinutes : 0) * 60 * 1000;
  const localNow = new Date(nowUtc.getTime() + offsetMs);
  const localMidnightUtc = Date.UTC(localNow.getUTCFullYear(), localNow.getUTCMonth(), localNow.getUTCDate());
  return new Date(localMidnightUtc - offsetMs);
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

// Enabled meal reminder times for today, as minutes-since-local-midnight.
// Meal reminders themselves are scheduled entirely client-side and never
// pass through this pipeline; this reads only the user's saved preference
// (`mealLoggingReminderPrefs`) so pantry pushes can steer around them.
function getEnabledMealMinutes(user) {
  const prefs = user?.mealLoggingReminderPrefs;
  if (!prefs || prefs.enabled !== true) return [];
  const minutes = [];
  for (const meal of ["breakfast", "lunch", "dinner"]) {
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
    const totalUnsentCount = await notificationsCollection.countDocuments({
      sentAt: { $exists: false },
    });
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
        .find({
          sentAt: { $exists: false },
        })
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
        try {
          // Get user's FCM token
          const user = await usersCollection.findOne(
            { _id: new ObjectId(notification.userId) },
            {
              projection: {
                fcmToken: 1,
                name: 1,
                timezoneOffsetMinutes: 1,
                mealLoggingReminderPrefs: 1,
              },
            }
          );

          if (!user || !user.fcmToken) {
            usersWithoutToken++;
            console.log(
              `[Notification Delivery] No FCM token for user ${notification.userId}`
            );
            continue;
          }

          // Quiet hours: leave unsent (retried on a later sweep) rather
          // than waking the user's device outside 8am-9pm local time.
          const localHour = localHourOf(now, user.timezoneOffsetMinutes);
          if (localHour < QUIET_HOURS_START_LOCAL || localHour >= QUIET_HOURS_END_LOCAL) {
            console.log(
              `[Notification Delivery] Deferring ${notification._id.toHexString()} for user ${notification.userId}: outside quiet hours (local hour ${localHour})`
            );
            continue;
          }

          // Pantry preferred-time / meal-collision gate. Only expiring_ingredient
          // and expired_items are affected; every other type skips this
          // entirely and falls straight through to the tier budget check below.
          const nowMinutes = localMinutesOfDay(now, user.timezoneOffsetMinutes);
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

          // Daily push budget: at most one push per tier per user per
          // local day. If this user already got a push in this tier
          // today, leave this one unsent (it stays visible in the
          // Notification Center and is retried later/next day).
          const tier = getTier(notification.type);
          if (tier !== null) {
            const todayLocal = localDayStartUtc(now, user.timezoneOffsetMinutes);
            const alreadySentThisTier = await notificationsCollection.findOne({
              userId: notification.userId,
              type: { $in: tierTypes(tier) },
              sentAt: { $gte: todayLocal },
            });
            if (alreadySentThisTier) {
              console.log(
                `[Notification Delivery] Skipping ${notification._id.toHexString()} for user ${notification.userId}: tier ${tier} push budget already used today`
              );
              continue;
            }
          }

          usersWithToken++;

          // Prepare notification payload
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

          deliveryResults.push({
            notificationId: notification._id.toHexString(),
            userId: notification.userId,
            status: "failed",
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
  };
  return colors[type] || "#9E9E9E";
}
