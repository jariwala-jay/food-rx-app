import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

import 'package:flutter_app/features/recipes/models/nutrition.dart';

/// Fetches nutrition for a single ingredient by its verified Spoonacular
/// id -- never by name. Returns null for any failure case, never a
/// [Nutrition] object with zeros, so missing data is never mistaken for
/// "this food has zero sodium".
class SpoonacularIngredientNutritionService {
  static const String _host =
      'spoonacular-recipe-food-nutrition-v1.p.rapidapi.com';
  final String _baseUrl = 'https://$_host';
  final String? _apiKey = dotenv.env['RAPID_API_KEY'];

  /// Injectable for tests (e.g. package:http/testing.dart's MockClient);
  /// defaults to a real client in production.
  final http.Client _client;

  SpoonacularIngredientNutritionService({http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'X-RapidAPI-Key': _apiKey!,
        'X-RapidAPI-Host': _host,
      };

  /// Returns nutrition for [spoonacularId] at the given [amount]/[unit]
  /// (default 100 grams). Returns null with no HTTP request when
  /// [spoonacularId] is null or non-positive; also null for any
  /// network/parsing failure -- callers don't need to distinguish why.
  Future<Nutrition?> getIngredientNutrition(
    int? spoonacularId, {
    double amount = 100,
    String unit = 'grams',
  }) async {
    if (spoonacularId == null || spoonacularId <= 0) {
      developer.log(
          'SpoonacularIngredientNutritionService: no verified id, skipping lookup.');
      return null;
    }
    if (_apiKey == null) {
      developer.log(
          'SpoonacularIngredientNutritionService: RAPID_API_KEY not found.');
      return null;
    }

    final uri = Uri.parse('$_baseUrl/food/ingredients/$spoonacularId/information')
        .replace(queryParameters: {
      'amount': amount.toString(),
      'unit': unit,
    });

    try {
      final response = await _client.get(uri, headers: _headers);
      if (response.statusCode == 429) {
        developer.log(
            'SpoonacularIngredientNutritionService: rate limited (429) for id $spoonacularId.');
        return null;
      }
      if (response.statusCode == 404) {
        developer.log(
            'SpoonacularIngredientNutritionService: id $spoonacularId not found (404).');
        return null;
      }
      if (response.statusCode != 200) {
        developer.log(
            'SpoonacularIngredientNutritionService: unexpected status ${response.statusCode} for id $spoonacularId.');
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic>) {
        developer.log(
            'SpoonacularIngredientNutritionService: unexpected response shape for id $spoonacularId.');
        return null;
      }
      final nutritionJson = decoded['nutrition'];
      if (nutritionJson is! Map<String, dynamic>) {
        developer.log(
            'SpoonacularIngredientNutritionService: no nutrition object in response for id $spoonacularId.');
        return null;
      }
      return Nutrition.fromJson(nutritionJson);
    } catch (e) {
      developer.log(
          'SpoonacularIngredientNutritionService: error fetching id $spoonacularId: $e');
      return null;
    }
  }
}
