import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

/// Enhanced Diet Serving Service for accurate DASH and MyPlate conversions
/// Uses canonical units (grams, milliliters, count) based on official dietary guidelines
///
/// References:
/// - DASH Diet: NIH/NHLBI Guidelines for 2000-calorie diet
/// - MyPlate: USDA Dietary Guidelines 2020-2025
class DietServingService {
  final UnitConversionService _conversionService;

  DietServingService({required UnitConversionService conversionService})
      : _conversionService = conversionService;

  // --- Enhanced Category Keywords with More Comprehensive Mapping ---

  static const Map<TrackerCategory, List<String>> _categoryKeywords = {
    TrackerCategory.veggies: [
      'tomato',
      'onion',
      'garlic',
      'carrot',
      'broccoli',
      'spinach',
      'lettuce',
      'cucumber',
      'pepper',
      'celery',
      'cabbage',
      'cauliflower',
      'zucchini',
      'squash',
      'eggplant',
      'mushroom',
      'asparagus',
      'green beans',
      'peas',
      'corn',
      'potato',
      'beet',
      'radish',
      'kale',
      'arugula',
      'bok choy',
      'brussels sprouts',
      'artichoke',
      'leek',
      'shallot',
      'scallion',
      'green onion',
      'jalapeno',
      'bell pepper',
      'hot pepper',
      'chili',
      'sweet potato',
      'turnip',
      'parsnip',
      'rutabaga',
      'collard greens',
      'swiss chard',
      'watercress',
      'endive',
      'radicchio',
      'fennel'
    ],
    TrackerCategory.fruits: [
      'apple',
      'banana',
      'orange',
      'lemon',
      'lime',
      'grape',
      'berry',
      'berries',
      'strawberry',
      'strawberries',
      'blueberry',
      'blueberries',
      'raspberry',
      'raspberries',
      'blackberry',
      'blackberries',
      'cranberry',
      'cranberries',
      'peach',
      'pear',
      'plum',
      'mango',
      'pineapple',
      'kiwi',
      'melon',
      'watermelon',
      'cantaloupe',
      'honeydew',
      'avocado',
      'cherry',
      'cherries',
      'apricot',
      'fig',
      'date',
      'raisin',
      'grapefruit',
      'tangerine',
      'mandarin',
      'papaya',
      'guava',
      'passion fruit',
      'pomegranate',
      'coconut',
      'dried fruit',
      'fruit juice'
    ],
    TrackerCategory.grains: [
      'rice',
      'wheat',
      'flour',
      'bread',
      'pasta',
      'noodle',
      'cereal',
      'oat',
      'oats',
      'barley',
      'quinoa',
      'couscous',
      'bulgur',
      'millet',
      'amaranth',
      'buckwheat',
      'rye',
      'spelt',
      'farro',
      'wild rice',
      'brown rice',
      'white rice',
      'jasmine rice',
      'basmati rice',
      'arborio rice',
      'crackers',
      'tortilla',
      'pita',
      'bagel',
      'muffin',
      'pancake',
      'waffle',
      'granola',
      'bran',
      'wheat germ'
    ],
    TrackerCategory.protein: [
      // MyPlate protein category - includes eggs for MyPlate diet
      'chicken', 'beef', 'pork', 'turkey', 'fish', 'salmon', 'tuna',
      'cod', 'tilapia', 'halibut', 'shrimp', 'crab', 'lobster', 'scallops',
      'mussels', 'clams', 'oysters', 'egg', 'egg white', 'tofu', 'tempeh',
      'seitan', 'protein powder', 'meat', 'poultry', 'seafood', 'duck',
      'lamb', 'veal', 'ground beef', 'ground turkey', 'ground chicken',
      'bacon', 'ham', 'sausage', 'deli meat', 'jerky'
    ],
    TrackerCategory.leanMeat: [
      // DASH-specific lean meats, poultry, fish - includes eggs for DASH diet
      'chicken', 'beef', 'pork', 'turkey', 'fish', 'salmon', 'tuna',
      'cod', 'tilapia', 'halibut', 'shrimp', 'crab', 'lobster', 'scallops',
      'mussels', 'clams', 'oysters', 'egg', 'egg white', 'tofu', 'tempeh',
      'seitan', 'protein powder', 'meat', 'poultry', 'seafood', 'duck',
      'lamb', 'veal', 'ground beef', 'ground turkey', 'ground chicken',
      'bacon', 'ham', 'sausage', 'deli meat', 'jerky'
    ],
    TrackerCategory.dairy: [
      'milk',
      'cheese',
      'yogurt',
      'butter',
      'cream',
      'sour cream',
      'cottage cheese',
      'ricotta',
      'mozzarella',
      'cheddar',
      'swiss',
      'parmesan',
      'feta',
      'goat cheese',
      'cream cheese',
      'ice cream',
      'frozen yogurt',
      'kefir',
      'buttermilk',
      'whey',
      'casein'
    ],
    TrackerCategory.fatsOils: [
      'oil',
      'olive oil',
      'vegetable oil',
      'canola oil',
      'coconut oil',
      'avocado oil',
      'sesame oil',
      'butter',
      'margarine',
      'lard',
      'tahini',
      'ghee',
      'shortening',
      'mayonnaise',
      'salad dressing',
      'vinaigrette'
    ],
    TrackerCategory.nutsLegumes: [
      'almond',
      'walnut',
      'pecan',
      'cashew',
      'pistachio',
      'peanut',
      'hazelnut',
      'macadamia',
      'brazil nut',
      'pine nut',
      'sunflower seed',
      'pumpkin seed',
      'chia seed',
      'flax seed',
      'sesame seed',
      'hemp seed',
      'bean',
      'black bean',
      'kidney bean',
      'pinto bean',
      'navy bean',
      'lima bean',
      'garbanzo bean',
      'chickpea',
      'lentil',
      'red lentil',
      'green lentil',
      'split pea',
      'black-eyed pea',
      'soybean',
      'edamame',
      'peanut butter',
      'almond butter',
      'cashew butter',
      'tahini'
    ],
    TrackerCategory.sweets: [
      'sugar',
      'brown sugar',
      'white sugar',
      'powdered sugar',
      'syrup',
      'maple syrup',
      'honey',
      'agave',
      'molasses',
      'chocolate',
      'cocoa',
      'cake',
      'cookie',
      'candy',
      'ice cream',
      'dessert',
      'pie',
      'pastry',
      'donut',
      'brownie',
      'fudge',
      'caramel',
      'marshmallow',
      'jelly',
      'jam',
      'preserves',
      'sorbet',
      'sherbet',
      'gelato'
    ],
    TrackerCategory.sodium: [], // Handled via nutrition facts, not ingredients
    TrackerCategory.water: [
      'water',
      'juice',
      'tea',
      'coffee',
      'soda',
      'sparkling water',
      'coconut water',
      'sports drink',
      'energy drink',
      'smoothie',
      'lemonade',
      'iced tea',
      'herbal tea',
      'broth',
      'soup'
    ],
  };

  // --- Official Diet Serving Definitions in Canonical Units ---
  // Based on DASH (2000 kcal) and MyPlate (USDA 2020-2025) guidelines

  static const Map<String, Map<TrackerCategory, Map<String, dynamic>>>
      _officialServingDefinitions = {
    'dash': {
      // DASH Diet serving definitions (2000 kcal/day)
      TrackerCategory.veggies: {
        'canonical_amount': 90.0, // 90g = 1/2 cup cooked or 1 cup raw leafy
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 cup raw leafy vegetables',
          '1/2 cup cooked vegetables',
          '1/2 cup (4 fl oz) low-sodium vegetable juice'
        ]
      },
      TrackerCategory.fruits: {
        'canonical_amount': 120.0, // 120g = 1 medium fruit or 1/2 cup
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 medium fruit',
          '1/4 cup dried fruit',
          '1/2 cup fresh, frozen or canned fruit',
          '1/2 cup (4 fl oz) 100% fruit juice'
        ]
      },
      TrackerCategory.grains: {
        'canonical_amount': 30.0, // 30g = 1 oz dry cereal or 1/2 cup cooked
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 slice whole-wheat bread',
          '1 oz dry whole-grain cereal',
          '1/2 cup cooked cereal, rice or pasta'
        ]
      },
      TrackerCategory.protein: {
        // Lean meats, poultry, fish
        'canonical_amount': 28.0, // 28g = 1 oz cooked lean meat
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 oz cooked lean meat, skinless poultry or fish',
          '1 egg',
          '2 egg whites'
        ]
      },
      TrackerCategory.leanMeat: {
        // DASH-specific lean meats, poultry, fish
        'canonical_amount': 28.0, // 28g = 1 oz cooked lean meat
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 oz cooked lean meat, skinless poultry or fish',
          '1 egg',
          '2 egg whites'
        ]
      },
      TrackerCategory.dairy: {
        // Low-fat or fat-free dairy
        'canonical_amount': 245.0, // 245ml = 1 cup milk
        'canonical_unit': 'milliliter',
        'display_unit': 'serving',
        'examples': [
          '1 cup (8 fl oz) low-fat or fat-free milk',
          '1 cup low-fat or fat-free yogurt',
          '1 1/2 oz low-fat or fat-free cheese'
        ]
      },
      TrackerCategory.nutsLegumes: {
        'canonical_amount': 42.0, // 42g = 1/3 cup nuts or 1/2 cup cooked beans
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1/3 cup (1 1/2 oz) nuts',
          '2 tbsp peanut butter',
          '2 tbsp (1/2 oz) seeds',
          '1/2 cup cooked dried beans or peas'
        ]
      },
      TrackerCategory.fatsOils: {
        'canonical_amount': 5.0, // 5ml = 1 tsp (base DASH serving)
        'canonical_unit': 'milliliter',
        'display_unit': 'serving',
        'examples': [
          '1 tsp soft margarine',
          '1 tsp vegetable oil',
          '1 tbsp mayonnaise (3 servings)',
          '2 tbsp low-fat salad dressing'
        ]
      },
      TrackerCategory.sweets: {
        'canonical_amount': 15.0, // 15g = 1 tbsp sugar
        'canonical_unit': 'gram',
        'display_unit': 'serving',
        'examples': [
          '1 tbsp sugar',
          '1 tbsp jelly or jam',
          '1/2 cup sorbet',
          '1 cup sugar-sweetened lemonade'
        ],
        'notes': 'note: up to 1 serving per day'
      },
      TrackerCategory.sodium: {
        'canonical_amount': 1500.0, // 1500mg daily (stricter DASH goal)
        'canonical_unit': 'milligram',
        'display_unit': 'mg',
        'examples': ['Daily sodium intake limit']
      },
      TrackerCategory.water: {
        'canonical_amount': 240.0, // 240ml = 1 cup
        'canonical_unit': 'milliliter',
        'display_unit': 'cup',
        'examples': ['8 oz water or other beverages']
      }
    },
    'myplate': {
      // MyPlate serving definitions (USDA 2020-2025)
      TrackerCategory.veggies: {
        'canonical_amount': 125.0, // 125g = 1 cup equivalent
        'canonical_unit': 'gram',
        'display_unit': 'cup',
        'examples': [
          '1 cup raw or cooked vegetables',
          '2 cups leafy salad greens',
          '1 cup 100% vegetable juice'
        ]
      },
      TrackerCategory.fruits: {
        'canonical_amount': 150.0, // 150g = 1 cup equivalent
        'canonical_unit': 'gram',
        'display_unit': 'cup',
        'examples': [
          '1 cup raw, frozen, or cooked fruit',
          '1/2 cup dried fruit',
          '1 cup 100% fruit juice'
        ]
      },
      TrackerCategory.grains: {
        'canonical_amount': 28.0, // 28g = 1 oz equivalent
        'canonical_unit': 'gram',
        'display_unit': 'oz',
        'examples': [
          '1 slice bread',
          '1 cup ready-to-eat cereal',
          '1/2 cup cooked rice, pasta, or cereal'
        ]
      },
      TrackerCategory.protein: {
        'canonical_amount': 28.0, // 28g = 1 oz equivalent
        'canonical_unit': 'gram',
        'display_unit': 'oz',
        'examples': [
          '1 oz seafood, lean meat, or poultry',
          '1 egg',
          '1 tbsp peanut butter',
          '1/4 cup cooked beans, peas, or lentils',
          '1/2 oz unsalted nuts or seeds'
        ]
      },
      TrackerCategory.dairy: {
        'canonical_amount': 245.0, // 245ml = 1 cup equivalent
        'canonical_unit': 'milliliter',
        'display_unit': 'cup',
        'examples': ['1 cup dairy milk or yogurt', '1.5 oz hard cheese']
      },
      TrackerCategory.water: {
        'canonical_amount': 240.0, // 240ml = 1 cup
        'canonical_unit': 'milliliter',
        'display_unit': 'cup',
        'examples': ['8 oz water or other beverages']
      }
    }
  };

  /// Maps an ingredient name to relevant tracker categories using enhanced keywords
  /// Now diet-specific to prevent duplicate tracking
  List<TrackerCategory> getCategoriesForIngredient(String ingredientName,
      {String? dietType}) {
    final lowerIngredient = ingredientName.toLowerCase();
    final List<TrackerCategory> categories = [];
    final lowerDiet = dietType?.toLowerCase();

    _categoryKeywords.forEach((category, keywords) {
      if (keywords.any((keyword) => lowerIngredient.contains(keyword))) {
        // Handle diet-specific category mapping to prevent duplicates
        if (lowerDiet == 'dash') {
          // DASH diet uses leanMeat instead of protein
          if (category == TrackerCategory.protein) {
            // Skip protein category for DASH diet
            return;
          }
          categories.add(category);
        } else if (lowerDiet == 'myplate') {
          // MyPlate diet uses protein instead of leanMeat
          if (category == TrackerCategory.leanMeat) {
            // Skip leanMeat category for MyPlate diet
            return;
          }
          categories.add(category);
        } else {
          // For unknown diets, include all categories (backward compatibility)
          categories.add(category);
        }
      }
    });

    return categories;
  }

  /// Calculates accurate diet servings using canonical units and official guidelines
  double getServingsForTracker({
    required String ingredientName,
    required double amount,
    required String unit,
    required TrackerCategory category,
    required String dietType,
  }) {
    final lowerDiet = dietType.toLowerCase();
    final servingDefinition = _officialServingDefinitions[lowerDiet]?[category];

    if (servingDefinition == null) {
      return 0.0; // This diet doesn't track this category
    }

    // Handle special cases for count-based ingredients that have direct serving equivalents
    final lowerIngredient = ingredientName.toLowerCase();
    final lowerUnit = unit.toLowerCase();

    // Special handling for eggs - 1 egg = 1 serving for both protein and leanMeat
    if ((category == TrackerCategory.protein ||
            category == TrackerCategory.leanMeat) &&
        lowerIngredient.contains('egg') &&
        (lowerUnit.isEmpty ||
            lowerUnit == 'piece' ||
            lowerUnit == 'large' ||
            lowerUnit == 'medium' ||
            lowerUnit == 'small')) {
      // 1 egg = 1 serving according to DASH and MyPlate guidelines
      return amount;
    }

    // Special handling for other count-based protein servings
    if ((category == TrackerCategory.protein ||
        category == TrackerCategory.leanMeat)) {
      // Handle other count-based proteins that might have direct serving equivalents
      if (lowerIngredient.contains('chicken breast') &&
          (lowerUnit.isEmpty || lowerUnit == 'piece')) {
        // 1 chicken breast ≈ 6 servings (174g ÷ 28g)
        return amount * 6.2;
      }
      if (lowerIngredient.contains('chicken thigh') &&
          (lowerUnit.isEmpty || lowerUnit == 'piece')) {
        // 1 chicken thigh ≈ 4 servings (109g ÷ 28g)
        return amount * 3.9;
      }
    }

    final canonicalAmount = servingDefinition['canonical_amount'] as double;
    final canonicalUnit = servingDefinition['canonical_unit'] as String;

    // Convert ingredient amount to canonical unit
    final convertedAmount = _conversionService.convert(
      amount: amount,
      fromUnit: unit,
      toUnit: canonicalUnit,
      ingredientName: ingredientName,
    );

    if (convertedAmount == 0.0 || canonicalAmount == 0.0) {
      return 0.0;
    }

    // Calculate servings based on canonical amount
    return convertedAmount / canonicalAmount;
  }

  /// Gets the official serving definition for a category and diet
  Map<String, dynamic>? getServingDefinition({
    required TrackerCategory category,
    required String dietType,
  }) {
    final lowerDiet = dietType.toLowerCase();
    return _officialServingDefinitions[lowerDiet]?[category];
  }

  /// Gets all available diet types
  List<String> getAvailableDietTypes() {
    return _officialServingDefinitions.keys.toList();
  }

  /// Gets all tracked categories for a specific diet
  List<TrackerCategory> getTrackedCategories(String dietType) {
    final lowerDiet = dietType.toLowerCase();
    return _officialServingDefinitions[lowerDiet]?.keys.toList() ?? [];
  }

  /// Validates if an ingredient amount can be converted to diet servings
  Map<String, dynamic> validateServingConversion({
    required String ingredientName,
    required double amount,
    required String unit,
    required TrackerCategory category,
    required String dietType,
  }) {
    final lowerDiet = dietType.toLowerCase();
    final servingDefinition = _officialServingDefinitions[lowerDiet]?[category];

    if (servingDefinition == null) {
      return {
        'canConvert': false,
        'confidence': 0.0,
        'error':
            'Diet type "$dietType" does not track category "${category.name}"'
      };
    }

    final canonicalUnit = servingDefinition['canonical_unit'] as String;

    // Check if conversion is possible
    final conversionResult = _conversionService.convertWithConfidence(
      amount: amount,
      fromUnit: unit,
      toUnit: canonicalUnit,
      ingredientName: ingredientName,
    );

    return {
      'canConvert': conversionResult['confidence'] > 0.0,
      'confidence': conversionResult['confidence'],
      'convertedAmount': conversionResult['amount'],
      'conversionPath': conversionResult['path'],
      'servingDefinition': servingDefinition,
    };
  }

  /// Calculates servings for multiple ingredients (useful for recipes)
  Map<TrackerCategory, double> calculateRecipeServings({
    required List<Map<String, dynamic>> ingredients,
    required String dietType,
    required int servings,
  }) {
    final Map<TrackerCategory, double> categoryServings = {};

    for (final ingredient in ingredients) {
      final name = ingredient['name'] as String;
      final amount = (ingredient['amount'] as num).toDouble();
      final unit = ingredient['unit'] as String;

      final categories = getCategoriesForIngredient(name, dietType: dietType);

      for (final category in categories) {
        final servingAmount = getServingsForTracker(
          ingredientName: name,
          amount: amount,
          unit: unit,
          category: category,
          dietType: dietType,
        );

        // Divide by recipe servings to get per-serving amount
        final perServingAmount = servingAmount / servings;

        categoryServings[category] =
            (categoryServings[category] ?? 0.0) + perServingAmount;
      }
    }

    return categoryServings;
  }

  /// Gets recommended daily servings for a diet type
  Map<TrackerCategory, double> getRecommendedDailyServings(String dietType) {
    final lowerDiet = dietType.toLowerCase();

    if (lowerDiet == 'dash') {
      return {
        TrackerCategory.veggies: 4.5, // 4-5 servings daily
        TrackerCategory.fruits: 4.5, // 4-5 servings daily
        TrackerCategory.grains: 7.0, // 6-8 servings daily
        TrackerCategory.leanMeat:
            6.0, // 6 or less servings daily (DASH uses leanMeat not protein)
        TrackerCategory.dairy: 2.5, // 2-3 servings daily
        TrackerCategory.nutsLegumes: 0.7, // 4-5 servings weekly (≈0.7 daily)
        TrackerCategory.fatsOils: 2.5, // 2-3 servings daily
        TrackerCategory.sweets: 0.7, // 5 or less servings weekly (≈0.7 daily)
        TrackerCategory.water: 8.0, // 8 cups daily
      };
    } else if (lowerDiet == 'myplate') {
      return {
        TrackerCategory.veggies: 2.5, // 2.5 cups daily
        TrackerCategory.fruits: 2.0, // 2 cups daily
        TrackerCategory.grains: 6.0, // 6 oz daily
        TrackerCategory.protein: 5.5, // 5.5 oz daily
        TrackerCategory.dairy: 3.0, // 3 cups daily
        TrackerCategory.water: 8.0, // 8 cups daily
      };
    }

    return {};
  }

  /// Formats serving amount for display
  String formatServingAmount(
      double amount, TrackerCategory category, String dietType) {
    final servingDefinition =
        getServingDefinition(category: category, dietType: dietType);
    if (servingDefinition == null) return amount.toStringAsFixed(1);

    final displayUnit = servingDefinition['display_unit'] as String;
    final formatted =
        amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 1);

    return '$formatted $displayUnit${amount != 1.0 ? 's' : ''}';
  }
}
