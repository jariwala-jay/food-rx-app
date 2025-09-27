import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/notification_trigger_service.dart';

class PantryNotificationService {
  final MongoDBService _mongoDBService = MongoDBService();
  final NotificationTriggerService _triggerService = NotificationTriggerService();

  /// Check for expiring items and create notifications
  Future<void> checkExpiringItems(String userId) async {
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
      
      for (final itemData in expiringItems) {
        final item = PantryItem.fromMap(itemData);
        final daysUntilExpiry = item.expirationDate.difference(now).inDays;
        
        await _createExpiryNotification(userId, item, daysUntilExpiry);
      }
      
    } catch (e) {
      debugPrint('Error checking expiring items: $e');
    }
  }

  /// Check for low stock categories
  Future<void> checkLowStock(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      // Get pantry items grouped by category
      final pantryItems = await _mongoDBService.pantryCollection.find({
        'userId': userId
      }).toList();
      
      final categoryCounts = <String, int>{};
      for (final itemData in pantryItems) {
        final item = PantryItem.fromMap(itemData);
        final category = item.category;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      
      // Check for low stock categories (2 or fewer items)
      final lowStockCategories = <String>[];
      for (final entry in categoryCounts.entries) {
        if (entry.value <= 2) {
          lowStockCategories.add(entry.key);
        }
      }
      
      if (lowStockCategories.isNotEmpty) {
        await _createLowStockNotification(userId, lowStockCategories);
      }
      
    } catch (e) {
      debugPrint('Error checking low stock: $e');
    }
  }

  /// Suggest recipes based on expiring items
  Future<void> suggestRecipesForExpiringItems(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final now = DateTime.now();
      final twoDaysFromNow = now.add(const Duration(days: 2));
      
      // Get items expiring in the next 2 days
      final expiringItems = await _mongoDBService.pantryCollection.find({
        'userId': userId,
        'expiryDate': {
          '\$lte': twoDaysFromNow.toIso8601String(),
          '\$gte': now.toIso8601String()
        }
      }).toList();
      
      if (expiringItems.isNotEmpty) {
        final itemNames = expiringItems.map((item) => item['name'] as String).toList();
        await _createRecipeSuggestionNotification(userId, itemNames);
      }
      
    } catch (e) {
      debugPrint('Error suggesting recipes for expiring items: $e');
    }
  }

  /// Create notification when items are added to pantry
  Future<void> onItemsAdded(String userId, List<PantryItem> addedItems) async {
    try {
      // Check if any of the added items are expiring soon
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));
      
      final expiringSoon = addedItems.where((item) => 
          item.expirationDate.isBefore(threeDaysFromNow)).toList();
      
      if (expiringSoon.isNotEmpty) {
        final itemNames = expiringSoon.map((item) => item.name).toList();
        await _createExpiringSoonNotification(userId, itemNames);
      }
      
      // Check if this completes any low stock categories
      await checkLowStock(userId);
      
    } catch (e) {
      debugPrint('Error handling items added: $e');
    }
  }

  /// Create notification when items are removed from pantry
  Future<void> onItemsRemoved(String userId, List<String> removedItemIds) async {
    try {
      // Check if removal causes low stock
      await checkLowStock(userId);
      
    } catch (e) {
      debugPrint('Error handling items removed: $e');
    }
  }

  /// Create notification when items are updated
  Future<void> onItemsUpdated(String userId, List<PantryItem> updatedItems) async {
    try {
      // Check for expiration changes
      for (final item in updatedItems) {
        final now = DateTime.now();
        final threeDaysFromNow = now.add(const Duration(days: 3));
        
        if (item.expirationDate.isBefore(threeDaysFromNow)) {
          final daysUntilExpiry = item.expirationDate.difference(now).inDays;
          await _createExpiryNotification(userId, item, daysUntilExpiry);
        }
      }
      
    } catch (e) {
      debugPrint('Error handling items updated: $e');
    }
  }

  // Private helper methods for creating notifications
  Future<void> _createExpiryNotification(String userId, PantryItem item, int daysUntilExpiry) async {
    String priority = 'medium';
    String urgency = '';
    
    if (daysUntilExpiry <= 1) {
      priority = 'urgent';
      urgency = '⚠️ ';
    } else if (daysUntilExpiry <= 2) {
      priority = 'high';
      urgency = '🔔 ';
    }
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.pantryExpiry,
      category: NotificationCategory.expiryAlert,
      title: '$urgency${item.name} Expires Soon!',
      message: 'Your ${item.name} expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}. Consider using it in a recipe today!',
      priority: NotificationPriority.values.firstWhere(
        (p) => p.toString().split('.').last == priority,
        orElse: () => NotificationPriority.medium,
      ),
      actionRequired: true,
      actionData: {
        'type': 'pantry_item',
        'itemId': item.id,
        'itemName': item.name,
        'daysUntilExpiry': daysUntilExpiry,
      },
    );
  }

  Future<void> _createLowStockNotification(String userId, List<String> lowStockCategories) async {
    final categoryNames = lowStockCategories.map((cat) => _getCategoryDisplayName(cat)).join(', ');
    
    await _triggerService.createNotification(
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

  Future<void> _createRecipeSuggestionNotification(String userId, List<String> itemNames) async {
    final itemList = itemNames.length > 3 
        ? '${itemNames.take(3).join(', ')} and ${itemNames.length - 3} more'
        : itemNames.join(', ');
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.pantryExpiry,
      category: NotificationCategory.recipeSuggestion,
      title: 'Recipe Ideas for Expiring Items 🍳',
      message: 'Your $itemList are expiring soon. Check out these recipe suggestions to use them up!',
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'recipe_suggestion',
        'expiringItems': itemNames,
      },
    );
  }

  Future<void> _createExpiringSoonNotification(String userId, List<String> itemNames) async {
    final itemList = itemNames.length > 2 
        ? '${itemNames.take(2).join(', ')} and ${itemNames.length - 2} more'
        : itemNames.join(', ');
    
    await _triggerService.createNotification(
      userId: userId,
      type: NotificationType.pantryExpiry,
      category: NotificationCategory.expiryAlert,
      title: 'Items Added - Expiring Soon! ⏰',
      message: 'You added $itemList to your pantry, but they expire soon. Consider using them first!',
      priority: NotificationPriority.medium,
      actionRequired: true,
      actionData: {
        'type': 'expiring_soon',
        'itemNames': itemNames,
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

  /// Get expiring items for a specific user
  Future<List<PantryItem>> getExpiringItems(String userId, {int daysAhead = 3}) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: daysAhead));
      
      final expiringItems = await _mongoDBService.pantryCollection.find({
        'userId': userId,
        'expiryDate': {
          '\$lte': futureDate.toIso8601String(),
          '\$gte': now.toIso8601String()
        }
      }).toList();
      
      return expiringItems.map((itemData) => PantryItem.fromMap(itemData)).toList();
    } catch (e) {
      debugPrint('Error getting expiring items: $e');
      return [];
    }
  }

  /// Get low stock categories for a specific user
  Future<List<String>> getLowStockCategories(String userId, {int threshold = 2}) async {
    try {
      await _mongoDBService.ensureConnection();
      
      final pantryItems = await _mongoDBService.pantryCollection.find({
        'userId': userId
      }).toList();
      
      final categoryCounts = <String, int>{};
      for (final itemData in pantryItems) {
        final item = PantryItem.fromMap(itemData);
        final category = item.category;
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }
      
      return categoryCounts.entries
          .where((entry) => entry.value <= threshold)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      debugPrint('Error getting low stock categories: $e');
      return [];
    }
  }
}
