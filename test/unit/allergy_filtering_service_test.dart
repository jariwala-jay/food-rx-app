import 'package:flutter_app/core/models/excluded_ingredient.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExcludedIngredient', () {
    test('reads legacy strings and matches common ingredient variations', () {
      final ingredient = ExcludedIngredient.fromJson('Peaches');

      expect(ingredient.name, 'peach');
      expect(ingredient.source, 'legacy');
      expect(ingredient.matches('fresh peach slices'), isTrue);
      expect(ingredient.matches('sliced peaches'), isTrue);
      expect(ingredient.matches('pear slices'), isFalse);
    });

    test('reads and writes structured values', () {
      final ingredient = ExcludedIngredient.fromJson(const {
        'id': 9236,
        'name': 'peach',
        'displayName': 'Peach',
        'source': 'spoonacular',
      });

      expect(ingredient.id, '9236');
      expect(ingredient.toJson()['source'], 'spoonacular');
    });
  });

  group('AllergyFilteringService', () {
    test('maps supported allergies without conflating wheat and gluten', () {
      final mapped = AllergyFilteringService.intolerancesFor([
        'Wheat',
        'Sesame',
        'Shellfish',
      ]);

      expect(mapped, contains(Intolerances.wheat));
      expect(mapped, contains(Intolerances.sesame));
      expect(mapped, contains(Intolerances.shellfish));
      expect(mapped, isNot(contains(Intolerances.gluten)));
    });

    test('detects custom exclusions and standard allergen aliases', () {
      const peach = ExcludedIngredient(
        id: '9236',
        name: 'peach',
        displayName: 'Peach',
        source: 'spoonacular',
      );

      expect(
        AllergyFilteringService.conflictsWithRestrictions(
          'fresh peaches',
          allergies: const [],
          excludedIngredients: const [peach],
        ),
        isTrue,
      );
      expect(
        AllergyFilteringService.conflictsWithRestrictions(
          'plain Greek yogurt',
          allergies: const ['Dairy'],
          excludedIngredients: const [],
        ),
        isTrue,
      );
      expect(
        AllergyFilteringService.conflictsWithRestrictions(
          'unsweetened coconut milk',
          allergies: const ['Dairy'],
          excludedIngredients: const [],
        ),
        isFalse,
      );
    });
  });

  test('RecipeFilter sends custom exclusions to Spoonacular', () {
    const filter = RecipeFilter(
      excludedIngredientNames: ['peach', 'mushroom'],
    );

    expect(
      filter.toSpoonacularParams()['excludeIngredients'],
      'peach,mushroom',
    );
  });

  test('UserModel remains compatible with legacy exclusion strings', () {
    final user = UserModel.fromJson({
      'email': 'test@example.com',
      'excludedIngredients': [
        'Peaches',
        {
          'id': 11260,
          'name': 'mushroom',
          'displayName': 'Mushroom',
          'source': 'spoonacular',
        },
      ],
    });

    expect(user.excludedIngredients, hasLength(2));
    expect(user.excludedIngredients!.first.name, 'peach');
    expect(
      user.toJson()['excludedIngredients'],
      everyElement(isA<Map<String, dynamic>>()),
    );
  });
}
