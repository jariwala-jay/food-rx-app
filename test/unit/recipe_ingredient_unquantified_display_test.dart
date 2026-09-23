import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

// Lines with no stated quantity ("Salt to taste", "olive oil") arrive from
// Spoonacular as `1 serving` and the unit cleanup turns that into "1 piece".
// They should show their source wording instead.
RecipeIngredient _ingredient(
  String original, {
  String name = 'salt',
  String unit = 'piece',
  String measureUnit = 'serving',
}) {
  return RecipeIngredient(
    id: 1,
    aisle: '',
    image: '',
    consistency: '',
    name: name,
    nameClean: name,
    original: original,
    originalName: original,
    amount: 1,
    unit: unit,
    meta: const [],
    measures: Measures(
      us: Measure(amount: 1, unitShort: measureUnit, unitLong: measureUnit),
      metric:
          Measure(amount: 1, unitShort: measureUnit, unitLong: measureUnit),
    ),
  );
}

void main() {
  group('RecipeIngredient.unquantifiedDisplayText', () {
    test('"to taste" lines show their source wording', () {
      expect(_ingredient('Salt to taste').unquantifiedDisplayText,
          'Salt to taste');
    });

    test('"as needed" lines show their source wording', () {
      expect(
          _ingredient('Pepper Powder as needed', name: 'pepper powder')
              .unquantifiedDisplayText,
          'Pepper Powder as needed');
    });

    test('bare ingredient names with no quantity are shown as written', () {
      expect(_ingredient('olive oil', name: 'olive oil').unquantifiedDisplayText,
          'Olive oil');
      expect(_ingredient('salt & pepper').unquantifiedDisplayText,
          'Salt & pepper');
    });

    test('first letter is capitalised', () {
      expect(_ingredient('salt, to taste').unquantifiedDisplayText,
          'Salt, to taste');
    });

    test('lines with a stated quantity are left to the normal formatter', () {
      expect(
          _ingredient('1 tsp salt', unit: 'teaspoon', measureUnit: 'tsp')
              .unquantifiedDisplayText,
          isNull);
      expect(
          _ingredient('2 tablespoons olive oil, for frying')
              .unquantifiedDisplayText,
          isNull);
    });

    test('a real measured unit is never replaced, even without digits in text',
        () {
      expect(
          _ingredient('a cup of milk', name: 'milk', measureUnit: 'cup')
              .unquantifiedDisplayText,
          isNull);
    });

    test('empty original text is ignored', () {
      expect(_ingredient('').unquantifiedDisplayText, isNull);
    });
  });
}
