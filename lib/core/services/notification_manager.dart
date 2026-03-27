import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/api_client.dart';

class NotificationManager extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<AppNotification> _notifications = [];
  String? _userId;
  bool _isLoading = false;
  String? _error;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _syncAppIconBadge() async {
    await _notificationService.setAppIconBadgeCount(unreadCount);
  }

  Future<void> clearAppIconBadge() async {
    await _notificationService.clearAppIconBadge();
  }

  Future<void> initialize(String userId) async {
    _userId = userId;
    await loadNotifications();
  }

  Future<void> loadNotifications() async {
    if (_userId == null) return;
    _setLoading(true);
    _setError(null);
    try {
      final list = await ApiClient.get('/notifications');
      if (list is List) {
        _notifications = list
            .whereType<Map<String, dynamic>>()
            .map((doc) => AppNotification.fromJson(doc))
            .toList();
      } else {
        _notifications = [];
      }
      debugPrint(
          'Notifications: loaded ${_notifications.length} for userId=$_userId');
      notifyListeners();
      await _syncAppIconBadge();
    } catch (e) {
      _setError('Failed to load notifications: $e');
      debugPrint('Error loading notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final success = await _notificationService.markAsRead(notificationId);
      if (success) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(
            readAt: DateTime.now(),
          );
          notifyListeners();
          await _syncAppIconBadge();
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> dismissNotification(String notificationId) async {
    try {
      await ApiClient.delete('/notifications/$notificationId');
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      await _syncAppIconBadge();
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
    }
  }

  List<AppNotification> get unreadNotifications {
    return _notifications.where((n) => !n.isRead).toList();
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    try {
      await ApiClient.post('/notifications/mark-all-read');
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(
            readAt: DateTime.now(),
          );
        }
      }
      notifyListeners();
      await _syncAppIconBadge();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    if (_userId == null) return;
    try {
      await ApiClient.delete('/notifications');
      _notifications.clear();
      notifyListeners();
      await _syncAppIconBadge();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

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

  Future<void> createTestNotification() async {
    if (_userId == null) return;
    try {
      await ApiClient.post('/notifications', body: {
        'type': 'admin',
        'title': 'Test Notification',
        'message': 'This is a test notification to verify the system is working.',
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
