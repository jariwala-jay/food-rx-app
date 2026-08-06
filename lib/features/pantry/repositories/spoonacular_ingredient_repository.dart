import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';

class SpoonacularIngredientRepository implements IngredientRepository {
  static const String _host =
      'spoonacular-recipe-food-nutrition-v1.p.rapidapi.com';
  final String _baseUrl = 'https://$_host';
  final String? _apiKey = dotenv.env['RAPID_API_KEY'];
  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;

  Map<String, String> get _headers => {
        'X-RapidAPI-Key': _apiKey!,
        'X-RapidAPI-Host': _host,
      };

  /// Parses each entry independently so one malformed row (missing/odd
  /// fields) doesn't throw away the rest of an otherwise-good batch.
  List<Ingredient> _parseIngredients(List<dynamic> rawResults) {
    final parsed = <Ingredient>[];
    for (final item in rawResults) {
      try {
        parsed.add(Ingredient.fromJson(item as Map<String, dynamic>));
      } catch (e) {
        developer.log('Skipping unparsable ingredient entry: $e');
      }
    }
    return parsed;
  }

  @override
  Future<List<Ingredient>> searchIngredients(
      {String? query,
      String? aisle,
      int number = 100,
      List<String>? intolerances}) async {
    if (_apiKey == null) {
      developer.log('Spoonacular API key not found.');
      return [];
    }

    // Check if we're still rate limited
    if (_isRateLimited && _rateLimitUntil != null) {
      if (DateTime.now().isBefore(_rateLimitUntil!)) {
        developer.log('Still rate limited, skipping API call');
        return [];
      } else {
        // Rate limit period has passed, reset
        _isRateLimited = false;
        _rateLimitUntil = null;
      }
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
    if (intolerances != null && intolerances.isNotEmpty) {
      queryParams['intolerances'] = intolerances.join(',');
    }

    // Use RapidAPI headers (same as recipe repo). Query-param auth alone
    // is unreliable and can fail for free-text search outside category browse.
    final uri = Uri.parse('$_baseUrl/food/ingredients/search')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        // Reset rate limit status on successful request
        _isRateLimited = false;
        _rateLimitUntil = null;

        final data = json.decode(response.body);
        final results = data['results'] as List;
        return _parseIngredients(results);
      } else if (response.statusCode == 429) {
        // Rate limited - set flag and wait 60 seconds before retrying
        _isRateLimited = true;
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 60));
        developer.log(
            'API Error in searchIngredients: ${response.statusCode} - ${response.body}. Rate limited until $_rateLimitUntil');
        return [];
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

    // Don't make autocomplete calls if we're rate limited
    if (_isRateLimited && _rateLimitUntil != null) {
      if (DateTime.now().isBefore(_rateLimitUntil!)) {
        developer.log('Rate limited, skipping autocomplete API call');
        return [];
      } else {
        // Rate limit period has passed, reset
        _isRateLimited = false;
        _rateLimitUntil = null;
      }
    }

    final Map<String, String> queryParams = {
      'query': query,
      'number': number.toString(),
      'metaInformation': 'true',
    };

    final uri = Uri.parse('$_baseUrl/food/ingredients/autocomplete')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        // Reset rate limit status on successful request
        _isRateLimited = false;
        _rateLimitUntil = null;

        final data = json.decode(response.body) as List;
        return _parseIngredients(data);
      } else if (response.statusCode == 429) {
        // Rate limited - set flag and wait 60 seconds before retrying
        _isRateLimited = true;
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 60));
        developer.log(
            'API Error in autocompleteIngredient: ${response.statusCode} - ${response.body}. Rate limited until $_rateLimitUntil');
        return [];
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

  // Check if we're currently rate limited
  bool get isRateLimited {
    if (_isRateLimited && _rateLimitUntil != null) {
      if (DateTime.now().isBefore(_rateLimitUntil!)) {
        return true;
      } else {
        // Rate limit period has passed, reset
        _isRateLimited = false;
        _rateLimitUntil = null;
        return false;
      }
    }
    return false;
  }
}
