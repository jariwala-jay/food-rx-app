// Google Cloud Function for Admin Notifications
// Allows admins to send custom notifications

const { MongoClient, ObjectId } = require("mongodb");

const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || "CHANGE_THIS_PASSWORD";

let client;

// Mirrors notification_eligibility.NOTIFICATION_TYPE_TO_PREF_KEY (Python)
// and the equivalent maps in notification-scheduler/index.js and
// notification-delivery/index.js.
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

// Malformed/non-hex uids can't be turned into an ObjectId -- returns null
// rather than throwing, so callers can treat them as "unresolvable" (same
// as a valid id with no matching user) instead of a database error.
function parseObjectId(uid) {
  try {
    return new ObjectId(uid);
  } catch (e) {
    return null;
  }
}

// Batches the recipient-preference lookup for a broadcast into a single
// query instead of one findOne per recipient. Throws on a real query
// failure -- callers decide how to handle "couldn't verify" rather than
// this function silently treating an error as "no matching users".
async function fetchPreferencesById(usersCollection, ids) {
  if (ids.length === 0) return new Map();
  const recipients = await usersCollection
    .find({ _id: { $in: ids } }, { projection: { notificationTypePrefs: 1 } })
    .toArray();
  return new Map(recipients.map((r) => [r._id.toHexString(), r]));
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
    const usersCollection = db.collection("users");

    const notificationType = type || "admin";
    const usersToNotify = userIds || [userId];
    let notificationsCreated = 0;
    let notificationsSkippedPreference = 0;
    let notificationsSkippedError = 0;

    // Malformed/unresolvable uids can't be looked up -- they fall through
    // to isNotificationTypeEnabled(null, ...)'s "unresolvable -> default
    // enabled" behavior, same as before (see
    // scripts/test_notification_preferences.js). Valid ids are batched into
    // one query below instead of one findOne per recipient.
    const idByUid = new Map(usersToNotify.map((uid) => [uid, parseObjectId(uid)]));
    const validIds = [...idByUid.values()].filter((id) => id !== null);

    let preferencesById = new Map();
    let lookupFailed = false;
    if (validIds.length > 0) {
      try {
        preferencesById = await fetchPreferencesById(usersCollection, validIds);
      } catch (dbError) {
        // A real database/query failure means we can't verify any of these
        // recipients' preferences -- unlike a malformed id, this is not "no
        // such recipient", it's "unknown", so skip them rather than
        // silently defaulting to sent and defeating the opt-out gate.
        console.error(
          "[Admin Notification] Batched preference lookup failed:",
          dbError
        );
        lookupFailed = true;
      }
    }

    for (const uid of usersToNotify) {
      const objectId = idByUid.get(uid);

      if (objectId && lookupFailed) {
        notificationsSkippedError++;
        continue;
      }

      const recipient = objectId
        ? preferencesById.get(objectId.toHexString()) || null
        : null;

      if (!isNotificationTypeEnabled(recipient, notificationType)) {
        notificationsSkippedPreference++;
        continue;
      }

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
      `[Admin Notification] Created ${notificationsCreated} notifications, skipped ${notificationsSkippedPreference} by preference, skipped ${notificationsSkippedError} by lookup error`
    );

    return res.status(200).json({
      status: "success",
      notificationsCreated: notificationsCreated,
      notificationsSkippedPreference: notificationsSkippedPreference,
      notificationsSkippedError: notificationsSkippedError,
    });
  } catch (error) {
    console.error("Error creating admin notification:", error);
    return res.status(500).json({ error: error.message });
  }
};

// Exposed only for scripts/test_*.js regression checks. Not used by the
// Cloud Function runtime itself, which only invokes exports.adminNotification.
exports.__testables = {
  isNotificationTypeEnabled,
  NOTIFICATION_TYPE_TO_PREF_KEY,
  parseObjectId,
  fetchPreferencesById,
};
