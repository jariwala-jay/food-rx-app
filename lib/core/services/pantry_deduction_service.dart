import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';

/// Enhanced Pantry Deduction Service for Food Rx
/// Implements FIFO logic and integrates with recipe scaling
/// Supports multiple packages and accurate unit conversions
class PantryDeductionService {
  final UnitConversionService _conversionService;
  final IngredientSubstitutionService _substitutionService;

  PantryDeductionService({
    required UnitConversionService conversionService,
    required IngredientSubstitutionService substitutionService,
  })  : _conversionService = conversionService,
        _substitutionService = substitutionService;

  /// Deducts ingredients from pantry using FIFO logic
  /// Returns detailed deduction results with confidence metrics
  Future<PantryDeductionResult> deductIngredientsFromPantry({
    required List<Map<String, dynamic>> scaledIngredients,
    required List<PantryItem> pantryItems,
  }) async {
    final deductionResults = <IngredientDeductionResult>[];
    final updatedPantryItems = <PantryItem>[];
    final itemsToRemove = <String>[];
    
    if (kDebugMode) {
      print('🗄️ Starting pantry deduction for ${scaledIngredients.length} ingredients');
    }

    // Process each ingredient from the scaled recipe
    for (final ingredient in scaledIngredients) {
      final ingredientName = ingredient['name'] as String? ?? '';
      final requiredAmount = (ingredient['amount'] as num?)?.toDouble() ?? 0.0;
      final requiredUnit = ingredient['unit'] as String? ?? '';

      if (kDebugMode) {
        print('📦 Processing: $requiredAmount $requiredUnit of $ingredientName');
      }

      final deductionResult = await _deductSingleIngredient(
        ingredientName: ingredientName,
        requiredAmount: requiredAmount,
        requiredUnit: requiredUnit,
        pantryItems: pantryItems,
      );

      deductionResults.add(deductionResult);

      // Apply the deductions to pantry items
      for (final deduction in deductionResult.pantryDeductions) {
        if (deduction.newQuantity <= 0) {
          // Mark item for removal
          itemsToRemove.add(deduction.pantryItemId);
        } else {
          // Update item quantity
          final originalItem = pantryItems.firstWhere(
            (item) => item.id == deduction.pantryItemId,
          );
          updatedPantryItems.add(
            originalItem.copyWith(quantity: deduction.newQuantity),
          );
        }
      }
    }

    final overallResult = PantryDeductionResult(
      ingredientResults: deductionResults,
      updatedItems: updatedPantryItems,
      itemsToRemove: itemsToRemove,
      totalIngredientsProcessed: scaledIngredients.length,
      successfulDeductions: deductionResults.where((r) => r.wasDeducted).length,
      averageConfidence: _calculateAverageConfidence(deductionResults),
      deductedAt: DateTime.now(),
    );

    if (kDebugMode) {
      print('✅ Deduction complete: ${overallResult.successfulDeductions}/${overallResult.totalIngredientsProcessed} successful');
      print('📊 Average confidence: ${(overallResult.averageConfidence * 100).toStringAsFixed(1)}%');
    }

    return overallResult;
  }

  /// Deducts a single ingredient using FIFO logic across multiple pantry items
  Future<IngredientDeductionResult> _deductSingleIngredient({
    required String ingredientName,
    required double requiredAmount,
    required String requiredUnit,
    required List<PantryItem> pantryItems,
  }) async {
    // Find all matching pantry items (including substitutes)
    final matchingItems = _findMatchingPantryItems(ingredientName, pantryItems);
    
    if (matchingItems.isEmpty) {
      return IngredientDeductionResult(
        ingredientName: ingredientName,
        requiredAmount: requiredAmount,
        requiredUnit: requiredUnit,
        wasDeducted: false,
        pantryDeductions: [],
        confidence: 0.0,
        conversionPath: 'no_matching_items',
      );
    }

    // Sort by expiration date (FIFO - oldest first)
    matchingItems.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));

    final pantryDeductions = <PantryItemDeduction>[];
    double remainingAmount = requiredAmount;
    double totalConfidence = 0.0;
    int conversions = 0;

    // Deduct from items using FIFO logic
    for (final pantryItem in matchingItems) {
      if (remainingAmount <= 0) break;

      // Convert required amount to pantry item's unit
      final conversionResult = _conversionService.convertWithConfidence(
        amount: remainingAmount,
        fromUnit: requiredUnit,
        toUnit: pantryItem.unitLabel,
        ingredientName: ingredientName,
      );

      final convertedAmount = conversionResult['amount'] as double;
      final confidence = conversionResult['confidence'] as double;
      totalConfidence += confidence;
      conversions++;

      if (confidence == 0.0) {
        // Can't convert to this unit, skip this item
        continue;
      }

      // Calculate how much we can deduct from this item
      final availableAmount = pantryItem.quantity;
      final amountToDeduct = convertedAmount.clamp(0.0, availableAmount);
      final newQuantity = availableAmount - amountToDeduct;

      // Convert back to required unit to update remaining amount
      final backConversion = _conversionService.convertWithConfidence(
        amount: amountToDeduct,
        fromUnit: pantryItem.unitLabel,
        toUnit: requiredUnit,
        ingredientName: ingredientName,
      );

      final deductedInRequiredUnit = backConversion['amount'] as double;
      remainingAmount -= deductedInRequiredUnit;

      pantryDeductions.add(PantryItemDeduction(
        pantryItemId: pantryItem.id,
        pantryItemName: pantryItem.name,
        originalQuantity: availableAmount,
        deductedAmount: amountToDeduct,
        newQuantity: newQuantity,
        unit: pantryItem.unitLabel,
        confidence: confidence,
        expirationDate: pantryItem.expirationDate,
      ));

      if (kDebugMode) {
        print('  📦 Deducted $amountToDeduct ${pantryItem.unitLabel} from ${pantryItem.name}');
        print('     Remaining: $newQuantity ${pantryItem.unitLabel} (expires: ${pantryItem.expirationDate.toLocal().toString().split(' ')[0]})');
      }
    }

    final averageConfidence = conversions > 0 ? totalConfidence / conversions : 0.0;
    final wasFullyDeducted = remainingAmount <= 0.01; // Small tolerance for floating point

    return IngredientDeductionResult(
      ingredientName: ingredientName,
      requiredAmount: requiredAmount,
      requiredUnit: requiredUnit,
      wasDeducted: wasFullyDeducted,
      pantryDeductions: pantryDeductions,
      confidence: averageConfidence,
      conversionPath: 'fifo_deduction',
      remainingAmount: remainingAmount.clamp(0.0, requiredAmount),
    );
  }

  /// Finds all pantry items that match the ingredient (including substitutes)
  List<PantryItem> _findMatchingPantryItems(String ingredientName, List<PantryItem> pantryItems) {
    final matchingItems = <PantryItem>[];

    for (final pantryItem in pantryItems) {
      // Direct name match
      if (_isIngredientMatch(ingredientName, pantryItem.name)) {
        matchingItems.add(pantryItem);
        continue;
      }

      // Check for valid substitutes
      final substitute = _substitutionService.getValidSubstitute(
        ingredientName,
        pantryItem.name,
      );
      if (substitute != null) {
        matchingItems.add(pantryItem);
      }
    }

    return matchingItems;
  }

  /// Checks if two ingredient names match (case-insensitive, flexible matching)
  bool _isIngredientMatch(String required, String available) {
    final requiredLower = required.toLowerCase().trim();
    final availableLower = available.toLowerCase().trim();

    // Exact match
    if (requiredLower == availableLower) return true;

    // Contains match (for variations like "ground beef" vs "beef")
    if (availableLower.contains(requiredLower) || requiredLower.contains(availableLower)) {
      return true;
    }

    // Remove common prefixes/suffixes and check again
    final cleanRequired = _cleanIngredientName(requiredLower);
    final cleanAvailable = _cleanIngredientName(availableLower);
    
    return cleanRequired == cleanAvailable;
  }

  /// Cleans ingredient names for better matching
  String _cleanIngredientName(String name) {
    return name
        .replaceAll(RegExp(r'\b(fresh|dried|ground|chopped|diced|sliced|organic|raw)\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Calculates average confidence across all deductions
  double _calculateAverageConfidence(List<IngredientDeductionResult> results) {
    if (results.isEmpty) return 0.0;
    
    final totalConfidence = results.fold<double>(
      0.0,
      (sum, result) => sum + result.confidence,
    );
    
    return totalConfidence / results.length;
  }

  /// Validates if sufficient pantry items exist for a recipe
  Future<PantryValidationResult> validatePantryForRecipe({
    required List<Map<String, dynamic>> scaledIngredients,
    required List<PantryItem> pantryItems,
  }) async {
    final validationResults = <IngredientValidationResult>[];
    
    for (final ingredient in scaledIngredients) {
      final ingredientName = ingredient['name'] as String? ?? '';
      final requiredAmount = (ingredient['amount'] as num?)?.toDouble() ?? 0.0;
      final requiredUnit = ingredient['unit'] as String? ?? '';

      final matchingItems = _findMatchingPantryItems(ingredientName, pantryItems);
      
      if (matchingItems.isEmpty) {
        validationResults.add(IngredientValidationResult(
          ingredientName: ingredientName,
          requiredAmount: requiredAmount,
          requiredUnit: requiredUnit,
          isAvailable: false,
          availableAmount: 0.0,
          confidence: 0.0,
        ));
        continue;
      }

      // Calculate total available amount
      double totalAvailable = 0.0;
      double totalConfidence = 0.0;
      int conversions = 0;

      for (final pantryItem in matchingItems) {
        final conversionResult = _conversionService.convertWithConfidence(
          amount: pantryItem.quantity,
          fromUnit: pantryItem.unitLabel,
          toUnit: requiredUnit,
          ingredientName: ingredientName,
        );

        totalAvailable += conversionResult['amount'] as double;
        totalConfidence += conversionResult['confidence'] as double;
        conversions++;
      }

      final averageConfidence = conversions > 0 ? totalConfidence / conversions : 0.0;
      final isAvailable = totalAvailable >= requiredAmount;

      validationResults.add(IngredientValidationResult(
        ingredientName: ingredientName,
        requiredAmount: requiredAmount,
        requiredUnit: requiredUnit,
        isAvailable: isAvailable,
        availableAmount: totalAvailable,
        confidence: averageConfidence,
      ));
    }

    return PantryValidationResult(
      ingredientValidations: validationResults,
      allIngredientsAvailable: validationResults.every((r) => r.isAvailable),
      availabilityPercentage: validationResults.where((r) => r.isAvailable).length / validationResults.length,
      averageConfidence: _calculateAverageValidationConfidence(validationResults),
    );
  }

  double _calculateAverageValidationConfidence(List<IngredientValidationResult> results) {
    if (results.isEmpty) return 0.0;
    
    final totalConfidence = results.fold<double>(
      0.0,
      (sum, result) => sum + result.confidence,
    );
    
    return totalConfidence / results.length;
  }
}

/// Result of pantry deduction operation
class PantryDeductionResult {
  final List<IngredientDeductionResult> ingredientResults;
  final List<PantryItem> updatedItems;
  final List<String> itemsToRemove;
  final int totalIngredientsProcessed;
  final int successfulDeductions;
  final double averageConfidence;
  final DateTime deductedAt;

  PantryDeductionResult({
    required this.ingredientResults,
    required this.updatedItems,
    required this.itemsToRemove,
    required this.totalIngredientsProcessed,
    required this.successfulDeductions,
    required this.averageConfidence,
    required this.deductedAt,
  });

  bool get wasSuccessful => successfulDeductions == totalIngredientsProcessed;
  double get successRate => totalIngredientsProcessed > 0 ? successfulDeductions / totalIngredientsProcessed : 0.0;
}

/// Result of deducting a single ingredient
class IngredientDeductionResult {
  final String ingredientName;
  final double requiredAmount;
  final String requiredUnit;
  final bool wasDeducted;
  final List<PantryItemDeduction> pantryDeductions;
  final double confidence;
  final String conversionPath;
  final double remainingAmount;

  IngredientDeductionResult({
    required this.ingredientName,
    required this.requiredAmount,
    required this.requiredUnit,
    required this.wasDeducted,
    required this.pantryDeductions,
    required this.confidence,
    required this.conversionPath,
    this.remainingAmount = 0.0,
  });
}

/// Details of deduction from a specific pantry item
class PantryItemDeduction {
  final String pantryItemId;
  final String pantryItemName;
  final double originalQuantity;
  final double deductedAmount;
  final double newQuantity;
  final String unit;
  final double confidence;
  final DateTime expirationDate;

  PantryItemDeduction({
    required this.pantryItemId,
    required this.pantryItemName,
    required this.originalQuantity,
    required this.deductedAmount,
    required this.newQuantity,
    required this.unit,
    required this.confidence,
    required this.expirationDate,
  });
}

/// Result of pantry validation for a recipe
class PantryValidationResult {
  final List<IngredientValidationResult> ingredientValidations;
  final bool allIngredientsAvailable;
  final double availabilityPercentage;
  final double averageConfidence;

  PantryValidationResult({
    required this.ingredientValidations,
    required this.allIngredientsAvailable,
    required this.availabilityPercentage,
    required this.averageConfidence,
  });
}

/// Validation result for a single ingredient
class IngredientValidationResult {
  final String ingredientName;
  final double requiredAmount;
  final String requiredUnit;
  final bool isAvailable;
  final double availableAmount;
  final double confidence;

  IngredientValidationResult({
    required this.ingredientName,
    required this.requiredAmount,
    required this.requiredUnit,
    required this.isAvailable,
    required this.availableAmount,
    required this.confidence,
  });

  double get shortfallAmount => requiredAmount - availableAmount;
  bool get hasShortfall => shortfallAmount > 0;
} 