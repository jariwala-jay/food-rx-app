import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients);
  Future<List<Recipe>> getSavedRecipes(String userId);
  Future<void> saveRecipe(String userId, Recipe recipe);
  Future<void> unsaveRecipe(String userId, int recipeId);
  Future<void> cookRecipe(String userId, Recipe recipe);

  /// Prepared recipes (leftovers from "I Cooked This").
  Future<List<Map<String, dynamic>>> getPreparedRaw(String userId);
  Future<void> logPreparedCook(
    String userId,
    Recipe recipe,
    double totalServings,
    double consumedServings,
  );
  Future<void> logPreparedConsumption(
    String userId,
    int recipeId,
    double servingsConsumed,
  );
}
