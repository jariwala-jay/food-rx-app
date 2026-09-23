import 'package:flutter_app/features/recipes/models/nutrition.dart';

/// Converts a [Nutrient]'s amount to milligrams (g/mg/mcg), matching the
/// conversion already used in the recipe cook flow's sodium tracking.
double nutrientAmountInMg(Nutrient nutrient) {
  final unit = nutrient.unit.toLowerCase();
  if (unit == 'g') {
    return nutrient.amount * 1000;
  }
  if (unit == 'mcg' || unit == 'μg') {
    return nutrient.amount / 1000;
  }
  // Already mg, or an unrecognized unit -- treated as-is rather than
  // guessing at a conversion.
  return nutrient.amount;
}

/// Finds a named nutrient (case-insensitive) in a [Nutrition]'s nutrient
/// list, or null if it isn't present in the response at all.
Nutrient? findNutrient(Nutrition nutrition, String name) {
  final target = name.toLowerCase();
  for (final n in nutrition.nutrients) {
    if (n.name.toLowerCase() == target) return n;
  }
  return null;
}
