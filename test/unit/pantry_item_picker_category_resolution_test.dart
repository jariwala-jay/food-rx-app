import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/pantry/views/pantry_item_picker_page.dart';

void main() {
  group('PantryItemPickerPage.shouldResolveCategoryFromName', () {
    // Regression: a fully custom item (no curated or Spoonacular match at
    // all) used to skip name-based category resolution entirely, because
    // isShowingGlobalIngredientSearch is explicitly false for that case
    // (searchSpoonacular resets it when both search and autocomplete come
    // back empty). The item was then filed under whichever tab the user
    // happened to be browsing, which can silently miscategorize it (e.g.
    // invisible to trackers, or excluded from recipe recommendations)
    // depending on which tab that was — independent of which tab it is.
    test('custom item resolves from name regardless of the browsed tab', () {
      expect(
        PantryItemPickerPage.shouldResolveCategoryFromName(
          isShowingGlobalIngredientSearch: false,
          itemId: 'custom_1234567890',
        ),
        true,
      );
      expect(
        PantryItemPickerPage.shouldResolveCategoryFromName(
          isShowingGlobalIngredientSearch: true,
          itemId: 'custom_1234567890',
        ),
        true,
      );
    });

    test('global-search (Spoonacular-matched) item resolves from name', () {
      expect(
        PantryItemPickerPage.shouldResolveCategoryFromName(
          isShowingGlobalIngredientSearch: true,
          itemId: '11282', // a real Spoonacular ingredient id shape
        ),
        true,
      );
    });

    // A curated item (already belongs to the tab it was picked from) keeps
    // trusting that tab's category outright — unaffected by this fix.
    test('curated (non-custom, non-global-search) item trusts the tab',
        () {
      expect(
        PantryItemPickerPage.shouldResolveCategoryFromName(
          isShowingGlobalIngredientSearch: false,
          itemId: '11282',
        ),
        false,
      );
    });
  });
}
