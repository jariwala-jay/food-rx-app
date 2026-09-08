import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository_impl.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';

/// Regression coverage for Spoonacular pagination in the fallback ladder.
/// Every tier request previously used a single page (offset=0, number=100)
/// and moved on to a more-relaxed tier as soon as that page didn't clear
/// the useful-candidates threshold — even when Spoonacular's own
/// `totalResults` said more candidates existed one page over. The ladder
/// now fetches page 2 of the *same* tier's filter first when a tier's page
/// came back full and `totalResults` confirms there's more, before falling
/// through to a more-relaxed tier.
void main() {
  late _CallCountingDetailedRepository fakeRepository;
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

  setUpAll(() {
    // SpoonacularRecipeRepository reads dotenv.env at construction time —
    // _CallCountingDetailedRepository only needs an instance to satisfy
    // RecipeRepositoryImpl's constructor (getRecipesDetailed is overridden
    // and never delegates to it), but dotenv must still be initialized.
    dotenv.testLoad(fileInput: 'RAPID_API_KEY=test-key');
  });

  setUp(() {
    fakeRepository = _CallCountingDetailedRepository();
  });

  // Explicit cuisine (routes through _generateExplicitCuisineRecipes, a
  // single _generateWithFallbacks call) with no maxReadyTime, so Tier 1 is
  // the only tier attempted before either the threshold is hit or the
  // ladder falls through to Tier 3.
  const filter = RecipeFilter(cuisines: [CuisineType.indian]);
  final pantryItems = [_pantry('Chicken Breast', category: 'meat')];

  test(
      'fetches page 2 of the same tier when page 1 is capped and '
      'totalResults reports more candidates', () async {
    buildService(minUsefulCandidates: 8);

    // Page 1: a full page (100) where only 5 pass validation (the other 95
    // are a protein the pantry doesn't have) — not enough to hit the
    // threshold on its own, but totalResults says 150 exist.
    final page1 = [
      ..._chickenRecipes(ids: [1, 2, 3, 4, 5]),
      ..._beefRecipes(ids: List.generate(95, (i) => 100 + i)),
    ];
    // Page 2: 5 more valid recipes — enough to cross the threshold of 8
    // once merged with page 1's 5.
    final page2 = _chickenRecipes(ids: [201, 202, 203, 204, 205]);

    fakeRepository.respondByCallIndex({
      1: (recipes: page1, totalResults: 150),
      2: (recipes: page2, totalResults: 150),
    });

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(fakeRepository.calls.length, 2);
    expect(fakeRepository.calls[0].offset, 0);
    expect(fakeRepository.calls[1].offset, 100);
    expect(
      results.map((r) => r.id).toSet(),
      {1, 2, 3, 4, 5, 201, 202, 203, 204, 205},
    );
  });

  test('does not fetch page 2 when totalResults reports no more candidates',
      () async {
    buildService(minUsefulCandidates: 8);

    // Page 1: a full page, still short of the threshold, but totalResults
    // says this cuisine has exactly 100 candidates total — nothing to gain
    // from a page 2.
    final page1 = [
      ..._chickenRecipes(ids: [1, 2, 3]),
      ..._beefRecipes(ids: List.generate(97, (i) => 100 + i)),
    ];

    fakeRepository.respondByCallIndex({
      1: (recipes: page1, totalResults: 100),
      // Tier 3 (relaxed health constraints) — reached only because Tier 1
      // never hit the threshold and page 2 was correctly skipped.
      2: (recipes: _chickenRecipes(ids: [301, 302, 303, 304, 305]), totalResults: null),
    });

    final results = await service.generateRecipes(
      filter: filter,
      pantryItems: pantryItems,
      userProfile: const {},
    );

    expect(fakeRepository.calls.map((c) => c.offset), everyElement(0));
    expect(
      results.map((r) => r.id).toSet(),
      {1, 2, 3, 301, 302, 303, 304, 305},
    );
  });
}

class _CallCountingDetailedRepository extends RecipeRepositoryImpl {
  _CallCountingDetailedRepository() : super(SpoonacularRecipeRepository());

  final List<({RecipeFilter filter, List<String> pantryIngredients, int offset})>
      calls = [];
  Map<int, ({List<Recipe> recipes, int? totalResults})> _byCallIndex = const {};

  /// Keys are 1-based call numbers across the whole generation call (every
  /// tier/page, in order) — the Nth call to [getRecipesDetailed] returns the
  /// response registered for key N (or an empty page if unregistered).
  void respondByCallIndex(
    Map<int, ({List<Recipe> recipes, int? totalResults})> responses,
  ) {
    _byCallIndex = responses;
  }

  @override
  Future<({List<Recipe> recipes, bool fromCache, int? totalResults})>
      getRecipesDetailed(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) async {
    calls.add((filter: filter, pantryIngredients: pantryIngredients, offset: offset));
    final response = _byCallIndex[calls.length];
    if (response == null) {
      return (recipes: const <Recipe>[], fromCache: false, totalResults: null);
    }
    return (
      recipes: response.recipes,
      fromCache: false,
      totalResults: response.totalResults,
    );
  }
}

/// Recipes that reliably pass every local validation gate: main ingredient
/// ("chicken") is in the pantry, no missing ingredients, written
/// instructions, no allergens/medical constraints (userProfile has none).
List<Recipe> _chickenRecipes({required List<int> ids}) =>
    ids.map((id) => _proteinRecipe(id: id, protein: 'Chicken')).toList();

/// Recipes whose main ingredient ("beef") the test pantry never stocks —
/// fails the main-ingredient gate, standing in for "the other 95 candidates
/// Spoonacular returned that don't match this pantry."
List<Recipe> _beefRecipes({required List<int> ids}) =>
    ids.map((id) => _proteinRecipe(id: id, protein: 'Beef')).toList();

Recipe _proteinRecipe({required int id, required String protein}) {
  final ingredientName = protein.toLowerCase();
  return Recipe(
    id: id,
    title: '$protein Recipe $id',
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
        id: ingredientName.hashCode,
        aisle: '',
        image: '',
        consistency: '',
        name: ingredientName,
        nameClean: ingredientName,
        original: ingredientName,
        originalName: ingredientName,
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
