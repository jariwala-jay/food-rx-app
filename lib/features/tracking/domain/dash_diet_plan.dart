import 'package:flutter_app/features/tracking/domain/diet_plan.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

class DashDietPlan implements DietPlan {
  @override
  DietPlanType get type => DietPlanType.dash;

  // Official DASH Diet Serving Size Definitions
  // Source: National Heart, Lung, and Blood Institute (NHLBI)
  // Each entry defines:
  // - keywords: to match ingredient names
  // - category: the TrackerCategory it belongs to
  // - standardAmount: the quantity for one serving
  // - standardUnit: the unit for one serving
  static final List<Map<String, dynamic>> _servingDefinitions = [
    // Grains
    {
      'keywords': ['bread'],
      'category': TrackerCategory.grains,
      'standardAmount': 1.0,
      'standardUnit': 'slice'
    },
    {
      'keywords': ['cereal', 'oats', 'oatmeal'],
      'category': TrackerCategory.grains,
      'standardAmount': 1.0,
      'standardUnit': 'oz'
    },
    {
      'keywords': ['rice', 'pasta', 'noodle', 'quinoa', 'couscous'],
      'category': TrackerCategory.grains,
      'standardAmount': 0.5,
      'standardUnit': 'cup'
    },
    // Veggies
    {
      'keywords': ['spinach', 'lettuce', 'kale', 'greens'],
      'category': TrackerCategory.veggies,
      'standardAmount': 1.0,
      'standardUnit': 'cup'
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
      'standardAmount': 0.5,
      'standardUnit': 'cup'
    },
    // Fruits
    {
      'keywords': [
        'apple',
        'banana',
        'orange',
        'peach',
        'pear',
        'plum',
        'apricot',
        'mango',
        'tangerine'
      ],
      'category': TrackerCategory.fruits,
      'standardAmount': 1.0,
      'standardUnit': 'medium'
    },
    {
      'keywords': ['grape', 'berry', 'strawberry', 'blueberry', 'melon'],
      'category': TrackerCategory.fruits,
      'standardAmount': 0.5,
      'standardUnit': 'cup'
    },
    {
      'keywords': ['raisin', 'date', 'dried fruit'],
      'category': TrackerCategory.fruits,
      'standardAmount': 0.25,
      'standardUnit': 'cup'
    },
    // Dairy
    {
      'keywords': ['milk', 'yogurt'],
      'category': TrackerCategory.dairy,
      'standardAmount': 1.0,
      'standardUnit': 'cup'
    },
    {
      'keywords': ['cheese'],
      'category': TrackerCategory.dairy,
      'standardAmount': 1.5,
      'standardUnit': 'oz'
    },
    // Lean Meat, Poultry, Fish
    {
      'keywords': ['chicken', 'beef', 'pork', 'turkey', 'fish', 'salmon'],
      'category': TrackerCategory.leanMeat,
      'standardAmount': 1.0,
      'standardUnit': 'oz'
    },
    {
      'keywords': ['egg'],
      'category': TrackerCategory.leanMeat,
      'standardAmount': 1.0,
      'standardUnit': 'egg'
    },
    // Nuts, Seeds, Legumes
    {
      'keywords': ['almond', 'walnut', 'pecan', 'cashew', 'pistachio', 'nut'],
      'category': TrackerCategory.nutsLegumes,
      'standardAmount': 1.0 / 3.0,
      'standardUnit': 'cup'
    },
    {
      'keywords': ['peanut butter'],
      'category': TrackerCategory.nutsLegumes,
      'standardAmount': 2.0,
      'standardUnit': 'tbsp'
    },
    {
      'keywords': ['sunflower seed', 'pumpkin seed', 'seed'],
      'category': TrackerCategory.nutsLegumes,
      'standardAmount': 2.0,
      'standardUnit': 'tbsp'
    },
    {
      'keywords': ['bean', 'lentil', 'chickpea', 'legume'],
      'category': TrackerCategory.nutsLegumes,
      'standardAmount': 0.5,
      'standardUnit': 'cup'
    },
    // Fats & Oils
    {
      'keywords': ['oil', 'margarine'],
      'category': TrackerCategory.fatsOils,
      'standardAmount': 1.0,
      'standardUnit': 'tsp'
    },
    {
      'keywords': ['mayonnaise'],
      'category': TrackerCategory.fatsOils,
      'standardAmount': 1.0,
      'standardUnit': 'tbsp'
    },
    {
      'keywords': ['salad dressing'],
      'category': TrackerCategory.fatsOils,
      'standardAmount': 2.0,
      'standardUnit': 'tbsp'
    },
    // Sweets
    {
      'keywords': ['sugar', 'jelly', 'jam', 'syrup', 'honey'],
      'category': TrackerCategory.sweets,
      'standardAmount': 1.0,
      'standardUnit': 'tbsp'
    },
    {
      'keywords': ['sorbet', 'sherbet'],
      'category': TrackerCategory.sweets,
      'standardAmount': 0.5,
      'standardUnit': 'cup'
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

    // If the unit is already "servings", we can't process it further without a category.
    // The logs show this causes major errors. We will assume 1 serving maps to the most likely category.
    if (cleanedUnit.startsWith('serving')) {
      for (final def in _servingDefinitions) {
        final List<String> keywords = def['keywords'];
        if (keywords.any((k) => name.contains(k))) {
          servings[def['category']] = (servings[def['category']] ?? 0) + amount;
          // Return on first match for servings to avoid double counting
          return servings;
        }
      }
      return servings; // Return empty if no keyword match for a "serving" unit
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
    return [
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.grains,
          goalValue: 6,
          unit: TrackerUnit.servings,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Grains'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.veggies,
          goalValue: 4,
          unit: TrackerUnit.servings,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Veggies'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.fruits,
          goalValue: 4,
          unit: TrackerUnit.servings,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Fruits'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.dairy,
          goalValue: 2,
          unit: TrackerUnit.servings,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Low-fat/fat-free Dairy'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.leanMeat,
          goalValue: 6,
          unit: TrackerUnit.oz,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Lean Meat, Poultry, Fish'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.nutsLegumes,
          goalValue: 4,
          unit: TrackerUnit.servings,
          isWeeklyGoal: true,
          dietType: 'DASH',
          name: 'Nuts, Seeds, Legumes'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.fatsOils,
          goalValue: 2,
          unit: TrackerUnit.servings,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Fats/oils'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.sweets,
          goalValue: 5,
          unit: TrackerUnit.servings,
          isWeeklyGoal: true,
          dietType: 'DASH',
          name: 'Sweets'),
      TrackerGoal(
          id: ObjectId().toHexString(),
          userId: userId,
          category: TrackerCategory.sodium,
          goalValue: 2300,
          unit: TrackerUnit.mg,
          isWeeklyGoal: false,
          dietType: 'DASH',
          name: 'Sodium'),
    ];
  }
}
