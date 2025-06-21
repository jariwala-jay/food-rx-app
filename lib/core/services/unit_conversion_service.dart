import 'package:flutter/foundation.dart';

class UnitConversionService {
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

    // If conversion is not possible, log it and return original amount
    if (kDebugMode) {
      print(
          '⚠️ UnitConversionService: Cannot convert $amount from "$fromUnit" to "$toUnit" for ingredient "$ingredientName". No valid conversion path found.');
    }
    return amount;
  }
}
