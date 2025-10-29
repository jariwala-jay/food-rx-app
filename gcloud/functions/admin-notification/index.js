// Google Cloud Function for Admin Notifications
// Allows admins to send custom notifications

const { MongoClient, ObjectId } = require("mongodb");

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "CHANGE_THIS_PASSWORD";

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

exports.adminNotification = async (req, res) => {
  try {
    // Check admin password
    const { password } = req.body || {};
    if (password !== ADMIN_PASSWORD) {
      return res.status(401).json({ error: "Unauthorized" });
    }

    const { userId, userIds, title, message, type } = req.body;

    if (!title || !message) {
      return res.status(400).json({
        error: "Missing required fields: title and message are required",
      });
    }

    if (!userId && !userIds) {
      return res.status(400).json({
        error: "Either userId or userIds array is required",
      });
    }

    const db = await connectToMongo();
    const notificationsCollection = db.collection("notifications");

    const notificationType = type || "admin";
    const usersToNotify = userIds || [userId];
    let notificationsCreated = 0;

    for (const uid of usersToNotify) {
      await notificationsCollection.insertOne({
        userId: uid,
        type: notificationType,
        title: title,
        message: message,
        createdAt: new Date(),
      });
      notificationsCreated++;
    }

    console.log(
      `[Admin Notification] Created ${notificationsCreated} notifications`
    );

    return res.status(200).json({
      status: "success",
      notificationsCreated: notificationsCreated,
    });
  } catch (error) {
    console.error("Error creating admin notification:", error);
    return res.status(500).json({ error: error.message });
  }
};
