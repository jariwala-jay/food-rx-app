// Google Cloud Function for Notification Delivery
// This function sends notifications via Firebase Cloud Messaging

const { MongoClient, ObjectId } = require("mongodb");
const admin = require("firebase-admin");

// Configuration from Environment Variables
const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";

let client;
let firebaseApp;

/**
 * Initialize Firebase Admin SDK
 */
async function initializeFirebase() {
  if (firebaseApp) return;

  try {
    // Initialize Firebase Admin SDK
    firebaseApp = admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
    console.log("Firebase Admin SDK initialized");
  } catch (error) {
    console.error("Error initializing Firebase Admin SDK:", error);
    throw error;
  }
}

/**
 * Establishes and reuses a MongoDB client connection.
 */
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

/**
 * Main entry point for notification delivery
 * This function handles different types of notification delivery
 */
exports.notificationDelivery = async (req, res) => {
  try {
    const { type, userId } = req.body || {};
    
    console.log(`[Notification Delivery] Processing ${type} delivery`);
    
    let result;
    
    switch (type) {
      case 'scheduled':
        result = await sendScheduledNotifications();
        break;
      case 'urgent':
        if (!userId) {
          return res.status(400).json({ error: 'userId is required for urgent notifications' });
        }
        result = await sendUrgentNotification(userId);
        break;
      case 'test':
        result = { status: 'success', message: 'Test notification delivery is working!' };
        break;
      default:
        return res.status(400).json({ error: 'Invalid delivery type. Use: scheduled, urgent, or test' });
    }
    
    res.status(200).json(result);
  } catch (error) {
    console.error('Error in notification delivery:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Send scheduled notifications
 * Triggered by Cloud Scheduler every hour
 */
async function sendScheduledNotifications() {
  let db;
  try {
    await initializeFirebase();
    db = await connectToMongo();

    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");
    const notificationAnalyticsCollection = db.collection(
      "notification_analytics"
    );

    console.log(
      "[Notification Delivery] Starting scheduled notification delivery"
    );

    // Get notifications that are scheduled to be sent now or in the past
    const now = new Date();
    const scheduledNotifications = await notificationsCollection
      .find({
        scheduledFor: { $lte: now },
        sentAt: { $exists: false },
      })
      .limit(100) // Process in batches
      .toArray();

    console.log(
      `[Notification Delivery] Found ${scheduledNotifications.length} notifications to send`
    );

    const deliveryResults = [];

    for (const notification of scheduledNotifications) {
      try {
        // Get user's FCM token
        const user = await usersCollection.findOne(
          { _id: ObjectIdHelper.parseObjectId(notification.userId) },
          { projection: { fcmToken: 1, name: 1 } }
        );

        if (!user || !user.fcmToken) {
          console.log(
            `[Notification Delivery] No FCM token for user ${notification.userId}`
          );
          continue;
        }

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
            category: notification.category,
            actionRequired: notification.actionRequired.toString(),
            actionData: JSON.stringify(notification.actionData || {}),
          },
          android: {
            notification: {
              icon: "ic_notification",
              color: getNotificationColor(notification.type),
              priority: getAndroidPriority(notification.priority),
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
              sentAt: now,
              updatedAt: now,
            },
          }
        );

        // Track analytics
        await notificationAnalyticsCollection.insertOne({
          userId: notification.userId,
          notificationId: notification._id.toHexString(),
          action: "sent",
          timestamp: now,
          metadata: { fcmMessageId: response },
        });

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

        // Track failed delivery
        await notificationAnalyticsCollection.insertOne({
          userId: notification.userId,
          notificationId: notification._id.toHexString(),
          action: "failed",
          timestamp: now,
          metadata: { error: error.message },
        });

        deliveryResults.push({
          notificationId: notification._id.toHexString(),
          userId: notification.userId,
          status: "failed",
          error: error.message,
        });
      }
    }

    console.log(
      `[Notification Delivery] Completed delivery attempt. Results:`,
      deliveryResults
    );

    return {
      status: "success",
      notificationsProcessed: scheduledNotifications.length,
      successfulDeliveries: deliveryResults.filter((r) => r.status === "sent")
        .length,
      failedDeliveries: deliveryResults.filter((r) => r.status === "failed")
        .length,
      results: deliveryResults,
    };
  } catch (error) {
    console.error("Error in notification delivery:", error);
    throw new Error(`Notification delivery failed: ${error.message}`);
  }
};

/**
 * Send urgent notifications immediately
 * Triggered by pantry expiry alerts or other urgent events
 */
async function sendUrgentNotification(userId) {
  let db;
  try {
    await initializeFirebase();
    db = await connectToMongo();

    const notificationsCollection = db.collection("notifications");
    const usersCollection = db.collection("users");
    const notificationAnalyticsCollection = db.collection(
      "notification_analytics"
    );

    console.log("[Urgent Notification] Processing urgent notification");

    // Parse the notification data from Pub/Sub message
    const notificationData = JSON.parse(
      Buffer.from(pubSubEvent.data, "base64").toString()
    );

    const {
      userId,
      title,
      message,
      type,
      category,
      actionData,
      priority = "urgent",
    } = notificationData;

    // Get user's FCM token
    const user = await usersCollection.findOne(
      { _id: ObjectIdHelper.parseObjectId(userId) },
      { projection: { fcmToken: 1, name: 1 } }
    );

    if (!user || !user.fcmToken) {
      throw new Error(`No FCM token found for user ${userId}`);
    }

    // Create notification record
    const notification = {
      userId: userId,
      type: type,
      category: category,
      title: title,
      message: message,
      priority: priority,
      scheduledFor: new Date(),
      actionRequired: !!actionData,
      actionData: actionData,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    const result = await notificationsCollection.insertOne(notification);
    const notificationId = result.insertedId.toHexString();

    // Prepare FCM message
    const fcmMessage = {
      token: user.fcmToken,
      notification: {
        title: title,
        body: message,
      },
      data: {
        notificationId: notificationId,
        type: type,
        category: category,
        actionRequired: (!!actionData).toString(),
        actionData: JSON.stringify(actionData || {}),
      },
      android: {
        notification: {
          icon: "ic_notification",
          color: getNotificationColor(type),
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: "default",
            alert: {
              title: title,
              body: message,
            },
          },
        },
      },
    };

    // Send notification
    const response = await admin.messaging().send(fcmMessage);
    console.log(
      `[Urgent Notification] Sent urgent notification to user ${userId}`
    );

    // Update notification as sent
    await notificationsCollection.updateOne(
      { _id: result.insertedId },
      {
        $set: {
          sentAt: new Date(),
          updatedAt: new Date(),
        },
      }
    );

    // Track analytics
    await notificationAnalyticsCollection.insertOne({
      userId: userId,
      notificationId: notificationId,
      action: "sent",
      timestamp: new Date(),
      metadata: { fcmMessageId: response, urgent: true },
    });

    return {
      status: "success",
      notificationId: notificationId,
      userId: userId,
      fcmMessageId: response,
    };
  } catch (error) {
    console.error("Error in urgent notification delivery:", error);
    throw new Error(`Urgent notification delivery failed: ${error.message}`);
  }
};

/**
 * Helper function to get notification color based on type
 */
function getNotificationColor(type) {
  const colors = {
    healthGoal: "#4CAF50", // Green
    pantryExpiry: "#FF9800", // Orange
    education: "#2196F3", // Blue
    system: "#9E9E9E", // Grey
  };
  return colors[type] || "#9E9E9E";
}

/**
 * Helper function to get Android priority based on notification priority
 */
function getAndroidPriority(priority) {
  const priorities = {
    low: "normal",
    medium: "high",
    high: "high",
    urgent: "max",
  };
  return priorities[priority] || "normal";
}

/**
 * Helper function to parse ObjectId safely
 */
function ObjectIdHelper() {
  return {
    parseObjectId: function (id) {
      if (typeof id === "string") {
        return new ObjectId(id);
      }
      return id;
    },
  };
}
