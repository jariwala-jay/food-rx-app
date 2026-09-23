import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_app/features/tracking/widgets/pantry_tracker_logging_modal.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_nutrition_service.dart';
import 'package:flutter_app/core/models/pantry_item.dart';

PantryItem _item({
  required String name,
  int? spoonacularId,
  UnitType unit = UnitType.pound,
}) {
  return PantryItem(
    id: name.toLowerCase().replaceAll(' ', '-'),
    name: name,
    imageUrl: '',
    category: 'meat',
    quantity: 1,
    unit: unit,
    expirationDate: DateTime.now().add(const Duration(days: 5)),
    spoonacularId: spoonacularId,
  );
}

Map<String, dynamic> _nutritionResponse(List<Map<String, dynamic>> nutrients) {
  return {
    'id': 5062,
    'name': 'chicken breast',
    'nutrition': {'nutrients': nutrients, 'ingredients': []},
  };
}

void main() {
  setUpAll(() {
    dotenv.testLoad(mergeWith: {'RAPID_API_KEY': 'test_key'});
  });

  group('spoonacularSafeUnit', () {
    test("'pc' is translated to the full word 'piece'", () {
      expect(spoonacularSafeUnit('pc'), 'piece');
    });

    test('every other unit label passes through unchanged', () {
      for (final unit in ['lb', 'oz', 'gal', 'ml', 'L', 'g', 'kg', 'cup', 'tbsp', 'tsp']) {
        expect(spoonacularSafeUnit(unit), unit);
      }
    });
  });

  group('computeSodiumEnrichmentForLoggedItems', () {
    test('a mapped item with sodium in mg contributes it directly', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_nutritionResponse([
            {'name': 'Sodium', 'amount': 262.0, 'unit': 'mg'},
          ])),
          200,
        );
      });
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: 'Chicken Breast', spoonacularId: 5062);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 226.0)],
        nutritionService: service,
      );

      expect(callCount, 1);
      expect(result.totalSodiumMg, 262.0);
      expect(result.itemsWithoutSodium, isEmpty);
    });

    test('an unmapped item makes no request and is not reported as failed',
        () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: 'Heavy Cream', spoonacularId: null);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 100.0)],
        nutritionService: service,
      );

      expect(callCount, 0,
          reason: 'no verified identity means no lookup is even attempted');
      expect(result.totalSodiumMg, 0.0);
      expect(result.itemsWithoutSodium, isEmpty,
          reason: 'an item that was never attempted is not the same as one '
              'that was attempted and failed');
    });

    test('a fully custom item (no spoonacularId) behaves the same as an unmapped one',
        () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: "Grandma's special food", spoonacularId: null);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 50.0)],
        nutritionService: service,
      );

      expect(callCount, 0);
      expect(result.totalSodiumMg, 0.0);
      expect(result.itemsWithoutSodium, isEmpty);
    });

    test('an API failure for a mapped item does not increment sodium and is reported',
        () async {
      final client = MockClient((request) async => http.Response('error', 500));
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: 'Chicken Breast', spoonacularId: 5062);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 226.0)],
        nutritionService: service,
      );

      expect(result.totalSodiumMg, 0.0);
      expect(result.itemsWithoutSodium, ['Chicken Breast']);
    });

    test('sodium returned in grams is correctly converted to mg', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode(_nutritionResponse([
              {'name': 'Sodium', 'amount': 0.262, 'unit': 'g'},
            ])),
            200,
          ));
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: 'Chicken Breast', spoonacularId: 5062);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 226.0)],
        nutritionService: service,
      );

      expect(result.totalSodiumMg, closeTo(262.0, 0.001));
    });

    test('sodium returned in mcg is correctly converted to mg', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode(_nutritionResponse([
              {'name': 'Sodium', 'amount': 262000.0, 'unit': 'mcg'},
            ])),
            200,
          ));
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(name: 'Chicken Breast', spoonacularId: 5062);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 226.0)],
        nutritionService: service,
      );

      expect(result.totalSodiumMg, closeTo(262.0, 0.001));
    });

    test('the physical consumed amount is what gets sent, not a fixed reference amount',
        () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode(_nutritionResponse([
            {'name': 'Sodium', 'amount': 524.0, 'unit': 'mg'},
          ])),
          200,
        );
      });
      final service = SpoonacularIngredientNutritionService(client: client);
      // 2 servings' worth, already resolved to a physical amount upstream --
      // this function must forward that amount as-is, not substitute a
      // fixed 100g reference.
      final item = _item(name: 'Chicken Breast', spoonacularId: 5062);

      await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 452.0)],
        nutritionService: service,
      );

      expect(capturedUri.queryParameters['amount'], '452.0');
    });

    test('multiple items sum their sodium contributions, mixing mapped and unmapped',
        () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode(_nutritionResponse([
              {'name': 'Sodium', 'amount': 100.0, 'unit': 'mg'},
            ])),
            200,
          ));
      final service = SpoonacularIngredientNutritionService(client: client);
      final chickenBreast = _item(name: 'Chicken Breast', spoonacularId: 5062);
      final blackPepper = _item(name: 'Black Pepper', spoonacularId: 1002030);
      final heavyCream = _item(name: 'Heavy Cream', spoonacularId: null);

      final result = await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [
          MapEntry(chickenBreast, 226.0),
          MapEntry(blackPepper, 5.0),
          MapEntry(heavyCream, 30.0),
        ],
        nutritionService: service,
      );

      expect(result.totalSodiumMg, 200.0); // 100 + 100, heavy cream skipped
      expect(result.itemsWithoutSodium, isEmpty);
    });

    test('a piece-unit item translates to the full word before the request',
        () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode(_nutritionResponse([
            {'name': 'Sodium', 'amount': 262.0, 'unit': 'mg'},
          ])),
          200,
        );
      });
      final service = SpoonacularIngredientNutritionService(client: client);
      final item = _item(
          name: 'Chicken Breast', spoonacularId: 5062, unit: UnitType.piece);

      await computeSodiumEnrichmentForLoggedItems(
        loggedItemsWithPhysicalAmounts: [MapEntry(item, 1.0)],
        nutritionService: service,
      );

      expect(capturedUri.queryParameters['unit'], 'piece');
    });
  });
}
