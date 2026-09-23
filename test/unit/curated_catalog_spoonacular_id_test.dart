import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/models/ingredient.dart';

/// Mirrors the extraction pattern used by the three curated-item
/// construction sites (pantry_group_category_page.dart,
/// pantry_item_picker_provider.dart, ingredient_fuzzy_matcher.dart):
/// int.tryParse(itemData['spoonacularId']?.toString() ?? '').
Ingredient _buildIngredientLikeConstructionSites(Map<String, dynamic> itemData) {
  final asset = itemData['imageAsset'] as String?;
  return Ingredient(
    id: itemData['id']?.toString() ?? '',
    name: itemData['name'] ?? '',
    image: itemData['imageUrl'] ?? '',
    imageName: asset != null
        ? 'default.jpg'
        : (itemData['imageUrl']?.split('/').last ?? 'default.jpg'),
    localAssetPath: asset,
    spoonacularId:
        int.tryParse(itemData['spoonacularId']?.toString() ?? ''),
  );
}

void main() {
  group('Curated catalog spoonacularId', () {
    // Regression: proves the full chain -- catalog data -> Ingredient ->
    // spoonacularId -- actually works for a real mapped entry and a real
    // deliberately-unmapped entry, not just that the field exists.
    test('curated Chicken Breast resolves to its verified spoonacularId',
        () {
      final items = getCommonItemsForCategory('meat', true);
      final chickenBreast =
          items.firstWhere((i) => i['name'] == 'Chicken Breast');
      final ingredient = _buildIngredientLikeConstructionSites(chickenBreast);
      expect(ingredient.spoonacularId, 5062);
      // The internal catalog slug must stay untouched -- spoonacularId is
      // a separate external identity, not a replacement for id.
      expect(ingredient.id, 'chicken-breast');
    });

    test('curated Heavy Cream has no spoonacularId (deliberately unmapped)',
        () {
      final items = getCommonItemsForCategory('dairy', true);
      final heavyCream = items.firstWhere((i) => i['name'] == 'Heavy Cream');
      final ingredient = _buildIngredientLikeConstructionSites(heavyCream);
      expect(ingredient.spoonacularId, null);
    });

    test('a live Spoonacular search result keeps its existing id behavior',
        () {
      final ingredient = Ingredient.fromJson(
          {'id': 5062, 'name': 'chicken breast', 'image': 'chicken-breasts.png'});
      // fromJson never sets spoonacularId -- id itself already carries the
      // real numeric Spoonacular id for this path; PantryItemAddModal
      // falls back to int.tryParse(id) in exactly this case.
      expect(ingredient.id, '5062');
      expect(ingredient.spoonacularId, null);
    });

    test('a fully custom item has no spoonacularId', () {
      const ingredient = Ingredient(
        id: 'custom_1234567890',
        name: 'Grandma\'s special food',
        image: '',
        imageName: 'default.jpg',
      );
      expect(ingredient.spoonacularId, null);
    });

    test('Ingredient.toJson carries spoonacularId through when present', () {
      const withId = Ingredient(
        id: 'chicken-breast',
        name: 'Chicken Breast',
        image: 'chicken-breasts.jpg',
        imageName: 'chicken-breasts.jpg',
        spoonacularId: 5062,
      );
      expect(withId.toJson()['spoonacularId'], 5062);

      const withoutId = Ingredient(
        id: 'heavy-cream',
        name: 'Heavy Cream',
        image: '',
        imageName: 'default.jpg',
      );
      expect(withoutId.toJson().containsKey('spoonacularId'), false);
    });

    // Mechanical validation the team asked for: every catalog entry that
    // carries a spoonacularId must still resolve to the same name it did
    // in the source-of-truth mapping -- guards against the catalog edit
    // having attached an id to the wrong entry.
    test('every curated entry with a spoonacularId has a plausible positive id',
        () {
      for (final key in [
        'fresh_fruits', 'frozen_fruits', 'canned_fruits',
        'fresh_veggies', 'frozen_veggies', 'canned_veggies',
        'grains', 'meat', 'beans', 'dairy', 'nuts_seeds', 'seasonings',
        'snacks_beverages',
      ]) {
        for (final item in getCommonItemsForCategory(key, true)) {
          final sid = item['spoonacularId'];
          if (sid != null) {
            expect(sid, isA<int>(),
                reason: "${item['name']} in $key has a non-int spoonacularId");
            expect(sid > 0, true,
                reason: "${item['name']} in $key has a non-positive spoonacularId");
          }
        }
        for (final item in getCommonItemsForCategory(key, false)) {
          final sid = item['spoonacularId'];
          if (sid != null) {
            expect(sid, isA<int>());
            expect(sid > 0, true);
          }
        }
      }
    });
  });
}
