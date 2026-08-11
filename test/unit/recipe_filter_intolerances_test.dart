import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

void main() {
  test('empty cuisines acts as no preference', () {
    const filter = RecipeFilter();
    expect(filter.isNoPreferenceOnly, isTrue);
    expect(filter.hasExplicitCuisinePreference, isFalse);
    expect(filter.toSpoonacularParams().containsKey('cuisine'), isFalse);
  });

  test('explicit no preference omits cuisine param', () {
    const filter = RecipeFilter(cuisines: [CuisineType.noPreference]);
    expect(filter.isNoPreferenceOnly, isTrue);
    expect(filter.toSpoonacularParams().containsKey('cuisine'), isFalse);
  });

  test('selected cuisines are explicit preference', () {
    const filter = RecipeFilter(cuisines: [CuisineType.korean]);
    expect(filter.isNoPreferenceOnly, isFalse);
    expect(filter.hasExplicitCuisinePreference, isTrue);
    expect(filter.toSpoonacularParams()['cuisine'], 'korean');
  });

  test('RecipeFilter.toSpoonacularParams includes intolerances', () {
    const filter = RecipeFilter(
      intolerances: [
        Intolerances.dairy,
        Intolerances.gluten,
        Intolerances.peanut,
      ],
    );

    final params = filter.toSpoonacularParams();
    expect(params['intolerances'], isNotNull);
    expect(params['intolerances']!.contains('dairy'), true);
    expect(params['intolerances']!.contains('gluten'), true);
    expect(params['intolerances']!.contains('peanut'), true);
  });
}
