import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class NotificationManager extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final MongoDBService _mongoDBService = MongoDBService();

  List<AppNotification> _notifications = [];
  String? _userId;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  // Initialize with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    await loadNotifications();
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

      // Sort by createdAt descending (supports BSON Date or ISO string)
      DateTime _asDate(dynamic v) {
        if (v is DateTime) return v;
        return DateTime.parse(v.toString());
      }

      results.sort(
          (a, b) => _asDate(b['createdAt']).compareTo(_asDate(a['createdAt'])));

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

  // Get unread notifications
  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
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
            // Store as BSON Date
            'readAt': DateTime.now(),
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

  // Debug method to create a test notification
  Future<void> createTestNotification() async {
    if (_userId == null) return;

    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      final testNotification = AppNotification(
        userId: _userId!,
        type: NotificationType.admin,
        title: 'Test Notification',
        message: 'This is a test notification to verify the system is working.',
      );

      await collection.insertOne({
        '_id': ObjectIdHelper.parseObjectId(testNotification.id),
        ...testNotification.toJson(),
      });

      debugPrint('✅ Test notification created');
      await loadNotifications();
    } catch (e) {
      debugPrint('❌ Error creating test notification: $e');
    }
  }

  @override
  void dispose() {
    _notificationService.dispose();
    super.dispose();
  }
}
