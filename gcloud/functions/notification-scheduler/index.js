// Google Cloud Function for Notification Scheduling
// This function generates and schedules notifications based on user data

const { MongoClient, ObjectId } = require("mongodb");

// Configuration from Environment Variables
const MONGODB_URI = process.env.MONGODB_URI;
const DB_NAME = process.env.DB_NAME || "test";

let client;

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
 * Main entry point for notification scheduling
 * This function handles different types of scheduled notifications
 */
exports.notificationScheduler = async (req, res) => {
  try {
    const { type } = req.body || {};
    
    console.log(`[Notification Scheduler] Processing ${type} notifications`);
    
    let result;
    
    switch (type) {
      case 'morning':
        result = await generateMorningNotifications();
        break;
      case 'afternoon':
        result = await generateAfternoonNotifications();
        break;
      case 'evening':
        result = await generateEveningNotifications();
        break;
      case 'test':
        result = { status: 'success', message: 'Test notification scheduler is working!' };
        break;
      default:
        return res.status(400).json({ error: 'Invalid notification type. Use: morning, afternoon, evening, or test' });
    }
    
    res.status(200).json(result);
  } catch (error) {
    console.error('Error in notification scheduler:', error);
    res.status(500).json({ error: error.message });
  }
};

/**
 * Generate notifications for morning (8 AM UTC = 6 AM EST)
 */
async function generateMorningNotifications() {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const notificationsCollection = db.collection("notifications");
    const notificationPreferencesCollection = db.collection(
      "notification_preferences"
    );
    const userTrackersCollection = db.collection("user_trackers");
    const pantryCollection = db.collection("pantry_items");

    console.log("[Morning Notifications] Starting notification generation");

    // Get all users with notification preferences
    const users = await usersCollection
      .aggregate([
        {
          $lookup: {
            from: "notification_preferences",
            localField: "_id",
            foreignField: "userId",
            as: "preferences",
          },
        },
        {
          $match: {
            "preferences.0": { $exists: true },
            "preferences.0.enabledTypes": { $in: ["healthGoal", "system"] },
          },
        },
      ])
      .toArray();

    console.log(
      `[Morning Notifications] Found ${users.length} users to process`
    );

    const notificationsToCreate = [];

    for (const user of users) {
      const userId = user._id.toHexString();
      const preferences = user.preferences[0];
      const userData = user;

      // Check if user wants morning notifications
      const morningTime = preferences.preferredTimes?.morning || "08:00";
      const currentHour = new Date().getUTCHours();
      const preferredHour = parseInt(morningTime.split(":")[0]);

      if (currentHour !== preferredHour) continue;

      // Generate breakfast reminder
      if (preferences.enabledTypes?.includes("system")) {
        notificationsToCreate.push({
          userId: userId,
          type: "system",
          category: "mealReminder",
          title: "Start Your Day Right! 🌅",
          message:
            "Don't forget to log your breakfast to track your daily progress.",
          priority: "medium",
          scheduledFor: new Date(),
          actionRequired: true,
          actionData: { type: "meal_logging", meal: "breakfast" },
          personalizationData: { userName: userData.name || "there" },
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }

      // Generate daily health tip
      if (preferences.enabledTypes?.includes("education")) {
        const healthTip = getDailyHealthTip(userData);
        if (healthTip) {
          notificationsToCreate.push({
            userId: userId,
            type: "education",
            category: "tip",
            title: "Daily Health Tip 💡",
            message: healthTip.message,
            priority: "low",
            scheduledFor: new Date(),
            actionRequired: false,
            personalizationData: { condition: healthTip.condition },
            createdAt: new Date(),
            updatedAt: new Date(),
          });
        }
      }

      // Generate progress motivation
      if (preferences.enabledTypes?.includes("healthGoal")) {
        const progressMotivation = await getProgressMotivation(
          userId,
          userTrackersCollection
        );
        if (progressMotivation) {
          notificationsToCreate.push({
            userId: userId,
            type: "healthGoal",
            category: "dailyProgress",
            title: progressMotivation.title,
            message: progressMotivation.message,
            priority: "medium",
            scheduledFor: new Date(),
            actionRequired: true,
            actionData: { type: "tracking" },
            personalizationData: progressMotivation.personalizationData,
            createdAt: new Date(),
            updatedAt: new Date(),
          });
        }
      }
    }

    // Batch insert notifications
    if (notificationsToCreate.length > 0) {
      await notificationsCollection.insertMany(notificationsToCreate);
      console.log(
        `[Morning Notifications] Created ${notificationsToCreate.length} notifications`
      );
    }

    return {
      status: "success",
      notificationsCreated: notificationsToCreate.length,
    };
  } catch (error) {
    console.error("Error in morning notification generation:", error);
    throw new Error(`Morning notification generation failed: ${error.message}`);
  }
};

/**
 * Generate notifications for afternoon (1 PM UTC = 11 AM EST)
 */
async function generateAfternoonNotifications() {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const notificationsCollection = db.collection("notifications");
    const notificationPreferencesCollection = db.collection(
      "notification_preferences"
    );
    const pantryCollection = db.collection("pantry_items");

    console.log("[Afternoon Notifications] Starting notification generation");

    const users = await usersCollection
      .aggregate([
        {
          $lookup: {
            from: "notification_preferences",
            localField: "_id",
            foreignField: "userId",
            as: "preferences",
          },
        },
        {
          $match: {
            "preferences.0": { $exists: true },
            "preferences.0.enabledTypes": { $in: ["pantryExpiry", "system"] },
          },
        },
      ])
      .toArray();

    console.log(
      `[Afternoon Notifications] Found ${users.length} users to process`
    );

    const notificationsToCreate = [];

    for (const user of users) {
      const userId = user._id.toHexString();
      const preferences = user.preferences[0];

      // Check if user wants afternoon notifications
      const afternoonTime = preferences.preferredTimes?.afternoon || "14:00";
      const currentHour = new Date().getUTCHours();
      const preferredHour = parseInt(afternoonTime.split(":")[0]);

      if (currentHour !== preferredHour) continue;

      // Generate lunch reminder
      if (preferences.enabledTypes?.includes("system")) {
        notificationsToCreate.push({
          userId: userId,
          type: "system",
          category: "mealReminder",
          title: "Lunch Time! 🥗",
          message:
            "Time to log your lunch and stay on track with your health goals.",
          priority: "medium",
          scheduledFor: new Date(),
          actionRequired: true,
          actionData: { type: "meal_logging", meal: "lunch" },
          personalizationData: { userName: user.name || "there" },
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }

      // Generate pantry expiry alerts
      if (preferences.enabledTypes?.includes("pantryExpiry")) {
        const expiryAlerts = await getExpiryAlerts(userId, pantryCollection);
        notificationsToCreate.push(...expiryAlerts);
      }
    }

    // Batch insert notifications
    if (notificationsToCreate.length > 0) {
      await notificationsCollection.insertMany(notificationsToCreate);
      console.log(
        `[Afternoon Notifications] Created ${notificationsToCreate.length} notifications`
      );
    }

    return {
      status: "success",
      notificationsCreated: notificationsToCreate.length,
    };
  } catch (error) {
    console.error("Error in afternoon notification generation:", error);
    throw new Error(
      `Afternoon notification generation failed: ${error.message}`
    );
  }
};

/**
 * Generate notifications for evening (6 PM UTC = 4 PM EST)
 */
async function generateEveningNotifications() {
  let db;
  try {
    db = await connectToMongo();
    const usersCollection = db.collection("users");
    const notificationsCollection = db.collection("notifications");
    const notificationPreferencesCollection = db.collection(
      "notification_preferences"
    );
    const userTrackersCollection = db.collection("user_trackers");

    console.log("[Evening Notifications] Starting notification generation");

    const users = await usersCollection
      .aggregate([
        {
          $lookup: {
            from: "notification_preferences",
            localField: "_id",
            foreignField: "userId",
            as: "preferences",
          },
        },
        {
          $match: {
            "preferences.0": { $exists: true },
            "preferences.0.enabledTypes": { $in: ["healthGoal", "system"] },
          },
        },
      ])
      .toArray();

    console.log(
      `[Evening Notifications] Found ${users.length} users to process`
    );

    const notificationsToCreate = [];

    for (const user of users) {
      const userId = user._id.toHexString();
      const preferences = user.preferences[0];

      // Check if user wants evening notifications
      const eveningTime = preferences.preferredTimes?.evening || "19:00";
      const currentHour = new Date().getUTCHours();
      const preferredHour = parseInt(eveningTime.split(":")[0]);

      if (currentHour !== preferredHour) continue;

      // Generate dinner reminder
      if (preferences.enabledTypes?.includes("system")) {
        notificationsToCreate.push({
          userId: userId,
          type: "system",
          category: "mealReminder",
          title: "Dinner Time! 🍽️",
          message:
            "Complete your day by logging your dinner and see your progress.",
          priority: "medium",
          scheduledFor: new Date(),
          actionRequired: true,
          actionData: { type: "meal_logging", meal: "dinner" },
          personalizationData: { userName: user.name || "there" },
          createdAt: new Date(),
          updatedAt: new Date(),
        });
      }

      // Generate daily progress summary
      if (preferences.enabledTypes?.includes("healthGoal")) {
        const progressSummary = await getDailyProgressSummary(
          userId,
          userTrackersCollection
        );
        if (progressSummary) {
          notificationsToCreate.push({
            userId: userId,
            type: "healthGoal",
            category: "dailyProgress",
            title: progressSummary.title,
            message: progressSummary.message,
            priority: "low",
            scheduledFor: new Date(),
            actionRequired: false,
            personalizationData: progressSummary.personalizationData,
            createdAt: new Date(),
            updatedAt: new Date(),
          });
        }
      }
    }

    // Batch insert notifications
    if (notificationsToCreate.length > 0) {
      await notificationsCollection.insertMany(notificationsToCreate);
      console.log(
        `[Evening Notifications] Created ${notificationsToCreate.length} notifications`
      );
    }

    return {
      status: "success",
      notificationsCreated: notificationsToCreate.length,
    };
  } catch (error) {
    console.error("Error in evening notification generation:", error);
    throw new Error(`Evening notification generation failed: ${error.message}`);
  }
};

/**
 * Helper function to get daily health tip based on user conditions
 */
function getDailyHealthTip(userData) {
  const conditions = userData.medicalConditions || [];
  const dietType = userData.dietType;

  const tips = {
    hypertension: [
      "For managing blood pressure, reduce salt by flavoring with herbs and spices instead.",
      "Try the DASH diet approach: focus on fruits, vegetables, and low-fat dairy.",
      "Limit processed foods which are often high in sodium.",
    ],
    diabetes: [
      "Keep blood sugar stable with complex carbohydrates like quinoa and sweet potatoes.",
      "Pair carbohydrates with protein and healthy fats to slow glucose absorption.",
      "Choose whole grains over refined grains for better blood sugar control.",
    ],
    obesity: [
      "Portion control tip: Use smaller plates to naturally reduce serving sizes.",
      "Focus on fiber-rich foods to help you feel full longer.",
      "Stay hydrated - sometimes thirst is mistaken for hunger.",
    ],
  };

  // Find the first matching condition
  for (const condition of conditions) {
    const lowerCondition = condition.toLowerCase();
    if (lowerCondition.includes("hypertension") && tips.hypertension) {
      return {
        condition: "hypertension",
        message:
          tips.hypertension[
            Math.floor(Math.random() * tips.hypertension.length)
          ],
      };
    }
    if (lowerCondition.includes("diabetes") && tips.diabetes) {
      return {
        condition: "diabetes",
        message:
          tips.diabetes[Math.floor(Math.random() * tips.diabetes.length)],
      };
    }
    if (
      (lowerCondition.includes("obesity") ||
        lowerCondition.includes("overweight")) &&
      tips.obesity
    ) {
      return {
        condition: "obesity",
        message: tips.obesity[Math.floor(Math.random() * tips.obesity.length)],
      };
    }
  }

  // Default tip if no specific condition
  const defaultTips = [
    "Remember to drink plenty of water throughout the day for optimal health.",
    "Include a variety of colorful fruits and vegetables in your meals.",
    "Take time to enjoy your meals and eat mindfully.",
  ];

  return {
    condition: "general",
    message: defaultTips[Math.floor(Math.random() * defaultTips.length)],
  };
}

/**
 * Helper function to get progress motivation
 */
async function getProgressMotivation(userId, userTrackersCollection) {
  try {
    const trackers = await userTrackersCollection
      .find({ userId: userId, isWeeklyGoal: false })
      .toArray();

    if (trackers.length === 0) return null;

    const totalGoals = trackers.length;
    const completedGoals = trackers.filter(
      (t) => t.currentValue >= t.goalValue
    ).length;
    const completionRate = completedGoals / totalGoals;

    if (completionRate === 0) {
      return {
        title: "Let's Get Started! 🚀",
        message:
          "You haven't logged any progress today. Start with one small step towards your health goals!",
        personalizationData: { completionRate: 0, totalGoals },
      };
    } else if (completionRate < 0.5) {
      return {
        title: "You're Making Progress! 💪",
        message: `You've completed ${completedGoals} of ${totalGoals} goals today. Keep going!`,
        personalizationData: { completionRate, completedGoals, totalGoals },
      };
    } else if (completionRate < 1) {
      return {
        title: "Almost There! 🎯",
        message: `Great job! You've completed ${completedGoals} of ${totalGoals} goals. Just a few more to go!`,
        personalizationData: { completionRate, completedGoals, totalGoals },
      };
    } else {
      return {
        title: "Perfect Day! 🌟",
        message: `Amazing! You've completed all ${totalGoals} of your daily goals. You're crushing it!`,
        personalizationData: { completionRate, completedGoals, totalGoals },
      };
    }
  } catch (error) {
    console.error("Error getting progress motivation:", error);
    return null;
  }
}

/**
 * Helper function to get expiry alerts
 */
async function getExpiryAlerts(userId, pantryCollection) {
  try {
    const now = new Date();
    const threeDaysFromNow = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
    const oneDayFromNow = new Date(now.getTime() + 24 * 60 * 60 * 1000);

    const expiringItems = await pantryCollection
      .find({
        userId: userId,
        expiryDate: { $lte: threeDaysFromNow, $gte: now },
      })
      .toArray();

    const alerts = [];

    for (const item of expiringItems) {
      const daysUntilExpiry = Math.ceil(
        (item.expiryDate - now) / (24 * 60 * 60 * 1000)
      );

      let priority = "medium";
      let urgency = "";

      if (daysUntilExpiry <= 1) {
        priority = "urgent";
        urgency = "⚠️ ";
      } else if (daysUntilExpiry <= 2) {
        priority = "high";
        urgency = "🔔 ";
      }

      alerts.push({
        userId: userId,
        type: "pantryExpiry",
        category: "expiryAlert",
        title: `${urgency}${item.name} Expires Soon!`,
        message: `Your ${item.name} expires in ${daysUntilExpiry} day${
          daysUntilExpiry === 1 ? "" : "s"
        }. Consider using it in a recipe today!`,
        priority: priority,
        scheduledFor: new Date(),
        actionRequired: true,
        actionData: { type: "pantry_item", itemId: item._id.toHexString() },
        personalizationData: { itemName: item.name, daysUntilExpiry },
        createdAt: new Date(),
        updatedAt: new Date(),
      });
    }

    return alerts;
  } catch (error) {
    console.error("Error getting expiry alerts:", error);
    return [];
  }
}

/**
 * Helper function to get daily progress summary
 */
async function getDailyProgressSummary(userId, userTrackersCollection) {
  try {
    const trackers = await userTrackersCollection
      .find({ userId: userId, isWeeklyGoal: false })
      .toArray();

    if (trackers.length === 0) return null;

    const completedGoals = trackers.filter(
      (t) => t.currentValue >= t.goalValue
    ).length;
    const totalGoals = trackers.length;

    return {
      title: "Daily Progress Summary 📊",
      message: `Today you completed ${completedGoals} of ${totalGoals} health goals. ${
        completedGoals === totalGoals
          ? "Perfect day!"
          : "Keep up the great work!"
      }`,
      personalizationData: { completedGoals, totalGoals },
    };
  } catch (error) {
    console.error("Error getting daily progress summary:", error);
    return null;
  }
}
