import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/models/ingredient.dart';

void main() {
  group('PantryItem.spoonacularId', () {
    // Regression: spoonacularId must mean "a verified Spoonacular identity
    // safe to use for nutrition" -- not "any id we happened to have". A
    // genuine live-search result's numeric id should be captured; a
    // curated catalog's internal slug (e.g. 'chicken-breast') and a fully
    // custom item's 'custom_<timestamp>' id must both yield null, since
    // neither is a verified Spoonacular identity.
    test('fromIngredient captures a genuine numeric Spoonacular id', () {
      final ingredient = Ingredient(
        id: '11282',
        name: 'Onion',
        image: 'onion.png',
        imageName: 'onion.png',
      );
      final item = PantryItem.fromIngredient(ingredient, 'fresh_veggies');
      expect(item.spoonacularId, 11282);
    });

    test('fromIngredient yields null spoonacularId for a curated slug id',
        () {
      final ingredient = Ingredient(
        id: 'chicken-breast',
        name: 'Chicken Breast',
        image: 'chicken-breasts.jpg',
        imageName: 'chicken-breasts.jpg',
      );
      final item = PantryItem.fromIngredient(ingredient, 'meat');
      expect(item.spoonacularId, null);
    });

    test('fromIngredient yields null spoonacularId for a custom item id',
        () {
      final ingredient = Ingredient(
        id: 'custom_1234567890',
        name: 'Grandma\'s special food',
        image: '',
        imageName: 'default.jpg',
      );
      final item = PantryItem.fromIngredient(ingredient, 'miscellaneous');
      expect(item.spoonacularId, null);
    });

    test('fromSpoonacularItem captures the numeric Spoonacular id', () {
      final item = PantryItem.fromSpoonacularItem(
        {'id': 5062, 'name': 'chicken breast', 'image': 'chicken-breasts.png'},
        'meat',
      );
      expect(item.spoonacularId, 5062);
    });

    test('toMap includes spoonacularId only when non-null', () {
      final withId = PantryItem(
        id: '1',
        name: 'Onion',
        imageUrl: '',
        category: 'fresh_veggies',
        quantity: 1,
        unit: UnitType.piece,
        expirationDate: DateTime.now(),
        spoonacularId: 11282,
      );
      expect(withId.toMap()['spoonacularId'], 11282);

      final withoutId = PantryItem(
        id: '2',
        name: 'Grandma\'s special food',
        imageUrl: '',
        category: 'miscellaneous',
        quantity: 1,
        unit: UnitType.piece,
        expirationDate: DateTime.now(),
      );
      expect(withoutId.toMap().containsKey('spoonacularId'), false);
    });

    test('fromMap round-trips spoonacularId', () {
      final map = {
        'name': 'Onion',
        'category': 'fresh_veggies',
        'quantity': '1.0',
        'unit': 'pc',
        'expiryDate': DateTime.now().toIso8601String(),
        'imageUrl': '',
        'isPantryItem': true,
        'spoonacularId': 11282,
      };
      final item = PantryItem.fromMap(map);
      expect(item.spoonacularId, 11282);
    });

    test('fromMap yields null spoonacularId when the field is absent (legacy records)',
        () {
      final map = {
        'name': 'Onion',
        'category': 'fresh_veggies',
        'quantity': '1.0',
        'unit': 'pc',
        'expiryDate': DateTime.now().toIso8601String(),
        'imageUrl': '',
        'isPantryItem': true,
      };
      final item = PantryItem.fromMap(map);
      expect(item.spoonacularId, null);
    });

    test('copyWith preserves spoonacularId when not overridden', () {
      final item = PantryItem(
        id: '1',
        name: 'Onion',
        imageUrl: '',
        category: 'fresh_veggies',
        quantity: 1,
        unit: UnitType.piece,
        expirationDate: DateTime.now(),
        spoonacularId: 11282,
      );
      final copy = item.copyWith(quantity: 2);
      expect(copy.spoonacularId, 11282);
    });
  });
}
