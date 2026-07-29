import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/services/simple_notification_service.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/pantry/views/expired_items_page.dart';
import 'package:flutter_app/features/navigation/views/main_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  static final SimpleNotificationService _expiringService =
      SimpleNotificationService();
  bool _sortNewestFirst = true;
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelectionMode() {
    setState(() {
      _selectionMode = true;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(List<AppNotification> notifications) {
    setState(() {
      if (_selectedIds.length == notifications.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(notifications.map((n) => n.id));
      }
    });
  }

  Future<void> _deleteSelected(NotificationManager notificationManager) async {
    if (_selectedIds.isEmpty) return;
    final ids = List<String>.from(_selectedIds);
    await notificationManager.dismissNotifications(ids);
    if (!mounted) return;
    _exitSelectionMode();
  }

  Widget _buildSelectionLeading(NotificationManager notificationManager) {
    final count = notificationManager.notifications.length;
    final allSelected = count > 0 && _selectedIds.length == count;
    final someSelected = _selectedIds.isNotEmpty && !allSelected;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _exitSelectionMode,
          tooltip: 'Cancel selection',
        ),
        Checkbox(
          value: allSelected ? true : (someSelected ? null : false),
          tristate: true,
          activeColor: const Color(0xFFFF6A00),
          onChanged: count == 0
              ? null
              : (_) => _toggleSelectAll(notificationManager.notifications),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Load notifications and ensure expiring-ingredient digest exists for today
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationManager =
          Provider.of<NotificationManager>(context, listen: false);
      // Opening Notification Center should clear the app icon badge immediately.
      notificationManager.clearAppIconBadge();
      notificationManager.loadNotifications();
      _ensureExpiringNotificationThenReload(notificationManager);
      _ensureExpiredNotificationThenReload(notificationManager);
      _ensureTrackerReminderThenReload(notificationManager);
    });
  }

  /// If user has pantry items expiring in the next 3 days, ensure we have
  /// an expiring_ingredient notification for today, then reload the list.
  Future<void> _ensureExpiringNotificationThenReload(
      NotificationManager notificationManager) async {
    try {
      final userId = await ApiClient.userId;
      if (userId == null || userId.isEmpty) return;
      await _expiringService.checkExpiringIngredients(userId);
      await notificationManager.loadNotifications();
    } catch (_) {
      // Ignore; list already loaded
    }
  }

  /// If user has expired pantry items, ensure we have an expired_items
  /// notification for today, then reload the list.
  Future<void> _ensureExpiredNotificationThenReload(
      NotificationManager notificationManager) async {
    try {
      final userId = await ApiClient.userId;
      if (userId == null || userId.isEmpty) return;
      await _expiringService.checkExpiredItems(userId);
      await notificationManager.loadNotifications();
    } catch (_) {
      // Ignore; list already loaded
    }
  }

  /// Ensures a tracker_reminder notification exists for today if the user
  /// hasn't logged anything yet, then reloads. Skips accounts &lt; 24h old.
  Future<void> _ensureTrackerReminderThenReload(
      NotificationManager notificationManager) async {
    try {
      final userId = await ApiClient.userId;
      if (userId == null || userId.isEmpty) return;
      final authController =
          Provider.of<AuthController>(context, listen: false);
      await _expiringService.checkTrackerReminder(
        userId,
        accountCreatedAt: authController.currentUser?.createdAt,
      );
      await notificationManager.loadNotifications();
    } catch (_) {
      // Ignore; list already loaded
    }
  }

  void _goBackToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const MainScreen(initialIndex: 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        leadingWidth: _selectionMode ? 104 : null,
        leading: _selectionMode
            ? Consumer<NotificationManager>(
                builder: (context, notificationManager, child) =>
                    _buildSelectionLeading(notificationManager),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: _goBackToHome,
                tooltip: 'Back to Home',
              ),
        title: Text(_selectionMode
            ? (_selectedIds.isEmpty
                ? 'Select notifications'
                : '${_selectedIds.length} selected')
            : 'Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectionMode)
            Consumer<NotificationManager>(
              builder: (context, notificationManager, child) {
                return IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: _selectedIds.isEmpty
                        ? Colors.grey
                        : Colors.black87,
                  ),
                  tooltip: 'Delete selected',
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _deleteSelected(notificationManager),
                );
              },
            )
          else
            Consumer<NotificationManager>(
              builder: (context, notificationManager, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: Colors.white,
                      textStyle: const TextStyle(color: Colors.black87),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    iconTheme: const IconThemeData(color: Colors.white),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.black87),
                    onSelected: (value) async {
                      switch (value) {
                        case 'sort_newest':
                          if (!mounted) return;
                          setState(() => _sortNewestFirst = true);
                          break;
                        case 'sort_oldest':
                          if (!mounted) return;
                          setState(() => _sortNewestFirst = false);
                          break;
                        case 'mark_all_read':
                          await notificationManager.markAllAsRead();
                          break;
                        case 'select_to_delete':
                          _enterSelectionMode();
                          break;
                        case 'refresh':
                          await notificationManager.loadNotifications();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'sort_newest',
                        child: Row(
                          children: [
                            Icon(Icons.south, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Sort: Newest to Oldest'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'sort_oldest',
                        child: Row(
                          children: [
                            Icon(Icons.north, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Sort: Oldest to Newest'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'refresh',
                        child: Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Refresh'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'mark_all_read',
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Mark all as read'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'select_to_delete',
                        child: Row(
                          children: [
                            Icon(Icons.checklist, color: Colors.black87),
                            SizedBox(width: 8),
                            Text('Select to delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Consumer<NotificationManager>(
        builder: (context, notificationManager, child) {
          if (notificationManager.isLoading) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
              ),
            );
          }

          if (notificationManager.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notifications',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notificationManager.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => notificationManager.loadNotifications(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final notifications = [...notificationManager.notifications]
            ..sort((a, b) => _sortNewestFirst
                ? b.createdAt.compareTo(a.createdAt)
                : a.createdAt.compareTo(b.createdAt));

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'ll see your health progress updates, pantry alerts, and personalized tips here.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => notificationManager.loadNotifications(),
            color: const Color(0xFFFF6A00),
            child: ListView.separated(
              padding: const EdgeInsets.only(
                  top: 12, bottom: 16, left: 16, right: 16),
              separatorBuilder: (_, __) => const SizedBox(height: 0),
              itemCount: notifications.length + (_selectionMode ? 0 : 1),
              itemBuilder: (context, index) {
                if (!_selectionMode && index == notifications.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      'Swipe left on a notification to delete it quickly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  );
                }

                final notification = notifications[index];
                final card = _buildNotificationCard(
                  notification,
                  notificationManager,
                );

                if (_selectionMode) {
                  return card;
                }

                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5275),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SvgPicture.asset(
                      'assets/icons/trash.svg',
                      width: 28,
                      height: 28,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await notificationManager
                        .dismissNotification(notification.id);
                    return true;
                  },
                  child: card,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, NotificationManager notificationManager) {
    final isRead = notification.isRead;
    final timeAgo = _getTimeAgo(notification.createdAt);
    final isSelected = _selectedIds.contains(notification.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: _selectionMode && isSelected
            ? Border.all(color: const Color(0xFFFF6A00), width: 1.5)
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          if (_selectionMode) {
            _toggleSelection(notification.id);
            return;
          }
          if (!isRead) {
            await notificationManager.markAsRead(notification.id);
          }
          _handleNotificationAction(notification);
        },
        onLongPress: _selectionMode
            ? null
            : () async {
                await _showNotificationOptions(
                    notification, notificationManager);
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectionMode) ...[
                Checkbox(
                  value: isSelected,
                  activeColor: const Color(0xFFFF6A00),
                  onChanged: (_) => _toggleSelection(notification.id),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                decoration: BoxDecoration(
                  color: _getTypeColor(notification.type).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  _getTypeIcon(notification.type),
                  color: _getTypeColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.w600 : FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6A00),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Color _getTypeColor(NotificationType type) {
    switch (type) {
      case NotificationType.expiring_ingredient:
        return Colors.orange;
      case NotificationType.expired_items:
        return const Color(0xFFFF6A00);
      case NotificationType.tracker_reminder:
        return Colors.green;
      case NotificationType.app_inactivity_reminder:
        return const Color(0xFF5C6BC0);
      case NotificationType.admin:
        return Colors.blue;
      case NotificationType.education:
        return const Color(0xFFFF6A00); // Orange
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.expiring_ingredient:
        return Icons.warning;
      case NotificationType.expired_items:
        return Icons.warning_amber_rounded;
      case NotificationType.tracker_reminder:
        return Icons.restaurant_menu;
      case NotificationType.app_inactivity_reminder:
        return Icons.notifications_active_outlined;
      case NotificationType.admin:
        return Icons.admin_panel_settings;
      case NotificationType.education:
        return Icons.school;
    }
  }

  void _handleNotificationAction(AppNotification notification) {
    // Navigate directly to the appropriate tab
    switch (notification.type) {
      case NotificationType.expiring_ingredient:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 1)),
          (route) => false,
        );
        break;
      case NotificationType.expired_items:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ExpiredItemsPage()),
          (route) => false,
        );
        break;
      case NotificationType.education:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 3)),
          (route) => false,
        );
        break;
      case NotificationType.admin:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)),
          (route) => false,
        );
        break;
      case NotificationType.tracker_reminder:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)),
          (route) => false,
        );
        break;
      case NotificationType.app_inactivity_reminder:
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen(initialIndex: 0)),
          (route) => false,
        );
        break;
    }
  }

  Future<void> _showNotificationOptions(AppNotification notification,
      NotificationManager notificationManager) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mark_email_read),
              title: const Text('Mark as Read'),
              onTap: () => Navigator.pop(context, 'mark_read'),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      switch (result) {
        case 'mark_read':
          await notificationManager.markAsRead(notification.id);
          break;
        case 'delete':
          await notificationManager.dismissNotification(notification.id);
          break;
      }
    }
  }
}
