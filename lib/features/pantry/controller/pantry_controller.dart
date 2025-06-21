import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/pantry_item.dart';
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

      _pantryItems = _convertLegacyItemsToPantryItems(pantryItemsData, true);
      _otherItems = _convertLegacyItemsToPantryItems(otherItemsData, false);

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load pantry items: $e');
    }
  }

  // Convert legacy item data to the new PantryItem format
  List<PantryItem> _convertLegacyItemsToPantryItems(
      List<Map<String, dynamic>> itemsData, bool isPantryItems) {
    return itemsData.map((data) {
      final double quantity =
          double.tryParse(data['quantity']?.toString() ?? '1') ?? 1.0;
      final UnitType unit = _parseUnitType(data['unit']);

      // Helper function to parse IDs that might be in "ObjectId(...)" format
      String parseItemId(dynamic id) {
        if (id == null) return '';

        String idStr = id.toString();
        if (idStr.startsWith('ObjectId("') && idStr.endsWith('")')) {
          // Extract the hexadecimal ID from ObjectId("hexString")
          return idStr.substring(9, idStr.length - 2);
        }
        return idStr;
      }

      // Get the item ID, handling ObjectId format if present
      String itemId = '';
      if (data['_id'] != null) {
        itemId = parseItemId(data['_id']);
      } else if (data['id'] != null) {
        itemId = parseItemId(data['id']);
      }

      return PantryItem(
        id: itemId,
        name: data['name'] ?? '',
        imageUrl: data['imageUrl'] ??
            'https://spoonacular.com/cdn/ingredients_100x100/no-image.jpg',
        category: data['category'] ?? '',
        quantity: quantity,
        unit: unit,
        expirationDate: data['expiryDate'] != null
            ? DateTime.parse(data['expiryDate'])
            : DateTime.now().add(const Duration(days: 7)),
        addedDate: data['addedDate'] != null
            ? DateTime.parse(data['addedDate'])
            : DateTime.now(),
        isSelected: false,
        isPantryItem: isPantryItems, // Ensure correct isPantryItem value
      );
    }).toList();
  }

  // Helper to parse unit types from string
  UnitType _parseUnitType(String? unitStr) {
    if (unitStr == null) return UnitType.piece;

    switch (unitStr.toLowerCase()) {
      case 'lb':
        return UnitType.pound;
      case 'oz':
        return UnitType.ounces;
      case 'gal':
        return UnitType.gallon;
      case 'ml':
        return UnitType.milliliter;
      case 'l':
        return UnitType.liter;
      case 'pc':
      case 'piece':
      case 'pieces':
        return UnitType.piece;
      case 'g':
        return UnitType.grams;
      case 'kg':
        return UnitType.kilograms;
      case 'cup':
      case 'cups':
        return UnitType.cup;
      case 'tbsp':
        return UnitType.tablespoon;
      case 'tsp':
        return UnitType.teaspoon;
      default:
        return UnitType.piece;
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
      final itemData = _convertPantryItemToLegacyFormat(item);
      final itemId = await _mongoDBService.addPantryItem(_userId!, itemData);

      final newItem = item.copyWith(id: itemId);
      if (itemData['isPantryItem']) {
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

  // Convert our new PantryItem to the legacy format for DB storage
  Map<String, dynamic> _convertPantryItemToLegacyFormat(PantryItem item) {
    // Use the item's actual isPantryItem value, not a hardcoded value
    return {
      'id': item.id,
      'name': item.name,
      'category': item.category,
      'quantity': item.quantity.toString(),
      'unit': item.unitLabel,
      'expiryDate': item.expirationDate.toIso8601String(),
      'addedDate': item.addedDate.toIso8601String(),
      'imageUrl': item.imageUrl,
      'isPantryItem': item.isPantryItem,
    };
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
      final updates = _convertPantryItemToLegacyFormat(item);

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
      return _convertLegacyItemsToPantryItems(expiringItemsData, true);
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
    if (_unitConversionService == null ||
        _ingredientSubstitutionService == null) {
      _setError("Services not initialized for pantry deduction.");
      return;
    }

    _setLoading(true);

    try {
      for (final recipeIngredient in recipe.extendedIngredients) {
        PantryItem? pantryItemToUpdate;
        for (final pantryItem in [..._pantryItems, ..._otherItems]) {
          final substitute = _ingredientSubstitutionService!
              .getValidSubstitute(recipeIngredient.name, pantryItem.name);
          if (substitute != null) {
            pantryItemToUpdate = pantryItem;
            break;
          }
        }

        if (pantryItemToUpdate != null) {
          final requiredAmount = _unitConversionService!.convert(
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
