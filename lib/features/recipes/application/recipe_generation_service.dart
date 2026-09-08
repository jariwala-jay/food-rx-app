import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository_impl.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/core/services/food_category_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';
import 'package:flutter_app/features/recipes/utils/recipe_ingredient_pantry_counts.dart';
import 'package:flutter_app/features/recipes/utils/recipe_main_ingredient_validation.dart';
import 'package:flutter_app/features/recipes/utils/recipe_pantry_sort.dart';
import 'package:flutter/foundation.dart';

/// Result of one Spoonacular fetch-and-validate call — see
/// [RecipeGenerationService._tryFetchAndValidateRecipes].
typedef _TierFetchResult = ({
  List<Recipe> results,
  int candidatesReturned,
  bool fromCache,
  int? totalResults,
});

class RecipeGenerationService {
  /// Default target for validated, deduped candidates the fallback ladder
  /// accumulates toward before ranking — not a "recipes shown" count. See
  /// [_generateWithFallbacks].
  static const int kDefaultMinUsefulCandidates = 12;

  /// Spoonacular's complexSearch `number` param used for every tier request
  /// (see [_tryFetchAndValidateRecipes]) — also the page size [_generateWithFallbacks]
  /// checks against to decide whether a tier's full page means more results
  /// exist beyond it.
  static const int _spoonacularPageSize = 100;

  final RecipeRepository _recipeRepository;
  final UnitConversionService _unitConversionService;
  final FoodCategoryService _foodCategoryService;
  final IngredientSubstitutionService _ingredientSubstitutionService;
  final DietConstraintsService _dietConstraintsService;
  final int _minUsefulCandidates;

  RecipeGenerationService({
    required RecipeRepository recipeRepository,
    required UnitConversionService unitConversionService,
    required FoodCategoryService foodCategoryService,
    required IngredientSubstitutionService ingredientSubstitutionService,
    required DietConstraintsService dietConstraintsService,
    int minUsefulCandidates = kDefaultMinUsefulCandidates,
  })  : assert(minUsefulCandidates >= 1),
        _recipeRepository = recipeRepository,
        _unitConversionService = unitConversionService,
        _foodCategoryService = foodCategoryService,
        _ingredientSubstitutionService = ingredientSubstitutionService,
        _dietConstraintsService = dietConstraintsService,
        _minUsefulCandidates = minUsefulCandidates;

  final RecipeMainIngredientValidator _mainIngredientValidator =
      RecipeMainIngredientValidator();

  Future<List<Recipe>> generateRecipes({
    required RecipeFilter filter,
    required List<PantryItem> pantryItems,
    required Map<String, dynamic> userProfile,
  }) async {
    // Phase 1.5: only meaningful, non-expired pantry items bias Spoonacular
    // discovery. Local validation (_hasEnoughIngredients, main ingredient
    // check) already excludes expired items, so an expired item never
    // actually counts as "in pantry" there — sending it to Spoonacular would
    // only bias search results toward something the user can't really cook.
    // Seasonings/condiments remain in [pantryItems] for ranking, badges, cook.
    final includeSelection =
        IngredientNutritionalCategoryResolver.selectForSpoonacularInclude(
      pantryItems.where((e) => !e.isExpired).map(
            (e) => (name: e.name, category: e.category),
          ),
    );
    final pantryIngredientNames = includeSelection.includedNames;
    _logSpoonacularIncludeSelection(includeSelection);

    // 1. Enhance filter with user-specific dietary constraints
    final enhancedFilter = _enhanceFilterWithUserProfile(filter, userProfile);
    final allergies = List<String>.from(userProfile['allergies'] ?? const []);
    final excludedIngredients =
        AllergyFilteringService.parseExcludedIngredients(
      userProfile['excludedIngredients'],
    );
    final requestPantryIngredientNames = pantryIngredientNames
        .where(
          (name) => !AllergyFilteringService.conflictsWithRestrictions(
            name,
            allergies: allergies,
            excludedIngredients: excludedIngredients,
          ),
        )
        .toList();
    final diagnostics = _GenerationDiagnostics(
      filter: enhancedFilter,
      userProfile: userProfile,
    );

    // 2. Generate with cuisine strategy
    final List<Recipe> validatedRecipes;
    if (enhancedFilter.isNoPreferenceOnly) {
      validatedRecipes = await _generateNoPreferenceRecipes(
        enhancedFilter,
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        diagnostics,
      );
    } else if (enhancedFilter.hasExplicitCuisinePreference) {
      validatedRecipes = await _generateExplicitCuisineRecipes(
        enhancedFilter,
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        diagnostics,
      );
    } else {
      validatedRecipes = await _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        requestPantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
        diagnostics: diagnostics,
      );
    }

    _sortRecipesByPantryEase(
      validatedRecipes,
      pantryItems,
      enhancedFilter,
      userProfile,
    );

    if (kDebugMode) {
      diagnostics.logSummary(finalReturned: validatedRecipes.length);
      if (validatedRecipes.isEmpty) {
        print('⚠️  No recipes found after all fallback attempts');
      }
    }

    return validatedRecipes;
  }

  List<CuisineType> _favoriteCuisinesFromProfile(
      Map<String, dynamic> userProfile) {
    final raw = userProfile['favoriteCuisines'];
    if (raw is! List) return [];
    return CuisineTypeExtension.fromUserFavoriteNames(
      raw.map((e) => e.toString()).toList(),
    );
  }

  void _logSpoonacularIncludeSelection(SpoonacularIncludeSelection selection) {
    if (!kDebugMode) return;
    print('\n📦 Spoonacular includeIngredients');
    print('');
    if (selection.includedNames.isEmpty) {
      print('Included: (none — searching without includeIngredients)');
    } else {
      print('Included:');
      for (final name in selection.includedNames) {
        print('  $name');
      }
    }
    if (selection.exclusions.isNotEmpty) {
      print('');
      print('Excluded:');
      for (final item in selection.exclusions) {
        print('  ${item.name} (${item.category.name.toUpperCase()})');
      }
    }
  }

  /// No preference: favorites from account first, then all other cuisines.
  Future<List<Recipe>> _generateNoPreferenceRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
    _GenerationDiagnostics diagnostics,
  ) async {
    final favoriteCuisines = _favoriteCuisinesFromProfile(userProfile);

    if (favoriteCuisines.isEmpty) {
      if (kDebugMode) {
        print(
            '🍽️ No preference: no account favorites — searching all cuisines');
      }
      return _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
        diagnostics: diagnostics,
      );
    }

    final favoriteNames = favoriteCuisines.map((c) => c.displayName).join(', ');
    if (kDebugMode) {
      print(
          '🍽️ No preference: favorites first ($favoriteNames), then other cuisines');
    }

    // Favorites and all-cuisines are independent Spoonacular searches — run
    // them concurrently instead of sequentially so the no-preference path
    // doesn't pay for two full fallback ladders back-to-back (each can take
    // several sequential requests on its own; see [_generateWithFallbacks]).
    final results = await Future.wait([
      _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: favoriteCuisines),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: true,
        batchLabel: 'No-preference batch 1/2: FAVORITES ($favoriteNames)',
        diagnostics: diagnostics,
      ),
      _generateWithFallbacks(
        enhancedFilter.copyWith(cuisines: const []),
        pantryIngredientNames,
        pantryItems,
        userProfile,
        keepCuisine: false,
        batchLabel: 'No-preference batch 2/2: ALL CUISINES',
        diagnostics: diagnostics,
      ),
    ]);
    final favoriteBatch = results[0];
    final allCuisinesBatch = results[1];

    return _mergePrimaryFirst(favoriteBatch, allCuisinesBatch);
  }

  /// User picked specific cuisine(s) — search only those (e.g. Korean → Korean only).
  Future<List<Recipe>> _generateExplicitCuisineRecipes(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile,
    _GenerationDiagnostics diagnostics,
  ) async {
    if (kDebugMode) {
      final selected = enhancedFilter.explicitCuisines;
      print(
          '🍽️ Selected cuisines only (${selected.map((c) => c.displayName).join(', ')})');
    }

    return _generateWithFallbacks(
      enhancedFilter,
      pantryIngredientNames,
      pantryItems,
      userProfile,
      keepCuisine: true,
      diagnostics: diagnostics,
    );
  }

  List<Recipe> _mergePrimaryFirst(
    List<Recipe> primaryBatch,
    List<Recipe> secondaryBatch,
  ) {
    final seen = primaryBatch.map((r) => r.id).toSet();
    final remainder =
        secondaryBatch.where((r) => !seen.contains(r.id)).toList();
    return [...primaryBatch, ...remainder];
  }

  Future<List<Recipe>> _generateWithFallbacks(
    RecipeFilter enhancedFilter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile, {
    required bool keepCuisine,
    required _GenerationDiagnostics diagnostics,
    String? batchLabel,
  }) async {
    // Accumulates validated candidates across tiers (deduped by recipe id,
    // first-seen-wins via _mergePrimaryFirst) until there are enough for the
    // ranking stage to work with, instead of stopping at the first tier that
    // returns anything at all. A stricter tier's version of a recipe (e.g.
    // isShoppingListSuggestion == false) always wins over a later, more
    // relaxed tier re-surfacing the same id.
    List<Recipe> accumulated = [];

    bool absorb(String label, _TierFetchResult tier) {
      final before = accumulated.length;
      accumulated = _mergePrimaryFirst(accumulated, tier.results);
      diagnostics.recordTier(
        label: label,
        batchLabel: batchLabel,
        candidatesReturned: tier.candidatesReturned,
        validatedPassed: tier.results.length,
        fromCache: tier.fromCache,
        newlyAddedToPool: accumulated.length - before,
        poolSizeAfter: accumulated.length,
      );
      if (accumulated.length >= _minUsefulCandidates) {
        diagnostics.noteFallback(
          '$label reached target (${accumulated.length}/$_minUsefulCandidates)',
        );
        return true;
      }
      return false;
    }

    // A tier's own filter is the most precise match for what the user
    // asked for — before falling through to a more-relaxed tier, check
    // whether this tier's first page came back full (== _spoonacularPageSize)
    // with more candidates reported beyond it (totalResults). If so, that's
    // Spoonacular's per-request cap, not the tier being out of matches:
    // fetch page 2 of the *same* filter first. Returns true once the
    // threshold is reached (by either page).
    Future<bool> runTier(
      String label,
      Future<_TierFetchResult> Function({required int offset}) fetchPage,
    ) async {
      final page1 = await fetchPage(offset: 0);
      if (absorb(label, page1)) return true;
      if (page1.candidatesReturned >= _spoonacularPageSize &&
          (page1.totalResults ?? 0) > _spoonacularPageSize) {
        if (kDebugMode) {
          print('🔁 $label hit the $_spoonacularPageSize-result page cap '
              '(${page1.totalResults} total available) — fetching page 2...');
        }
        final page2 = await fetchPage(offset: _spoonacularPageSize);
        if (absorb('$label (page 2)', page2)) return true;
      }
      return false;
    }

    // Tier 1: as requested.
    if (await runTier(
      'Tier 1 (as requested)',
      ({required offset}) => _tryFetchAndValidateRecipes(
        enhancedFilter,
        pantryIngredientNames,
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
        batchLabel: batchLabel,
        offset: offset,
        diagnostics: diagnostics,
      ),
    )) {
      return accumulated;
    }

    // Tier 2: drop maxReadyTime.
    if (enhancedFilter.maxReadyTime != null) {
      final droppedReadyTime = enhancedFilter.maxReadyTime;
      if (kDebugMode) {
        print('🔁 Only ${accumulated.length} so far. Retrying without '
            'maxReadyTime (was $droppedReadyTime min)...');
      }
      if (await runTier(
        'Tier 2 (dropped maxReadyTime, was $droppedReadyTime min)',
        ({required offset}) => _tryFetchAndValidateRecipes(
          enhancedFilter.copyWith(maxReadyTime: null),
          pantryIngredientNames,
          pantryItems,
          userProfile,
          enforceCuisine: keepCuisine,
          batchLabel: batchLabel,
          offset: offset,
          diagnostics: diagnostics,
        ),
      )) {
        return accumulated;
      }
    }

    // Tier 3: relax health constraints.
    if (kDebugMode) {
      print('🔁 Only ${accumulated.length} so far. Retrying with relaxed '
          'health constraints...');
    }
    final relaxedHealthFilter = enhancedFilter.copyWith(
      maxReadyTime: null,
      veryHealthy: false,
      dashCompliant: false,
      myPlateCompliant: false,
      maxSodium: null,
    );
    if (await runTier(
      'Tier 3 (relaxed health constraints)',
      ({required offset}) => _tryFetchAndValidateRecipes(
        relaxedHealthFilter,
        pantryIngredientNames,
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
        batchLabel: batchLabel,
        offset: offset,
        diagnostics: diagnostics,
      ),
    )) {
      return accumulated;
    }

    // Tier 4: drop includeIngredients. Spoonacular's includeIngredients is
    // an AND filter — even a capped pantry list can still fail to match.
    // Lean on local pantry validation (_hasEnoughIngredients, main
    // ingredient check) instead.
    if (pantryIngredientNames.isNotEmpty) {
      final droppedIngredients = pantryIngredientNames.join(', ');
      if (kDebugMode) {
        print('🔁 Only ${accumulated.length} so far. Retrying without '
            'includeIngredients (was: $droppedIngredients)...');
      }
      if (await runTier(
        'Tier 4 (dropped includeIngredients, was: $droppedIngredients)',
        ({required offset}) => _tryFetchAndValidateRecipes(
          relaxedHealthFilter,
          const [],
          pantryItems,
          userProfile,
          enforceCuisine: keepCuisine,
          batchLabel: batchLabel,
          offset: offset,
          diagnostics: diagnostics,
        ),
      )) {
        return accumulated;
      }
    }

    // Tier 5: some cuisine+mealType combos have zero matches in
    // Spoonacular's own dataset (e.g. cuisine=indian&type=breakfast returns
    // 0 candidates even though cuisine=indian alone returns plenty). For
    // breakfast: drop the `type` param and rely on _matchesBreakfastIntent
    // locally so the result isn't an obvious lunch/dinner dish.
    if (enhancedFilter.mealType == MealType.breakfast &&
        !enhancedFilter.suppressTypeParam) {
      if (kDebugMode) {
        print('🔁 Only ${accumulated.length} so far. Retrying without the '
            'breakfast type filter (local heuristic will still enforce it)...');
      }
      if (await runTier(
        'Tier 5 (dropped breakfast type filter)',
        ({required offset}) => _tryFetchAndValidateRecipes(
          relaxedHealthFilter.copyWith(suppressTypeParam: true),
          const [],
          pantryItems,
          userProfile,
          enforceCuisine: keepCuisine,
          batchLabel: batchLabel,
          offset: offset,
          diagnostics: diagnostics,
        ),
      )) {
        return accumulated;
      }
    }

    // Tier 6, absolute last resort: show real recipes to shop against
    // instead of an empty state. Drops only the main-ingredient gate (never
    // meal-type-intent, allergy/health/medical/instructions, and never the
    // <= 8 missing-ingredients cap — past that it's not "a bit of
    // shopping") and lets _sortRecipesByPantryEase rank the closest
    // matches — e.g. a pantry with just chicken in it surfaces chicken
    // recipes first, missing ingredients and all, so the user can see what
    // to buy. A breakfast search still only shows breakfast dishes here,
    // just possibly ones missing their main ingredient. Always runs
    // unconditionally at this point — there's no tier after it, so its
    // result is absorbed but never gated on the threshold.
    final shoppingListFilter = enhancedFilter.mealType == MealType.breakfast
        ? relaxedHealthFilter.copyWith(suppressTypeParam: true)
        : relaxedHealthFilter;
    if (kDebugMode) {
      print('🔁 Only ${accumulated.length} so far. Last resort: showing '
          'recipes to shop for (main-ingredient gate relaxed, meal type '
          'still enforced, still <= 8 missing ingredients)...');
    }
    await runTier(
      'Tier 6 (shopping-list, main-ingredient gate relaxed)',
      ({required offset}) => _tryFetchAndValidateRecipes(
        shoppingListFilter,
        const [],
        pantryItems,
        userProfile,
        enforceCuisine: keepCuisine,
        relaxPantryGates: true,
        batchLabel: batchLabel,
        offset: offset,
        diagnostics: diagnostics,
      ),
    );

    if (accumulated.isEmpty) {
      diagnostics.noteFallback('All fallback attempts returned 0 recipes');
      // Only drop cuisine when the user picked specific cuisines and still
      // got nothing — never actually broadened, just logged.
      if (keepCuisine && enhancedFilter.hasExplicitCuisinePreference) {
        if (kDebugMode) {
          print('⚠️ No recipes matched selected cuisine(s); not broadening '
              'to other cuisines.');
        }
      }
    } else if (accumulated.length < _minUsefulCandidates) {
      diagnostics.noteFallback(
        'Exhausted all tiers with partial results: ${accumulated.length}/'
        '$_minUsefulCandidates',
      );
    }

    return accumulated;
  }

  void _sortRecipesByPantryEase(
    List<Recipe> recipes,
    List<PantryItem> pantryItems,
    RecipeFilter filter,
    Map<String, dynamic> userProfile,
  ) {
    final counts = RecipeIngredientPantryCounts(
      PantryDeductionService(
        conversionService: _unitConversionService,
        substitutionService: _ingredientSubstitutionService,
      ),
    );

    // No preference → no cuisine bias at all; ties get shuffled instead
    // (sortByEasiestToMake randomizes same-missing-count groups when
    // preferredCuisines is empty). Multi-select → selection order, others
    // last within each tier.
    final preferredCuisines = filter.isNoPreferenceOnly
        ? const <CuisineType>[]
        : filter.explicitCuisines;

    RecipePantrySort.sortByEasiestToMake(
      recipes,
      pantry: pantryItems,
      counts: counts,
      targetServings: filter.servings,
      preferredCuisines: preferredCuisines,
      tiebreaker: (a, b) {
        // Only breaks ties among recipes already equal on missing
        // ingredients/coverage/score (Point 2) — a recipe with fewer
        // missing ingredients still wins outright even against a much
        // faster one; this just stops e.g. a 120-min recipe beating a
        // 15-min recipe when they're otherwise equally easy to shop for.
        final timeCmp = _compareReadyTime(a.readyInMinutes, b.readyInMinutes);
        if (timeCmp != 0) return timeCmp;
        final usedCmp =
            (b.usedIngredientCount ?? 0).compareTo(a.usedIngredientCount ?? 0);
        if (usedCmp != 0) return usedCmp;
        return b.healthScore.compareTo(a.healthScore);
      },
    );
  }

  /// Shorter total time wins. A recipe with unknown time (readyInMinutes
  /// <= 0 — Spoonacular didn't report it) is treated as worse than any
  /// known time rather than winning by default as "0 minutes."
  static int _compareReadyTime(int a, int b) {
    final aKnown = a > 0;
    final bKnown = b > 0;
    if (aKnown && bKnown) return a.compareTo(b);
    if (aKnown) return -1;
    if (bKnown) return 1;
    return 0;
  }

  /// Fetch recipes from repository and validate them.
  ///
  /// [relaxPantryGates]: last-resort "shop for the rest" mode — skips only
  /// the main-ingredient-in-pantry gate, so the user gets real recipe
  /// suggestions instead of an empty state when the star ingredient isn't
  /// in their pantry. Matching recipes get flagged via
  /// [Recipe.isShoppingListSuggestion] so the UI can label them as closest
  /// matches rather than strict results. Meal-type-intent is never relaxed
  /// (a breakfast search must never surface a dinner/lunch/snack dish, even
  /// as a last resort — Tier 5 already handles the "no recipe in this
  /// cuisine is ever tagged breakfast" case via [RecipeFilter.suppressTypeParam]
  /// + local intent matching instead). The <= 8 missing-ingredients cap
  /// (_hasEnoughIngredients) is NOT relaxed here either — past that point
  /// it's not "a bit of shopping", and showing it anyway stopped being a
  /// helpful suggestion. Allergy and health/medical gates are never relaxed
  /// either — those protect against something actually unsafe, not just
  /// "not quite what you asked for".
  Future<_TierFetchResult> _tryFetchAndValidateRecipes(
    RecipeFilter filter,
    List<String> pantryIngredientNames,
    List<PantryItem> pantryItems,
    Map<String, dynamic> userProfile, {
    bool enforceCuisine = false,
    bool relaxPantryGates = false,
    String? batchLabel,
    int offset = 0,
    required _GenerationDiagnostics diagnostics,
  }) async {
    final requestUri = SpoonacularRecipeRepository.buildComplexSearchUri(
      filter,
      pantryIngredientNames,
      offset: offset,
    );
    diagnostics.recordSpoonacularRequest(requestUri.toString(),
        label: batchLabel);

    // Fetch recipes from the repository. Use the cache-aware fetch when the
    // concrete repository supports it (instrumentation only — falls back to
    // the plain interface method, with cache status unknown/assumed false,
    // for any other RecipeRepository implementation e.g. test fakes). Only
    // the detailed path reports totalResults, so pagination (see
    // [_generateWithFallbacks]) is a no-op against a plain RecipeRepository.
    final List<Recipe> recipes;
    bool fromCache = false;
    int? totalResults;
    final repo = _recipeRepository;
    if (repo is RecipeRepositoryImpl) {
      final detailed = await repo.getRecipesDetailed(
        filter,
        pantryIngredientNames,
        offset: offset,
      );
      recipes = detailed.recipes;
      fromCache = detailed.fromCache;
      totalResults = detailed.totalResults;
    } else {
      recipes = await repo.getRecipes(
        filter,
        pantryIngredientNames,
        offset: offset,
      );
    }

    diagnostics.spoonacularCandidates += recipes.length;

    if (kDebugMode) {
      print('\n🔍 RECIPE GENERATION DEBUG:');
      print('Recipes from API: ${recipes.length}');
      print('Filter meal types: ${filter.spoonacularMealTypes}');
      final params = filter.toSpoonacularParams();
      print('Spoonacular search params:');
      for (final entry in params.entries) {
        print('  ${entry.key}=${entry.value}');
      }
      if (pantryIngredientNames.isNotEmpty) {
        print('Pantry includeIngredients: ${pantryIngredientNames.join(', ')}');
      }
      print('User medical conditions: ${userProfile['medicalConditions']}');
      print('User diet type: ${userProfile['dietType']}');
      print('\nAPI recipe list:');
      for (final recipe in recipes) {
        print('  [${recipe.id}] ${recipe.title}');
      }
    }

    // Perform local validation and enhancement
    final validatedRecipes = <Recipe>[];

    for (var recipe in recipes) {
      if (kDebugMode) {
        print('\n📋 Validating recipe: ${recipe.title}');
      }
      var isShoppingListSuggestion = false;

      // a. Check if pantry has enough ingredients
      final allergies = List<String>.from(userProfile['allergies'] ?? const []);
      final excludedIngredients =
          AllergyFilteringService.parseExcludedIngredients(
        userProfile['excludedIngredients'],
      );
      if (AllergyFilteringService.recipeContainsRestrictions(
        recipe,
        allergies: allergies,
        excludedIngredients: excludedIngredients,
      )) {
        diagnostics.failedHealth++;
        if (kDebugMode) {
          print('  ❌ Contains an allergy or excluded ingredient');
        }
        continue;
      }

      // Alcoholic drinks are never an appropriate suggestion in a DASH/
      // medical-condition meal-planning app — never relaxed, at any tier.
      if (_isAlcoholicBeverage(recipe)) {
        diagnostics.failedHealth++;
        if (kDebugMode) {
          print('  ❌ Alcoholic beverage — not a valid recipe suggestion');
        }
        continue;
      }

      // b. Check if pantry has enough ingredients — hard cap (<= 8 missing),
      // never relaxed even in shopping-list mode: past that point it's not
      // "a bit of shopping", it's a different meal plan entirely.
      if (!_hasEnoughIngredients(recipe, pantryItems)) {
        diagnostics.failedPantry++;
        if (kDebugMode) {
          print(
              '  ❌ Not enough ingredients (missed: ${recipe.requiredMissedIngredientCount})');
        }
        continue;
      }

      // c. Main ingredient must be in pantry (Point 1 validation gate).
      final mainIngredientResult =
          _mainIngredientValidator.validate(recipe, pantryItems);
      if (!mainIngredientResult.passes) {
        if (!relaxPantryGates) {
          diagnostics.failedMainIngredient++;
          if (kDebugMode) {
            print(
              '  ❌ Main ingredient missing: ${mainIngredientResult.mainIngredientName}'
              ' (${mainIngredientResult.mainCategory?.name ?? 'unknown'})',
            );
          }
          continue;
        }
        isShoppingListSuggestion = true;
        if (kDebugMode) {
          print(
            '  🛒 Shopping needed for main ingredient: ${mainIngredientResult.mainIngredientName}'
            ' (${mainIngredientResult.mainCategory?.name ?? 'unknown'}) — showing anyway',
          );
        }
      }
      if (kDebugMode && mainIngredientResult.passes && !mainIngredientResult.gateSkipped) {
        print(
          '  ✓ Main ingredient in pantry: ${mainIngredientResult.mainIngredientName}'
          ' (${mainIngredientResult.mainCategory?.name ?? 'unknown'})',
        );
      }

      // d. Validate against health constraints (DASH, MyPlate, etc.)
      if (!(await _isHealthCompliant(recipe, userProfile))) {
        diagnostics.failedHealth++;
        if (kDebugMode) {
          print('  ❌ Not health compliant');
        }
        continue;
      }

      // e. Validate against medical condition constraints
      if (!_isMedicalConditionCompliant(recipe, userProfile)) {
        diagnostics.failedMedical++;
        if (kDebugMode) {
          print('  ❌ Not medical condition compliant');
        }
        continue;
      }

      // f. Snacks/breakfast: drop full meals Spoonacular mis-tags as the
      // wrong meal (e.g. fried rice tagged snack, a dinner dish surfacing
      // for a breakfast search). Never relaxed, even in shopping-list mode
      // — a search for breakfast should never show a dinner/lunch/snack
      // item, even as a last resort; better to return fewer results than
      // the wrong meal type.
      if (!_matchesMealTypeIntent(recipe, filter)) {
        diagnostics.failedMealType++;
        if (kDebugMode) {
          print(
              '  ❌ Does not match meal type intent (${filter.mealType?.displayName})');
        }
        continue;
      }

      // g. Require written cooking steps (exclude video-only Spoonacular entries).
      if (!recipe.hasCookingInstructions) {
        diagnostics.failedInstructions++;
        if (kDebugMode) {
          print('  ❌ No written cooking instructions (video-only or empty)');
        }
        continue;
      }

      if (kDebugMode) {
        print('  ✅ Recipe passed all validations');
      }

      // h. Enhance recipe with pantry data
      var enhancedRecipe = _enhanceRecipeWithPantryData(recipe, pantryItems);
      if (isShoppingListSuggestion) {
        enhancedRecipe =
            enhancedRecipe.copyWith(isShoppingListSuggestion: true);
      }

      validatedRecipes.add(enhancedRecipe);
    }

    var results = validatedRecipes;
    if (enforceCuisine && filter.hasExplicitCuisinePreference) {
      final before = results.length;
      results = results
          .where((r) => _matchesSelectedCuisines(r, filter.cuisines))
          .toList();
      final cuisineDropped = before - results.length;
      if (cuisineDropped > 0) {
        diagnostics.failedCuisine += cuisineDropped;
      }
      if (kDebugMode && cuisineDropped > 0) {
        print('  🍛 Cuisine post-filter: $before → ${results.length} recipes');
      }
    }

    diagnostics.validatedPassed += results.length;

    if (kDebugMode) {
      print('Validated recipes: ${results.length}');
      print('Filtered out: ${recipes.length - results.length}');
      if (results.isNotEmpty) {
        print('\n✅ Recipes passing validation:');
        for (final recipe in results) {
          print('  [${recipe.id}] ${recipe.title}');
        }
      }
    }

    return (
      results: results,
      candidatesReturned: recipes.length,
      fromCache: fromCache,
      totalResults: totalResults,
    );
  }

  bool _matchesSelectedCuisines(Recipe recipe, List<CuisineType> selected) {
    // apiName, not name — Spoonacular tags recipes with the space-separated
    // display form (e.g. "Middle Eastern"), not the enum's camelCase.
    final wanted = selected
        .where((c) => c != CuisineType.noPreference)
        .map((c) => c.apiName.toLowerCase())
        .toSet();
    if (wanted.isEmpty) return true;

    final recipeCuisines = recipe.cuisines.map((c) => c.toLowerCase()).toSet();
    if (recipeCuisines.isEmpty) {
      // Spoonacular sometimes omits cuisine tags; trust the API cuisine param.
      return true;
    }
    return recipeCuisines.any(wanted.contains);
  }

  /// Enhance filter with user-specific dietary constraints based on diet assignment matrix
  RecipeFilter _enhanceFilterWithUserProfile(
      RecipeFilter filter, Map<String, dynamic> userProfile) {
    final medicalConditions =
        List<String>.from(userProfile['medicalConditions'] ?? []);
    final healthGoals = List<String>.from(userProfile['healthGoals'] ?? []);
    final dietType = userProfile['dietType'] as String?;
    final allergies = List<String>.from(userProfile['allergies'] ?? []);
    final dietRule = userProfile['diet_rule'] as Map<String, dynamic>?;

    // Convert medical conditions to filter enum
    final medicalConditionEnums = medicalConditions
        .map((condition) {
          switch (condition.toLowerCase()) {
            case 'hypertension':
              return MedicalCondition.hypertension;
            case 'diabetes':
              return MedicalCondition.diabetes;
            case 'pre-diabetes':
            case 'prediabetes':
              return MedicalCondition.prediabetes;
            case 'overweight/obesity':
            case 'obesity':
              return MedicalCondition.obesity;
            default:
              return null;
          }
        })
        .where((condition) => condition != null)
        .cast<MedicalCondition>()
        .toList();

    final intoleranceEnums = AllergyFilteringService.intolerancesFor(allergies);
    final excludedIngredients =
        AllergyFilteringService.parseExcludedIngredients(
      userProfile['excludedIngredients'],
    );

    // Determine diet compliance based on diet rule from matrix
    bool dashCompliant = false;
    bool myPlateCompliant = false;
    int? maxSodium;

    if (dietRule != null) {
      final diet = dietRule['diet'] as String;
      if (diet == 'DASH') {
        dashCompliant = true;
      } else if (diet == 'MyPlate') {
        myPlateCompliant = true;
      }

      // Get sodium constraint from diet rule
      final sodiumCap = dietRule['sodium_mg_max'];
      if (sodiumCap is int) {
        maxSodium = (sodiumCap / 3).round(); // Convert daily to per-serving
      }
    } else {
      // Fallback to old logic if no diet rule
      if (dietType == 'DASH' ||
          medicalConditions.contains('Hypertension') ||
          healthGoals.contains('Lower blood pressure')) {
        dashCompliant = true;
      } else {
        myPlateCompliant = true;
      }
    }

    return filter.copyWith(
      medicalConditions: medicalConditionEnums,
      intolerances: [...filter.intolerances, ...intoleranceEnums],
      dashCompliant: dashCompliant,
      myPlateCompliant: myPlateCompliant,
      maxSodium: maxSodium,
      veryHealthy: true, // Always prefer healthier options
      excludedIngredientNames:
          excludedIngredients.map((ingredient) => ingredient.name).toList(),
    );
  }

  /// When user picks Snacks, exclude obvious full meals Spoonacular still tags as snack.
  /// When the breakfast search had to drop Spoonacular's own `type` filter
  /// (see [RecipeFilter.suppressTypeParam]) because a cuisine+breakfast combo
  /// has zero matches in Spoonacular's dataset, apply a local allowlist so a
  /// dinner/lunch dish from that cuisine doesn't get shown as "breakfast".
  bool _matchesMealTypeIntent(Recipe recipe, RecipeFilter filter) {
    if (filter.mealType == MealType.snack) {
      return _matchesSnackIntent(recipe);
    }
    if (filter.mealType == MealType.breakfast && filter.suppressTypeParam) {
      return _matchesBreakfastIntent(recipe);
    }
    return true;
  }

  bool _matchesSnackIntent(Recipe recipe) {
    final types = recipe.dishTypes.map((t) => t.toLowerCase().trim()).toSet();
    if (types.contains('main course')) return false;

    final title = recipe.title.toLowerCase();
    const notSnackPhrases = [
      'fried rice',
      'brown rice and',
      'vegetable fried',
      'stir fry',
      'stir-fry',
      'curry',
      'casserole',
      'lasagna',
      'enchilada',
      'burrito bowl',
      'pasta',
      'pizza',
      'burger',
      'meatloaf',
      'pot roast',
      'soup',
    ];
    if (notSnackPhrases.any(title.contains)) return false;

    return types.contains('snack') ||
        types.contains('fingerfood') ||
        types.contains('appetizer') ||
        types.contains('hor d\'oeuvre') ||
        types.contains("hor d'oeuvre");
  }

  /// Allowlist only (no denylist): with Spoonacular's own dishType filter
  /// dropped, it's safer to under-include than to surface an obvious dinner
  /// dish (e.g. "Slow Cooker Lamb Curry") as a breakfast suggestion.
  static const List<String> _breakfastTitleKeywords = [
    // Indian breakfast dishes (the combo that motivated this fallback tier)
    'dosa', 'idli', 'idly', 'poha', 'upma', 'uttapam', 'paratha', 'parantha',
    'thepla', 'sabudana', 'chila', 'cheela', 'vada', 'poori', 'puri bhaji',
    // General
    'breakfast', 'brunch', 'pancake', 'waffle', 'french toast', 'omelet',
    'omelette', 'egg breakfast', 'scramble', 'frittata', 'porridge',
    'oatmeal', 'overnight oats', 'granola', 'muesli', 'hash brown', 'bagel',
    'crepe', 'shakshuka', 'congee', 'muffin', 'cereal',
    // Smoothies/shakes only — not juice, which is too broad to assume
    // breakfast (juice can accompany any meal).
    'smoothie', 'smoothie bowl', 'protein shake',
  ];

  bool _matchesBreakfastIntent(Recipe recipe) {
    final types = recipe.dishTypes.map((t) => t.toLowerCase().trim()).toSet();
    if (types.contains('breakfast') ||
        types.contains('brunch') ||
        types.contains('morning meal')) {
      return true;
    }

    final title = recipe.title.toLowerCase();
    return _breakfastTitleKeywords.any(title.contains);
  }

  bool _hasEnoughIngredients(Recipe recipe, List<PantryItem> pantryItems) {
    // The Spoonacular findByIngredients endpoint provides `missedIngredientCount`.
    // If it's null (which can happen if the recipe comes from another source
    // like the bulk endpoint), we can fall back to checking the extendedIngredients list.
    if (recipe.missedIngredientCount != null ||
        recipe.missedIngredients.isNotEmpty) {
      // Exclude optional lines from the threshold (matches cart badge).
      return recipe.requiredMissedIngredientCount <= 8;
    }

    // Fallback for recipes that have full ingredient details but not the count.
    return recipe.extendedIngredients.isNotEmpty;
  }

  Future<bool> _isHealthCompliant(
      Recipe recipe, Map<String, dynamic> userProfile) async {
    final dietRule = userProfile['diet_rule'] as Map<String, dynamic>?;
    if (dietRule == null) {
      return true; // Default to allowing recipe if no diet rule
    }

    final nutrition = recipe.nutrition;
    if (nutrition == null) {
      return true; // Allow if nutrition data is not available
    }

    // Get constraints for the diet rule
    final constraints =
        await _dietConstraintsService.getConstraintsForRule(dietRule);

    // Validate recipe against constraints
    return await _dietConstraintsService.validateRecipe(
        nutrition.toMap(), constraints);
  }

  bool _isMedicalConditionCompliant(
      Recipe recipe, Map<String, dynamic> userProfile) {
    final medicalConditions =
        List<String>.from(userProfile['medicalConditions'] ?? []);
    final nutrition = recipe.nutrition;

    if (nutrition == null) {
      if (kDebugMode) {
        print('    ℹ️ No nutrition data - allowing recipe');
      }
      return true; // Allow if nutrition data is not available
    }

    for (final condition in medicalConditions) {
      if (kDebugMode) {
        print('    🏥 Checking condition: $condition');
      }

      switch (condition.toLowerCase()) {
        case 'diabetes':
        case 'pre-diabetes':
        case 'prediabetes':
          if (!_isDiabetesCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed diabetes compliance');
            }
            return false;
          }
          break;
        case 'obesity':
        case 'overweight/obesity':
          if (!_isObesityCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed obesity compliance');
            }
            return false;
          }
          break;
        case 'hypertension':
          if (!_isHypertensionCompliant(recipe, nutrition)) {
            if (kDebugMode) {
              print('    ❌ Failed hypertension compliance');
            }
            return false;
          }
          break;
      }
    }

    if (kDebugMode) {
      print('    ✅ Passed all medical condition checks');
    }
    return true;
  }

  bool _isDiabetesCompliant(Recipe recipe, Nutrition nutrition) {
    final sugar = _getNutrientAmount(nutrition, 'Sugar');
    final carbs = _getNutrientAmount(nutrition, 'Carbohydrates');
    final fiber = _getNutrientAmount(nutrition, 'Fiber');

    if (kDebugMode) {
      print(
          '      📊 Diabetes check - Sugar: ${sugar}g, Carbs: ${carbs}g, Fiber: ${fiber}g');
    }

    // ADA guidelines for diabetes (using the new relaxed limits from RecipeFilter)
    if (sugar > 45) {
      if (kDebugMode) {
        print('      ❌ Sugar too high: ${sugar}g > 45g');
      }
      return false; // Max 45g sugar per serving
    }
    if (carbs > 75) {
      if (kDebugMode) {
        print('      ❌ Carbs too high: ${carbs}g > 75g');
      }
      return false; // Max 75g carbs per serving
    }
    // Removed fiber requirement as per our latest changes

    if (kDebugMode) {
      print('      ✅ Passed diabetes compliance');
    }
    return true;
  }

  bool _isObesityCompliant(Recipe recipe, Nutrition nutrition) {
    // No specific constraints for obesity

    return true;
  }

  bool _isHypertensionCompliant(Recipe recipe, Nutrition nutrition) {
    final sodium = _getNutrientAmount(nutrition, 'Sodium');
    final saturatedFat = _getNutrientAmount(nutrition, 'Saturated Fat');

    // DASH guidelines for hypertension (practical approach)
    if (sodium > 800) {
      return false; // Max 800mg sodium per serving (practical DASH)
    }
    if (saturatedFat > 8) {
      return false; // Max 8g saturated fat per serving
    }
    // Prefer recipes with good potassium (300mg+) but don't require it

    return true;
  }

  /// Title keywords for cocktails/spirits — used when nutrition data is
  /// unavailable, or as a backstop against recipes with trace/miscounted
  /// alcohol nutrient data (e.g. rum-flavored desserts). Bare "spritz" was
  /// deliberately dropped in favor of the specific drinks below it —
  /// "spritzer" alone is also a common name for plain sparkling-fruit-soda
  /// mocktails with no alcohol at all, so it isn't a reliable signal on its
  /// own the way a named cocktail or "wine spritzer" is.
  static const List<String> _alcoholicDrinkKeywords = [
    'martini', 'margarita', 'mojito', 'daiquiri', 'mimosa', 'sangria',
    'cocktail', 'bloody mary', 'pina colada', 'piña colada', 'aperol spritz',
    'old fashioned', 'screwdriver', 'negroni', 'manhattan', 'whiskey sour',
    'moscow mule', 'gin and tonic', 'rum punch', 'wine spritzer',
  ];

  /// A title explicitly flagging itself as alcohol-free overrides the
  /// keyword backstop above — "Virgin Sangria" and "Sparkling Cranberry
  /// Spritzer Mocktail" aren't alcoholic just because they share a name
  /// with a cocktail. Only applies to the title heuristic: real nutrient
  /// data showing alcohol > 0 (checked first, below) always wins regardless
  /// of what the title claims.
  static const List<String> _nonAlcoholicQualifiers = [
    'virgin',
    'mocktail',
    'non-alcoholic',
    'nonalcoholic',
    'alcohol-free',
    'alcohol free',
  ];

  bool _isAlcoholicBeverage(Recipe recipe) {
    final nutrition = recipe.nutrition;
    if (nutrition != null && _getNutrientAmount(nutrition, 'Alcohol') > 0) {
      return true;
    }
    final title = recipe.title.toLowerCase();
    if (_nonAlcoholicQualifiers.any(title.contains)) return false;
    return _alcoholicDrinkKeywords.any(title.contains);
  }

  double _getNutrientAmount(Nutrition nutrition, String nutrientName) {
    try {
      final nutrient = nutrition.nutrients.firstWhere(
        (n) => n.name.toLowerCase() == nutrientName.toLowerCase(),
      );
      return nutrient.amount;
    } catch (e) {
      return 0.0; // Return 0 if nutrient not found
    }
  }

  Recipe _enhanceRecipeWithPantryData(
      Recipe recipe, List<PantryItem> pantryItems) {
    // The usedIngredients list from Spoonacular tells us what we have.
    final usedPantryItemNames =
        recipe.usedIngredients.map((i) => i.name).toSet();

    final expiringPantryItems = pantryItems
        .where((pantryItem) =>
            usedPantryItemNames.contains(pantryItem.name) &&
            pantryItem.expiryDate != null &&
            pantryItem.expiryDate!
                .isBefore(DateTime.now().add(const Duration(days: 2))))
        .map((pantryItem) => pantryItem.name)
        .toList();

    return recipe.copyWith(
      pantryItemsUsed: usedPantryItemNames.toList(),
      expiringItemsUsed: expiringPantryItems,
    );
  }
}

/// Debug-only counters for generation observation (no effect on ranking/validation).
class _GenerationDiagnostics {
  final RecipeFilter filter;
  final Map<String, dynamic> userProfile;

  int spoonacularCandidates = 0;
  int validatedPassed = 0;
  int failedPantry = 0;
  int failedHealth = 0;
  int failedMedical = 0;
  int failedMealType = 0;
  int failedInstructions = 0;
  int failedCuisine = 0;
  int failedMainIngredient = 0;
  String fallbackStatus = 'Not evaluated';

  final List<({String? label, String url})> spoonacularRequests = [];

  /// One entry per tier attempt across the whole generation call (both
  /// no-preference branches, if applicable) — measurement only, doesn't
  /// influence the fallback ladder or ranking. See [recordTier].
  final List<_TierDiagnostics> tiers = [];

  _GenerationDiagnostics({
    required this.filter,
    required this.userProfile,
  });

  void noteFallback(String status) {
    fallbackStatus = status;
  }

  /// [label] is passed explicitly per call (e.g. "FAVORITES" vs
  /// "ALL CUISINES") rather than read from shared mutable state, since the
  /// no-preference path runs its two batches concurrently — a shared
  /// "current label" field would get stomped by whichever batch set it last.
  void recordSpoonacularRequest(String url, {String? label}) {
    spoonacularRequests.add((label: label, url: url));
  }

  /// Records one tier attempt for the "actual network calls vs cache hits,
  /// candidates per tier, new-to-pool per tier" measurement — added purely
  /// for instrumentation, appended by [absorb] in [_generateWithFallbacks]
  /// which already computes every one of these values for its own dedup
  /// logic; this just also keeps a copy. Never read by the fallback ladder
  /// itself, so it cannot change when the ladder stops or what it returns.
  void recordTier({
    required String label,
    required String? batchLabel,
    required int candidatesReturned,
    required int validatedPassed,
    required bool fromCache,
    required int newlyAddedToPool,
    required int poolSizeAfter,
  }) {
    tiers.add(_TierDiagnostics(
      label: label,
      batchLabel: batchLabel,
      candidatesReturned: candidatesReturned,
      validatedPassed: validatedPassed,
      fromCache: fromCache,
      newlyAddedToPool: newlyAddedToPool,
      poolSizeAfter: poolSizeAfter,
    ));
  }

  void logSummary({required int finalReturned}) {
    final cuisines = filter.isNoPreferenceOnly
        ? 'No preference'
        : (filter.explicitCuisines.isEmpty
            ? 'All cuisines'
            : filter.explicitCuisines.map((c) => c.displayName).join(', '));
    final meal =
        filter.spoonacularTypeParam ?? filter.mealType?.displayName ?? 'Any';
    final maxTime =
        filter.maxReadyTime != null ? '${filter.maxReadyTime} min' : 'None';
    final dietType = userProfile['dietType']?.toString() ?? 'Unknown';
    final healthFlags = <String>[
      if (filter.dashCompliant) 'DASH',
      if (filter.myPlateCompliant) 'MyPlate',
      if (filter.veryHealthy) 'veryHealthy',
    ].join(', ');

    print('\n📊 Recipe Generation Summary');
    print('');
    print('Requested:');
    print('- Cuisine: $cuisines');
    print('- Meal type: $meal');
    print('- Max time: $maxTime');
    print('- Health: $dietType${healthFlags.isEmpty ? '' : ' ($healthFlags)'}');
    print('');
    print('Spoonacular:');
    print('- Candidates returned: $spoonacularCandidates');
    if (spoonacularRequests.isNotEmpty) {
      print('- Requests (${spoonacularRequests.length}):');
      for (var i = 0; i < spoonacularRequests.length; i++) {
        final req = spoonacularRequests[i];
        final label = req.label ?? 'Request ${i + 1}';
        print('    ${i + 1}. $label');
        print('       URL: ${req.url}');
        final params = Uri.tryParse(req.url)?.queryParameters ?? const {};
        if (params.isNotEmpty) {
          for (final entry in params.entries) {
            print('         ${entry.key}=${entry.value}');
          }
        }
      }
    }
    print('');
    print('Validation:');
    print('- Passed: $validatedPassed');
    print('- Failed:');
    print('    Pantry: $failedPantry');
    print('    Health: $failedHealth');
    print('    Medical: $failedMedical');
    print('    Meal type: $failedMealType');
    print('    Instructions: $failedInstructions');
    print('    Cuisine: $failedCuisine');
    print('    Main ingredient: $failedMainIngredient');
    print('');
    print('Final:');
    print('- Returned to UI: $finalReturned');
    print('');
    print('Fallback:');
    print('- $fallbackStatus');

    if (tiers.isNotEmpty) {
      final networkCalls = tiers.where((t) => !t.fromCache).length;
      final cacheHits = tiers.where((t) => t.fromCache).length;
      print('');
      print('Spoonacular usage:');
      print('- Tier attempts: ${tiers.length}');
      print('- Network requests: $networkCalls');
      print('- Cache hits: $cacheHits');
      print('- Per tier:');
      for (final t in tiers) {
        final source = t.fromCache ? 'cache' : 'network';
        final batch = t.batchLabel != null ? ' [${t.batchLabel}]' : '';
        print('    ${t.label}$batch — $source, '
            '${t.candidatesReturned} candidates → ${t.validatedPassed} '
            'validated → +${t.newlyAddedToPool} new to pool '
            '(pool: ${t.poolSizeAfter})');
      }

      final batchLabels = tiers
          .map((t) => t.batchLabel)
          .whereType<String>()
          .toSet();
      if (batchLabels.length > 1) {
        print('- By search branch:');
        for (final label in batchLabels) {
          final branchTiers = tiers.where((t) => t.batchLabel == label);
          final branchNetwork = branchTiers.where((t) => !t.fromCache).length;
          final branchCache = branchTiers.where((t) => t.fromCache).length;
          print('    $label — $branchNetwork network, $branchCache cache '
              '(${branchTiers.length} tier attempts)');
        }
      }
    }
  }
}

/// One tier attempt's stats, for the "actual network calls vs cache hits,
/// candidates per tier" measurement only (see [_GenerationDiagnostics.recordTier]).
class _TierDiagnostics {
  final String label;
  final String? batchLabel;
  final int candidatesReturned;
  final int validatedPassed;
  final bool fromCache;
  final int newlyAddedToPool;
  final int poolSizeAfter;

  const _TierDiagnostics({
    required this.label,
    required this.batchLabel,
    required this.candidatesReturned,
    required this.validatedPassed,
    required this.fromCache,
    required this.newlyAddedToPool,
    required this.poolSizeAfter,
  });
}
