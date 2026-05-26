import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_servings_display.dart';

/// Pantry match stats for one recipe (same rules as green/orange badges).
class RecipePantryMatchScore {
  final int inPantry;
  final int requiredMissing;
  final int requiredTotal;

  const RecipePantryMatchScore({
    required this.inPantry,
    required this.requiredMissing,
  }) : requiredTotal = inPantry + requiredMissing;

  /// Share of required ingredients already in pantry (0.0–1.0).
  double get completionRatio =>
      requiredTotal > 0 ? inPantry / requiredTotal : 1.0;

  /// Sort: fewer items to buy first, then more in pantry, then higher %.
  int compareEaseTo(RecipePantryMatchScore other) {
    final needCmp = requiredMissing.compareTo(other.requiredMissing);
    if (needCmp != 0) return needCmp;

    final haveCmp = other.inPantry.compareTo(inPantry);
    if (haveCmp != 0) return haveCmp;

    final ratioCmp = other.completionRatio.compareTo(completionRatio);
    if (ratioCmp != 0) return ratioCmp;

    return 0;
  }
}

/// Sorts recipes so the easiest to make (fewest shopping items) appear first.
class RecipePantrySort {
  static RecipePantryMatchScore score(
    Recipe recipe,
    List<PantryItem> pantry,
    RecipeIngredientPantryCounts counts,
  ) {
    return RecipePantryMatchScore(
      inPantry: counts.inPantryCount(recipe, pantry),
      requiredMissing: counts.requiredMissingCount(recipe, pantry),
    );
  }

  static void sortByEasiestToMake(
    List<Recipe> recipes, {
    required List<PantryItem> pantry,
    required RecipeIngredientPantryCounts counts,
    int? targetServings,
    int Function(Recipe a, Recipe b)? tiebreaker,
  }) {
    final scores = <int, RecipePantryMatchScore>{};
    for (final recipe in recipes) {
      final forCounts = RecipeServingsDisplay.forCounts(
        recipe,
        targetServings: targetServings,
      );
      scores[recipe.id] = score(forCounts, pantry, counts);
    }

    recipes.sort((a, b) {
      final pantryCmp = scores[a.id]!.compareEaseTo(scores[b.id]!);
      if (pantryCmp != 0) return pantryCmp;
      return tiebreaker?.call(a, b) ?? 0;
    });
  }
}
