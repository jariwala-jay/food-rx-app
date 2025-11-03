import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

void main() {
  test('RecipeFilter.toSpoonacularParams includes intolerances', () {
    final filter = RecipeFilter(
      intolerances: const [
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
