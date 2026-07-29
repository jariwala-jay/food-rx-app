/// Maps a food/ingredient (by name, optionally with a Spoonacular `aisle`
/// hint) to one of the existing MyFoodRx pantry categories.
///
/// Name matching does the heavy lifting; `aisle` is only a last-resort
/// tiebreaker since it's often missing or too broad (e.g. "Produce") to
/// trust on its own. Falls back to `'miscellaneous'` if neither matches.
class IngredientCategoryMapper {
  IngredientCategoryMapper._();

  static const String miscellaneous = 'miscellaneous';

  /// Returns a FoodRx leaf category key: fresh_fruits, frozen_fruits,
  /// canned_fruits, fresh_veggies, frozen_veggies, canned_veggies, grains,
  /// meat, beans, dairy, nuts_seeds, seasonings — or 'miscellaneous'.
  static String resolveCategory({required String name, String? aisle}) {
    final normalized = name.toLowerCase().trim();
    if (normalized.isEmpty) return miscellaneous;

    final preserveForm = _detectPreserveForm(normalized);

    final bucket = _matchBucketFromName(normalized);
    if (bucket != null) {
      return _leafKeyFor(bucket, preserveForm);
    }

    final aisleBucket = _matchBucketFromAisle(aisle);
    if (aisleBucket != null) {
      return _leafKeyFor(aisleBucket, preserveForm);
    }

    return miscellaneous;
  }

  // --- Preserve-form detection (fresh / frozen / canned) ---

  static _PreserveForm _detectPreserveForm(String name) {
    if (_matchesAny(name, const ['frozen'])) return _PreserveForm.frozen;
    if (_matchesAny(name, const [
      'canned',
      'jarred',
      'pickled',
      'preserved',
      'brined',
      'dried',
    ])) {
      return _PreserveForm.canned;
    }
    return _PreserveForm.fresh;
  }

  static String _leafKeyFor(_Bucket bucket, _PreserveForm form) {
    switch (bucket) {
      case _Bucket.fruit:
        switch (form) {
          case _PreserveForm.frozen:
            return 'frozen_fruits';
          case _PreserveForm.canned:
            return 'canned_fruits';
          case _PreserveForm.fresh:
            return 'fresh_fruits';
        }
      case _Bucket.vegetable:
        switch (form) {
          case _PreserveForm.frozen:
            return 'frozen_veggies';
          case _PreserveForm.canned:
            return 'canned_veggies';
          case _PreserveForm.fresh:
            return 'fresh_veggies';
        }
      case _Bucket.grain:
        return 'grains';
      case _Bucket.meat:
        return 'meat';
      case _Bucket.bean:
        return 'beans';
      case _Bucket.dairy:
        return 'dairy';
      case _Bucket.nut:
        return 'nuts_seeds';
      case _Bucket.seasoning:
        return 'seasonings';
    }
  }

  // --- Name-based bucket matching ---

  /// Order matters: seasoning is checked before vegetable so "black pepper"
  /// doesn't get caught by the bare "pepper" vegetable keyword.
  static _Bucket? _matchBucketFromName(String name) {
    if (_matchesAny(name, _seasoningKeywords)) return _Bucket.seasoning;
    if (_matchesAny(name, _meatKeywords)) return _Bucket.meat;
    if (_matchesAny(name, _beanKeywords)) return _Bucket.bean;
    if (_matchesAny(name, _nutKeywords)) return _Bucket.nut;
    if (_matchesAny(name, _dairyKeywords)) return _Bucket.dairy;
    if (_matchesAny(name, _vegetableKeywords)) return _Bucket.vegetable;
    if (_matchesAny(name, _fruitKeywords)) return _Bucket.fruit;
    if (_matchesAny(name, _grainKeywords)) return _Bucket.grain;
    return null;
  }

  static bool _matchesAny(String name, List<String> keywords) {
    for (final keyword in keywords) {
      // Short tokens need word boundaries so "pea" doesn't match inside
      // "chickpea", "ham" doesn't match inside "hamburger", "corn" doesn't
      // match inside "popcorn"/"cornstarch", and "pear" doesn't match
      // inside "pearl onion".
      if (keyword.length <= 4) {
        if (RegExp('\\b${RegExp.escape(keyword)}s?\\b').hasMatch(name)) {
          return true;
        }
      } else if (name.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  // --- Aisle fallback (narrow, only reliably single-category aisles) ---

  static _Bucket? _matchBucketFromAisle(String? aisle) {
    if (aisle == null || aisle.isEmpty) return null;
    switch (aisle) {
      case 'Meat':
      case 'Seafood':
        return _Bucket.meat;
      case 'Milk, Eggs, Other Dairy':
      case 'Cheese':
        return _Bucket.dairy;
      case 'Nuts':
        return _Bucket.nut;
      case 'Spices and Seasonings':
        return _Bucket.seasoning;
      case 'Pasta and Rice':
      case 'Cereal':
        return _Bucket.grain;
      default:
        // Deliberately excludes broad aisles (Produce, Ethnic Foods,
        // Refrigerated, Canned and Jarred, Frozen, Gourmet, Health Foods,
        // ...) — they don't reliably identify a single FoodRx category.
        return null;
    }
  }

  // --- Keyword dictionaries ---

  static const List<String> _fruitKeywords = [
    'apple',
    'banana',
    'plantain',
    'mango',
    'strawberry',
    'blueberry',
    'raspberry',
    'blackberry',
    'berry',
    'melon',
    'watermelon',
    'cantaloupe',
    'orange',
    'clementine',
    'tangerine',
    'grapefruit',
    'grape',
    'peach',
    'pear',
    'plum',
    'pineapple',
    'papaya',
    'kiwi',
    'fig',
    'date',
    'lemon',
    'lime',
    'cherry',
    'apricot',
    'pomegranate',
    'guava',
    'avocado',
    'raisin',
    'nectarine',
    'persimmon',
    'lychee',
    'passion fruit',
  ];

  static const List<String> _vegetableKeywords = [
    'onion',
    'kimchi',
    'pickle',
    'cabbage',
    'carrot',
    'tomato',
    'potato',
    'spinach',
    'kale',
    'broccoli',
    'cauliflower',
    'lettuce',
    'cucumber',
    'zucchini',
    'squash',
    'beet',
    'beetroot',
    'radish',
    'garlic',
    'mushroom',
    'asparagus',
    'celery',
    'eggplant',
    'artichoke',
    'okra',
    'leek',
    'scallion',
    'shallot',
    'turnip',
    'parsnip',
    'brussels sprout',
    'chard',
    'arugula',
    'bok choy',
    'sweet potato',
    'yam',
    'corn',
    'bell pepper',
    'jalapeno',
    'jalapeño',
    'chili pepper',
    'chile pepper',
    'sweet pepper',
    'banana pepper',
    'poblano',
    'habanero',
    'serrano',
    'shishito',
    'pepperoncini',
    'cubanelle',
    'capsicum',
    // Bare fallback for "green/red pepper" etc.; spice forms are already
    // caught by _seasoningKeywords, which runs first.
    'pepper',
  ];

  static const List<String> _grainKeywords = [
    'rice',
    'wheat',
    'oat',
    'quinoa',
    'barley',
    'bread',
    'pasta',
    'noodle',
    'cereal',
    'flour',
    'couscous',
    'bulgur',
    'millet',
    'tortilla',
    'cracker',
    'bagel',
    'bun',
    'roll',
    'polenta',
    'farro',
    'rye',
    'granola',
  ];

  static const List<String> _meatKeywords = [
    'chicken',
    'beef',
    'pork',
    'turkey',
    'lamb',
    'fish',
    'salmon',
    'tuna',
    'shrimp',
    'seafood',
    'shellfish',
    'crab',
    'lobster',
    'sausage',
    'bacon',
    'ham',
    'steak',
    'veal',
    'venison',
    'duck',
    'meatball',
  ];

  static const List<String> _beanKeywords = [
    'bean',
    'lentil',
    'chickpea',
    'garbanzo',
    'tofu',
    'tempeh',
    'edamame',
    'hummus',
    'seitan',
    'soybean',
    'pea',
  ];

  static const List<String> _dairyKeywords = [
    'milk',
    'cheese',
    'yogurt',
    'yoghurt',
    'paneer',
    'egg',
    'butter',
    'cream',
    'kefir',
    'ghee',
    'custard',
    'ricotta',
    'mozzarella',
    'cheddar',
  ];

  static const List<String> _nutKeywords = [
    'almond',
    'walnut',
    'cashew',
    'pecan',
    'pistachio',
    'peanut',
    'hazelnut',
    'macadamia',
    'sunflower seed',
    'pumpkin seed',
    'chia',
    'flax',
    'sesame',
    'brazil nut',
    'pine nut',
  ];

  static const List<String> _seasoningKeywords = [
    'cumin',
    'salt',
    'black pepper',
    'white pepper',
    'ground pepper',
    'cracked pepper',
    'peppercorn',
    'pepper flakes',
    'crushed red pepper',
    'paprika',
    'cinnamon',
    'oregano',
    'basil',
    'thyme',
    'rosemary',
    'nutmeg',
    'clove',
    'turmeric',
    'chili powder',
    'cayenne',
    'garlic powder',
    'onion powder',
    'seasoning',
    'spice',
    'curry powder',
    'coriander',
    'ginger powder',
    'bay leaf',
    'saffron',
    'vanilla extract',
    'allspice',
    'fennel seed',
    'mustard seed',
    'cardamom',
  ];
}

enum _Bucket { fruit, vegetable, grain, meat, bean, dairy, nut, seasoning }

enum _PreserveForm { fresh, frozen, canned }
