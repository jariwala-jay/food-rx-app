// Google Cloud Function for Notification Scheduling
// Handles expiring ingredients and inactivity reminders.

const { MongoClient, ObjectId } = require("mongodb");

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";

let client;

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

exports.notificationScheduler = async (req, res) => {
  try {
    const { type } = req.body || {};

    console.log(`[Notification Scheduler] Processing ${type} notifications`);

    let result;

    switch (type) {
      case "expiring_ingredients":
        result = await checkExpiringIngredients();
        break;
      case "tracker_reminder":
        result = await checkMealLoggingInactivityReminders();
        break;
      case "app_inactivity_reminder":
        result = await checkAppInactivityReminders();
        break;
      case "run_all":
        result = await runAllNotificationChecks();
        break;
      case "test":
        result = {
          status: "success",
          message: "Test notification scheduler is working!",
        };
        break;
      default:
        return res.status(400).json({
          error:
            "Invalid notification type. Use: expiring_ingredients, tracker_reminder, app_inactivity_reminder, run_all, or test",
        });
    }

    res.status(200).json(result);
  } catch (error) {
    console.error("Error in notification scheduler:", error);
    res.status(500).json({ error: error.message });
  }
};

const MEAL_LOGGING_DAY_MILESTONES = [1, 2, 3, 4, 5, 6];
const MEAL_LOGGING_WEEK_MILESTONES = [7, 14, 21, 28];
const MEAL_LOGGING_MONTH_MILESTONES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

const APP_OPEN_DAY_MILESTONES = [1, 2, 3, 4, 5, 6];
const APP_OPEN_WEEK_MILESTONES = [7, 14, 21, 28];
const APP_OPEN_MONTH_MILESTONES = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

function toStartOfDay(date) {
  const d = new Date(date);
  d.setHours(0, 0, 0, 0);
  return d;
}

function dayDiffFloor(later, earlier) {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.floor(
    (toStartOfDay(later).getTime() - toStartOfDay(earlier).getTime()) / msPerDay
  );
}

function addMonths(date, months) {
  const d = new Date(date);
  const originalDay = d.getDate();
  d.setMonth(d.getMonth() + months);
  if (d.getDate() < originalDay) {
    d.setDate(0);
  }
  return d;
}

function getInactivityBucket(now, referenceDate, dayMilestones, weekMilestones, monthMilestones) {
  if (!referenceDate) return null;

  const days = dayDiffFloor(now, referenceDate);
  if (days <= 0) return null;

  for (const d of dayMilestones) {
    if (days === d) {
      return { key: `d${d}`, days };
    }
  }

  for (const w of weekMilestones) {
    if (days === w) {
      return { key: `w${w / 7}`, days };
    }
  }

  for (const m of monthMilestones) {
    const target = addMonths(toStartOfDay(referenceDate), m);
    const targetDay = toStartOfDay(target).getTime();
    const todayDay = toStartOfDay(now).getTime();
    if (targetDay === todayDay) {
      return { key: `m${m}`, days };
    }
  }

  return null;
}

function bucketLabel(bucketKey) {
  if (!bucketKey || bucketKey.length < 2) return "";
  const kind = bucketKey[0];
  const value = parseInt(bucketKey.slice(1), 10);
  if (Number.isNaN(value)) return "";
  if (kind === "d") return `${value} day${value > 1 ? "s" : ""}`;
  if (kind === "w") return `${value} week${value > 1 ? "s" : ""}`;
  if (kind === "m") return `${value} month${value > 1 ? "s" : ""}`;
  return "";
}

function formatBucketMessage(prefix, bucketKey) {
  const label = bucketLabel(bucketKey);
  if (!label) return prefix;
  return `${prefix} It's been ${label}.`;
}

/**
 * Check for expiring pantry items (3 days before expiry)
 */
async function checkExpiringIngredients() {
  let db;
  try {
    db = await connectToMongo();
    const pantryCollection = db.collection("pantry_items");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Expiring Ingredients] Starting check");

    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);

    // Get total user count
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Expiring Ingredients] Total users to check: ${totalUsers}`);

    // Process users in batches to avoid memory issues
    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      // Get next batch of users
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Expiring Ingredients] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Get expiring items for this user (next 3 days)
        // expiryDate may be stored as ISO string; convert to Date for comparison
        const expiringItems = await pantryCollection
          .aggregate([
            {
              $match: {
                userId: user._id,
                expiryDate: { $exists: true, $ne: null },
              },
            },
            { $addFields: { expiryDateParsed: { $toDate: "$expiryDate" } } },
            {
              $match: { expiryDateParsed: { $lte: threeDaysFromNow, $gte: now } },
            },
          ])
          .toArray();

        if (expiringItems.length === 0) continue;

        // Build a digest message with up to 3 item names
        const names = expiringItems
          .map((i) => (i.name || "").toString())
          .filter((n) => n.length > 0);

        const maxNames = 3;
        const shown = names.slice(0, maxNames);
        const remaining = names.length - shown.length;
        const itemsSummary =
          remaining > 0
            ? `${shown.join(", ")} and ${remaining} more`
            : shown.join(", ");

        const title =
          names.length === 1
            ? `${names[0]} expires soon`
            : `${names.length} food items expiring soon`;
        const message =
          names.length === 1
            ? "Use it in a recipe today so it doesn't go to waste."
            : `Expiring soon: ${itemsSummary}`;

        // If a digest exists today, update it; otherwise insert new
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const existing = await notificationsCollection.findOne({
          userId: userId,
          type: "expiring_ingredient",
          createdAt: { $gte: today },
        });

        if (existing) {
          await notificationsCollection.updateOne(
            { _id: existing._id },
            { $set: { title, message, updatedAt: new Date() } }
          );
          console.log(
            `[Expiring Ingredients] Updated digest for user ${userId} with ${names.length} items`
          );
        } else {
          await notificationsCollection.insertOne({
            userId: userId,
            type: "expiring_ingredient",
            title,
            message,
            createdAt: new Date(),
          });
          notificationsCreated++;
        }
      }

      processedUsers += users.length;

      // If we got fewer users than the batch size, we've processed all
      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Expiring Ingredients] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} notifications created so far`
      );
    }

    console.log(
      `[Expiring Ingredients] Completed. Processed ${processedUsers} users, created ${notificationsCreated} notifications`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking expiring ingredients:", error);
    throw new Error(`Expiring ingredients check failed: ${error.message}`);
  }
}

/**
 * Meal logging inactivity reminders.
 */
async function checkMealLoggingInactivityReminders() {
  let db;
  try {
    db = await connectToMongo();
    const progressCollection = db.collection("tracker_progress");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Meal Logging Reminder] Starting check");

    const now = new Date();

    // Get total user count
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[Meal Logging Reminder] Total users to check: ${totalUsers}`);

    // Process users in batches to avoid memory issues
    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      // Get next batch of users
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      console.log(
        `[Meal Logging Reminder] Processing batch: ${users.length} users (${processedUsers + users.length}/${totalUsers} total)`
      );

      for (const user of users) {
        const userId = user._id.toHexString();

        // Only one tracker reminder notification per user per day.
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const existingToday = await notificationsCollection.findOne({
          userId: userId,
          type: "tracker_reminder",
          createdAt: { $gte: today },
        });
        if (existingToday) {
          continue;
        }

        const latestProgress = await progressCollection
          .find({
            userId: userId,
          })
          .sort({ progressDate: -1 })
          .limit(1)
          .toArray();

        if (latestProgress.length === 0) {
          continue;
        }

        const latestDate = new Date(latestProgress[0].progressDate);
        if (Number.isNaN(latestDate.getTime())) {
          continue;
        }

        const bucket = getInactivityBucket(
          now,
          latestDate,
          MEAL_LOGGING_DAY_MILESTONES,
          MEAL_LOGGING_WEEK_MILESTONES,
          MEAL_LOGGING_MONTH_MILESTONES
        );

        if (!bucket) {
          continue;
        }

        // Dedupe per bucket.
        const existing = await notificationsCollection.findOne({
          userId: userId,
          type: "tracker_reminder",
          bucketKey: bucket.key,
        });

        if (existing) {
          continue;
        }

        await notificationsCollection.insertOne({
          userId: userId,
          type: "tracker_reminder",
          title: "Don't forget to log your meals",
          message: formatBucketMessage(
            "It's time to log your food and stay on track with your nutrition goals.",
            bucket.key
          ),
          bucketKey: bucket.key,
          daysSinceLastLog: bucket.days,
          createdAt: new Date(),
        });

        notificationsCreated++;
      }

      processedUsers += users.length;

      // If we got fewer users than the batch size, we've processed all
      if (users.length < BATCH_SIZE) {
        hasMore = false;
      }

      console.log(
        `[Meal Logging Reminder] Batch complete. Progress: ${processedUsers}/${totalUsers} users processed, ${notificationsCreated} reminders created so far`
      );
    }

    console.log(
      `[Meal Logging Reminder] Completed. Processed ${processedUsers} users, created ${notificationsCreated} reminders`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking meal logging inactivity reminders:", error);
    throw new Error(`Meal logging reminder check failed: ${error.message}`);
  }
}

/**
 * App-open inactivity reminders.
 */
async function checkAppInactivityReminders() {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const notificationsCollection = db.collection("notifications");

    console.log("[App Inactivity Reminder] Starting check");

    const now = new Date();
    const totalUsers = await usersCollection.countDocuments({});
    console.log(`[App Inactivity Reminder] Total users to check: ${totalUsers}`);

    const BATCH_SIZE = 1000;
    let notificationsCreated = 0;
    let processedUsers = 0;
    let hasMore = true;

    while (hasMore) {
      const users = await usersCollection
        .find({})
        .skip(processedUsers)
        .limit(BATCH_SIZE)
        .toArray();

      if (users.length === 0) {
        hasMore = false;
        break;
      }

      for (const user of users) {
        const userId = user._id.toHexString();

        // Only one app inactivity reminder notification per user per day.
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const existingToday = await notificationsCollection.findOne({
          userId: userId,
          type: "app_inactivity_reminder",
          createdAt: { $gte: today },
        });
        if (existingToday) continue;

        const rawLastActive = user.lastActiveAt || user.lastLoginAt || user.updatedAt;
        if (!rawLastActive) continue;

        const lastActiveDate = new Date(rawLastActive);
        if (Number.isNaN(lastActiveDate.getTime())) continue;

        const bucket = getInactivityBucket(
          now,
          lastActiveDate,
          APP_OPEN_DAY_MILESTONES,
          APP_OPEN_WEEK_MILESTONES,
          APP_OPEN_MONTH_MILESTONES
        );

        if (!bucket) continue;

        const existing = await notificationsCollection.findOne({
          userId: userId,
          type: "app_inactivity_reminder",
          bucketKey: bucket.key,
        });

        if (existing) continue;

        await notificationsCollection.insertOne({
          userId: userId,
          type: "app_inactivity_reminder",
          title: "We miss you at MyFoodRx",
          message: formatBucketMessage(
            "Open the app to review your pantry, trackers, and recommendations.",
            bucket.key
          ),
          bucketKey: bucket.key,
          daysSinceLastActive: bucket.days,
          createdAt: new Date(),
        });

        notificationsCreated++;
      }

      processedUsers += users.length;
      if (users.length < BATCH_SIZE) hasMore = false;
    }

    console.log(
      `[App Inactivity Reminder] Completed. Processed ${processedUsers} users, created ${notificationsCreated} reminders`
    );

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking app inactivity reminders:", error);
    throw new Error(`App inactivity reminder check failed: ${error.message}`);
  }
}

async function runAllNotificationChecks() {
  const expiring = await checkExpiringIngredients();
  const meal = await checkMealLoggingInactivityReminders();
  const app = await checkAppInactivityReminders();
  return {
    status: "success",
    expiringIngredients: expiring.notificationsCreated || 0,
    mealLoggingReminders: meal.notificationsCreated || 0,
    appInactivityReminders: app.notificationsCreated || 0,
  };
}
