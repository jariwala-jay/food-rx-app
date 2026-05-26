import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/utils/recipe_pantry_sort.dart';

void main() {
  group('RecipePantryMatchScore', () {
    test('completion ratio is have / (have + need)', () {
      const score = RecipePantryMatchScore(inPantry: 4, requiredMissing: 5);
      expect(score.requiredTotal, 9);
      expect(score.completionRatio, closeTo(4 / 9, 0.001));
    });

    test('orders by fewest need first (user example)', () {
      final need5 = RecipePantryMatchScore(inPantry: 4, requiredMissing: 5);
      final need4 = RecipePantryMatchScore(inPantry: 4, requiredMissing: 4);
      final need3 = RecipePantryMatchScore(inPantry: 4, requiredMissing: 3);
      final need1 = RecipePantryMatchScore(inPantry: 2, requiredMissing: 1);

      final ordered = [need5, need4, need3, need1]
        ..sort((a, b) => a.compareEaseTo(b));

      expect(ordered, [need1, need3, need4, need5]);
    });

    test('when need is equal, more in pantry wins', () {
      const fewerHave = RecipePantryMatchScore(inPantry: 2, requiredMissing: 3);
      const moreHave = RecipePantryMatchScore(inPantry: 4, requiredMissing: 3);

      expect(moreHave.compareEaseTo(fewerHave), lessThan(0));
    });
  });
}
