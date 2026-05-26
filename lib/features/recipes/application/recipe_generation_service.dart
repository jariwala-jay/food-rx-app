import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_pantry_sort.dart';
import 'package:flutter/foundation.dart';

class RecipeGenerationService {
  final RecipeRepository _recipeRepository;
  final UnitConversionService _unitConversionService;
  final FoodCategoryService _foodCategoryService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
  final DietConstraintsService _dietConstraintsService;

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

    // 2. Generate with cuisine strategy
    final List<Recipe> validatedRecipes;
    if (enhancedFilter.isNoPreferenceOnly) {
      validatedRecipes = await _generateNoPreferenceRecipes(
        enhancedFilter,
        pantryIngredientNames,
        pantryItems,
        userProfile,
      );
    } else if (enhancedFilter.hasExplicitCuisinePreference) {
      validatedRecipes = await _generateExplicitCuisineRecipes(
        enhancedFilter,
        pantryIngredientNames,
        pantryItems,
        userProfile,
      );
    } else {
      validatedRecipes = await _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
      );
    }

    _sortRecipesByPantryEase(validatedRecipes, pantryItems, enhancedFilter);

    if (kDebugMode) {
      print('\n📊 FINAL RESULTS:');
      print('Validated recipes: ${validatedRecipes.length}');
      if (validatedRecipes.isEmpty) {
        print('⚠️  No recipes found after all fallback attempts');
      }
    }

    return validatedRecipes;
  }

  List<CuisineType> _favoriteCuisinesFromProfile(Map<String, dynamic> userProfile) {
    final raw = userProfile['favoriteCuisines'];
    if (raw is! List) return [];
    return CuisineTypeExtension.fromUserFavoriteNames(
      raw.map((e) => e.toString()).toList(),
    );
  }

  /// No preference: favorites from account first, then all other cuisines.
  Future<List<Recipe>> _generateNoPreferenceRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
  ) async {
    final favoriteCuisines = _favoriteCuisinesFromProfile(userProfile);

    if (favoriteCuisines.isEmpty) {
      if (kDebugMode) {
        print('🍽️ No preference: no account favorites — searching all cuisines');
      }
      return _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
      );
    }

    if (kDebugMode) {
      print(
          '🍽️ No preference: favorites first (${favoriteCuisines.map((c) => c.displayName).join(', ')}), then other cuisines');
    }

    final favoriteBatch = await _generateWithFallbacks(
      enhancedFilter.copyWith(cuisines: favoriteCuisines),
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: true,
    );

    final allCuisinesBatch = await _generateWithFallbacks(
      enhancedFilter.copyWith(cuisines: const []),
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: false,
    );

    return _mergePrimaryFirst(favoriteBatch, allCuisinesBatch);
  }

  /// User picked specific cuisine(s) — search only those (e.g. Korean → Korean only).
  Future<List<Recipe>> _generateExplicitCuisineRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
  ) async {
    if (kDebugMode) {
      final selected = enhancedFilter.explicitCuisines;
      print(
          '🍽️ Selected cuisines only (${selected.map((c) => c.displayName).join(', ')})');
    }

    return _generateWithFallbacks(
      enhancedFilter,
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: true,
    );
  }

  List<Recipe> _mergePrimaryFirst(
    List<Recipe> primaryBatch,
    List<Recipe> secondaryBatch,
  ) {
    final seen = primaryBatch.map((r) => r.id).toSet();
    final remainder =
        secondaryBatch.where((r) => !seen.contains(r.id)).toList();
    return [...primaryBatch, ...remainder];
  }

  Future<List<Recipe>> _generateWithFallbacks(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile, {
    required bool keepCuisine,
  }) async {
    List<Recipe> validatedRecipes = await _tryFetchAndValidateRecipes(
      enhancedFilter,
      pantryIngredientNames,
      pantryItems,
      userProfile,
      enforceCuisine: keepCuisine,
    );

    if (validatedRecipes.isEmpty && enhancedFilter.maxReadyTime != null) {
      if (kDebugMode) {
        print(
            '🔁 No validated recipes found. Retrying without maxReadyTime '
            '(was ${enhancedFilter.maxReadyTime} min)...');
      }
      validatedRecipes = await _tryFetchAndValidateRecipes(
        enhancedFilter.copyWith(maxReadyTime: null),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
      );
    }

    if (validatedRecipes.isEmpty) {
      if (kDebugMode) {
        print('🔁 Still none. Retrying with relaxed health constraints...');
      }
      validatedRecipes = await _tryFetchAndValidateRecipes(
        enhancedFilter.copyWith(
          maxReadyTime: null,
          veryHealthy: false,
          dashCompliant: false,
          myPlateCompliant: false,
          maxSodium: null,
        ),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
      );
    }

    // Only drop cuisine when the user picked specific cuisines and still got nothing.
    if (validatedRecipes.isEmpty &&
        keepCuisine &&
        enhancedFilter.hasExplicitCuisinePreference) {
      if (kDebugMode) {
        print(
            '⚠️ No recipes matched selected cuisine(s); not broadening to other cuisines.');
      }
    }

    return validatedRecipes;
  }

  void _sortRecipesByPantryEase(
    List<Recipe> recipes,
    List<PantryItem> pantryItems,
    RecipeFilter filter,
  ) {
    final counts = RecipeIngredientPantryCounts(
      PantryDeductionService(
        conversionService: _unitConversionService,
        substitutionService: _ingredientSubstitutionService,
      ),
    );

    RecipePantrySort.sortByEasiestToMake(
      recipes,
      pantry: pantryItems,
      counts: counts,
      targetServings: filter.servings,
      tiebreaker: (a, b) {
        final usedCmp = (b.usedIngredientCount ?? 0)
            .compareTo(a.usedIngredientCount ?? 0);
        if (usedCmp != 0) return usedCmp;
        return b.healthScore.compareTo(a.healthScore);
      },
    );
  }

  /// Fetch recipes from repository and validate them
  Future<List<Recipe>> _tryFetchAndValidateRecipes(
    RecipeFilter filter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile, {
    bool enforceCuisine = false,
  }) async {
    // Fetch recipes from the repository
    final recipes =
        await _recipeRepository.getRecipes(filter, pantryIngredientNames);

    if (kDebugMode) {
      print('\n🔍 RECIPE GENERATION DEBUG:');
      print('Recipes from API: ${recipes.length}');
      print('Filter meal types: ${filter.spoonacularMealTypes}');
      final params = filter.toSpoonacularParams();
      print('Spoonacular type param: ${params['type']}');
      print('Spoonacular cuisine param: ${params['cuisine'] ?? '(none)'}');
      print('Spoonacular maxReadyTime: ${params['maxReadyTime'] ?? '(none)'}');
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
              '  ❌ Not enough ingredients (missed: ${recipe.requiredMissedIngredientCount})');
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

      // d. Snacks: drop full meals Spoonacular mis-tags as snack (e.g. fried rice).
      if (!_matchesMealTypeIntent(recipe, filter)) {
        if (kDebugMode) {
          print('  ❌ Does not match meal type intent (${filter.mealType?.displayName})');
        }
        continue;
      }

      // e. Require written cooking steps (exclude video-only Spoonacular entries).
      if (!recipe.hasCookingInstructions) {
        if (kDebugMode) {
          print('  ❌ No written cooking instructions (video-only or empty)');
        }
        continue;
      }

      if (kDebugMode) {
        print('  ✅ Recipe passed all validations');
      }

      // f. Enhance recipe with pantry data
      final enhancedRecipe = _enhanceRecipeWithPantryData(recipe, pantryItems);

      validatedRecipes.add(enhancedRecipe);
    }

    var results = validatedRecipes;
    if (enforceCuisine && filter.hasExplicitCuisinePreference) {
      final before = results.length;
      results = results
          .where((r) => _matchesSelectedCuisines(r, filter.cuisines))
          .toList();
      if (kDebugMode && before != results.length) {
        print('  🍛 Cuisine post-filter: $before → ${results.length} recipes');
      }
    }

    if (kDebugMode) {
      print('Validated recipes: ${results.length}');
      print('Filtered out: ${recipes.length - results.length}');
    }

    return results;
  }

  bool _matchesSelectedCuisines(Recipe recipe, List<CuisineType> selected) {
    final wanted = selected
        .where((c) => c != CuisineType.noPreference)
        .map((c) => c.name.toLowerCase())
        .toSet();
    if (wanted.isEmpty) return true;

    final recipeCuisines =
        recipe.cuisines.map((c) => c.toLowerCase()).toSet();
    if (recipeCuisines.isEmpty) {
      // Spoonacular sometimes omits cuisine tags; trust the API cuisine param.
      return true;
    }
    return recipeCuisines.any(wanted.contains);
  }

  /// Enhance filter with user-specific dietary constraints based on diet assignment matrix
  RecipeFilter _enhanceFilterWithUserProfile(
      RecipeFilter filter, Map<String, dynamic> userProfile) {
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

    return filter.copyWith(
      medicalConditions: medicalConditionEnums,
      intolerances: [...filter.intolerances, ...intoleranceEnums],
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      maxSodium: maxSodium,
      veryHealthy: true, // Always prefer healthier options
    );
  }

  /// When user picks Snacks, exclude obvious full meals Spoonacular still tags as snack.
  bool _matchesMealTypeIntent(Recipe recipe, RecipeFilter filter) {
    if (filter.mealType != MealType.snack) return true;

    final types =
        recipe.dishTypes.map((t) => t.toLowerCase().trim()).toSet();
    if (types.contains('main course')) return false;

    final title = recipe.title.toLowerCase();
    const notSnackPhrases = [
      'fried rice',
      'brown rice and',
      'vegetable fried',
      'stir fry',
      'stir-fry',
      'curry',
      'casserole',
      'lasagna',
      'enchilada',
      'burrito bowl',
      'pasta',
      'pizza',
      'burger',
      'meatloaf',
      'pot roast',
      'soup',
    ];
    if (notSnackPhrases.any(title.contains)) return false;

    return types.contains('snack') ||
        types.contains('fingerfood') ||
        types.contains('appetizer') ||
        types.contains('hor d\'oeuvre') ||
        types.contains("hor d'oeuvre");
  }

  bool _hasEnoughIngredients(Recipe recipe, List<PantryItem> pantryItems) {
    // The Spoonacular findByIngredients endpoint provides `missedIngredientCount`.
    // If it's null (which can happen if the recipe comes from another source
    // like the bulk endpoint), we can fall back to checking the extendedIngredients list.
    if (recipe.missedIngredientCount != null ||
        recipe.missedIngredients.isNotEmpty) {
      // Exclude optional lines from the threshold (matches cart badge).
      return recipe.requiredMissedIngredientCount <= 8;
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
