import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoRecipeRepository {
  final MongoDBService _mongoDBService;
  final String _savedRecipesCollection = 'saved_recipes';
  final String _cookedRecipesCollection = 'cooked_recipes';

  MongoRecipeRepository(this._mongoDBService);

  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients) {
    // This is handled by Spoonacular, so we don't implement it here.
    throw UnimplementedError(
        'getRecipes is not implemented in MongoRecipeRepository');
  }

  Future<List<Recipe>> getSavedRecipes(String userId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_savedRecipesCollection);
    final docs = await collection.find(where.eq('userId', userId)).toList();
    return docs.map((doc) => Recipe.fromJson(doc['recipe'])).toList();
  }

  Future<void> saveRecipe(String userId, Recipe recipe) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_savedRecipesCollection);
    await collection.insertOne({
      'userId': userId,
      'recipeId': recipe.id,
      'recipe': recipe.toJson(),
      'savedAt': DateTime.now(),
    });
  }

  Future<void> unsaveRecipe(String userId, int recipeId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_savedRecipesCollection);
    await collection
        .deleteOne(where.eq('userId', userId).eq('recipeId', recipeId));
  }

  Future<void> cookRecipe(String userId, Recipe recipe) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_cookedRecipesCollection);
    await collection.insertOne({
      'userId': userId,
      'recipeId': recipe.id,
      'recipe': recipe.toJson(),
      'cookedAt': DateTime.now(),
    });
  }
}
