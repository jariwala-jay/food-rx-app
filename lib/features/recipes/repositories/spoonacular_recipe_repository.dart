import 'dart:convert';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

class SpoonacularRecipeRepository {
  final String _baseUrl = 'https://api.spoonacular.com';
  final String? _apiKey = dotenv.env['SPOONACULAR_API_KEY'];

  Future<List<Recipe>> getRecipes(
      RecipeFilter filter, List<String> pantryIngredients) async {
    if (_apiKey == null) {
      developer.log('No API key available, returning demo recipe data');
      return _getDemoRecipes();
    }

    final Map<String, String> queryParams = {
      ...filter.toSpoonacularParams(),
      'includeIngredients': pantryIngredients.join(','),
      'number': '20',
      'addRecipeInformation': 'true',
      'instructionsRequired': 'true',
      'fillIngredients': 'true',
      'sort':
          'min-missing-ingredients', // Prioritize recipes with less missing ingredients
      'sortDirection': 'asc',
    };

    final uri = Uri.parse('$_baseUrl/recipes/complexSearch')
        .replace(queryParameters: {...queryParams, 'apiKey': _apiKey!});

    developer.log('Spoonacular Request URI: $uri',
        name: 'SpoonacularRecipeRepo');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final String jsonString = utf8.decode(response.bodyBytes);
        // developer.log('Spoonacular complexSearch Response: $jsonString',
        //     name: 'RecipeRepo');
        final data = json.decode(jsonString);
        final results = data['results'] as List;
        return results.map((item) => Recipe.fromSearchResult(item)).toList();
      } else {
        developer.log(
            'API Error in complexSearch: ${response.statusCode} - ${response.body}');
        throw Exception(
            'Failed to load recipes (Error: ${response.statusCode}). Please try again later.');
      }
    } catch (e) {
      developer.log('Error in complexSearch: $e');
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
        'image': 'https://spoonacular.com/recipeImages/1-312x231.jpg',
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
