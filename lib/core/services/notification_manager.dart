import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/models/notification_preferences.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class NotificationManager extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final MongoDBService _mongoDBService = MongoDBService();

  List<AppNotification> _notifications = [];
  NotificationPreferences? _preferences;
  String? _userId;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppNotification> get notifications => _notifications;
  NotificationPreferences? get preferences => _preferences;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Initialize with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    await loadNotifications();
    await loadPreferences();
  }

  // Load notifications from database
  Future<void> loadNotifications() async {
    if (_userId == null) return;

    _setLoading(true);
    _setError(null);

    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      final results = await collection.find({'userId': _userId!}).toList();

      // Sort by createdAt descending
      results.sort((a, b) => DateTime.parse(b['createdAt'])
          .compareTo(DateTime.parse(a['createdAt'])));

      // Limit to last 50 notifications
      final limitedResults = results.take(50).toList();

      _notifications =
          limitedResults.map((doc) => AppNotification.fromJson(doc)).toList();

      notifyListeners();
    } catch (e) {
      _setError('Failed to load notifications: $e');
      debugPrint('Error loading notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load notification preferences
  Future<void> loadPreferences() async {
    if (_userId == null) return;

    try {
      _preferences = await _notificationService.getPreferences(_userId!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  // Sync notifications with server
  Future<void> syncNotifications() async {
    await loadNotifications();
  }

  // Handle notification action
  Future<void> handleNotificationAction(
      String notificationId, String action) async {
    try {
      switch (action) {
        case 'read':
          await markAsRead(notificationId);
          break;
        case 'dismiss':
          await dismissNotification(notificationId);
          break;
        default:
          debugPrint('Unknown notification action: $action');
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);

      if (success) {
        // Update local state
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            readAt: DateTime.now(),
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Dismiss notification
  Future<void> dismissNotification(String notificationId) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      await collection.deleteOne(
        {'_id': ObjectIdHelper.parseObjectId(notificationId)},
      );

      // Update local state
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  // Update notification preferences
  Future<bool> updatePreferences(NotificationPreferences preferences) async {
    try {
      final success = await _notificationService.updatePreferences(preferences);

      if (success) {
        _preferences = preferences;
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      return false;
    }
  }

  // Get notifications by type
  List<AppNotification> getNotificationsByType(NotificationType type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  // Get notifications by category
  List<AppNotification> getNotificationsByCategory(
      NotificationCategory category) {
    return _notifications.where((n) => n.category == category).toList();
  }

  // Get unread notifications
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  // Get recent notifications (last 7 days)
  List<AppNotification> get recentNotifications {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _notifications.where((n) => n.createdAt.isAfter(weekAgo)).toList();
  }

  // Check if notification type is enabled
  bool isTypeEnabled(NotificationType type) {
    return _preferences?.isTypeEnabled(type) ?? true;
  }

  // Enable notification type
  Future<void> enableType(NotificationType type) async {
    if (_preferences == null) return;

    final updatedPreferences = _preferences!.copyWith();
    updatedPreferences.enableType(type);
    await updatePreferences(updatedPreferences);
  }

  // Disable notification type
  Future<void> disableType(NotificationType type) async {
    if (_preferences == null) return;

    final updatedPreferences = _preferences!.copyWith();
    updatedPreferences.disableType(type);
    await updatePreferences(updatedPreferences);
  }

  // Create a test notification (for development)
  Future<void> createTestNotification() async {
    if (_userId == null) return;

    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      final testNotification = AppNotification(
        userId: _userId!,
        type: NotificationType.system,
        category: NotificationCategory.tip,
        title: 'Test Notification',
        message: 'This is a test notification to verify the system is working.',
        priority: NotificationPriority.low,
        actionRequired: false,
      );

      await collection.insertOne({
        '_id': ObjectIdHelper.parseObjectId(testNotification.id),
        ...testNotification.toJson(),
      });

      // Reload notifications to show the new one
      await loadNotifications();
    } catch (e) {
      debugPrint('Error creating test notification: $e');
    }
  }

  // Clear all notifications
  Future<void> clearAllNotifications() async {
    if (_userId == null) return;

    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      await collection.deleteMany({'userId': _userId!});

      _notifications.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    if (_userId == null) return;

    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      await collection.updateMany(
        {'userId': _userId!},
        {
          '\$set': {
            'readAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        },
      );

      // Update local state
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(
            readAt: DateTime.now(),
          );
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}
