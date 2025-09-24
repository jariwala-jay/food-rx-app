import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';

void main() {
  group('Diet Assignment Matrix Tests', () {
    late PersonalizationService personalizationService;
    late NutritionContent nutritionContent;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      nutritionContent = await NutritionContentLoader.load();
      personalizationService = PersonalizationService(nutritionContent);
    });

    group('Diabetes + Hypertension Cases', () {
      test(
          'Diabetes + Hypertension + Overweight → DASH with 1500mg sodium, GI ≤69',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes', 'Hypertension', 'Obesity'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });

      test(
          'Diabetes + Hypertension + Normal Weight → DASH with 1500mg sodium, GI ≤69',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes', 'Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });
    });

    group('Diabetes Only Cases', () {
      test(
          'Diabetes + No Hypertension + Overweight → DASH with 1500mg sodium, GI ≤69',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });

      test(
          'Diabetes + No Hypertension + Normal Weight → DASH with 1500mg sodium, GI ≤69',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });

      test(
          'Pre-diabetes + No Hypertension + Overweight → DASH with 1500mg sodium, GI ≤69',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Pre-diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });
    });

    group('Hypertension Only Cases', () {
      test('No Diabetes + Hypertension + Overweight → DASH with 1500mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });

      test(
          'No Diabetes + Hypertension + Normal Weight → DASH with 1500mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });
    });

    group('Overweight Only Cases', () {
      test(
          'No Diabetes + No Hypertension + Overweight → MyPlate with 2300mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Obesity'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(2300));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('YES'));
        expect(dietRule['diet'], equals('MyPlate'));
        expect(dietRule['sodium_mg_max'], equals(2300));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });

      test(
          'No Diabetes + No Hypertension + Overweight with Weight Loss Goal → MyPlate with 2300mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(2300));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('YES'));
        expect(dietRule['diet'], equals('MyPlate'));
        expect(dietRule['sodium_mg_max'], equals(2300));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });
    });

    group('Healthy Cases', () {
      test(
          'No Diabetes + No Hypertension + Normal Weight → MyPlate with 2300mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: [],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(2300));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('NO'));
        expect(dietRule['diet'], equals('MyPlate'));
        expect(dietRule['sodium_mg_max'], equals(2300));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });

      test(
          'No Diabetes + No Hypertension + Normal Weight with Health Goals → MyPlate with 2300mg sodium',
          () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: [],
          healthGoals: ['Improve overall health', 'Build muscle'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(2300));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('NO'));
        expect(dietRule['hypertension'], equals('NO'));
        expect(dietRule['overweight_obese'], equals('NO'));
        expect(dietRule['diet'], equals('MyPlate'));
        expect(dietRule['sodium_mg_max'], equals(2300));
        expect(dietRule.containsKey('glycemic_index_max'), isFalse);
      });
    });

    group('Edge Cases', () {
      test('Multiple conditions with diabetes priority → DASH', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: [
            'Diabetes',
            'Hypertension',
            'Obesity',
            'High Cholesterol'
          ],
          healthGoals: ['Weight loss', 'Lower blood pressure'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['overweight_obese'], equals('ANY'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });

      test('Case insensitive condition matching', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['DIABETES', 'HYPERTENSION'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });

      test('Partial condition matching', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Type 2 Diabetes', 'Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        final dietRule =
            result.diagnostics['diet_rule'] as Map<String, dynamic>;
        expect(dietRule['diabetes_prediabetes'], equals('YES'));
        expect(dietRule['hypertension'], equals('YES'));
        expect(dietRule['diet'], equals('DASH'));
        expect(dietRule['sodium_mg_max'], equals(1500));
        expect(dietRule['glycemic_index_max'], equals(69));
      });
    });

    group('Weight Loss Scenarios', () {
      test('DASH with weight loss goal → step-down calories', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(1500));

        // Should have step-down calories for weight loss
        final diagnostics = result.diagnostics;
        expect(diagnostics.containsKey('maintenance'), isTrue);
        expect(diagnostics.containsKey('tier'), isTrue);
        expect(result.targetCalories, lessThan(diagnostics['maintenance']));
      });

      test('MyPlate with weight loss goal → TDEE - 500', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan['sodium_mg_per_day_max'], equals(2300));

        // Should have TDEE - 500 for weight loss
        final diagnostics = result.diagnostics;
        expect(diagnostics.containsKey('tdee'), isTrue);
        expect(result.targetCalories, lessThan(diagnostics['tdee']));
      });
    });

    group('Gender-Specific Tests', () {
      test('Female DASH step-down respects female floor (1200)', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 4.0,
          weightLb: 200.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.targetCalories, greaterThanOrEqualTo(1200));
      });

      test('Male DASH step-down respects male floor (1500)', () {
        final result = personalizationService.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 200.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.targetCalories, greaterThanOrEqualTo(1500));
      });
    });
  });
}
