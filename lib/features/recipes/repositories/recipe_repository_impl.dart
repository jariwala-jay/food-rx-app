import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/mongo_recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';

class RecipeRepositoryImpl implements RecipeRepository {
  final SpoonacularRecipeRepository _spoonacularRecipeRepository;
  final MongoRecipeRepository _mongoRecipeRepository;

  RecipeRepositoryImpl(
      this._spoonacularRecipeRepository, this._mongoRecipeRepository);

  @override
  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients) {
    return _spoonacularRecipeRepository.getRecipes(filter, pantryIngredients);
  }

  @override
  Future<List<Recipe>> getSavedRecipes(String userId) {
    return _mongoRecipeRepository.getSavedRecipes(userId);
  }

  @override
  Future<void> saveRecipe(String userId, Recipe recipe) {
    return _mongoRecipeRepository.saveRecipe(userId, recipe);
  }

  @override
  Future<void> unsaveRecipe(String userId, int recipeId) {
    return _mongoRecipeRepository.unsaveRecipe(userId, recipeId);
  }

  @override
  Future<void> cookRecipe(String userId, Recipe recipe) {
    return _mongoRecipeRepository.cookRecipe(userId, recipe);
  }
}
