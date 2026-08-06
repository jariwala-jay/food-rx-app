import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/ingredient_display_metadata.dart';
import 'package:flutter_app/core/utils/kitchen_quantity_formatter.dart';

void main() {
  const formatter = KitchenQuantityFormatter();

  group('IngredientDisplayMetadataRegistry', () {
    test('resolves garlic behavior as smallCount', () {
      expect(
        IngredientDisplayMetadataRegistry.behaviorFor('garlic'),
        DisplayBehavior.smallCount,
      );
      expect(
        IngredientDisplayMetadataRegistry.behaviorFor('fresh garlic'),
        DisplayBehavior.smallCount,
      );
    });

    test('does not apply garlic behavior to garlic powder', () {
      expect(
        IngredientDisplayMetadataRegistry.resolveKey('garlic powder'),
        isNull,
      );
    });

    test('does not apply garlic behavior to onion', () {
      expect(
        IngredientDisplayMetadataRegistry.resolveKey('onion'),
        isNull,
      );
    });
  });

  group('Garlic smallCount display', () {
    test('0.33 cloves garlic displays as 1 small clove garlic', () {
      expect(
        formatter.formatIngredientLine(
          amount: 0.33,
          unit: 'cloves',
          ingredientName: 'garlic',
        ),
        equals('1 small clove garlic'),
      );
    });

    test('0.5 cloves garlic displays as 1/2 clove garlic', () {
      expect(
        formatter.formatIngredientLine(
          amount: 0.5,
          unit: 'cloves',
          ingredientName: 'garlic',
        ),
        equals('1/2 clove garlic'),
      );
    });

    test('0.8 cloves garlic displays as 1 clove garlic', () {
      expect(
        formatter.formatIngredientLine(
          amount: 0.8,
          unit: 'cloves',
          ingredientName: 'garlic',
        ),
        equals('1 clove garlic'),
      );
    });

    test('2 cloves garlic uses formatter count rules not metadata', () {
      expect(
        formatter.formatIngredientLine(
          amount: 2,
          unit: 'cloves',
          ingredientName: 'garlic',
        ),
        equals('2 cloves garlic'),
      );
    });
  });

  group('Garlic metadata regression', () {
    test('0.33 onion does not use garlic smallCount behavior', () {
      final line = formatter.formatIngredientLine(
        amount: 0.33,
        unit: '',
        ingredientName: 'onion',
      );

      expect(line, isNot(contains('small clove')));
      expect(line, isNot(contains('clove')));
    });

    test('formatLineOverride does not modify amount — display only', () {
      const exactAmount = 0.333;
      final display = formatter.formatIngredientLine(
        amount: exactAmount,
        unit: 'cloves',
        ingredientName: 'garlic',
      );

      expect(display, equals('1 small clove garlic'));
      expect(exactAmount, closeTo(0.333, 0.001));
    });
  });
}
