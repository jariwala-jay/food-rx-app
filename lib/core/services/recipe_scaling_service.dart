import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

/// Recipe Scaling Service for Food Rx
/// Provides intelligent recipe scaling with confidence scoring
/// Integrates with Spoonacular recipe format and UnitConversionService
class RecipeScalingService {
  final UnitConversionService _conversionService;

  RecipeScalingService({required UnitConversionService conversionService})
      : _conversionService = conversionService;

  /// Scales a complete recipe from Spoonacular format to target servings
  /// Returns scaled recipe data with confidence metrics
  Map<String, dynamic> scaleRecipe({
    required Map<String, dynamic> originalRecipe,
    required int targetServings,
  }) {
    final originalServings = (originalRecipe['servings'] ?? 1.0) as num;
    final scaleFactor = targetServings / originalServings.toDouble();
    
    if (kDebugMode) {
      print('🍽️ Scaling recipe "${originalRecipe['title']}" from $originalServings to $targetServings servings (factor: ${scaleFactor.toStringAsFixed(3)})');
    }

    // Scale the extended ingredients
    final originalIngredients = originalRecipe['extendedIngredients'] as List<dynamic>;
    final scalingResults = scaleExtendedIngredients(
      extendedIngredients: originalIngredients,
      scaleFactor: scaleFactor,
    );

    // Calculate overall confidence
    final overallConfidence = _calculateOverallConfidence(scalingResults['ingredients']);
    
    // Create scaled recipe
    final scaledRecipe = Map<String, dynamic>.from(originalRecipe);
    scaledRecipe['servings'] = targetServings;
    scaledRecipe['extendedIngredients'] = scalingResults['ingredients'];
    scaledRecipe['scalingMetadata'] = {
      'originalServings': originalServings,
      'targetServings': targetServings,
      'scaleFactor': scaleFactor,
      'overallConfidence': overallConfidence,
      'scaledAt': DateTime.now().toIso8601String(),
      'conversionSummary': scalingResults['summary'],
    };

    if (kDebugMode) {
      print('✅ Recipe scaled with ${overallConfidence.toStringAsFixed(1)}% confidence');
    }

    return scaledRecipe;
  }

  /// Scales a list of Spoonacular extendedIngredients
  /// Returns detailed scaling results with confidence metrics
  Map<String, dynamic> scaleExtendedIngredients({
    required List<dynamic> extendedIngredients,
    required double scaleFactor,
  }) {
    final scaledIngredients = <Map<String, dynamic>>[];
    final conversionSummary = {
      'totalIngredients': extendedIngredients.length,
      'highConfidence': 0,
      'mediumConfidence': 0,
      'lowConfidence': 0,
      'failed': 0,
      'seasoningsAdjusted': 0,
    };

    for (final ingredient in extendedIngredients) {
      final scaledIngredient = _scaleIndividualIngredient(
        ingredient: ingredient as Map<String, dynamic>,
        scaleFactor: scaleFactor,
      );
      
      scaledIngredients.add(scaledIngredient);
      
      // Update summary statistics
      final confidence = scaledIngredient['scalingMetadata']['confidence'] as double;
      if (confidence >= 0.95) {
        conversionSummary['highConfidence'] = conversionSummary['highConfidence']! + 1;
      } else if (confidence >= 0.85) {
        conversionSummary['mediumConfidence'] = conversionSummary['mediumConfidence']! + 1;
      } else if (confidence > 0.0) {
        conversionSummary['lowConfidence'] = conversionSummary['lowConfidence']! + 1;
      } else {
        conversionSummary['failed'] = conversionSummary['failed']! + 1;
      }
      
      if (scaledIngredient['scalingMetadata']['seasoningAdjusted'] == true) {
        conversionSummary['seasoningsAdjusted'] = conversionSummary['seasoningsAdjusted']! + 1;
      }
    }

    return {
      'ingredients': scaledIngredients,
      'summary': conversionSummary,
    };
  }

  /// Scales an individual Spoonacular ingredient with intelligent unit optimization
  Map<String, dynamic> _scaleIndividualIngredient({
    required Map<String, dynamic> ingredient,
    required double scaleFactor,
  }) {
    final name = ingredient['name'] ?? ingredient['nameClean'] ?? '';
    final originalAmount = (ingredient['amount'] ?? 0.0) as double;
    final originalUnit = ingredient['unit'] ?? '';
    
    // Handle zero amounts (but not empty units - those should still be scaled)
    if (originalAmount == 0.0) {
      final scaledIngredient = Map<String, dynamic>.from(ingredient);
      scaledIngredient['scalingMetadata'] = {
        'originalAmount': originalAmount,
        'originalUnit': originalUnit,
        'scaleFactor': scaleFactor,
        'confidence': 0.0,
        'conversionPath': 'zero_amount',
        'seasoningAdjusted': false,
        'optimized': false,
      };
      return scaledIngredient;
    }

    // Check if this is a seasoning/spice that should be scaled differently
    final isSeasoningOrSpice = _isSeasoningOrSpice(name);
    final adjustedScaleFactor = isSeasoningOrSpice && scaleFactor > 2.0 
        ? 1.0 + (scaleFactor - 1.0) * 0.5  // Reduce scaling for seasonings
        : scaleFactor;

    // Scale the amount
    final scaledAmount = originalAmount * adjustedScaleFactor;
    
    // Optimize units for readability (always optimize, even for empty units)
    final optimized = _conversionService.optimizeUnits(scaledAmount, originalUnit);
    final finalAmount = optimized['amount'] as double;
    final finalUnit = optimized['unit'] as String;
    
    // Create scaled ingredient
    final scaledIngredient = Map<String, dynamic>.from(ingredient);
    scaledIngredient['amount'] = finalAmount;
    scaledIngredient['unit'] = finalUnit;
    
    // Update measures if they exist
    if (ingredient.containsKey('measures')) {
      scaledIngredient['measures'] = _scaleMeasures(
        originalMeasures: ingredient['measures'] as Map<String, dynamic>,
        originalAmount: originalAmount,
        finalAmount: finalAmount,
        finalUnit: finalUnit,
      );
    }
    
    // Add scaling metadata
    scaledIngredient['scalingMetadata'] = {
      'originalAmount': originalAmount,
      'originalUnit': originalUnit,
      'scaleFactor': adjustedScaleFactor,
      'confidence': 0.95, // High confidence for direct scaling
      'conversionPath': 'direct_scaling',
      'seasoningAdjusted': isSeasoningOrSpice && scaleFactor > 2.0,
      'optimized': finalUnit != originalUnit,
    };

    return scaledIngredient;
  }

  /// Updates the measures object in Spoonacular format
  Map<String, dynamic> _scaleMeasures({
    required Map<String, dynamic> originalMeasures,
    required double originalAmount,
    required double finalAmount,
    required String finalUnit,
  }) {
    final scaledMeasures = Map<String, dynamic>.from(originalMeasures);
    
    // Update US measures
    if (scaledMeasures.containsKey('us')) {
      final usMeasures = Map<String, dynamic>.from(scaledMeasures['us']);
      usMeasures['amount'] = finalAmount;
      usMeasures['unitShort'] = _getShortUnit(finalUnit, finalAmount);
      usMeasures['unitLong'] = _getLongUnit(finalUnit, finalAmount);
      scaledMeasures['us'] = usMeasures;
    }
    
    // Update metric measures
    if (scaledMeasures.containsKey('metric')) {
      final metricMeasures = Map<String, dynamic>.from(scaledMeasures['metric']);
      
      // Try to convert to metric if we have a US unit
      final metricResult = _conversionService.convertWithConfidence(
        amount: finalAmount,
        fromUnit: finalUnit,
        toUnit: _getMetricEquivalent(finalUnit),
        ingredientName: '',
      );
      
      if (metricResult['confidence'] > 0.0) {
        final metricAmount = metricResult['amount'] as double;
        metricMeasures['amount'] = metricAmount;
        metricMeasures['unitShort'] = _getShortUnit(_getMetricEquivalent(finalUnit), metricAmount);
        metricMeasures['unitLong'] = _getLongUnit(_getMetricEquivalent(finalUnit), metricAmount);
      } else {
        // Fallback to same unit
        metricMeasures['amount'] = finalAmount;
        metricMeasures['unitShort'] = _getShortUnit(finalUnit, finalAmount);
        metricMeasures['unitLong'] = _getLongUnit(finalUnit, finalAmount);
      }
      
      scaledMeasures['metric'] = metricMeasures;
    }
    
    return scaledMeasures;
  }

  /// Checks if an ingredient is a seasoning or spice
  bool _isSeasoningOrSpice(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    final seasonings = [
      'salt', 'pepper', 'paprika', 'cumin', 'oregano', 'basil', 'thyme', 
      'rosemary', 'cinnamon', 'nutmeg', 'ginger', 'turmeric', 'chili powder',
      'garlic powder', 'onion powder', 'bay leaf', 'parsley', 'cilantro',
      'dill', 'sage', 'marjoram', 'tarragon', 'mint', 'cardamom', 'cloves',
      'allspice', 'fennel', 'coriander', 'mustard seed', 'celery seed',
      'caraway', 'anise', 'vanilla', 'extract', 'seasoning', 'spice',
      'herb', 'powder', 'dried', 'ground', 'coffee', 'instant coffee'
    ];
    
    return seasonings.any((seasoning) => lowerName.contains(seasoning));
  }

  /// Calculates overall confidence for a list of scaled ingredients
  double _calculateOverallConfidence(List<Map<String, dynamic>> ingredients) {
    if (ingredients.isEmpty) return 0.0;
    
    double totalConfidence = 0.0;
    int validIngredients = 0;
    
    for (final ingredient in ingredients) {
      if (ingredient.containsKey('scalingMetadata')) {
        final confidence = ingredient['scalingMetadata']['confidence'] as double;
        totalConfidence += confidence;
        validIngredients++;
      }
    }
    
    return validIngredients > 0 ? (totalConfidence / validIngredients) * 100 : 0.0;
  }

  /// Gets the short unit format for Spoonacular
  String _getShortUnit(String unit, [double amount = 1.0]) {
    final lowerUnit = unit.toLowerCase();
    
    // Handle pluralization for short units
    if (amount == 1.0) {
      const singularShortUnits = {
        'teaspoon': 'tsp',
        'teaspoons': 'tsp',
        'tablespoon': 'Tbsp',
        'tablespoons': 'Tbsp',
        'cup': 'cup',
        'cups': 'cup',
        'ounce': 'oz',
        'ounces': 'oz',
        'pound': 'lb',
        'pounds': 'lb',
        'gram': 'g',
        'grams': 'g',
        'kilogram': 'kg',
        'kilograms': 'kg',
        'milliliter': 'ml',
        'milliliters': 'ml',
        'liter': 'l',
        'liters': 'l',
        'fluid ounce': 'fl. oz',
        'fluid ounces': 'fl. oz',
        'quart': 'qt',
        'quarts': 'qt',
        'pint': 'pt',
        'pints': 'pt',
        'gallon': 'gal',
        'gallons': 'gal',
      };
      return singularShortUnits[lowerUnit] ?? unit;
    } else {
      const pluralShortUnits = {
        'teaspoon': 'tsps',
        'teaspoons': 'tsps',
        'tablespoon': 'Tbsps',
        'tablespoons': 'Tbsps',
        'cup': 'cups',
        'cups': 'cups',
        'ounce': 'oz',
        'ounces': 'oz',
        'pound': 'lbs',
        'pounds': 'lbs',
        'gram': 'g',
        'grams': 'g',
        'kilogram': 'kg',
        'kilograms': 'kg',
        'milliliter': 'ml',
        'milliliters': 'ml',
        'liter': 'l',
        'liters': 'l',
        'fluid ounce': 'fl. oz',
        'fluid ounces': 'fl. oz',
        'quart': 'qts',
        'quarts': 'qts',
        'pint': 'pts',
        'pints': 'pts',
        'gallon': 'gals',
        'gallons': 'gals',
      };
      return pluralShortUnits[lowerUnit] ?? unit;
    }
  }

  /// Gets the long unit format for Spoonacular
  String _getLongUnit(String unit, [double amount = 1.0]) {
    final lowerUnit = unit.toLowerCase();
    
    // Handle pluralization based on amount
    if (amount == 1.0) {
      const singularUnits = {
        'tsp': 'teaspoon',
        'tsps': 'teaspoon',
        'tbsp': 'tablespoon',
        'tbsps': 'tablespoon',
        'cup': 'cup',
        'cups': 'cup',
        'oz': 'ounce',
        'lb': 'pound',
        'lbs': 'pound',
        'g': 'gram',
        'kg': 'kilogram',
        'ml': 'milliliter',
        'l': 'liter',
        'fl. oz': 'fl. oz',
        'qt': 'quart',
        'qts': 'quart',
        'pt': 'pint',
        'pts': 'pint',
        'gal': 'gallon',
        'gals': 'gallon',
      };
      return singularUnits[lowerUnit] ?? unit;
    } else {
      const pluralUnits = {
        'tsp': 'teaspoons',
        'tsps': 'teaspoons',
        'tbsp': 'tablespoons',
        'tbsps': 'tablespoons',
        'cup': 'cups',
        'cups': 'cups',
        'oz': 'ounces',
        'lb': 'pounds',
        'lbs': 'pounds',
        'g': 'grams',
        'kg': 'kilograms',
        'ml': 'milliliters',
        'l': 'liters',
        'fl. oz': 'fl. ozs',
        'qt': 'quarts',
        'qts': 'quarts',
        'pt': 'pints',
        'pts': 'pints',
        'gal': 'gallons',
        'gals': 'gallons',
      };
      return pluralUnits[lowerUnit] ?? unit;
    }
  }

  /// Gets the metric equivalent of a US unit
  String _getMetricEquivalent(String unit) {
    const metricEquivalents = {
      'cup': 'ml',
      'cups': 'ml',
      'tablespoon': 'ml',
      'tablespoons': 'ml',
      'teaspoon': 'ml',
      'teaspoons': 'ml',
      'fluid ounce': 'ml',
      'fluid ounces': 'ml',
      'ounce': 'gram',
      'ounces': 'gram',
      'pound': 'gram',
      'pounds': 'gram',
      'quart': 'liter',
      'quarts': 'liter',
      'pint': 'ml',
      'pints': 'ml',
      'gallon': 'liter',
      'gallons': 'liter',
    };
    
    return metricEquivalents[unit.toLowerCase()] ?? unit;
  }

  /// Validates if a recipe can be scaled with confidence
  Map<String, dynamic> validateRecipeScaling({
    required Map<String, dynamic> recipe,
    required int targetServings,
  }) {
    final originalServings = recipe['servings'] as int;
    final scaleFactor = targetServings / originalServings;
    final extendedIngredients = recipe['extendedIngredients'] as List<dynamic>;
    
    final validation = {
      'canScale': true,
      'confidence': 100.0,
      'warnings': <String>[],
      'recommendations': <String>[],
      'scaleFactor': scaleFactor,
    };
    
         // Check for extreme scaling factors
     if (scaleFactor < 0.1) {
       (validation['warnings'] as List<String>).add('Very small scaling factor (${scaleFactor.toStringAsFixed(2)}x) may result in unmeasurable amounts');
       validation['confidence'] = (validation['confidence'] as double) * 0.8;
     } else if (scaleFactor > 10.0) {
       (validation['warnings'] as List<String>).add('Very large scaling factor (${scaleFactor.toStringAsFixed(2)}x) may require cooking time adjustments');
       validation['confidence'] = (validation['confidence'] as double) * 0.9;
     }
    
    // Check for problematic ingredients
    int seasoningsCount = 0;
    int zeroAmountCount = 0;
    
    for (final ingredient in extendedIngredients) {
      final name = ingredient['name'] ?? '';
      final amount = (ingredient['amount'] ?? 0.0) as double;
      
      if (amount == 0.0) {
        zeroAmountCount++;
      }
      
      if (_isSeasoningOrSpice(name)) {
        seasoningsCount++;
      }
    }
    
         if (seasoningsCount > 0 && scaleFactor > 2.0) {
       (validation['recommendations'] as List<String>).add('$seasoningsCount seasonings will be scaled conservatively to avoid overpowering flavors');
     }
     
     if (zeroAmountCount > 0) {
       (validation['warnings'] as List<String>).add('$zeroAmountCount ingredients have no specified amounts');
       validation['confidence'] = (validation['confidence'] as double) * 0.95;
     }
    
    return validation;
  }

  /// Gets scaling statistics for a recipe
  Map<String, dynamic> getScalingStatistics(Map<String, dynamic> scaledRecipe) {
    if (!scaledRecipe.containsKey('scalingMetadata')) {
      return {'error': 'Recipe has not been scaled'};
    }
    
    final metadata = scaledRecipe['scalingMetadata'] as Map<String, dynamic>;
    final summary = metadata['conversionSummary'] as Map<String, dynamic>;
    
    return {
      'originalServings': metadata['originalServings'],
      'targetServings': metadata['targetServings'],
      'scaleFactor': metadata['scaleFactor'],
      'overallConfidence': metadata['overallConfidence'],
      'scaledAt': metadata['scaledAt'],
      'ingredientStats': {
        'total': summary['totalIngredients'],
        'highConfidence': summary['highConfidence'],
        'mediumConfidence': summary['mediumConfidence'],
        'lowConfidence': summary['lowConfidence'],
        'failed': summary['failed'],
        'seasoningsAdjusted': summary['seasoningsAdjusted'],
      },
    };
  }
} 