# Notification System Deployment & Testing Guide

## 🚀 Deployment Overview

The notification system consists of several components that need to be deployed:

### **Components to Deploy:**

1. **Flutter App** - Already running locally ✅
2. **Google Cloud Functions** - For notification scheduling and delivery
3. **MongoDB Database** - Already configured ✅
4. **Firebase Project** - For push notifications (optional)

## 📋 Prerequisites

### **1. Google Cloud CLI Setup**

```bash
# Install Google Cloud CLI (if not already installed)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Authenticate with Google Cloud
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

### **2. Firebase CLI Setup**

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login
```

## 🔧 Cloud Functions Deployment

### **1. Deploy Notification Scheduler**

```bash
cd /Users/jay/dev/food-rx-app
gcloud functions deploy notification-scheduler \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-scheduler \
  --set-env-vars MONGODB_URI="your_mongodb_connection_string"
```

### **2. Deploy Notification Delivery**

```bash
gcloud functions deploy notification-delivery \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-delivery \
  --set-env-vars MONGODB_URI="your_mongodb_connection_string"
```

### **3. Set up Cloud Scheduler (Cron Jobs)**

```bash
# Morning notifications (8 AM daily)
gcloud scheduler jobs create http morning-notifications \
  --schedule="0 8 * * *" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"morning"}'

# Afternoon notifications (2 PM daily)
gcloud scheduler jobs create http afternoon-notifications \
  --schedule="0 14 * * *" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"afternoon"}'

# Evening notifications (8 PM daily)
gcloud scheduler jobs create http evening-notifications \
  --schedule="0 20 * * *" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler" \
  --http-method=POST \
  --headers="Content-Type=application/json" \
  --message-body='{"type":"evening"}'
```

## 🧪 Testing Strategy

### **1. Local Testing (Immediate)**

#### **A. Test Notification Creation**

```dart
// Add this to your app for testing
void testNotificationCreation() async {
  final authController = Provider.of<AuthController>(context, listen: false);
  final userId = authController.currentUser?.id;

  if (userId != null) {
    final healthGoalService = authController.healthGoalNotificationService;

    // Test progress milestone
    await healthGoalService?.checkDailyProgressMilestones(userId);

    // Test streak achievement
    await healthGoalService?.checkStreakAchievements(userId);

    // Test goal completion
    await healthGoalService?.checkGoalCompletions(userId);
  }
}
```

#### **B. Test Notification Manager**

```dart
// Test notification loading and display
void testNotificationManager() async {
  final authController = Provider.of<AuthController>(context, listen: false);
  final notificationManager = authController.notificationManager;

  if (notificationManager != null) {
    // Load notifications
    await notificationManager.loadNotifications();

    // Check unread count
    print('Unread notifications: ${notificationManager.unreadCount}');

    // Mark as read
    if (notificationManager.notifications.isNotEmpty) {
      await notificationManager.markAsRead(notificationManager.notifications.first.id);
    }
  }
}
```

### **2. Cloud Functions Testing**

#### **A. Test Scheduler Function**

```bash
# Test morning notifications
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler \
  -H "Content-Type: application/json" \
  -d '{"type":"morning"}'

# Test afternoon notifications
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler \
  -H "Content-Type: application/json" \
  -d '{"type":"afternoon"}'

# Test evening notifications
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/notification-scheduler \
  -H "Content-Type: application/json" \
  -d '{"type":"evening"}'
```

#### **B. Test Delivery Function**

```bash
# Test notification delivery
curl -X POST https://REGION-PROJECT_ID.cloudfunctions.net/notification-delivery \
  -H "Content-Type: application/json" \
  -d '{"userId":"test_user_id"}'
```

### **3. Database Testing**

#### **A. Check Notification Creation**

```javascript
// MongoDB query to check notifications
db.notifications
  .find({ userId: "your_user_id" })
  .sort({ createdAt: -1 })
  .limit(10);
```

#### **B. Check Analytics**

```javascript
// Check notification analytics
db.notification_analytics
  .find({ userId: "your_user_id" })
  .sort({ timestamp: -1 })
  .limit(10);
```

## 🔍 Monitoring & Debugging

### **1. Cloud Functions Logs**

```bash
# View logs for scheduler
gcloud functions logs read notification-scheduler --limit=50

# View logs for delivery
gcloud functions logs read notification-delivery --limit=50
```

### **2. Flutter App Logs**

```bash
# View Flutter logs
flutter logs
```

### **3. MongoDB Monitoring**

```javascript
// Check notification counts by type
db.notifications.aggregate([{ $group: { _id: "$type", count: { $sum: 1 } } }]);

// Check notification delivery rates
db.notification_analytics.aggregate([
  { $group: { _id: "$action", count: { $sum: 1 } } },
]);
```

## 🎯 Testing Scenarios

### **Scenario 1: New User Onboarding**

1. Create a new user account
2. Login to the app
3. Check for onboarding notifications
4. Verify notification preferences are created

### **Scenario 2: Pantry Management**

1. Add items to pantry with expiration dates
2. Update item quantities
3. Check for expiration and low stock alerts
4. Verify recipe suggestions

### **Scenario 3: Health Goal Tracking**

1. Set up health goals
2. Log meals and track progress
3. Check for progress milestone notifications
4. Verify streak achievements

### **Scenario 4: Re-engagement**

1. Simulate user inactivity (modify lastLoginAt in database)
2. Login after 3+ days
3. Check for re-engagement notifications

## 🚨 Troubleshooting

### **Common Issues:**

#### **1. Notifications Not Appearing**

- Check MongoDB connection
- Verify user ID is correct
- Check notification preferences
- Review Cloud Function logs

#### **2. Cloud Functions Not Triggering**

- Verify Cloud Scheduler jobs are enabled
- Check function permissions
- Review function logs for errors

#### **3. iOS Build Issues**

- Firebase is currently disabled for iOS compatibility
- Use local notifications for testing
- Re-enable Firebase when iOS issues are resolved

## 📊 Performance Monitoring

### **Key Metrics to Track:**

1. **Notification Delivery Rate** - % of notifications successfully delivered
2. **User Engagement** - % of notifications opened/acted upon
3. **System Performance** - Response times for Cloud Functions
4. **Error Rates** - Failed notification attempts

### **Monitoring Setup:**

```bash
# Enable Cloud Monitoring
gcloud services enable monitoring.googleapis.com

# Set up alerts for function errors
gcloud alpha monitoring policies create --policy-from-file=monitoring-policy.yaml
```

## 🔄 Continuous Deployment

### **Automated Deployment Script:**

```bash
#!/bin/bash
# deploy-notifications.sh

echo "Deploying notification system..."

# Deploy Cloud Functions
gcloud functions deploy notification-scheduler --source gcloud/functions/notification-scheduler
gcloud functions deploy notification-delivery --source gcloud/functions/notification-delivery

# Update Cloud Scheduler jobs
gcloud scheduler jobs update http morning-notifications --schedule="0 8 * * *"
gcloud scheduler jobs update http afternoon-notifications --schedule="0 14 * * *"
gcloud scheduler jobs update http evening-notifications --schedule="0 20 * * *"

echo "Deployment complete!"
```

This comprehensive guide covers deployment, testing, and monitoring of the notification system. Would you like me to help you implement any specific part of this?
