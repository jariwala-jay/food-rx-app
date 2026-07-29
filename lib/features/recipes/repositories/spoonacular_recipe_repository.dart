import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

const String recipeRateLimitMessage =
    'Recipes are temporarily unavailable. Please try again in a moment.';

class SpoonacularRecipeRepository {
  static const String complexSearchBaseUrl =
      'https://spoonacular-recipe-food-nutrition-v1.p.rapidapi.com/recipes/complexSearch';
  final String? _apiKey = dotenv.env['RAPID_API_KEY'];
  bool _isRateLimited = false;
  DateTime? _rateLimitUntil;

  /// True while a prior 429 cooldown is still in effect.
  bool get isRateLimited {
    if (_isRateLimited && _rateLimitUntil != null) {
      if (DateTime.now().isBefore(_rateLimitUntil!)) return true;
      _isRateLimited = false;
      _rateLimitUntil = null;
    }
    return false;
  }

  /// Builds the same complexSearch URI [getRecipes] will call (for debug summaries).
  static Uri buildComplexSearchUri(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) {
    final queryParams = <String, String>{
      ...filter.toSpoonacularParams(),
      'number': number.toString(),
      'offset': offset.toString(),
      'addRecipeInformation': 'true',
      'instructionsRequired': 'true',
      'fillIngredients': 'true',
      'sort': 'min-missing-ingredients',
      'sortDirection': 'asc',
    };
    if (pantryIngredients.isNotEmpty) {
      queryParams['includeIngredients'] = pantryIngredients.join(',');
    }
    return Uri.parse(complexSearchBaseUrl).replace(queryParameters: queryParams);
  }

  Future<List<Recipe>> getRecipes(
    RecipeFilter filter,
    List<String> pantryIngredients, {
    int number = 100,
    int offset = 0,
  }) async {
    if (_apiKey == null) {
      developer.log('No API key available, returning demo recipe data');
      return _getDemoRecipes();
    }

    // A single generation pass can issue several fallback requests; once one
    // is 429'd, skip the rest of the cooldown window instead of piling on
    // more requests that will just get throttled too.
    if (isRateLimited) {
      developer.log('Still rate limited, skipping complexSearch call');
      throw ApiException(429, recipeRateLimitMessage);
    }

    final uri = buildComplexSearchUri(
      filter,
      pantryIngredients,
      number: number,
      offset: offset,
    );
    final queryParams = Map<String, String>.from(uri.queryParameters);

    final headers = {
      'X-RapidAPI-Key': _apiKey!,
      'X-RapidAPI-Host': 'spoonacular-recipe-food-nutrition-v1.p.rapidapi.com',
    };

    if (kDebugMode) {
      debugPrint('\n🌐 Spoonacular complexSearch request');
      debugPrint('URL: $uri');
      for (final entry in queryParams.entries) {
        debugPrint('  ${entry.key}=${entry.value}');
      }
    } else {
      developer.log('Spoonacular Request URI: $uri',
          name: 'SpoonacularRecipeRepo');
    }

    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        _isRateLimited = false;
        _rateLimitUntil = null;

        final String jsonString = utf8.decode(response.bodyBytes);
        final data = json.decode(jsonString);
        final results = data['results'] as List;

        if (kDebugMode) {
          debugPrint('\n📥 Spoonacular API results (${results.length} recipes):');
          for (final item in results) {
            final map = item as Map<String, dynamic>;
            debugPrint('  [${map['id']}] ${map['title']}');
          }
        }

        return results.map((item) => Recipe.fromSearchResult(item)).toList();
      } else if (response.statusCode == 429) {
        _isRateLimited = true;
        _rateLimitUntil = DateTime.now().add(const Duration(seconds: 60));
        developer.log(
            'API Error in complexSearch: 429 - ${response.body}. Rate limited until $_rateLimitUntil');
        if (kDebugMode) {
          debugPrint('❌ Spoonacular complexSearch rate limited (429)');
        }
        throw ApiException(429, recipeRateLimitMessage);
      } else {
        developer.log(
            'API Error in complexSearch: ${response.statusCode} - ${response.body}');
        if (kDebugMode) {
          debugPrint(
              '❌ Spoonacular complexSearch failed: ${response.statusCode}');
          debugPrint(response.body);
        }
        throw Exception(
            'Failed to load recipes (Error: ${response.statusCode}). Please try again later.');
      }
    } catch (e) {
      developer.log('Error in complexSearch: $e');
      // Preserve typed/HTTP status errors (rate limit, e.g. 405, ...)
      // instead of masking them with a generic connectivity message.
      if (e is ApiException) {
        rethrow;
      }
      if (e is Exception &&
          e.toString().contains('Failed to load recipes (Error:')) {
        rethrow;
      }
      throw Exception(
          'An error occurred while fetching recipes. Please check your connection and try again.');
    }
  }

  Future<List<Recipe>> getSavedRecipes(String userId) {
    // This would be implemented with a database, not Spoonacular
    throw UnimplementedError();
  }

  Future<void> saveRecipe(String userId, Recipe recipe) {
    // This would be implemented with a database
    throw UnimplementedError();
  }

  Future<void> unsaveRecipe(String userId, int recipeId) {
    // This would be implemented with a database
    throw UnimplementedError();
  }

  Future<void> cookRecipe(String userId, Recipe recipe) {
    // This would be implemented with a database
    throw UnimplementedError();
  }

  List<Recipe> _getDemoRecipes() {
    // A simple demo recipe to return on failure
    return [
      Recipe.fromJson({
        'id': 1,
        'title': 'Demo Vegetable Stir Fry',
        'image':
            'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=400&h=300&fit=crop',
        'readyInMinutes': 20,
        'servings': 4,
        'sourceUrl': 'https://example.com/recipe1',
        'summary': 'A delicious and healthy vegetable stir fry.',
        'extendedIngredients': [
          {
            'id': 11124,
            'name': 'carrot',
            'amount': 2.0,
            'unit': 'large',
          },
          {
            'id': 11282,
            'name': 'onion',
            'amount': 1.0,
            'unit': 'medium',
          }
        ],
        'analyzedInstructions': [
          {
            'name': '',
            'steps': [
              {'number': 1, 'step': 'Cook it.'}
            ]
          }
        ],
        'vegetarian': true,
        'vegan': true,
        'glutenFree': true,
        'dairyFree': true,
        'veryHealthy': true,
      })
    ];
  }
}
