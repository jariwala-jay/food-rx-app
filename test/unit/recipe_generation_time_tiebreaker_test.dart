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

/// Regression coverage for the readyInMinutes tiebreaker added to
/// `_sortRecipesByPantryEase` after a user observed a 120-min recipe
/// ranked above a 40-min one when searching under a much shorter time
/// budget (the fallback ladder drops maxReadyTime by Tier 2, and nothing
/// previously considered time once a recipe passed validation). The
/// tiebreaker only breaks ties among recipes already equal on missing
/// ingredients/coverage/score (Point 2 still wins outright) — verified
/// here by giving two recipes an identical pantry match and differing
/// only in readyInMinutes.
void main() {
  test(
      'a recipe with fewer/no missing ingredients but a much longer time '
      'no longer beats an equally-easy, faster recipe', () async {
    final fakeRepository = _SingleResponseRepository([
      _chickenRecipe(id: 1, readyInMinutes: 120),
      _chickenRecipe(id: 2, readyInMinutes: 15),
    ]);
    final conversion = UnitConversionService();
    final service = RecipeGenerationService(
      recipeRepository: fakeRepository,
      unitConversionService: conversion,
      foodCategoryService: FoodCategoryService(conversionService: conversion),
      ingredientSubstitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
      dietConstraintsService: DietConstraintsService(),
      minUsefulCandidates: 1,
    );
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final results = await service.generateRecipes(
      filter: const RecipeFilter(cuisines: [CuisineType.indian]),
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id).toList(), [2, 1]);
  });

  test('missing-ingredients count still wins outright over a faster recipe',
      () async {
    final fakeRepository = _SingleResponseRepository([
      // Slower but a perfect pantry match (0 missing).
      _chickenRecipe(id: 1, readyInMinutes: 120),
      // Faster, but missing an ingredient the pantry doesn't have —
      // Point 2 (fewer missing first) must still rank id 1 above this.
      _chickenRecipe(
        id: 2,
        readyInMinutes: 15,
        extraMissingIngredientName: 'shrimp',
      ),
    ]);
    final conversion = UnitConversionService();
    final service = RecipeGenerationService(
      recipeRepository: fakeRepository,
      unitConversionService: conversion,
      foodCategoryService: FoodCategoryService(conversionService: conversion),
      ingredientSubstitutionService: IngredientSubstitutionService(
        conversionService: conversion,
      ),
      dietConstraintsService: DietConstraintsService(),
      minUsefulCandidates: 1,
    );
    final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

    final results = await service.generateRecipes(
      filter: const RecipeFilter(cuisines: [CuisineType.indian]),
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(results.map((r) => r.id).toList(), [1, 2]);
  });
}

class _SingleResponseRepository implements RecipeRepository {
  _SingleResponseRepository(this._recipes);

  final List<Recipe> _recipes;
  var _called = false;

  @override
  Future<List<Recipe>> getRecipes(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) async {
    if (_called) return const [];
    _called = true;
    return _recipes;
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
/// ingredient ("chicken") is in the pantry, no allergens, no medical/health
/// constraints to violate (userProfile has none set). Optionally adds a
/// second, unmatched ingredient so the recipe counts as missing one.
Recipe _chickenRecipe({
  required int id,
  required int readyInMinutes,
  String? extraMissingIngredientName,
}) {
  final ingredients = [
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
    if (extraMissingIngredientName != null)
      RecipeIngredient(
        id: extraMissingIngredientName.hashCode,
        aisle: '',
        image: '',
        consistency: '',
        name: extraMissingIngredientName,
        nameClean: extraMissingIngredientName,
        original: extraMissingIngredientName,
        originalName: extraMissingIngredientName,
        amount: 1,
        unit: 'cup',
        meta: const [],
        measures: Measures(
          us: Measure(amount: 1, unitShort: 'cup', unitLong: 'cup'),
          metric: Measure(amount: 1, unitShort: 'cup', unitLong: 'cup'),
        ),
      ),
  ];

  return Recipe(
    id: id,
    title: 'Chicken Recipe $id',
    image: '',
    readyInMinutes: readyInMinutes,
    servings: 2,
    sourceUrl: '',
    summary: '',
    cuisines: const [],
    dishTypes: const [],
    diets: const [],
    extendedIngredients: ingredients,
    missedIngredients: extraMissingIngredientName == null
        ? const []
        : [ingredients.last],
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
