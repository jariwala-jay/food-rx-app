import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NutritionContentLoader Tests', () {
    test('should load DASH calorie map correctly', () async {
      final content = await NutritionContentLoader.load();

      expect(content.dashCalorieMap, isA<Map<String, dynamic>>());
      expect(content.dashCalorieMap,
          containsPair('data', isA<Map<String, dynamic>>()));

      final data = content.dashCalorieMap['data'] as Map<String, dynamic>;
      expect(data, containsPair('women', isA<Map<String, dynamic>>()));
      expect(data, containsPair('men', isA<Map<String, dynamic>>()));

      // Test women's data structure
      final womenData = data['women'] as Map<String, dynamic>;
      expect(womenData, containsPair('19-30', isA<Map<String, dynamic>>()));
      expect(womenData, containsPair('31-50', isA<Map<String, dynamic>>()));
      expect(womenData, containsPair('51+', isA<Map<String, dynamic>>()));

      // Test men's data structure
      final menData = data['men'] as Map<String, dynamic>;
      expect(menData, containsPair('19-30', isA<Map<String, dynamic>>()));
      expect(menData, containsPair('31-50', isA<Map<String, dynamic>>()));
      expect(menData, containsPair('51+', isA<Map<String, dynamic>>()));

      // Test specific calorie values for women 19-30
      final women19_30 = womenData['19-30'] as Map<String, dynamic>;
      expect(women19_30, containsPair('sedentary', 2000));
      expect(women19_30, containsPair('moderate', 2000));
      expect(women19_30, containsPair('active', 2400));

      // Test specific calorie values for men 19-30
      final men19_30 = menData['19-30'] as Map<String, dynamic>;
      expect(men19_30, containsPair('sedentary', 2400));
      expect(men19_30, containsPair('moderate', 2600));
      expect(men19_30, containsPair('active', 3000));
    });

    test('should load diet assignment rules correctly', () async {
      final content = await NutritionContentLoader.load();

      expect(content.dietAssignmentRules, isA<List<dynamic>>());
      expect(content.dietAssignmentRules.length, greaterThan(0));

      // Test that rules have required fields
      for (final rule in content.dietAssignmentRules) {
        expect(rule, containsPair('diabetes_prediabetes', isA<String>()));
        expect(rule, containsPair('hypertension', isA<String>()));
        expect(rule, containsPair('overweight_obese', isA<String>()));
        expect(rule, containsPair('diet', isA<String>()));
        expect(rule['diet'], isIn(['DASH', 'MyPlate']));
      }

      // Test specific rule: DM=YES, HTN=YES should be DASH with 1500 sodium
      final dmHtnRule = content.dietAssignmentRules.firstWhere((rule) =>
          rule['diabetes_prediabetes'] == 'YES' &&
          rule['hypertension'] == 'YES');
      expect(dmHtnRule['diet'], equals('DASH'));
      expect(dmHtnRule['sodium_mg_max'], equals(1500));
    });

    test('should load DASH servings correctly', () async {
      final content = await NutritionContentLoader.load();

      expect(content.dashServings, isA<List<dynamic>>());
      expect(content.dashServings.length, greaterThan(0));

      // Test first entry (1200 kcal)
      final firstEntry = content.dashServings[0] as Map<String, dynamic>;
      expect(firstEntry, containsPair('kcal', 1200));
      expect(firstEntry, containsPair('grainsMax', isA<int>()));
      expect(firstEntry, containsPair('vegetablesMax', isA<int>()));
      expect(firstEntry, containsPair('fruitsMax', isA<int>()));
      expect(firstEntry, containsPair('dairyMax', isA<int>()));
      expect(firstEntry, containsPair('leanMeatsMax', isA<int>()));
      expect(firstEntry, containsPair('sodium', isA<int>()));

      // Verify no minimum values exist
      expect(firstEntry, isNot(containsPair('grainsMin', anything)));
      expect(firstEntry, isNot(containsPair('vegetablesMin', anything)));
      expect(firstEntry, isNot(containsPair('fruitsMin', anything)));
      expect(firstEntry, isNot(containsPair('dairyMin', anything)));
      expect(firstEntry, isNot(containsPair('leanMeatsMin', anything)));

      // Test daily sweets entry (2600 kcal)
      final dailySweetsEntry = content.dashServings.firstWhere(
        (entry) => (entry as Map<String, dynamic>)['kcal'] == 2600,
      ) as Map<String, dynamic>;

      expect(dailySweetsEntry, containsPair('sweetsMaxPerDay', 2));
      expect(dailySweetsEntry, containsPair('sweetsMaxPerWeek', 0));

      // Test weekly sweets entry (1800 kcal)
      final weeklySweetsEntry = content.dashServings.firstWhere(
        (entry) => (entry as Map<String, dynamic>)['kcal'] == 1800,
      ) as Map<String, dynamic>;

      expect(weeklySweetsEntry, containsPair('sweetsMaxPerWeek', 5));
      expect(
          weeklySweetsEntry, isNot(containsPair('sweetsMaxPerDay', anything)));
    });

    test('should load MyPlate targets correctly', () async {
      final content = await NutritionContentLoader.load();

      expect(content.myplateTargets, isA<List<dynamic>>());
      expect(content.myplateTargets.length, greaterThan(0));

      // Test first entry (1600 kcal)
      final firstEntry = content.myplateTargets[0] as Map<String, dynamic>;
      expect(firstEntry, containsPair('kcal', 1600));
      expect(firstEntry, containsPair('fruits', isA<double>()));
      expect(firstEntry, containsPair('vegetables', isA<double>()));
      expect(firstEntry, containsPair('grains', isA<int>()));
      expect(firstEntry, containsPair('protein', isA<double>()));
      expect(firstEntry, containsPair('dairy', isA<int>()));
      expect(firstEntry, containsPair('addedSugarsMax', isA<int>()));
      expect(firstEntry, containsPair('saturatedFatMax', isA<int>()));
      expect(firstEntry, containsPair('sodiumMax', isA<int>()));

      // Test specific values for 2000 kcal
      final entry2000 = content.myplateTargets.firstWhere(
        (entry) => (entry as Map<String, dynamic>)['kcal'] == 2000,
      ) as Map<String, dynamic>;

      expect(entry2000['fruits'], equals(2.0));
      expect(entry2000['vegetables'], equals(2.5));
      expect(entry2000['grains'], equals(6));
      expect(entry2000['protein'], equals(5.5));
      expect(entry2000['dairy'], equals(3));
      expect(entry2000['addedSugarsMax'], equals(50));
      expect(entry2000['saturatedFatMax'], equals(22));
      expect(entry2000['sodiumMax'], equals(2300));
    });

    test('should have consistent data across all entries', () async {
      final content = await NutritionContentLoader.load();

      // Test DASH servings consistency
      for (final entry in content.dashServings) {
        final map = entry as Map<String, dynamic>;
        expect(map, containsPair('kcal', isA<int>()));
        expect(map, containsPair('grainsMax', isA<int>()));
        expect(map, containsPair('vegetablesMax', isA<int>()));
        expect(map, containsPair('fruitsMax', isA<int>()));
        expect(map, containsPair('dairyMax', isA<int>()));
        expect(map, containsPair('leanMeatsMax', isA<int>()));
        expect(map, containsPair('sodium', isA<int>()));

        // Verify kcal values are in expected range
        final kcal = map['kcal'] as int;
        expect(kcal, greaterThanOrEqualTo(1200));
        expect(kcal, lessThanOrEqualTo(3100));
      }

      // Test MyPlate targets consistency
      for (final entry in content.myplateTargets) {
        final map = entry as Map<String, dynamic>;
        expect(map, containsPair('kcal', isA<int>()));
        expect(map, containsPair('fruits', isA<double>()));
        expect(map, containsPair('vegetables', isA<double>()));
        expect(map, containsPair('grains', isA<int>()));
        expect(map, containsPair('protein', isA<double>()));
        expect(map, containsPair('dairy', isA<int>()));
        expect(map, containsPair('addedSugarsMax', isA<int>()));
        expect(map, containsPair('saturatedFatMax', isA<int>()));
        expect(map, containsPair('sodiumMax', isA<int>()));

        // Verify kcal values are in expected range
        final kcal = map['kcal'] as int;
        expect(kcal, greaterThanOrEqualTo(1600));
        expect(kcal, lessThanOrEqualTo(3200));
      }
    });

    test('should handle all DASH calorie tiers', () async {
      final content = await NutritionContentLoader.load();

      final expectedTiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];
      final actualTiers = content.dashServings
          .map((entry) => (entry as Map<String, dynamic>)['kcal'] as int)
          .toList();

      for (final tier in expectedTiers) {
        expect(actualTiers, contains(tier));
      }
    });

    test('should handle all MyPlate calorie tiers', () async {
      final content = await NutritionContentLoader.load();

      final expectedTiers = [
        1600,
        1800,
        2000,
        2200,
        2400,
        2600,
        2800,
        3000,
        3200
      ];
      final actualTiers = content.myplateTargets
          .map((entry) => (entry as Map<String, dynamic>)['kcal'] as int)
          .toList();

      for (final tier in expectedTiers) {
        expect(actualTiers, contains(tier));
      }
    });
  });
}
