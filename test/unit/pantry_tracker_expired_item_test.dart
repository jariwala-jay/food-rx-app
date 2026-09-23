import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/tracking/widgets/pantry_tracker_logging_modal.dart';

void main() {
  group('pantryItemIsLoggable', () {
    // Regression: an expired pantry item (e.g. spinach past its
    // expiration date) was showing up under its food-group tracker in
    // the "From Pantry" tab, letting the user log servings from spoiled
    // food. Expired items must never be selectable there, regardless of
    // category/search/allergy match.
    test('an expired item is never loggable, even if everything else matches',
        () {
      expect(
        pantryItemIsLoggable(
          matchesCategory: true,
          matchesSearch: true,
          isExpired: true,
          hasAllergyConflict: false,
        ),
        false,
      );
    });

    test('a non-expired item matching everything else is loggable', () {
      expect(
        pantryItemIsLoggable(
          matchesCategory: true,
          matchesSearch: true,
          isExpired: false,
          hasAllergyConflict: false,
        ),
        true,
      );
    });

    test('expiry is checked independently of category/search/allergy', () {
      // Every combination of the other three flags should still be
      // rejected once isExpired is true.
      for (final matchesCategory in [true, false]) {
        for (final matchesSearch in [true, false]) {
          for (final hasAllergyConflict in [true, false]) {
            expect(
              pantryItemIsLoggable(
                matchesCategory: matchesCategory,
                matchesSearch: matchesSearch,
                isExpired: true,
                hasAllergyConflict: hasAllergyConflict,
              ),
              false,
              reason: 'isExpired=true must always block logging',
            );
          }
        }
      }
    });

    test('a category mismatch still blocks logging for a non-expired item',
        () {
      expect(
        pantryItemIsLoggable(
          matchesCategory: false,
          matchesSearch: true,
          isExpired: false,
          hasAllergyConflict: false,
        ),
        false,
      );
    });

    test('an allergy conflict still blocks logging for a non-expired item',
        () {
      expect(
        pantryItemIsLoggable(
          matchesCategory: true,
          matchesSearch: true,
          isExpired: false,
          hasAllergyConflict: true,
        ),
        false,
      );
    });
  });
}
