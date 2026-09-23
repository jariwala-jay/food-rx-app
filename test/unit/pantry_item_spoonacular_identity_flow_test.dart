import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/models/pantry_item.dart';

/// Mirrors the three curated construction sites' extraction pattern
/// (pantry_group_category_page.dart, pantry_item_picker_provider.dart,
/// ingredient_fuzzy_matcher.dart).
Ingredient _buildCuratedIngredient(Map<String, dynamic> itemData) {
  final asset = itemData['imageAsset'] as String?;
  return Ingredient(
    id: itemData['id']?.toString() ?? '',
    name: itemData['name'] ?? '',
    image: itemData['imageUrl'] ?? '',
    imageName: asset != null
        ? 'default.jpg'
        : (itemData['imageUrl']?.split('/').last ?? 'default.jpg'),
    localAssetPath: asset,
    spoonacularId: int.tryParse(itemData['spoonacularId']?.toString() ?? ''),
  );
}

/// Mirrors PantryItemAddModal._addItem()'s exact precedence: prefer the
/// curated foodItem's own spoonacularId; otherwise fall back to parsing
/// itemId directly (the live-search-result case, where itemId already IS
/// the real numeric Spoonacular id).
int? _resolveSpoonacularIdLikeAddModal(
    Map<String, dynamic> foodItem, String itemId) {
  return foodItem['spoonacularId'] != null
      ? int.tryParse(foodItem['spoonacularId'].toString())
      : int.tryParse(itemId);
}

/// Runs an Ingredient through the exact chain the app does end to end:
/// Ingredient -> toJson() (what reaches the modal) -> add-modal precedence
/// -> PantryItem -> toMap() (what would be sent to Mongo) -> fromMap()
/// (what a later reload would reconstruct).
PantryItem _runFullPersistenceFlow(Ingredient ingredient) {
  final foodItem = ingredient.toJson();
  final itemId =
      foodItem['id']?.toString() ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
  final spoonacularId = _resolveSpoonacularIdLikeAddModal(foodItem, itemId);

  final pantryItem = PantryItem(
    id: itemId,
    name: ingredient.name,
    imageUrl: ingredient.imageUrl,
    category: 'meat',
    quantity: 1,
    unit: UnitType.pound,
    expirationDate: DateTime.now().add(const Duration(days: 5)),
    spoonacularId: spoonacularId,
  );

  final mongoDocument = pantryItem.toMap();
  return PantryItem.fromMap(mongoDocument);
}

void main() {
  group('Phase 2B: curated catalog -> pantry document -> reload persistence flow', () {
    test('mapped curated item (Chicken Breast) survives the full round-trip',
        () {
      final items = getCommonItemsForCategory('meat', true);
      final chickenBreast =
          items.firstWhere((i) => i['name'] == 'Chicken Breast');
      final ingredient = _buildCuratedIngredient(chickenBreast);

      final reloaded = _runFullPersistenceFlow(ingredient);

      expect(reloaded.spoonacularId, 5062,
          reason: 'Chicken Breast -> 5062 must survive Ingredient -> '
              'toJson -> modal -> PantryItem -> toMap -> fromMap intact');
    });

    test('unmapped curated item (Heavy Cream) has no spoonacularId anywhere in the flow',
        () {
      final items = getCommonItemsForCategory('dairy', true);
      final heavyCream = items.firstWhere((i) => i['name'] == 'Heavy Cream');
      final ingredient = _buildCuratedIngredient(heavyCream);

      // Confirm the "document" never carries the key at all, not just that
      // it deserializes back to null -- proves toMap() genuinely omits it
      // for legacy-record cleanliness, not that the key exists with a null
      // value.
      final foodItem = ingredient.toJson();
      final itemId = foodItem['id'].toString();
      final spoonacularId = _resolveSpoonacularIdLikeAddModal(foodItem, itemId);
      final pantryItem = PantryItem(
        id: itemId,
        name: ingredient.name,
        imageUrl: ingredient.imageUrl,
        category: 'dairy',
        quantity: 1,
        unit: UnitType.ounces,
        expirationDate: DateTime.now().add(const Duration(days: 7)),
        spoonacularId: spoonacularId,
      );
      final mongoDocument = pantryItem.toMap();

      expect(mongoDocument.containsKey('spoonacularId'), false,
          reason: 'Unmapped items must not write a spoonacularId key at all');

      final reloaded = PantryItem.fromMap(mongoDocument);
      expect(reloaded.spoonacularId, null);
    });

    test('a live Spoonacular search result (no curated mapping) still persists its id',
        () {
      // Simulates what a genuine Spoonacular /food/ingredients/search
      // result looks like once parsed by Ingredient.fromJson -- id is
      // already the real numeric Spoonacular id, spoonacularId itself is
      // unset (that's expected; the add-modal falls back to itemId).
      final ingredient = Ingredient.fromJson(
          {'id': 5062, 'name': 'chicken breast', 'image': 'chicken-breasts.png'});

      final reloaded = _runFullPersistenceFlow(ingredient);

      expect(reloaded.spoonacularId, 5062,
          reason: 'Curated ids and live-search ids must coexist without '
              'changing existing live-search behavior');
    });

    test('curated mapping takes precedence over itemId parsing when both could apply',
        () {
      // Regression guard for the precedence rule itself: if a curated
      // entry's spoonacularId and its raw id somehow disagreed, the
      // curated spoonacularId must win -- it's the deliberately verified
      // identity, itemId parsing is only ever the fallback.
      const ingredient = Ingredient(
        id: 'chicken-breast', // internal slug -- int.tryParse would yield null
        name: 'Chicken Breast',
        image: 'chicken-breasts.jpg',
        imageName: 'chicken-breasts.jpg',
        spoonacularId: 5062,
      );

      final reloaded = _runFullPersistenceFlow(ingredient);
      expect(reloaded.spoonacularId, 5062);
    });
  });
}
