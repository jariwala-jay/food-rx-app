// index.js (Google Cloud Function)

const { MongoClient, ObjectId } = require("mongodb");

// --- Configuration from Environment Variables ---
// IMPORTANT: Set these environment variables when deploying your Cloud Function.
// MONGODB_URI: e.g., "mongodb+srv://user:password@cluster.mongodb.net/test?retryWrites=true&w=majority"
// DB_NAME: Your MongoDB database name (e.g., "foodrx")

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test"; // <--- !!! IMPORTANT: Replace 'foodrx_db' with your actual database name !!!

let client; // MongoClient instance to reuse connections

/**
 * Establishes and reuses a MongoDB client connection.
 * @returns {Promise<Db>} The MongoDB database instance.
 */
async function connectToMongo() {
  if (!MONGODB_URI) {
    throw new Error(
      "MONGODB_URI environment variable is not set. Please configure it."
    );
  }

  // Reuse existing client if connected and not explicitly closed
  if (client && client.topology && client.topology.isConnected()) {
    console.log("Reusing existing MongoDB connection.");
    return client.db(DB_NAME);
  }

  try {
    console.log("Attempting to connect to MongoDB...");
    client = new MongoClient(MONGODB_URI, {
      // Recommended options for modern MongoDB drivers
      useNewUrlParser: true,
      useUnifiedTopology: true,
      serverSelectionTimeoutMS: 5000, // Timeout after 5s for initial connection
    });
    await client.connect();
    console.log("Successfully connected to MongoDB.");
    return client.db(DB_NAME);
  } catch (error) {
    console.error("Failed to connect to MongoDB:", error);
    // Ensure client is closed on connection failure to avoid hanging resources
    if (client) {
      await client.close();
      client = null;
    }
    throw new Error("Database connection failed.");
  }
}

/**
 * Calculates the progress date (end of the day in EST) for a daily reset.
 * This function should be triggered at 05:00 UTC (midnight EST).
 * The progress date will be the previous calendar day in UTC, at 23:59:59 UTC.
 * Example: If triggered on 2025-06-23 05:00:00 UTC (which is 2025-06-23 00:00:00 EST),
 * the progress date will be 2025-06-22 23:59:59.999 UTC, representing the end of day for EST.
 *
 * @returns {Date} The progress date representing the end of the previous EST day.
 */
function getDailyProgressDateEST() {
  const now = new Date(); // Current UTC time
  // Create a date for the end of the previous UTC day
  const progressDate = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() - 1,
      23,
      59,
      59,
      999
    )
  );
  return progressDate;
}

/**
 * Calculates the progress date (end of the week in EST) for a weekly reset.
 * This function should be triggered on Sunday at 05:00 UTC (midnight EST).
 * The progress date will be the previous Saturday in UTC, at 23:59:59 UTC.
 * Example: If triggered on 2025-06-22 05:00:00 UTC (Sunday),
 * the progress date will be 2025-06-21 23:59:59.999 UTC (Saturday).
 *
 * @returns {Date} The progress date representing the end of the previous EST week (Saturday).
 */
function getWeeklyProgressDateEST() {
  const now = new Date(); // Current UTC time (e.g., Sunday 05:00 UTC)
  // Get the date for the previous Saturday (UTC)
  const lastSaturday = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() - 1,
      23,
      59,
      59,
      999
    )
  );
  return lastSaturday;
}

/**
 * Cloud Function to reset daily user trackers.
 * Triggered by Cloud Scheduler publishing to 'daily-tracker-reset-topic'.
 */
exports.resetDailyTrackers = async (pubSubEvent, context) => {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const userTrackersCollection = db.collection("user_trackers");
    const trackerProgressCollection = db.collection("tracker_progress");

    // Get all users
    const users = await usersCollection
      .find({}, { projection: { _id: 1 } })
      .toArray();
    console.log(`[Daily Reset] Found ${users.length} users to process.`);

    const nowIso = new Date().toISOString(); // Current timestamp for lastUpdated
    const progressDate = getDailyProgressDateEST(); // End of the day being reset

    for (const user of users) {
      const userId = user._id.toHexString();

      // 1. Fetch current daily trackers for this user
      const dailyTrackers = await userTrackersCollection
        .find({
          userId: userId,
          isWeeklyGoal: false,
        })
        .toArray();

      const progressRecordsToSave = [];
      for (const tracker of dailyTrackers) {
        // Apply the robust _id conversion here:
        let trackerHexId;
        if (tracker._id instanceof ObjectId) {
          trackerHexId = tracker._id.toHexString();
        } else if (typeof tracker._id === "string") {
          // If it's already a string, use it directly.
          // Add a check to ensure it's a valid hex string if strict validation is needed
          // For simplicity, we assume if it's a string, it's the hex ID.
          trackerHexId = tracker._id;
        } else {
          // Fallback for other types, though less common for _id fields
          console.warn(
            `[Daily Reset] Tracker _id for ${tracker.name} is not ObjectId or string. Using toString(). Value: ${tracker._id}`
          );
          trackerHexId = tracker._id.toString();
        }

        if (tracker.currentValue > 0) {
          progressRecordsToSave.push({
            userId: userId,
            trackerId: trackerHexId, // <-- Use the safely converted trackerHexId here
            trackerName: tracker.name,
            trackerCategory: tracker.category,
            targetValue: tracker.goalValue,
            achievedValue: tracker.currentValue,
            progressDate: progressDate.toISOString(),
            periodType: "daily",
            dietType: tracker.dietType,
            unit: tracker.unit,
            createdAt: nowIso,
          });
        }
      }

      // 2. Save progress snapshot (batch insert for efficiency)
      if (progressRecordsToSave.length > 0) {
        try {
          await trackerProgressCollection.insertMany(progressRecordsToSave);
          console.log(
            `[Daily Reset] Saved ${progressRecordsToSave.length} daily progress records for user ${userId}.`
          );
        } catch (err) {
          console.error(
            `[Daily Reset] Error saving progress for user ${userId}:`,
            err
          );
          // Continue processing even if one user's progress save fails
        }
      }

      // 3. Reset current values for daily trackers
      try {
        const resetResult = await userTrackersCollection.updateMany(
          { userId: userId, isWeeklyGoal: false },
          { $set: { currentValue: 0.0, lastUpdated: nowIso } }
        );
        console.log(
          `[Daily Reset] Reset ${resetResult.modifiedCount} daily trackers for user ${userId}.`
        );
      } catch (err) {
        console.error(
          `[Daily Reset] Error resetting trackers for user ${userId}:`,
          err
        );
        // Continue processing even if one user's tracker reset fails
      }
    }

    console.log("Daily tracker reset process completed successfully.");
    return { status: "success", message: "Daily trackers reset completed." };
  } catch (error) {
    console.error("Fatal error during daily tracker reset:", error);
    // Throwing an error indicates to Cloud Functions to retry (if configured)
    throw new Error(`Daily tracker reset failed: ${error.message}`);
  }
};

/**
 * Cloud Function to reset weekly user trackers.
 * Triggered by Cloud Scheduler publishing to 'weekly-tracker-reset-topic'.
 */
exports.resetWeeklyTrackers = async (pubSubEvent, context) => {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const userTrackersCollection = db.collection("user_trackers");
    const trackerProgressCollection = db.collection("tracker_progress");

    // Get all users
    const users = await usersCollection
      .find({}, { projection: { _id: 1 } })
      .toArray();
    console.log(`[Weekly Reset] Found ${users.length} users to process.`);

    const nowIso = new Date().toISOString(); // Current timestamp for lastUpdated
    const progressDate = getWeeklyProgressDateEST(); // End of the week being reset

    for (const user of users) {
      const userId = user._id.toHexString();

      // 1. Fetch current weekly trackers for this user
      const weeklyTrackers = await userTrackersCollection
        .find({
          userId: userId,
          isWeeklyGoal: true,
        })
        .toArray();

      const progressRecordsToSave = [];
      for (const tracker of weeklyTrackers) {
        // Apply the robust _id conversion here:
        let trackerHexId;
        if (tracker._id instanceof ObjectId) {
          trackerHexId = tracker._id.toHexString();
        } else if (typeof tracker._id === "string") {
          trackerHexId = tracker._id;
        } else {
          console.warn(
            `[Weekly Reset] Tracker _id for ${tracker.name} is not ObjectId or string. Using toString(). Value: ${tracker._id}`
          );
          trackerHexId = tracker._id.toString();
        }

        if (tracker.currentValue > 0) {
          progressRecordsToSave.push({
            userId: userId,
            trackerId: trackerHexId, // <-- Use the safely converted trackerHexId here
            trackerName: tracker.name,
            trackerCategory: tracker.category,
            targetValue: tracker.goalValue,
            achievedValue: tracker.currentValue,
            progressDate: progressDate.toISOString(),
            periodType: "weekly",
            dietType: tracker.dietType,
            unit: tracker.unit,
            createdAt: nowIso,
          });
        }
      }

      // 2. Save progress snapshot (batch insert for efficiency)
      if (progressRecordsToSave.length > 0) {
        try {
          await trackerProgressCollection.insertMany(progressRecordsToSave);
          console.log(
            `[Weekly Reset] Saved ${progressRecordsToSave.length} weekly progress records for user ${userId}.`
          );
        } catch (err) {
          console.error(
            `[Weekly Reset] Error saving progress for user ${userId}:`,
            err
          );
        }
      }

      // 3. Reset current values for weekly trackers
      try {
        const resetResult = await userTrackersCollection.updateMany(
          { userId: userId, isWeeklyGoal: true },
          { $set: { currentValue: 0.0, lastUpdated: nowIso } }
        );
        console.log(
          `[Weekly Reset] Reset ${resetResult.modifiedCount} weekly trackers for user ${userId}.`
        );
      } catch (err) {
        console.error(
          `[Weekly Reset] Error resetting trackers for user ${userId}:`,
          err
        );
      }
    }

    console.log("Weekly tracker reset process completed successfully.");
    return { status: "success", message: "Weekly trackers reset completed." };
  } catch (error) {
    console.error("Fatal error during weekly tracker reset:", error);
    throw new Error(`Weekly tracker reset failed: ${error.message}`);
  }
};
