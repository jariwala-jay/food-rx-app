import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

void main() {
  group('UnitConversionService', () {
    final conversionService = UnitConversionService();

    // --- Basic Weight Conversions ---
    test('converts grams to kilograms', () {
      expect(
          conversionService.convert(amount: 1000, fromUnit: 'g', toUnit: 'kg'),
          1.0);
    });

    test('converts kilograms to grams', () {
      expect(
          conversionService.convert(amount: 1.5, fromUnit: 'kg', toUnit: 'g'),
          1500.0);
    });

    test('converts ounces to grams', () {
      expect(conversionService.convert(amount: 1, fromUnit: 'oz', toUnit: 'g'),
          closeTo(28.35, 0.01));
    });

    test('converts pounds to grams', () {
      expect(conversionService.convert(amount: 1, fromUnit: 'lb', toUnit: 'g'),
          closeTo(453.59, 0.01));
    });

    // --- Basic Volume Conversions ---
    test('converts cups to ml', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'cup', toUnit: 'ml'),
          closeTo(236.59, 0.01));
    });

    test('converts tablespoons to ml', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'Tbs', toUnit: 'ml'),
          closeTo(14.79, 0.01));
    });

    test('converts teaspoons to ml', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'tsp', toUnit: 'ml'),
          closeTo(4.93, 0.01));
    });

    test('converts fluid ounces to ml', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'fl oz', toUnit: 'ml'),
          closeTo(29.57, 0.01));
    });

    // --- Volume to Weight Conversions (using density) ---
    test('converts cups of flour to grams', () {
      expect(
          conversionService.convert(
            amount: 1,
            fromUnit: 'cup',
            toUnit: 'g',
            ingredientName: 'all-purpose flour',
          ),
          closeTo(125.39, 0.01));
    });

    test('converts cups of sugar to grams', () {
      expect(
          conversionService.convert(
            amount: 1,
            fromUnit: 'cup',
            toUnit: 'g',
            ingredientName: 'sugar',
          ),
          closeTo(198.73, 0.01));
    });

    test('converts tablespoons of olive oil to grams', () {
      expect(
          conversionService.convert(
            amount: 1,
            fromUnit: 'tablespoon',
            toUnit: 'g',
            ingredientName: 'olive oil',
          ),
          closeTo(13.6, 0.01));
    });

    // --- Piece/Unit to Weight Conversions ---
    test('converts pieces of egg to grams', () {
      expect(
          conversionService.convert(
            amount: 2,
            fromUnit:
                'large', // Spoonacular sometimes returns adjectives as units
            toUnit: 'g',
            ingredientName: 'egg',
          ),
          100.0);
    });

    test('converts cloves of garlic to grams', () {
      expect(
          conversionService.convert(
              amount: 3,
              fromUnit: 'cloves',
              toUnit: 'g',
              ingredientName: 'garlic'),
          9.0);
    });

    // --- Unit Normalization Tests ---
    test('handles various spellings of "gram"', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'g', toUnit: 'grams'),
          1.0);
      expect(
          conversionService.convert(amount: 1, fromUnit: 'gram', toUnit: 'g'),
          1.0);
    });

    test('handles various spellings of "ounce"', () {
      expect(
          conversionService.convert(amount: 1, fromUnit: 'oz', toUnit: 'ounce'),
          1.0);
      expect(
          conversionService.convert(
              amount: 1, fromUnit: 'ounces', toUnit: 'oz'),
          1.0);
    });

    test('handles various spellings of "tablespoon"', () {
      expect(
          conversionService.convert(
              amount: 1, fromUnit: 'Tbs', toUnit: 'tablespoon'),
          1.0);
      expect(
          conversionService.convert(
              amount: 1, fromUnit: 'tbsp', toUnit: 'Tablespoons'),
          1.0);
    });

    // --- Edge Cases and Invalid Conversions ---
    test('returns original amount when conversion is not possible', () {
      expect(
          conversionService.convert(
              amount: 1,
              fromUnit: 'unknown_unit',
              toUnit: 'g',
              ingredientName: 'some ingredient'),
          1.0);
    });

    test(
        'handles conversion from a volume to a weight for an ingredient with no density',
        () {
      // Expecting it to fail gracefully and return the original amount
      expect(
          conversionService.convert(
              amount: 1,
              fromUnit: 'cup',
              toUnit: 'g',
              ingredientName: 'an ingredient with no density info'),
          1.0);
    });

    test('handles zero amount', () {
      expect(conversionService.convert(amount: 0, fromUnit: 'g', toUnit: 'kg'),
          0.0);
    });

    test('handles empty ingredient name', () {
      expect(
          conversionService.convert(
              amount: 1, fromUnit: 'cup', toUnit: 'ml', ingredientName: ''),
          closeTo(236.59, 0.01));
    });

    test('handles "serving" as a unit', () {
      // This is a common case from spoonacular. We can't directly convert it, but we should handle it gracefully.
      // Often, we need to look up the serving size in grams from another API call or a database.
      // For now, the service should return the original amount if it can't find a direct conversion.
      expect(
          conversionService.convert(
              amount: 1,
              fromUnit: 'serving',
              toUnit: 'g',
              ingredientName: 'chicken breast'),
          1.0); // Expecting it to return the original amount as no direct conversion for 'serving' is defined
    });
  });
}
