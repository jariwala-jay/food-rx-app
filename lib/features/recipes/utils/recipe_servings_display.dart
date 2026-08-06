import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

/// Recipe scaled to [targetServings] for display counts (badges, validation).
class RecipeServingsDisplay {
  static final RecipeScalingService _scalingService = RecipeScalingService(
    conversionService: UnitConversionService(),
  );

  static Recipe forCounts(Recipe recipe, {int? targetServings}) {
    final target = targetServings;
    final original = recipe.servings;

    if (target == null ||
        target <= 0 ||
        original <= 0 ||
        target == original) {
      return recipe;
    }

    try {
      return Recipe.fromJson(
        _scalingService.scaleRecipe(
          originalRecipe: recipe.toJson(),
          targetServings: target,
        ),
      );
    } catch (_) {
      return recipe;
    }
  }
}
