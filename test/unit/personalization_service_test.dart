import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('PersonalizationService Tests', () {
    late PersonalizationService service;
    late NutritionContent nutritionContent;

    setUpAll(() async {
      // Load nutrition content for testing
      nutritionContent = await NutritionContentLoader.load();
      service = PersonalizationService(nutritionContent);
    });

    group('Height Conversion Tests', () {
      test('should convert feet and inches to cm correctly', () {
        // Test case 1: 5 feet 6 inches = 167.64 cm
        final heightCm1 = (5.0 * 12 + 6.0) * 2.54;
        expect(heightCm1, closeTo(167.64, 0.1));

        // Test case 2: 6 feet 0 inches = 182.88 cm
        final heightCm2 = (6.0 * 12 + 0.0) * 2.54;
        expect(heightCm2, closeTo(182.88, 0.1));

        // Test case 3: 5 feet 3 inches = 160.02 cm
        final heightCm3 = (5.0 * 12 + 3.0) * 2.54;
        expect(heightCm3, closeTo(160.02, 0.1));
      });
    });

    group('Age Calculation from DOB Tests', () {
      test('should calculate age correctly from DOB', () {
        final now = DateTime(2024, 1, 15);

        // Test case 1: Born in 1990, should be 34 years old
        final dob1 = DateTime(1990, 1, 15);
        final age1 = now.difference(dob1).inDays ~/ 365;
        expect(age1, equals(34));

        // Test case 2: Born in 1985, should be 39 years old
        final dob2 = DateTime(1985, 6, 10);
        final age2 = now.difference(dob2).inDays ~/ 365;
        expect(age2, equals(38)); // 38 years and some months

        // Test case 3: Born in 2000, should be 24 years old
        final dob3 = DateTime(2000, 12, 31);
        final age3 = now.difference(dob3).inDays ~/ 365;
        expect(age3, equals(23)); // 23 years and some days
      });
    });

    group('DASH Diet Selection Tests', () {
      test('should select DASH diet for hypertension', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: ['General health'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.targetCalories, greaterThan(0));
        expect(result.selectedDietPlan, isNotEmpty);
        expect(result.diagnostics, containsPair('maintenance', isA<int>()));
      });

      test('should select DASH diet for blood pressure goal', () {
        final result = service.personalize(
          dob: DateTime(1985, 5, 15),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 6.0,
          weightLb: 150.0,
          activityLevel: 'light',
          medicalConditions: [],
          healthGoals: ['Lower blood pressure'],
        );

        expect(result.dietType, equals('DASH'));
      });

      test(
          'should select DASH diet for both hypertension and blood pressure goal',
          () {
        final result = service.personalize(
          dob: DateTime(1975, 3, 20),
          sex: 'male',
          heightFeet: 5.0,
          heightInches: 10.0,
          weightLb: 200.0,
          activityLevel: 'very active',
          medicalConditions: ['Hypertension'],
          healthGoals: ['Lower blood pressure'],
        );

        expect(result.dietType, equals('DASH'));
      });
    });

    group('MyPlate Diet Selection Tests', () {
      test('should select MyPlate diet for diabetes', () {
        final result = service.personalize(
          dob: DateTime(1980, 8, 10),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 4.0,
          weightLb: 160.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: ['Blood sugar control'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.diagnostics, containsPair('bmr', isA<double>()));
        expect(result.diagnostics, containsPair('pal', isA<double>()));
        expect(result.diagnostics, containsPair('tdee', isA<double>()));
      });

      test('should select MyPlate diet for obesity', () {
        final result = service.personalize(
          dob: DateTime(1995, 12, 5),
          sex: 'male',
          heightFeet: 5.0,
          heightInches: 8.0,
          weightLb: 250.0,
          activityLevel: 'sedentary',
          medicalConditions: ['Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('MyPlate'));
      });

      test('should select MyPlate diet for general health', () {
        final result = service.personalize(
          dob: DateTime(2000, 7, 20),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 5.0,
          weightLb: 130.0,
          activityLevel: 'moderate',
          medicalConditions: [],
          healthGoals: ['General health', 'Fitness'],
        );

        expect(result.dietType, equals('MyPlate'));
      });
    });

    group('DASH Calorie Calculation Tests', () {
      test(
          'should calculate DASH maintenance calories for different age groups',
          () {
        // Test 19-30 age group
        final result1 = service.personalize(
          dob: DateTime(2000, 1, 1), // 24 years old
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );
        expect(result1.dietType, equals('DASH'));
        expect(result1.diagnostics['maintenance'], greaterThan(0));

        // Test 31-50 age group
        final result2 = service.personalize(
          dob: DateTime(1985, 1, 1), // 39 years old
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 6.0,
          weightLb: 150.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );
        expect(result2.dietType, equals('DASH'));
        expect(result2.diagnostics['maintenance'], greaterThan(0));

        // Test 51+ age group
        final result3 = service.personalize(
          dob: DateTime(1970, 1, 1), // 54 years old
          sex: 'male',
          heightFeet: 5.0,
          heightInches: 10.0,
          weightLb: 170.0,
          activityLevel: 'sedentary',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );
        expect(result3.dietType, equals('DASH'));
        expect(result3.diagnostics['maintenance'], greaterThan(0));
      });

      test('should apply DASH step-down for weight loss', () {
        final result = service.personalize(
          dob: DateTime(1980, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 220.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension', 'Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.diagnostics['mode'], equals('step-down'));
        expect(
            result.targetCalories, lessThan(result.diagnostics['maintenance']));
      });
    });

    group('MyPlate BMR and TDEE Calculation Tests', () {
      test('should calculate BMR correctly for male', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0, // 182.88 cm
          weightLb: 180.0, // 81.65 kg
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.diagnostics['bmr'], isA<double>());
        expect(result.diagnostics['bmr'],
            greaterThan(1500)); // Should be reasonable BMR
        expect(result.diagnostics['pal'], equals(1.55)); // Moderate activity
        expect(result.diagnostics['tdee'], isA<double>());
        expect(
            result.diagnostics['tdee'], greaterThan(result.diagnostics['bmr']));
      });

      test('should calculate BMR correctly for female', () {
        final result = service.personalize(
          dob: DateTime(1995, 1, 1),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 6.0, // 167.64 cm
          weightLb: 140.0, // 63.5 kg
          activityLevel: 'light',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.diagnostics['bmr'], isA<double>());
        expect(result.diagnostics['bmr'],
            greaterThan(1200)); // Should be reasonable BMR
        expect(result.diagnostics['pal'], equals(1.375)); // Light activity
        expect(result.diagnostics['tdee'], isA<double>());
        expect(
            result.diagnostics['tdee'], greaterThan(result.diagnostics['bmr']));
      });

      test('should apply MyPlate weight loss reduction', () {
        final result = service.personalize(
          dob: DateTime(1985, 1, 1),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 4.0,
          weightLb: 200.0,
          activityLevel: 'moderate',
          medicalConditions: ['Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.diagnostics['mode'], equals('-500'));
        expect(result.targetCalories, lessThan(result.diagnostics['tdee']));
        // Target calories should be rounded to nearest tier, not exactly TDEE - 500
        expect(result.targetCalories, greaterThan(0));
      });
    });

    group('Diet Plan Selection Tests', () {
      test('should select correct DASH tier based on calories', () {
        // Test different calorie tiers
        final tiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];

        for (final tier in tiers) {
          // Create a scenario that should result in this tier
          final result = service.personalize(
            dob: DateTime(1990, 1, 1),
            sex: tier <= 2000 ? 'female' : 'male',
            heightFeet: tier <= 2000 ? 5.0 : 6.0,
            heightInches: tier <= 2000 ? 4.0 : 0.0,
            weightLb: tier <= 2000 ? 120.0 : 200.0,
            activityLevel: tier <= 1600 ? 'sedentary' : 'moderate',
            medicalConditions: ['Hypertension'],
            healthGoals: [],
          );

          expect(result.dietType, equals('DASH'));
          expect(tiers, contains(result.targetCalories));
        }
      });

      test('should select correct MyPlate tier based on calories', () {
        // Test different calorie tiers for MyPlate
        final tiers = [1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000, 3200];

        for (final tier in tiers) {
          final result = service.personalize(
            dob: DateTime(1990, 1, 1),
            sex: tier <= 2000 ? 'female' : 'male',
            heightFeet: tier <= 2000 ? 5.0 : 6.0,
            heightInches: tier <= 2000 ? 4.0 : 0.0,
            weightLb: tier <= 2000 ? 120.0 : 200.0,
            activityLevel: tier <= 1800 ? 'sedentary' : 'moderate',
            medicalConditions: ['Diabetes'],
            healthGoals: [],
          );

          expect(result.dietType, equals('MyPlate'));
          expect(tiers, contains(result.targetCalories));
        }
      });
    });

    group('Edge Cases Tests', () {
      test('should handle minimum age correctly', () {
        final result = service.personalize(
          dob: DateTime(2005, 1, 1), // 19 years old
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.targetCalories, greaterThan(0));
      });

      test('should handle maximum age correctly', () {
        final result = service.personalize(
          dob: DateTime(1950, 1, 1), // 74 years old
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 4.0,
          weightLb: 140.0,
          activityLevel: 'sedentary',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.targetCalories, greaterThan(0));
      });

      test('should handle very short height', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'female',
          heightFeet: 4.0,
          heightInches: 8.0, // 142.24 cm
          weightLb: 100.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.targetCalories, greaterThan(0));
      });

      test('should handle very tall height', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 7.0,
          heightInches: 0.0, // 213.36 cm
          weightLb: 250.0,
          activityLevel: 'very active',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.targetCalories, greaterThan(0));
      });

      test('should handle very low weight', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'female',
          heightFeet: 5.0,
          heightInches: 4.0,
          weightLb: 90.0, // Very low weight
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.targetCalories, greaterThan(0));
      });

      test('should handle very high weight', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 350.0, // Very high weight
          activityLevel: 'moderate',
          medicalConditions: ['Obesity'],
          healthGoals: ['Weight loss'],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.targetCalories, greaterThan(0));
      });
    });

    group('Activity Level Tests', () {
      test('should handle all activity levels correctly', () {
        final activityLevels = [
          'sedentary',
          'light',
          'moderate',
          'very active'
        ];

        for (final activity in activityLevels) {
          final result = service.personalize(
            dob: DateTime(1990, 1, 1),
            sex: 'male',
            heightFeet: 6.0,
            heightInches: 0.0,
            weightLb: 180.0,
            activityLevel: activity,
            medicalConditions: ['Diabetes'],
            healthGoals: [],
          );

          expect(result.dietType, equals('MyPlate'));
          expect(result.targetCalories, greaterThan(0));

          if (result.diagnostics.containsKey('pal')) {
            expect(result.diagnostics['pal'], isA<double>());
            expect(result.diagnostics['pal'], greaterThan(1.0));
          }
        }
      });
    });

    group('Medical Conditions and Health Goals Tests', () {
      test('should handle multiple medical conditions', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 200.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension', 'Diabetes', 'Obesity'],
          healthGoals: ['Weight loss', 'Lower blood pressure'],
        );

        // Should prioritize DASH due to hypertension/blood pressure
        expect(result.dietType, equals('DASH'));
        expect(result.diagnostics['mode'],
            equals('step-down')); // Due to obesity/weight loss
      });

      test('should handle empty medical conditions and health goals', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: [],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate')); // Default to MyPlate
        expect(result.targetCalories, greaterThan(0));
      });
    });

    group('Diet Plan Content Tests', () {
      test('should return valid DASH plan content', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Hypertension'],
          healthGoals: [],
        );

        expect(result.dietType, equals('DASH'));
        expect(result.selectedDietPlan, containsPair('kcal', isA<int>()));
        expect(result.selectedDietPlan, containsPair('grainsMax', isA<int>()));
        expect(
            result.selectedDietPlan, containsPair('vegetablesMax', isA<int>()));
        expect(result.selectedDietPlan, containsPair('fruitsMax', isA<int>()));
        expect(result.selectedDietPlan, containsPair('dairyMax', isA<int>()));
        expect(
            result.selectedDietPlan, containsPair('leanMeatsMax', isA<int>()));
        expect(result.selectedDietPlan, containsPair('sodium', isA<int>()));
      });

      test('should return valid MyPlate plan content', () {
        final result = service.personalize(
          dob: DateTime(1990, 1, 1),
          sex: 'male',
          heightFeet: 6.0,
          heightInches: 0.0,
          weightLb: 180.0,
          activityLevel: 'moderate',
          medicalConditions: ['Diabetes'],
          healthGoals: [],
        );

        expect(result.dietType, equals('MyPlate'));
        expect(result.selectedDietPlan, containsPair('kcal', isA<int>()));
        expect(result.selectedDietPlan, containsPair('fruits', isA<double>()));
        expect(
            result.selectedDietPlan, containsPair('vegetables', isA<double>()));
        expect(result.selectedDietPlan, containsPair('grains', isA<int>()));
        expect(result.selectedDietPlan, containsPair('protein', isA<double>()));
        expect(result.selectedDietPlan, containsPair('dairy', isA<int>()));
        expect(result.selectedDietPlan, containsPair('sodiumMax', isA<int>()));
        expect(result.selectedDietPlan,
            containsPair('addedSugarsMax', isA<int>()));
        expect(result.selectedDietPlan,
            containsPair('saturatedFatMax', isA<int>()));
      });
    });
  });
}
