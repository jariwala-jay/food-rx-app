import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/tracking/services/tracker_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TrackerService Tests', () {
    late TrackerService trackerService;
    late NutritionContent nutritionContent;

    setUpAll(() async {
      nutritionContent = await NutritionContentLoader.load();
      trackerService = TrackerService();
    });

    group('Nutrition Content Loading Tests', () {
      test('should load nutrition content successfully', () async {
        expect(nutritionContent.dashCalorieMap, isA<Map<String, dynamic>>());
        expect(nutritionContent.dashServings, isA<List<dynamic>>());
        expect(nutritionContent.myplateTargets, isA<List<dynamic>>());

        expect(nutritionContent.dashServings.length, greaterThan(0));
        expect(nutritionContent.myplateTargets.length, greaterThan(0));
      });

      test('should have correct DASH servings structure', () async {
        final firstEntry =
            nutritionContent.dashServings[0] as Map<String, dynamic>;

        expect(firstEntry, containsPair('kcal', isA<int>()));
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
      });

      test('should have correct MyPlate targets structure', () async {
        final firstEntry =
            nutritionContent.myplateTargets[0] as Map<String, dynamic>;

        expect(firstEntry, containsPair('kcal', isA<int>()));
        expect(firstEntry, containsPair('fruits', isA<double>()));
        expect(firstEntry, containsPair('vegetables', isA<double>()));
        expect(firstEntry, containsPair('grains', isA<int>()));
        expect(firstEntry, containsPair('protein', isA<double>()));
        expect(firstEntry, containsPair('dairy', isA<int>()));
        expect(firstEntry, containsPair('addedSugarsMax', isA<int>()));
        expect(firstEntry, containsPair('saturatedFatMax', isA<int>()));
        expect(firstEntry, containsPair('sodiumMax', isA<int>()));
      });

      test('should have daily sweets limits for 2600+ kcal plans', () async {
        final dailySweetsEntries = nutritionContent.dashServings
            .where((entry) => (entry as Map<String, dynamic>)['kcal'] >= 2600)
            .toList();

        for (final entry in dailySweetsEntries) {
          final map = entry as Map<String, dynamic>;
          expect(map, containsPair('sweetsMaxPerDay', isA<int>()));
          expect(map, containsPair('sweetsMaxPerWeek', 0));
        }
      });

      test('should have weekly sweets limits for 1200-2000 kcal plans',
          () async {
        final weeklySweetsEntries =
            nutritionContent.dashServings.where((entry) {
          final kcal = (entry as Map<String, dynamic>)['kcal'] as int;
          return kcal >= 1200 && kcal <= 2000;
        }).toList();

        for (final entry in weeklySweetsEntries) {
          final map = entry as Map<String, dynamic>;
          expect(map, containsPair('sweetsMaxPerWeek', isA<int>()));
          expect(map, isNot(containsPair('sweetsMaxPerDay', anything)));
        }
      });
    });

    group('DASH Calorie Map Tests', () {
      test('should have correct age groups for women', () async {
        final data =
            nutritionContent.dashCalorieMap['data'] as Map<String, dynamic>;
        final womenData = data['women'] as Map<String, dynamic>;

        expect(womenData, containsPair('19-30', isA<Map<String, dynamic>>()));
        expect(womenData, containsPair('31-50', isA<Map<String, dynamic>>()));
        expect(womenData, containsPair('51+', isA<Map<String, dynamic>>()));

        // Test specific calorie values for women 19-30
        final women19_30 = womenData['19-30'] as Map<String, dynamic>;
        expect(women19_30, containsPair('sedentary', 2000));
        expect(women19_30, containsPair('moderate', 2000));
        expect(women19_30, containsPair('active', 2400));
      });

      test('should have correct age groups for men', () async {
        final data =
            nutritionContent.dashCalorieMap['data'] as Map<String, dynamic>;
        final menData = data['men'] as Map<String, dynamic>;

        expect(menData, containsPair('19-30', isA<Map<String, dynamic>>()));
        expect(menData, containsPair('31-50', isA<Map<String, dynamic>>()));
        expect(menData, containsPair('51+', isA<Map<String, dynamic>>()));

        // Test specific calorie values for men 19-30
        final men19_30 = menData['19-30'] as Map<String, dynamic>;
        expect(men19_30, containsPair('sedentary', 2400));
        expect(men19_30, containsPair('moderate', 2600));
        expect(men19_30, containsPair('active', 3000));
      });
    });

    group('Data Consistency Tests', () {
      test('should have consistent DASH servings data', () async {
        for (final entry in nutritionContent.dashServings) {
          final map = entry as Map<String, dynamic>;
          final kcal = map['kcal'] as int;

          // Verify kcal values are in expected range
          expect(kcal, greaterThanOrEqualTo(1200));
          expect(kcal, lessThanOrEqualTo(3100));

          // Verify all required fields exist
          expect(map, containsPair('grainsMax', isA<int>()));
          expect(map, containsPair('vegetablesMax', isA<int>()));
          expect(map, containsPair('fruitsMax', isA<int>()));
          expect(map, containsPair('dairyMax', isA<int>()));
          expect(map, containsPair('leanMeatsMax', isA<int>()));
          expect(map, containsPair('sodium', isA<int>()));
        }
      });

      test('should have consistent MyPlate targets data', () async {
        for (final entry in nutritionContent.myplateTargets) {
          final map = entry as Map<String, dynamic>;
          final kcal = map['kcal'] as int;

          // Verify kcal values are in expected range
          expect(kcal, greaterThanOrEqualTo(1600));
          expect(kcal, lessThanOrEqualTo(3200));

          // Verify all required fields exist
          expect(map, containsPair('fruits', isA<double>()));
          expect(map, containsPair('vegetables', isA<double>()));
          expect(map, containsPair('grains', isA<int>()));
          expect(map, containsPair('protein', isA<double>()));
          expect(map, containsPair('dairy', isA<int>()));
          expect(map, containsPair('addedSugarsMax', isA<int>()));
          expect(map, containsPair('saturatedFatMax', isA<int>()));
          expect(map, containsPair('sodiumMax', isA<int>()));
        }
      });

      test('should have all expected DASH calorie tiers', () async {
        final expectedTiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];
        final actualTiers = nutritionContent.dashServings
            .map((entry) => (entry as Map<String, dynamic>)['kcal'] as int)
            .toList();

        for (final tier in expectedTiers) {
          expect(actualTiers, contains(tier));
        }
      });

      test('should have all expected MyPlate calorie tiers', () async {
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
        final actualTiers = nutritionContent.myplateTargets
            .map((entry) => (entry as Map<String, dynamic>)['kcal'] as int)
            .toList();

        for (final tier in expectedTiers) {
          expect(actualTiers, contains(tier));
        }
      });
    });

    group('TrackerService Singleton Tests', () {
      test('should return same instance', () {
        final instance1 = TrackerService();
        final instance2 = TrackerService();

        expect(identical(instance1, instance2), isTrue);
      });

      test('should have required dependencies', () {
        expect(trackerService, isNotNull);
        // The service should be initialized without errors
        expect(trackerService, isA<TrackerService>());
      });
    });
  });
}
