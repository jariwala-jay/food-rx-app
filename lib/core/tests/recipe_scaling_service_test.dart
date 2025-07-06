import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';

void main() {
  group('RecipeScalingService Tests', () {
    late RecipeScalingService scalingService;
    late UnitConversionService conversionService;

    setUp(() {
      conversionService = UnitConversionService();
      scalingService = RecipeScalingService(conversionService: conversionService);
    });

    // Sample Spoonacular recipe data based on the provided format
    final sampleRecipe = {
      "id": 633446,
      "title": "Baked Banana Pudding With Rum Sauce",
      "servings": 1,
      "extendedIngredients": [
        {
          "id": 9040,
          "name": "bananas",
          "amount": 5.0,
          "unit": "",
          "measures": {
            "us": {"amount": 5.0, "unitShort": "", "unitLong": ""},
            "metric": {"amount": 5.0, "unitShort": "", "unitLong": ""}
          }
        },
        {
          "id": 19334,
          "name": "brown sugar",
          "amount": 25.0,
          "unit": "grams",
          "measures": {
            "us": {"amount": 0.882, "unitShort": "oz", "unitLong": "ounces"},
            "metric": {"amount": 25.0, "unitShort": "g", "unitLong": "grams"}
          }
        },
        {
          "id": 1001,
          "name": "butter",
          "amount": 0.5,
          "unit": "tablespoon",
          "measures": {
            "us": {"amount": 0.5, "unitShort": "Tbsps", "unitLong": "Tbsps"},
            "metric": {"amount": 0.5, "unitShort": "Tbsps", "unitLong": "Tbsps"}
          }
        },
        {
          "id": 1053,
          "name": "bailey's cream",
          "amount": 100.0,
          "unit": "ml",
          "measures": {
            "us": {"amount": 3.402, "unitShort": "fl. oz", "unitLong": "fl. ozs"},
            "metric": {"amount": 100.0, "unitShort": "ml", "unitLong": "milliliters"}
          }
        },
        {
          "id": 1012010,
          "name": "ground cinnamon",
          "amount": 0.5,
          "unit": "teaspoon",
          "measures": {
            "us": {"amount": 0.5, "unitShort": "tsps", "unitLong": "teaspoons"},
            "metric": {"amount": 0.5, "unitShort": "tsps", "unitLong": "teaspoons"}
          }
        },
        {
          "id": 19335,
          "name": "caster sugar",
          "amount": 66.0,
          "unit": "grams",
          "measures": {
            "us": {"amount": 2.328, "unitShort": "oz", "unitLong": "ounces"},
            "metric": {"amount": 66.0, "unitShort": "g", "unitLong": "grams"}
          }
        }
      ]
    };

    group('Recipe Scaling', () {
      test('Scales recipe to double servings correctly', () {
        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: sampleRecipe,
          targetServings: 2,
        );

        expect(scaledRecipe['servings'], equals(2));
        expect(scaledRecipe['scalingMetadata']['scaleFactor'], equals(2.0));
        expect(scaledRecipe['scalingMetadata']['originalServings'], equals(1));
        expect(scaledRecipe['scalingMetadata']['targetServings'], equals(2));

        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        
        // Check bananas (no unit, should scale directly)
        final bananas = scaledIngredients.firstWhere((ing) => ing['name'] == 'bananas');
        expect(bananas['amount'], equals(10.0)); // 5 * 2
        
        // Check brown sugar (grams)
        final brownSugar = scaledIngredients.firstWhere((ing) => ing['name'] == 'brown sugar');
        expect(brownSugar['amount'], equals(50.0)); // 25 * 2
        expect(brownSugar['unit'], equals('grams'));
        
        // Check butter (tablespoon)
        final butter = scaledIngredients.firstWhere((ing) => ing['name'] == 'butter');
        expect(butter['amount'], equals(1.0)); // 0.5 * 2
        expect(butter['unit'], equals('tablespoon'));
      });

      test('Scales recipe to half servings correctly', () {
        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: sampleRecipe,
          targetServings: 0, // This should be treated as 0.5 servings
        );

        // Actually, let's test with a proper fraction
        final halfScaledRecipe = scalingService.scaleRecipe(
          originalRecipe: Map<String, dynamic>.from(sampleRecipe)..['servings'] = 2,
          targetServings: 1,
        );

        expect(halfScaledRecipe['servings'], equals(1));
        expect(halfScaledRecipe['scalingMetadata']['scaleFactor'], equals(0.5));

        final scaledIngredients = halfScaledRecipe['extendedIngredients'] as List<dynamic>;
        
        // Check bananas
        final bananas = scaledIngredients.firstWhere((ing) => ing['name'] == 'bananas');
        expect(bananas['amount'], equals(2.5)); // 5 * 0.5
      });

      test('Handles seasoning scaling correctly', () {
        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: sampleRecipe,
          targetServings: 5, // 5x scaling should trigger seasoning adjustment
        );

        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        
        // Check cinnamon (seasoning) - should be scaled less aggressively
        final cinnamon = scaledIngredients.firstWhere((ing) => ing['name'] == 'ground cinnamon');
        final cinnamonMetadata = cinnamon['scalingMetadata'];
        
        expect(cinnamonMetadata['seasoningAdjusted'], isTrue);
        expect(cinnamonMetadata['scaleFactor'], lessThan(5.0)); // Should be less than full 5x
        expect(cinnamon['amount'], lessThan(2.5)); // 0.5 * 5 = 2.5, but should be less
      });

      test('Optimizes units after scaling', () {
        // Create a recipe with small tablespoon amounts that should convert to cups
        final testRecipe = {
          "id": 1,
          "title": "Test Recipe",
          "servings": 1,
          "extendedIngredients": [
            {
              "id": 1,
              "name": "flour",
              "amount": 2.0,
              "unit": "tablespoon",
              "measures": {
                "us": {"amount": 2.0, "unitShort": "Tbsps", "unitLong": "Tbsps"},
                "metric": {"amount": 2.0, "unitShort": "Tbsps", "unitLong": "Tbsps"}
              }
            }
          ]
        };

        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: testRecipe,
          targetServings: 16, // 2 tbsp * 16 = 32 tbsp = 2 cups
        );

        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        final flour = scaledIngredients.first;
        
        expect(flour['amount'], equals(2.0)); // Should be optimized to 2 cups
        expect(flour['unit'], equals('cups')); // Should be converted from tablespoons
        expect(flour['scalingMetadata']['optimized'], isTrue);
      });
    });

    group('Extended Ingredients Scaling', () {
      test('Scales individual ingredients with metadata', () {
        final extendedIngredients = sampleRecipe['extendedIngredients'] as List<dynamic>;
        
        final results = scalingService.scaleExtendedIngredients(
          extendedIngredients: extendedIngredients,
          scaleFactor: 3.0,
        );

        final scaledIngredients = results['ingredients'] as List<Map<String, dynamic>>;
        final summary = results['summary'] as Map<String, dynamic>;

        expect(scaledIngredients.length, equals(extendedIngredients.length));
        expect(summary['totalIngredients'], equals(extendedIngredients.length));
        
        // Check that all ingredients have scaling metadata
        for (final ingredient in scaledIngredients) {
          expect(ingredient.containsKey('scalingMetadata'), isTrue);
          final metadata = ingredient['scalingMetadata'];
          expect(metadata.containsKey('originalAmount'), isTrue);
          expect(metadata.containsKey('originalUnit'), isTrue);
          expect(metadata.containsKey('scaleFactor'), isTrue);
          expect(metadata.containsKey('confidence'), isTrue);
        }
      });

      test('Handles zero amounts correctly', () {
        final zeroAmountIngredient = {
          "id": 1,
          "name": "test ingredient",
          "amount": 0.0,
          "unit": "cup",
        };

        final results = scalingService.scaleExtendedIngredients(
          extendedIngredients: [zeroAmountIngredient],
          scaleFactor: 2.0,
        );

        final scaledIngredients = results['ingredients'] as List<Map<String, dynamic>>;
        final ingredient = scaledIngredients.first;

        expect(ingredient['amount'], equals(0.0));
        expect(ingredient['scalingMetadata']['confidence'], equals(0.0));
        expect(ingredient['scalingMetadata']['conversionPath'], equals('zero_amount'));
      });

      test('Handles empty units correctly', () {
        final emptyUnitIngredient = {
          "id": 1,
          "name": "test ingredient",
          "amount": 5.0,
          "unit": "",
        };

        final results = scalingService.scaleExtendedIngredients(
          extendedIngredients: [emptyUnitIngredient],
          scaleFactor: 2.0,
        );

        final scaledIngredients = results['ingredients'] as List<Map<String, dynamic>>;
        final ingredient = scaledIngredients.first;

        expect(ingredient['amount'], equals(10.0)); // Should still scale
        expect(ingredient['scalingMetadata']['confidence'], equals(0.95));
        expect(ingredient['scalingMetadata']['conversionPath'], equals('direct_scaling'));
      });
    });

    group('Measures Scaling', () {
      test('Updates US and metric measures correctly', () {
        final testIngredient = {
          "id": 1,
          "name": "flour",
          "amount": 1.0,
          "unit": "cup",
          "measures": {
            "us": {"amount": 1.0, "unitShort": "cup", "unitLong": "cup"},
            "metric": {"amount": 240.0, "unitShort": "ml", "unitLong": "milliliters"}
          }
        };

        final results = scalingService.scaleExtendedIngredients(
          extendedIngredients: [testIngredient],
          scaleFactor: 2.0,
        );

        final scaledIngredient = (results['ingredients'] as List<Map<String, dynamic>>).first;
        final measures = scaledIngredient['measures'];

        expect(measures['us']['amount'], equals(2.0));
        expect(measures['us']['unitShort'], equals('cups'));
        expect(measures['us']['unitLong'], equals('cups'));
      });
    });

    group('Validation', () {
      test('Validates normal scaling scenarios', () {
        final validation = scalingService.validateRecipeScaling(
          recipe: sampleRecipe,
          targetServings: 4,
        );

        expect(validation['canScale'], isTrue);
        expect(validation['confidence'], equals(100.0));
        expect(validation['scaleFactor'], equals(4.0));
        expect((validation['warnings'] as List).isEmpty, isTrue);
      });

      test('Warns about extreme scaling factors', () {
        final smallScaleValidation = scalingService.validateRecipeScaling(
          recipe: sampleRecipe,
          targetServings: 0, // This creates a very small scale factor
        );

        expect((smallScaleValidation['warnings'] as List).isNotEmpty, isTrue);
        expect(smallScaleValidation['confidence'], lessThan(100.0));

        // Test large scaling
        final largeScaleValidation = scalingService.validateRecipeScaling(
          recipe: Map<String, dynamic>.from(sampleRecipe)..['servings'] = 1,
          targetServings: 50, // 50x scaling
        );

        expect((largeScaleValidation['warnings'] as List).isNotEmpty, isTrue);
        expect(largeScaleValidation['confidence'], lessThan(100.0));
      });

      test('Provides recommendations for seasoning adjustments', () {
        final validation = scalingService.validateRecipeScaling(
          recipe: sampleRecipe,
          targetServings: 5, // 5x scaling should trigger seasoning recommendation
        );

        final recommendations = validation['recommendations'] as List<String>;
        expect(recommendations.any((rec) => rec.contains('seasonings')), isTrue);
      });
    });

    group('Statistics', () {
      test('Provides accurate scaling statistics', () {
        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: sampleRecipe,
          targetServings: 3,
        );

        final stats = scalingService.getScalingStatistics(scaledRecipe);

        expect(stats['originalServings'], equals(1));
        expect(stats['targetServings'], equals(3));
        expect(stats['scaleFactor'], equals(3.0));
        expect(stats.containsKey('overallConfidence'), isTrue);
        expect(stats.containsKey('scaledAt'), isTrue);
        expect(stats.containsKey('ingredientStats'), isTrue);

        final ingredientStats = stats['ingredientStats'];
        expect(ingredientStats['total'], equals(6)); // Number of ingredients in sample recipe
      });

      test('Handles unscaled recipes correctly', () {
        final stats = scalingService.getScalingStatistics(sampleRecipe);
        expect(stats.containsKey('error'), isTrue);
        expect(stats['error'], equals('Recipe has not been scaled'));
      });
    });

    group('Edge Cases', () {
      test('Handles recipes with no ingredients', () {
        final emptyRecipe = {
          "id": 1,
          "title": "Empty Recipe",
          "servings": 1,
          "extendedIngredients": <dynamic>[]
        };

        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: emptyRecipe,
          targetServings: 2,
        );

        expect(scaledRecipe['servings'], equals(2));
        expect((scaledRecipe['extendedIngredients'] as List).isEmpty, isTrue);
        expect(scaledRecipe['scalingMetadata']['overallConfidence'], equals(0.0));
      });

      test('Handles recipes with missing ingredient data', () {
        final incompleteRecipe = {
          "id": 1,
          "title": "Incomplete Recipe",
          "servings": 1,
          "extendedIngredients": [
            {
              "id": 1,
              "name": "mystery ingredient",
              // Missing amount and unit
            }
          ]
        };

        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: incompleteRecipe,
          targetServings: 2,
        );

        expect(scaledRecipe['servings'], equals(2));
        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        expect(scaledIngredients.length, equals(1));
        
        final ingredient = scaledIngredients.first;
        expect(ingredient['scalingMetadata']['confidence'], equals(0.0));
      });

      test('Handles very small amounts correctly', () {
        final smallAmountRecipe = {
          "id": 1,
          "title": "Small Amount Recipe",
          "servings": 8,
          "extendedIngredients": [
            {
              "id": 1,
              "name": "salt",
              "amount": 0.125,
              "unit": "teaspoon",
            }
          ]
        };

        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: smallAmountRecipe,
          targetServings: 1, // Scale down by 8x
        );

        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        final salt = scaledIngredients.first;
        
        // Should still have a reasonable amount, even if very small
        expect(salt['amount'], greaterThan(0.0));
        expect(salt['scalingMetadata']['confidence'], greaterThan(0.0));
      });
    });

    group('PRD Compliance', () {
      test('Meets PRD scaling accuracy requirements', () {
        // Test the PRD example: 450g ground turkey scaled by 0.375 → 169g
        final prdTestRecipe = {
          "id": 1,
          "title": "PRD Test Recipe",
          "servings": 8,
          "extendedIngredients": [
            {
              "id": 1,
              "name": "ground turkey",
              "amount": 450.0,
              "unit": "grams",
            }
          ]
        };

        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: prdTestRecipe,
          targetServings: 3, // 3/8 = 0.375 scaling factor
        );

        final scaledIngredients = scaledRecipe['extendedIngredients'] as List<dynamic>;
        final turkey = scaledIngredients.first;
        
        expect(turkey['amount'], closeTo(168.75, 1.0)); // 450 * 0.375 = 168.75
        expect(scaledRecipe['scalingMetadata']['scaleFactor'], closeTo(0.375, 0.001));
      });

      test('Achieves high confidence scores for standard conversions', () {
        final scaledRecipe = scalingService.scaleRecipe(
          originalRecipe: sampleRecipe,
          targetServings: 2,
        );

        // PRD target: ≥ 95% confidence for auto-conversions
        expect(scaledRecipe['scalingMetadata']['overallConfidence'], greaterThanOrEqualTo(95.0));
      });

      test('Performance meets PRD targets', () {
        final stopwatch = Stopwatch()..start();
        
        // Perform multiple scaling operations
        for (int i = 0; i < 100; i++) {
          scalingService.scaleRecipe(
            originalRecipe: sampleRecipe,
            targetServings: 2 + (i % 5), // Vary target servings
          );
        }
        
        stopwatch.stop();
        final averageTime = stopwatch.elapsedMilliseconds / 100;
        
        // PRD target: < 150ms per conversion (this should be much faster)
        expect(averageTime, lessThan(50.0)); // Allow 50ms per scaling operation
      });
    });
  });
} 