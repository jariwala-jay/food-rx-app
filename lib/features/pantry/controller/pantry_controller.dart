import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
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

  // Reference to AuthProvider
  AuthController? _authProvider;

  PantryController(
    this._mongoDBService, {
    required UnitConversionService conversionService,
    required IngredientSubstitutionService ingredientSubstitutionService,
  })  : _unitConversionService = conversionService,
        _ingredientSubstitutionService = ingredientSubstitutionService;

  // Getters
  List<PantryItem> get pantryItems => _pantryItems;
  List<PantryItem> get otherItems => _otherItems;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasPantryItems => _pantryItems.isNotEmpty;
  bool get hasOtherItems => _otherItems.isNotEmpty;

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
    final userId = _authProvider?.currentUser?.id;
    if (userId == null) {
      _pantryItems.clear();
      _otherItems.clear();
      _error = "User not logged in";
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      final allItemMaps = await _mongoDBService.getPantryItems(userId);

      // Convert maps to PantryItem objects
      final allItems =
          allItemMaps.map((map) => PantryItem.fromMap(map)).toList();

      // IMPORTANT: Clear the lists before adding new items
      _pantryItems.clear();
      _otherItems.clear();

      for (var item in allItems) {
        if (item.isPantryItem) {
          _pantryItems.add(item);
        } else {
          _otherItems.add(item);
        }
      }

      // Sort items alphabetically
      _pantryItems.sort((a, b) => a.name.compareTo(b.name));
      _otherItems.sort((a, b) => a.name.compareTo(b.name));

      _error = null;
    } catch (e) {
      _setError('Failed to load items: $e');
    } finally {
      _setLoading(false);
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
      } else {
        _otherItems = [..._otherItems, newItem];
      }

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to add item: $e');
    }
  }

  // Remove a pantry item
  Future<void> removeItem(String itemId) async {
    _setLoading(true);
    try {
      await _mongoDBService.deletePantryItem(itemId);
      _pantryItems.removeWhere((item) => item.id == itemId);
      _otherItems.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to remove item: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update a pantry item
  Future<void> updateItem(PantryItem item) async {
    _setLoading(true);
    try {
      await _mongoDBService.updatePantryItem(item);
      // await loadItems(); // This is inefficient, let's update locally

      // Find and update in the correct list
      int pantryIndex = _pantryItems.indexWhere((i) => i.id == item.id);
      if (pantryIndex != -1) {
        _pantryItems[pantryIndex] = item;
      } else {
        int otherIndex = _otherItems.indexWhere((i) => i.id == item.id);
        if (otherIndex != -1) {
          _otherItems[otherIndex] = item;
        }
      }

      notifyListeners();
    } catch (e) {
      _setError('Failed to update item: $e');
      // Optionally reload to revert optimistic update on failure
      await loadItems();
    } finally {
      _setLoading(false);
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

  /// Force a UI refresh - useful when external services update pantry
  void forceUIRefresh() {
    notifyListeners();
  }

  Future<void> deductIngredientsForRecipe(Recipe recipe,
      {int servingsToDeduct = 1}) async {
    _setLoading(true);

    try {
      // Calculate the multiplier based on servings
      final servingMultiplier = servingsToDeduct / recipe.servings;

      if (kDebugMode) {
        print('🥘 Deducting ingredients for ${recipe.title}');
        print('   Recipe servings: ${recipe.servings}');
        print('   Servings to deduct: $servingsToDeduct');
        print('   Multiplier: $servingMultiplier');
      }

      bool anyItemsUpdated = false;

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
          // Calculate the actual amount needed based on servings
          final baseAmount = recipeIngredient.amount * servingMultiplier;

          final requiredAmount = await _unitConversionService.convertAsync(
            amount: baseAmount,
            fromUnit: recipeIngredient.unit,
            toUnit: pantryItemToUpdate.unitLabel,
            ingredientName: recipeIngredient.name,
          );

          final newQuantity = pantryItemToUpdate.quantity - requiredAmount;

          if (kDebugMode) {
            print(
                '   ${recipeIngredient.name}: ${recipeIngredient.amount} ${recipeIngredient.unit} * $servingMultiplier = $baseAmount ${recipeIngredient.unit}');
            print(
                '   Converting to ${pantryItemToUpdate.unitLabel}: $requiredAmount');
            print(
                '   Pantry: ${pantryItemToUpdate.quantity} -> $newQuantity ${pantryItemToUpdate.unitLabel}');
          }

          if (newQuantity <= 0) {
            await removeItem(pantryItemToUpdate.id);
            anyItemsUpdated = true;
          } else {
            await updateItem(
                pantryItemToUpdate.copyWith(quantity: newQuantity));
            anyItemsUpdated = true;
          }
        }
      }

      // Force UI refresh if any items were updated
      if (anyItemsUpdated) {
        forceUIRefresh();
        if (kDebugMode) {
          print('🔄 Forced pantry UI refresh after ingredient deduction');
        }
      }
    } catch (e) {
      _setError('Failed to deduct ingredients: $e');
    } finally {
      _setLoading(false);
    }
  }
}
