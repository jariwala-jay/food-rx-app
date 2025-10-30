# Simplified Notification System

## Overview

This notification system has been streamlined to include only the core requirements with minimal complexity.

## Core Features

1. **Expiring Ingredients Notifications** - Users get notified 3 days before pantry items expire
2. **Daily Tracker Reminder** - Users get notified at 8 PM EST if they haven't logged anything in their tracker
3. **Admin Custom Notifications** - Admins can send any custom notification via API
4. **Educational Content** (Optional) - Admin can notify users about new educational materials

## Architecture

### Client Side (Flutter)

- **NotificationService** (`lib/core/services/notification_service.dart`)

  - Handles FCM initialization and token management
  - Stores FCM tokens in MongoDB via `users` collection
  - Supports iOS and Android

- **NotificationManager** (`lib/core/services/notification_manager.dart`)

  - Loads notifications from database
  - Marks notifications as read
  - Manages notification list in UI

- **SimpleNotificationService** (`lib/core/services/simple_notification_service.dart`)
  - `checkExpiringIngredients()` - Checks items expiring in 3 days
  - `checkTrackerReminder()` - Checks if user logged today
  - `createAdminNotification()` - Creates custom admin notifications
  - `notifyNewEducation()` - Notifies about new educational content

### Backend (Google Cloud Functions)

- **notification-scheduler** - Runs daily checks
  - 2 PM EST: Checks expiring ingredients
  - 8 PM EST: Checks tracker reminders
- **notification-delivery** - Sends FCM notifications from database

- **admin-notification** - Admin API endpoint
  ```javascript
  POST /admin-notification
  {
    "password": "ADMIN_PASSWORD",
    "userId": "user_id", // or userIds: ["id1", "id2"]
    "title": "Notification Title",
    "message": "Notification message",
    "type": "admin" // optional
  }
  ```

## Data Model

### app_notification

```dart
{
  id: string,
  userId: string,
  type: 'expiring_ingredient' | 'tracker_reminder' | 'admin' | 'education',
  title: string,
  message: string,
  createdAt: DateTime,
  readAt?: DateTime,
  sentAt?: DateTime
}
```

## MongoDB Collections

### notifications

- Stores all notifications
- Indexes: userId, userId+type, userId+readAt, sentAt

### users

- Stores FCM token in `fcmToken` field

## How It Works

### Expiring Ingredients

1. User adds/updates pantry item
2. If item expires in 3 days, `SimpleNotificationService.checkExpiringIngredients()` is called
3. Notification created in database
4. Cloud scheduler runs at 2 PM EST daily to check all users
5. Cloud delivery function sends via FCM

### Tracker Reminder

1. Cloud scheduler runs at 8 PM EST daily
2. Checks if user has logged any tracker progress today
3. If not, creates notification
4. Cloud delivery function sends via FCM

### Admin Notifications

1. Admin calls `/admin-notification` API with password
2. Notification created for specified user(s)
3. Cloud delivery function sends via FCM

### Educational Content

1. Admin calls `SimpleNotificationService.notifyNewEducation()`
2. Or use admin API with `type: 'education'`

## Deployment

### Cloud Functions

```bash
# Deploy scheduler
gcloud functions deploy notification-scheduler \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-scheduler

# Deploy delivery
gcloud functions deploy notification-delivery \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/notification-delivery

# Deploy admin
gcloud functions deploy admin-notification \
  --runtime nodejs18 \
  --trigger-http \
  --allow-unauthenticated \
  --source gcloud/functions/admin-notification
```

### Cloud Scheduler

```bash
# Expiring ingredients check (2 PM EST)
gcloud scheduler jobs create http expiring-ingredients \
  --schedule="0 19 * * *" \
  --time-zone="America/New_York" \
  --uri="YOUR_FUNCTION_URL/notification-scheduler" \
  --http-method=POST \
  --message-body='{"type":"expiring_ingredients"}'

# Tracker reminder (8 PM EST)
gcloud scheduler jobs create http tracker-reminder \
  --schedule="0 20 * * *" \
  --time-zone="America/New_York" \
  --uri="YOUR_FUNCTION_URL/notification-scheduler" \
  --http-method=POST \
  --message-body='{"type":"tracker_reminder"}'

# Delivery check (every hour)
gcloud scheduler jobs create http notification-delivery \
  --schedule="0 * * * *" \
  --uri="YOUR_FUNCTION_URL/notification-delivery" \
  --http-method=POST \
  --message-body='{"type":"scheduled"}'
```

## Testing

### Test Expiring Ingredients

1. Add pantry item with expiry date = today + 2 days
2. Check notifications in app

### Test Tracker Reminder

1. Don't log anything in tracker
2. Wait for 8 PM EST
3. Check notifications

### Test Admin Notifications

```bash
curl -X POST YOUR_FUNCTION_URL/admin-notification \
  -H "Content-Type: application/json" \
  -d '{
    "password": "YOUR_ADMIN_PASSWORD",
    "userId": "USER_ID",
    "title": "Test Notification",
    "message": "This is a test"
  }'
```

## Environment Variables

- `MONGODB_URI` - MongoDB connection string
- `DB_NAME` - Database name (default: "test")
- `ADMIN_PASSWORD` - Password for admin notifications (set in Cloud Functions)

## Files Structure

```
lib/core/
  models/
    app_notification.dart          # Simple notification model
  services/
    notification_service.dart      # FCM initialization
    notification_manager.dart      # UI state management
    simple_notification_service.dart  # Core notification logic
    mongodb_service.dart           # Database access

gcloud/functions/
  notification-scheduler/          # Daily checks
  notification-delivery/           # FCM sending
  admin-notification/              # Admin API
```

## What Was Removed

- Complex notification preferences system
- Analytics tracking
- Navigation handlers
- Multiple redundant notification services
- Complex scheduler logic with multiple times
- Preference UI page
- Testing page

## Benefits

- **Simpler** - 70% less code
- **Faster** - Fewer database queries
- **Easier to maintain** - Clear single responsibility
- **Better performance** - No complex analytics overhead
