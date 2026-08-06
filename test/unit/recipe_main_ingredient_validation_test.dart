import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_main_ingredient_validation.dart';

void main() {
  late RecipeMainIngredientValidator validator;
  late RecipeIngredientPantryCounts counts;

  setUp(() {
    final conversion = UnitConversionService();
    final pantryService = PantryDeductionService(
      conversionService: conversion,
      substitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
    );
    counts = RecipeIngredientPantryCounts(pantryService);
    validator = RecipeMainIngredientValidator(counts: counts);
  });

  group('RecipeMainIngredientValidator', () {
    test('passes when main protein is in pantry', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'salmon fillet', amount: 2),
          _ingredient(name: 'ginger', amount: 1),
          _ingredient(name: 'soy sauce', amount: 1),
        ],
      );
      final pantry = [
        _pantry('Salmon', category: 'protein'),
        _pantry('Salt', category: 'seasonings'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isTrue);
      expect(result.gateSkipped, isFalse);
      expect(result.mainIngredientName, 'salmon fillet');
      expect(result.mainCategory, IngredientNutritionalCategory.protein);
    });

    test('fails when protein main is missing even if sides are in pantry', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'salmon fillet', amount: 2),
          _ingredient(name: 'rice', amount: 1),
        ],
      );
      final pantry = [
        _pantry('White Rice', category: 'grains'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isFalse);
      expect(result.mainIngredientName, 'salmon fillet');
    });

    test('fails Palak-style dish when paneer missing but spinach present', () {
      final recipe = _recipe(
        title: 'Palak Paneer',
        extendedIngredients: [
          _ingredient(name: 'spinach', amount: 500, unit: 'g'),
          _ingredient(name: 'paneer', amount: 200, unit: 'g'),
          _ingredient(name: 'salt', amount: 1),
        ],
      );
      final pantry = [
        _pantry('Spinach', category: 'fresh_veggies'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isFalse);
      expect(result.mainIngredientName, 'paneer');
      expect(result.mainCategory, IngredientNutritionalCategory.protein);
    });

    test('fails Beer Can Chicken when only onion is in pantry', () {
      final recipe = _recipe(
        title: 'Barbecued Beer Can Chicken',
        extendedIngredients: [
          _ingredient(name: 'onion', amount: 2),
          _ingredient(name: 'kosher salt', amount: 1),
          _ingredient(name: 'chicken', amount: 1),
        ],
      );
      final pantry = [
        _pantry('Onions', category: 'fresh_veggies'),
        _pantry('White Rice', category: 'grains'),
        _pantry('Salt', category: 'seasonings'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isFalse);
      expect(result.mainIngredientName, 'chicken');
      expect(result.mainCategory, IngredientNutritionalCategory.protein);
    });

    test('title protein gate passes when chicken is in pantry', () {
      final recipe = _recipe(
        title: 'Barbecued Beer Can Chicken',
        extendedIngredients: [
          _ingredient(name: 'onion', amount: 2),
          _ingredient(name: 'chicken', amount: 1),
        ],
      );
      final pantry = [
        _pantry('Chicken Breast', category: 'protein'),
        _pantry('Onions', category: 'fresh_veggies'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isTrue);
      expect(result.mainIngredientName, 'chicken');
    });

    test('ignores chicken stock as main when title has no protein', () {
      final recipe = _recipe(
        title: 'Simple Vegetable Soup',
        extendedIngredients: [
          _ingredient(name: 'chicken stock', amount: 4),
          _ingredient(name: 'carrot', amount: 2),
        ],
      );

      final main = validator.identifyMainIngredient(recipe);

      expect(main?.ingredient.name, 'carrot');
      expect(main?.category, IngredientNutritionalCategory.vegetable);
    });

    test('hamburger buns are not treated as protein main via ham', () {
      expect(
        IngredientNutritionalCategoryResolver.fromIngredientName(
          'hamburger buns',
        ),
        isNot(IngredientNutritionalCategory.protein),
      );
    });

    test('fish sauce is condiment not protein', () {
      expect(
        IngredientNutritionalCategoryResolver.fromIngredientName('fish sauce'),
        IngredientNutritionalCategory.condiment,
      );
    });

    test('uses highest-importance non-protein when recipe has no protein', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'carrot', amount: 3),
          _ingredient(name: 'celery', amount: 1),
          _ingredient(name: 'water', amount: 4),
        ],
      );

      final main = validator.identifyMainIngredient(recipe);

      expect(main?.ingredient.name, 'carrot');
      expect(main?.category, IngredientNutritionalCategory.vegetable);
    });

    test('passes vegetarian main when that vegetable is in pantry', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'carrot', amount: 3),
          _ingredient(name: 'celery', amount: 1),
        ],
      );
      final pantry = [
        _pantry('Carrots', category: 'fresh_veggies'),
      ];

      expect(validator.validate(recipe, pantry).passes, isTrue);
    });

    test('skips gate for empty pantry', () {
      final recipe = _recipe(
        extendedIngredients: [_ingredient(name: 'salmon fillet', amount: 2)],
      );

      final result = validator.validate(recipe, const []);

      expect(result.passes, isTrue);
      expect(result.gateSkipped, isTrue);
      expect(RecipeMainIngredientValidator.shouldEnforceGate(const []), isFalse);
    });

    test('skips gate for seasoning-only pantry', () {
      final recipe = _recipe(
        extendedIngredients: [_ingredient(name: 'salmon fillet', amount: 2)],
      );
      final pantry = [
        _pantry('Salt', category: 'seasonings'),
        _pantry('Pepper', category: 'seasonings'),
      ];

      final result = validator.validate(recipe, pantry);

      expect(result.passes, isTrue);
      expect(result.gateSkipped, isTrue);
    });

    test('ignores seasonings, condiments and water when picking main', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'water', amount: 2),
          _ingredient(name: 'soy sauce', amount: 1),
          _ingredient(name: 'salt', amount: 1),
          _ingredient(name: 'spinach', amount: 2),
        ],
      );

      final main = validator.identifyMainIngredient(recipe);

      expect(main?.ingredient.name, 'spinach');
    });
  });
}

Recipe _recipe({
  int id = 1,
  String title = 'Test',
  List<RecipeIngredient>? extendedIngredients,
}) {
  return Recipe(
    id: id,
    title: title,
    image: '',
    readyInMinutes: 30,
    servings: 2,
    sourceUrl: '',
    summary: '',
    cuisines: const [],
    dishTypes: const [],
    diets: const [],
    extendedIngredients: extendedIngredients ?? const [],
    analyzedInstructions: const [],
    vegetarian: false,
    vegan: false,
    glutenFree: true,
    dairyFree: true,
    veryHealthy: true,
    cheap: false,
    veryPopular: false,
    sustainable: false,
    lowFodmap: false,
    weightWatcherSmartPoints: 0,
    gaps: '',
    pricePerServing: 0,
    aggregateLikes: 0,
    healthScore: 0,
    creditsText: '',
    license: '',
    sourceName: '',
    spoonacularScore: 0,
    spoonacularSourceUrl: '',
  );
}

RecipeIngredient _ingredient({
  required String name,
  double amount = 1,
  String unit = 'cup',
}) {
  return RecipeIngredient(
    id: name.hashCode,
    aisle: '',
    image: '',
    consistency: '',
    name: name,
    nameClean: name,
    original: name,
    originalName: name,
    amount: amount,
    unit: unit,
    meta: const [],
    measures: Measures(
      us: Measure(amount: amount, unitShort: unit, unitLong: unit),
      metric: Measure(amount: amount, unitShort: unit, unitLong: unit),
    ),
  );
}

PantryItem _pantry(
  String name, {
  required String category,
}) {
  return PantryItem(
    id: name,
    name: name,
    imageUrl: '',
    category: category,
    quantity: 5,
    unit: UnitType.piece,
    expirationDate: DateTime.now().add(const Duration(days: 7)),
  );
}
