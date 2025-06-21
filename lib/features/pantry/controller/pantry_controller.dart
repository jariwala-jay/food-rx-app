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
  Future<void> removeItem(String itemId, bool isPantryItem) async {
    _setLoading(true);

    try {
      await _mongoDBService.ensureConnection();

      // 🔑 Ensure itemId is a clean hex string, no quotes or wrapper
      final cleanedId = itemId.replaceAll('"', '').trim();

      await _mongoDBService.deletePantryItem(cleanedId);

      if (isPantryItem) {
        _pantryItems = _pantryItems.where((item) => item.id != itemId).toList();
      } else {
        _otherItems = _otherItems.where((item) => item.id != itemId).toList();
      }

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

      // 🔑 Ensure itemId is a clean hex string, no quotes or wrapper
      final cleanedId = item.id.replaceAll('"', '').trim();

      await _mongoDBService.updatePantryItem(cleanedId, updates);

      if (item.isPantryItem) {
        _pantryItems =
            _pantryItems.map((i) => i.id == item.id ? item : i).toList();
      } else {
        _otherItems =
            _otherItems.map((i) => i.id == item.id ? item : i).toList();
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
