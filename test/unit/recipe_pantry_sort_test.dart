import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_pantry_sort.dart';

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

  group('IngredientNutritionalCategoryResolver', () {
    test('seasoning/condiment name wins over misfiled pantry category', () {
      expect(
        IngredientNutritionalCategoryResolver.resolve(
          ingredientName: 'salt',
          pantryCategoryKey: 'protein',
        ),
        IngredientNutritionalCategory.seasoning,
      );
      expect(
        IngredientNutritionalCategoryResolver.resolve(
          ingredientName: 'olive oil',
          pantryCategoryKey: 'dairy',
        ),
        IngredientNutritionalCategory.condiment,
      );
    });

    test('pantry category still wins for non-seasoning ingredients', () {
      expect(
        IngredientNutritionalCategoryResolver.resolve(
          ingredientName: 'mystery item',
          pantryCategoryKey: 'protein',
        ),
        IngredientNutritionalCategory.protein,
      );
    });

    test('falls back to seasoning keywords for generic pantry category', () {
      expect(
        IngredientNutritionalCategoryResolver.resolve(
          ingredientName: 'paprika',
          pantryCategoryKey: 'other',
        ),
        IngredientNutritionalCategory.seasoning,
      );
    });
  });

  group('RecipePantryRelevanceScore', () {
    test('completion ratio is have / (have + need)', () {
      const score = RecipePantryRelevanceScore(
        pantryRelevanceScore: 10,
        inPantry: 4,
        requiredMissing: 5,
        expiringBonus: 0,
      );
      expect(score.requiredTotal, 9);
      expect(score.completionRatio, closeTo(4 / 9, 0.001));
    });

    test('orders by fewer missing first, then completion, then pantry score',
        () {
      // High pantry score but more missing should lose to low score / fewer missing.
      const moreMissingHighScore = RecipePantryRelevanceScore(
        pantryRelevanceScore: 10,
        inPantry: 3,
        requiredMissing: 5,
        expiringBonus: 0,
      );
      const fewerMissingLowScore = RecipePantryRelevanceScore(
        pantryRelevanceScore: 2,
        inPantry: 4,
        requiredMissing: 1,
        expiringBonus: 0,
      );

      expect(
        fewerMissingLowScore.compareRankingTo(moreMissingHighScore),
        lessThan(0),
      );
    });

    test('when missing is equal, higher completion ratio wins', () {
      const lowCoverage = RecipePantryRelevanceScore(
        pantryRelevanceScore: 10,
        inPantry: 2,
        requiredMissing: 4,
        expiringBonus: 0,
      );
      const highCoverage = RecipePantryRelevanceScore(
        pantryRelevanceScore: 5,
        inPantry: 4,
        requiredMissing: 4,
        expiringBonus: 0,
      );

      expect(highCoverage.compareRankingTo(lowCoverage), lessThan(0));
    });

    test('when missing and coverage equal, higher pantry score wins', () {
      const need5 = RecipePantryRelevanceScore(
        pantryRelevanceScore: 10,
        inPantry: 4,
        requiredMissing: 5,
        expiringBonus: 0,
      );
      const need5LowerScore = RecipePantryRelevanceScore(
        pantryRelevanceScore: 3,
        inPantry: 4,
        requiredMissing: 5,
        expiringBonus: 0,
      );

      expect(need5.compareRankingTo(need5LowerScore), lessThan(0));
    });
  });

  group('RecipePantryMatchScore (legacy)', () {
    test('orders by fewest need first', () {
      const need5 = RecipePantryMatchScore(inPantry: 4, requiredMissing: 5);
      const need1 = RecipePantryMatchScore(inPantry: 2, requiredMissing: 1);

      final ordered = [need5, need1]..sort((a, b) => a.compareEaseTo(b));
      expect(ordered, [need1, need5]);
    });
  });

  group('Phase 1 ranking', () {
    final pantry = [
      _pantry('Chicken', category: 'protein'),
      _pantry('Spinach', category: 'fresh_veggies'),
      _pantry('Rice', category: 'grains'),
      _pantry('Salt', category: 'seasonings'),
      _pantry('Pepper', category: 'seasonings'),
      _pantry('Paprika', category: 'seasonings'),
      _pantry('Chili powder', category: 'seasonings'),
    ];

    test('meaningful ingredients outrank seasoning-only matches', () {
      final mealRecipe = _recipe(
        id: 1,
        title: 'Chicken Spinach Bowl',
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'spinach'),
          _ingredient(name: 'rice'),
        ],
      );
      final spiceRecipe = _recipe(
        id: 2,
        title: 'Spice Mix',
        extendedIngredients: [
          _ingredient(name: 'salt'),
          _ingredient(name: 'pepper'),
          _ingredient(name: 'paprika'),
          _ingredient(name: 'chili powder'),
        ],
      );

      final mealScore = RecipePantrySort.score(mealRecipe, pantry, counts);
      final spiceScore = RecipePantrySort.score(spiceRecipe, pantry, counts);

      expect(mealScore.pantryRelevanceScore, greaterThan(spiceScore.pantryRelevanceScore));
      expect(mealScore.pantryRelevanceScore, closeTo(10, 0.001));
      expect(spiceScore.pantryRelevanceScore, closeTo(2, 0.001));

      final recipes = [spiceRecipe, mealRecipe];
      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: pantry,
        counts: counts,
      );
      expect(recipes.first.id, mealRecipe.id);
    });

    test('expiring pantry item adds bonus over non-expiring match', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final nextWeek = DateTime.now().add(const Duration(days: 7));

      final expiringPantry = [
        _pantry('Chicken', category: 'protein', expirationDate: tomorrow),
      ];
      final freshPantry = [
        _pantry('Chicken', category: 'protein', expirationDate: nextWeek),
      ];

      final recipe = _recipe(
        extendedIngredients: [_ingredient(name: 'chicken breast')],
      );

      final expiringScore =
          RecipePantrySort.score(recipe, expiringPantry, counts);
      final freshScore = RecipePantrySort.score(recipe, freshPantry, counts);

      expect(expiringScore.expiringBonus, 3);
      expect(freshScore.expiringBonus, 0);
      expect(
        expiringScore.pantryRelevanceScore,
        greaterThan(freshScore.pantryRelevanceScore),
      );
    });

    test('matched ingredients expose category metadata', () {
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'spinach'),
        ],
      );

      final matched = counts.matchedRequiredIngredients(recipe, pantry);
      expect(matched.length, 2);
      expect(matched[0].category, IngredientNutritionalCategory.protein);
      expect(matched[1].category, IngredientNutritionalCategory.vegetable);
    });

    test('one pantry item contributes protein weight once across duplicate lines',
        () {
      final chickenOnly = [_pantry('Chicken Breast', category: 'protein')];
      final recipe = _recipe(
        title: 'Chicken Piccata',
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'chicken stock'),
          _ingredient(name: 'chicken broth'),
        ],
      );

      final score = RecipePantrySort.score(recipe, chickenOnly, counts);

      expect(score.matchedIngredients.length, 3);
      expect(score.pantryRelevanceScore, closeTo(5, 0.001));
    });

    test('different pantry items in same category each contribute weight', () {
      final pantryItems = [
        _pantry('Chicken Breast', category: 'protein'),
        _pantry('Eggs', category: 'protein'),
      ];
      final recipe = _recipe(
        title: 'Chicken omelette',
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'eggs'),
        ],
      );

      final score = RecipePantrySort.score(recipe, pantryItems, counts);

      expect(score.pantryRelevanceScore, closeTo(10, 0.001));
    });

    test('seasonings still add half-point weights alongside protein', () {
      final pantryItems = [
        _pantry('Chicken Breast', category: 'protein'),
        _pantry('Salt', category: 'seasonings'),
        _pantry('Pepper', category: 'seasonings'),
      ];
      final recipe = _recipe(
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'salt'),
          _ingredient(name: 'pepper'),
        ],
      );

      final score = RecipePantrySort.score(recipe, pantryItems, counts);

      expect(score.pantryRelevanceScore, closeTo(6, 0.001));
    });

    test('similar missing counts keep stable health-score tiebreaker', () {
      final recipeA = _recipe(
        id: 1,
        title: 'A',
        healthScore: 90,
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'garlic'),
        ],
      );
      final recipeB = _recipe(
        id: 2,
        title: 'B',
        healthScore: 50,
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'ginger'),
        ],
      );

      final recipes = [recipeB, recipeA];
      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: pantry,
        counts: counts,
        tiebreaker: (a, b) => b.healthScore.compareTo(a.healthScore),
      );

      expect(recipes.first.healthScore, 90);
    });

    test('when ease is equal, preferred cuisines rank above others', () {
      final chickenOnly = [_pantry('Chicken', category: 'protein')];
      final indian = _recipe(
        id: 1,
        title: 'Indian Chicken',
        cuisines: const ['indian'],
        extendedIngredients: [_ingredient(name: 'chicken breast')],
      );
      final chinese = _recipe(
        id: 2,
        title: 'Chinese Chicken',
        cuisines: const ['chinese'],
        extendedIngredients: [_ingredient(name: 'chicken breast')],
      );
      final french = _recipe(
        id: 3,
        title: 'French Chicken',
        cuisines: const ['french'],
        extendedIngredients: [_ingredient(name: 'chicken breast')],
      );

      final recipes = [french, chinese, indian];
      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: chickenOnly,
        counts: counts,
        preferredCuisines: const [
          CuisineType.indian,
          CuisineType.chinese,
          CuisineType.american,
        ],
      );

      // Indian/Chinese are interleaved (order between them is randomized —
      // see the round-robin test below); "other" (French) is always last.
      expect(recipes.take(2).map((r) => r.id).toSet(), {1, 2});
      expect(recipes.last.id, 3);
    });

    test('ties interleave cuisines round-robin instead of fixed blocks', () {
      final chickenOnly = [_pantry('Chicken', category: 'protein')];
      Recipe make(int id, String cuisine, String label) => _recipe(
            id: id,
            title: '$cuisine $label',
            cuisines: [cuisine],
            extendedIngredients: [_ingredient(name: 'chicken breast')],
          );

      final recipes = [
        make(1, 'american', 'A1'),
        make(2, 'chinese', 'C1'),
        make(3, 'indian', 'I1'),
        make(4, 'american', 'A2'),
        make(5, 'chinese', 'C2'),
        make(6, 'indian', 'I2'),
      ];

      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: chickenOnly,
        counts: counts,
        preferredCuisines: const [
          CuisineType.american,
          CuisineType.chinese,
          CuisineType.indian,
        ],
        random: Random(3),
      );

      // Round-robin: each cuisine appears exactly once per round of 3,
      // never a full block of the same cuisine back-to-back.
      final round1 = recipes.sublist(0, 3).map((r) => r.cuisines.single).toSet();
      final round2 = recipes.sublist(3, 6).map((r) => r.cuisines.single).toSet();
      expect(round1, {'american', 'chinese', 'indian'});
      expect(round2, {'american', 'chinese', 'indian'});
    });

    test('cuisine visiting order varies with the random seed', () {
      final chickenOnly = [_pantry('Chicken', category: 'protein')];
      Recipe make(int id, String cuisine) => _recipe(
            id: id,
            title: cuisine,
            cuisines: [cuisine],
            extendedIngredients: [_ingredient(name: 'chicken breast')],
          );

      final base = [
        make(1, 'american'),
        make(2, 'chinese'),
        make(3, 'indian'),
      ];
      const preferred = [
        CuisineType.american,
        CuisineType.chinese,
        CuisineType.indian,
      ];

      final orderA = List<Recipe>.of(base);
      RecipePantrySort.sortByEasiestToMake(
        orderA,
        pantry: chickenOnly,
        counts: counts,
        preferredCuisines: preferred,
        random: Random(1),
      );

      final orderB = List<Recipe>.of(base);
      RecipePantrySort.sortByEasiestToMake(
        orderB,
        pantry: chickenOnly,
        counts: counts,
        preferredCuisines: preferred,
        random: Random(3),
      );

      expect(
        orderA.map((r) => r.id).toList(),
        isNot(equals(orderB.map((r) => r.id).toList())),
      );
    });

    test(
        'missing-count is a hard boundary; completion % ordering is '
        'preserved within a cuisine inside a tier', () {
      final pantryItems = [
        _pantry('Chicken', category: 'protein'),
        _pantry('Rice', category: 'grains'),
        _pantry('Onion', category: 'fresh_veggies'),
      ];

      // missing=0, unselected cuisine — must still rank first: fewer
      // missing ingredients always wins, even over a preferred cuisine.
      final mexicanNoMissing = _recipe(
        id: 10,
        title: 'Mexican No Missing',
        cuisines: const ['mexican'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'rice'),
        ],
      );

      // missing=1 tier, two American recipes with different completion %.
      final americanHighCompletion = _recipe(
        id: 1,
        title: 'American High Completion',
        cuisines: const ['american'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'rice'),
          _ingredient(name: 'onion'),
          _ingredient(name: 'mushroom'),
        ],
      );
      final americanLowCompletion = _recipe(
        id: 2,
        title: 'American Low Completion',
        cuisines: const ['american'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'beef'),
        ],
      );
      final chinese = _recipe(
        id: 3,
        title: 'Chinese',
        cuisines: const ['chinese'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'rice'),
          _ingredient(name: 'shrimp'),
        ],
      );
      final indian = _recipe(
        id: 4,
        title: 'Indian',
        cuisines: const ['indian'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'paneer'),
        ],
      );

      final recipes = [
        chinese,
        americanLowCompletion,
        indian,
        mexicanNoMissing,
        americanHighCompletion,
      ];

      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: pantryItems,
        counts: counts,
        preferredCuisines: const [
          CuisineType.american,
          CuisineType.chinese,
          CuisineType.indian,
        ],
        random: Random(3),
      );

      // Missing=0 always first, regardless of cuisine.
      expect(recipes.first.id, mexicanNoMissing.id);

      // Round 1 of the missing=1 tier interleaves one recipe per cuisine.
      final round1Ids = recipes.sublist(1, 4).map((r) => r.id).toSet();
      expect(round1Ids, {
        americanHighCompletion.id,
        chinese.id,
        indian.id,
      });

      // Round 2: only American has a second recipe left — and it's the
      // lower-completion one, proving the bucket kept its internal
      // completion-based order rather than being reshuffled.
      expect(recipes.last.id, americanLowCompletion.id);
    });

    test('fewer missing beats preferred cuisine with more shopping', () {
      final pantryItems = [
        _pantry('Chicken', category: 'protein'),
        _pantry('Rice', category: 'grains'),
        _pantry('Onion', category: 'fresh_veggies'),
      ];
      // Preferred cuisine but needs lots of shopping.
      final hardAmerican = _recipe(
        id: 1,
        title: 'Hard American',
        cuisines: const ['american'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'cheese'),
          _ingredient(name: 'bacon'),
          _ingredient(name: 'tomato'),
          _ingredient(name: 'lettuce'),
        ],
      );
      // Non-preferred but almost cookable.
      final easyChinese = _recipe(
        id: 2,
        title: 'Easy Chinese',
        cuisines: const ['chinese'],
        extendedIngredients: [
          _ingredient(name: 'chicken breast'),
          _ingredient(name: 'rice'),
          _ingredient(name: 'onion'),
        ],
      );

      final recipes = [hardAmerican, easyChinese];
      RecipePantrySort.sortByEasiestToMake(
        recipes,
        pantry: pantryItems,
        counts: counts,
        preferredCuisines: const [CuisineType.american],
      );

      expect(recipes.first.id, easyChinese.id);
    });
  });
}

Recipe _recipe({
  int id = 1,
  String title = 'Test',
  double healthScore = 0,
  List<String> cuisines = const [],
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
    cuisines: cuisines,
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
    healthScore: healthScore,
    creditsText: '',
    license: '',
    sourceName: '',
    spoonacularScore: 0,
    spoonacularSourceUrl: '',
  );
}

RecipeIngredient _ingredient({required String name}) {
  return RecipeIngredient(
    id: name.hashCode,
    aisle: '',
    image: '',
    consistency: '',
    name: name,
    nameClean: name,
    original: name,
    originalName: name,
    amount: 1,
    unit: 'cup',
    meta: const [],
    measures: Measures(
      us: Measure(amount: 1, unitShort: 'cup', unitLong: 'cup'),
      metric: Measure(amount: 1, unitShort: 'cup', unitLong: 'cup'),
    ),
  );
}

PantryItem _pantry(
  String name, {
  required String category,
  DateTime? expirationDate,
}) {
  return PantryItem(
    id: name,
    name: name,
    imageUrl: '',
    category: category,
    quantity: 5,
    unit: UnitType.piece,
    expirationDate: expirationDate ?? DateTime.now().add(const Duration(days: 7)),
  );
}
