import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/services/pantry_api_service.dart';

class SimpleNotificationService {
  final PantryApiService _pantryApi = PantryApiService();

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  // Keeps the today/tomorrow/N-days urgency signal in the *heading* (the
  // body is now fixed regardless of day count — see checkExpiringIngredients
  // below). Mirrors expiringSoonHeading() in
  // gcloud/functions/notification-scheduler/index.js — keep both in sync.
  // Not private (and @visibleForTesting) so it's directly unit-testable —
  // there's no ApiClient mocking seam in this codebase to test it via the
  // public checkExpiringIngredients() entry point instead.
  @visibleForTesting
  static String expiringItemHeading(String itemName, DateTime expiryDate) {
    final days =
        _dateOnly(expiryDate).difference(_dateOnly(DateTime.now())).inDays;
    if (days <= 0) return '$itemName expires today';
    if (days == 1) return '$itemName expires tomorrow';
    return '$itemName expires in $days days';
  }

  // Truncates a multi-item digest body to the first 3 item names plus an
  // "and N more" tail, so a large pantry doesn't produce an unreadably long
  // notification. Mirrors expiringItemsListSummary() in
  // gcloud/functions/notification-scheduler/index.js — keep both in sync.
  @visibleForTesting
  static String expiringItemsListSummary(List<String> names) {
    const maxNames = 3;
    final shown = names.take(maxNames).toList();
    final remaining = names.length - shown.length;
    return remaining > 0
        ? '${shown.join(', ')} and $remaining more'
        : shown.join(', ');
  }

  Future<void> checkExpiringIngredients(String userId) async {
    try {
      final expiringItems =
          await _pantryApi.getExpiringItems(userId, daysThreshold: 3);
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

      final title = names.length == 1
          ? expiringItemHeading(
              names.first,
              DateTime.parse(inWindow.first['expiryDate'].toString()),
            )
          : '${names.length} items expire soon';
      final message = names.length == 1
          ? 'Check your pantry and use it before it expires.'
          : '${expiringItemsListSummary(names)}. Check your pantry and use them before they expire.';

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
          }) ??
          false;

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

  // Unlike checkExpiringIngredients (which is mirrored by a server-side cron
  // in notification-scheduler), this is intentionally the only place where
  // expired_items are created.
  // Expiring items have a deadline: users benefit from being warned before
  // the ingredient expires, even if they have not opened the app recently.
  // That requires proactive server-side detection.
  // Expired items are different. There is no additional deadline to protect;
  // this notification is simply a prompt to review pantry state. The client
  // already has pantry data available when this runs (during pantry loading or
  // notification center open), so adding a server-side check would duplicate
  // work without improving delivery.
  // Keeping this client-only avoids duplicate notification creation paths.
  Future<void> checkExpiredItems(String userId) async {
    try {
      final expiringItems =
          await _pantryApi.getExpiringItems(userId, daysThreshold: 0);
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
          }) ??
          false;

      if (hasToday) {
        debugPrint('✅ Expired digest already sent today');
        return;
      }

      final itemIds = expired
          .map((i) => (i['_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final title = names.length == 1
          ? '${names.first} has expired'
          : 'Some items have expired';
      final message = names.length == 1
          ? 'Review its expiration date and update it if needed.'
          : '${expiringItemsListSummary(names)}. Review the expiration dates and update them if needed.';

      await ApiClient.post('/notifications', body: {
        'type': 'expired_items',
        'title': title,
        'message': message,
        'itemIds': itemIds,
      });

      debugPrint('✅ Created expired items digest');
    } catch (e) {
      debugPrint('Error checking expired items: $e');
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
