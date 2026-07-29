import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_main_ingredient_validation.dart';
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

  final RecipeMainIngredientValidator _mainIngredientValidator =
      RecipeMainIngredientValidator();

  Future<List<Recipe>> generateRecipes({
    required RecipeFilter filter,
    required List<PantryItem> pantryItems,
    required Map<String, dynamic> userProfile,
  }) async {
    // Phase 1.5: only meaningful pantry items bias Spoonacular discovery.
    // Seasonings/condiments remain in [pantryItems] for ranking, badges, cook.
    final includeSelection =
        IngredientNutritionalCategoryResolver.selectForSpoonacularInclude(
      pantryItems.map(
        (e) => (name: e.name, category: e.category),
      ),
    );
    final pantryIngredientNames = includeSelection.includedNames;
    _logSpoonacularIncludeSelection(includeSelection);

    // 1. Enhance filter with user-specific dietary constraints
    final enhancedFilter = _enhanceFilterWithUserProfile(filter, userProfile);
    final allergies = List<String>.from(userProfile['allergies'] ?? const []);
    final excludedIngredients =
        AllergyFilteringService.parseExcludedIngredients(
      userProfile['excludedIngredients'],
    );
    final requestPantryIngredientNames = pantryIngredientNames
        .where(
          (name) => !AllergyFilteringService.conflictsWithRestrictions(
            name,
            allergies: allergies,
            excludedIngredients: excludedIngredients,
          ),
        )
        .toList();
    final diagnostics = _GenerationDiagnostics(
      filter: enhancedFilter,
      userProfile: userProfile,
    );

    // 2. Generate with cuisine strategy
    final List<Recipe> validatedRecipes;
    if (enhancedFilter.isNoPreferenceOnly) {
      validatedRecipes = await _generateNoPreferenceRecipes(
        enhancedFilter,
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        diagnostics,
      );
    } else if (enhancedFilter.hasExplicitCuisinePreference) {
      validatedRecipes = await _generateExplicitCuisineRecipes(
        enhancedFilter,
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        diagnostics,
      );
    } else {
      validatedRecipes = await _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
        diagnostics: diagnostics,
      );
    }

    _sortRecipesByPantryEase(
      validatedRecipes,
      pantryItems,
      enhancedFilter,
      userProfile,
    );

    if (kDebugMode) {
      diagnostics.logSummary(finalReturned: validatedRecipes.length);
      if (validatedRecipes.isEmpty) {
        print('⚠️  No recipes found after all fallback attempts');
      }
    }

    return validatedRecipes;
  }

  List<CuisineType> _favoriteCuisinesFromProfile(
      Map<String, dynamic> userProfile) {
    final raw = userProfile['favoriteCuisines'];
    if (raw is! List) return [];
    return CuisineTypeExtension.fromUserFavoriteNames(
      raw.map((e) => e.toString()).toList(),
    );
  }

  void _logSpoonacularIncludeSelection(SpoonacularIncludeSelection selection) {
    if (!kDebugMode) return;
    print('\n📦 Spoonacular includeIngredients');
    print('');
    if (selection.includedNames.isEmpty) {
      print('Included: (none — searching without includeIngredients)');
    } else {
      print('Included:');
      for (final name in selection.includedNames) {
        print('  $name');
      }
    }
    if (selection.exclusions.isNotEmpty) {
      print('');
      print('Excluded:');
      for (final item in selection.exclusions) {
        print('  ${item.name} (${item.category.name.toUpperCase()})');
      }
    }
  }

  /// No preference: favorites from account first, then all other cuisines.
  Future<List<Recipe>> _generateNoPreferenceRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
    _GenerationDiagnostics diagnostics,
  ) async {
    final favoriteCuisines = _favoriteCuisinesFromProfile(userProfile);

    if (favoriteCuisines.isEmpty) {
      if (kDebugMode) {
        print(
            '🍽️ No preference: no account favorites — searching all cuisines');
      }
      return _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
        diagnostics: diagnostics,
      );
    }

    final favoriteNames = favoriteCuisines.map((c) => c.displayName).join(', ');
    if (kDebugMode) {
      print(
          '🍽️ No preference: favorites first ($favoriteNames), then other cuisines');
    }

    diagnostics.nextRequestLabel =
        'No-preference batch 1/2: FAVORITES ($favoriteNames)';
    final favoriteBatch = await _generateWithFallbacks(
      enhancedFilter.copyWith(cuisines: favoriteCuisines),
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: true,
      diagnostics: diagnostics,
    );

    diagnostics.nextRequestLabel = 'No-preference batch 2/2: ALL CUISINES';
    final allCuisinesBatch = await _generateWithFallbacks(
      enhancedFilter.copyWith(cuisines: const []),
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: false,
      diagnostics: diagnostics,
    );

    return _mergePrimaryFirst(favoriteBatch, allCuisinesBatch);
  }

  /// User picked specific cuisine(s) — search only those (e.g. Korean → Korean only).
  Future<List<Recipe>> _generateExplicitCuisineRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
    _GenerationDiagnostics diagnostics,
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
      diagnostics: diagnostics,
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
    required _GenerationDiagnostics diagnostics,
  }) async {
    List<Recipe> validatedRecipes = await _tryFetchAndValidateRecipes(
      enhancedFilter,
      pantryIngredientNames,
      pantryItems,
      userProfile,
      enforceCuisine: keepCuisine,
      diagnostics: diagnostics,
    );

    if (validatedRecipes.isNotEmpty) {
      diagnostics.noteFallback(
        'Not triggered (${validatedRecipes.length} recipes available)',
      );
      return validatedRecipes;
    }

    if (enhancedFilter.maxReadyTime != null) {
      if (kDebugMode) {
        print('🔁 No validated recipes found. Retrying without maxReadyTime '
            '(was ${enhancedFilter.maxReadyTime} min)...');
      }
      validatedRecipes = await _tryFetchAndValidateRecipes(
        enhancedFilter.copyWith(maxReadyTime: null),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
        diagnostics: diagnostics,
      );
      if (validatedRecipes.isNotEmpty) {
        diagnostics.noteFallback(
          'Dropped maxReadyTime (was ${enhancedFilter.maxReadyTime} min); '
          '${validatedRecipes.length} recipes available',
        );
        return validatedRecipes;
      }
    }

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
      diagnostics: diagnostics,
    );
    if (validatedRecipes.isNotEmpty) {
      diagnostics.noteFallback(
        'Relaxed health constraints; ${validatedRecipes.length} recipes available',
      );
    } else {
      diagnostics.noteFallback('All fallback attempts returned 0 recipes');
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
    Map<String, dynamic> userProfile,
  ) {
    final counts = RecipeIngredientPantryCounts(
      PantryDeductionService(
        conversionService: _unitConversionService,
        substitutionService: _ingredientSubstitutionService,
      ),
    );

    // Point 3: no preference → onboarding favorites order.
    // Point 4: multi-select → selection order. Others → last.
    final preferredCuisines = filter.isNoPreferenceOnly
        ? _favoriteCuisinesFromProfile(userProfile)
        : filter.explicitCuisines;

    RecipePantrySort.sortByEasiestToMake(
      recipes,
      pantry: pantryItems,
      counts: counts,
      targetServings: filter.servings,
      preferredCuisines: preferredCuisines,
      tiebreaker: (a, b) {
        final usedCmp =
            (b.usedIngredientCount ?? 0).compareTo(a.usedIngredientCount ?? 0);
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
    required _GenerationDiagnostics diagnostics,
  }) async {
    final requestUri = SpoonacularRecipeRepository.buildComplexSearchUri(
      filter,
      pantryIngredientNames,
    );
    diagnostics.recordSpoonacularRequest(requestUri.toString());

    // Fetch recipes from the repository
    final recipes =
        await _recipeRepository.getRecipes(filter, pantryIngredientNames);

    diagnostics.spoonacularCandidates += recipes.length;

    if (kDebugMode) {
      print('\n🔍 RECIPE GENERATION DEBUG:');
      print('Recipes from API: ${recipes.length}');
      print('Filter meal types: ${filter.spoonacularMealTypes}');
      final params = filter.toSpoonacularParams();
      print('Spoonacular search params:');
      for (final entry in params.entries) {
        print('  ${entry.key}=${entry.value}');
      }
      if (pantryIngredientNames.isNotEmpty) {
        print('Pantry includeIngredients: ${pantryIngredientNames.join(', ')}');
      }
      print('User medical conditions: ${userProfile['medicalConditions']}');
      print('User diet type: ${userProfile['dietType']}');
      print('\nAPI recipe list:');
      for (final recipe in recipes) {
        print('  [${recipe.id}] ${recipe.title}');
      }
    }

    // Perform local validation and enhancement
    final validatedRecipes = <Recipe>[];

    for (var recipe in recipes) {
      if (kDebugMode) {
        print('\n📋 Validating recipe: ${recipe.title}');
      }

      // a. Check if pantry has enough ingredients
      final allergies = List<String>.from(userProfile['allergies'] ?? const []);
      final excludedIngredients =
          AllergyFilteringService.parseExcludedIngredients(
        userProfile['excludedIngredients'],
      );
      if (AllergyFilteringService.recipeContainsRestrictions(
        recipe,
        allergies: allergies,
        excludedIngredients: excludedIngredients,
      )) {
        diagnostics.failedHealth++;
        if (kDebugMode) {
          print('  ❌ Contains an allergy or excluded ingredient');
        }
        continue;
      }

      // b. Check if pantry has enough ingredients
      if (!_hasEnoughIngredients(recipe, pantryItems)) {
        diagnostics.failedPantry++;
        if (kDebugMode) {
          print(
              '  ❌ Not enough ingredients (missed: ${recipe.requiredMissedIngredientCount})');
        }
        continue;
      }

      // c. Main ingredient must be in pantry (Point 1 validation gate).
      final mainIngredientResult =
          _mainIngredientValidator.validate(recipe, pantryItems);
      if (!mainIngredientResult.passes) {
        diagnostics.failedMainIngredient++;
        if (kDebugMode) {
          print(
            '  ❌ Main ingredient missing: ${mainIngredientResult.mainIngredientName}'
            ' (${mainIngredientResult.mainCategory?.name ?? 'unknown'})',
          );
        }
        continue;
      }
      if (kDebugMode && !mainIngredientResult.gateSkipped) {
        print(
          '  ✓ Main ingredient in pantry: ${mainIngredientResult.mainIngredientName}'
          ' (${mainIngredientResult.mainCategory?.name ?? 'unknown'})',
        );
      }

      // d. Validate against health constraints (DASH, MyPlate, etc.)
      if (!(await _isHealthCompliant(recipe, userProfile))) {
        diagnostics.failedHealth++;
        if (kDebugMode) {
          print('  ❌ Not health compliant');
        }
        continue;
      }

      // e. Validate against medical condition constraints
      if (!_isMedicalConditionCompliant(recipe, userProfile)) {
        diagnostics.failedMedical++;
        if (kDebugMode) {
          print('  ❌ Not medical condition compliant');
        }
        continue;
      }

      // f. Snacks: drop full meals Spoonacular mis-tags as snack (e.g. fried rice).
      if (!_matchesMealTypeIntent(recipe, filter)) {
        diagnostics.failedMealType++;
        if (kDebugMode) {
          print(
              '  ❌ Does not match meal type intent (${filter.mealType?.displayName})');
        }
        continue;
      }

      // g. Require written cooking steps (exclude video-only Spoonacular entries).
      if (!recipe.hasCookingInstructions) {
        diagnostics.failedInstructions++;
        if (kDebugMode) {
          print('  ❌ No written cooking instructions (video-only or empty)');
        }
        continue;
      }

      if (kDebugMode) {
        print('  ✅ Recipe passed all validations');
      }

      // h. Enhance recipe with pantry data
      final enhancedRecipe = _enhanceRecipeWithPantryData(recipe, pantryItems);

      validatedRecipes.add(enhancedRecipe);
    }

    var results = validatedRecipes;
    if (enforceCuisine && filter.hasExplicitCuisinePreference) {
      final before = results.length;
      results = results
          .where((r) => _matchesSelectedCuisines(r, filter.cuisines))
          .toList();
      final cuisineDropped = before - results.length;
      if (cuisineDropped > 0) {
        diagnostics.failedCuisine += cuisineDropped;
      }
      if (kDebugMode && cuisineDropped > 0) {
        print('  🍛 Cuisine post-filter: $before → ${results.length} recipes');
      }
    }

    diagnostics.validatedPassed += results.length;

    if (kDebugMode) {
      print('Validated recipes: ${results.length}');
      print('Filtered out: ${recipes.length - results.length}');
      if (results.isNotEmpty) {
        print('\n✅ Recipes passing validation:');
        for (final recipe in results) {
          print('  [${recipe.id}] ${recipe.title}');
        }
      }
    }

    return results;
  }

  bool _matchesSelectedCuisines(Recipe recipe, List<CuisineType> selected) {
    final wanted = selected
        .where((c) => c != CuisineType.noPreference)
        .map((c) => c.name.toLowerCase())
        .toSet();
    if (wanted.isEmpty) return true;

    final recipeCuisines = recipe.cuisines.map((c) => c.toLowerCase()).toSet();
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

    final intoleranceEnums = AllergyFilteringService.intolerancesFor(allergies);
    final excludedIngredients =
        AllergyFilteringService.parseExcludedIngredients(
      userProfile['excludedIngredients'],
    );

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
      excludedIngredientNames:
          excludedIngredients.map((ingredient) => ingredient.name).toList(),
    );
  }

  /// When user picks Snacks, exclude obvious full meals Spoonacular still tags as snack.
  bool _matchesMealTypeIntent(Recipe recipe, RecipeFilter filter) {
    if (filter.mealType != MealType.snack) return true;

    final types = recipe.dishTypes.map((t) => t.toLowerCase().trim()).toSet();
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

/// Debug-only counters for generation observation (no effect on ranking/validation).
class _GenerationDiagnostics {
  final RecipeFilter filter;
  final Map<String, dynamic> userProfile;

  int spoonacularCandidates = 0;
  int validatedPassed = 0;
  int failedPantry = 0;
  int failedHealth = 0;
  int failedMedical = 0;
  int failedMealType = 0;
  int failedInstructions = 0;
  int failedCuisine = 0;
  int failedMainIngredient = 0;
  String fallbackStatus = 'Not evaluated';

  /// Label for Spoonacular requests in the current batch (e.g. no-preference).
  /// Stays set across fallback retries until replaced.
  String? nextRequestLabel;

  final List<({String? label, String url})> spoonacularRequests = [];

  _GenerationDiagnostics({
    required this.filter,
    required this.userProfile,
  });

  void noteFallback(String status) {
    fallbackStatus = status;
  }

  void recordSpoonacularRequest(String url) {
    spoonacularRequests.add((label: nextRequestLabel, url: url));
  }

  void logSummary({required int finalReturned}) {
    final cuisines = filter.isNoPreferenceOnly
        ? 'No preference'
        : (filter.explicitCuisines.isEmpty
            ? 'All cuisines'
            : filter.explicitCuisines.map((c) => c.displayName).join(', '));
    final meal =
        filter.spoonacularTypeParam ?? filter.mealType?.displayName ?? 'Any';
    final maxTime =
        filter.maxReadyTime != null ? '${filter.maxReadyTime} min' : 'None';
    final dietType = userProfile['dietType']?.toString() ?? 'Unknown';
    final healthFlags = <String>[
      if (filter.dashCompliant) 'DASH',
      if (filter.myPlateCompliant) 'MyPlate',
      if (filter.veryHealthy) 'veryHealthy',
    ].join(', ');

    print('\n📊 Recipe Generation Summary');
    print('');
    print('Requested:');
    print('- Cuisine: $cuisines');
    print('- Meal type: $meal');
    print('- Max time: $maxTime');
    print('- Health: $dietType${healthFlags.isEmpty ? '' : ' ($healthFlags)'}');
    print('');
    print('Spoonacular:');
    print('- Candidates returned: $spoonacularCandidates');
    if (spoonacularRequests.isNotEmpty) {
      print('- Requests (${spoonacularRequests.length}):');
      for (var i = 0; i < spoonacularRequests.length; i++) {
        final req = spoonacularRequests[i];
        final label = req.label ?? 'Request ${i + 1}';
        print('    ${i + 1}. $label');
        print('       URL: ${req.url}');
        final params = Uri.tryParse(req.url)?.queryParameters ?? const {};
        if (params.isNotEmpty) {
          for (final entry in params.entries) {
            print('         ${entry.key}=${entry.value}');
          }
        }
      }
    }
    print('');
    print('Validation:');
    print('- Passed: $validatedPassed');
    print('- Failed:');
    print('    Pantry: $failedPantry');
    print('    Health: $failedHealth');
    print('    Medical: $failedMedical');
    print('    Meal type: $failedMealType');
    print('    Instructions: $failedInstructions');
    print('    Cuisine: $failedCuisine');
    print('    Main ingredient: $failedMainIngredient');
    print('');
    print('Final:');
    print('- Returned to UI: $finalReturned');
    print('');
    print('Fallback:');
    print('- $fallbackStatus');
  }
}
