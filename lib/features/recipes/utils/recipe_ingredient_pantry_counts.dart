import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

/// Pantry match counts aligned with [RecipeDetailPage] badges and ingredient list.
class RecipeIngredientPantryCounts {
  final PantryDeductionService _pantryService;

  const RecipeIngredientPantryCounts(this._pantryService);

  static String matchName(RecipeIngredient ingredient) {
    final n = ingredient.nameClean.trim();
    return n.isNotEmpty ? n : ingredient.name;
  }

  bool isInPantry(RecipeIngredient ingredient, List<PantryItem> pantry) {
    return _pantryService.hasPantryMatchForIngredient(
      matchName(ingredient),
      pantry,
    );
  }

  int inPantryCount(Recipe recipe, List<PantryItem> pantry) {
    return recipe.extendedIngredients
        .where((i) => !i.isOptionalIngredient && isInPantry(i, pantry))
        .length;
  }

  int requiredMissingCount(Recipe recipe, List<PantryItem> pantry) {
    return recipe.extendedIngredients
        .where(
          (i) => !i.isOptionalIngredient && !isInPantry(i, pantry),
        )
        .length;
  }
}
