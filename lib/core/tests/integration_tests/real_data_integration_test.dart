import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/recipe_scaling_service.dart';
import '../test_data/spoonacular_recipe_search_response.dart';

void main() {
  group('Real Data Integration Tests', () {
    late UnitConversionService unitConversionService;
    late RecipeScalingService recipeScalingService;

    setUp(() {
      unitConversionService = UnitConversionService();
      recipeScalingService = RecipeScalingService(conversionService: unitConversionService);
    });

    group('Recipe Scaling with Real Spoonacular Data', () {
      test('should scale Chicken Ranch Burgers recipe', () {
        // Use real Spoonacular data
        final recipe = SpoonacularTestData.createMockRecipeForScaling(991010);
        
        final result = recipeScalingService.scaleRecipe(
          originalRecipe: recipe,
          targetServings: 6,
        );

        expect(result['servings'], 6);
        expect(result['scalingMetadata']['scaleFactor'], 1.5);
        expect(result['scalingMetadata']['overallConfidence'], greaterThan(0.9));
        
        // Verify specific ingredients were scaled
        final scaledIngredients = result['extendedIngredients'] as List;
        final bellPepper = scaledIngredients.firstWhere(
          (ingredient) => ingredient['name'] == 'bell pepper',
        );
        expect(bellPepper['amount'], 0.75); // 0.5 * 1.5
        
        final chicken = scaledIngredients.firstWhere(
          (ingredient) => ingredient['name'] == 'chicken',
        );
        expect(chicken['amount'], 1.5); // 1 * 1.5
      });

      test('should scale Apple Cheddar Turkey Burgers recipe', () {
        final recipe = SpoonacularTestData.createMockRecipeForScaling(632502);
        
        final result = recipeScalingService.scaleRecipe(
          originalRecipe: recipe,
          targetServings: 2,
        );

        expect(result['servings'], 2);
        expect(result['scalingMetadata']['scaleFactor'], 0.5);
        
        // Verify ground turkey scaling
        final scaledIngredients = result['extendedIngredients'] as List;
        final groundTurkey = scaledIngredients.firstWhere(
          (ingredient) => ingredient['name'] == 'ground turkey',
        );
        expect(groundTurkey['amount'], 0.5); // 1 * 0.5
      });

      test('should handle large batch scaling (8x)', () {
        final recipe = SpoonacularTestData.createMockRecipeForScaling(991010);
        
        final result = recipeScalingService.scaleRecipe(
          originalRecipe: recipe,
          targetServings: 32, // 8x scaling
        );

        expect(result['scalingMetadata']['scaleFactor'], 8.0);
        
        // Verify seasoning adjustment for large batches
        final scaledIngredients = result['extendedIngredients'] as List;
        final ranchSeasoning = scaledIngredients.firstWhere(
          (ingredient) => ingredient['name'] == 'ranch seasoning',
        );
        
        // Ranch seasoning should be scaled down for large batches
        expect(ranchSeasoning['amount'], lessThan(8.0)); // Less than full 8x scaling
        expect(ranchSeasoning['scalingMetadata']['seasoningAdjusted'], true);
      });
    });

    group('Unit Conversion with Real Ingredients', () {
      test('should convert chicken from pounds to grams', () {
        final result = unitConversionService.convert(
          amount: 1.0,
          fromUnit: 'lb',
          toUnit: 'g',
          ingredientName: 'chicken',
        );

        expect(result, closeTo(453.6, 5)); // 1 lb ≈ 453.6g
        
        // Test with confidence method
        final withConfidence = unitConversionService.convertWithConfidence(
          amount: 1.0,
          fromUnit: 'lb',
          toUnit: 'g',
          ingredientName: 'chicken',
        );
        expect(withConfidence['confidence'], greaterThan(0.9));
      });

      test('should convert bell pepper from medium to grams', () {
        final result = unitConversionService.convert(
          amount: 0.5,
          fromUnit: 'medium',
          toUnit: 'g',
          ingredientName: 'bell pepper',
        );

        expect(result, greaterThan(0));
        
        // Test with confidence method
        final withConfidence = unitConversionService.convertWithConfidence(
          amount: 0.5,
          fromUnit: 'medium',
          toUnit: 'g',
          ingredientName: 'bell pepper',
        );
        expect(withConfidence['confidence'], greaterThan(0.8));
      });

      test('should convert bread crumbs from cups to grams', () {
        final result = unitConversionService.convert(
          amount: 0.5,
          fromUnit: 'cup',
          toUnit: 'g',
          ingredientName: 'bread crumbs',
        );

        expect(result, greaterThan(0));
        
        // Test with confidence method
        final withConfidence = unitConversionService.convertWithConfidence(
          amount: 0.5,
          fromUnit: 'cup',
          toUnit: 'g',
          ingredientName: 'bread crumbs',
        );
        expect(withConfidence['confidence'], greaterThan(0.9));
      });
    });

    group('Cross-Service Integration', () {
      test('should scale recipe and convert units for pantry deduction', () {
        final recipe = SpoonacularTestData.createMockRecipeForScaling(632502);
        
        // First scale the recipe
        final scalingResult = recipeScalingService.scaleRecipe(
          originalRecipe: recipe,
          targetServings: 6,
        );

        expect(scalingResult['servings'], 6);
        
        // Then convert ingredients to grams for pantry deduction
        final scaledIngredients = scalingResult['extendedIngredients'] as List;
        final conversions = <String, double>{};
        
        for (final ingredient in scaledIngredients) {
          final amount = ingredient['amount'] as double;
          final unit = ingredient['unit'] as String;
          final name = ingredient['name'] as String;
          
          if (unit.isNotEmpty && unit != 'serving') {
            final conversionResult = unitConversionService.convert(
              amount: amount,
              fromUnit: unit,
              toUnit: 'g',
              ingredientName: name,
            );
            
            if (conversionResult > 0) {
              conversions[name] = conversionResult;
            }
          }
        }
        
        // Verify we got meaningful conversions
        expect(conversions.isNotEmpty, true);
        expect(conversions.values.every((amount) => amount > 0), true);
      });
    });

    group('Performance Tests with Real Data', () {
      test('should scale multiple recipes within performance targets', () {
        final stopwatch = Stopwatch()..start();
        
        // Scale all available recipes
        final recipeIds = SpoonacularTestData.getAllRecipeIds();
        final results = <int, dynamic>{};
        
        for (final id in recipeIds.take(3)) { // Test first 3 recipes
          final recipe = SpoonacularTestData.createMockRecipeForScaling(id);
          final result = recipeScalingService.scaleRecipe(
            originalRecipe: recipe,
            targetServings: 6,
          );
          results[id] = result;
        }
        
        stopwatch.stop();
        
        // Verify all succeeded (check if servings were properly set)
        expect(results.values.every((result) => result['servings'] == 6), true);
        
        // Verify performance (should be well under 150ms per recipe as per PRD)
        final averageTime = stopwatch.elapsedMilliseconds / results.length;
        expect(averageTime, lessThan(150));
        
        print('Average scaling time: ${averageTime.toStringAsFixed(2)}ms');
      });
    });

    group('Data Validation Tests', () {
      test('should validate all test recipes have required fields', () {
        final recipeIds = SpoonacularTestData.getAllRecipeIds();
        
        for (final id in recipeIds) {
          final recipe = SpoonacularTestData.getRecipeById(id);
          
          // Verify required fields exist
          expect(recipe['id'], isNotNull);
          expect(recipe['title'], isNotNull);
          expect(recipe['calories'], isNotNull);
          expect(recipe['protein'], isNotNull);
          expect(recipe['fat'], isNotNull);
          expect(recipe['carbs'], isNotNull);
          
          // Verify ingredients structure
          expect(recipe['missedIngredients'], isA<List>());
          expect(recipe['usedIngredients'], isA<List>());
          
          // Verify each ingredient has required fields
          final allIngredients = [
            ...recipe['missedIngredients'] as List<dynamic>,
            ...recipe['usedIngredients'] as List<dynamic>,
          ];
          
          for (final ingredient in allIngredients) {
            expect(ingredient['id'], isNotNull);
            expect(ingredient['name'], isNotNull);
            expect(ingredient['amount'], isNotNull);
            expect(ingredient['unit'], isNotNull);
            expect(ingredient['original'], isNotNull);
          }
        }
      });
    });
  });
} 