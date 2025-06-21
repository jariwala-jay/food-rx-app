import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';

class SpoonacularIngredientRepository implements IngredientRepository {
  final String _baseUrl = 'https://api.spoonacular.com';
  final String? _apiKey = dotenv.env['SPOONACULAR_API_KEY'];

  @override
  Future<List<Ingredient>> searchIngredients(
      {String? query, String? aisle, int number = 100}) async {
    if (_apiKey == null) {
      developer.log('Spoonacular API key not found.');
      return [];
    }

    final Map<String, String> queryParams = {
      'number': number.toString(),
    };
    if (query != null && query.isNotEmpty) {
      queryParams['query'] = query;
    }
    if (aisle != null && aisle.isNotEmpty) {
      queryParams['aisle'] = aisle;
    }

    final uri = Uri.parse('$_baseUrl/food/ingredients/search')
        .replace(queryParameters: {...queryParams, 'apiKey': _apiKey!});

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        return results.map((item) => Ingredient.fromJson(item)).toList();
      } else {
        developer.log(
            'API Error in searchIngredients: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      developer.log('Error in searchIngredients: $e');
      return [];
    }
  }

  @override
  Future<List<Ingredient>> autocompleteIngredient(
      {required String query, int number = 10}) async {
    if (_apiKey == null) {
      developer.log('Spoonacular API key not found.');
      return [];
    }

    final Map<String, String> queryParams = {
      'query': query,
      'number': number.toString(),
      'metaInformation': 'true',
    };

    final uri = Uri.parse('$_baseUrl/food/ingredients/autocomplete')
        .replace(queryParameters: {...queryParams, 'apiKey': _apiKey!});

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        return data.map((item) => Ingredient.fromJson(item)).toList();
      } else {
        developer.log(
            'API Error in autocompleteIngredient: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      developer.log('Error in autocompleteIngredient: $e');
      return [];
    }
  }
}
