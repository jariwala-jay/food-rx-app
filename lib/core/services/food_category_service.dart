import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';

class FoodCategoryService {
  final UnitConversionService _conversionService;
  final DietServingService _dietServingService;

  FoodCategoryService({required UnitConversionService conversionService})
      : _conversionService = conversionService,
        _dietServingService = DietServingService(conversionService: conversionService);

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
  /// Uses enhanced DietServingService for more accurate categorization.
  List<TrackerCategory> getCategoriesForIngredient(String ingredientName, {String? dietType}) {
    // Use the enhanced diet serving service for better categorization
    return _dietServingService.getCategoriesForIngredient(ingredientName, dietType: dietType);
  }

  /// Calculates the number of servings for a given ingredient based on diet.
  /// Uses enhanced DietServingService with canonical units and official guidelines.
  double getServingsForTracker({
    required String ingredientName,
    required double amount,
    required String unit,
    required TrackerCategory category,
    required String dietType,
  }) {
    // Use the enhanced diet serving service for accurate conversions
    return _dietServingService.getServingsForTracker(
      ingredientName: ingredientName,
      amount: amount,
      unit: unit,
      category: category,
      dietType: dietType,
    );
  }

  /// Gets the official serving definition for a category and diet (new method)
  Map<String, dynamic>? getServingDefinition({
    required TrackerCategory category,
    required String dietType,
  }) {
    return _dietServingService.getServingDefinition(
      category: category,
      dietType: dietType,
    );
  }

  /// Calculates servings for multiple ingredients (useful for recipes)
  Map<TrackerCategory, double> calculateRecipeServings({
    required List<Map<String, dynamic>> ingredients,
    required String dietType,
    required int servings,
  }) {
    return _dietServingService.calculateRecipeServings(
      ingredients: ingredients,
      dietType: dietType,
      servings: servings,
    );
  }

  /// Gets recommended daily servings for a diet type
  Map<TrackerCategory, double> getRecommendedDailyServings(String dietType) {
    return _dietServingService.getRecommendedDailyServings(dietType);
  }

  /// Validates if an ingredient amount can be converted to diet servings
  Map<String, dynamic> validateServingConversion({
    required String ingredientName,
    required double amount,
    required String unit,
    required TrackerCategory category,
    required String dietType,
  }) {
    return _dietServingService.validateServingConversion(
      ingredientName: ingredientName,
      amount: amount,
      unit: unit,
      category: category,
      dietType: dietType,
    );
  }
}
