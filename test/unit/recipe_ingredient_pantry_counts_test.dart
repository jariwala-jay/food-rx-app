import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_servings_display.dart';

void main() {
  late PantryDeductionService pantryService;
  late RecipeIngredientPantryCounts counts;

  setUp(() {
    final conversion = UnitConversionService();
    pantryService = PantryDeductionService(
      conversionService: conversion,
      substitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
    );
    counts = RecipeIngredientPantryCounts(pantryService);
  });

  group('RecipeIngredient.resolveDisplayName', () {
    test('dedupes repeated nameClean from API', () {
      expect(
        RecipeIngredient.resolveDisplayName('celery celery', 'celery'),
        'celery',
      );
    });

    test('falls back to name when nameClean is empty', () {
      expect(
        RecipeIngredient.resolveDisplayName('', 'celery'),
        'celery',
      );
    });
  });

  group('RecipeIngredient.sanitizeUnit', () {
    test('removes duplicate name when unit equals ingredient', () {
      expect(
        RecipeIngredient.sanitizeUnit('celery', 'celery'),
        '',
      );
    });

    test('removes name embedded in unit', () {
      expect(
        RecipeIngredient.sanitizeUnit('cups celery', 'celery'),
        'cups',
      );
    });
  });

  group('RecipeIngredient.isOptionalIngredient', () {
    test('detects optional in original text', () {
      final ing = _ingredient(name: 'parsley', original: 'parsley, optional');
      expect(ing.isOptionalIngredient, isTrue);
    });

    test('required ingredient is not optional', () {
      final ing = _ingredient(name: 'broccoli', original: '1 1/2 pounds broccoli');
      expect(ing.isOptionalIngredient, isFalse);
    });
  });

  group('RecipeIngredient.formatDisplayLine', () {
    test('appends optional suffix for sesame seeds line', () {
      final ing = _ingredient(
        name: 'sesame seeds',
        original: 'toasted sesame seeds, optional',
      );
      expect(
        ing.formatDisplayLine('2 pieces sesame seeds'),
        '2 pieces sesame seeds optional',
      );
    });
  });

  group('Recipe required vs optional ingredient lines', () {
    test('badges count required lines only (13 listed, 12 required)', () {
      final recipe = _recipe(
        extendedIngredients: List.generate(
          12,
          (i) => _ingredient(name: 'item$i'),
        )
          ..add(_ingredient(
            name: 'sesame seeds',
            original: 'toasted sesame seeds, optional',
          )),
      );
      expect(recipe.extendedIngredients.length, 13);
      expect(recipe.requiredIngredientLineCount, 12);
      expect(recipe.optionalIngredientLineCount, 1);
    });
  });

  group('Recipe.requiredMissedIngredientCount', () {
    test('excludes optional from missedIngredients list', () {
      final recipe = _recipe(
        missedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
          _ingredient(name: 'garnish', original: 'lemon zest (optional)'),
        ],
        missedIngredientCount: 99,
      );
      expect(recipe.requiredMissedIngredientCount, 2);
    });
  });

  group('RecipeIngredientPantryCounts', () {
    test('green and orange exclude optional ingredients', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
          _ingredient(name: 'lemon juice'),
          _ingredient(name: 'garnish', original: 'parsley (optional)'),
        ],
      );
      final pantry = [
        _pantryItem('broccoli'),
        _pantryItem('garlic'),
      ];

      expect(counts.inPantryCount(recipe, pantry), 2);
      expect(counts.requiredMissingCount(recipe, pantry), 1);
    });

    test('green plus orange equals required ingredient lines', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
          _ingredient(name: 'lemon juice'),
          _ingredient(name: 'rice vinegar'),
          _ingredient(name: 'dijon mustard'),
          _ingredient(name: 'chili flakes', original: 'chili flakes (optional)'),
        ],
      );
      final pantry = [_pantryItem('broccoli')];

      final green = counts.inPantryCount(recipe, pantry);
      final orange = counts.requiredMissingCount(recipe, pantry);
      const requiredLines = 5;

      expect(green + orange, requiredLines);
      expect(green, 1);
      expect(orange, 4);
    });

    test('list and detail use same counts for same recipe and pantry', () {
      final recipe = _recipe(
        servings: 4,
        extendedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
          _ingredient(name: 'lemon juice'),
          _ingredient(name: 'rice vinegar'),
          _ingredient(name: 'dijon mustard'),
          _ingredient(name: 'salt'),
          _ingredient(name: 'pepper'),
          _ingredient(name: 'oil', original: 'olive oil (optional)'),
        ],
      );
      final pantry = [
        _pantryItem('broccoli'),
        _pantryItem('garlic'),
      ];

      // Simulates recipe list card (scaled to 2 servings).
      final listRecipe =
          RecipeServingsDisplay.forCounts(recipe, targetServings: 2);
      // Simulates detail page at same target servings.
      final detailRecipe =
          RecipeServingsDisplay.forCounts(recipe, targetServings: 2);

      expect(
        counts.inPantryCount(listRecipe, pantry),
        counts.inPantryCount(detailRecipe, pantry),
      );
      expect(
        counts.requiredMissingCount(listRecipe, pantry),
        counts.requiredMissingCount(detailRecipe, pantry),
      );
    });

    test('scaled recipe keeps same ingredient line count as original', () {
      final recipe = _recipe(
        servings: 4,
        extendedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
          _ingredient(name: 'lemon juice'),
        ],
      );
      final scaled =
          RecipeServingsDisplay.forCounts(recipe, targetServings: 2);

      expect(scaled.extendedIngredients.length, recipe.extendedIngredients.length);
      expect(scaled.servings, 2);
    });

    test('empty pantry yields green 0 and orange equal to required lines', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'broccoli'),
          _ingredient(name: 'garlic'),
        ],
      );

      expect(counts.inPantryCount(recipe, const []), 0);
      expect(counts.requiredMissingCount(recipe, const []), 2);
    });
  });
}

Measures _emptyMeasures() => Measures(
      us: Measure(amount: 0, unitShort: 'g', unitLong: 'grams'),
      metric: Measure(amount: 0, unitShort: 'g', unitLong: 'grams'),
    );

RecipeIngredient _ingredient({
  required String name,
  String original = '',
}) {
  final line = original.isNotEmpty ? original : name;
  return RecipeIngredient(
    id: name.hashCode,
    aisle: '',
    image: '',
    consistency: '',
    name: name,
    nameClean: name,
    original: line,
    originalName: line,
    amount: 1,
    unit: 'cup',
    meta: const [],
    measures: _emptyMeasures(),
  );
}

Recipe _recipe({
  int servings = 2,
  List<RecipeIngredient>? extendedIngredients,
  List<RecipeIngredient> missedIngredients = const [],
  int? missedIngredientCount,
}) {
  return Recipe(
    id: 1,
    title: 'Test Recipe',
    image: '',
    readyInMinutes: 30,
    servings: servings,
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
    missedIngredients: missedIngredients,
    missedIngredientCount: missedIngredientCount,
  );
}

PantryItem _pantryItem(String name) => PantryItem(
      id: name,
      name: name,
      imageUrl: '',
      category: 'produce',
      quantity: 5,
      unit: UnitType.piece,
      expirationDate: DateTime.now().add(const Duration(days: 7)),
    );
