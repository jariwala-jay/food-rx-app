import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

class UnitConversionService {
  final String _baseUrl = 'https://api.spoonacular.com';
  final String? _apiKey = dotenv.env['SPOONACULAR_API_KEY'];

  // --- Ratio-based Converters ---

  // Volume conversions (base unit: milliliters)
  static const Map<String, double> _volumeToMl = {
    'cup': 236.588,
    'fluid ounce': 29.5735,
    'tablespoon': 14.7868,
    'teaspoon': 4.92892,
    'ml': 1.0,
    'liter': 1000.0,
    'gallon': 3785.41,
    'quart': 946.353,
    'pint': 473.176,
  };

  // Weight conversions (base unit: grams)
  static const Map<String, double> _weightToGrams = {
    'gram': 1.0,
    'kilogram': 1000.0,
    'ounce': 28.3495,
    'pound': 453.592,
  };

  // --- Ingredient-Specific Density Data (g/mL) ---
  // Source: USDA FoodData Central and other cooking resources.
  static final Map<String, double> _ingredientDensities = {
    // This will be expanded
    'water': 1.0,
    'milk': 1.03,
    'almond milk': 1.03, // Approximation
    'flour': 0.53,
    'sugar': 0.84,
    'butter': 0.91,
    'oil': 0.92,
    'salt': 1.2,
    'rice': 0.85,
    'chicken': 0.7, // Cooked, diced
    'beef': 0.6, // Cooked, ground
    'onion': 0.6,
    'carrot': 0.6,
    'potato': 0.78,
    'tomato': 0.7,
    'cheese': 1.0, // Varies widely, 1.0 is a generic placeholder
    'blackberries': 0.6, // Approximation
  };

  // --- Piece-to-Gram Conversions ---
  static final Map<String, double> _pieceToGrams = {
    'egg': 50.0, // large egg
    'clove of garlic': 3.0,
    'slice of bread': 28.0,
    'bacon slice': 12.0,
  };

  // Direct serving mappings for common ingredients
  static const Map<String, Map<String, double>> _servingConversions = {
    'egg': {
      'piece': 1.0,
      'pieces': 1.0,
      'pc': 1.0,
      'whole': 1.0,
      'large': 1.0,
    },
    'eggs': {
      'piece': 1.0,
      'pieces': 1.0,
      'pc': 1.0,
      'whole': 1.0,
      'large': 1.0,
    },
    'bread': {
      'slice': 1.0,
      'slices': 1.0,
      'piece': 1.0,
      'pieces': 1.0,
    },
    'apple': {
      'piece': 1.0,
      'pieces': 1.0,
      'medium': 1.0,
      'whole': 1.0,
    },
    'banana': {
      'piece': 1.0,
      'pieces': 1.0,
      'medium': 1.0,
      'whole': 1.0,
    },
  };

  /// Normalizes a unit string to a consistent, singular, lowercase format.
  String _normalizeUnit(String unit) {
    String lowerUnit = unit.toLowerCase().trim();

    const Map<String, String> mappings = {
      // Volume
      'cups': 'cup',
      'cup': 'cup',
      'fl oz': 'fluid ounce',
      'fluid ounces': 'fluid ounce',
      'fluid ounce': 'fluid ounce',
      'tablespoons': 'tablespoon',
      'tablespoon': 'tablespoon',
      'tbsp': 'tablespoon',
      'teaspoons': 'teaspoon',
      'teaspoon': 'teaspoon',
      'tsp': 'teaspoon',
      'milliliters': 'ml',
      'milliliter': 'ml',
      'ml': 'ml',
      'liters': 'liter',
      'liter': 'liter',
      'l': 'liter',
      'gallons': 'gallon',
      'gallon': 'gallon',
      'gal': 'gallon',
      'quarts': 'quart',
      'quart': 'quart',
      'pints': 'pint',
      'pint': 'pint',
      // Weight
      'grams': 'gram',
      'gram': 'gram',
      'g': 'gram',
      'kilograms': 'kilogram',
      'kilogram': 'kilogram',
      'kg': 'kilogram',
      'ounces': 'ounce',
      'ounce': 'ounce',
      'oz': 'ounce',
      'pounds': 'pound',
      'pound': 'pound',
      'lbs': 'pound',
      'lb': 'pound',
      // Piece-based
      'piece': 'piece',
      'pieces': 'piece',
      'clove': 'clove',
      'cloves': 'clove',
      'slice': 'slice',
      'slices': 'slice',
      '': 'unit', // Default for empty unit strings
      'unit': 'unit',
      'serving': 'serving',
      'servings': 'serving',
    };
    return mappings[lowerUnit] ?? lowerUnit;
  }

  /// Finds the best matching key in a map for a given ingredient name.
  /// This is more robust than simple `contains`.
  String? _findBestMatch(String ingredientName, Map<String, dynamic> map) {
    final lowerIngredient = ingredientName.toLowerCase();

    // Exact match first
    if (map.containsKey(lowerIngredient)) {
      return lowerIngredient;
    }

    // Then check for keywords
    for (final key in map.keys) {
      if (lowerIngredient.contains(key)) {
        return key;
      }
    }

    return null;
  }

  /// Converts an amount from a source unit to a target unit.
  /// If local conversion fails, tries Spoonacular API as fallback.
  double convert({
    required double amount,
    required String fromUnit,
    required String toUnit,
    String ingredientName = '',
  }) {
    final String normFrom = _normalizeUnit(fromUnit);
    final String normTo = _normalizeUnit(toUnit);

    if (normFrom == normTo) {
      return amount;
    }

    // Handle serving conversions with direct mapping first
    if (normFrom == 'serving' || normFrom == 'servings') {
      final lowerIngredient = ingredientName.toLowerCase();

      // Check direct serving mappings
      for (final ingredient in _servingConversions.keys) {
        if (lowerIngredient.contains(ingredient)) {
          final conversion = _servingConversions[ingredient]?[normTo];
          if (conversion != null) {
            if (kDebugMode) {
              print(
                  '[UnitConversionService] 🎯 Direct serving conversion: $amount $normFrom $ingredientName -> ${amount * conversion} $normTo');
            }
            return amount * conversion;
          }
        }
      }
    }

    // Try standard conversion tables
    final conversionFactor = _getConversionFactor(normFrom, normTo);
    if (conversionFactor != null) {
      return amount * conversionFactor;
    }

    // Try complex conversion logic with density and ingredient-specific conversions
    double? amountInGrams;
    double? amountInMl;

    // --- Step 1: Convert initial amount to a base unit (grams or mL) ---

    // From Volume
    if (_volumeToMl.containsKey(normFrom)) {
      amountInMl = amount * _volumeToMl[normFrom]!;
    }
    // From Weight
    else if (_weightToGrams.containsKey(normFrom)) {
      amountInGrams = amount * _weightToGrams[normFrom]!;
    }
    // From Piece
    else if (normFrom == 'piece' || normFrom == 'unit') {
      final pieceKey = _findBestMatch(ingredientName, _pieceToGrams);
      if (pieceKey != null) {
        amountInGrams = amount * _pieceToGrams[pieceKey]!;
      }
    }

    // --- Step 2: Handle cross-conversions if necessary (e.g., g -> mL) ---
    final densityKey = _findBestMatch(ingredientName, _ingredientDensities);
    final density =
        densityKey != null ? _ingredientDensities[densityKey] : null;

    if (density != null) {
      if (amountInMl != null && amountInGrams == null) {
        // We have mL, can calculate grams
        amountInGrams = amountInMl * density;
      } else if (amountInGrams != null && amountInMl == null) {
        // We have grams, can calculate mL
        amountInMl = amountInGrams / density;
      }
    }

    // --- Step 3: Convert from base unit to target unit ---

    // To Volume
    if (_volumeToMl.containsKey(normTo)) {
      if (amountInMl != null) {
        return amountInMl / _volumeToMl[normTo]!;
      }
    }
    // To Weight
    else if (_weightToGrams.containsKey(normTo)) {
      if (amountInGrams != null) {
        return amountInGrams / _weightToGrams[normTo]!;
      }
    }
    // To Piece
    else if (normTo == 'piece' || normTo == 'unit') {
      final pieceKey = _findBestMatch(ingredientName, _pieceToGrams);
      if (pieceKey != null && amountInGrams != null) {
        return amountInGrams / _pieceToGrams[pieceKey]!;
      }
    }

    // Skip Spoonacular API for nonsensical conversions
    if (normFrom == 'serving' || normTo == 'serving') {
      // Don't try to convert arbitrary ingredients from/to servings
      // This often doesn't make sense (e.g., "serving of salt" to "ounces")
      if (ingredientName.isNotEmpty) {
        final lowerIngredient = ingredientName.toLowerCase();
        final servingMakesSense = [
          'egg',
          'bread',
          'slice',
          'piece',
          'apple',
          'banana',
          'orange',
          'chicken breast',
          'fish fillet',
        ].any((item) => lowerIngredient.contains(item));

        if (!servingMakesSense) {
          if (kDebugMode) {
            print(
                '[UnitConversionService] ⚠️ Skipping nonsensical serving conversion: $amount $normFrom $ingredientName to $normTo');
          }
          return amount; // Return original amount as fallback
        }
      }
    }

    if (kDebugMode) {
      print(
          '[UnitConversionService] ⚠️ UnitConversionService: Cannot convert $amount from "$fromUnit" to "$toUnit" for ingredient "$ingredientName". No valid conversion path found.');
    }
    return amount; // Return original amount as fallback
  }

  /// Get direct conversion factor between two units if available
  double? _getConversionFactor(String fromUnit, String toUnit) {
    // Volume to volume
    if (_volumeToMl.containsKey(fromUnit) && _volumeToMl.containsKey(toUnit)) {
      return _volumeToMl[fromUnit]! / _volumeToMl[toUnit]!;
    }

    // Weight to weight
    if (_weightToGrams.containsKey(fromUnit) &&
        _weightToGrams.containsKey(toUnit)) {
      return _weightToGrams[fromUnit]! / _weightToGrams[toUnit]!;
    }

    return null;
  }

  /// Async version of convert that can use Spoonacular API
  Future<double> convertAsync({
    required double amount,
    required String fromUnit,
    required String toUnit,
    String ingredientName = '',
  }) async {
    // First try local conversion
    final localResult = convert(
      amount: amount,
      fromUnit: fromUnit,
      toUnit: toUnit,
      ingredientName: ingredientName,
    );

    // If local conversion worked (result is different from input or units are the same)
    final String normFrom = _normalizeUnit(fromUnit);
    final String normTo = _normalizeUnit(toUnit);

    if (normFrom == normTo || localResult != amount) {
      return localResult;
    }

    // Try Spoonacular API as fallback
    if (ingredientName.isNotEmpty && _apiKey != null) {
      final apiResult = await _trySpoonacularConversion(
        ingredientName: ingredientName,
        sourceAmount: amount,
        sourceUnit: fromUnit,
        targetUnit: toUnit,
      );

      if (apiResult != null) {
        return apiResult;
      }
    }

    // Return original amount if all else fails
    return amount;
  }

  /// Try Spoonacular API conversion (async version)
  Future<double?> _trySpoonacularConversion({
    required String ingredientName,
    required double sourceAmount,
    required String sourceUnit,
    required String targetUnit,
  }) async {
    if (_apiKey == null) return null;

    try {
      final uri = Uri.parse('$_baseUrl/recipes/convert').replace(
        queryParameters: {
          'ingredientName': ingredientName,
          'sourceAmount': sourceAmount.toString(),
          'sourceUnit': sourceUnit,
          'targetUnit': targetUnit,
          'apiKey': _apiKey!,
        },
      );

      developer.log(
        'Trying Spoonacular conversion: $sourceAmount $sourceUnit $ingredientName to $targetUnit',
        name: 'UnitConversionService',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final targetAmount = data['targetAmount'];

        if (targetAmount != null) {
          final convertedAmount = (targetAmount is num)
              ? targetAmount.toDouble()
              : double.tryParse(targetAmount.toString());

          if (convertedAmount != null) {
            developer.log(
              '✅ Spoonacular conversion successful: $sourceAmount $sourceUnit -> $convertedAmount $targetUnit',
              name: 'UnitConversionService',
            );
            return convertedAmount;
          }
        }
      } else {
        developer.log(
          'Spoonacular API error: ${response.statusCode} - ${response.body}',
          name: 'UnitConversionService',
        );
      }
    } catch (e) {
      developer.log(
        'Spoonacular conversion failed: $e',
        name: 'UnitConversionService',
      );
    }

    return null;
  }

  /// Fire-and-forget async call for logging purposes
  void _trySpoonacularConversionAsync({
    required String ingredientName,
    required double sourceAmount,
    required String sourceUnit,
    required String targetUnit,
  }) {
    // Fire and forget - just for logging what would be possible with API
    _trySpoonacularConversion(
      ingredientName: ingredientName,
      sourceAmount: sourceAmount,
      sourceUnit: sourceUnit,
      targetUnit: targetUnit,
    ).then((result) {
      if (result != null) {
        developer.log(
          '💡 Spoonacular API could convert: $sourceAmount $sourceUnit $ingredientName -> $result $targetUnit',
          name: 'UnitConversionService',
        );
      }
    }).catchError((e) {
      // Ignore errors in fire-and-forget call
    });
  }
}
