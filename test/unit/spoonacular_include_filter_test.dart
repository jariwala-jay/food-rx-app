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
  });
}
