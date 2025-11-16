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

      for (const notification of scheduledNotifications) {
        try {
          // Get user's FCM token
          const user = await usersCollection.findOne(
            { _id: new ObjectId(notification.userId) },
            { projection: { fcmToken: 1, name: 1 } }
          );

          if (!user || !user.fcmToken) {
            usersWithoutToken++;
            console.log(
              `[Notification Delivery] No FCM token for user ${notification.userId}`
            );
            continue;
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
    tracker_reminder: "#4CAF50", // Green
    admin: "#9E9E9E", // Grey
    education: "#2196F3", // Blue
  };
  return colors[type] || "#9E9E9E";
}
