import 'dart:math';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter/foundation.dart';

class RecipeGenerationService {
  final RecipeRepository _recipeRepository;
  final UnitConversionService _unitConversionService;
  final FoodCategoryService _foodCategoryService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
  final DietConstraintsService _dietConstraintsService;
  static int _requestCount = 0; // Static counter for variety across requests

  RecipeGenerationService({
    required RecipeRepository recipeRepository,
    required UnitConversionService unitConversionService,
    required FoodCategoryService foodCategoryService,
    required IngredientSubstitutionService ingredientSubstitutionService,
    required DietConstraintsService dietConstraintsService,
  })  : _recipeRepository = recipeRepository,
        _unitConversionService = unitConversionService,
        _foodCategoryService = foodCategoryService,
        _ingredientSubstitutionService = ingredientSubstitutionService,
        _dietConstraintsService = dietConstraintsService;

  Future<List<Recipe>> generateRecipes({
    required RecipeFilter filter,
    required List<PantryItem> pantryItems,
    required Map<String, dynamic> userProfile,
  }) async {
    final pantryIngredientNames = pantryItems.map((e) => e.name).toList();

    // 1. Enhance filter with user-specific dietary constraints
    final enhancedFilter = _enhanceFilterWithUserProfile(filter, userProfile);

    // 2. Try fetching and validating recipes with progressive fallback:
    //    a) original filter, b) without meal type, c) without cuisines, d) without time
    List<Recipe> validatedRecipes = await _tryFetchAndValidateRecipes(
        enhancedFilter, pantryIngredientNames, pantryItems, userProfile);

    // If still empty after all fallbacks, try without meal type
    // Use a small offset for variety even during fallback
    if (validatedRecipes.isEmpty &&
        (enhancedFilter.mealType != null ||
            enhancedFilter.spoonacularMealType != null ||
            enhancedFilter.spoonacularMealTypes != null)) {
      if (kDebugMode) {
        print('🔁 No validated recipes found. Retrying without meal type...');
      }
      // Calculate a small offset for variety (based on request count)
      final fallbackOffset = (_requestCount % 3) * 20; // 0, 20, or 40
      // Create a new filter without meal type, keeping small offset for variety
      final withoutMealType = RecipeFilter(
        cuisines: enhancedFilter.cuisines,
        diets: enhancedFilter.diets,
        intolerances: enhancedFilter.intolerances,
        medicalConditions: enhancedFilter.medicalConditions,
        maxReadyTime: enhancedFilter.maxReadyTime,
        servings: enhancedFilter.servings,
        includeIngredients: enhancedFilter.includeIngredients,
        excludeIngredients: enhancedFilter.excludeIngredients,
        prioritizeExpiring: enhancedFilter.prioritizeExpiring,
        dashCompliant: enhancedFilter.dashCompliant,
        myPlateCompliant: enhancedFilter.myPlateCompliant,
        maxCalories: enhancedFilter.maxCalories,
        minProtein: enhancedFilter.minProtein,
        maxSodium: enhancedFilter.maxSodium,
        maxSugar: enhancedFilter.maxSugar,
        vegetarian: enhancedFilter.vegetarian,
        vegan: enhancedFilter.vegan,
        glutenFree: enhancedFilter.glutenFree,
        dairyFree: enhancedFilter.dairyFree,
        veryHealthy: enhancedFilter.veryHealthy,
        query: enhancedFilter.query,
        offset: fallbackOffset, // Use small offset for variety
      );
      validatedRecipes = await _tryFetchAndValidateRecipes(
          withoutMealType, pantryIngredientNames, pantryItems, userProfile);
    }

    // If still empty, try without cuisines
    if (validatedRecipes.isEmpty && enhancedFilter.cuisines.isNotEmpty) {
      if (kDebugMode) {
        print('🔁 Still none. Retrying without cuisines...');
      }
      // Calculate a small offset for variety (based on request count)
      final fallbackOffset = (_requestCount % 3) * 20; // 0, 20, or 40
      final withoutCuisines = RecipeFilter(
        diets: enhancedFilter.diets,
        intolerances: enhancedFilter.intolerances,
        medicalConditions: enhancedFilter.medicalConditions,
        maxReadyTime: enhancedFilter.maxReadyTime,
        servings: enhancedFilter.servings,
        includeIngredients: enhancedFilter.includeIngredients,
        excludeIngredients: enhancedFilter.excludeIngredients,
        prioritizeExpiring: enhancedFilter.prioritizeExpiring,
        dashCompliant: enhancedFilter.dashCompliant,
        myPlateCompliant: enhancedFilter.myPlateCompliant,
        maxCalories: enhancedFilter.maxCalories,
        minProtein: enhancedFilter.minProtein,
        maxSodium: enhancedFilter.maxSodium,
        maxSugar: enhancedFilter.maxSugar,
        vegetarian: enhancedFilter.vegetarian,
        vegan: enhancedFilter.vegan,
        glutenFree: enhancedFilter.glutenFree,
        dairyFree: enhancedFilter.dairyFree,
        veryHealthy: enhancedFilter.veryHealthy,
        query: enhancedFilter.query,
        offset: fallbackOffset, // Use small offset for variety
      );
      validatedRecipes = await _tryFetchAndValidateRecipes(
          withoutCuisines, pantryIngredientNames, pantryItems, userProfile);
    }

    // If still empty, try without time limit
    if (validatedRecipes.isEmpty && enhancedFilter.maxReadyTime != null) {
      if (kDebugMode) {
        print('🔁 Still none. Retrying without time limit...');
      }
      // Calculate a small offset for variety (based on request count)
      final fallbackOffset = (_requestCount % 3) * 20; // 0, 20, or 40
      final withoutTime = RecipeFilter(
        diets: enhancedFilter.diets,
        intolerances: enhancedFilter.intolerances,
        medicalConditions: enhancedFilter.medicalConditions,
        servings: enhancedFilter.servings,
        includeIngredients: enhancedFilter.includeIngredients,
        excludeIngredients: enhancedFilter.excludeIngredients,
        prioritizeExpiring: enhancedFilter.prioritizeExpiring,
        dashCompliant: enhancedFilter.dashCompliant,
        myPlateCompliant: enhancedFilter.myPlateCompliant,
        maxCalories: enhancedFilter.maxCalories,
        minProtein: enhancedFilter.minProtein,
        maxSodium: enhancedFilter.maxSodium,
        maxSugar: enhancedFilter.maxSugar,
        vegetarian: enhancedFilter.vegetarian,
        vegan: enhancedFilter.vegan,
        glutenFree: enhancedFilter.glutenFree,
        dairyFree: enhancedFilter.dairyFree,
        veryHealthy: enhancedFilter.veryHealthy,
        query: enhancedFilter.query,
        offset: fallbackOffset, // Use small offset for variety
      );
      validatedRecipes = await _tryFetchAndValidateRecipes(
          withoutTime, pantryIngredientNames, pantryItems, userProfile);
    }

    // 3. Sort recipes by health score and ingredient availability
    validatedRecipes.sort((a, b) {
      // Primary sort: by used ingredient count (more available ingredients first)
      final usedIngredientComparison =
          (b.usedIngredientCount ?? 0).compareTo(a.usedIngredientCount ?? 0);
      if (usedIngredientComparison != 0) return usedIngredientComparison;

      // Secondary sort: by health score (healthier recipes first)
      return b.healthScore.compareTo(a.healthScore);
    });

    // 4. Apply final randomization shuffle for variety (industry best practice)
    // This ensures variety even when API returns same results
    if (validatedRecipes.length > 1) {
      // Use a seed based on time AND request count for better variety
      // Changes every minute AND with each request to ensure different order
      final timeSeed = DateTime.now().millisecondsSinceEpoch ~/
          60000; // Changes every minute
      final seed =
          timeSeed + _requestCount; // Add request count for additional variety
      final seededRandom = Random(seed);
      validatedRecipes.shuffle(seededRandom);

      if (kDebugMode) {
        print(
            '🎲 Applied local shuffling for variety (seed: $seed, timeSeed: $timeSeed, requestCount: $_requestCount)');
      }
    }

    if (kDebugMode) {
      print('\n📊 FINAL RESULTS:');
      print('Validated recipes: ${validatedRecipes.length}');
      if (validatedRecipes.isEmpty) {
        print('⚠️  No recipes found after all fallback attempts');
      }
    }

    return validatedRecipes;
  }

  /// Fetch recipes from repository and validate them
  Future<List<Recipe>> _tryFetchAndValidateRecipes(
    RecipeFilter filter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
  ) async {
    // Fetch recipes from the repository
    final recipes =
        await _recipeRepository.getRecipes(filter, pantryIngredientNames);

    if (kDebugMode) {
      print('\n🔍 RECIPE GENERATION DEBUG:');
      print('Recipes from API: ${recipes.length}');
      print('User Profile: $userProfile');
    }

    // Perform local validation and enhancement
    final validatedRecipes = <Recipe>[];

    for (var recipe in recipes) {
      if (kDebugMode) {
        print('\n📋 Validating recipe: ${recipe.title}');
      }

      // a. Check if pantry has enough ingredients
      if (!_hasEnoughIngredients(recipe, pantryItems)) {
        if (kDebugMode) {
          print(
              '  ❌ Not enough ingredients (missed: ${recipe.missedIngredientCount})');
        }
        continue;
      }

      // b. Validate against health constraints (DASH, MyPlate, etc.)
      if (!(await _isHealthCompliant(recipe, userProfile))) {
        if (kDebugMode) {
          print('  ❌ Not health compliant');
        }
        continue;
      }

      // c. Validate against medical condition constraints
      if (!_isMedicalConditionCompliant(recipe, userProfile)) {
        if (kDebugMode) {
          print('  ❌ Not medical condition compliant');
        }
        continue;
      }

      if (kDebugMode) {
        print('  ✅ Recipe passed all validations');
      }

      // d. Enhance recipe with pantry data
      final enhancedRecipe = _enhanceRecipeWithPantryData(recipe, pantryItems);

      validatedRecipes.add(enhancedRecipe);
    }

    if (kDebugMode) {
      print('Validated recipes: ${validatedRecipes.length}');
      print('Filtered out: ${recipes.length - validatedRecipes.length}');
    }

    return validatedRecipes;
  }

  /// Enhance filter with user-specific dietary constraints based on diet assignment matrix
  RecipeFilter _enhanceFilterWithUserProfile(
      RecipeFilter filter, Map<String, dynamic> userProfile) {
    // Calculate offset for variety (industry best practice: time-based pagination)
    final offset = _calculateVarietyOffset(filter);

    // Note: We don't use random sort API parameter to maintain min-missing-ingredients
    // Variety is achieved through offset-based pagination and local shuffling

    if (kDebugMode && offset > 0) {
      print(
          '🎲 Variety settings: offset=$offset (using min-missing-ingredients sort)');
    }

    final medicalConditions =
        List<String>.from(userProfile['medicalConditions'] ?? []);
    final healthGoals = List<String>.from(userProfile['healthGoals'] ?? []);
    final dietType = userProfile['dietType'] as String?;
    final allergies = List<String>.from(userProfile['allergies'] ?? []);
    final dietRule = userProfile['diet_rule'] as Map<String, dynamic>?;

    // Convert medical conditions to filter enum
    final medicalConditionEnums = medicalConditions
        .map((condition) {
          switch (condition.toLowerCase()) {
            case 'hypertension':
              return MedicalCondition.hypertension;
            case 'diabetes':
              return MedicalCondition.diabetes;
            case 'pre-diabetes':
            case 'prediabetes':
              return MedicalCondition.prediabetes;
            case 'overweight/obesity':
            case 'obesity':
              return MedicalCondition.obesity;
            default:
              return null;
          }
        })
        .where((condition) => condition != null)
        .cast<MedicalCondition>()
        .toList();

    // Convert allergies to intolerances
    final intoleranceEnums = allergies
        .map((allergy) {
          switch (allergy.toLowerCase()) {
            case 'dairy':
              return Intolerances.dairy;
            case 'eggs':
              return Intolerances.egg;
            case 'gluten':
            case 'wheat':
              return Intolerances.gluten;
            case 'peanuts':
              return Intolerances.peanut;
            case 'tree nuts':
              return Intolerances.treeNut;
            case 'soy':
              return Intolerances.soy;
            case 'fish':
            case 'shellfish':
              return Intolerances.seafood;
            default:
              return null;
          }
        })
        .where((intolerance) => intolerance != null)
        .cast<Intolerances>()
        .toList();

    // Determine diet compliance based on diet rule from matrix
    bool dashCompliant = false;
    bool myPlateCompliant = false;
    int? maxSodium;

    if (dietRule != null) {
      final diet = dietRule['diet'] as String;
      if (diet == 'DASH') {
        dashCompliant = true;
      } else if (diet == 'MyPlate') {
        myPlateCompliant = true;
      }

      // Get sodium constraint from diet rule
      final sodiumCap = dietRule['sodium_mg_max'];
      if (sodiumCap is int) {
        maxSodium = (sodiumCap / 3).round(); // Convert daily to per-serving
      }
    } else {
      // Fallback to old logic if no diet rule
      if (dietType == 'DASH' ||
          medicalConditions.contains('Hypertension') ||
          healthGoals.contains('Lower blood pressure')) {
        dashCompliant = true;
      } else {
        myPlateCompliant = true;
      }
    }

    // Increment request count for variety
    _requestCount++;

    return filter.copyWith(
      medicalConditions: medicalConditionEnums,
      intolerances: [...filter.intolerances, ...intoleranceEnums],
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      maxSodium: maxSodium,
      veryHealthy: true, // Always prefer healthier options
      offset: offset > 0
          ? offset
          : filter
              .offset, // Use calculated offset if > 0, otherwise keep existing
      // Note: randomize flag is kept for potential future use, but we don't use it for API sort
      // to maintain min-missing-ingredients prioritization
    );
  }

  /// Calculate offset for recipe variety using industry best practices
  /// Uses time-based pagination: hour of day + day of week for natural variety
  int _calculateVarietyOffset(RecipeFilter filter) {
    // If offset is explicitly set, use it (but cap it to prevent empty results)
    if (filter.offset != null && filter.offset! > 0) {
      // Cap offset at 60 to avoid empty result sets with strict filters
      return filter.offset! > 60 ? 60 : filter.offset!;
    }

    // Calculate offset based on time-of-day and day-of-week
    // This ensures variety across different sessions while maintaining consistency
    final now = DateTime.now();
    final hourOfDay = now.hour;
    final dayOfWeek = now.weekday; // 1-7 (Monday-Sunday)

    // Create a deterministic but varied offset
    // Formula: (hour * 2 + dayOfWeek) % 5, multiplied by 20 (our page size)
    // This gives us 0-80 offset range, cycling through different pages
    // Reduced range to avoid empty results when combined with strict filters
    final baseOffset = ((hourOfDay * 2 + dayOfWeek) % 5) * 20;

    // Add some additional randomness based on request count
    final additionalOffset = (_requestCount % 3) * 20;

    // Cap at 60 to ensure we don't go too far and get empty results
    final calculatedOffset = (baseOffset + additionalOffset) % 60;

    return calculatedOffset;
  }

  bool _hasEnoughIngredients(Recipe recipe, List<PantryItem> pantryItems) {
    // The Spoonacular findByIngredients endpoint provides `missedIngredientCount`.
    // If it's null (which can happen if the recipe comes from another source
    // like the bulk endpoint), we can fall back to checking the extendedIngredients list.
    if (recipe.missedIngredientCount != null) {
      // We allow for a few missing ingredients to give the user more options.
      return recipe.missedIngredientCount! <= 5;
    }

    // Fallback for recipes that have full ingredient details but not the count.
    return recipe.extendedIngredients.isNotEmpty;
  }

  Future<bool> _isHealthCompliant(
      Recipe recipe, Map<String, dynamic> userProfile) async {
    final dietRule = userProfile['diet_rule'] as Map<String, dynamic>?;
    if (dietRule == null) {
      return true; // Default to allowing recipe if no diet rule
    }

    final nutrition = recipe.nutrition;
    if (nutrition == null) {
      return true; // Allow if nutrition data is not available
    }

    // Get constraints for the diet rule
    final constraints =
        await _dietConstraintsService.getConstraintsForRule(dietRule);

    // Validate recipe against constraints
    return await _dietConstraintsService.validateRecipe(
        nutrition.toMap(), constraints);
  }

  bool _isMedicalConditionCompliant(
      Recipe recipe, Map<String, dynamic> userProfile) {
    final medicalConditions =
        List<String>.from(userProfile['medicalConditions'] ?? []);
    final nutrition = recipe.nutrition;

    if (nutrition == null) {
      if (kDebugMode) {
        print('    ℹ️ No nutrition data - allowing recipe');
      }
      return true; // Allow if nutrition data is not available
    }

    for (final condition in medicalConditions) {
      if (kDebugMode) {
        print('    🏥 Checking condition: $condition');
      }

      switch (condition.toLowerCase()) {
        case 'diabetes':
        case 'pre-diabetes':
        case 'prediabetes':
          if (!_isDiabetesCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed diabetes compliance');
            }
            return false;
          }
          break;
        case 'obesity':
        case 'overweight/obesity':
          if (!_isObesityCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed obesity compliance');
            }
            return false;
          }
          break;
        case 'hypertension':
          if (!_isHypertensionCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed hypertension compliance');
            }
            return false;
          }
          break;
      }
    }

    if (kDebugMode) {
      print('    ✅ Passed all medical condition checks');
    }
    return true;
  }

  bool _isDiabetesCompliant(Recipe recipe, Nutrition nutrition) {
    final sugar = _getNutrientAmount(nutrition, 'Sugar');
    final carbs = _getNutrientAmount(nutrition, 'Carbohydrates');
    final fiber = _getNutrientAmount(nutrition, 'Fiber');

    if (kDebugMode) {
      print(
          '      📊 Diabetes check - Sugar: ${sugar}g, Carbs: ${carbs}g, Fiber: ${fiber}g');
    }

    // ADA guidelines for diabetes (using the new relaxed limits from RecipeFilter)
    if (sugar > 45) {
      if (kDebugMode) {
        print('      ❌ Sugar too high: ${sugar}g > 45g');
      }
      return false; // Max 45g sugar per serving
    }
    if (carbs > 75) {
      if (kDebugMode) {
        print('      ❌ Carbs too high: ${carbs}g > 75g');
      }
      return false; // Max 75g carbs per serving
    }
    // Removed fiber requirement as per our latest changes

    if (kDebugMode) {
      print('      ✅ Passed diabetes compliance');
    }
    return true;
  }

  bool _isObesityCompliant(Recipe recipe, Nutrition nutrition) {
    // No specific constraints for obesity

    return true;
  }

  bool _isHypertensionCompliant(Recipe recipe, Nutrition nutrition) {
    final sodium = _getNutrientAmount(nutrition, 'Sodium');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');

    // DASH guidelines for hypertension (practical approach)
    if (sodium > 800) {
      return false; // Max 800mg sodium per serving (practical DASH)
    }
    if (saturatedFat > 8) {
      return false; // Max 8g saturated fat per serving
    }
    // Prefer recipes with good potassium (300mg+) but don't require it

    return true;
  }

  double _getNutrientAmount(Nutrition nutrition, String nutrientName) {
    try {
      final nutrient = nutrition.nutrients.firstWhere(
        (n) => n.name.toLowerCase() == nutrientName.toLowerCase(),
      );
      return nutrient.amount;
    } catch (e) {
      return 0.0; // Return 0 if nutrient not found
    }
  }

  Recipe _enhanceRecipeWithPantryData(
      Recipe recipe, List<PantryItem> pantryItems) {
    // The usedIngredients list from Spoonacular tells us what we have.
    final usedPantryItemNames =
        recipe.usedIngredients.map((i) => i.name).toSet();

    final expiringPantryItems = pantryItems
        .where((pantryItem) =>
            usedPantryItemNames.contains(pantryItem.name) &&
            pantryItem.expiryDate != null &&
            pantryItem.expiryDate!
                .isBefore(DateTime.now().add(const Duration(days: 2))))
        .map((pantryItem) => pantryItem.name)
        .toList();

    return recipe.copyWith(
      pantryItemsUsed: usedPantryItemNames.toList(),
      expiringItemsUsed: expiringPantryItems,
    );
  }
}
