import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

class IngredientService {
  final String _baseUrl = 'https://api.spoonacular.com';
  final String? _apiKey = dotenv.env['SPOONACULAR_API_KEY'];

  // Cache of categorized ingredients from CSV
  Map<String, List<Map<String, dynamic>>> _categorizedIngredients = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _loadIngredientsFromCSV();
      _isInitialized = true;
      developer.log(
          'IngredientService initialized successfully with ${_getTotalIngredientCount()} total ingredients');
    } catch (e) {
      developer.log('Error initializing IngredientService: $e');
      _populateWithDemoData(); // Fallback to demo data in case of error
      _isInitialized = true;
    }
  }

  int _getTotalIngredientCount() {
    int total = 0;
    _categorizedIngredients.forEach((key, value) {
      total += value.length;
    });
    return total;
  }

  Future<void> _loadIngredientsFromCSV() async {
    try {
      developer.log('Loading ingredients from CSV...');
      final String csvData =
          await rootBundle.loadString('assets/top-1k-ingredients.csv');
      final List<String> lines = csvData.split('\n');
      developer.log('CSV loaded with ${lines.length} lines');

      _categorizedIngredients = {
        'fresh_fruits': [],
        'canned_fruits': [],
        'fresh_veggies': [],
        'canned_veggies': [],
        'grains': [],
        'protein': [],
        'dairy': [],
        'seasonings': [],
        'oils': [],
        'baking': [],
        'condiments': [],
        'beverages': [],
        'other': [],
      };

      final startIndex = lines[0].contains('name;id') ? 1 : 0;

      int processed = 0;
      for (var i = startIndex; i < lines.length; i++) {
        final line = lines[i];
        if (line.isEmpty) continue;

        final parts = line.split(';');
        if (parts.length < 2) continue;

        final name = parts[0].trim();
        final id = parts[1].trim();

        if (name.isEmpty || id.isEmpty) continue;

        final category = _determineCategory(name);

        _categorizedIngredients[category]!.add({
          'id': id,
          'name': name,
          'image': getIngredientImageUrl(
              '$name.jpg'.toLowerCase().replaceAll(' ', '-')),
        });
        processed++;
      }

      developer.log('Processed $processed ingredients into categories');
    } catch (e) {
      developer.log('Error loading ingredients from CSV: $e');
      rethrow;
    }
  }

  void _populateWithDemoData() {
    developer.log('Populating with demo data');
    _categorizedIngredients = {
      'fresh_fruits': [
        {
          'id': '9003',
          'name': 'Apple',
          'image': getIngredientImageUrl('apple.jpg')
        },
      ],
      'fresh_veggies': [
        {
          'id': '11124',
          'name': 'Carrot',
          'image': getIngredientImageUrl('carrot.jpg')
        },
      ],
    };
  }

  String _determineCategory(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    if (_matchesAny(lowerName, ['apple', 'banana', 'orange'])) {
      return 'fresh_fruits';
    }
    if (_matchesAny(lowerName, ['carrot', 'onion', 'tomato'])) {
      return 'fresh_veggies';
    }
    return 'other';
  }

  bool _matchesAny(String text, List<String> patterns) {
    for (var pattern in patterns) {
      if (text.contains(pattern)) {
        return true;
      }
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> autocompleteIngredient(String query,
      {int number = 10}) async {
    if (query.length <= 3) {
      final allIngredients =
          _categorizedIngredients.values.expand((e) => e).toList();
      final filteredItems = allIngredients
          .where((item) => item['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .take(number)
          .toList();
      if (filteredItems.isNotEmpty) return filteredItems;
    }

    if (_apiKey == null) return [];

    final url = Uri.parse(
        '$_baseUrl/food/ingredients/autocomplete?query=$query&number=$number&apiKey=$_apiKey');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data
          .cast<Map<String, dynamic>>()
          .map((item) => {
                'id': item['id'],
                'name': item['name'],
                'image': getIngredientImageUrl(item['image']),
              })
          .toList();
    } else {
      throw Exception('Failed to fetch autocomplete: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getIngredientsForCategory(
      String categoryKey) async {
    if (!_isInitialized) await initialize();
    return _categorizedIngredients[categoryKey] ?? [];
  }

  static String getIngredientImageUrl(String imageName) {
    if (imageName.isEmpty || imageName.toLowerCase() == 'no-image.jpg') {
      return 'https://spoonacular.com/cdn/ingredients_100x100/no-image.jpg';
    }
    if (imageName.startsWith('http')) return imageName;
    if (imageName.contains('spoonacular.com/cdn/ingredients')) {
      final parts = imageName.split('/');
      imageName = parts.last;
    }
    return 'https://spoonacular.com/cdn/ingredients_100x100/$imageName';
  }
}
