import 'package:flutter_app/core/models/excluded_ingredient.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

class AllergyFilteringService {
  static const Map<String, Intolerances> _intoleranceMappings = {
    'dairy': Intolerances.dairy,
    'egg': Intolerances.egg,
    'eggs': Intolerances.egg,
    'gluten': Intolerances.gluten,
    'peanut': Intolerances.peanut,
    'peanuts': Intolerances.peanut,
    'sesame': Intolerances.sesame,
    'shellfish': Intolerances.shellfish,
    'soy': Intolerances.soy,
    'tree nut': Intolerances.treeNut,
    'tree nuts': Intolerances.treeNut,
    'wheat': Intolerances.wheat,
    // Spoonacular has no fish-only intolerance. Seafood is the closest API
    // filter; local aliases below preserve the fish/shellfish distinction.
    'fish': Intolerances.seafood,
  };

  static const Map<String, List<String>> _allergenAliases = {
    'dairy': [
      'milk',
      'buttermilk',
      'half-and-half',
      'cheese',
      'butter',
      'butterscotch',
      'cream',
      'creamed',
      'yogurt',
      'yoghurt',
      'whey',
      'casein',
      'ghee',
    ],
    'egg': ['egg', 'eggnog', 'mayonnaise', 'mayo'],
    'eggs': ['egg', 'eggnog', 'mayonnaise', 'mayo'],
    'gluten': [
      'wheat',
      'barley',
      'rye',
      'malt',
      'semolina',
      'bulgur',
      'farro',
    ],
    'peanut': ['peanut', 'groundnut'],
    'peanuts': ['peanut', 'groundnut'],
    'sesame': ['sesame', 'tahini'],
    'shellfish': [
      'shrimp',
      'prawn',
      'crab',
      'lobster',
      'clam',
      'mussel',
      'oyster',
      'scallop',
      'crayfish',
    ],
    'soy': ['soy', 'soybean', 'tofu', 'tempeh', 'edamame', 'miso'],
    'tree nut': [
      'almond',
      'walnut',
      'cashew',
      'pecan',
      'pistachio',
      'hazelnut',
      'macadamia',
      'brazil nut',
      'pine nut',
    ],
    'tree nuts': [
      'almond',
      'walnut',
      'cashew',
      'pecan',
      'pistachio',
      'hazelnut',
      'macadamia',
      'brazil nut',
      'pine nut',
    ],
    'wheat': [
      'wheat',
      'wheat flour',
      'semolina',
      'bulgur',
      'farro',
      'couscous'
    ],
    'fish': [
      'fish',
      'anchovy',
      'bass',
      'cod',
      'haddock',
      'halibut',
      'mackerel',
      'salmon',
      'sardine',
      'tilapia',
      'trout',
      'tuna',
    ],
  };

  /// Known derivative/related terms for common custom (non-curated) foods —
  /// only for cases where the derivative doesn't share a matching word token
  /// with the base name (a single compound word, or an unrelated product
  /// name), so `ExcludedIngredient.matches()`'s token-subset check can't
  /// catch it on its own. Multi-word derivatives like "apple juice" or
  /// "almond milk" already match without an entry here. Keyed by the
  /// *normalized* custom allergy name. Grow this as real gaps turn up —
  /// deliberately not pre-populated with speculative/unconfirmed synonyms.
  static const Map<String, List<String>> _customIngredientDerivatives = {
    'apple': ['applesauce'],
  };

  static List<Intolerances> intolerancesFor(List<String> allergies) {
    return allergies
        .map((allergy) => _intoleranceMappings[allergy.trim().toLowerCase()])
        .whereType<Intolerances>()
        .toSet()
        .toList();
  }

  static List<String> intoleranceApiNamesFor(List<String> allergies) =>
      intolerancesFor(allergies)
          .map((intolerance) => intolerance.apiName)
          .toList();

  static List<ExcludedIngredient> parseExcludedIngredients(dynamic raw) {
    if (raw is! List) return const [];
    final parsed = <ExcludedIngredient>[];
    for (final value in raw) {
      try {
        final ingredient = ExcludedIngredient.fromJson(value);
        if (ingredient.name.isNotEmpty && !parsed.contains(ingredient)) {
          parsed.add(ingredient);
        }
      } on FormatException {
        // Ignore malformed legacy values rather than breaking recipe generation.
      }
    }
    return parsed;
  }

  /// [conflictsWithRestrictions] against [user]'s own allergies/excluded
  /// ingredients — the same "does this pantry/ingredient name conflict with
  /// what this user can't eat" check used by the pantry item picker,
  /// category browse page, pantry list, and tracker item picker, previously
  /// each re-implementing the null-check + field lookup independently.
  static bool itemNameConflictsWithUser(String itemName, UserModel? user) {
    if (user == null) return false;
    return conflictsWithRestrictions(
      itemName,
      allergies: user.allergies ?? const [],
      excludedIngredients: user.excludedIngredients ?? const [],
    );
  }

  static bool conflictsWithRestrictions(
    String ingredientText, {
    required List<String> allergies,
    required List<ExcludedIngredient> excludedIngredients,
  }) {
    if (excludedIngredients.any((item) => item.matches(ingredientText))) {
      return true;
    }

    final normalizedText = ExcludedIngredient.normalize(ingredientText);

    // Custom entries also get checked against known derivative products
    // that don't share a word token with the base name (e.g. "applesauce"
    // for "apple") — the same curated-relationship idea used for predefined
    // allergens below, scaled down to a small, deliberately short list.
    for (final excluded in excludedIngredients) {
      final derivatives = _customIngredientDerivatives[
          ExcludedIngredient.normalize(excluded.name)];
      if (derivatives != null &&
          derivatives.any((term) => _containsAlias(normalizedText, term))) {
        return true;
      }
    }

    for (final allergy in allergies) {
      final allergyKey = allergy.trim().toLowerCase();
      final aliases = _allergenAliases[allergyKey] ?? const [];
      if (aliases.any(
        (alias) => _containsAllergenAlias(
          normalizedText,
          allergyKey,
          alias,
        ),
      )) {
        return true;
      }
    }
    return false;
  }

  static bool recipeContainsRestrictions(
    Recipe recipe, {
    required List<String> allergies,
    required List<ExcludedIngredient> excludedIngredients,
  }) {
    return recipe.extendedIngredients.any((ingredient) {
      final searchableText = [
        ingredient.name,
        ingredient.nameClean,
        ingredient.originalName,
        ingredient.original,
      ].where((value) => value.isNotEmpty).join(' ');
      return conflictsWithRestrictions(
        searchableText,
        allergies: allergies,
        excludedIngredients: excludedIngredients,
      );
    });
  }

  static bool _containsAlias(String normalizedText, String alias) {
    final normalizedAlias = ExcludedIngredient.normalize(alias);
    if (normalizedAlias.isEmpty) return false;
    final textTokens = normalizedText.split(' ').toSet();
    return normalizedAlias.split(' ').every(textTokens.contains);
  }

  static bool _containsAllergenAlias(
    String normalizedText,
    String allergy,
    String alias,
  ) {
    if (allergy == 'dairy') {
      final normalizedAlias = ExcludedIngredient.normalize(alias);
      const nonDairyQualifiers = {
        'almond',
        'cashew',
        'cocoa',
        'coconut',
        'hemp',
        'oat',
        'peanut',
        'rice',
        'soy',
      };
      if ((normalizedAlias == 'milk' ||
              normalizedAlias == 'butter' ||
              normalizedAlias == 'cream') &&
          nonDairyQualifiers.any(normalizedText.split(' ').contains)) {
        return false;
      }
      if (normalizedAlias == 'cream' &&
          normalizedText.contains('cream tartar')) {
        return false;
      }
    }
    return _containsAlias(normalizedText, alias);
  }
}
