import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/pantry/views/pantry_page.dart';

// The pantry page's edit sheet is shared by FoodRx Items and Home Items, so
// the maximum-quantity rule is enforced here for both tabs.
PantryItem _item({required double quantity, bool isPantryItem = true}) {
  return PantryItem(
    id: 'item-1',
    name: 'Cannellini Beans',
    imageUrl: '',
    category: 'beans',
    quantity: quantity,
    unit: UnitType.ounces,
    expirationDate: DateTime.now().add(const Duration(days: 30)),
    isPantryItem: isPantryItem,
  );
}

Future<void> _pumpSheet(WidgetTester tester, PantryItem item) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: EditPantryItemSheet(item: item))),
  ));
}

void main() {
  const errorText = 'Maximum quantity is ${PantryItem.maxQuantity}';

  for (final isPantryItem in [true, false]) {
    final tab = isPantryItem ? 'FoodRx item' : 'Home item';

    testWidgets('$tab within the limit shows no error', (tester) async {
      await _pumpSheet(tester, _item(quantity: 5, isPantryItem: isPantryItem));

      expect(find.text(errorText), findsNothing);
    });

    testWidgets('$tab saved above the limit shows the error and cannot be saved',
        (tester) async {
      await _pumpSheet(
          tester, _item(quantity: 9999999999, isPantryItem: isPantryItem));

      expect(find.text(errorText), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();

      // Blocked before any save is attempted (which would surface this).
      expect(find.text('Failed to update item. Please try again.'), findsNothing);
      expect(find.text(errorText), findsOneWidget);
    });

    testWidgets('$tab error clears once the quantity is lowered',
        (tester) async {
      await _pumpSheet(
          tester, _item(quantity: 9999999999, isPantryItem: isPantryItem));

      await tester.enterText(find.byType(TextField), '250');
      await tester.pump();

      expect(find.text(errorText), findsNothing);
    });
  }

  testWidgets('the quantity field accepts at most 6 characters', (tester) async {
    await _pumpSheet(tester, _item(quantity: 5));

    await tester.enterText(find.byType(TextField), '1234567');
    await tester.pump();

    expect(find.text('1234567'), findsNothing);
  });
}
