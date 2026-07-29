/// Nutritional importance bucket for pantry relevance scoring (Phase 1 ranking).
enum IngredientNutritionalCategory {
  protein,
  vegetable,
  grain,
  legume,
  fruit,
  dairy,
  seasoning,
  condiment,
  other,
}

/// Maps pantry keys, ingredient names, and categories to weights.
class IngredientNutritionalCategoryResolver {
  IngredientNutritionalCategoryResolver._();

  static const double expiringBonusPerItem = 3.0;
  static const double maxExpiringBonus = 6.0;

  static double weightFor(IngredientNutritionalCategory category) {
    switch (category) {
      case IngredientNutritionalCategory.protein:
        return 5.0;
      case IngredientNutritionalCategory.vegetable:
        return 3.0;
      case IngredientNutritionalCategory.grain:
        return 2.0;
      case IngredientNutritionalCategory.legume:
        return 2.0;
      case IngredientNutritionalCategory.fruit:
        return 2.0;
      case IngredientNutritionalCategory.dairy:
        return 2.0;
      case IngredientNutritionalCategory.seasoning:
        return 0.5;
      case IngredientNutritionalCategory.condiment:
        return 0.5;
      case IngredientNutritionalCategory.other:
        return 1.0;
    }
  }

  /// Priority 1: user-assigned pantry category key from add flow.
  static IngredientNutritionalCategory fromPantryCategoryKey(String? categoryKey) {
    if (categoryKey == null || categoryKey.trim().isEmpty) {
      return IngredientNutritionalCategory.other;
    }
    final key = categoryKey.toLowerCase().trim();
    switch (key) {
      case 'fresh_fruits':
      case 'frozen_fruits':
      case 'canned_fruits':
        return IngredientNutritionalCategory.fruit;
      case 'fresh_veggies':
      case 'frozen_veggies':
      case 'canned_veggies':
        return IngredientNutritionalCategory.vegetable;
      case 'meat':
      case 'protein': // legacy FoodRx key
        return IngredientNutritionalCategory.protein;
      case 'beans':
        return IngredientNutritionalCategory.legume;
      case 'nuts_seeds':
        return IngredientNutritionalCategory.other;
      case 'grains':
        return IngredientNutritionalCategory.grain;
      case 'dairy':
        return IngredientNutritionalCategory.dairy;
      case 'seasonings':
        return IngredientNutritionalCategory.seasoning;
      case 'snacks_beverages':
        return IngredientNutritionalCategory.other;
      default:
        return IngredientNutritionalCategory.other;
    }
  }

  /// Priority 2: keyword match on ingredient name (fallback when pantry key is generic).
  static IngredientNutritionalCategory fromIngredientName(String ingredientName) {
    final name = ingredientName.toLowerCase().trim();
    if (name.isEmpty) return IngredientNutritionalCategory.other;

    if (_matchesAny(name, _seasoningKeywords) || _isPepperSpice(name)) {
      return IngredientNutritionalCategory.seasoning;
    }
    if (_isCookingOilOrFat(name) || _matchesAny(name, _condimentKeywords)) {
      return IngredientNutritionalCategory.condiment;
    }
    if (_matchesAny(name, _proteinKeywords)) {
      return IngredientNutritionalCategory.protein;
    }
    if (_matchesAny(name, _legumeKeywords)) {
      return IngredientNutritionalCategory.legume;
    }
    if (_matchesAny(name, _vegetableKeywords)) {
      return IngredientNutritionalCategory.vegetable;
    }
    if (_matchesAny(name, _fruitKeywords)) {
      return IngredientNutritionalCategory.fruit;
    }
    if (_matchesAny(name, _grainKeywords)) {
      return IngredientNutritionalCategory.grain;
    }
    if (_matchesAny(name, _dairyKeywords)) {
      return IngredientNutritionalCategory.dairy;
    }

    return IngredientNutritionalCategory.other;
  }

  /// Pantry category wins when specific; otherwise fall back to name keywords.
  ///
  /// Seasoning/condiment name matches always win so oils and sauces are not
  /// pulled into Spoonacular `includeIngredients` when misfiled (e.g. oil under
  /// dairy). Completes Phase 1.5.1 condiment coverage.
  static IngredientNutritionalCategory resolve({
    required String ingredientName,
    String? pantryCategoryKey,
  }) {
    final fromName = fromIngredientName(ingredientName);
    if (fromName == IngredientNutritionalCategory.seasoning ||
        fromName == IngredientNutritionalCategory.condiment) {
      return fromName;
    }
    final fromPantry = fromPantryCategoryKey(pantryCategoryKey);
    if (fromPantry != IngredientNutritionalCategory.other) {
      return fromPantry;
    }
    return fromName;
  }

  /// Seasonings/condiments stay in ranking & matching, but not Spoonacular discovery.
  static bool isExcludedFromSpoonacularInclude(
    IngredientNutritionalCategory category,
  ) {
    return category == IngredientNutritionalCategory.seasoning ||
        category == IngredientNutritionalCategory.condiment;
  }

  /// Builds the `includeIngredients` list for Spoonacular (Phase 1.5).
  /// Empty [includedNames] means omit the param and search without pantry bias.
  static SpoonacularIncludeSelection selectForSpoonacularInclude(
    Iterable<({String name, String category})> pantryEntries,
  ) {
    final included = <String>[];
    final excluded = <SpoonacularIncludeExclusion>[];
    final seenIncluded = <String>{};

    for (final entry in pantryEntries) {
      final name = entry.name.trim();
      if (name.isEmpty) continue;

      final category = resolve(
        ingredientName: name,
        pantryCategoryKey: entry.category,
      );

      if (isExcludedFromSpoonacularInclude(category)) {
        excluded.add(
          SpoonacularIncludeExclusion(name: name, category: category),
        );
        continue;
      }

      final key = name.toLowerCase();
      if (seenIncluded.add(key)) {
        included.add(name);
      }
    }

    return SpoonacularIncludeSelection(
      includedNames: included,
      exclusions: excluded,
    );
  }

  /// True when expiry is within [withinDays] and not already expired.
  static bool isExpiringSoon(
    DateTime expirationDate, {
    int withinDays = 2,
  }) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final expiryDay = DateTime(
      expirationDate.year,
      expirationDate.month,
      expirationDate.day,
    );
    if (expiryDay.isBefore(today)) return false;
    final threshold = today.add(Duration(days: withinDays));
    return !expiryDay.isAfter(threshold);
  }

  static bool _matchesAny(String name, List<String> keywords) {
    for (final keyword in keywords) {
      // Short tokens (ham, pea) need word boundaries so "hamburger" ≠ ham
      // and "pear" ≠ pea.
      if (keyword.length <= 3) {
        if (RegExp('\\b${RegExp.escape(keyword)}s?\\b').hasMatch(name)) {
          return true;
        }
      } else if (name.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  /// Word-safe oil check — avoids matching "boil" / "foil" via bare "oil".
  static bool _isCookingOilOrFat(String name) {
    if (name == 'oil' ||
        name.endsWith(' oil') ||
        name.contains(' oil ')) {
      return true;
    }
    // Cooking butter only — not peanut/almond/apple butter or "butter chicken".
    if (name == 'butter' ||
        (name.endsWith(' butter') &&
            !_matchesAny(name, const [
              'peanut',
              'almond',
              'cashew',
              'apple',
            ]))) {
      return true;
    }
    return _matchesAny(name, _oilAndFatKeywords);
  }

  /// True only for the spice form (black pepper, pepper flakes). Colored
  /// peppers (bell, jalapeño, ...) are vegetables, handled elsewhere.
  static bool _isPepperSpice(String name) {
    return name == 'pepper' ||
        name.contains('black pepper') ||
        name.contains('white pepper') ||
        name.contains('ground pepper') ||
        name.contains('cracked pepper') ||
        name.contains('pepper flakes') ||
        name.contains('peppercorn') ||
        (name.contains('crushed') && name.contains('pepper'));
  }

  static const List<String> _seasoningKeywords = [
    'salt',
    'paprika',
    'cumin',
    'oregano',
    'basil',
    'thyme',
    'rosemary',
    'cinnamon',
    'nutmeg',
    'clove',
    'turmeric',
    'chili powder',
    'cayenne',
    'garlic powder',
    'onion powder',
    'seasoning',
    'spice',
  ];

  static const List<String> _condimentKeywords = [
    'ketchup',
    'mustard',
    'mayonnaise',
    'mayo',
    'soy sauce',
    'fish sauce',
    'vinegar',
    'hot sauce',
    'worcestershire',
    'barbecue sauce',
    'bbq sauce',
    'dressing',
    'relish',
    'margarine',
    'shortening',
    'ghee',
  ];

  /// Matched via [_isCookingOilOrFat] (not bare substring "oil").
  static const List<String> _oilAndFatKeywords = [
    'olive oil',
    'vegetable oil',
    'canola oil',
    'sesame oil',
    'coconut oil',
    'peanut oil',
    'sunflower oil',
    'avocado oil',
    'corn oil',
    'cooking oil',
    'grapeseed oil',
    'rapeseed oil',
  ];

  static const List<String> _proteinKeywords = [
    'chicken',
    'beef',
    'pork',
    'turkey',
    'fish',
    'salmon',
    'tuna',
    'shrimp',
    'egg',
    'tofu',
    'tempeh',
    'seitan',
    'bacon',
    'sausage',
    'ham',
    'lamb',
    'paneer',
  ];

  static const List<String> _legumeKeywords = [
    'bean',
    'lentil',
    'chickpea',
    'pea',
    'edamame',
  ];

  static const List<String> _vegetableKeywords = [
    'spinach',
    'broccoli',
    'carrot',
    'celery',
    'onion',
    'garlic',
    'pepper',
    'tomato',
    'lettuce',
    'kale',
    'cabbage',
    'zucchini',
    'squash',
    'mushroom',
    'asparagus',
    'potato',
    'cucumber',
    'pak choi',
    'pak choy',
    'bok choy',
  ];

  static const List<String> _fruitKeywords = [
    'apple',
    'banana',
    'orange',
    'berry',
    'grape',
    'lemon',
    'lime',
    'mango',
    'peach',
    'pear',
    'melon',
    'avocado',
  ];

  static const List<String> _grainKeywords = [
    'rice',
    'oat',
    'pasta',
    'noodle',
    'bread',
    'flour',
    'quinoa',
    'barley',
    'couscous',
    'cereal',
    'wheat',
  ];

  static const List<String> _dairyKeywords = [
    'milk',
    'cheese',
    'yogurt',
    'cream',
    'cottage',
  ];
}

/// Result of Phase 1.5 filtering for Spoonacular `includeIngredients`.
class SpoonacularIncludeSelection {
  final List<String> includedNames;
  final List<SpoonacularIncludeExclusion> exclusions;

  const SpoonacularIncludeSelection({
    required this.includedNames,
    required this.exclusions,
  });

  bool get isEmpty => includedNames.isEmpty;
}

class SpoonacularIncludeExclusion {
  final String name;
  final IngredientNutritionalCategory category;

  const SpoonacularIncludeExclusion({
    required this.name,
    required this.category,
  });
}
