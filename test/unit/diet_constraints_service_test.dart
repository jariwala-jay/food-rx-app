import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/diet_constraints_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';

void main() {
  group('DietConstraintsService Tests', () {
    late DietConstraintsService constraintsService;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final nutritionContent = await NutritionContentLoader.load();
      constraintsService = DietConstraintsService();
      // Manually set the content for testing
      constraintsService.setContentForTesting(nutritionContent);
    });

    group('Constraint Generation', () {
      test('Diabetes + Hypertension rule generates correct constraints',
          () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        expect(constraints['maxSodiumPerDay'], equals(1500));
        expect(constraints['maxSodiumPerServing'], equals(500)); // 1500/3
        expect(constraints['maxGlycemicIndex'], equals(69));
        expect(constraints['maxSaturatedFatPerServing'], equals(8));
        expect(constraints['minFiberPerServing'], equals(2));
        expect(constraints['minPotassiumPerServing'], equals(300));
        expect(constraints['veryHealthy'], isTrue);
        expect(constraints['lowFat'], isTrue);
      });

      test('Diabetes only rule generates correct constraints', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'NO',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        expect(constraints['maxSodiumPerDay'], equals(1500));
        expect(constraints['maxSodiumPerServing'], equals(500));
        expect(constraints['maxGlycemicIndex'], equals(69));
        expect(constraints['maxSaturatedFatPerServing'], equals(8));
        expect(constraints['minFiberPerServing'], equals(2));
        expect(constraints['minPotassiumPerServing'], equals(300));
        expect(constraints['veryHealthy'], isTrue);
        expect(constraints['lowFat'], isTrue);
      });

      test('Hypertension only rule generates correct constraints', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        expect(constraints['maxSodiumPerDay'], equals(1500));
        expect(constraints['maxSodiumPerServing'], equals(500));
        expect(constraints.containsKey('maxGlycemicIndex'), isFalse);
        expect(constraints['maxSaturatedFatPerServing'], equals(8));
        expect(constraints['minFiberPerServing'], equals(2));
        expect(constraints['minPotassiumPerServing'], equals(300));
        expect(constraints['veryHealthy'], isTrue);
        expect(constraints['lowFat'], isTrue);
      });

      test('MyPlate rule generates correct constraints', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        expect(constraints['maxSodiumPerDay'], equals(2300));
        expect(
            constraints['maxSodiumPerServing'], equals(767)); // 2300/3 rounded
        expect(constraints.containsKey('maxGlycemicIndex'), isFalse);
        expect(constraints['maxSaturatedFatPerServing'], equals(10));
        expect(constraints['maxSugarPerServing'], equals(30));
        expect(constraints['maxCaloriesPerServing'], equals(600));
        expect(constraints['veryHealthy'], isTrue);
        expect(constraints['balancedNutrition'], isTrue);
      });
    });

    group('Spoonacular API Parameters', () {
      test('DASH rule generates correct Spoonacular parameters', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final params = await constraintsService.getSpoonacularConstraints(rule);

        expect(params['maxSodium'], equals('500'));
        expect(params['veryHealthy'], equals('true'));
      });

      test('MyPlate rule generates correct Spoonacular parameters', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final params = await constraintsService.getSpoonacularConstraints(rule);

        expect(params['maxSodium'], equals('767'));
        expect(params['veryHealthy'], equals('true'));
      });
    });

    group('Recipe Validation', () {
      test('Valid DASH recipe passes validation', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {'name': 'Glycemic Index', 'amount': 45.0, 'unit': ''},
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            {'name': 'Fiber', 'amount': 4.0, 'unit': 'g'},
            {'name': 'Potassium', 'amount': 500.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('Invalid DASH recipe fails validation - high sodium', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {
              'name': 'Sodium',
              'amount': 600.0,
              'unit': 'mg'
            }, // Exceeds 500mg limit
            {'name': 'Glycemic Index', 'amount': 45.0, 'unit': ''},
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            {'name': 'Fiber', 'amount': 4.0, 'unit': 'g'},
            {'name': 'Potassium', 'amount': 500.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid DASH recipe fails validation - high glycemic index',
          () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {
              'name': 'Glycemic Index',
              'amount': 75.0,
              'unit': ''
            }, // Exceeds 69 limit
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            {'name': 'Fiber', 'amount': 4.0, 'unit': 'g'},
            {'name': 'Potassium', 'amount': 500.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid DASH recipe fails validation - high saturated fat',
          () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {'name': 'Glycemic Index', 'amount': 45.0, 'unit': ''},
            {
              'name': 'Saturated Fat',
              'amount': 10.0,
              'unit': 'g'
            }, // Exceeds 8g limit
            {'name': 'Fiber', 'amount': 4.0, 'unit': 'g'},
            {'name': 'Potassium', 'amount': 500.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid DASH recipe fails validation - low fiber', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {'name': 'Glycemic Index', 'amount': 45.0, 'unit': ''},
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            {'name': 'Fiber', 'amount': 1.0, 'unit': 'g'}, // Below 2g minimum
            {'name': 'Potassium', 'amount': 500.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid DASH recipe fails validation - low potassium', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {'name': 'Glycemic Index', 'amount': 45.0, 'unit': ''},
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            {'name': 'Fiber', 'amount': 4.0, 'unit': 'g'},
            {
              'name': 'Potassium',
              'amount': 200.0,
              'unit': 'mg'
            }, // Below 300mg minimum
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Valid MyPlate recipe passes validation', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 600.0, 'unit': 'mg'},
            {'name': 'Saturated Fat', 'amount': 8.0, 'unit': 'g'},
            {'name': 'Sugar', 'amount': 20.0, 'unit': 'g'},
            {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('Invalid MyPlate recipe fails validation - high sodium', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {
              'name': 'Sodium',
              'amount': 800.0,
              'unit': 'mg'
            }, // Exceeds 767mg limit
            {'name': 'Saturated Fat', 'amount': 8.0, 'unit': 'g'},
            {'name': 'Sugar', 'amount': 20.0, 'unit': 'g'},
            {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid MyPlate recipe fails validation - high saturated fat',
          () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 600.0, 'unit': 'mg'},
            {
              'name': 'Saturated Fat',
              'amount': 12.0,
              'unit': 'g'
            }, // Exceeds 10g limit
            {'name': 'Sugar', 'amount': 20.0, 'unit': 'g'},
            {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid MyPlate recipe fails validation - high sugar', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 600.0, 'unit': 'mg'},
            {'name': 'Saturated Fat', 'amount': 8.0, 'unit': 'g'},
            {'name': 'Sugar', 'amount': 35.0, 'unit': 'g'}, // Exceeds 30g limit
            {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('Invalid MyPlate recipe fails validation - high calories', () async {
        final rule = {
          'diabetes_prediabetes': 'NO',
          'hypertension': 'NO',
          'overweight_obese': 'YES',
          'diet': 'MyPlate',
          'sodium_mg_max': 2300
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 600.0, 'unit': 'mg'},
            {'name': 'Saturated Fat', 'amount': 8.0, 'unit': 'g'},
            {'name': 'Sugar', 'amount': 20.0, 'unit': 'g'},
            {
              'name': 'Calories',
              'amount': 700.0,
              'unit': 'kcal'
            }, // Exceeds 600kcal limit
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });
    });

    group('Edge Cases', () {
      test('Recipe with missing nutrition data passes validation', () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [] // Empty nutrition data
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue); // Should pass when nutrition data is missing
      });

      test('Recipe with partial nutrition data validates available nutrients',
          () async {
        final rule = {
          'diabetes_prediabetes': 'YES',
          'hypertension': 'YES',
          'overweight_obese': 'ANY',
          'diet': 'DASH',
          'sodium_mg_max': 1500,
          'glycemic_index_max': 69
        };

        final constraints =
            await constraintsService.getConstraintsForRule(rule);

        final recipeNutrition = {
          'nutrients': [
            {'name': 'Sodium', 'amount': 400.0, 'unit': 'mg'},
            {'name': 'Saturated Fat', 'amount': 5.0, 'unit': 'g'},
            // Missing Glycemic Index, Fiber, Potassium
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue); // Should pass for available nutrients
      });
    });
  });
}
