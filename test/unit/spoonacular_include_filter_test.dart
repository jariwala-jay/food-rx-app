import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/utils/ingredient_nutritional_category.dart';

void main() {
  group('Phase 1.5 Spoonacular includeIngredients filter', () {
    test('excludes seasonings and keeps meaningful pantry names', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Chicken Breast', category: 'protein'),
        (name: 'Salt', category: 'seasonings'),
        (name: 'Black Pepper', category: 'seasonings'),
        (name: 'White Rice', category: 'grains'),
      ]);

      expect(selection.includedNames, ['Chicken Breast', 'White Rice']);
      expect(
        selection.exclusions.map((e) => e.name),
        ['Salt', 'Black Pepper'],
      );
    });

    test('seasoning-only pantry yields empty includeIngredients', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Salt', category: 'seasonings'),
        (name: 'Pepper', category: 'seasonings'),
        (name: 'Paprika', category: 'seasonings'),
      ]);

      expect(selection.includedNames, isEmpty);
      expect(selection.exclusions.length, 3);
    });

    test('condiments are excluded from discovery', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Spinach', category: 'fresh_veggies'),
        (name: 'Ketchup', category: 'essentials_condiments'),
      ]);

      expect(selection.includedNames, ['Spinach']);
      expect(selection.exclusions.single.name, 'Ketchup');
      expect(
        selection.exclusions.single.category,
        IngredientNutritionalCategory.condiment,
      );
    });

    test('Phase 1.5.1: cooking oils and butter are condiments', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Tomatoes', category: 'fresh_veggies'),
        (name: 'olive oil', category: 'dairy'),
        (name: 'Canola Oil', category: 'pantry_staples'),
        (name: 'Butter', category: 'dairy'),
        (name: 'Soy Sauce', category: 'essentials_condiments'),
      ]);

      expect(selection.includedNames, ['Tomatoes']);
      expect(
        selection.exclusions.map((e) => e.name),
        ['olive oil', 'Canola Oil', 'Butter', 'Soy Sauce'],
      );
      expect(
        selection.exclusions.every(
          (e) => e.category == IngredientNutritionalCategory.condiment,
        ),
        isTrue,
      );
    });

    test('Phase 1.5.1: boil/foil are not treated as oil', () {
      expect(
        IngredientNutritionalCategoryResolver.fromIngredientName('boil'),
        isNot(IngredientNutritionalCategory.condiment),
      );
      expect(
        IngredientNutritionalCategoryResolver.fromIngredientName(
          'aluminum foil',
        ),
        isNot(IngredientNutritionalCategory.condiment),
      );
      expect(
        IngredientNutritionalCategoryResolver.fromIngredientName(
          'butter chicken',
        ),
        IngredientNutritionalCategory.protein,
      );
    });

    test('dedupes included names case-insensitively', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude([
        (name: 'Chicken Breast', category: 'protein'),
        (name: 'chicken breast', category: 'protein'),
      ]);

      expect(selection.includedNames, ['Chicken Breast']);
    });

    // Regression: Spoonacular's `includeIngredients` is an AND filter — a
    // recipe must contain *every* listed ingredient. Sending a large,
    // unrelated pantry (as happened for an Indian breakfast search with
    // oranges + coconut + chicken + canned tomatoes + white beans all
    // required at once) made matches impossible and returned 0 candidates.
    test(
        'caps a large, varied pantry to a handful of highest-weight items '
        'instead of requiring every pantry item to match (AND-filter trap)',
        () {
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

      // Never send the whole pantry — that's what produced the impossible
      // AND-of-8 query that returned 0 candidates.
      expect(selection.includedNames.length, lessThan(8));
      expect(
        selection.includedNames,
        isNot(containsAll([
          'Oranges',
          'coconut',
          'Frozen Mixed Berries',
          'Frozen Raspberries',
          'White Beans',
          'Canned Tomatoes',
          'Chicken Breast',
          'Chicken Thighs',
        ])),
      );

      // Highest-weight (protein) items are kept over low-weight ones like
      // the uncategorized "coconut" (weight 1.0, category 'other').
      expect(selection.includedNames, contains('Chicken Breast'));
      expect(selection.includedNames, contains('Chicken Thighs'));
      expect(selection.includedNames, isNot(contains('coconut')));
    });

    test('maxIncluded caps the includeIngredients list length', () {
      final selection =
          IngredientNutritionalCategoryResolver.selectForSpoonacularInclude(
        [
          (name: 'Chicken Breast', category: 'meat'),
          (name: 'Spinach', category: 'fresh_veggies'),
          (name: 'White Rice', category: 'grains'),
          (name: 'Milk', category: 'dairy'),
          (name: 'Lentils', category: 'beans'),
        ],
        maxIncluded: 2,
      );

      expect(selection.includedNames.length, 2);
      // Protein (5.0) then vegetable (3.0) outrank grain/dairy/legume (2.0 each).
      expect(selection.includedNames, ['Chicken Breast', 'Spinach']);
    });
  });
}
