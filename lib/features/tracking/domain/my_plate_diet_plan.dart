import 'package:flutter_app/features/tracking/domain/diet_plan.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

class MyPlateDietPlan implements DietPlan {
  @override
  DietPlanType get type => DietPlanType.myPlate;

  // Official MyPlate Serving Size Definitions (Equivalents)
  // Source: USDA MyPlate Plan
  static final List<Map<String, dynamic>> _servingDefinitions = [
    // Grains (oz-equivalents)
    {
      'keywords': ['bread', 'bagel', 'muffin'],
      'category': TrackerCategory.grains,
      'standardAmount': 1.0,
      'standardUnit': 'slice' // 1 regular slice, 1 mini-bagel, etc.
    },
    {
      'keywords': ['cereal'],
      'category': TrackerCategory.grains,
      'standardAmount': 1.0,
      'standardUnit': 'cup' // 1 cup of ready-to-eat cereal
    },
    {
      'keywords': ['rice', 'pasta', 'noodle', 'oats', 'oatmeal', 'quinoa'],
      'category': TrackerCategory.grains,
      'standardAmount': 0.5,
      'standardUnit': 'cup' // 1/2 cup cooked
    },
    // Veggies (cup-equivalents)
    {
      'keywords': ['spinach', 'lettuce', 'kale', 'greens'],
      'category': TrackerCategory.veggies,
      'standardAmount': 2.0,
      'standardUnit': 'cup' // 2 cups raw leafy greens
    },
    {
      'keywords': [
        'tomato',
        'onion',
        'garlic',
        'carrot',
        'broccoli',
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
        'bean',
        'pea',
        'corn',
        'potato'
      ],
      'category': TrackerCategory.veggies,
      'standardAmount': 1.0,
      'standardUnit': 'cup' // 1 cup raw or cooked
    },
    // Fruits (cup-equivalents)
    {
      'keywords': ['dried fruit', 'raisin', 'date', 'prune'],
      'category': TrackerCategory.fruits,
      'standardAmount': 0.5,
      'standardUnit': 'cup'
    },
    {
      'keywords': [
        'apple',
        'banana',
        'orange',
        'peach',
        'pear',
        'plum',
        'grape',
        'berry',
        'strawberry',
        'blueberry',
        'melon',
        'juice'
      ],
      'category': TrackerCategory.fruits,
      'standardAmount': 1.0,
      'standardUnit': 'cup'
    },
    // Dairy (cup-equivalents)
    {
      'keywords': ['milk', 'yogurt', 'soymilk'],
      'category': TrackerCategory.dairy,
      'standardAmount': 1.0,
      'standardUnit': 'cup'
    },
    {
      'keywords': ['cheese'],
      'category': TrackerCategory.dairy,
      'standardAmount': 1.5,
      'standardUnit': 'oz' // 1.5 oz hard cheese
    },
    // Protein (oz-equivalents)
    {
      'keywords': ['chicken', 'beef', 'pork', 'turkey', 'fish', 'salmon'],
      'category': TrackerCategory.protein,
      'standardAmount': 1.0,
      'standardUnit': 'oz'
    },
    {
      'keywords': ['egg'],
      'category': TrackerCategory.protein,
      'standardAmount': 1.0,
      'standardUnit': 'egg'
    },
    {
      'keywords': ['bean', 'lentil', 'chickpea', 'legume'],
      'category': TrackerCategory.protein,
      'standardAmount': 0.25,
      'standardUnit': 'cup'
    },
    {
      'keywords': ['peanut butter'],
      'category': TrackerCategory.protein,
      'standardAmount': 1.0,
      'standardUnit': 'tbsp'
    },
    {
      'keywords': ['almond', 'walnut', 'pistachio', 'nut', 'seed'],
      'category': TrackerCategory.protein,
      'standardAmount': 0.5,
      'standardUnit': 'oz'
    },
  ];

  @override
  Map<TrackerCategory, double> getServingsForIngredient({
    required String ingredientName,
    required double amount,
    required String unit,
    UnitConversionService? conversionService,
  }) {
    final name = ingredientName.toLowerCase();
    final cleanedUnit = unit.toLowerCase().trim();
    final servings = <TrackerCategory, double>{};

    if (cleanedUnit.startsWith('serving')) {
      for (final def in _servingDefinitions) {
        final List<String> keywords = def['keywords'];
        if (keywords.any((k) => name.contains(k))) {
          servings[def['category']] = (servings[def['category']] ?? 0) + amount;
          return servings;
        }
      }
      return servings;
    }

    for (final def in _servingDefinitions) {
      final List<String> keywords = def['keywords'];
      if (keywords.any((k) => name.contains(k))) {
        final category = def['category'] as TrackerCategory;
        final standardAmount = def['standardAmount'] as double;
        final standardUnit = def['standardUnit'] as String;
        double convertedAmount = 0;

        if (cleanedUnit == standardUnit ||
            (cleanedUnit + 's') == standardUnit ||
            cleanedUnit == (standardUnit + 's')) {
          convertedAmount = amount;
        } else if (conversionService != null) {
          convertedAmount = conversionService.convert(
            amount: amount,
            fromUnit: cleanedUnit,
            toUnit: standardUnit,
            ingredientName: name,
          );
        }

        if (convertedAmount > 0 && standardAmount > 0) {
          final calculatedServings = convertedAmount / standardAmount;
          servings[category] = (servings[category] ?? 0) + calculatedServings;
        }
      }
    }

    return servings;
  }

  @override
  List<TrackerGoal> getGoals(String userId) {
    // Based on a 2,000-calorie diet
    return [
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.fruits,
          goalValue: 2,
          unit: TrackerUnit.cups,
          isWeeklyGoal: false,
          dietType: 'MyPlate',
          name: 'Fruits'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.veggies,
          goalValue: 2.5,
          unit: TrackerUnit.cups,
          isWeeklyGoal: false,
          dietType: 'MyPlate',
          name: 'Veggies'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.grains,
          goalValue: 6,
          unit: TrackerUnit.oz,
          isWeeklyGoal: false,
          dietType: 'MyPlate',
          name: 'Grains'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.protein,
          goalValue: 5.5,
          unit: TrackerUnit.oz,
          isWeeklyGoal: false,
          dietType: 'MyPlate',
          name: 'Protein'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.dairy,
          goalValue: 3,
          unit: TrackerUnit.cups,
          isWeeklyGoal: false,
          dietType: 'MyPlate',
          name: 'Dairy'),
    ];
  }
}
