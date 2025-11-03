import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class SimpleNotificationService {
  final MongoDBService _mongoDBService = MongoDBService();

  /// Check expiring pantry items (3 days before expiry)
  /// Best practice: send a single daily digest per user with a capped list of items.
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

      if (expiringItems.isEmpty) return;

      // Summarize items: include up to 3 names, then "+N more"
      final names = expiringItems
          .map((i) => (i['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toList();
      const maxNames = 3;
      final shown = names.take(maxNames).toList();
      final remaining = names.length - shown.length;
      final itemsSummary = remaining > 0
          ? '${shown.join(', ')} and $remaining more'
          : shown.join(', ');

      final title = names.length == 1
          ? '${names.first} expires soon'
          : '${names.length} food expiring soon';
      final message = names.length == 1
          ? 'Use it in a recipe today so it doesn\'t go to waste.'
          : 'Expiring soon: $itemsSummary';

      // If a digest exists today, update it instead of creating a new one
      final collection = _mongoDBService.notificationsCollection;
      final startOfDay = DateTime(now.year, now.month, now.day);
      final existing = await collection.findOne({
        'userId': userId,
        'type': 'expiring_ingredient',
        'createdAt': {'\$gte': startOfDay}
      });

      if (existing != null) {
        await collection.updateOne({
          '_id': ObjectIdHelper.parseObjectId(
              existing['_id']?.toString() ?? existing['id'])
        }, {
          '\$set': {
            'title': title,
            'message': message,
            'updatedAt': DateTime.now(),
          }
        });
        debugPrint('✅ Updated expiring items digest for today');
        return;
      }

      await _createNotification(
        userId: userId,
        type: NotificationType.expiring_ingredient,
        title: title,
        message: message,
      );
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
          title: 'Time to log your food!',
          message:
              "You haven't logged anything in your tracker today. Don't forget to track your food!",
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
