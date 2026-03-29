import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/prepared_recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart'
    as domain_repo;
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

class RecipeController extends ChangeNotifier {
  final RecipeGenerationService recipeGenerationService;
  final domain_repo.RecipeRepository recipeRepository;
  final PantryDeductionService pantryDeductionService;
  final DietServingService dietServingService;
  final TrackerProvider trackerProvider;
  AuthController authProvider;
  PantryController pantryController;

  RecipeController({
    required this.recipeGenerationService,
    required this.recipeRepository,
    required this.pantryDeductionService,
    required this.dietServingService,
    required this.trackerProvider,
    required this.authProvider,
    required this.pantryController,
  });

  // State
  List<Recipe> _recipes = [];
  List<Recipe> _savedRecipes = [];
  List<PreparedRecipe> _preparedRecipes = [];
  RecipeFilter _currentFilter = const RecipeFilter();
  bool _isLoading = false;
  String? _error;
  bool _hasAttemptedGeneration = false;

  // Getters
  List<Recipe> get recipes => _recipes;
  List<Recipe> get savedRecipes => _savedRecipes;
  List<PreparedRecipe> get preparedRecipes => _preparedRecipes;
  RecipeFilter get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasAttemptedGeneration => _hasAttemptedGeneration;
  UserModel? get currentUser => authProvider.currentUser;
  List<PantryItem> get pantryItems => pantryController.pantryItems;

  List<String> get userMedicalConditionsDisplay {
    final conditions = currentUser?.medicalConditions ?? [];
    return conditions.map((conditionStr) {
      try {
        final conditionEnum = MedicalCondition.values.firstWhere(
          (e) => e.name.toLowerCase() == conditionStr.toLowerCase(),
        );
        return conditionEnum.displayName;
      } catch (e) {
        return conditionStr.isNotEmpty
            ? conditionStr[0].toUpperCase() + conditionStr.substring(1)
            : '';
      }
    }).toList();
  }

  void initialize() {
    // Listeners can be set up here if needed
    // e.g., _authProvider.addListener(_onAuthChanged);
    loadSavedRecipes();
  }

  Future<void> generateRecipes({RecipeFilter? filter}) async {
    _isLoading = true;
    _error = null;
    _hasAttemptedGeneration = true; // Mark that generation has been attempted
    if (filter != null) {
      _currentFilter = filter;
    }
    notifyListeners();

    try {
      final user = authProvider.currentUser;
      if (user == null) {
        _error = 'You must be logged in to generate recipes.';
        return;
      }

      await pantryController.loadItems();
      final pantryItems = pantryController.pantryItems;

      // Create comprehensive user profile for recipe filtering
      final userProfile = {
        'dietType': user.dietType,
        'medicalConditions': user.medicalConditions ?? [],
        'healthGoals': user.healthGoals,
        'allergies': user.allergies ?? [],
        'foodRestrictions': user.foodRestrictions ?? [],
        'excludedIngredients': user.excludedIngredients ?? [],
        'activityLevel': user.activityLevel,
        'age': user.age,
        'sex': user.sex,
        'targetCalories': user.targetCalories,
        'diet_rule': user.diagnostics?[
            'diet_rule'], // Include diet rule from personalization
      };

      final generatedRecipes = await recipeGenerationService.generateRecipes(
        filter: _currentFilter,
        pantryItems: pantryItems,
        userProfile: userProfile,
      );

      // Check if all recipes were filtered out during validation
      if (generatedRecipes.isEmpty) {
        _recipes = [];
        // Don't set error - let the empty state handle this case
        if (kDebugMode) {
          print(
              'All recipes were filtered out during dietary/pantry validation');
        }
      } else {
        _recipes = generatedRecipes;
      }
    } catch (e) {
      _error = userFacingErrorMessage(e);
      if (kDebugMode) {
        print('Failed to generate recipes: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateFilter(RecipeFilter newFilter) {
    _currentFilter = newFilter;
    notifyListeners();
    generateRecipes();
  }

  Future<void> refreshPantryItems() async {
    await pantryController.loadItems();
    notifyListeners();
  }

  Future<void> loadSavedRecipes() async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    _savedRecipes = await recipeRepository.getSavedRecipes(userId);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveRecipe(Recipe recipe) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    await recipeRepository.saveRecipe(userId, recipe);
    _savedRecipes.add(recipe.copyWith(isSaved: true));
    notifyListeners();
  }

  Future<void> unsaveRecipe(int recipeId) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    await recipeRepository.unsaveRecipe(userId, recipeId);
    _savedRecipes.removeWhere((r) => r.id == recipeId);
    notifyListeners();
  }

  bool isRecipeSaved(int recipeId) {
    return _savedRecipes.any((r) => r.id == recipeId);
  }

  /// After "I Cooked This" with servings consumed: store leftover in prepared recipes.
  /// Call only when leftover > 0.
  Future<void> logPreparedFromCook({
    required Recipe recipe,
    required double totalServings,
    required double consumedServings,
  }) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    final leftover = totalServings - consumedServings;
    if (leftover <= 0) return;
    await recipeRepository.logPreparedCook(
      userId,
      recipe,
      totalServings,
      consumedServings,
    );
  }

  /// Load prepared recipes (leftovers) from the backend.
  Future<void> loadPreparedRecipes() async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    try {
      final raw = await recipeRepository.getPreparedRaw(userId);
      _preparedRecipes = raw
          .map((d) => PreparedRecipe.fromJson(d))
          .where((p) => p.remainingServings > 0)
          .toList();
    } catch (e) {
      if (kDebugMode) print('Failed to load prepared recipes: $e');
      _preparedRecipes = [];
    }
    notifyListeners();
  }

  /// Deduct pantry and update diet trackers for [servingsConsumed] of [recipe].
  /// Used when logging consumption from a prepared (leftover) recipe.
  Future<void> applyConsumptionToPantryAndGoals(
    Recipe recipe,
    double servingsConsumed,
  ) async {
    final user = authProvider.currentUser;
    if (user == null) return;
    final recipeServings = recipe.servings.toDouble();
    if (recipeServings <= 0) return;
    final consumedFraction =
        (servingsConsumed / recipeServings).clamp(0.0, 1.0);
    final userDietType =
        (user.myPlanType ?? user.dietType ?? 'MyPlate').toString().toLowerCase();

    final scaledIngredients = recipe.extendedIngredients
        .map((ing) => {
              'name': ing.nameClean,
              'amount': ing.amount * consumedFraction,
              'unit': ing.unit,
            })
        .toList();

    final deductionResult =
        await pantryDeductionService.deductIngredientsFromPantry(
      scaledIngredients: scaledIngredients,
      pantryItems: [
        ...pantryController.pantryItems,
        ...pantryController.otherItems
      ],
    );

    for (final updatedItem in deductionResult.updatedItems) {
      await pantryController.updateItem(updatedItem);
    }
    for (final itemId in deductionResult.itemsToRemove) {
      final itemToRemove = [
        ...pantryController.pantryItems,
        ...pantryController.otherItems
      ].where((item) => item.id == itemId);
      if (itemToRemove.isNotEmpty) {
        await pantryController.removeItem(
            itemId, itemToRemove.first.isPantryItem);
      }
    }

    final Map<TrackerCategory, double> categoryServings = {};
    for (final ingredient in recipe.extendedIngredients) {
      if (ingredient.unit.toLowerCase() == 'servings' ||
          ingredient.unit.toLowerCase() == 'serving') continue;
      final categories = dietServingService.getCategoriesForIngredient(
          ingredient.nameClean, dietType: userDietType);
      final perPersonAmount = ingredient.amount / recipe.servings;
      for (final category in categories) {
        final dietServings = dietServingService.getServingsForTracker(
          ingredientName: ingredient.nameClean,
          amount: perPersonAmount * servingsConsumed,
          unit: ingredient.unit,
          category: category,
          dietType: userDietType,
        );
        if (dietServings > 0) {
          final rounded =
              double.parse(dietServings.toStringAsFixed(2));
          categoryServings[category] =
              (categoryServings[category] ?? 0.0) + rounded;
        }
      }
    }

    if (userDietType == 'dash' && recipe.nutrition != null) {
      final sodiumNutrient = recipe.nutrition!.nutrients
          .where((n) => n.name.toLowerCase() == 'sodium')
          .firstOrNull;
      if (sodiumNutrient != null) {
        double sodiumMg = sodiumNutrient.amount * servingsConsumed;
        if (sodiumNutrient.unit.toLowerCase() == 'g') sodiumMg *= 1000;
        if (sodiumNutrient.unit.toLowerCase() == 'mcg' ||
            sodiumNutrient.unit.toLowerCase() == 'μg') sodiumMg /= 1000;
        if (sodiumMg > 0) {
          categoryServings[TrackerCategory.sodium] =
              (categoryServings[TrackerCategory.sodium] ?? 0.0) +
                  double.parse(sodiumMg.toStringAsFixed(2));
        }
      }
    }

    for (final entry in categoryServings.entries) {
      final matchingTracker = trackerProvider.findTrackerByCategory(
          entry.key, userDietType);
      if (matchingTracker != null) {
        await trackerProvider.incrementTracker(matchingTracker.id, entry.value);
      }
    }

    await pantryController.loadItems();
  }

  /// Log consumption from a prepared recipe (leftover). Decreases remaining,
  /// deducts pantry, updates goals, then reloads prepared list.
  Future<void> logConsumptionFromPrepared(
    PreparedRecipe item,
    double servingsConsumed,
  ) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    final toUse = servingsConsumed.clamp(0.0, item.remainingServings);
    if (toUse <= 0) return;

    await recipeRepository.logPreparedConsumption(
      userId,
      item.recipeId,
      toUse,
    );
    await applyConsumptionToPantryAndGoals(item.recipe, toUse);
    await loadPreparedRecipes();
  }

  /// Remove a prepared recipe entry without applying pantry/goal consumption side effects.
  /// Used by swipe-delete in Prepared Recipes list.
  Future<void> removePreparedRecipe(PreparedRecipe item) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    if (item.remainingServings <= 0) return;

    await recipeRepository.logPreparedConsumption(
      userId,
      item.recipeId,
      item.remainingServings,
    );
    await loadPreparedRecipes();
  }

  /// Restore a previously removed prepared recipe entry (for undo).
  Future<void> restorePreparedRecipe(PreparedRecipe item) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) return;
    if (item.remainingServings <= 0) return;

    await recipeRepository.logPreparedCook(
      userId,
      item.recipe,
      item.remainingServings,
      0,
    );
    await loadPreparedRecipes();
  }

  Future<void> cookRecipe(Recipe recipe) async {
    final userId = authProvider.currentUser?.id;
    if (userId == null) {
      _error = "User not logged in";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (kDebugMode) {
        print('\n🍳 ===== STARTING RECIPE COOKING =====');
        print('Recipe: ${recipe.title}');
        print('Recipe servings: ${recipe.servings}');
        print('Ingredients count: ${recipe.extendedIngredients.length}');
      }

      // Step 1: Deduct ingredients from pantry using comprehensive service
      final scaledIngredients = recipe.extendedIngredients
          .map((ing) => {
                'name': ing.nameClean,
                'amount': ing.amount,
                'unit': ing.unit, // Units are now clean from the source
              })
          .toList();

      if (kDebugMode) {
        print('\n📦 PANTRY DEDUCTION STARTING...');
        print('Scaled ingredients to deduct:');
        for (var i = 0; i < scaledIngredients.length; i++) {
          final ing = scaledIngredients[i];
          print('  ${i + 1}. ${ing['amount']} ${ing['unit']} ${ing['name']}');
        }

        print('\nCurrent pantry state:');
        print('Pantry items: ${pantryController.pantryItems.length}');
        print('Other items: ${pantryController.otherItems.length}');
        for (var item in pantryController.pantryItems) {
          print('  - ${item.name}: ${item.quantity} ${item.unit.name}');
        }
        for (var item in pantryController.otherItems) {
          print('  - ${item.name}: ${item.quantity} ${item.unit.name}');
        }
      }

      final deductionResult =
          await pantryDeductionService.deductIngredientsFromPantry(
        scaledIngredients: scaledIngredients,
        pantryItems: [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ],
      );

      if (kDebugMode) {
        print('\n📦 PANTRY DEDUCTION COMPLETED!');
        print(
            'Total ingredients processed: ${deductionResult.totalIngredientsProcessed}');
        print('Successful deductions: ${deductionResult.successfulDeductions}');
        print(
            'Failed deductions: ${deductionResult.totalIngredientsProcessed - deductionResult.successfulDeductions}');
        print(
            'Average confidence: ${(deductionResult.averageConfidence * 100).toStringAsFixed(1)}%');
        print('Was successful: ${deductionResult.wasSuccessful}');

        print('\nUpdated items (${deductionResult.updatedItems.length}):');
        for (var item in deductionResult.updatedItems) {
          print('  - ${item.name}: ${item.quantity} ${item.unit.name}');
        }

        print('\nItems to remove (${deductionResult.itemsToRemove.length}):');
        for (var itemId in deductionResult.itemsToRemove) {
          print('  - Item ID: $itemId');
        }

        print('\nIngredient-level results:');
        for (var result in deductionResult.ingredientResults) {
          print(
              '  - ${result.ingredientName}: ${result.wasDeducted ? "✅" : "❌"} (confidence: ${(result.confidence * 100).toStringAsFixed(1)}%)');
          if (!result.wasDeducted && result.remainingAmount > 0) {
            print(
                '    Missing: ${result.remainingAmount} ${result.requiredUnit}');
          }
        }
      }

      // Step 2: Add to diet tracking (1 serving per person)
      final user = authProvider.currentUser;
      final userDietType =
          user?.dietType?.toLowerCase() ?? 'myplate'; // Default to MyPlate

      const servingsPerPerson = 1;

      if (kDebugMode) {
        print('\n🥗 DIET TRACKING STARTING...');
        print('User diet type: $userDietType');
        print('Servings per person: $servingsPerPerson');
      }

      // Aggregate servings by category to avoid duplicate updates
      final Map<TrackerCategory, double> categoryServings = {};

      // Use the clean ingredient data directly from the recipe
      for (final ingredient in recipe.extendedIngredients) {
        final categories = dietServingService.getCategoriesForIngredient(
            ingredient.nameClean,
            dietType: userDietType);

        if (kDebugMode) {
          print(
              'Ingredient: ${ingredient.nameClean} (${ingredient.amount} ${ingredient.unit})');
          print('  Categories: ${categories.map((c) => c.name).join(', ')}');
        }

        for (final category in categories) {
          double dietServings = 0.0;

          // Skip any remaining malformed units (should be very rare now)
          if (ingredient.unit.toLowerCase() == 'servings' ||
              ingredient.unit.toLowerCase() == 'serving') {
            if (kDebugMode) {
              print('  Skipping malformed unit: ${ingredient.unit}');
            }
            continue;
          }

          // Calculate servings for the user's selected diet only
          // This is the amount per person (total recipe amount divided by servings)
          final perPersonAmount = ingredient.amount / recipe.servings;

          dietServings = dietServingService.getServingsForTracker(
            ingredientName: ingredient.nameClean,
            amount: perPersonAmount * servingsPerPerson,
            unit: ingredient.unit,
            category: category,
            dietType: userDietType,
          );

          if (kDebugMode) {
            print('  Per person amount: $perPersonAmount');
            print('  Diet servings for ${category.name}: $dietServings');
          }

          if (dietServings > 0) {
            // Round to 2 decimal places and aggregate
            final roundedServings =
                double.parse(dietServings.toStringAsFixed(2));
            categoryServings[category] =
                (categoryServings[category] ?? 0.0) + roundedServings;
          }
        }
      }

      // Add sodium tracking from nutrition data (DASH diet specific)
      if (userDietType == 'dash' && recipe.nutrition != null) {
        final sodiumNutrient = recipe.nutrition!.nutrients
            .where((n) => n.name.toLowerCase() == 'sodium')
            .firstOrNull;

        if (sodiumNutrient != null) {
          // Convert sodium amount per serving to mg if needed
          // The nutrition data is typically per serving, so we multiply by servingsPerPerson
          double sodiumMg = sodiumNutrient.amount * servingsPerPerson;

          // Convert to mg if in different units
          if (sodiumNutrient.unit.toLowerCase() == 'g') {
            sodiumMg *= 1000; // Convert grams to mg
          } else if (sodiumNutrient.unit.toLowerCase() == 'mcg' ||
              sodiumNutrient.unit.toLowerCase() == 'μg') {
            sodiumMg /= 1000; // Convert micrograms to mg
          }

          if (sodiumMg > 0) {
            final roundedSodium = double.parse(sodiumMg.toStringAsFixed(2));
            categoryServings[TrackerCategory.sodium] =
                (categoryServings[TrackerCategory.sodium] ?? 0.0) +
                    roundedSodium;

            if (kDebugMode) {
              print('Added sodium tracking: ${roundedSodium}mg');
            }
          }
        }
      }

      if (kDebugMode) {
        print('\n🥗 DIET TRACKING SUMMARY:');
        print('Categories to update: ${categoryServings.length}');
        for (var entry in categoryServings.entries) {
          print('  ${entry.key.name}: ${entry.value}');
        }
      }

      // Update tracker for each category
      for (final entry in categoryServings.entries) {
        final category = entry.key;
        final servings = entry.value;

        // Find the matching tracker and update it
        final matchingTracker =
            trackerProvider.findTrackerByCategory(category, userDietType);
        if (matchingTracker != null) {
          if (kDebugMode) {
            print(
                'Updating tracker ${matchingTracker.id} (${category.name}) with $servings servings');
          }
          await trackerProvider.incrementTracker(matchingTracker.id, servings);
        } else {
          if (kDebugMode) {
            print('No matching tracker found for category: ${category.name}');
          }
        }
      }

      // Step 3: Log the meal in the user's history (via RecipeRepository)
      if (kDebugMode) {
        print('\n📝 LOGGING MEAL TO HISTORY...');
      }
      await recipeRepository.cookRecipe(userId, recipe);

      // Step 4: Reload pantry to reflect changes
      if (kDebugMode) {
        print('\n📦 RELOADING PANTRY...');
        print(
            'Pantry items before reload: ${pantryController.pantryItems.length}');
        print(
            'Other items before reload: ${pantryController.otherItems.length}');
      }

      await pantryController.loadItems();

      if (kDebugMode) {
        print(
            'Pantry items after reload: ${pantryController.pantryItems.length}');
        print(
            'Other items after reload: ${pantryController.otherItems.length}');

        print('\nFinal pantry state:');
        for (var item in pantryController.pantryItems) {
          print('  - ${item.name}: ${item.quantity} ${item.unit.name}');
        }
        for (var item in pantryController.otherItems) {
          print('  - ${item.name}: ${item.quantity} ${item.unit.name}');
        }
      }

      if (kDebugMode) {
        print('\n✅ RECIPE COOKING COMPLETED SUCCESSFULLY');
        print(
            '   Pantry deduction: ${deductionResult.successfulDeductions}/${deductionResult.totalIngredientsProcessed} successful');
        print(
            '   Diet tracking: ${categoryServings.length} categories updated');
        print('===== RECIPE COOKING COMPLETE =====\n');
      }
    } catch (e) {
      _error = userFacingErrorMessage(e);
      if (kDebugMode) {
        print('\n❌ RECIPE COOKING FAILED: $e');
        print('Stack trace: ${StackTrace.current}');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void resetGenerationAttempt() {
    _hasAttemptedGeneration = false;
    _recipes = [];
    _error = null;
    notifyListeners();
  }
}
