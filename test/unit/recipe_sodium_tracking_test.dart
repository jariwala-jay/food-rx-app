import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/recipes/application/recipe_generation_service.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/repositories/recipe_repository.dart';
import 'package:flutter_app/features/tracking/controller/tracker_provider.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

// Recipe logging must add the recipe's sodium to the Sodium tracker for both
// DASH and MyPlate users (Sodium is a tracker on both plans). Covers the two
// RecipeController paths: cooking a recipe and logging a prepared recipe.
// The recipe has no ingredients so only the sodium increment is exercised.

class _FakeAuth extends Fake implements AuthController {
  @override
  final UserModel currentUser;
  _FakeAuth(this.currentUser);
}

class _FakePantry extends Fake implements PantryController {
  @override
  List<PantryItem> get pantryItems => const [];
  @override
  List<PantryItem> get otherItems => const [];
  @override
  Future<void> loadItems() async {}
}

class _FakeRepository extends Fake implements RecipeRepository {
  @override
  Future<void> cookRecipe(String userId, Recipe recipe) async {}
}

class _FakeTrackers extends Fake implements TrackerProvider {
  final List<TrackerGoal> trackers;
  final Map<String, double> increments = {};
  _FakeTrackers(this.trackers);

  @override
  List<TrackerGoal> get dailyTrackers => trackers;
  @override
  List<TrackerGoal> get weeklyTrackers => const [];

  @override
  TrackerGoal? findTrackerByCategory(TrackerCategory category, String dietType) {
    for (final t in trackers) {
      if (t.category == category &&
          t.dietType.toLowerCase() == dietType.toLowerCase()) {
        return t;
      }
    }
    return null;
  }

  @override
  Future<void> incrementTracker(String trackerId, double amount) async {
    increments[trackerId] = (increments[trackerId] ?? 0) + amount;
  }
}

Recipe _recipe({Nutrition? nutrition, int servings = 2}) {
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
    extendedIngredients: const [],
    analyzedInstructions: const [],
    vegetarian: false,
    vegan: false,
    glutenFree: true,
    dairyFree: true,
    veryHealthy: false,
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
    nutrition: nutrition,
  );
}

Nutrition _sodiumNutrition(double amount, {String unit = 'mg'}) => Nutrition(
      nutrients: [Nutrient(name: 'Sodium', amount: amount, unit: unit)],
      ingredients: const [],
    );

TrackerGoal _sodiumTracker(String dietType) => TrackerGoal(
      userId: 'u1',
      name: 'Sodium',
      category: TrackerCategory.sodium,
      goalValue: 2300,
      unit: TrackerUnit.mg,
      dietType: dietType,
    );

void main() {
  late _FakeTrackers trackers;
  late TrackerGoal sodiumTracker;

  RecipeController buildController(String planType) {
    sodiumTracker = _sodiumTracker(planType);
    trackers = _FakeTrackers([sodiumTracker]);
    final conversion = UnitConversionService();
    return RecipeController(
      recipeGenerationService: _NoGeneration(),
      recipeRepository: _FakeRepository(),
      pantryDeductionService: PantryDeductionService(
        conversionService: conversion,
        substitutionService:
            IngredientSubstitutionService(conversionService: conversion),
      ),
      dietServingService: DietServingService(conversionService: conversion),
      trackerProvider: trackers,
      authProvider: _FakeAuth(UserModel(
        id: 'u1',
        email: 'u@example.com',
        dietType: planType,
        myPlanType: planType,
      )),
      pantryController: _FakePantry(),
    );
  }

  for (final plan in ['DASH', 'MyPlate']) {
    group('$plan user', () {
      test('cookRecipe adds one serving of recipe sodium', () async {
        final controller = buildController(plan);

        await controller.cookRecipe(_recipe(nutrition: _sodiumNutrition(400)));

        expect(trackers.increments[sodiumTracker.id], 400);
      });

      test('logging prepared servings scales sodium by servings consumed',
          () async {
        final controller = buildController(plan);

        await controller.applyConsumptionToPantryAndGoals(
          _recipe(nutrition: _sodiumNutrition(400)),
          1.5,
        );

        expect(trackers.increments[sodiumTracker.id], 600);
      });

      test('sodium reported in grams is converted to mg', () async {
        final controller = buildController(plan);

        await controller.cookRecipe(
            _recipe(nutrition: _sodiumNutrition(0.5, unit: 'g')));

        expect(trackers.increments[sodiumTracker.id], 500);
      });

      test('missing sodium data leaves the Sodium tracker untouched',
          () async {
        final controller = buildController(plan);

        await controller.cookRecipe(_recipe(nutrition: null));
        await controller.cookRecipe(_recipe(
            nutrition: Nutrition(nutrients: const [], ingredients: const [])));
        await controller.applyConsumptionToPantryAndGoals(
            _recipe(nutrition: null), 1);

        expect(trackers.increments, isEmpty);
      });
    });
  }
}

class _NoGeneration extends Fake implements RecipeGenerationService {}
