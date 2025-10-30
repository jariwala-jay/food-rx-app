// Google Cloud Function for Notification Scheduling
// Handles only expiring ingredients and tracker reminders

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
        result = await checkTrackerReminders();
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
            "Invalid notification type. Use: expiring_ingredients, tracker_reminder, or test",
        });
    }

    res.status(200).json(result);
  } catch (error) {
    console.error("Error in notification scheduler:", error);
    res.status(500).json({ error: error.message });
  }
};

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

    // Get all users
    const users = await usersCollection.find({}).toArray();
    console.log(`[Expiring Ingredients] Checking ${users.length} users`);

    let notificationsCreated = 0;

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
          : `${names.length} items expiring soon`;
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

    console.log(
      `[Expiring Ingredients] Created ${notificationsCreated} notifications`
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
 * Check if users need tracker reminders (8 PM EST)
 */
async function checkTrackerReminders() {
  let db;
  try {
    db = await connectToMongo();
    const progressCollection = db.collection("tracker_progress");
    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");

    console.log("[Tracker Reminder] Starting check");

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    // Get all users
    const users = await usersCollection.find({}).toArray();
    console.log(`[Tracker Reminder] Checking ${users.length} users`);

    let notificationsCreated = 0;

    for (const user of users) {
      const userId = user._id.toHexString();

      // Check if user has any progress today
      const todayProgress = await progressCollection
        .find({
          userId: userId,
          progressDate: {
            $gte: today,
            $lt: tomorrow,
          },
        })
        .toArray();

      if (todayProgress.length > 0) {
        console.log(
          `[Tracker Reminder] User ${userId} has logged today, skipping`
        );
        continue;
      }

      // Check if reminder already sent today
      const today2 = new Date();
      today2.setHours(0, 0, 0, 0);

      const existing = await notificationsCollection.findOne({
        userId: userId,
        type: "tracker_reminder",
        createdAt: { $gte: today2 },
      });

      if (existing) {
        console.log(
          `[Tracker Reminder] Reminder already sent today for user ${userId}`
        );
        continue;
      }

      // Create reminder
      await notificationsCollection.insertOne({
        userId: userId,
        type: "tracker_reminder",
        title: "Time to log your meals!",
        message:
          "You haven't logged anything in your tracker today. Don't forget to track your meals!",
        createdAt: new Date(),
      });

      notificationsCreated++;
    }

    console.log(`[Tracker Reminder] Created ${notificationsCreated} reminders`);

    return {
      status: "success",
      notificationsCreated: notificationsCreated,
    };
  } catch (error) {
    console.error("Error checking tracker reminders:", error);
    throw new Error(`Tracker reminder check failed: ${error.message}`);
  }
}
