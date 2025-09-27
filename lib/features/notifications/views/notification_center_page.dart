import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/models/app_notification.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  @override
  void initState() {
    super.initState();
    // Load notifications when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationManager = Provider.of<NotificationManager>(context, listen: false);
      notificationManager.loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Consumer<NotificationManager>(
            builder: (context, notificationManager, child) {
              return PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'mark_all_read':
                      await notificationManager.markAllAsRead();
                      break;
                    case 'clear_all':
                      await notificationManager.clearAllNotifications();
                      break;
                    case 'refresh':
                      await notificationManager.loadNotifications();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read),
                        SizedBox(width: 8),
                        Text('Mark All Read'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all),
                        SizedBox(width: 8),
                        Text('Clear All'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationManager>(
        builder: (context, notificationManager, child) {
          if (notificationManager.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
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

          final notifications = notificationManager.notifications;

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
            child: ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(notification, notificationManager);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notification, NotificationManager notificationManager) {
    final isRead = notification.isRead;
    final timeAgo = _getTimeAgo(notification.createdAt);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isRead ? 1 : 3,
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(notification.category),
          child: Icon(
            _getCategoryIcon(notification.category),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[700] : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                color: isRead ? Colors.grey[600] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        trailing: isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () async {
          if (!isRead) {
            await notificationManager.markAsRead(notification.id);
          }
          
          // Handle notification action if needed
          if (notification.actionData != null) {
            _handleNotificationAction(notification);
          }
        },
        onLongPress: () async {
          await _showNotificationOptions(notification, notificationManager);
        },
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

  Color _getCategoryColor(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.dailyProgress:
        return Colors.green;
      case NotificationCategory.streak:
        return Colors.orange;
      case NotificationCategory.expiryAlert:
        return Colors.red;
      case NotificationCategory.tip:
        return Colors.blue;
      case NotificationCategory.mealReminder:
        return Colors.purple;
      case NotificationCategory.onboarding:
        return Colors.teal;
      case NotificationCategory.reengagement:
        return Colors.indigo;
      case NotificationCategory.newContent:
        return Colors.cyan;
      case NotificationCategory.bookmarkReminder:
        return Colors.amber;
      case NotificationCategory.lowStock:
        return Colors.deepOrange;
      case NotificationCategory.recipeSuggestion:
        return Colors.pink;
      case NotificationCategory.motivation:
        return Colors.lightGreen;
      case NotificationCategory.goalAdjustment:
        return Colors.deepPurple;
    }
  }

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.dailyProgress:
        return Icons.trending_up;
      case NotificationCategory.streak:
        return Icons.local_fire_department;
      case NotificationCategory.expiryAlert:
        return Icons.warning;
      case NotificationCategory.tip:
        return Icons.lightbulb;
      case NotificationCategory.mealReminder:
        return Icons.restaurant;
      case NotificationCategory.onboarding:
        return Icons.school;
      case NotificationCategory.reengagement:
        return Icons.refresh;
      case NotificationCategory.newContent:
        return Icons.new_releases;
      case NotificationCategory.bookmarkReminder:
        return Icons.bookmark;
      case NotificationCategory.lowStock:
        return Icons.inventory;
      case NotificationCategory.recipeSuggestion:
        return Icons.menu_book;
      case NotificationCategory.motivation:
        return Icons.favorite;
      case NotificationCategory.goalAdjustment:
        return Icons.tune;
    }
  }

  void _handleNotificationAction(AppNotification notification) {
    // Handle different notification actions
    switch (notification.type) {
      case NotificationType.pantryExpiry:
        // Navigate to pantry page
        Navigator.pushNamed(context, '/pantry');
        break;
      case NotificationType.education:
        // Navigate to recipe page
        Navigator.pushNamed(context, '/recipes');
        break;
      case NotificationType.healthGoal:
        // Navigate to tracking page
        Navigator.pushNamed(context, '/tracking');
        break;
      case NotificationType.system:
        // Default action - could show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification: ${notification.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Future<void> _showNotificationOptions(AppNotification notification, NotificationManager notificationManager) async {
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