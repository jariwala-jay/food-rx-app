import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';

/// One required recipe line matched to a pantry row (for relevance scoring).
class MatchedPantryIngredient {
  final RecipeIngredient recipeIngredient;
  final PantryItem pantryItem;
  final IngredientNutritionalCategory category;
  final bool isExpiringSoon;

  const MatchedPantryIngredient({
    required this.recipeIngredient,
    required this.pantryItem,
    required this.category,
    required this.isExpiringSoon,
  });

  String get recipeIngredientLabel =>
      RecipeIngredientPantryCounts.matchName(recipeIngredient);

  double get categoryWeight => IngredientNutritionalCategoryResolver.weightFor(
        category,
      );
}

/// Pantry match stats aligned with [RecipeDetailPage] badges and ingredient list.
class RecipeIngredientPantryCounts {
  final PantryDeductionService _pantryService;

  const RecipeIngredientPantryCounts(this._pantryService);

  static String matchName(RecipeIngredient ingredient) {
    final n = ingredient.nameClean.trim();
    return n.isNotEmpty ? n : ingredient.name;
  }

  List<PantryItem> _availablePantry(List<PantryItem> pantry) =>
      pantry.where((item) => !item.isExpired).toList();

  bool isInPantry(RecipeIngredient ingredient, List<PantryItem> pantry) {
    return _pantryService.hasPantryMatchForIngredient(
      matchName(ingredient),
      _availablePantry(pantry),
    );
  }

  List<RecipeIngredient> _uniqueIngredients(Recipe recipe) =>
      RecipeIngredient.mergeDuplicateLines(recipe.extendedIngredients);

  int inPantryCount(Recipe recipe, List<PantryItem> pantry) {
    return _uniqueIngredients(recipe)
        .where((i) => !i.isOptionalIngredient && isInPantry(i, pantry))
        .length;
  }

  int requiredMissingCount(Recipe recipe, List<PantryItem> pantry) {
    return _uniqueIngredients(recipe)
        .where(
          (i) => !i.isOptionalIngredient && !isInPantry(i, pantry),
        )
        .length;
  }

  /// Required recipe lines that match non-expired pantry rows, with category metadata.
  List<MatchedPantryIngredient> matchedRequiredIngredients(
    Recipe recipe,
    List<PantryItem> pantry,
  ) {
    final available = _availablePantry(pantry);
    final matched = <MatchedPantryIngredient>[];

    for (final ingredient in _uniqueIngredients(recipe)) {
      if (ingredient.isOptionalIngredient) continue;

      final name = matchName(ingredient);
      final pantryMatches = _pantryService.findMatchingPantryItems(
        name,
        available,
      );
      if (pantryMatches.isEmpty) continue;

      final pantryItem = pantryMatches.first;
      final category = IngredientNutritionalCategoryResolver.resolve(
        ingredientName: name,
        pantryCategoryKey: pantryItem.category,
      );

      matched.add(
        MatchedPantryIngredient(
          recipeIngredient: ingredient,
          pantryItem: pantryItem,
          category: category,
          isExpiringSoon: IngredientNutritionalCategoryResolver.isExpiringSoon(
            pantryItem.expirationDate,
          ),
        ),
      );
    }

    return matched;
  }
}
