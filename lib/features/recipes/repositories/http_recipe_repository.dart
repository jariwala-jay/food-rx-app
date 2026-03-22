import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

/// Saved/cooked recipes via API (replaces MongoRecipeRepository for persistence).
class HttpRecipeRepository {
  Future<List<Recipe>> getSavedRecipes(String userId) async {
    final list = await ApiClient.get('/recipes/saved');
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((d) {
          final recipe = d['recipe'];
          if (recipe is Map<String, dynamic>) return Recipe.fromJson(recipe);
          return null;
        })
        .whereType<Recipe>()
        .toList();
  }

  Future<void> saveRecipe(String userId, Recipe recipe) async {
    await ApiClient.post('/recipes/saved', body: {
      'recipeId': recipe.id,
      'recipe': recipe.toJson(),
    });
  }

  Future<void> unsaveRecipe(String userId, int recipeId) async {
    await ApiClient.delete('/recipes/saved/$recipeId');
  }

  Future<void> cookRecipe(String userId, Recipe recipe) async {
    await ApiClient.post('/recipes/cooked', body: {
      'recipeId': recipe.id,
      'recipe': recipe.toJson(),
    });
  }

  /// List prepared recipes (leftover servings) for the current user.
  Future<List<Map<String, dynamic>>> getPreparedRecipes(String userId) async {
    final list = await ApiClient.get('/recipes/prepared');
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  /// Log cooking and store leftover servings (total - consumed).
  Future<void> logPreparedCook({
    required String userId,
    required Recipe recipe,
    required double totalServings,
    required double consumedServings,
  }) async {
    await ApiClient.post('/recipes/prepared/cook', body: {
      'recipeId': recipe.id,
      'recipe': recipe.toJson(),
      'totalServings': totalServings,
      'consumedServings': consumedServings,
    });
  }

  /// Log consumption from a prepared recipe's leftover (decreases remaining).
  Future<void> logPreparedConsumption({
    required String userId,
    required int recipeId,
    required double servingsConsumed,
  }) async {
    await ApiClient.post('/recipes/prepared/consume', body: {
      'recipeId': recipeId,
      'servingsConsumed': servingsConsumed,
    });
  }
}
