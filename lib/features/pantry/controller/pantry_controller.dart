import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';
import '../../recipes/models/recipe.dart';

class PantryController extends ChangeNotifier {
  final MongoDBService _mongoDBService;
  final UnitConversionService _unitConversionService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
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

  PantryController(
    this._mongoDBService, {
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

  // Reference to AuthProvider
  AuthController? _authProvider;

  void setAuthProvider(AuthController authProvider) {
    _authProvider = authProvider;
  }

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
      await _mongoDBService.ensureConnection();
      final pantryItemsData =
          await _mongoDBService.getPantryItems(_userId!, isPantryItem: true);
      final otherItemsData =
          await _mongoDBService.getPantryItems(_userId!, isPantryItem: false);

      _pantryItems =
          pantryItemsData.map((data) => PantryItem.fromMap(data)).toList();
      _otherItems =
          otherItemsData.map((data) => PantryItem.fromMap(data)).toList();

      // Sort main lists by expiration date - items expiring soonest first
      _pantryItems.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
      _otherItems.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

      // Apply current filters after loading
      _applyFilters();

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load pantry items: $e');
    }
  }

  // Add a new pantry item
  Future<void> addPantryItem(PantryItem item) async {
    if (_userId == null) {
      _setError('User not logged in');
      return;
    }

    _setLoading(true);

    try {
      await _mongoDBService.ensureConnection();
      final itemData = item.toMap();
      final itemId = await _mongoDBService.addPantryItem(_userId!, itemData);

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

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add item: $e');
    }
  }

  // Remove a pantry item
  Future<void> removeItem(String itemId, bool isPantryItem) async {
    _setLoading(true);

    try {
      await _mongoDBService.ensureConnection();

      // Use robust ObjectId handling to convert any ID format to proper ObjectId
      if (!ObjectIdHelper.isValidObjectId(itemId)) {
        _setError('Invalid item ID format: $itemId');
        return;
      }

      await _mongoDBService.deletePantryItem(itemId);

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

      await _mongoDBService.ensureConnection();

      // Use robust ObjectId handling
      if (!ObjectIdHelper.isValidObjectId(item.id)) {
        _setError('Invalid item ID format: ${item.id}');
        return;
      }

      await _mongoDBService.updatePantryItem(item.id, updates);

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
      await _mongoDBService.ensureConnection();
      final expiringItemsData = await _mongoDBService.getExpiringItems(_userId!,
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
            'miscellaneous',
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
