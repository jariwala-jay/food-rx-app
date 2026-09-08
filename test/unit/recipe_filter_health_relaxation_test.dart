import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';

// Regression: RecipeGenerationService's fallback chain relaxes health
// constraints (veryHealthy: false, dashCompliant: false, maxSodium: null)
// when a search returns 0 candidates. That relaxation used to be silently
// undone by RecipeFilter.toSpoonacularParams(), which independently
// re-derived maxSodium/veryHealthy from `medicalConditions` regardless of
// the filter's own (relaxed) fields — so the "relaxed" fallback request
// still carried maxSodium=1500&veryHealthy=true and never actually widened
// the search.
void main() {
  group('RecipeFilter health constraint relaxation', () {
    test('DASH-compliant filter sends sodium/health params', () {
      const filter = RecipeFilter(
        medicalConditions: [MedicalCondition.hypertension],
        dashCompliant: true,
        veryHealthy: true,
        maxSodium: 500,
      );

      final params = filter.toSpoonacularParams();

      expect(params['maxSodium'], '500');
      expect(params['veryHealthy'], 'true');
      expect(params['lowFat'], 'true');
    });

    test(
        'relaxing veryHealthy/dashCompliant/maxSodium drops those params from '
        'the query even though medicalConditions is still populated', () {
      const original = RecipeFilter(
        medicalConditions: [MedicalCondition.hypertension],
        dashCompliant: true,
        veryHealthy: true,
        maxSodium: 500,
      );

      final relaxed = original.copyWith(
        veryHealthy: false,
        dashCompliant: false,
        myPlateCompliant: false,
        maxSodium: null,
      );

      // The relaxation intentionally keeps medicalConditions — only the
      // Spoonacular-facing health params should be dropped.
      expect(relaxed.medicalConditions, [MedicalCondition.hypertension]);

      final params = relaxed.toSpoonacularParams();

      expect(params.containsKey('maxSodium'), isFalse);
      expect(params.containsKey('veryHealthy'), isFalse);
      expect(params.containsKey('lowFat'), isFalse);
    });

    test('relaxation also works for diabetes/myPlate profiles', () {
      const original = RecipeFilter(
        medicalConditions: [MedicalCondition.diabetes],
        myPlateCompliant: true,
        veryHealthy: true,
        maxSodium: 2300,
      );
      expect(original.toSpoonacularParams()['maxSodium'], '2300');

      final relaxed = original.copyWith(
        veryHealthy: false,
        dashCompliant: false,
        myPlateCompliant: false,
        maxSodium: null,
      );
      final params = relaxed.toSpoonacularParams();

      expect(params.containsKey('maxSodium'), isFalse);
      expect(params.containsKey('veryHealthy'), isFalse);
    });
  });
}
