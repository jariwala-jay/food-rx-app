import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_nutrition_service.dart';
import 'package:flutter_app/core/utils/nutrient_unit_converter.dart';
import 'package:flutter_app/features/recipes/models/nutrition.dart';

Map<String, dynamic> _fakeInformationResponse({
  required int id,
  List<Map<String, dynamic>> nutrients = const [],
}) {
  return {
    'id': id,
    'name': 'chicken breast',
    'nutrition': {
      'nutrients': nutrients,
      'ingredients': [],
    },
  };
}

void main() {
  setUpAll(() {
    // Matches the exact mechanism flutter_dotenv provides for tests --
    // avoids depending on a real .env file being loaded, and avoids
    // silently short-circuiting every test at the "no API key" guard.
    dotenv.testLoad(mergeWith: {'RAPID_API_KEY': 'test_key'});
  });

  group('SpoonacularIngredientNutritionService', () {
    test('a valid id makes exactly one request and parses nutrition', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode(_fakeInformationResponse(id: 5062, nutrients: [
            {'name': 'Sodium', 'amount': 45.0, 'unit': 'mg'},
          ])),
          200,
        );
      });
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(5062);

      expect(callCount, 1);
      expect(nutrition, isNotNull);
      expect(findNutrient(nutrition!, 'Sodium')?.amount, 45.0);
    });

    // Architectural guard: protects the "identity comes from the verified
    // id, never a name search" rule the whole investigation established.
    test('the request URL contains the id and never the food name', () async {
      late Uri capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(jsonEncode(_fakeInformationResponse(id: 5062)), 200);
      });
      final service = SpoonacularIngredientNutritionService(client: client);

      await service.getIngredientNutrition(5062);

      expect(capturedUri.path.contains('5062'), true);
      expect(capturedUri.toString().contains('query='), false);
      expect(capturedUri.toString().toLowerCase().contains('chicken'), false);
    });

    test('sodium parses correctly for a known id', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode(_fakeInformationResponse(id: 1002030, nutrients: [
              {'name': 'Sodium', 'amount': 20.0, 'unit': 'mg'},
              {'name': 'Calories', 'amount': 251.0, 'unit': 'kcal'},
            ])),
            200,
          ));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(1002030);

      final sodium = findNutrient(nutrition!, 'Sodium');
      expect(sodium, isNotNull);
      expect(sodium!.amount, 20.0);
      expect(sodium.unit, 'mg');
    });

    test('a null id makes no HTTP request at all', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(null);

      expect(callCount, 0,
          reason: 'a null id means "no verified identity" -- must never '
              'trigger a lookup of any kind');
      expect(nutrition, null);
    });

    test('a non-positive id makes no HTTP request', () async {
      int callCount = 0;
      final client = MockClient((request) async {
        callCount++;
        return http.Response('{}', 200);
      });
      final service = SpoonacularIngredientNutritionService(client: client);

      final resultZero = await service.getIngredientNutrition(0);
      final resultNegative = await service.getIngredientNutrition(-5);

      expect(callCount, 0);
      expect(resultZero, null);
      expect(resultNegative, null);
    });

    test('a 404 response fails gracefully, not as an exception', () async {
      final client = MockClient((request) async => http.Response('Not Found', 404));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(999999999);

      expect(nutrition, null);
    });

    test('a 429 response fails gracefully, not as an exception', () async {
      final client = MockClient((request) async =>
          http.Response('{"message":"rate limited"}', 429));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(5062);

      expect(nutrition, null);
    });

    test('a malformed/missing nutrition object does not crash', () async {
      final client = MockClient((request) async => http.Response(
            jsonEncode({'id': 5062, 'name': 'chicken breast'}), // no 'nutrition' key
            200,
          ));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(5062);

      expect(nutrition, null);
    });

    test('unparseable JSON body does not crash', () async {
      final client = MockClient((request) async => http.Response('not json at all', 200));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(5062);

      expect(nutrition, null);
    });

    test('a network exception does not crash and returns null', () async {
      final client = MockClient((request) async => throw Exception('network down'));
      final service = SpoonacularIngredientNutritionService(client: client);

      final nutrition = await service.getIngredientNutrition(5062);

      expect(nutrition, null);
    });
  });

  group('nutrientAmountInMg', () {
    test('mg values are returned unchanged', () {
      final n = _fakeNutrient(amount: 800, unit: 'mg');
      expect(nutrientAmountInMg(n), 800);
    });

    test('g values are converted to mg (x1000)', () {
      final n = _fakeNutrient(amount: 0.8, unit: 'g');
      expect(nutrientAmountInMg(n), 800);
    });

    test('mcg values are converted to mg (/1000)', () {
      final n = _fakeNutrient(amount: 800000, unit: 'mcg');
      expect(nutrientAmountInMg(n), 800);
    });

    test('the micro sign (μg) unit is treated the same as mcg', () {
      final n = _fakeNutrient(amount: 800000, unit: 'μg');
      expect(nutrientAmountInMg(n), 800);
    });

    test('unit matching is case-insensitive', () {
      final n = _fakeNutrient(amount: 0.8, unit: 'G');
      expect(nutrientAmountInMg(n), 800);
    });
  });
}

Nutrient _fakeNutrient({required double amount, required String unit}) {
  return Nutrient(name: 'Sodium', amount: amount, unit: unit);
}
