import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';
import '../../recipes/models/recipe.dart';

/// Enhanced Pantry Controller with FIFO deduction and recipe scaling integration
/// Implements PRD requirements for accurate pantry management
class EnhancedPantryController extends ChangeNotifier {
  final MongoDBService _mongoDBService;
  final UnitConversionService _unitConversionService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
  final PantryDeductionService _pantryDeductionService;
  final RecipeScalingService _recipeScalingService;
  
  List<PantryItem> _pantryItems = [];
  List<PantryItem> _otherItems = [];
  bool _isLoading = false;
  String? _error;
  String? _userId;

  // Reference to AuthProvider
  AuthController? _authProvider;

  EnhancedPantryController(
    this._mongoDBService, {
    required UnitConversionService conversionService,
    required IngredientSubstitutionService ingredientSubstitutionService,
    required PantryDeductionService pantryDeductionService,
    required RecipeScalingService recipeScalingService,
  })  : _unitConversionService = conversionService,
        _ingredientSubstitutionService = ingredientSubstitutionService,
        _pantryDeductionService = pantryDeductionService,
        _recipeScalingService = recipeScalingService;

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

  /// Enhanced recipe deduction with scaling and FIFO logic
  /// Implements PRD requirements for accurate pantry management
  Future<EnhancedDeductionResult> deductScaledRecipeFromPantry({
    required Recipe recipe,
    required int targetServings,
  }) async {
    if (_userId == null) {
      return EnhancedDeductionResult(
        success: false,
        error: 'User not logged in',
        scalingResult: null,
        deductionResult: null,
        updatedPantryItems: [],
        removedPantryItems: [],
      );
    }

    _setLoading(true);

    try {
      if (kDebugMode) {
        print('🍳 Starting enhanced recipe deduction for ${recipe.title}');
        print('   Target servings: $targetServings (original: ${recipe.servings})');
      }

      // Step 1: Scale the recipe to target servings
      final scalingResult = await _recipeScalingService.scaleRecipe(
        recipe: recipe,
        targetServings: targetServings,
      );

      if (!scalingResult.success) {
        _setError('Failed to scale recipe: ${scalingResult.error}');
        return EnhancedDeductionResult(
          success: false,
          error: 'Recipe scaling failed: ${scalingResult.error}',
          scalingResult: scalingResult,
          deductionResult: null,
          updatedPantryItems: [],
          removedPantryItems: [],
        );
      }

      if (kDebugMode) {
        print('✅ Recipe scaled successfully with ${(scalingResult.averageConfidence * 100).toStringAsFixed(1)}% confidence');
      }

      // Step 2: Validate pantry has sufficient ingredients
      final allPantryItems = [..._pantryItems, ..._otherItems];
      final validationResult = await _pantryDeductionService.validatePantryForRecipe(
        scaledIngredients: scalingResult.scaledIngredients,
        pantryItems: allPantryItems,
      );

      if (!validationResult.allIngredientsAvailable) {
        final missingIngredients = validationResult.ingredientValidations
            .where((v) => !v.isAvailable)
            .map((v) => v.ingredientName)
            .toList();
        
        _setError('Missing ingredients: ${missingIngredients.join(', ')}');
        return EnhancedDeductionResult(
          success: false,
          error: 'Insufficient ingredients: ${missingIngredients.join(', ')}',
          scalingResult: scalingResult,
          deductionResult: null,
          updatedPantryItems: [],
          removedPantryItems: [],
          validationResult: validationResult,
        );
      }

      if (kDebugMode) {
        print('✅ Pantry validation passed: ${(validationResult.availabilityPercentage * 100).toStringAsFixed(1)}% available');
      }

      // Step 3: Perform FIFO deduction
      final deductionResult = await _pantryDeductionService.deductIngredientsFromPantry(
        scaledIngredients: scalingResult.scaledIngredients,
        pantryItems: allPantryItems,
      );

      if (!deductionResult.wasSuccessful) {
        _setError('Deduction failed: ${deductionResult.successRate * 100}% success rate');
        return EnhancedDeductionResult(
          success: false,
          error: 'Pantry deduction incomplete',
          scalingResult: scalingResult,
          deductionResult: deductionResult,
          updatedPantryItems: [],
          removedPantryItems: [],
          validationResult: validationResult,
        );
      }

      if (kDebugMode) {
        print('✅ FIFO deduction completed: ${deductionResult.successfulDeductions}/${deductionResult.totalIngredientsProcessed} ingredients');
        print('   Average confidence: ${(deductionResult.averageConfidence * 100).toStringAsFixed(1)}%');
      }

      // Step 4: Apply changes to database and local state
      await _applyDeductionChanges(deductionResult);

      final result = EnhancedDeductionResult(
        success: true,
        error: null,
        scalingResult: scalingResult,
        deductionResult: deductionResult,
        updatedPantryItems: deductionResult.updatedItems,
        removedPantryItems: deductionResult.itemsToRemove,
        validationResult: validationResult,
      );

      _setLoading(false);
      return result;

    } catch (e) {
      _setError('Enhanced deduction failed: $e');
      return EnhancedDeductionResult(
        success: false,
        error: 'Unexpected error: $e',
        scalingResult: null,
        deductionResult: null,
        updatedPantryItems: [],
        removedPantryItems: [],
      );
    }
  }

  /// Validates if pantry has sufficient ingredients for a scaled recipe
  Future<PantryValidationResult> validateRecipeAvailability({
    required Recipe recipe,
    required int targetServings,
  }) async {
    try {
      // Scale the recipe
      final scalingResult = await _recipeScalingService.scaleRecipe(
        recipe: recipe,
        targetServings: targetServings,
      );

      if (!scalingResult.success) {
        throw Exception('Recipe scaling failed: ${scalingResult.error}');
      }

      // Validate pantry
      final allPantryItems = [..._pantryItems, ..._otherItems];
      return await _pantryDeductionService.validatePantryForRecipe(
        scaledIngredients: scalingResult.scaledIngredients,
        pantryItems: allPantryItems,
      );
    } catch (e) {
      throw Exception('Validation failed: $e');
    }
  }

  /// Applies deduction changes to database and updates local state
  Future<void> _applyDeductionChanges(PantryDeductionResult deductionResult) async {
    await _mongoDBService.ensureConnection();

    // Update quantities for modified items
    for (final updatedItem in deductionResult.updatedItems) {
      await _mongoDBService.updatePantryItem(updatedItem.id, updatedItem.toMap());
      
      // Update local state
      if (updatedItem.isPantryItem) {
        _pantryItems = _pantryItems.map((item) => 
          item.id == updatedItem.id ? updatedItem : item
        ).toList();
      } else {
        _otherItems = _otherItems.map((item) => 
          item.id == updatedItem.id ? updatedItem : item
        ).toList();
      }
    }

    // Remove depleted items
    for (final itemId in deductionResult.itemsToRemove) {
      await _mongoDBService.deletePantryItem(itemId);
      
      // Update local state
      _pantryItems = _pantryItems.where((item) => item.id != itemId).toList();
      _otherItems = _otherItems.where((item) => item.id != itemId).toList();
    }

    notifyListeners();
  }

  /// Legacy method for backward compatibility
  /// Now uses enhanced deduction with FIFO logic
  Future<void> deductIngredientsForRecipe(Recipe recipe) async {
    final result = await deductScaledRecipeFromPantry(
      recipe: recipe,
      targetServings: recipe.servings,
    );

    if (!result.success) {
      _setError(result.error ?? 'Deduction failed');
    }
  }

  /// Get pantry statistics for analytics
  Map<String, dynamic> getPantryStatistics() {
    final allItems = [..._pantryItems, ..._otherItems];
    final expiringItems = allItems.where((item) => 
      item.expirationDate.difference(DateTime.now()).inDays <= 7
    ).toList();

    return {
      'totalItems': allItems.length,
      'pantryItems': _pantryItems.length,
      'otherItems': _otherItems.length,
      'expiringItems': expiringItems.length,
      'categories': _getCategoryBreakdown(),
      'averageExpiryDays': _getAverageExpiryDays(),
    };
  }

  Map<String, int> _getCategoryBreakdown() {
    final allItems = [..._pantryItems, ..._otherItems];
    final breakdown = <String, int>{};
    
    for (final item in allItems) {
      breakdown[item.category] = (breakdown[item.category] ?? 0) + 1;
    }
    
    return breakdown;
  }

  double _getAverageExpiryDays() {
    final allItems = [..._pantryItems, ..._otherItems];
    if (allItems.isEmpty) return 0.0;
    
    final totalDays = allItems.fold<int>(0, (sum, item) => 
      sum + item.expirationDate.difference(DateTime.now()).inDays
    );
    
    return totalDays / allItems.length;
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
}

/// Result of enhanced recipe deduction with scaling and FIFO logic
class EnhancedDeductionResult {
  final bool success;
  final String? error;
  final RecipeScalingResult? scalingResult;
  final PantryDeductionResult? deductionResult;
  final List<PantryItem> updatedPantryItems;
  final List<String> removedPantryItems;
  final PantryValidationResult? validationResult;

  EnhancedDeductionResult({
    required this.success,
    required this.error,
    required this.scalingResult,
    required this.deductionResult,
    required this.updatedPantryItems,
    required this.removedPantryItems,
    this.validationResult,
  });

  /// Overall confidence combining scaling and deduction confidence
  double get overallConfidence {
    if (scalingResult == null || deductionResult == null) return 0.0;
    
    return (scalingResult!.averageConfidence + deductionResult!.averageConfidence) / 2.0;
  }

  /// PRD compliance check: ≥95% confidence, ≤5% variance
  bool get isPRDCompliant {
    return overallConfidence >= 0.95 && success;
  }

  /// Summary for logging and analytics
  Map<String, dynamic> get summary {
    return {
      'success': success,
      'error': error,
      'overallConfidence': overallConfidence,
      'isPRDCompliant': isPRDCompliant,
      'scalingStats': scalingResult?.toMap(),
      'deductionStats': {
        'totalIngredients': deductionResult?.totalIngredientsProcessed ?? 0,
        'successfulDeductions': deductionResult?.successfulDeductions ?? 0,
        'averageConfidence': deductionResult?.averageConfidence ?? 0.0,
        'itemsUpdated': updatedPantryItems.length,
        'itemsRemoved': removedPantryItems.length,
      },
      'validationStats': validationResult != null ? {
        'allAvailable': validationResult!.allIngredientsAvailable,
        'availabilityPercentage': validationResult!.availabilityPercentage,
        'averageConfidence': validationResult!.averageConfidence,
      } : null,
    };
  }
} 