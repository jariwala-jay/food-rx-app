import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

abstract class RecipeRepository {
  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients);
  Future<List<Recipe>> getSavedRecipes(String userId);
  Future<void> saveRecipe(String userId, Recipe recipe);
  Future<void> unsaveRecipe(String userId, int recipeId);
  Future<void> cookRecipe(String userId, Recipe recipe);
}
