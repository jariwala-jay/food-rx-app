import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/http_recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';

class RecipeRepositoryImpl implements RecipeRepository {
  final SpoonacularRecipeRepository _spoonacularRecipeRepository;
  final HttpRecipeRepository _httpRecipeRepository = HttpRecipeRepository();

  RecipeRepositoryImpl(this._spoonacularRecipeRepository);

  @override
  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients) {
    return _spoonacularRecipeRepository.getRecipes(filter, pantryIngredients);
  }

  @override
  Future<List<Recipe>> getSavedRecipes(String userId) {
    return _httpRecipeRepository.getSavedRecipes(userId);
  }

  @override
  Future<void> saveRecipe(String userId, Recipe recipe) {
    return _httpRecipeRepository.saveRecipe(userId, recipe);
  }

  @override
  Future<void> unsaveRecipe(String userId, int recipeId) {
    return _httpRecipeRepository.unsaveRecipe(userId, recipeId);
  }

  @override
  Future<void> cookRecipe(String userId, Recipe recipe) {
    return _httpRecipeRepository.cookRecipe(userId, recipe);
  }

  @override
  Future<List<Map<String, dynamic>>> getPreparedRaw(String userId) {
    return _httpRecipeRepository.getPreparedRecipes(userId);
  }

  @override
  Future<void> logPreparedCook(
    String userId,
    Recipe recipe,
    double totalServings,
    double consumedServings,
  ) {
    return _httpRecipeRepository.logPreparedCook(
      userId: userId,
      recipe: recipe,
      totalServings: totalServings,
      consumedServings: consumedServings,
    );
  }

  @override
  Future<void> logPreparedConsumption(
    String userId,
    int recipeId,
    double servingsConsumed,
  ) {
    return _httpRecipeRepository.logPreparedConsumption(
      userId: userId,
      recipeId: recipeId,
      servingsConsumed: servingsConsumed,
    );
  }
}
