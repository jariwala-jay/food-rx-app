import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/pantry_api_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/simple_notification_service.dart';
import '../../recipes/models/recipe.dart';

class PantryController extends ChangeNotifier {
  final PantryApiService _pantryApi = PantryApiService();
  final UnitConversionService _unitConversionService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
  final SimpleNotificationService _notificationService =
      SimpleNotificationService();
  List<PantryItem> _pantryItems = [];
  List<PantryItem> _otherItems = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  // Search and filtering state
  String _searchQuery = '';
  String? _selectedCategory;
  List<PantryItem> _filteredPantryItems = [];
  List<PantryItem> _filteredOtherItems = [];

  PantryController({
    required UnitConversionService conversionService,
    required IngredientSubstitutionService ingredientSubstitutionService,
  })  : _unitConversionService = conversionService,
        _ingredientSubstitutionService = ingredientSubstitutionService;

  // Getters
  List<PantryItem> get pantryItems => _pantryItems;
  List<PantryItem> get otherItems => _otherItems;
  List<PantryItem> get filteredPantryItems => _filteredPantryItems;
  List<PantryItem> get filteredOtherItems => _filteredOtherItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPantryItems => _pantryItems.isNotEmpty;
  bool get hasOtherItems => _otherItems.isNotEmpty;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  // Initialize with the user's ID
  void initializeWithUser(String userId) {
    if (_userId == userId) return; // Avoid re-initialization
    _userId = userId;
    loadItems();
  }

  // Load pantry items from database
  Future<void> loadItems() async {
    if (_userId == null) {
      _setError('User not logged in');
      return;
    }

    _setLoading(true);

    try {
      final pantryItemsData =
          await _pantryApi.getPantryItems(_userId!, isPantryItem: true);
      final otherItemsData =
          await _pantryApi.getPantryItems(_userId!, isPantryItem: false);

      _pantryItems = pantryItemsData;
      _otherItems = otherItemsData;

      // Sort main lists by expiration date - items expiring soonest first
      _pantryItems.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      _otherItems.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

      // Merge rows that are the same item added on the same calendar day (sum qty).
      try {
        await _mergeDuplicatePantryRowsInDatabase(isPantryItem: true);
        await _mergeDuplicatePantryRowsInDatabase(isPantryItem: false);
      } catch (e) {
        debugPrint('Pantry duplicate merge skipped/failed: $e');
      }

      // Apply current filters after loading
      _applyFilters();

      // If user has expired pantry items, ensure we have an expired_items
      // digest notification for today.
      await _notificationService.checkExpiredItems(_userId!);

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load pantry items: $e');
    }
  }

  // Public method to refresh items (can be called from other parts of the app)
  Future<void> refreshItems() async {
    await loadItems();
  }

  // Add a new pantry item
  Future<void> addPantryItem(PantryItem item) async {
    if (_userId == null) {
      _setError('User not logged in');
      return;
    }

    _setLoading(true);

    try {
      // If the same ingredient was already added today (same category + unit), merge qty.
      final duplicate = _findSameDayDuplicate(item);
      if (duplicate != null) {
        final earliestExpiry = duplicate.expirationDate.isBefore(item.expirationDate)
            ? duplicate.expirationDate
            : item.expirationDate;
        final merged = duplicate.copyWith(
          quantity: duplicate.quantity + item.quantity,
          expirationDate: earliestExpiry,
        );
        await updateItem(merged);
        return;
      }

      final itemData = item.toMap();
      final itemId = await _pantryApi.addPantryItem(_userId!, itemData);

      final newItem = item.copyWith(id: itemId);
      if (item.isPantryItem) {
        _pantryItems = [..._pantryItems, newItem];
        _pantryItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      } else {
        _otherItems = [..._otherItems, newItem];
        _otherItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      }

      // Apply filters after adding new item
      _applyFilters();

      // Check if item expires within 3 days and notify
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));
      if (newItem.expirationDate.isBefore(threeDaysFromNow) &&
          newItem.expirationDate.isAfter(now)) {
        await _notificationService.checkExpiringIngredients(_userId!);
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add item: $e');
    }
  }

  // Clear items added during tour (apples from fresh_fruits category added recently)
  Future<void> clearTourItems() async {
    if (_userId == null) return;

    try {
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      // Find tour items (apples from fresh_fruits added in last hour)
      final tourItems = _pantryItems.where((item) {
        final isApple = item.name.toLowerCase().contains('apple') &&
            !item.name.toLowerCase().contains('applesauce');
        final isFreshFruits = item.category == 'fresh_fruits';
        final wasAddedRecently = item.addedDate.isAfter(oneHourAgo);
        return isApple && isFreshFruits && wasAddedRecently;
      }).toList();

      // Remove each tour item
      for (final item in tourItems) {
        await _pantryApi.deletePantryItem(item.id);
      }

      // Reload items to reflect changes
      if (tourItems.isNotEmpty) {
        await loadItems();
      }
    } catch (e) {
      print('Error clearing tour items: $e');
    }
  }

  // Remove a pantry item
  Future<void> removeItem(String itemId, bool isPantryItem) async {
    _setLoading(true);

    try {
      await _pantryApi.deletePantryItem(itemId);

      if (isPantryItem) {
        _pantryItems = _pantryItems.where((item) => item.id != itemId).toList();
      } else {
        _otherItems = _otherItems.where((item) => item.id != itemId).toList();
      }

      // Apply filters after removing item
      _applyFilters();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove item: $e');
    }
  }

  // Update a pantry item
  Future<void> updateItem(PantryItem item) async {
    _setLoading(true);

    try {
      final updates = item.toMap();
      await _pantryApi.updatePantryItem(item.id, updates);

      if (item.isPantryItem) {
        _pantryItems =
            _pantryItems.map((i) => i.id == item.id ? item : i).toList();
        _pantryItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      } else {
        _otherItems =
            _otherItems.map((i) => i.id == item.id ? item : i).toList();
        _otherItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      }

      // Apply filters after updating item
      _applyFilters();

      // Check if item expires within 3 days and notify
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3));
      if (item.expirationDate.isBefore(threeDaysFromNow) &&
          item.expirationDate.isAfter(now)) {
        await _notificationService.checkExpiringIngredients(_userId!);
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to update item: $e');
    }
  }

  // Get expiring items
  Future<List<PantryItem>> getExpiringItems({int daysThreshold = 7}) async {
    if (_userId == null) {
      _setError('User not logged in');
      return [];
    }

    try {
      final expiringItemsData = await _pantryApi.getExpiringItems(_userId!,
          daysThreshold: daysThreshold);
      return expiringItemsData.map((data) => PantryItem.fromMap(data)).toList();
    } catch (e) {
      _setError('Failed to get expiring items: $e');
      return [];
    }
  }

  // Search and filtering methods
  void updateSearchQuery(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
  }

  void updateSelectedCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
  }

  void _applyFilters() {
    _filteredPantryItems = _pantryItems.where((item) {
      bool matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery);
      bool matchesCategory = _selectedCategory == null ||
          item.category.toLowerCase() == _selectedCategory!.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();

    _filteredOtherItems = _otherItems.where((item) {
      bool matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery);
      bool matchesCategory = _selectedCategory == null ||
          item.category.toLowerCase() == _selectedCategory!.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();

    // Sort by expiration date - items expiring soonest first
    _filteredPantryItems
        .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
    _filteredOtherItems
        .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

    notifyListeners();
  }

  // Get available categories for filtering
  List<String> getAvailableCategories(bool isPantryItem) {
    final items = isPantryItem ? _pantryItems : _otherItems;
    final categories = items.map((item) => item.category).toSet().toList();

    // Define priority order for categories
    final priorityOrder = isPantryItem
        ? [
            'fresh_fruits',
            'fresh_veggies',
            'protein',
            'dairy',
            'grains',
            'canned_fruits',
            'canned_veggies',
            'seasonings',
          ]
        : [
            'fresh_produce',
            'protein_meat',
            'dairy_eggs',
            'pantry_staples',
            'frozen_foods',
            'snacks_beverages',
            'essentials_condiments',
          ];

    // Sort categories by priority, then alphabetically for unlisted categories
    categories.sort((a, b) {
      final aIndex = priorityOrder.indexOf(a);
      final bIndex = priorityOrder.indexOf(b);

      // If both are in priority list, sort by priority order
      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      }
      // If only one is in priority list, prioritize it
      if (aIndex != -1) return -1;
      if (bIndex != -1) return 1;
      // If neither is in priority list, sort alphabetically
      return a.compareTo(b);
    });

    return categories;
  }

  /// Same logical product row: name + category + calendar day added + unit.
  String _duplicateGroupKey(PantryItem p) {
    final d = DateTime(p.addedDate.year, p.addedDate.month, p.addedDate.day);
    return '${p.name.toLowerCase().trim()}|${p.category}|${d.year}-${d.month}-${d.day}|${p.unitLabel}';
  }

  /// Finds an existing row that should merge with [candidate] (same day add).
  PantryItem? _findSameDayDuplicate(PantryItem candidate) {
    final list = candidate.isPantryItem ? _pantryItems : _otherItems;
    final candidateKey = _duplicateGroupKey(candidate);
    for (final p in list) {
      if (_duplicateGroupKey(p) == candidateKey) {
        return p;
      }
    }
    return null;
  }

  /// Collapses existing DB duplicates (e.g. from before merge-on-add existed).
  Future<void> _mergeDuplicatePantryRowsInDatabase({
    required bool isPantryItem,
  }) async {
    if (_userId == null) return;

    final items = isPantryItem ? _pantryItems : _otherItems;
    final groups = <String, List<PantryItem>>{};
    for (final item in List<PantryItem>.from(items)) {
      groups.putIfAbsent(_duplicateGroupKey(item), () => []).add(item);
    }

    var changed = false;
    for (final list in groups.values) {
      if (list.length < 2) continue;
      changed = true;
      list.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      final keeper = list.first;
      var total = 0.0;
      DateTime earliestExpiry = list.first.expirationDate;
      for (final i in list) {
        total += i.quantity;
        if (i.expirationDate.isBefore(earliestExpiry)) {
          earliestExpiry = i.expirationDate;
        }
      }
      final merged = keeper.copyWith(
        quantity: total,
        expirationDate: earliestExpiry,
      );
      await _pantryApi.updatePantryItem(keeper.id, merged.toMap());
      for (var i = 1; i < list.length; i++) {
        await _pantryApi.deletePantryItem(list[i].id);
      }
    }

    if (changed) {
      final refreshed =
          await _pantryApi.getPantryItems(_userId!, isPantryItem: isPantryItem);
      if (isPantryItem) {
        _pantryItems = refreshed;
        _pantryItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      } else {
        _otherItems = refreshed;
        _otherItems
            .sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      }
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) {
      _error = null;
    }
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> deductIngredientsForRecipe(Recipe recipe) async {
    _setLoading(true);

    try {
      for (final recipeIngredient in recipe.extendedIngredients) {
        PantryItem? pantryItemToUpdate;
        for (final pantryItem in [..._pantryItems, ..._otherItems]) {
          final substitute = _ingredientSubstitutionService.getValidSubstitute(
              recipeIngredient.name, pantryItem.name);
          if (substitute != null) {
            pantryItemToUpdate = pantryItem;
            break;
          }
        }

        if (pantryItemToUpdate != null) {
          final requiredAmount = _unitConversionService.convert(
            amount: recipeIngredient.amount,
            fromUnit: recipeIngredient.unit,
            toUnit: pantryItemToUpdate.unit.name,
            ingredientName: recipeIngredient.name,
          );

          final newQuantity = pantryItemToUpdate.quantity - requiredAmount;

          if (newQuantity <= 0) {
            await removeItem(
                pantryItemToUpdate.id, pantryItemToUpdate.isPantryItem);
          } else {
            await updateItem(
                pantryItemToUpdate.copyWith(quantity: newQuantity));
          }
        }
      }
    } catch (e) {
      _setError('Failed to deduct ingredients: $e');
    } finally {
      _setLoading(false);
    }
  }
}
