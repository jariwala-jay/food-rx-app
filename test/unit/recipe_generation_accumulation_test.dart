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

/// Regression coverage for the fallback ladder's accumulate-until-threshold
/// behavior in `RecipeGenerationService._generateWithFallbacks`. Before this
/// fix, the ladder stopped at the very first tier that returned any
/// non-empty result — even a single recipe — so a sparse cuisine+time combo
/// (e.g. Indian + under 45 min) could return far fewer recipes than later,
/// more-relaxed tiers actually had available. It now merges results across
/// tiers (deduped by recipe id) until `minUsefulCandidates` is reached, or
/// all tiers are exhausted, before returning.
void main() {
  late _CallCountingRepository fakeRepository;
  late RecipeGenerationService service;

  void buildService({required int minUsefulCandidates}) {
    final conversion = UnitConversionService();
    service = RecipeGenerationService(
      recipeRepository: fakeRepository,
      unitConversionService: conversion,
      foodCategoryService: FoodCategoryService(conversionService: conversion),
      ingredientSubstitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
      dietConstraintsService: DietConstraintsService(),
      minUsefulCandidates: minUsefulCandidates,
    );
  }

  setUp(() {
    fakeRepository = _CallCountingRepository();
  });

  // Filter has an explicit cuisine (routes through _generateExplicitCuisineRecipes,
  // a single _generateWithFallbacks call) and a maxReadyTime (so tier 2 exists
  // to retry against), keeping the tier-to-call-number mapping predictable.
  const filter = RecipeFilter(
    cuisines: [CuisineType.indian],
    maxReadyTime: 45,
  );
  final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

  test(
      'accumulates candidates across tiers instead of stopping at the '
      'first non-empty tier', () async {
    buildService(minUsefulCandidates: 3);
    fakeRepository.respondByCallIndex({
      1: [_chickenRecipe(id: 1)],
      2: [_chickenRecipe(id: 2), _chickenRecipe(id: 3)],
    });

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id).toSet(), {1, 2, 3});
  });

  test(
      'deduplicates a recipe id that reappears in a later, more-relaxed '
      'tier', () async {
    buildService(minUsefulCandidates: 3);
    fakeRepository.respondByCallIndex({
      1: [_chickenRecipe(id: 1), _chickenRecipe(id: 2)],
      2: [_chickenRecipe(id: 2), _chickenRecipe(id: 3)],
    });

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    final ids = results.map((r) => r.id).toList()..sort();
    expect(ids, [1, 2, 3]);
    expect(results.length, 3); // id 2 counted once, not twice
  });

  test('stops calling further tiers once the threshold is reached',
      () async {
    buildService(minUsefulCandidates: 3);
    fakeRepository.respondByCallIndex({
      1: [_chickenRecipe(id: 1)],
      2: [_chickenRecipe(id: 2), _chickenRecipe(id: 3)],
      // Must never be reached: the pool already hits the threshold of 3
      // after call 2, so a 3rd call (and this recipe) should never happen.
      3: [_chickenRecipe(id: 4)],
    });

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(fakeRepository.calls.length, 2);
    expect(results.map((r) => r.id).toSet(), {1, 2, 3});
    expect(results.map((r) => r.id), isNot(contains(4)));
  });
}

class _CallCountingRepository implements RecipeRepository {
  final List<({RecipeFilter filter, List<String> pantryIngredients})> calls =
      [];
  Map<int, List<Recipe>> _byCallIndex = const {};

  /// Keys are 1-based call numbers — the Nth time [getRecipes] is invoked
  /// returns the recipes registered for key N (or none if unregistered).
  void respondByCallIndex(Map<int, List<Recipe>> responses) {
    _byCallIndex = responses;
  }

  @override
  Future<List<Recipe>> getRecipes(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) async {
    calls.add((filter: filter, pantryIngredients: pantryIngredients));
    return _byCallIndex[calls.length] ?? const [];
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

/// A recipe that reliably passes every local validation gate: main
/// ingredient ("chicken") is in the pantry, no missing ingredients, has
/// written instructions, no allergens, no medical/health constraints to
/// violate (userProfile has none set).
Recipe _chickenRecipe({required int id}) {
  return Recipe(
    id: id,
    title: 'Chicken Recipe $id',
    image: '',
    readyInMinutes: 30,
    servings: 2,
    sourceUrl: '',
    summary: '',
    cuisines: const [],
    dishTypes: const [],
    diets: const [],
    extendedIngredients: [
      RecipeIngredient(
        id: 'chicken breast'.hashCode,
        aisle: '',
        image: '',
        consistency: '',
        name: 'chicken breast',
        nameClean: 'chicken breast',
        original: 'chicken breast',
        originalName: 'chicken breast',
        amount: 2,
        unit: 'cup',
        meta: const [],
        measures: Measures(
          us: Measure(amount: 2, unitShort: 'cup', unitLong: 'cup'),
          metric: Measure(amount: 2, unitShort: 'cup', unitLong: 'cup'),
        ),
      ),
    ],
    missedIngredients: const [],
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
