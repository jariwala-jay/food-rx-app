import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

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

    // 1. Fetch recipes from the repository
    final recipes =
        await _recipeRepository.getRecipes(filter, pantryIngredientNames);

    // 2. Perform local validation and enhancement
    final validatedRecipes = <Recipe>[];
    for (var recipe in recipes) {
      // a. Check if pantry has enough ingredients
      if (!_hasEnoughIngredients(recipe, pantryItems)) {
        continue;
      }

      // b. Validate against health constraints (DASH, MyPlate, etc.)
      if (!_isHealthCompliant(recipe, userProfile)) {
        continue;
      }

      // c. Enhance recipe with pantry data
      final enhancedRecipe = _enhanceRecipeWithPantryData(recipe, pantryItems);

      validatedRecipes.add(enhancedRecipe);
    }

    // 3. The API already sorts by `min-missing-ingredients`. No need to re-sort here.
    // validatedRecipes.sort((a, b) =>
    //     (b.usedIngredientCount ?? 0).compareTo(a.usedIngredientCount ?? 0));

    return validatedRecipes;
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
    final dietPlan = userProfile['dietPlan'];
    if (dietPlan == 'DASH') {
      final sodium = recipe.nutrition?.nutrients
              .firstWhere((n) => n.name == 'Sodium',
                  orElse: () => Nutrient(name: 'Sodium', amount: 0, unit: 'mg'))
              .amount ??
          0;
      if (sodium > 500)
        return false; // Strict sodium limit for DASH per serving
    }
    // Add more compliance checks for MyPlate, etc.
    return true;
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
