import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';

class RecipeGenerationService {
  final RecipeRepository _recipeRepository;
  final UnitConversionService _unitConversionService;
  final FoodCategoryService _foodCategoryService;
  final IngredientSubstitutionService _ingredientSubstitutionService;

  RecipeGenerationService({
    required RecipeRepository recipeRepository,
    required UnitConversionService unitConversionService,
    required FoodCategoryService foodCategoryService,
    required IngredientSubstitutionService ingredientSubstitutionService,
  })  : _recipeRepository = recipeRepository,
        _unitConversionService = unitConversionService,
        _foodCategoryService = foodCategoryService,
        _ingredientSubstitutionService = ingredientSubstitutionService;

  Future<List<Recipe>> generateRecipes({
    required RecipeFilter filter,
    required List<PantryItem> pantryItems,
    required Map<String, dynamic> userProfile,
  }) async {
    final pantryIngredientNames = pantryItems.map((e) => e.name).toList();

    // 1. Enhance filter with user-specific dietary constraints
    final enhancedFilter = _enhanceFilterWithUserProfile(filter, userProfile);

    // 2. Fetch recipes from the repository with enhanced filter
    final recipes = await _recipeRepository.getRecipes(
        enhancedFilter, pantryIngredientNames);

    if (kDebugMode) {
      print('\n🔍 RECIPE GENERATION DEBUG:');
      print('Recipes from API: ${recipes.length}');
      print('User Profile: $userProfile');
    }

    // 3. Perform local validation and enhancement
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
      if (!_isHealthCompliant(recipe, userProfile)) {
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
      print('\n📊 FINAL RESULTS:');
      print('API recipes: ${recipes.length}');
      print('Validated recipes: ${validatedRecipes.length}');
      print('Filtered out: ${recipes.length - validatedRecipes.length}');
    }

    // 4. Sort recipes by health score and ingredient availability
    validatedRecipes.sort((a, b) {
      // Primary sort: by used ingredient count (more available ingredients first)
      final usedIngredientComparison =
          (b.usedIngredientCount ?? 0).compareTo(a.usedIngredientCount ?? 0);
      if (usedIngredientComparison != 0) return usedIngredientComparison;

      // Secondary sort: by health score (healthier recipes first)
      return b.healthScore.compareTo(a.healthScore);
    });

    return validatedRecipes;
  }

  /// Enhance filter with user-specific dietary constraints based on medical conditions and diet type
  RecipeFilter _enhanceFilterWithUserProfile(
      RecipeFilter filter, Map<String, dynamic> userProfile) {
    final medicalConditions =
        List<String>.from(userProfile['medicalConditions'] ?? []);
    final healthGoals = List<String>.from(userProfile['healthGoals'] ?? []);
    final dietType = userProfile['dietType'] as String?;
    final allergies = List<String>.from(userProfile['allergies'] ?? []);

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

    // Determine diet compliance based on user's diet type and medical conditions
    bool dashCompliant = false;
    bool myPlateCompliant = false;

    if (dietType == 'DASH' ||
        medicalConditions.contains('Hypertension') ||
        healthGoals.contains('Lower blood pressure')) {
      dashCompliant = true;
    } else {
      myPlateCompliant = true;
    }

    return filter.copyWith(
      medicalConditions: medicalConditionEnums,
      intolerances: [...filter.intolerances, ...intoleranceEnums],
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      veryHealthy: true, // Always prefer healthier options
    );
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

  bool _isHealthCompliant(Recipe recipe, Map<String, dynamic> userProfile) {
    final dietPlan = userProfile['dietType'];

    if (dietPlan == 'DASH') {
      return _isDashCompliant(recipe);
    } else if (dietPlan == 'MyPlate') {
      return _isMyPlateCompliant(recipe);
    }

    return true; // Default to allowing recipe if no specific diet plan
  }

  bool _isDashCompliant(Recipe recipe) {
    final nutrition = recipe.nutrition;
    if (nutrition == null) {
      return true; // Allow if nutrition data is not available
    }

    // DASH diet guidelines per serving (more practical limits)
    final sodium = _getNutrientAmount(nutrition, 'Sodium');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');
    final fiber = _getNutrientAmount(nutrition, 'Fiber');
    final potassium = _getNutrientAmount(nutrition, 'Potassium');

    // DASH compliance checks (more practical)
    if (sodium > 400) {
      return false; // Max 800mg sodium per serving (more practical than 600mg)
    }
    if (saturatedFat > 8) {
      return false; // Max 8g saturated fat per serving (slightly more lenient)
    }
    if (fiber < 2) {
      return false; // Min 2g fiber per serving (more achievable)
    }

    return true;
  }

  bool _isMyPlateCompliant(Recipe recipe) {
    final nutrition = recipe.nutrition;
    if (nutrition == null)
      return true; // Allow if nutrition data is not available

    // MyPlate guidelines per serving (more flexible than DASH)
    final sodium = _getNutrientAmount(nutrition, 'Sodium');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');
    final sugar = _getNutrientAmount(nutrition, 'Sugar');
    final calories = _getNutrientAmount(nutrition, 'Calories');

    // MyPlate compliance checks (more lenient)
    if (sodium > 800)
      return false; // Max 800mg sodium per serving (2300mg/day ÷ 3 meals)
    if (saturatedFat > 10) return false; // Max 10g saturated fat per serving
    if (sugar > 30) return false; // Max 30g sugar per serving
    if (calories > 600)
      return false; // Max 600 calories per serving for main dishes

    return true;
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
    final calories = _getNutrientAmount(nutrition, 'Calories');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');
    final protein = _getNutrientAmount(nutrition, 'Protein');
    final fiber = _getNutrientAmount(nutrition, 'Fiber');

    // Weight management guidelines
    if (calories > 400) return false; // Max 400 calories per serving
    if (saturatedFat > 5) return false; // Max 5g saturated fat per serving
    if (protein < 15) return false; // Min 15g protein per serving (satiety)
    if (fiber < 5) return false; // Min 5g fiber per serving (satiety)

    return true;
  }

  bool _isHypertensionCompliant(Recipe recipe, Nutrition nutrition) {
    final sodium = _getNutrientAmount(nutrition, 'Sodium');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');
    final potassium = _getNutrientAmount(nutrition, 'Potassium');

    // DASH guidelines for hypertension (practical approach)
    if (sodium > 400) {
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
