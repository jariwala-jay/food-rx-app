import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class SimpleNotificationService {
  final MongoDBService _mongoDBService = MongoDBService();

  /// Check expiring pantry items (3 days before expiry)
  Future<void> checkExpiringIngredients(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));

      // Get expiring items
      final expiringItems = await _mongoDBService.pantryCollection.find({
        'userId': ObjectIdHelper.parseObjectId(userId),
        'expiryDate': {
          '\$lte': threeDaysFromNow.toIso8601String(),
          '\$gte': now.toIso8601String()
        }
      }).toList();

      for (final item in expiringItems) {
        final expiryDate = DateTime.parse(item['expiryDate']);
        final daysUntilExpiry = expiryDate.difference(now).inDays;

        // Create notification if not already sent
        await _createNotification(
          userId: userId,
          type: NotificationType.expiring_ingredient,
          title:
              '${item['name']} expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}!',
          message:
              'Your ${item['name']} expires soon. Consider using it in a recipe today!',
        );
      }
    } catch (e) {
      debugPrint('Error checking expiring ingredients: $e');
    }
  }

  /// Check if user logged anything in tracker today (for 8 PM reminder)
  Future<void> checkTrackerReminder(String userId) async {
    try {
      await _mongoDBService.ensureConnection();

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Get tracker progress for today
      final progressCollection =
          _mongoDBService.db.collection('tracker_progress');
      final todayProgress = await progressCollection.find({
        'userId': userId,
        'progressDate': {
          '\$gte': startOfDay.toIso8601String(),
          '\$lt': endOfDay.toIso8601String(),
        }
      }).toList();

      // If no progress logged today, create reminder
      if (todayProgress.isEmpty) {
        await _createNotification(
          userId: userId,
          type: NotificationType.tracker_reminder,
          title: 'Time to log your meals!',
          message:
              "You haven't logged anything in your tracker today. Don't forget to track your meals!",
        );
      }
    } catch (e) {
      debugPrint('Error checking tracker reminder: $e');
    }
  }

  /// Admin: Create custom notification
  Future<void> createAdminNotification(
      String userId, String title, String message) async {
    try {
      await _createNotification(
        userId: userId,
        type: NotificationType.admin,
        title: title,
        message: message,
      );
    } catch (e) {
      debugPrint('Error creating admin notification: $e');
      rethrow;
    }
  }

  /// Optional: New education content notification
  Future<void> notifyNewEducation(
      String userId, String articleId, String title) async {
    try {
      await _createNotification(
        userId: userId,
        type: NotificationType.education,
        title: 'New Educational Content Available!',
        message: 'Check out the new article: $title',
      );
    } catch (e) {
      debugPrint('Error creating education notification: $e');
    }
  }

  /// Internal helper to create notification
  Future<void> _createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String message,
  }) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      // Check if similar notification already exists today
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final existing = await collection.findOne({
        'userId': userId,
        'type': type.toString().split('.').last,
        'createdAt': {'\$gte': startOfDay.toIso8601String()}
      });

      if (existing != null) {
        debugPrint('Similar notification already sent today, skipping');
        return;
      }

      final notification = AppNotification(
        userId: userId,
        type: type,
        title: title,
        message: message,
      );

      await collection.insertOne({
        '_id': ObjectIdHelper.parseObjectId(notification.id),
        ...notification.toJson(),
      });

      debugPrint('✅ Created notification: ${notification.title}');
    } catch (e) {
      debugPrint('Error creating notification: $e');
      rethrow;
    }
  }
}
