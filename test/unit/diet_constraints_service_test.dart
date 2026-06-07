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
        expect(constraints['maxSodiumPerServing'], equals(500));
        expect(constraints['maxGlycemicIndex'], equals(69));
        expect(constraints['veryHealthy'], isTrue);
        expect(constraints['lowFat'], isTrue);
        // Note: maxSaturatedFatPerServing, minFiberPerServing, minPotassiumPerServing
        // were removed in refactor (streamline diet constraints, Oct 2025)
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
        expect(constraints['maxSodiumPerServing'], equals(767));
        expect(constraints.containsKey('maxGlycemicIndex'), isFalse);
        expect(constraints['veryHealthy'], isTrue);
        // Note: maxSaturatedFatPerServing, maxSugarPerServing, maxCaloriesPerServing,
        // balancedNutrition were removed in refactor (streamline diet constraints, Oct 2025)
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
            {'name': 'Sodium', 'amount': 600.0, 'unit': 'mg'},
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
            {'name': 'Glycemic Index', 'amount': 75.0, 'unit': ''},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('DASH recipe with high saturated fat passes — constraint removed',
          () async {
        // maxSaturatedFatPerServing was removed in refactor (Oct 2025)
        // Recipe with high sat fat now passes DASH validation
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
            {'name': 'Saturated Fat', 'amount': 10.0, 'unit': 'g'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('DASH recipe with low fiber passes — constraint removed', () async {
        // minFiberPerServing was removed in refactor (Oct 2025)
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
            {'name': 'Fiber', 'amount': 1.0, 'unit': 'g'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('DASH recipe with low potassium passes — constraint removed',
          () async {
        // minPotassiumPerServing was removed in refactor (Oct 2025)
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
            {'name': 'Potassium', 'amount': 200.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
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
            {'name': 'Sodium', 'amount': 800.0, 'unit': 'mg'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isFalse);
      });

      test('MyPlate recipe with high saturated fat passes — constraint removed',
          () async {
        // maxSaturatedFatPerServing was removed in refactor (Oct 2025)
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
            {'name': 'Saturated Fat', 'amount': 12.0, 'unit': 'g'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('MyPlate recipe with high sugar passes — constraint removed',
          () async {
        // maxSugarPerServing was removed in refactor (Oct 2025)
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
            {'name': 'Sugar', 'amount': 35.0, 'unit': 'g'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });

      test('MyPlate recipe with high calories passes — constraint removed',
          () async {
        // maxCaloriesPerServing was removed in refactor (Oct 2025)
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
            {'name': 'Calories', 'amount': 700.0, 'unit': 'kcal'},
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
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

        final recipeNutrition = {'nutrients': []};

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
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
          ]
        };

        final isValid = await constraintsService.validateRecipe(
            recipeNutrition, constraints);
        expect(isValid, isTrue);
      });
    });
  });
}
