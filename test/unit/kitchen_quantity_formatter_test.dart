import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/kitchen_quantity_formatter.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';

void main() {
  group('KitchenQuantityFormatter', () {
    const formatter = KitchenQuantityFormatter();

    group('Step 1 — fine dry seasoning bands', () {
      test('0.083 tsp basil displays as A pinch of dried basil', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.083,
            unit: 'tsp',
            ingredientName: 'dried basil',
          ),
          equals('A pinch of dried basil'),
        );
      });

      test('0.03 tsp oregano displays as A tiny pinch of', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.03,
            unit: 'tsp',
            ingredientName: 'oregano',
          ),
          equals('A tiny pinch of oregano'),
        );
      });

      test('0.06 tsp thyme displays as A pinch of', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.06,
            unit: 'tsp',
            ingredientName: 'thyme',
          ),
          equals('A pinch of thyme'),
        );
      });

      test('0.125 tsp basil displays as 1/8 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.125,
            unit: 'teaspoon',
            ingredientName: 'dried basil',
          ),
          equals('1/8 teaspoon dried basil'),
        );
      });

      test('0.22 tsp paprika displays as 1/4 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.22,
            unit: 'tsp',
            ingredientName: 'paprika',
          ),
          equals('1/4 teaspoon paprika'),
        );
      });
    });

    group('Step 1 — friendly values do not regress', () {
      test('1 tsp dried basil stays 1 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1,
            unit: 'tsp',
            ingredientName: 'dried basil',
          ),
          equals('1 teaspoon dried basil'),
        );
      });

      test('0.5 tsp oregano stays 1/2 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.5,
            unit: 'tsp',
            ingredientName: 'oregano',
          ),
          equals('1/2 teaspoon oregano'),
        );
      });

      test('0.25 tsp paprika stays 1/4 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.25,
            unit: 'tsp',
            ingredientName: 'paprika',
          ),
          equals('1/4 teaspoon paprika'),
        );
      });

      test('2 tbsp olive oil stays 2 tbsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 2,
            unit: 'tbsp',
            ingredientName: 'olive oil',
          ),
          equals('2 tablespoons olive oil'),
        );
      });

      test('1 cup spinach stays 1 cup', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1,
            unit: 'cup',
            ingredientName: 'spinach',
          ),
          equals('1 cup spinach'),
        );
      });
    });

    group('Step 1 — unit conversion before formatting', () {
      test('3 tsp olive oil converts to 1 tbsp before display', () {
        expect(
          formatter.formatIngredientLine(
            amount: 3,
            unit: 'tsp',
            ingredientName: 'olive oil',
          ),
          equals('1 tablespoon olive oil'),
        );
      });

      test('0.25 pound flank steak converts to 4 ounces', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.25,
            unit: 'pound',
            ingredientName: 'flank steak',
          ),
          equals('4 ounces flank steak'),
        );
      });

      test('0.0417 cup milk converts to teaspoons instead of zero cups', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.0417,
            unit: 'cup',
            ingredientName: 'milk',
          ),
          isNot(contains('0 cup')),
        );
      });

      test('0.333 cloves garlic displays as 1 small clove via metadata', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.3333,
            unit: 'cloves',
            ingredientName: 'garlic',
          ),
          equals('1 small clove garlic'),
        );
      });

      test('0.042 tsp sesame oil displays as a drizzle', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.042,
            unit: 'teaspoon',
            ingredientName: 'sesame oil',
          ),
          equals('A drizzle of sesame oil'),
        );
      });

      test('0.04 tsp olive oil displays as a drizzle', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.04,
            unit: 'tsp',
            ingredientName: 'olive oil',
          ),
          equals('A drizzle of olive oil'),
        );
      });

      test('1.33 ounces egg noodles displays as 1 1/2 ounces', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1.3333,
            unit: 'ounces',
            ingredientName: 'egg noodles',
          ),
          equals('1 1/2 ounces egg noodles'),
        );
      });

      test('0.75 ounces displays as grams under 1 oz', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.75,
            unit: 'ounces',
            ingredientName: 'feta cheese',
          ),
          equals('21 g feta cheese'),
        );
      });

      test('non-zero scaled amounts never display as zero', () {
        const cases = <({double amount, String unit, String name})>[
          (amount: 0.3333, unit: 'cloves', name: 'garlic'),
          (amount: 0.0417, unit: 'cup', name: 'milk'),
          (amount: 0.25, unit: '', name: 'onion'),
          (amount: 0.042, unit: 'teaspoon', name: 'sesame oil'),
        ];

        for (final testCase in cases) {
          final line = formatter.formatIngredientLine(
            amount: testCase.amount,
            unit: testCase.unit,
            ingredientName: testCase.name,
          );
          expect(
            line,
            isNot(startsWith('0 ')),
            reason: 'Unexpected zero display for ${testCase.name}',
          );
          expect(
            RegExp(r'\b0\s+(clove|cup|onion|teaspoon|tablespoon)').hasMatch(line),
            isFalse,
            reason: 'Zero unit display for ${testCase.name}: $line',
          );
        }
      });
    });

    group('Step 1 — precise ingredients skip cooking rounding', () {
      test('0.17 tsp baking soda uses conservative 1/8 tsp rounding', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.17,
            unit: 'tsp',
            ingredientName: 'baking soda',
          ),
          equals('1/8 teaspoon baking soda'),
        );
      });

      test('0.17 tsp supplement keeps exact display amount', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.17,
            unit: 'tsp',
            ingredientName: 'vitamin d supplement',
          ),
          equals('0.17 teaspoon vitamin d supplement'),
        );
      });

      test('classifies supplement as precise category', () {
        expect(
          formatter.categoryFor('iron supplement', 'tsp'),
          IngredientDisplayCategory.precise,
        );
      });
    });

    group('Phase 1 — volume and count', () {
      test('1.75 cloves garlic displays as 2 cloves', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1.75,
            unit: 'clove',
            ingredientName: 'garlic',
          ),
          equals('2 cloves garlic'),
        );
      });

      test('0.17 tsp baking soda displays as 1/8 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.17,
            unit: 'tsp',
            ingredientName: 'baking soda',
          ),
          equals('1/8 teaspoon baking soda'),
        );
      });

      test('100 g spinach keeps weight display', () {
        expect(
          formatter.formatIngredientLine(
            amount: 100,
            unit: 'g',
            ingredientName: 'spinach',
          ),
          equals('100 g spinach'),
        );
      });

      test('0.5 tsp coconut oil displays as 1/2 tsp', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.5,
            unit: 'tsp',
            ingredientName: 'coconut oil',
          ),
          equals('1/2 teaspoon coconut oil'),
        );
      });

      test('32 tablespoons displays as 2 cups after unit conversion', () {
        expect(
          formatter.formatIngredientLine(
            amount: 32,
            unit: 'tablespoon',
            ingredientName: 'flour',
          ),
          equals('2 cups flour'),
        );
      });
    });

    group('Phase 2 — seasoning count units', () {
      test('invalid piece unit on sea salt normalizes to pinch display', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 1,
          unit: 'piece',
          ingredientName: 'sea salt',
        );

        expect(result.path, IngredientFormatPath.seasoningCountUnit);
        expect(result.display, 'A pinch of sea salt');
        expect(result.display, isNot(contains('piece')));
      });

      test('multiple invalid piece units use tsp proxy not piece label', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 2,
          unit: 'piece',
          ingredientName: 'sea salt',
        );

        expect(result.path, IngredientFormatPath.seasoningCountUnit);
        expect(result.display, '2 tsp sea salt');
        expect(result.display, isNot(contains('piece')));
      });

      test('crystal unit on salt normalizes like invalid count unit', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 1,
          unit: 'crystal',
          ingredientName: 'sea salt',
        );

        expect(result.path, IngredientFormatPath.seasoningCountUnit);
        expect(result.display, 'A pinch of sea salt');
      });

      test('1 piece bell pepper keeps standard count display', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 1,
          unit: 'piece',
          ingredientName: 'bell pepper',
        );

        expect(result.path, IngredientFormatPath.standardFormatter);
        expect(result.display, '1 piece bell pepper');
      });

      test('1 piece ginger keeps standard count display', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 1,
          unit: 'piece',
          ingredientName: 'ginger',
        );

        expect(result.path, IngredientFormatPath.standardFormatter);
        expect(result.display, '1 piece ginger');
      });
    });

    group('Phase 2 — produce conversions', () {
      test('0.167 bunch asparagus displays as bunch fraction with spear hint', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.167,
            unit: 'bunch',
            ingredientName: 'asparagus',
          ),
          equals('1/4 bunch asparagus (~4 asparagus spears)'),
        );
      });

      test('0.167 bunch spring onions prefers clean stalk count over quarter bunch', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.1667,
            unit: 'bunch',
            ingredientName: 'spring onions',
          ),
          equals('1 spring onion stalk'),
        );
      });

      test('0.33 piece spring onions matches Spoonacular count unit path', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 0.333,
          unit: 'piece',
          ingredientName: 'small spring onions, sliced',
        );

        expect(result.path, IngredientFormatPath.producePieceStalk);
        expect(result.display, '1 spring onion stalk, sliced');
      });

      test('0.33 stalk unit spring onions uses produce piece stalk path', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 0.333,
          unit: 'stalks',
          ingredientName: 'small spring onions, sliced',
        );

        expect(result.path, IngredientFormatPath.producePieceStalk);
        expect(result.display, '1 spring onion stalk, sliced');
      });

      test('0.33 spring onions with Spoonacular size unit uses stalk path', () {
        final unit = RecipeIngredient.sanitizeUnit('small', 'spring onions');
        expect(unit, '');

        final result = formatter.formatIngredientLineWithPath(
          amount: 0.333,
          unit: unit,
          ingredientName: 'small spring onions, sliced',
        );

        expect(result.path, IngredientFormatPath.producePieceStalk);
        expect(result.display, '1 spring onion stalk, sliced');
        expect(result.display, isNot(contains('1/4')));
      });

      test('0.5 bunch spring onions displays as bunch fraction with stalk hint', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.5,
            unit: 'bunch',
            ingredientName: 'spring onions',
          ),
          equals('1/2 bunch spring onions (~3 spring onion stalks)'),
        );
      });

      test('1+ bunch asparagus keeps bunch fraction display', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1.5,
            unit: 'bunch',
            ingredientName: 'asparagus',
          ),
          equals('1 1/2 bunches asparagus'),
        );
      });

      test('parsley bunch does not use asparagus-style spear conversion', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.167,
            unit: 'bunch',
            ingredientName: 'parsley',
          ),
          equals('1/4 bunch parsley'),
        );
      });
    });

    group('Phase 2 — count ranges', () {
      test('1 1/2 eggs displays as 1–2 eggs', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1.5,
            unit: '',
            ingredientName: 'eggs (free range if possible)',
          ),
          equals('1–2 eggs (free range if possible)'),
        );
      });

      test('2.5 eggs displays as 2–3 eggs', () {
        expect(
          formatter.formatIngredientLine(
            amount: 2.5,
            unit: 'egg',
            ingredientName: 'egg',
          ),
          equals('2–3 eggs'),
        );
      });
    });

    group('display name composition', () {
      test('composeIngredientDisplayName reorders basil dried', () {
        expect(
          RecipeIngredient.composeIngredientDisplayName('basil dried', ' dried'),
          equals('dried basil'),
        );
      });

      test('composeIngredientDisplayName avoids duplicate size descriptors', () {
        expect(
          RecipeIngredient.composeIngredientDisplayName(
            'small spring onions',
            ' sliced',
          ),
          equals('small spring onions, sliced'),
        );
        expect(
          RecipeIngredient.composeIngredientDisplayName(
            'small spring onions',
            ' sliced',
          ),
          isNot(contains('small small')),
        );
      });
    });

    group('Phase 2 — categories', () {
      test('classifies dried basil as seasoning', () {
        expect(
          formatter.categoryFor('basil dried', 'tsp'),
          IngredientDisplayCategory.seasoning,
        );
      });

      test('classifies asparagus bunch as produce', () {
        expect(
          formatter.categoryFor('asparagus', 'bunch'),
          IngredientDisplayCategory.produce,
        );
      });

      test('classifies baking soda as baking', () {
        expect(
          formatter.categoryFor('baking soda', 'tsp'),
          IngredientDisplayCategory.baking,
        );
      });

      test('classifies coconut oil as liquid', () {
        expect(
          formatter.categoryFor('coconut oil', 'tsp'),
          IngredientDisplayCategory.liquid,
        );
      });
    });

    group('Step 3.2 — formatter path observability', () {
      test('garlic partial clove uses metadata_override path', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 0.33,
          unit: 'cloves',
          ingredientName: 'garlic',
        );

        expect(result.path, IngredientFormatPath.metadataOverride);
        expect(result.display, '1 small clove garlic');
      });

      test('parmesan cup line uses standard_formatter path', () {
        final result = formatter.formatIngredientLineWithPath(
          amount: 0.15,
          unit: 'cup',
          ingredientName: 'parmesan cheese',
        );

        expect(result.path, IngredientFormatPath.standardFormatter);
        expect(result.display, contains('parmesan cheese'));
      });
    });

    group('v1.1 — Spoonacular spoon / plural / oil sanitization', () {
      test('spoon salt becomes pinch of salt, not pinch of spoon salt', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.083,
            unit: 'spoon',
            ingredientName: 'spoon salt',
          ),
          equals('A pinch of salt'),
        );
      });

      test('spoon butter maps to tablespoon', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1,
            unit: 'spoon',
            ingredientName: 'butter',
          ),
          equals('1 tablespoon butter'),
        );
      });

      test('scaled spoon salt at 1/8 tsp displays cleanly', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.125,
            unit: 'spoon',
            ingredientName: 'spoon salt',
          ),
          equals('1/8 teaspoon salt'),
        );
      });

      test('1 chillies singularizes to chilli', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1,
            unit: '',
            ingredientName: 'chillies',
          ),
          equals('1 chilli'),
        );
      });

      test('pieces oil becomes tablespoons oil', () {
        expect(
          formatter.formatIngredientLine(
            amount: 2,
            unit: 'pieces',
            ingredientName: 'oil',
          ),
          equals('2 tablespoons oil'),
        );
      });

      test('RecipeIngredient.sanitizeUnit maps spoon to teaspoon', () {
        expect(
          RecipeIngredient.sanitizeUnit('spoon', 'salt'),
          equals('teaspoon'),
        );
        expect(
          RecipeIngredient.sanitizeUnit('spoon', 'butter'),
          equals('tablespoon'),
        );
      });

      test('Tbs abbreviation displays as tablespoon', () {
        expect(
          formatter.formatIngredientLine(
            amount: 1,
            unit: 'Tbs',
            ingredientName: 'ginger',
          ),
          equals('1 tablespoon ginger'),
        );
        expect(
          RecipeIngredient.sanitizeUnit('Tbs', 'ginger'),
          equals('tablespoon'),
        );
      });
    });

    group('v1.2 — US-friendly weight display', () {
      test('0.1 kg becomes 100 grams', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.1,
            unit: 'kg',
            ingredientName: 'spinach',
          ),
          equals('100 grams spinach'),
        );
      });

      test('0.125 kg cheese becomes 125 grams', () {
        expect(
          formatter.formatIngredientLine(
            amount: 0.125,
            unit: 'kg',
            ingredientName: 'cheese',
          ),
          equals('125 grams cheese'),
        );
      });

      test('1 kg becomes pounds for US display', () {
        final line = formatter.formatIngredientLine(
          amount: 1,
          unit: 'kg',
          ingredientName: 'chicken',
        );
        expect(line.toLowerCase(), contains('pound'));
        expect(line.toLowerCase(), isNot(contains('kilogram')));
        expect(line.toLowerCase(), isNot(contains('kg')));
      });

      test('1500 g becomes pounds instead of kilograms', () {
        final line = formatter.formatIngredientLine(
          amount: 1500,
          unit: 'g',
          ingredientName: 'beef',
        );
        expect(line.toLowerCase(), contains('pound'));
        expect(line.toLowerCase(), isNot(contains('kilogram')));
      });
    });
  });
}
