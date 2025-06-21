import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

class FoodCategoryService {
  final UnitConversionService _conversionService;

  FoodCategoryService({required UnitConversionService conversionService})
      : _conversionService = conversionService;

  // --- Data for Mapping Ingredients to Categories ---

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
      'kale'
    ],
    TrackerCategory.fruits: [
      'apple',
      'banana',
      'orange',
      'lemon',
      'lime',
      'grape',
      'berry',
      'strawberry',
      'blueberry',
      'raspberry',
      'peach',
      'pear',
      'plum',
      'mango',
      'pineapple',
      'kiwi',
      'melon',
      'avocado'
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
      'barley',
      'quinoa',
      'couscous'
    ],
    TrackerCategory.protein: [
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
      'bean',
      'lentil',
      'chickpea'
    ],
    TrackerCategory.dairy: ['milk', 'cheese', 'yogurt', 'butter', 'cream'],
    TrackerCategory.fatsOils: ['oil', 'butter', 'margarine', 'lard', 'tahini'],
    TrackerCategory.nutsLegumes: [
      'almond',
      'walnut',
      'pecan',
      'cashew',
      'pistachio',
      'peanut',
      'sunflower seed',
      'pumpkin seed',
      'bean',
      'lentil',
      'chickpea',
      'pea',
      'soybean'
    ],
    TrackerCategory.sweets: [
      'sugar',
      'syrup',
      'honey',
      'chocolate',
      'cake',
      'cookie',
      'candy',
      'ice cream',
      'dessert'
    ],
    TrackerCategory.sodium:
        [], // Sodium is handled via nutrition facts, not ingredients
    TrackerCategory.water: ['water', 'juice', 'tea', 'coffee', 'soda'],
  };

  // --- Data for Standard Serving Sizes per Diet ---
  // Defines what "1 serving" means for each category and diet type.
  static const Map<String, Map<TrackerCategory, Map<String, dynamic>>>
      _standardServings = {
    'myplate': {
      TrackerCategory.veggies: {'amount': 1, 'unit': 'cup'},
      TrackerCategory.fruits: {'amount': 1, 'unit': 'cup'},
      TrackerCategory.grains: {'amount': 1, 'unit': 'ounce'},
      TrackerCategory.protein: {'amount': 1, 'unit': 'ounce'},
      TrackerCategory.dairy: {'amount': 1, 'unit': 'cup'},
    },
    'dash': {
      TrackerCategory.veggies: {'amount': 1, 'unit': 'cup'},
      TrackerCategory.fruits: {'amount': 1, 'unit': 'cup'},
      TrackerCategory.grains: {'amount': 1, 'unit': 'ounce'},
      TrackerCategory.protein: {'amount': 1, 'unit': 'ounce'},
      TrackerCategory.dairy: {'amount': 1, 'unit': 'cup'},
      TrackerCategory.nutsLegumes: {'amount': 0.25, 'unit': 'cup'},
      TrackerCategory.fatsOils: {'amount': 1, 'unit': 'teaspoon'},
      TrackerCategory.sweets: {'amount': 1, 'unit': 'tablespoon'},
    },
    // Can add other diet types here
  };

  /// Maps an ingredient name to a list of relevant tracker categories.
  List<TrackerCategory> getCategoriesForIngredient(String ingredientName) {
    final lowerIngredient = ingredientName.toLowerCase();
    final List<TrackerCategory> categories = [];

    _categoryKeywords.forEach((category, keywords) {
      if (keywords.any((keyword) => lowerIngredient.contains(keyword))) {
        categories.add(category);
      }
    });

    return categories;
  }

  /// Calculates the number of servings for a given ingredient based on diet.
  double getServingsForTracker({
    required String ingredientName,
    required double amount,
    required String unit,
    required TrackerCategory category,
    required String dietType,
  }) {
    final lowerDiet = dietType.toLowerCase();
    final standardServing = _standardServings[lowerDiet]?[category];

    if (standardServing == null) {
      return 0.0; // This diet doesn't track this category
    }

    final standardAmount = standardServing['amount'] as double;
    final standardUnit = standardServing['unit'] as String;

    // Convert the ingredient's amount to the standard serving unit
    final convertedAmount = _conversionService.convert(
      amount: amount,
      fromUnit: unit,
      toUnit: standardUnit,
      ingredientName: ingredientName,
    );

    if (convertedAmount == 0.0 || standardAmount == 0.0) {
      return 0.0;
    }

    return convertedAmount / standardAmount;
  }
}
