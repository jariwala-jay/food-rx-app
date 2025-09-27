import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/notification_manager.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  NotificationType? _selectedFilter;
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Mark All as Read'),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Text('Clear All'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationManager>(
        builder: (context, notificationManager, child) {
          if (notificationManager.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (notificationManager.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    notificationManager.error!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
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

          final notifications = _getFilteredNotifications(notificationManager);

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'You\'ll see your notifications here when they arrive',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildFilterBar(notificationManager),
              Expanded(
                child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _buildNotificationCard(
                        notification, notificationManager);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(NotificationManager notificationManager) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<NotificationType?>(
                value: _selectedFilter,
                hint: const Text('All Types'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<NotificationType?>(
                    value: null,
                    child: Text('All Types'),
                  ),
                  ...NotificationType.values.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(_getNotificationTypeTitle(type)),
                      )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: Text('Unread (${notificationManager.unreadCount})'),
            selected: _showUnreadOnly,
            onSelected: (selected) {
              setState(() {
                _showUnreadOnly = selected;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, NotificationManager manager) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification.type),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: Colors.white,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatDate(notification.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (notification.priority == NotificationPriority.urgent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'URGENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: notification.isRead
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _dismissNotification(notification.id, manager),
              )
            : IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => _markAsRead(notification.id, manager),
              ),
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification.id, manager);
          }
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  List<AppNotification> _getFilteredNotifications(NotificationManager manager) {
    List<AppNotification> notifications = manager.notifications;

    if (_selectedFilter != null) {
      notifications =
          notifications.where((n) => n.type == _selectedFilter).toList();
    }

    if (_showUnreadOnly) {
      notifications = notifications.where((n) => !n.isRead).toList();
    }

    return notifications;
  }

  void _handleMenuAction(String action) {
    final manager = Provider.of<NotificationManager>(context, listen: false);

    switch (action) {
      case 'mark_all_read':
        _markAllAsRead(manager);
        break;
      case 'clear_all':
        _clearAllNotifications(manager);
        break;
    }
  }

  void _markAsRead(String notificationId, NotificationManager manager) {
    manager.markAsRead(notificationId);
  }

  void _dismissNotification(
      String notificationId, NotificationManager manager) {
    manager.dismissNotification(notificationId);
  }

  void _markAllAsRead(NotificationManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Read'),
        content: const Text(
            'Are you sure you want to mark all notifications as read?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              manager.markAllAsRead();
            },
            child: const Text('Mark All Read'),
          ),
        ],
      ),
    );
  }

  void _clearAllNotifications(NotificationManager manager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
            'Are you sure you want to clear all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              manager.clearAllNotifications();
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) {
    // TODO: Implement navigation based on notification type and action data
    debugPrint('Notification tapped: ${notification.title}');
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.healthGoal:
        return Colors.green;
      case NotificationType.pantryExpiry:
        return Colors.orange;
      case NotificationType.education:
        return Colors.blue;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.healthGoal:
        return Icons.favorite;
      case NotificationType.pantryExpiry:
        return Icons.warning;
      case NotificationType.education:
        return Icons.school;
      case NotificationType.system:
        return Icons.info;
    }
  }

  String _getNotificationTypeTitle(NotificationType type) {
    switch (type) {
      case NotificationType.healthGoal:
        return 'Health Goals';
      case NotificationType.pantryExpiry:
        return 'Pantry Alerts';
      case NotificationType.education:
        return 'Education';
      case NotificationType.system:
        return 'System';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}
