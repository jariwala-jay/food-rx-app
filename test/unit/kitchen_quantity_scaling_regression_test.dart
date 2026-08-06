import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/utils/kitchen_quantity_formatter.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

void main() {
  group('Recipe scaling + kitchen display regression', () {
    late RecipeScalingService scalingService;

    setUp(() {
      scalingService = RecipeScalingService(
        conversionService: UnitConversionService(),
      );
    });

    test('6→1 serving keeps exact basil amount while showing pinch display', () {
      const formatter = KitchenQuantityFormatter();

      final scaled = scalingService.scaleRecipe(
        originalRecipe: {
          'id': 1,
          'title': 'Spring Onion & Asparagus Frittata',
          'servings': 6,
          'extendedIngredients': [
            {
              'id': 1,
              'name': 'basil',
              'nameClean': 'basil dried',
              'amount': 0.5,
              'unit': 'teaspoon',
              'original': '0.5 teaspoons dried basil',
            },
          ],
        },
        targetServings: 1,
      );

      final ingredient = (scaled['extendedIngredients'] as List).first
          as Map<String, dynamic>;
      final exactAmount = ingredient['amount'] as double;

      expect(exactAmount, closeTo(0.5 / 6, 0.0001));
      expect(ingredient['unit'], equals('teaspoon'));
      expect(ingredient['scalingMetadata']['optimized'], isFalse);

      final displayName = RecipeIngredient.composeIngredientDisplayName(
        'basil dried',
        ' dried',
      );

      expect(
        formatter.formatIngredientLine(
          amount: exactAmount,
          unit: 'teaspoon',
          ingredientName: displayName,
        ),
        equals('A pinch of dried basil'),
      );
    });

    test('pantry math uses exact scaled amount not display-rounded amount', () {
      final scaled = scalingService.scaleRecipe(
        originalRecipe: {
          'id': 1,
          'title': 'Frittata',
          'servings': 6,
          'extendedIngredients': [
            {
              'id': 1,
              'name': 'basil dried',
              'amount': 0.5,
              'unit': 'teaspoon',
            },
          ],
        },
        targetServings: 1,
      );

      final exactAmount =
          (scaled['extendedIngredients'] as List).first['amount'] as double;
      const consumedFraction = 1.0;
      final pantryDeduction = exactAmount * consumedFraction;

      expect(pantryDeduction, isNot(closeTo(0.125, 0.001)));
      expect(pantryDeduction, closeTo(0.083333, 0.0001));
    });

    test('Spoonacular piece spring onions use stalk path not quarter snap', () {
      const formatter = KitchenQuantityFormatter();

      final scaled = scalingService.scaleRecipe(
        originalRecipe: {
          'id': 1,
          'title': 'Spring Onion & Asparagus Frittata',
          'servings': 6,
          'extendedIngredients': [
            {
              'id': 2,
              'name': 'small spring onions',
              'nameClean': 'small spring onions',
              'amount': 2.0,
              'unit': 'piece',
              'original': '2 small spring onions, sliced',
            },
          ],
        },
        targetServings: 1,
      );

      final ingredient = (scaled['extendedIngredients'] as List).first
          as Map<String, dynamic>;
      final exactAmount = ingredient['amount'] as double;

      expect(exactAmount, closeTo(2 / 6, 0.0001));

      final displayName = RecipeIngredient.composeIngredientDisplayName(
        'small spring onions',
        ' sliced',
      );
      expect(displayName, 'small spring onions, sliced');

      final formatted = formatter.formatIngredientLineWithPath(
        amount: exactAmount,
        unit: ingredient['unit'] as String,
        ingredientName: displayName,
      );

      expect(formatted.path, IngredientFormatPath.producePieceStalk);
      expect(formatted.display, '1 spring onion stalk, sliced');
      expect(formatted.display, isNot(contains('1/4')));
    });

    test('live frittata spring onions with size unit use stalk path', () {
      const formatter = KitchenQuantityFormatter();

      final scaled = scalingService.scaleRecipe(
        originalRecipe: {
          'id': 1,
          'title': 'Spring Onion & Asparagus Frittata',
          'servings': 6,
          'extendedIngredients': [
            {
              'id': 2,
              'name': 'spring onions',
              'nameClean': 'spring onions',
              'amount': 2.0,
              'unit': 'small',
              'original': '2 small spring onions, tops trimmed and sliced',
            },
          ],
        },
        targetServings: 1,
      );

      final ingredient = (scaled['extendedIngredients'] as List).first
          as Map<String, dynamic>;
      final exactAmount = (ingredient['amount'] as num).toDouble();

      expect(exactAmount, closeTo(2 / 6, 0.0001));

      final displayName = RecipeIngredient.composeIngredientDisplayName(
        'spring onions',
        ' sliced small',
      );
      expect(displayName, 'small spring onions, sliced');

      final unit = RecipeIngredient.sanitizeUnit(
        ingredient['unit'] as String,
        'spring onions',
      );
      expect(unit, '');

      final formatted = formatter.formatIngredientLineWithPath(
        amount: exactAmount,
        unit: unit,
        ingredientName: displayName,
      );

      expect(formatted.path, IngredientFormatPath.producePieceStalk);
      expect(formatted.display, '1 spring onion stalk, sliced');
    });

    test('frittata spring onions scale 1/2/6 servings with exact stored amounts', () {
      const formatter = KitchenQuantityFormatter();
      const originalRecipe = {
        'id': 1,
        'title': 'Spring Onion & Asparagus Frittata',
        'servings': 6,
        'extendedIngredients': [
          {
            'id': 2,
            'name': 'spring onions',
            'nameClean': 'spring onions',
            'amount': 2.0,
            'unit': 'small',
            'original': '2 small spring onions, tops trimmed and sliced',
          },
        ],
      };

      const cases = <Map<String, dynamic>>[
        {
          'targetServings': 1,
          'expectedAmount': 2 / 6,
          'expectedDisplay': '1 spring onion stalk, sliced',
          'expectedPath': IngredientFormatPath.producePieceStalk,
        },
        {
          'targetServings': 2,
          'expectedAmount': 4 / 6,
          'expectedDisplay': '1 spring onion stalk, sliced',
          'expectedPath': IngredientFormatPath.producePieceStalk,
        },
        {
          'targetServings': 6,
          'expectedAmount': 2.0,
          'expectedDisplay': '2 small spring onions, sliced',
          'expectedPath': IngredientFormatPath.standardFormatter,
        },
      ];

      for (final testCase in cases) {
        final scaled = scalingService.scaleRecipe(
          originalRecipe: originalRecipe,
          targetServings: testCase['targetServings'] as int,
        );

        final ingredient = (scaled['extendedIngredients'] as List).first
            as Map<String, dynamic>;
        final exactAmount = (ingredient['amount'] as num).toDouble();

        expect(
          exactAmount,
          closeTo(testCase['expectedAmount'] as double, 0.0001),
          reason: '${testCase['targetServings']} servings stored amount',
        );

        final displayName = RecipeIngredient.composeIngredientDisplayName(
          'spring onions',
          ' sliced small',
        );
        expect(displayName, 'small spring onions, sliced');

        final unit = RecipeIngredient.sanitizeUnit(
          ingredient['unit'] as String,
          'spring onions',
        );

        final formatted = formatter.formatIngredientLineWithPath(
          amount: exactAmount,
          unit: unit,
          ingredientName: displayName,
        );

        expect(
          formatted.path,
          testCase['expectedPath'] as IngredientFormatPath,
          reason: '${testCase['targetServings']} servings formatter path',
        );
        expect(
          formatted.display,
          testCase['expectedDisplay'] as String,
          reason: '${testCase['targetServings']} servings display',
        );
      }
    });
  });
}
