import 'package:flutter_app/core/models/excluded_ingredient.dart';
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
      'cheese',
      'butter',
      'cream',
      'yogurt',
      'yoghurt',
      'whey',
      'casein',
      'ghee',
    ],
    'egg': ['egg', 'mayonnaise', 'mayo'],
    'eggs': ['egg', 'mayonnaise', 'mayo'],
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

  static bool conflictsWithRestrictions(
    String ingredientText, {
    required List<String> allergies,
    required List<ExcludedIngredient> excludedIngredients,
  }) {
    if (excludedIngredients.any((item) => item.matches(ingredientText))) {
      return true;
    }

    final normalizedText = ExcludedIngredient.normalize(ingredientText);
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
