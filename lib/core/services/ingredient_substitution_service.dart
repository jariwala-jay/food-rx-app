import 'package:flutter_app/core/services/unit_conversion_service.dart';

class IngredientSubstitutionService {
  final UnitConversionService _conversionService;

  IngredientSubstitutionService(
      {required UnitConversionService conversionService})
      : _conversionService = conversionService;

  // --- Ingredient Substitution Map ---
  // Key: a generic ingredient name (often from a recipe).
  // Value: list of more specific substitutes (often in a user's pantry).
  static const Map<String, List<String>> _substitutions = {
    // Dairy
    'milk': [
      'almond milk',
      'soy milk',
      'oat milk',
      'rice milk',
      'evaporated milk',
      'condensed milk',
      'full cream milk',
      'skim milk'
    ],
    'cheese': [
      'cheddar',
      'mozzarella',
      'provolone',
      'swiss',
      'parmesan',
      'feta',
      'goat cheese',
      'brie'
    ],
    'butter': ['margarine', 'coconut oil', 'ghee', 'clarified butter'],

    // Flours & Grains
    'flour': [
      'all-purpose flour',
      'whole wheat flour',
      'bread flour',
      'gluten-free flour'
    ],
    'rice': ['white rice', 'brown rice', 'basmati rice', 'jasmine rice'],

    // Meats
    'chicken': ['chicken breast', 'chicken thighs'],
    'beef': ['ground beef', 'stew meat', 'steak'],
    'pork': ['pork chop', 'pork loin', 'bacon'],

    // Produce
    'onion': ['yellow onion', 'white onion', 'red onion', 'shallot', 'leek'],
    'potato': [
      'russet potato',
      'yukon gold potato',
      'red potato',
      'sweet potato'
    ],
    'lettuce': ['romaine', 'iceberg', 'butter lettuce', 'spring mix'],
    'pak choi': [
      'bok choy',
      'bok choy leaves',
      'baby bok choy',
      'baby bok choy leaves',
      'pak choy'
    ],
    'pak choy': [
      'bok choy',
      'bok choy leaves',
      'baby bok choy',
      'baby bok choy leaves',
      'pak choi'
    ],
    'bok choy': [
      'pak choi',
      'pak choy',
      'baby bok choy',
      'baby bok choy leaves',
      'bok choy leaves'
    ],
    'berries': [
      'strawberry',
      'blueberry',
      'raspberry',
      'blackberry',
      'mixed berries'
    ],
    'apple': ['gala apple', 'granny smith apple', 'fuji apple', 'pineapple'],

    // Regional/spelling aliases — same ingredient, different common name.
    'cilantro': ['coriander', 'coriander leaves', 'fresh coriander'],
    'coriander': ['cilantro', 'fresh cilantro'],
    'green onion': [
      'scallion',
      'scallions',
      'spring onion',
      'spring onions'
    ],
    'scallion': [
      'green onion',
      'green onions',
      'spring onion',
      'spring onions'
    ],
    'spring onion': ['scallion', 'scallions', 'green onion', 'green onions'],
    'chickpea': ['garbanzo beans', 'garbanzo bean', 'garbanzo'],
    'garbanzo': ['chickpeas', 'chickpea'],
    'eggplant': ['aubergine'],
    'aubergine': ['eggplant'],
    'zucchini': ['courgette', 'courgettes'],
    'courgette': ['zucchini'],
    'shrimp': ['prawn', 'prawns'],
    'prawn': ['shrimp', 'shrimps'],
    'chili paste': ['chilli paste', 'chile paste'],
    'chilli paste': ['chili paste', 'chile paste'],
    'green chutney': [
      'mint chutney',
      'coriander chutney',
      'cilantro chutney'
    ],
    'mint chutney': [
      'green chutney',
      'coriander chutney',
      'cilantro chutney'
    ],

    // Sugars & Sweeteners
    'sugar': [
      'white sugar',
      'brown sugar',
      'coconut sugar',
      'maple syrup',
      'honey',
      'agave'
    ],

    // Fats & Oils
    'oil': [
      'vegetable oil',
      'canola oil',
      'olive oil',
      'coconut oil',
      'avocado oil'
    ],

    // Misc
    'chocolate': [
      'semi-sweet chocolate',
      'dark chocolate',
      'milk chocolate',
      'chocolate chips',
      'milk chocolate pieces'
    ],
    'popcorn': ['buttered popcorn', 'kettle corn'],
  };

  /// Checks if a pantry item is a valid substitute for a recipe ingredient.
  /// Returns the name of the pantry item if it's a valid sub, otherwise null.
  String? getValidSubstitute(String recipeIngredient, String pantryItem) {
    final lowerRecipe = recipeIngredient.toLowerCase().trim();
    final lowerPantry = pantryItem.toLowerCase().trim();

    // 1. Direct match (or pantry item contains recipe item, e.g., "chicken" in "chicken breast")
    if (lowerPantry.contains(lowerRecipe)) {
      return pantryItem;
    }

    // 2. Check substitution map
    for (final entry in _substitutions.entries) {
      final genericIngredient = entry.key;
      final substituteList = entry.value;

      // Does the recipe ask for the generic term and the pantry has a specific one?
      // e.g., recipe wants "milk", pantry has "almond milk"
      if (lowerRecipe.contains(genericIngredient) &&
          substituteList.contains(lowerPantry)) {
        return pantryItem;
      }
    }

    return null;
  }
}
