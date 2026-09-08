import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';

// Regression coverage for the "0 candidates" bug: assert against the actual
// query parameters sent to Spoonacular (buildComplexSearchUri), not just the
// local pantry/main-ingredient validators — those never even ran because the
// API call itself returned nothing.
void main() {
  group('SpoonacularRecipeRepository.buildComplexSearchUri', () {
    test(
        'a large, varied pantry never produces an includeIngredients AND '
        'query containing every pantry item', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Oranges', category: 'fresh_fruits'),
        (name: 'coconut', category: 'other'),
        (name: 'Frozen Mixed Berries', category: 'frozen_fruits'),
        (name: 'Frozen Raspberries', category: 'frozen_fruits'),
        (name: 'White Beans', category: 'beans'),
        (name: 'Canned Tomatoes', category: 'canned_veggies'),
        (name: 'Chicken Breast', category: 'meat'),
        (name: 'Chicken Thighs', category: 'meat'),
      ]);

      const filter = RecipeFilter(
        cuisines: [CuisineType.indian],
        mealType: MealType.breakfast,
        maxReadyTime: 60,
      );

      final uri = SpoonacularRecipeRepository.buildComplexSearchUri(
        filter,
        selection.includedNames,
      );

      final includeIngredients = uri.queryParameters['includeIngredients'];
      expect(includeIngredients, isNotNull);
      final sentNames = includeIngredients!.split(',');

      expect(sentNames.length, lessThan(8));
    });

    test('relaxed health filter omits maxSodium/veryHealthy from the URI',
        () {
      const filter = RecipeFilter(
        medicalConditions: [MedicalCondition.hypertension],
        dashCompliant: true,
        veryHealthy: true,
        maxSodium: 500,
      );

      final strictUri =
          SpoonacularRecipeRepository.buildComplexSearchUri(filter, const []);
      expect(strictUri.queryParameters['maxSodium'], '500');
      expect(strictUri.queryParameters['veryHealthy'], 'true');

      final relaxed = filter.copyWith(
        veryHealthy: false,
        dashCompliant: false,
        myPlateCompliant: false,
        maxSodium: null,
      );
      final relaxedUri = SpoonacularRecipeRepository.buildComplexSearchUri(
        relaxed,
        const [],
      );

      expect(relaxedUri.queryParameters.containsKey('maxSodium'), isFalse);
      expect(relaxedUri.queryParameters.containsKey('veryHealthy'), isFalse);
    });

    // Regression: cuisine=indian&type=breakfast returns 0 totalResults from
    // Spoonacular's own API even though cuisine=indian alone returns 121 —
    // the dishType tagging just doesn't cover that intersection. The
    // suppressTypeParam fallback tier drops `type` from the query while
    // RecipeFilter.mealType stays set, so local meal-type-intent matching
    // still has something to enforce.
    test('suppressTypeParam omits type from the URI but keeps cuisine', () {
      const filter = RecipeFilter(
        cuisines: [CuisineType.indian],
        mealType: MealType.breakfast,
      );

      final normalUri =
          SpoonacularRecipeRepository.buildComplexSearchUri(filter, const []);
      expect(normalUri.queryParameters['type'], 'breakfast');

      final suppressed = filter.copyWith(suppressTypeParam: true);
      final suppressedUri = SpoonacularRecipeRepository.buildComplexSearchUri(
        suppressed,
        const [],
      );

      expect(suppressedUri.queryParameters.containsKey('type'), isFalse);
      expect(suppressedUri.queryParameters['cuisine'], 'indian');
      // mealType itself is untouched — only the outgoing query param is
      // suppressed, so local validation can still use filter.mealType.
      expect(suppressed.mealType, MealType.breakfast);
    });

    // Regression: RecipeGenerationService._isHealthCompliant and
    // _isMedicalConditionCompliant both silently pass any recipe with a null
    // `nutrition` field ("No nutrition data - allowing recipe"). Spoonacular
    // only includes nutrition in complexSearch results when explicitly
    // asked via addRecipeNutrition — without it, DASH/sodium/medical-
    // condition checks were never actually enforced, on any tier.
    test('requests nutrition data so health/medical gates can be enforced',
        () {
      const filter = RecipeFilter();
      final uri =
          SpoonacularRecipeRepository.buildComplexSearchUri(filter, const []);

      expect(uri.queryParameters['addRecipeNutrition'], 'true');
    });

    // Regression: multi-word cuisines were sent using the enum's raw
    // camelCase name (e.g. "middleEastern"), which Spoonacular doesn't
    // recognize — confirmed live against the API to return totalResults: 0,
    // versus 33 real Middle Eastern-tagged recipes for the correct
    // space-separated form. CuisineType.apiName now provides that mapping.
    test(
        'multi-word cuisines are sent space-separated, not as the enum\'s '
        'camelCase name', () {
      const filter = RecipeFilter(cuisines: [
        CuisineType.middleEastern,
        CuisineType.easternEurope,
        CuisineType.latinAmerican,
      ]);
      final uri =
          SpoonacularRecipeRepository.buildComplexSearchUri(filter, const []);

      expect(
        uri.queryParameters['cuisine'],
        'middle eastern,eastern european,latin american',
      );
    });

    test('single-word cuisines are unaffected by apiName', () {
      const filter = RecipeFilter(cuisines: [
        CuisineType.indian,
        CuisineType.american,
      ]);
      final uri =
          SpoonacularRecipeRepository.buildComplexSearchUri(filter, const []);

      expect(uri.queryParameters['cuisine'], 'indian,american');
    });
  });
}
