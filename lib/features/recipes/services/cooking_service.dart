import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/recipes/domain/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/services/meal_logging_service.dart';

class CookingService {
  final PantryController _pantryController;
  final RecipeRepository _recipeRepository;
  final MealLoggingService _mealLoggingService;

  CookingService({
    required PantryController pantryController,
    required RecipeRepository recipeRepository,
    required MealLoggingService mealLoggingService,
  })  : _pantryController = pantryController,
        _recipeRepository = recipeRepository,
        _mealLoggingService = mealLoggingService;

  Future<void> cookRecipe({
    required String userId,
    required Recipe recipe,
    required int servingsConsumed,
    required int servingsToDeduct,
    required String dietType,
  }) async {
    // 1. Deduct ingredients from pantry
    await _pantryController.deductIngredientsForRecipe(
      recipe,
      servingsToDeduct: servingsToDeduct,
    );

    // 2. Log the meal in user's history
    await _recipeRepository.cookRecipe(userId, recipe);

    // 3. Update diet trackers
    await _mealLoggingService.logMealConsumption(
      recipe: recipe,
      servingsConsumed: servingsConsumed,
      userId: userId,
      dietType: dietType,
    );
  }
}
