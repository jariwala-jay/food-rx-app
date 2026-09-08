import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';

/// End-to-end regression for the "0 candidates" bug: drives the real
/// fallback ladder in RecipeGenerationService through a fake repository that
/// only returns recipes once includeIngredients is dropped (the last-resort
/// tier), and proves two things the includeIngredients/health-relaxation fix
/// alone doesn't guarantee:
///
/// 1. Every fallback attempt before the last one still carries a (capped)
///    includeIngredients param — the ladder isn't skipping straight to "no
///    ingredients at all".
/// 2. Recipes surfaced by the includeIngredients-dropped tier still go
///    through the same local pipeline (_hasEnoughIngredients, main
///    ingredient validation) as every other tier — dropping the API-side
///    filter must not let an arbitrary Spoonacular recipe through.
void main() {
  late _FakeRecipeRepository fakeRepository;
  late RecipeGenerationService service;

  setUp(() {
    fakeRepository = _FakeRecipeRepository();
    final conversion = UnitConversionService();
    service = RecipeGenerationService(
      recipeRepository: fakeRepository,
      unitConversionService: conversion,
      foodCategoryService: FoodCategoryService(conversionService: conversion),
      ingredientSubstitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
      dietConstraintsService: DietConstraintsService(),
      // These tests assert exactly which tier produces which recipes, not
      // cross-tier accumulation — pin the threshold to 1 so the ladder still
      // stops at the first tier that returns anything, matching what each
      // test's assertions expect.
      minUsefulCandidates: 1,
    );
  });

  test(
      'includeIngredients-dropped tier only fires last, and still filters '
      'out recipes that fail local pantry / main-ingredient validation', () async {
    final pantryItems = [
      _pantry('Oranges', category: 'fresh_fruits'),
      _pantry('coconut', category: 'other'),
      _pantry('Frozen Mixed Berries', category: 'frozen_fruits'),
      _pantry('Frozen Raspberries', category: 'frozen_fruits'),
      _pantry('White Beans', category: 'beans'),
      _pantry('Canned Tomatoes', category: 'canned_veggies'),
      _pantry('Chicken Breast', category: 'meat'),
      _pantry('Chicken Thighs', category: 'meat'),
    ];

    // Only respond with candidates once includeIngredients has been dropped
    // — simulates the capped top-3 query, then the health-relaxed query,
    // both still returning 0 from Spoonacular.
    final goodRecipe = _recipe(
      id: 1,
      title: 'Chicken Breakfast Skillet',
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 2)],
    );
    final missingMainIngredientRecipe = _recipe(
      id: 2,
      title: 'Salmon Breakfast Bowl',
      extendedIngredients: [_ingredient(name: 'salmon fillet', amount: 2)],
    );
    final tooManyMissingRecipe = _recipe(
      id: 3,
      title: 'Everything Bagel Feast',
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 1)],
      missedIngredients: List.generate(
        9,
        (i) => _ingredient(name: 'exotic ingredient $i'),
      ),
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (pantryIngredients.isEmpty) {
        return [goodRecipe, missingMainIngredientRecipe, tooManyMissingRecipe];
      }
      return const [];
    });

    const filter = RecipeFilter(
      cuisines: [CuisineType.indian],
      mealType: MealType.breakfast,
      maxReadyTime: 60,
      medicalConditions: [MedicalCondition.hypertension],
      dashCompliant: true,
      veryHealthy: true,
      maxSodium: 500,
    );

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    // Every call before the last one must still carry a capped (non-empty,
    // and never the full 8-item pantry) includeIngredients list.
    expect(fakeRepository.calls.length, greaterThanOrEqualTo(2));
    final callsBeforeLast =
        fakeRepository.calls.sublist(0, fakeRepository.calls.length - 1);
    for (final call in callsBeforeLast) {
      expect(call.pantryIngredients, isNotEmpty);
      expect(call.pantryIngredients.length, lessThan(8));
    }

    // The final call is the one that actually returned candidates, and it's
    // the one with includeIngredients dropped.
    final lastCall = fakeRepository.calls.last;
    expect(lastCall.pantryIngredients, isEmpty);

    // Local validation still ran on the includeIngredients-dropped results:
    // only the recipe whose main ingredient is in the pantry, and that
    // doesn't miss too many ingredients, survives.
    expect(results.map((r) => r.id), [1]);
    expect(results.map((r) => r.id), isNot(contains(2)));
    expect(results.map((r) => r.id), isNot(contains(3)));
  });

  // Regression: Spoonacular's own dataset has 0 recipes tagged both
  // cuisine=indian and type=breakfast (verified directly against the live
  // API), even though cuisine=indian alone has plenty. Only once the `type`
  // param itself is dropped (suppressTypeParam) does the fake repo return
  // candidates — proving the ladder reaches that tier, and that the local
  // breakfast allowlist (_matchesBreakfastIntent) still keeps out an obvious
  // lunch/dinner dish that slips through once Spoonacular's own dishType
  // filter is gone.
  test(
      'dropping the breakfast type filter still keeps out non-breakfast '
      'dishes via the local allowlist', () async {
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final breakfastDish = _recipe(
      id: 10,
      title: 'Chicken Keema Dosa',
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 2)],
    );
    final dinnerDish = _recipe(
      id: 11,
      title: 'Slow Cooker Chicken Curry',
      dishTypes: const ['lunch', 'main course', 'dinner'],
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 2)],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (filter.suppressTypeParam) {
        return [breakfastDish, dinnerDish];
      }
      return const [];
    });

    const filter = RecipeFilter(
      cuisines: [CuisineType.indian],
      mealType: MealType.breakfast,
    );

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(fakeRepository.calls.any((c) => c.filter.suppressTypeParam), isTrue);
    expect(
      fakeRepository.calls
          .where((c) => !c.filter.suppressTypeParam)
          .every((c) => c.filter.spoonacularTypeParam == 'breakfast'),
      isTrue,
    );

    // Only the recipe that reads as breakfast (title keyword "dosa") survives
    // — the curry tagged lunch/dinner is filtered out locally even though
    // Spoonacular's own `type` filter was dropped for this attempt.
    expect(results.map((r) => r.id), [10]);
  });

  // Regression: local validation (RecipeMainIngredientValidator,
  // RecipeIngredientPantryCounts) already excludes expired pantry items via
  // `!item.isExpired`, so an expired item never actually counts as "in
  // pantry" for matching purposes. But the includeIngredients selection used
  // to build it from the raw, unfiltered pantry list — sending Spoonacular
  // an expired "Chicken Breast" as a required ingredient even though the
  // user can no longer actually cook with it.
  test('expired pantry items are never sent as includeIngredients', () async {
    final pantryItems = [
      _pantry(
        'Chicken Breast',
        category: 'meat',
        expirationDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      _pantry('White Rice', category: 'grains'),
    ];

    fakeRepository.respond((filter, pantryIngredients) => const []);

    const filter = RecipeFilter(cuisines: [CuisineType.indian]);

    await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(fakeRepository.calls, isNotEmpty);
    final firstCall = fakeRepository.calls.first;
    expect(firstCall.pantryIngredients, contains('White Rice'));
    expect(firstCall.pantryIngredients, isNot(contains('Chicken Breast')));
  });

  // Regression: "shop for the rest" last-resort tier. When every strict tier
  // fails, generation should show real recipes to shop against — ranking by
  // pantry match — rather than an empty state, but must never bypass the
  // allergy/health gates while doing it, and the <= 8 missing-ingredients
  // cap stays a hard limit even here — past that it's not "a bit of
  // shopping" anymore.
  test(
      'shopping-list fallback surfaces a recipe missing its main '
      'ingredient, but still enforces the 8-missing cap and blocks '
      'allergens', () async {
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    // Main ingredient (chicken) is in pantry, but recipe needs 10 more
    // things — exceeds the hard _hasEnoughIngredients cap (<= 8), even in
    // shopping-list mode.
    final tooMuchShoppingRecipe = _recipe(
      id: 20,
      title: 'Elaborate Chicken Biryani',
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 2)],
      missedIngredients:
          List.generate(10, (i) => _ingredient(name: 'spice $i')),
    );
    // Main ingredient (salmon) isn't in pantry at all — would fail the
    // strict RecipeMainIngredientValidator gate, but is within the 8-missing
    // cap, so the shopping-list tier should still surface it.
    final salmonShoppingRecipe = _recipe(
      id: 21,
      title: 'Salmon Curry',
      extendedIngredients: [_ingredient(name: 'salmon fillet', amount: 2)],
    );
    // Contains an allergen — must be blocked in every tier, including this
    // last-resort one.
    final allergenRecipe = _recipe(
      id: 22,
      title: 'Peanut Chicken Satay',
      extendedIngredients: [
        _ingredient(name: 'chicken breast', amount: 2),
        _ingredient(name: 'peanut butter', amount: 1),
      ],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (pantryIngredients.isEmpty) {
        return [tooMuchShoppingRecipe, salmonShoppingRecipe, allergenRecipe];
      }
      return const [];
    });

    const filter = RecipeFilter(cuisines: [CuisineType.indian]);

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {
        'allergies': ['Peanut'],
      },
    );

    expect(results.map((r) => r.id), [21]);
    expect(results.map((r) => r.id), isNot(contains(20)));
    expect(results.map((r) => r.id), isNot(contains(22)));
  });

  // Regression: a "No preference" breakfast search with an irrelevant pantry
  // surfaced "Passion Fruit Martini" as a breakfast suggestion once the
  // shopping-list tier relaxed meal-type intent — an alcoholic cocktail is
  // never an acceptable suggestion in a DASH/medical-condition meal-planning
  // app, regardless of tier or relaxation.
  test('alcoholic beverages are excluded even in shopping-list mode',
      () async {
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final martini = _recipe(
      id: 40,
      title: 'Passion Fruit Martini',
      extendedIngredients: [_ingredient(name: 'vodka', amount: 2)],
    );
    final smoothie = _recipe(
      id: 41,
      title: 'Orange Cardamom Smoothie',
      extendedIngredients: [_ingredient(name: 'orange', amount: 2)],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (pantryIngredients.isEmpty) {
        return [martini, smoothie];
      }
      return const [];
    });

    const filter = RecipeFilter(cuisines: [CuisineType.indian]);

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id), isNot(contains(40)));
    expect(results.map((r) => r.id), contains(41));
  });

  // Regression: the alcohol title-keyword backstop used to substring-match
  // words like "sangria"/"spritz" with no allowance for a title explicitly
  // flagging itself alcohol-free, incorrectly excluding legitimate
  // zero-alcohol mocktails that happen to share a cocktail's name. The real
  // alcoholic version of the same drink must still be excluded.
  test(
      'non-alcoholic mocktails sharing a cocktail name are not excluded, but '
      'the real alcoholic drink still is', () async {
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final alcoholicSangria = _recipe(
      id: 42,
      title: 'Classic Red Wine Sangria',
      extendedIngredients: [_ingredient(name: 'red wine', amount: 2)],
    );
    final virginSangria = _recipe(
      id: 43,
      title: 'Virgin Sangria Mocktail',
      extendedIngredients: [_ingredient(name: 'grape juice', amount: 2)],
    );
    final alcoholicSpritz = _recipe(
      id: 44,
      title: 'Aperol Spritz',
      extendedIngredients: [_ingredient(name: 'prosecco', amount: 2)],
    );
    final nonAlcoholicSpritzer = _recipe(
      id: 45,
      title: 'Sparkling Cranberry Spritzer',
      extendedIngredients: [_ingredient(name: 'cranberry juice', amount: 2)],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (pantryIngredients.isEmpty) {
        return [
          alcoholicSangria,
          virginSangria,
          alcoholicSpritz,
          nonAlcoholicSpritzer,
        ];
      }
      return const [];
    });

    const filter = RecipeFilter(cuisines: [CuisineType.indian]);

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id), isNot(contains(42)));
    expect(results.map((r) => r.id), contains(43));
    expect(results.map((r) => r.id), isNot(contains(44)));
    expect(results.map((r) => r.id), contains(45));
  });

  // Regression: meal-type-intent is never relaxed, not even in the
  // shopping-list last-resort tier — a search for breakfast must never
  // surface a dinner/lunch dish, even when it's the only candidate
  // available and the user would otherwise see an empty state. Spoonacular
  // has zero Indian recipes tagged breakfast, so this exercises the exact
  // sparse-combo case that used to fall through to the (now removed)
  // meal-type relaxation.
  test(
      'shopping-list fallback still excludes a dinner dish for a breakfast '
      'search, even as the last resort', () async {
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final chickenCurry = _recipe(
      id: 30,
      title: 'Butter Chicken',
      dishTypes: const ['lunch', 'main course', 'dinner'],
      extendedIngredients: [_ingredient(name: 'chicken breast', amount: 2)],
    );

    // Only responds once `type=breakfast` itself has been dropped from the
    // query (suppressTypeParam) — matching the real bug, where Spoonacular
    // returns 0 for cuisine=indian&type=breakfast at every earlier tier.
    fakeRepository.respond((filter, pantryIngredients) {
      if (filter.suppressTypeParam) {
        return [chickenCurry];
      }
      return const [];
    });

    const filter = RecipeFilter(
      cuisines: [CuisineType.indian],
      mealType: MealType.breakfast,
    );

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results, isEmpty);
  });

  // Regression: smoothies are now a recognized breakfast match, not just a
  // last-resort shopping-list suggestion — a smoothie whose main ingredient
  // is in the pantry should pass the strict (non-relaxed) breakfast-type-
  // drop tier on its own, before the shopping-list tier is ever reached.
  test('smoothie is accepted as a real breakfast match, not just closest',
      () async {
    final pantryItems = [_pantry('Orange', category: 'fresh_fruits')];

    final smoothie = _recipe(
      id: 50,
      title: 'Orange Cardamom Smoothie',
      dishTypes: const ['beverage', 'drink'],
      extendedIngredients: [_ingredient(name: 'orange', amount: 2)],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (filter.suppressTypeParam) {
        return [smoothie];
      }
      return const [];
    });

    const filter = RecipeFilter(
      cuisines: [CuisineType.indian],
      mealType: MealType.breakfast,
    );

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id), [50]);
    // Passed the strict meal-type check (via the smoothie keyword), not the
    // relaxed shopping-list one.
    expect(results.single.isShoppingListSuggestion, isFalse);
  });

  // Regression: juice is deliberately NOT in the breakfast allowlist (juice
  // can accompany any meal, unlike a smoothie) — and since meal-type-intent
  // is never relaxed (not even in the shopping-list tier), juice is
  // excluded from a breakfast search entirely rather than surfacing as an
  // approximate match.
  test('juice is not a recognized breakfast match, and is excluded '
      'entirely — not even as a shopping-list suggestion', () async {
    final pantryItems = [_pantry('Orange', category: 'fresh_fruits')];

    final juice = _recipe(
      id: 51,
      title: 'Fresh Orange Juice',
      dishTypes: const ['beverage', 'drink'],
      extendedIngredients: [_ingredient(name: 'orange', amount: 2)],
    );

    fakeRepository.respond((filter, pantryIngredients) {
      if (filter.suppressTypeParam) {
        return [juice];
      }
      return const [];
    });

    const filter = RecipeFilter(
      cuisines: [CuisineType.indian],
      mealType: MealType.breakfast,
    );

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results, isEmpty);
  });
}

class _FakeRecipeRepository implements RecipeRepository {
  final List<({RecipeFilter filter, List<String> pantryIngredients})> calls =
      [];
  List<Recipe> Function(RecipeFilter filter, List<String> pantryIngredients)?
      _responder;

  void respond(
    List<Recipe> Function(RecipeFilter filter, List<String> pantryIngredients)
        responder,
  ) {
    _responder = responder;
  }

  @override
  Future<List<Recipe>> getRecipes(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) async {
    calls.add((filter: filter, pantryIngredients: pantryIngredients));
    return _responder?.call(filter, pantryIngredients) ?? const [];
  }

  @override
  Future<List<Recipe>> getSavedRecipes(String userId) async => const [];

  @override
  Future<void> saveRecipe(String userId, Recipe recipe) async {}

  @override
  Future<void> unsaveRecipe(String userId, int recipeId) async {}

  @override
  Future<void> cookRecipe(String userId, Recipe recipe) async {}

  @override
  Future<List<Map<String, dynamic>>> getPreparedRaw(String userId) async =>
      const [];

  @override
  Future<void> logPreparedCook(
    String userId,
    Recipe recipe,
    double totalServings,
    double consumedServings,
  ) async {}

  @override
  Future<void> logPreparedConsumption(
    String userId,
    int recipeId,
    double servingsConsumed,
  ) async {}
}

Recipe _recipe({
  required int id,
  String title = 'Test',
  List<RecipeIngredient>? extendedIngredients,
  List<RecipeIngredient>? missedIngredients,
  List<String>? dishTypes,
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
    dishTypes: dishTypes ?? const [],
    diets: const [],
    extendedIngredients: extendedIngredients ?? const [],
    missedIngredients: missedIngredients ?? const [],
    analyzedInstructions: [
      RecipeInstruction(
        name: '',
        steps: [
          InstructionStep(
            number: 1,
            step: 'Cook everything thoroughly for about 10 minutes.',
            ingredients: const [],
            equipment: const [],
          ),
        ],
      ),
    ],
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
  DateTime? expirationDate,
}) {
  return PantryItem(
    id: name,
    name: name,
    imageUrl: '',
    category: category,
    quantity: 5,
    unit: UnitType.piece,
    expirationDate:
        expirationDate ?? DateTime.now().add(const Duration(days: 7)),
  );
}
