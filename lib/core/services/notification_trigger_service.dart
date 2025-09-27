import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class NotificationTriggerService {
  final MongoDBService _mongoDBService = MongoDBService();
  final NotificationManager _notificationManager = NotificationManager();

  // Initialize the trigger service
  Future<void> initialize(String userId) async {
    await _notificationManager.initialize(userId);
  }

  // Check for meal logging reminders
  Future<void> checkMealLoggingReminders(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get user's last meal logging activity
      final lastMealLog = await _getLastMealLog(userId);
      final now = DateTime.now();
      
      // Check if user hasn't logged breakfast by 10 AM
      if (now.hour >= 10 && !_hasLoggedMeal(lastMealLog, 'breakfast', now)) {
        await _createMealReminderNotification(
          userId, 
          'breakfast', 
          'Start Your Day Right! 🌅',
          "Don't forget to log your breakfast to track your daily progress."
        );
      }
      
      // Check if user hasn't logged lunch by 2 PM
      if (now.hour >= 14 && !_hasLoggedMeal(lastMealLog, 'lunch', now)) {
        await _createMealReminderNotification(
          userId, 
          'lunch', 
          'Lunch Time! 🥗',
          "Time to log your lunch and stay on track with your health goals."
        );
      }
      
      // Check if user hasn't logged dinner by 8 PM
      if (now.hour >= 20 && !_hasLoggedMeal(lastMealLog, 'dinner', now)) {
        await _createMealReminderNotification(
          userId, 
          'dinner', 
          'Dinner Time! 🍽️',
          "Complete your day by logging your dinner and see your progress."
        );
      }
      
    } catch (e) {
      debugPrint('Error checking meal logging reminders: $e');
    }
  }

  // Check for onboarding completion
  Future<void> checkOnboardingStatus(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get user data
      final user = await _mongoDBService.usersCollection.findOne({
        '_id': ObjectIdHelper.parseObjectId(userId)
      });
      
      if (user == null) return;
      
      // Check if profile is incomplete
      if (_isProfileIncomplete(user)) {
        await _createOnboardingNotification(
          userId,
          'Complete Your Health Profile 📋',
          "Complete your health profile to get personalized recommendations and unlock all features!",
          'profile_completion'
        );
      }
      
      // Check if pantry is empty
      if (await _isPantryEmpty(userId)) {
        await _createOnboardingNotification(
          userId,
          'Add Items to Your Pantry 🥘',
          "Add items to your pantry to unlock smart recipe suggestions and meal planning!",
          'pantry_setup'
        );
      }
      
      // Check if health goals are not set
      if (_areHealthGoalsNotSet(user)) {
        await _createOnboardingNotification(
          userId,
          'Set Your Health Goals 🎯',
          "Set your health goals to start tracking your progress and get personalized recommendations!",
          'goal_setting'
        );
      }
      
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
    }
  }

  // Check for re-engagement (user hasn't used app in 3+ days)
  Future<void> checkReengagement(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final user = await _mongoDBService.usersCollection.findOne({
        '_id': ObjectIdHelper.parseObjectId(userId)
      });
      
      if (user == null) return;
      
      final lastLogin = user['lastLoginAt'] != null 
          ? DateTime.parse(user['lastLoginAt'])
          : user['createdAt'] != null 
              ? DateTime.parse(user['createdAt'])
              : DateTime.now();
      
      final daysSinceLastLogin = DateTime.now().difference(lastLogin).inDays;
      
      if (daysSinceLastLogin >= 3) {
        await _createReengagementNotification(userId, daysSinceLastLogin);
      }
      
    } catch (e) {
      debugPrint('Error checking re-engagement: $e');
    }
  }

  // Check for pantry expiration alerts
  Future<void> checkPantryExpirationAlerts(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));
      
      // Get expiring items
      final expiringItems = await _mongoDBService.pantryCollection.find({
        'userId': userId,
        'expiryDate': {
          '\$lte': threeDaysFromNow.toIso8601String(),
          '\$gte': now.toIso8601String()
        }
      }).toList();
      
      for (final item in expiringItems) {
        final expiryDate = DateTime.parse(item['expiryDate']);
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        
        String priority = 'medium';
        String urgency = '';
        
        if (daysUntilExpiry <= 1) {
          priority = 'urgent';
          urgency = '⚠️ ';
        } else if (daysUntilExpiry <= 2) {
          priority = 'high';
          urgency = '🔔 ';
        }
        
        await _createPantryExpiryNotification(
          userId,
          item['name'],
          daysUntilExpiry,
          priority,
          urgency,
          item['_id'].toString()
        );
      }
      
    } catch (e) {
      debugPrint('Error checking pantry expiration alerts: $e');
    }
  }

  // Check for low stock alerts
  Future<void> checkLowStockAlerts(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get pantry items grouped by category
      final pantryItems = await _mongoDBService.pantryCollection.find({
        'userId': userId
      }).toList();
      
      final categoryCounts = <String, int>{};
      for (final item in pantryItems) {
        final category = item['category'] ?? 'other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      
      // Check for low stock categories
      final lowStockCategories = <String>[];
      for (final entry in categoryCounts.entries) {
        if (entry.value <= 2) { // Consider low if 2 or fewer items
          lowStockCategories.add(entry.key);
        }
      }
      
      if (lowStockCategories.isNotEmpty) {
        await _createLowStockNotification(userId, lowStockCategories);
      }
      
    } catch (e) {
      debugPrint('Error checking low stock alerts: $e');
    }
  }

  // Helper methods
  Future<Map<String, dynamic>?> _getLastMealLog(String userId) async {
    // This would integrate with your meal logging system
    // For now, return null as placeholder
    return null;
  }

  bool _hasLoggedMeal(Map<String, dynamic>? lastMealLog, String mealType, DateTime now) {
    // This would check if user has logged the specific meal today
    // For now, return false as placeholder
    return false;
  }

  bool _isProfileIncomplete(Map<String, dynamic> user) {
    return user['age'] == null || 
           user['gender'] == null || 
           user['medicalConditions'] == null ||
           (user['medicalConditions'] as List).isEmpty;
  }

  Future<bool> _isPantryEmpty(String userId) async {
    final pantryItems = await _mongoDBService.pantryCollection.find({
      'userId': userId
    }).toList();
    return pantryItems.isEmpty;
  }

  bool _areHealthGoalsNotSet(Map<String, dynamic> user) {
    return user['healthGoals'] == null || 
           (user['healthGoals'] as List).isEmpty;
  }

  // Notification creation methods
  Future<void> _createMealReminderNotification(
    String userId, 
    String mealType, 
    String title, 
    String message
  ) async {
    await _createNotification(
      userId: userId,
      type: NotificationType.system,
      category: NotificationCategory.mealReminder,
      title: title,
      message: message,
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'meal_logging',
        'meal': mealType,
      },
    );
  }

  Future<void> _createOnboardingNotification(
    String userId, 
    String title, 
    String message, 
    String actionType
  ) async {
    await _createNotification(
      userId: userId,
      type: NotificationType.system,
      category: NotificationCategory.onboarding,
      title: title,
      message: message,
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'onboarding',
        'action': actionType,
      },
    );
  }

  Future<void> _createReengagementNotification(String userId, int daysSinceLastLogin) async {
    String title;
    String message;
    
    if (daysSinceLastLogin >= 7) {
      title = "We Miss You! 💙";
      message = "It's been a week since you last used Food Rx. Let's get back on track with your health goals!";
    } else {
      title = "Don't Break Your Streak! 🔥";
      message = "It's been $daysSinceLastLogin days since you last tracked your meals. Let's get back on track today!";
    }
    
    await _createNotification(
      userId: userId,
      type: NotificationType.system,
      category: NotificationCategory.reengagement,
      title: title,
      message: message,
      priority: NotificationPriority.high,
      actionRequired: true,
      actionData: {
        'type': 'reengagement',
        'days_since_last_login': daysSinceLastLogin,
      },
    );
  }

  Future<void> _createPantryExpiryNotification(
    String userId,
    String itemName,
    int daysUntilExpiry,
    String priority,
    String urgency,
    String itemId
  ) async {
    await _createNotification(
      userId: userId,
      type: NotificationType.pantryExpiry,
      category: NotificationCategory.expiryAlert,
      title: '$urgency$itemName Expires Soon!',
      message: 'Your $itemName expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}. Consider using it in a recipe today!',
      priority: NotificationPriority.values.firstWhere(
        (p) => p.toString().split('.').last == priority,
        orElse: () => NotificationPriority.medium,
      ),
      actionRequired: true,
      actionData: {
        'type': 'pantry_item',
        'itemId': itemId,
        'itemName': itemName,
        'daysUntilExpiry': daysUntilExpiry,
      },
    );
  }

  Future<void> _createLowStockNotification(String userId, List<String> lowStockCategories) async {
    final categoryNames = lowStockCategories.map((cat) => _getCategoryDisplayName(cat)).join(', ');
    
    await _createNotification(
      userId: userId,
      type: NotificationType.pantryExpiry,
      category: NotificationCategory.lowStock,
      title: 'Low Stock Alert 📦',
      message: 'You\'re running low on $categoryNames. Consider restocking during your next pantry visit!',
      priority: NotificationPriority.low,
      actionRequired: true,
      actionData: {
        'type': 'low_stock',
        'categories': lowStockCategories,
      },
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category.toLowerCase()) {
      case 'fresh_fruits':
        return 'fresh fruits';
      case 'fresh_veggies':
        return 'fresh vegetables';
      case 'canned_fruits':
        return 'canned fruits';
      case 'canned_veggies':
        return 'canned vegetables';
      case 'grains':
        return 'grains';
      case 'protein':
        return 'protein';
      case 'dairy':
        return 'dairy';
      case 'seasonings':
        return 'seasonings';
      case 'oils':
        return 'oils';
      case 'baking':
        return 'baking supplies';
      case 'condiments':
        return 'condiments';
      case 'beverages':
        return 'beverages';
      default:
        return category;
    }
  }

  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required NotificationCategory category,
    required String title,
    required String message,
    required NotificationPriority priority,
    bool actionRequired = false,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? personalizationData,
  }) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      final notification = AppNotification(
        userId: userId,
        type: type,
        category: category,
        title: title,
        message: message,
        priority: priority,
        scheduledFor: DateTime.now(),
        actionRequired: actionRequired,
        actionData: actionData,
        personalizationData: personalizationData,
      );

      await collection.insertOne({
        '_id': ObjectIdHelper.parseObjectId(notification.id),
        ...notification.toJson(),
      });

      // Refresh the notification manager
      await _notificationManager.loadNotifications();
      
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }
}
