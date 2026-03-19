import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/services/pantry_api_service.dart';

class SimpleNotificationService {
  final PantryApiService _pantryApi = PantryApiService();

  Future<void> checkExpiringIngredients(String userId) async {
    try {
      final expiringItems = await _pantryApi.getExpiringItems(userId, daysThreshold: 3);
      final now = DateTime.now();
      final threshold = now.add(const Duration(days: 3));
      final inWindow = expiringItems.where((i) {
        final exp = i['expiryDate']?.toString();
        if (exp == null) return false;
        try {
          final d = DateTime.parse(exp);
          return d.isAfter(now) && d.isBefore(threshold);
        } catch (_) {
          return false;
        }
      }).toList();

      if (inWindow.isEmpty) return;

      final names = inWindow
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

      final list = await ApiClient.get('/notifications') as List?;
      final startOfDay = DateTime(now.year, now.month, now.day);
      final hasToday = list?.any((n) {
        if (n is! Map) return false;
        if (n['type'] != 'expiring_ingredient') return false;
        final createdAt = n['createdAt']?.toString();
        if (createdAt == null) return false;
        try {
          return DateTime.parse(createdAt).isAfter(startOfDay);
        } catch (_) {
          return false;
        }
      }) ?? false;

      if (hasToday) {
        debugPrint('✅ Expiring digest already sent today');
        return;
      }

      await ApiClient.post('/notifications', body: {
        'type': 'expiring_ingredient',
        'title': title,
        'message': message,
      });
      debugPrint('✅ Created expiring items digest');
    } catch (e) {
      debugPrint('Error checking expiring ingredients: $e');
    }
  }

  Future<void> checkExpiredItems(String userId) async {
    try {
      final expiringItems = await _pantryApi.getExpiringItems(userId, daysThreshold: 0);
      final now = DateTime.now();

      final expired = expiringItems.where((i) {
        final exp = i['expiryDate']?.toString();
        if (exp == null) return false;
        final d = DateTime.tryParse(exp);
        if (d == null) return false;
        // Consider expired if it is strictly before "now" (i.e. not "expires today").
        return d.isBefore(now);
      }).toList();

      if (expired.isEmpty) return;

      final names = expired
          .map((i) => (i['name'] ?? '').toString())
          .where((n) => n.isNotEmpty)
          .toList();

      const maxNames = 3;
      final shown = names.take(maxNames).toList();
      final remaining = names.length - shown.length;
      final itemsSummary = remaining > 0
          ? '${shown.join(', ')} and $remaining more'
          : shown.join(', ');

      final list = await ApiClient.get('/notifications') as List?;
      final startOfDay = DateTime(now.year, now.month, now.day);
      final hasToday = list?.any((n) {
        if (n is! Map) return false;
        if (n['type'] != 'expired_items') return false;
        final createdAt = n['createdAt']?.toString();
        if (createdAt == null) return false;
        try {
          return DateTime.parse(createdAt).isAfter(startOfDay);
        } catch (_) {
          return false;
        }
      }) ?? false;

      if (hasToday) {
        debugPrint('✅ Expired digest already sent today');
        return;
      }

      await ApiClient.post('/notifications', body: {
        'type': 'expired_items',
        'title': 'Some food items are expired',
        'message':
            'Expired: $itemsSummary. Tap to review and extend if it is not spoiled.',
      });

      debugPrint('✅ Created expired items digest');
    } catch (e) {
      debugPrint('Error checking expired items: $e');
    }
  }

  Future<void> checkTrackerReminder(String userId) async {
    try {
      final list = await ApiClient.get('/trackers/progress') as List?;
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final hasProgressToday = list?.any((p) {
        if (p is! Map) return false;
        final d = p['progressDate']?.toString();
        if (d == null) return false;
        try {
          final dt = DateTime.parse(d);
          return !dt.isBefore(startOfDay) && dt.isBefore(endOfDay);
        } catch (_) {
          return false;
        }
      }) ?? false;

      if (!hasProgressToday) {
        await ApiClient.post('/notifications', body: {
          'type': 'tracker_reminder',
          'title': 'Time to log your food!',
          'message':
              "You haven't logged anything in your tracker today. Don't forget to track your food!",
        });
      }
    } catch (e) {
      debugPrint('Error checking tracker reminder: $e');
    }
  }

  Future<void> createAdminNotification(
      String userId, String title, String message) async {
    try {
      await ApiClient.post('/notifications', body: {
        'type': 'admin',
        'title': title,
        'message': message,
      });
    } catch (e) {
      debugPrint('Error creating admin notification: $e');
      rethrow;
    }
  }

  Future<void> notifyNewEducation(
      String userId, String articleId, String title) async {
    try {
      await ApiClient.post('/notifications', body: {
        'type': 'education',
        'title': 'New Educational Content Available!',
        'message': 'Check out the new article: $title',
      });
    } catch (e) {
      debugPrint('Error creating education notification: $e');
    }
  }
}
