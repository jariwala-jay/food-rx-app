import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/app_notification.dart';

class NotificationNavigationHandler {
  static final NotificationNavigationHandler _instance = NotificationNavigationHandler._internal();
  factory NotificationNavigationHandler() => _instance;
  NotificationNavigationHandler._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Handle notification tap and navigate to appropriate screen
  void handleNotificationTap(AppNotification notification) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      switch (notification.type) {
        case NotificationType.healthGoal:
          _handleHealthGoalNavigation(context, notification);
          break;
        case NotificationType.pantryExpiry:
          _handlePantryNavigation(context, notification);
          break;
        case NotificationType.education:
          _handleEducationNavigation(context, notification);
          break;
        case NotificationType.system:
          _handleSystemNavigation(context, notification);
          break;
      }
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
    }
  }

  void _handleHealthGoalNavigation(BuildContext context, AppNotification notification) {
    switch (notification.category) {
      case NotificationCategory.dailyProgress:
      case NotificationCategory.streak:
        // Navigate to tracking/home screen
        Navigator.pushNamed(context, '/home');
        break;
      default:
        Navigator.pushNamed(context, '/home');
    }
  }

  void _handlePantryNavigation(BuildContext context, AppNotification notification) {
    switch (notification.category) {
      case NotificationCategory.expiryAlert:
        // Navigate to pantry with specific item highlighted
        final itemId = notification.actionData?['itemId'];
        if (itemId != null) {
          Navigator.pushNamed(context, '/pantry', arguments: {'highlightItem': itemId});
        } else {
          Navigator.pushNamed(context, '/pantry');
        }
        break;
      case NotificationCategory.lowStock:
        // Navigate to pantry
        Navigator.pushNamed(context, '/pantry');
        break;
      case NotificationCategory.recipeSuggestion:
        // Navigate to recipes with expiring ingredients filter
        final ingredients = notification.actionData?['ingredients'] as List<String>?;
        Navigator.pushNamed(context, '/recipes', arguments: {'expiringIngredients': ingredients});
        break;
      default:
        Navigator.pushNamed(context, '/pantry');
    }
  }

  void _handleEducationNavigation(BuildContext context, AppNotification notification) {
    switch (notification.category) {
      case NotificationCategory.tip:
        // Navigate to education/tips section
        Navigator.pushNamed(context, '/education');
        break;
      case NotificationCategory.newContent:
        // Navigate to specific article if available
        final articleId = notification.actionData?['articleId'];
        if (articleId != null) {
          Navigator.pushNamed(context, '/article', arguments: {'articleId': articleId});
        } else {
          Navigator.pushNamed(context, '/education');
        }
        break;
      case NotificationCategory.bookmarkReminder:
        // Navigate to bookmarks
        Navigator.pushNamed(context, '/education', arguments: {'showBookmarks': true});
        break;
      default:
        Navigator.pushNamed(context, '/education');
    }
  }

  void _handleSystemNavigation(BuildContext context, AppNotification notification) {
    switch (notification.category) {
      case NotificationCategory.mealReminder:
        // Navigate to meal logging
        final meal = notification.actionData?['meal'] as String?;
        Navigator.pushNamed(context, '/meal-logging', arguments: {'meal': meal});
        break;
      case NotificationCategory.onboarding:
        // Navigate to appropriate onboarding step
        final action = notification.actionData?['action'] as String?;
        switch (action) {
          case 'profile_completion':
            Navigator.pushNamed(context, '/profile-setup');
            break;
          case 'pantry_setup':
            Navigator.pushNamed(context, '/pantry-setup');
            break;
          case 'goal_setting':
            Navigator.pushNamed(context, '/goal-setup');
            break;
          default:
            Navigator.pushNamed(context, '/profile-setup');
        }
        break;
      case NotificationCategory.reengagement:
        // Navigate to home screen
        Navigator.pushNamed(context, '/home');
        break;
      default:
        Navigator.pushNamed(context, '/home');
    }
  }

  /// Handle notification action buttons
  void handleNotificationAction(AppNotification notification, String action) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      switch (action) {
        case 'view':
          handleNotificationTap(notification);
          break;
        case 'dismiss':
          // Dismiss notification (handled by NotificationManager)
          break;
        case 'snooze':
          // Snooze notification for later
          _snoozeNotification(notification);
          break;
        case 'quick_log':
          // Quick meal logging
          final meal = notification.actionData?['meal'] as String?;
          Navigator.pushNamed(context, '/quick-log', arguments: {'meal': meal});
          break;
        case 'add_to_pantry':
          // Add item to pantry
          Navigator.pushNamed(context, '/pantry-add');
          break;
        case 'view_recipes':
          // View recipes with specific filters
          final filters = notification.actionData?['filters'];
          Navigator.pushNamed(context, '/recipes', arguments: {'filters': filters});
          break;
        default:
          handleNotificationTap(notification);
      }
    } catch (e) {
      debugPrint('Error handling notification action: $e');
    }
  }

  void _snoozeNotification(AppNotification notification) {
    // TODO: Implement snooze functionality
    // This would create a new notification scheduled for later
    debugPrint('Snoozing notification: ${notification.title}');
  }

  /// Get appropriate icon for notification type
  IconData getNotificationIcon(NotificationType type) {
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

  /// Get appropriate color for notification type
  Color getNotificationColor(NotificationType type) {
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

  /// Get action buttons for notification
  List<NotificationActionButton> getActionButtons(AppNotification notification) {
    final buttons = <NotificationActionButton>[];

    switch (notification.type) {
      case NotificationType.healthGoal:
        if (notification.category == NotificationCategory.dailyProgress) {
          buttons.add(NotificationActionButton(
            label: 'View Progress',
            action: 'view',
            icon: Icons.trending_up,
          ));
        }
        break;
      case NotificationType.pantryExpiry:
        if (notification.category == NotificationCategory.expiryAlert) {
          buttons.add(NotificationActionButton(
            label: 'View Pantry',
            action: 'view',
            icon: Icons.kitchen,
          ));
          buttons.add(NotificationActionButton(
            label: 'Find Recipes',
            action: 'view_recipes',
            icon: Icons.restaurant,
          ));
        }
        break;
      case NotificationType.system:
        if (notification.category == NotificationCategory.mealReminder) {
          buttons.add(NotificationActionButton(
            label: 'Quick Log',
            action: 'quick_log',
            icon: Icons.add_circle,
          ));
        }
        break;
      default:
        buttons.add(NotificationActionButton(
          label: 'View',
          action: 'view',
          icon: Icons.visibility,
        ));
    }

    // Always add dismiss button
    buttons.add(NotificationActionButton(
      label: 'Dismiss',
      action: 'dismiss',
      icon: Icons.close,
    ));

    return buttons;
  }
}

class NotificationActionButton {
  final String label;
  final String action;
  final IconData icon;

  NotificationActionButton({
    required this.label,
    required this.action,
    required this.icon,
  });
}
