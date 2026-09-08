import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/ingredient_fuzzy_matcher.dart';

void main() {
  group('diagnostic: print results for the requested test cases', () {
    test('prints related-suggestion and typo-correction results', () {
      const probes = [
        'pickled onions',
        'fresh spinach',
        'cocnut',
        'spinich',
        'tomatoe',
        'xyzabc123',
      ];
      for (final probe in probes) {
        final related = IngredientFuzzyMatcher.findRelatedSuggestion(
          probe,
          isFoodPantryItem: true,
        );
        final typo = IngredientFuzzyMatcher.findTypoCorrection(
          probe,
          isFoodPantryItem: true,
        );
        // ignore: avoid_print
        print('"$probe" -> related=${related == null ? "(none)" : "${related.ingredient.name} [${related.category}] score=${related.similarity.toStringAsFixed(3)}"} '
            '| typo=${typo == null ? "(none)" : "${typo.ingredient.name} [${typo.category}] score=${typo.similarity.toStringAsFixed(3)}"}');
      }
    });
  });

  group('IngredientFuzzyMatcher.sameIngredient (UI-layer dedup helper)', () {
    test('true when related and typo resolve to the same curated ingredient',
        () {
      // "tomatoe" legitimately triggers both: an exact normalized match
      // (tier 1, since neither "diced" nor a plural suffix survives
      // normalization) AND a strong edit-distance match — both landing on
      // the same "Tomatoes" candidate.
      final related = IngredientFuzzyMatcher.findRelatedSuggestion(
        'tomatoe',
        isFoodPantryItem: true,
      );
      final typo = IngredientFuzzyMatcher.findTypoCorrection(
        'tomatoe',
        isFoodPantryItem: true,
      );
      expect(related?.ingredient.name, 'Tomatoes');
      expect(typo?.ingredient.name, 'Tomatoes');
      expect(IngredientFuzzyMatcher.sameIngredient(related, typo), isTrue);
    });

    test('false when only a related suggestion exists ("pickled onions")',
        () {
      final related = IngredientFuzzyMatcher.findRelatedSuggestion(
        'pickled onions',
        isFoodPantryItem: true,
      );
      final typo = IngredientFuzzyMatcher.findTypoCorrection(
        'pickled onions',
        isFoodPantryItem: true,
      );
      expect(related, isNotNull);
      expect(typo, isNull);
      expect(IngredientFuzzyMatcher.sameIngredient(related, typo), isFalse);
    });

    test('false when only a typo correction exists ("cocnut")', () {
      final related = IngredientFuzzyMatcher.findRelatedSuggestion(
        'cocnut',
        isFoodPantryItem: true,
      );
      final typo = IngredientFuzzyMatcher.findTypoCorrection(
        'cocnut',
        isFoodPantryItem: true,
      );
      expect(related, isNull);
      expect(typo, isNotNull);
      expect(IngredientFuzzyMatcher.sameIngredient(related, typo), isFalse);
    });

    test('false when both are null, and false when they genuinely differ',
        () {
      expect(IngredientFuzzyMatcher.sameIngredient(null, null), isFalse);
      final a = IngredientFuzzyMatcher.findRelatedSuggestion('pickled onions',
          isFoodPantryItem: true);
      final b = IngredientFuzzyMatcher.findTypoCorrection('mozarella',
          isFoodPantryItem: true);
      expect(a?.ingredient.name, isNot(b?.ingredient.name));
      expect(IngredientFuzzyMatcher.sameIngredient(a, b), isFalse);
    });
  });

  group('IngredientFuzzyMatcher.findRelatedSuggestion (phrase/related, no Levenshtein)', () {
    test('word/phrase containment catches the required cases', () {
      final cases = <String, String>{
        'pickled onions': 'Onions',
        'fresh spinach': 'Spinach',
        'red apple': 'Apples',
        'frozen broccoli': 'Broccoli',
        'grond beef': 'Ground Beef', // partial overlap tier
      };
      for (final entry in cases.entries) {
        final match = IngredientFuzzyMatcher.findRelatedSuggestion(
          entry.key,
          isFoodPantryItem: true,
        );
        expect(match, isNotNull, reason: 'expected a match for "${entry.key}"');
        expect(match!.ingredient.name, entry.value,
            reason: '"${entry.key}" should suggest "${entry.value}"');
      }
    });

    test('pure spelling typos are NOT caught here (that is findTypoCorrection\'s job)',
        () {
      for (final probe in ['cocnut', 'spinich', 'mozarella', 'quinoaa']) {
        final match = IngredientFuzzyMatcher.findRelatedSuggestion(
          probe,
          isFoodPantryItem: true,
        );
        expect(match, isNull, reason: '"$probe" is a typo, not a phrase match');
      }
    });

    test('does not suggest anything for unrelated/gibberish input', () {
      for (final probe in ['xyzabc123', 'kiwanoxyz123', 'qwzxjk']) {
        final match = IngredientFuzzyMatcher.findRelatedSuggestion(
          probe,
          isFoodPantryItem: true,
        );
        expect(match, isNull, reason: '"$probe" should have no suggestion');
      }
    });

    test('respects the isExcluded callback (e.g. allergy conflicts)', () {
      final unfiltered = IngredientFuzzyMatcher.findRelatedSuggestion(
        'pickled onions',
        isFoodPantryItem: true,
      );
      expect(unfiltered, isNotNull);
      expect(unfiltered!.ingredient.name, 'Onions');

      // Excluding the only real match should fall through to nothing —
      // "Onion Powder" only reaches the weaker partial-overlap tier,
      // which never outranks a full match, so with "Onions" excluded
      // there's nothing left in the top tier and it should surface there
      // instead rather than returning null (falls through a tier, not to
      // nothing) — assert it's no longer "Onions" either way.
      final filtered = IngredientFuzzyMatcher.findRelatedSuggestion(
        'pickled onions',
        isFoodPantryItem: true,
        isExcluded: (name) => name == 'Onions',
      );
      expect(filtered?.ingredient.name, isNot('Onions'));
    });

    test('a query that is only stopwords has no related suggestion', () {
      final match = IngredientFuzzyMatcher.findRelatedSuggestion(
        'fresh frozen',
        isFoodPantryItem: true,
      );
      expect(match, isNull);
    });
  });

  group('IngredientFuzzyMatcher.findTypoCorrection (spelling only, at 0.75)', () {
    test('catches common single-edit typos, including multi-word names', () {
      final cases = <String, String>{
        'cocnut': 'Coconut Oil',
        'coconot': 'Coconut Oil',
        'chiken breast': 'Chicken Breast',
        'frozn peas': 'Frozen Peas',
        'yogourt': 'Yogurt',
        'brocoli': 'Broccoli',
        'tomatoe': 'Tomatoes',
        'garlik': 'Garlic',
        'onionn': 'Onions',
        'grond beef': 'Ground Beef',
        'blak beans': 'Black Beans',
        'mozarella': 'Mozzarella Cheese',
        'quinoaa': 'Quinoa',
        'swet potato': 'Sweet Potatoes',
      };

      for (final entry in cases.entries) {
        final match = IngredientFuzzyMatcher.findTypoCorrection(
          entry.key,
          isFoodPantryItem: true,
        );
        expect(match, isNotNull, reason: 'expected a match for "${entry.key}"');
        expect(match!.ingredient.name, entry.value,
            reason: '"${entry.key}" should suggest "${entry.value}"');
      }
    });

    test('does not suggest anything for unrelated/gibberish input', () {
      for (final probe in ['xyzabc123', 'kiwanoxyz123', 'qwzxjk']) {
        final match = IngredientFuzzyMatcher.findTypoCorrection(
          probe,
          isFoodPantryItem: true,
        );
        expect(match, isNull, reason: '"$probe" should have no suggestion');
      }
    });

    // Known limitation, not a bug: "bananna" (a double-letter-swap typo)
    // scores ~0.71 against "Bananas" — just under the 0.75 threshold, so
    // it currently gets no suggestion. Recorded here so a future threshold
    // change is a deliberate decision, not a silent regression.
    test('double-edit typos like "bananna" fall just under the threshold',
        () {
      final match = IngredientFuzzyMatcher.findTypoCorrection(
        'bananna',
        isFoodPantryItem: true,
      );
      expect(match, isNull);
    });

    // Known limitation, not a bug: pure edit-distance token matching can
    // surface a spelling-close but conceptually different curated item.
    // "aple" scores higher against the "Apple" token inside "Apple Cider
    // Vinegar" (single-letter insertion) than against "Apples" (needs an
    // extra "s"), so the multi-word seasoning wins the ranking even though
    // a person typing "aple" almost certainly means the fruit.
    test('token matching can rank a multi-word item over a plainer one',
        () {
      final match = IngredientFuzzyMatcher.findTypoCorrection(
        'aple',
        isFoodPantryItem: true,
      );
      expect(match?.ingredient.name, 'Apple Cider Vinegar');
    });

    test('respects the isExcluded callback (e.g. allergy conflicts)', () {
      const looseThreshold = 0.5;
      final unfiltered = IngredientFuzzyMatcher.findTypoCorrection(
        'cocnut',
        isFoodPantryItem: true,
        threshold: looseThreshold,
      );
      expect(unfiltered, isNotNull);
      final topName = unfiltered!.ingredient.name;

      final filtered = IngredientFuzzyMatcher.findTypoCorrection(
        'cocnut',
        isFoodPantryItem: true,
        threshold: looseThreshold,
        isExcluded: (name) => name == topName,
      );
      expect(filtered, isNotNull);
      expect(filtered!.ingredient.name, isNot(topName));
    });

    test('allergy-conflicting single candidate yields no suggestion', () {
      final match = IngredientFuzzyMatcher.findTypoCorrection(
        'cocnut',
        isFoodPantryItem: true,
        isExcluded: (name) => name == 'Coconut Oil',
      );
      expect(match, isNull);
    });
  });
}
