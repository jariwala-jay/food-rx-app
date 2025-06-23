import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Helper function to find an ingredient in a recipe, ignoring case.
RecipeIngredient? findIngredient(Recipe recipe, String name) {
  try {
    return recipe.extendedIngredients.firstWhere(
        (ing) => ing.name.toLowerCase().contains(name.toLowerCase()));
  } catch (e) {
    return null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Declare variables here but don't initialize them yet.
  late SpoonacularRecipeRepository recipeRepository;
  late UnitConversionService unitConversionService;

  // Load environment variables and initialize repositories ONCE before any tests run.
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
    // Now it's safe to initialize the repository.
    recipeRepository = SpoonacularRecipeRepository();
    unitConversionService = UnitConversionService();
  });

  group('End-to-End Recipe Servings Conversion Test', () {
    // Test Case 1: Doubling a stir-fry recipe
    testWidgets('correctly doubles a stir-fry recipe',
        (WidgetTester tester) async {
      final List<Recipe> recipes = await recipeRepository
          .getRecipes(const RecipeFilter(query: 'Beef and Broccoli'), []);
      expect(recipes, isNotEmpty);

      final originalRecipe = recipes.first;
      final originalServings = originalRecipe.servings;
      final targetServings = originalServings * 2;
      final ratio = targetServings / originalServings;

      final adjustedIngredients = originalRecipe.extendedIngredients.map((ing) {
        final scaledAmount = ing.amount * ratio;
        final optimized =
            unitConversionService.optimizeUnits(scaledAmount, ing.unit);
        return ing.copyWith(
            amount: optimized['amount'] as double,
            unit: optimized['unit'] as String);
      }).toList();

      final adjustedRecipe = originalRecipe.copyWith(
          extendedIngredients: adjustedIngredients, servings: targetServings);

      print("\n--- TEST 1: Double Stir-Fry Servings ---");
      print("Original: ${originalRecipe.title} for $originalServings");
      print("Adjusted for: $targetServings");

      final beef = findIngredient(adjustedRecipe, 'beef steak');
      expect(beef?.unit.toLowerCase(), contains('pound'));
      expect(beef?.amount, closeTo(1.5, 0.01));
      print("OK: Beef correctly scaled to pounds.");

      final chili = findIngredient(adjustedRecipe, 'chili sauce');
      if (chili != null &&
          findIngredient(originalRecipe, 'chili sauce')!
              .unit
              .contains('teaspoon')) {
        expect(chili.unit.toLowerCase(), contains('tablespoon'));
        expect(chili.amount, closeTo(1.33, 0.01));
        print("OK: Chili sauce correctly scaled to tablespoons.");
      }
    });

    // Test Case 2: Halving a baking recipe
    testWidgets('correctly halves a baking recipe',
        (WidgetTester tester) async {
      final List<Recipe> recipes = await recipeRepository.getRecipes(
          const RecipeFilter(query: 'Classic Chocolate Chip Cookies'), []);
      expect(recipes, isNotEmpty);

      final originalRecipe = recipes.first;
      final originalServings = originalRecipe.servings;
      final targetServings = (originalServings / 2).round();
      final ratio = targetServings / originalServings;

      final adjustedIngredients = originalRecipe.extendedIngredients.map((ing) {
        final scaledAmount = ing.amount * ratio;
        final optimized =
            unitConversionService.optimizeUnits(scaledAmount, ing.unit);
        return ing.copyWith(
            amount: optimized['amount'] as double,
            unit: optimized['unit'] as String);
      }).toList();

      final adjustedRecipe = originalRecipe.copyWith(
          extendedIngredients: adjustedIngredients, servings: targetServings);

      print("\n--- TEST 2: Halve Baking Recipe Servings ---");
      print("Original: ${originalRecipe.title} for $originalServings");
      print("Adjusted for: $targetServings");

      final flour = findIngredient(adjustedRecipe, 'flour');
      final originalFlour = findIngredient(originalRecipe, 'flour');
      if (flour != null && originalFlour != null) {
        expect(flour.amount, closeTo(originalFlour.amount * ratio, 0.01));
        print("OK: Flour amount correctly halved.");
      }

      final butter = findIngredient(adjustedRecipe, 'butter');
      final originalButter = findIngredient(originalRecipe, 'butter');
      if (butter != null && originalButter != null) {
        expect(butter.amount, closeTo(originalButter.amount * ratio, 0.01));
        print("OK: Butter amount correctly halved.");
      }
    });

    // Test Case 3: Scaling a soup recipe by a non-integer factor
    testWidgets('correctly scales a soup recipe by a non-integer factor',
        (WidgetTester tester) async {
      final List<Recipe> recipes = await recipeRepository
          .getRecipes(const RecipeFilter(query: 'Tomato Soup'), []);
      expect(recipes, isNotEmpty);

      final originalRecipe = recipes.first;
      final originalServings = originalRecipe.servings;
      final targetServings = originalServings + 1;
      final ratio = targetServings / originalServings;

      final adjustedIngredients = originalRecipe.extendedIngredients.map((ing) {
        final scaledAmount = ing.amount * ratio;
        final optimized =
            unitConversionService.optimizeUnits(scaledAmount, ing.unit);
        return ing.copyWith(
            amount: optimized['amount'] as double,
            unit: optimized['unit'] as String);
      }).toList();

      final adjustedRecipe = originalRecipe.copyWith(
          extendedIngredients: adjustedIngredients, servings: targetServings);

      print("\n--- TEST 3: Scale Soup Servings by non-integer ---");
      print("Original: ${originalRecipe.title} for $originalServings");
      print("Adjusted for: $targetServings");

      final tomatoes = findIngredient(adjustedRecipe, 'tomatoes');
      final originalTomatoes = findIngredient(originalRecipe, 'tomatoes');

      if (tomatoes != null && originalTomatoes != null) {
        expect(tomatoes.amount, closeTo(originalTomatoes.amount * ratio, 0.01));
        print("OK: Tomato amount correctly scaled by a non-integer factor.");
      }
    });
  });
}
