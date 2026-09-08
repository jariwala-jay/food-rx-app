import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_servings_display.dart';

/// Pantry relevance stats for ranking validated recipes.
class RecipePantryRelevanceScore {
  final double pantryRelevanceScore;
  final int inPantry;
  final int requiredMissing;
  final double expiringBonus;
  final List<MatchedPantryIngredient> matchedIngredients;

  const RecipePantryRelevanceScore({
    required this.pantryRelevanceScore,
    required this.inPantry,
    required this.requiredMissing,
    required this.expiringBonus,
    this.matchedIngredients = const [],
  });

  int get requiredTotal => inPantry + requiredMissing;

  /// Share of required ingredients already in pantry (0.0–1.0).
  /// green / (green + orange)
  double get completionRatio =>
      requiredTotal > 0 ? inPantry / requiredTotal : 1.0;

  /// Sort (Points 2–4):
  /// 1. Required missing ASC (less shopping first)
  /// 2. Completion ratio DESC (more green %)
  /// 3. Pantry relevance score DESC (meaningful matches)
  int compareRankingTo(RecipePantryRelevanceScore other) {
    final needCmp = requiredMissing.compareTo(other.requiredMissing);
    if (needCmp != 0) return needCmp;

    final coverageCmp = other.completionRatio.compareTo(completionRatio);
    if (coverageCmp != 0) return coverageCmp;

    return other.pantryRelevanceScore.compareTo(pantryRelevanceScore);
  }
}

/// @deprecated Use [RecipePantryRelevanceScore] — kept for existing unit tests.
class RecipePantryMatchScore {
  final int inPantry;
  final int requiredMissing;
  final int requiredTotal;

  const RecipePantryMatchScore({
    required this.inPantry,
    required this.requiredMissing,
  }) : requiredTotal = inPantry + requiredMissing;

  double get completionRatio =>
      requiredTotal > 0 ? inPantry / requiredTotal : 1.0;

  int compareEaseTo(RecipePantryMatchScore other) {
    final needCmp = requiredMissing.compareTo(other.requiredMissing);
    if (needCmp != 0) return needCmp;

    final haveCmp = other.inPantry.compareTo(inPantry);
    if (haveCmp != 0) return haveCmp;

    return other.completionRatio.compareTo(completionRatio);
  }
}

/// Sorts validated recipes: easiest to shop/cook first, then cuisine preference.
class RecipePantrySort {
  static const int otherCuisinePriority = 999;

  static RecipePantryRelevanceScore score(
    Recipe recipe,
    List<PantryItem> pantry,
    RecipeIngredientPantryCounts counts,
  ) {
    final matched = counts.matchedRequiredIngredients(recipe, pantry);
    final inPantry = matched.length;
    final requiredMissing = counts.requiredMissingCount(recipe, pantry);

    // One pantry item contributes its category weight once per recipe
    // (multiple recipe lines matching the same row do not inflate score).
    final seenPantryIds = <String>{};
    double categoryWeightSum = 0;
    for (final match in matched) {
      if (seenPantryIds.add(match.pantryItem.id)) {
        categoryWeightSum += match.categoryWeight;
      }
    }

    final seenExpiringPantryIds = <String>{};
    double expiringBonus = 0;
    for (final match in matched) {
      if (!match.isExpiringSoon) continue;
      if (seenExpiringPantryIds.add(match.pantryItem.id)) {
        expiringBonus += IngredientNutritionalCategoryResolver.expiringBonusPerItem;
      }
    }
    if (expiringBonus > IngredientNutritionalCategoryResolver.maxExpiringBonus) {
      expiringBonus = IngredientNutritionalCategoryResolver.maxExpiringBonus;
    }

    return RecipePantryRelevanceScore(
      pantryRelevanceScore: categoryWeightSum + expiringBonus,
      inPantry: inPantry,
      requiredMissing: requiredMissing,
      expiringBonus: expiringBonus,
      matchedIngredients: matched,
    );
  }

  /// Builds cuisine priority map: index 0 = highest preference, others = 999.
  static Map<String, int> cuisinePriorityMap(List<CuisineType> preferred) {
    final map = <String, int>{};
    for (var i = 0; i < preferred.length; i++) {
      final cuisine = preferred[i];
      if (cuisine == CuisineType.noPreference) continue;
      // apiName, not name — Spoonacular tags recipes with the space-separated
      // display form (e.g. "Middle Eastern"), not the enum's camelCase, and
      // cuisinePriorityFor keys its lookup off that same tag string.
      map[cuisine.apiName.toLowerCase()] = i;
    }
    return map;
  }

  /// Lowest priority among recipe cuisine tags; [otherCuisinePriority] if none match.
  static int cuisinePriorityFor(
    Recipe recipe,
    Map<String, int> priorityByCuisine,
  ) {
    if (priorityByCuisine.isEmpty) return otherCuisinePriority;

    var best = otherCuisinePriority;
    for (final tag in recipe.cuisines) {
      final key = tag.toLowerCase().trim();
      final priority = priorityByCuisine[key];
      if (priority != null && priority < best) {
        best = priority;
      }
    }
    return best;
  }

  /// Sorts easiest-to-make first, then interleaves cuisines round-robin
  /// within each missing-ingredient-count group instead of blocking them
  /// (American, Chinese, ... -> American, Indian, Chinese, ...). Missing
  /// count still hard-gates the order; only same-count recipes get shuffled
  /// together, and "other"/unselected cuisines stay last within their group.
  static void sortByEasiestToMake(
    List<Recipe> recipes, {
    required List<PantryItem> pantry,
    required RecipeIngredientPantryCounts counts,
    int? targetServings,
    List<CuisineType> preferredCuisines = const [],
    int Function(Recipe a, Recipe b)? tiebreaker,
    Random? random,
  }) {
    final scores = <int, RecipePantryRelevanceScore>{};
    final cuisinePriority = cuisinePriorityMap(preferredCuisines);
    final cuisineRanks = <int, int>{};

    for (final recipe in recipes) {
      final forCounts = RecipeServingsDisplay.forCounts(
        recipe,
        targetServings: targetServings,
      );
      scores[recipe.id] = score(forCounts, pantry, counts);
      cuisineRanks[recipe.id] = cuisinePriorityFor(recipe, cuisinePriority);
    }

    int easeCompare(Recipe a, Recipe b) {
      final pantryCmp = scores[a.id]!.compareRankingTo(scores[b.id]!);
      if (pantryCmp != 0) return pantryCmp;
      return tiebreaker?.call(a, b) ?? 0;
    }

    final easeSorted = List<Recipe>.of(recipes)..sort(easeCompare);

    final effectiveRandom = random ?? Random();
    final cuisineVisitOrder = cuisinePriority.values.toSet().toList()..sort();
    cuisineVisitOrder.shuffle(effectiveRandom);

    // Group by missing-ingredient count (not the full ease comparator) so
    // groups are big enough for interleaving to actually show up.
    final merged = <Recipe>[];
    var start = 0;
    while (start < easeSorted.length) {
      final groupMissing = scores[easeSorted[start].id]!.requiredMissing;
      var end = start + 1;
      while (end < easeSorted.length &&
          scores[easeSorted[end].id]!.requiredMissing == groupMissing) {
        end++;
      }
      final tiedGroup = easeSorted.sublist(start, end);
      // No cuisine preference at all → nothing to interleave by, so shuffle
      // within the tied group instead of preserving whatever order the
      // recipes happened to arrive in (e.g. a favorites-cuisine batch
      // fetched before an all-cuisines batch). Only recipes fully tied by
      // the complete ease comparator (coverage/score/tiebreaker, not just
      // missing-count) get shuffled together, so a real tiebreaker (e.g.
      // health score) still orders recipes that merely share a missing
      // count.
      merged.addAll(
        cuisineVisitOrder.isEmpty
            ? _shuffleFullyTiedRuns(tiedGroup, easeCompare, effectiveRandom)
            : _interleaveByCuisine(tiedGroup, cuisineRanks, cuisineVisitOrder),
      );
      start = end;
    }

    recipes
      ..clear()
      ..addAll(merged);

    if (kDebugMode) {
      _logPantryScores(recipes, scores, cuisineRanks);
    }
  }

  /// [group] is already sorted by [compare]. Shuffles only within
  /// contiguous runs where consecutive recipes compare equal (0) — i.e.
  /// genuinely indistinguishable by ease/tiebreaker — leaving the relative
  /// order between distinct runs untouched.
  static List<Recipe> _shuffleFullyTiedRuns(
    List<Recipe> group,
    int Function(Recipe a, Recipe b) compare,
    Random random,
  ) {
    if (group.length <= 1) return group;

    final result = <Recipe>[];
    var start = 0;
    while (start < group.length) {
      var end = start + 1;
      while (end < group.length && compare(group[start], group[end]) == 0) {
        end++;
      }
      final run = group.sublist(start, end);
      if (run.length > 1) run.shuffle(random);
      result.addAll(run);
      start = end;
    }
    return result;
  }

  /// Round-robin interleaves a group of equally-easy recipes across
  /// [cuisineVisitOrder]; recipes in "other" (unselected) cuisines are
  /// appended last, preserving their relative order.
  static List<Recipe> _interleaveByCuisine(
    List<Recipe> tiedRecipes,
    Map<int, int> cuisineRanks,
    List<int> cuisineVisitOrder,
  ) {
    if (tiedRecipes.length <= 1) return tiedRecipes;

    final buckets = <int, List<Recipe>>{};
    for (final recipe in tiedRecipes) {
      buckets.putIfAbsent(cuisineRanks[recipe.id]!, () => []).add(recipe);
    }

    final queues = cuisineVisitOrder
        .where(buckets.containsKey)
        .map((priority) => Queue<Recipe>.of(buckets[priority]!))
        .toList();

    final result = <Recipe>[];
    while (queues.any((queue) => queue.isNotEmpty)) {
      for (final queue in queues) {
        if (queue.isNotEmpty) result.add(queue.removeFirst());
      }
    }
    final otherBucket = buckets[otherCuisinePriority];
    if (otherBucket != null) result.addAll(otherBucket);
    return result;
  }

  static void _logPantryScores(
    List<Recipe> recipes,
    Map<int, RecipePantryRelevanceScore> scores,
    Map<int, int> cuisineRanks,
  ) {
    debugPrint('\n📊 Recipe Pantry Scores (ranked):');
    for (final recipe in recipes) {
      final s = scores[recipe.id]!;
      final coveragePct = (s.completionRatio * 100).round();
      final cuisineRank = cuisineRanks[recipe.id] ?? otherCuisinePriority;
      debugPrint('\n${recipe.title}');
      debugPrint('  missing=${s.requiredMissing}');
      debugPrint('  coverage=$coveragePct%');
      debugPrint('  score=${s.pantryRelevanceScore.toStringAsFixed(1)}');
      debugPrint(
        '  cuisinePriority=${cuisineRank == otherCuisinePriority ? 'other' : cuisineRank}'
        '${recipe.cuisines.isEmpty ? '' : ' (${recipe.cuisines.join(', ')})'}',
      );
      if (s.matchedIngredients.isNotEmpty) {
        debugPrint('  matched:');
        final scoredPantryIds = <String>{};
        for (final m in s.matchedIngredients) {
          final contributes = scoredPantryIds.add(m.pantryItem.id);
          final weightLabel = contributes
              ? m.categoryWeight.toStringAsFixed(1)
              : '0 (deduped)';
          debugPrint(
            '    ${m.recipeIngredientLabel}(${m.category.name.toUpperCase()})'
            '=$weightLabel'
            ' via ${m.pantryItem.name}',
          );
        }
      }
      if (s.expiringBonus > 0) {
        debugPrint('  expiringBonus=${s.expiringBonus.toStringAsFixed(1)}');
      }
    }
  }
}
