import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/models/excluded_ingredient.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/utils/levenshtein.dart';

/// A curated ingredient close enough to a typed query to suggest — pure/
/// offline, no network involved.
class IngredientSuggestion {
  final Ingredient ingredient;
  final String category;
  final double similarity;

  const IngredientSuggestion({
    required this.ingredient,
    required this.category,
    required this.similarity,
  });
}

class _Candidate {
  final Ingredient ingredient;
  final String category;
  final List<String> normalizedTokens;

  const _Candidate({
    required this.ingredient,
    required this.category,
    required this.normalizedTokens,
  });
}

/// Splits ingredient-search suggestions into two distinct kinds, offered
/// only when a search comes back with no real matches (local or
/// Spoonacular). Deliberately offline throughout — only ever looks at the
/// app's own curated category data, never calls an API.
///
///  - [findRelatedSuggestion]: the candidate is recognizably the same
///    ingredient the user is describing, just phrased differently
///    ("pickled onions" -> "Onions", "fresh spinach" -> "Spinach"). Shown
///    as "Did you mean?" — a related item worth adding *instead*.
///  - [findTypoCorrection]: the candidate is a spelling fix for what was
///    typed ("cocnut" -> "Coconut Oil"). Meant for a "search instead for
///    X?" prompt near the search field — a correction to what they meant
///    to type, not a different suggestion.
///
/// Word/phrase matching reuses [ExcludedIngredient.normalize] — the same
/// stopword-stripping + singularization already relied on for allergy
/// matching — rather than a second, weaker normalizer. Levenshtein
/// (typo) matching is separate and unaffected by that normalization.
class IngredientFuzzyMatcher {
  IngredientFuzzyMatcher._();

  /// Levenshtein similarity below this is treated as unrelated, not a
  /// typo. Tuned against real curated data — see
  /// ingredient_fuzzy_matcher_test.dart. At 0.75, single-edit typos
  /// ("cocnut", "brocoli", "swet potato") match correctly; going higher
  /// (0.8+) starts losing some of those. Going lower starts catching
  /// double-edit typos too (e.g. "bananna" needs ~0.71) but increases the
  /// risk of spelling-similar-but-unrelated suggestions, so this stays at
  /// the top of that safer range.
  static const double defaultThreshold = 0.75;

  /// A multi-word candidate qualifies for the partial-overlap tier once at
  /// least this fraction of its own words appear as exact words in the
  /// query (e.g. "grond beef" -> "Ground Beef" via the exact "beef" word,
  /// 1 of 2 = 0.5).
  static const double _wordOverlapThreshold = 0.5;

  /// Every category with its own curated item list — the two "group"
  /// categories (fruits/vegetables) hold no items directly, only their
  /// Fresh/Frozen/Canned subcategories do.
  static List<String> _candidateCategoryKeys(bool isFoodPantryItem) {
    final keys = <String>{};
    for (final cat in foodPantryCategories) {
      final key = cat['key']!;
      final subs = foodPantrySubcategories[key];
      if (subs != null) {
        keys.addAll(subs.map((s) => s['key']!));
      } else {
        keys.add(key);
      }
    }
    if (!isFoodPantryItem) {
      for (final cat in otherPantryItemCategories) {
        final key = cat['key']!;
        if (!foodPantrySubcategories.containsKey(key)) {
          keys.add(key);
        }
      }
    }
    return keys.toList();
  }

  static List<String> _normalizedTokens(String text) => ExcludedIngredient
      .normalize(text)
      .split(' ')
      .where((t) => t.isNotEmpty)
      .toList();

  static List<_Candidate> _collectCandidates(bool isFoodPantryItem) {
    final result = <_Candidate>[];
    for (final categoryKey in _candidateCategoryKeys(isFoodPantryItem)) {
      final items = getCommonItemsForCategory(categoryKey, isFoodPantryItem);
      for (final itemData in items) {
        final name = itemData['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final asset = itemData['imageAsset'] as String?;
        final imageUrl = itemData['imageUrl'] as String?;
        result.add(_Candidate(
          ingredient: Ingredient(
            id: itemData['id']?.toString() ?? name.toLowerCase(),
            name: name,
            image: imageUrl ?? '',
            imageName: asset != null
                ? 'default.jpg'
                : (imageUrl?.split('/').last ?? 'default.jpg'),
            aisle: categoryKey,
            localAssetPath: asset,
          ),
          category: categoryKey,
          normalizedTokens: _normalizedTokens(name),
        ));
      }
    }
    return result;
  }

  /// Best of: Levenshtein similarity against the full query, and against
  /// each individual word of the candidate name. Most curated names are
  /// multi-word ("Coconut Oil", "Frozen Peas") — comparing a single
  /// mistyped word against the whole multi-word string scores poorly even
  /// on an obvious typo, so a per-token comparison is needed to catch
  /// those. Deliberately independent of the stopword/singular
  /// normalization used for phrase matching above — a spelling typo
  /// should be judged on the letters actually typed.
  static double _typoSimilarity(String query, String candidateName) {
    final lowerCandidate = candidateName.toLowerCase();
    var best = levenshteinSimilarity(query, lowerCandidate);
    for (final token in lowerCandidate.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      final tokenScore = levenshteinSimilarity(query, token);
      if (tokenScore > best) best = tokenScore;
    }
    return best;
  }

  static IngredientSuggestion _toSuggestion(_Candidate c, double score) =>
      IngredientSuggestion(
        ingredient: c.ingredient,
        category: c.category,
        similarity: score,
      );

  /// Fraction of [candidate]'s own normalized words that appear in
  /// [queryTokenSet] (both already stopword-stripped + singularized).
  static double _overlapRatio(
      List<String> candidateTokens, Set<String> queryTokenSet) {
    if (candidateTokens.isEmpty) return 0.0;
    final matches = candidateTokens.where(queryTokenSet.contains).length;
    return matches / candidateTokens.length;
  }

  /// Related-item suggestion — same ingredient, different phrasing.
  /// Cascades through 3 tiers (a higher tier always wins over a lower
  /// one, scores are never blended across tiers):
  ///   1. exact match once both sides are normalized (stopwords stripped,
  ///      singularized) — "fresh spinach" and "Spinach" both normalize to
  ///      just "spinach"
  ///   2. every one of the candidate's words is present in the query,
  ///      which may still have extra words of its own — "pickled onions"
  ///      contains all of "Onions"' words (trivially, it's one word) but
  ///      isn't identical to it
  ///   3. at least half the candidate's words are present in the query —
  ///      catches a multi-word candidate where only one word is typo'd
  ///      ("grond beef" -> "Ground Beef" via the exact "beef" word)
  ///
  /// [isExcluded] (e.g. an allergy check) removes a candidate from
  /// consideration everywhere, falling through to the next candidate
  /// in-tier first, then the next tier down, rather than suppressing the
  /// suggestion outright just because the top match happens to be
  /// excluded.
  static IngredientSuggestion? findRelatedSuggestion(
    String query, {
    required bool isFoodPantryItem,
    bool Function(String name)? isExcluded,
  }) {
    final queryTokens = _normalizedTokens(query);
    if (queryTokens.isEmpty) return null;
    final queryTokenSet = queryTokens.toSet();

    final all = _collectCandidates(isFoodPantryItem);
    bool allowed(_Candidate c) =>
        isExcluded == null || !isExcluded(c.ingredient.name);

    final exactPool = <_Candidate>[];
    final containedPool = <_Candidate>[];
    final overlapPool = <MapEntry<_Candidate, double>>[];

    for (final c in all) {
      if (!allowed(c) || c.normalizedTokens.isEmpty) continue;
      final ratio = _overlapRatio(c.normalizedTokens, queryTokenSet);
      if (ratio == 1.0) {
        if (c.normalizedTokens.length == queryTokens.length) {
          exactPool.add(c);
        } else {
          containedPool.add(c);
        }
      } else if (ratio >= _wordOverlapThreshold) {
        overlapPool.add(MapEntry(c, ratio));
      }
    }

    // Within a tier, prefer the plainer/shorter candidate name — e.g. for
    // "fresh spinach", both "Spinach" and "Frozen Spinach" normalize to
    // just "spinach" (their storage-type word is itself a stopword), so
    // this picks the base ingredient over an incidental variant.
    int byPlainness(_Candidate a, _Candidate b) =>
        a.normalizedTokens.length != b.normalizedTokens.length
            ? a.normalizedTokens.length.compareTo(b.normalizedTokens.length)
            : a.ingredient.name.length.compareTo(b.ingredient.name.length);

    if (exactPool.isNotEmpty) {
      exactPool.sort(byPlainness);
      return _toSuggestion(exactPool.first, 1.0);
    }
    if (containedPool.isNotEmpty) {
      containedPool.sort(byPlainness);
      return _toSuggestion(containedPool.first, 0.95);
    }
    if (overlapPool.isNotEmpty) {
      overlapPool.sort((a, b) => b.value.compareTo(a.value));
      return _toSuggestion(overlapPool.first.key, overlapPool.first.value);
    }
    return null;
  }

  /// Spelling-correction candidate — purely edit-distance based, for a
  /// single mistyped word ("cocnut" -> "Coconut Oil", the closest
  /// available curated item; there's no standalone "Coconut" in the
  /// curated list). Meant to be offered as a "search instead for X?"
  /// correction, not an "add this instead" prompt — see
  /// [findRelatedSuggestion] for that. Spoonacular is never involved.
  static IngredientSuggestion? findTypoCorrection(
    String query, {
    required bool isFoodPantryItem,
    bool Function(String name)? isExcluded,
    double threshold = defaultThreshold,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return null;

    final all = _collectCandidates(isFoodPantryItem);
    bool allowed(_Candidate c) =>
        isExcluded == null || !isExcluded(c.ingredient.name);

    final scored = <MapEntry<_Candidate, double>>[];
    for (final c in all) {
      if (!allowed(c)) continue;
      final score = _typoSimilarity(normalizedQuery, c.ingredient.name);
      if (score >= threshold) {
        scored.add(MapEntry(c, score));
      }
    }
    if (scored.isEmpty) return null;
    scored.sort((a, b) => b.value.compareTo(a.value));
    return _toSuggestion(scored.first.key, scored.first.value);
  }

  /// True when [a] and [b] resolve to the exact same curated ingredient —
  /// a UI-layer dedup helper, not a matching tier. [findRelatedSuggestion]
  /// and [findTypoCorrection] run independently and can legitimately both
  /// land on the same candidate (e.g. "tomatoe" -> "Tomatoes" via both a
  /// normalized-exact match and edit distance); callers should use this to
  /// show only one of the two suggestion UIs in that case, since showing
  /// both would just repeat the same name under two different framings.
  static bool sameIngredient(
      IngredientSuggestion? a, IngredientSuggestion? b) {
    if (a == null || b == null) return false;
    return a.ingredient.name.toLowerCase() == b.ingredient.name.toLowerCase();
  }
}
