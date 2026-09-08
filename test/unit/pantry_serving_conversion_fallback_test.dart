import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

/// Guards the exact mismatch reported from the "Log Fruits" pantry picker:
/// an ingredient with no known piece-weight (e.g. "coconut" in "pc") showed
/// "Max: 0.0" but "Will deduct: 120 pc" for 1 serving -- the raw canonical
/// serving amount (120g) leaking through unconverted and mislabeled as
/// pieces. Both directions must report a failed conversion so callers fall
/// back to the pantry quantity / raw serving count instead of the
/// unconverted canonical amount.
void main() {
  test('unconvertible piece ingredient reports failed conversion both ways',
      () {
    final conversion = UnitConversionService();
    final dietServing = DietServingService(conversionService: conversion);

    final servingDefinition = dietServing.getServingDefinition(
      category: TrackerCategory.fruits,
      dietType: 'dash',
    );
    final canonicalAmount = servingDefinition!['canonical_amount'] as double;
    final canonicalUnit = servingDefinition['canonical_unit'] as String;
    expect(canonicalAmount, 120.0);
    expect(canonicalUnit, 'gram');

    // Mirrors _getMaxServingsAvailable: pantry quantity (0 pc) -> canonical unit.
    final maxConv = conversion.convertWithConfidence(
      amount: 0.0,
      fromUnit: 'pc',
      toUnit: canonicalUnit,
      ingredientName: 'coconut',
    );
    expect(maxConv['conversionPath'], 'failed');

    // Mirrors _calculatePhysicalAmountForServings: 1 serving in canonical
    // unit -> pantry item's unit (pc). Must also fail, so the caller's
    // `if (conversionPath == 'failed') return servings;` fallback applies
    // instead of trusting the raw, unconverted 120.
    final deductConv = conversion.convertWithConfidence(
      amount: 1.0 * canonicalAmount,
      fromUnit: canonicalUnit,
      toUnit: 'pc',
      ingredientName: 'coconut',
    );
    expect(deductConv['conversionPath'], 'failed');
  });
}
