import 'package:flutter/material.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'nested Other picker updates its label and waits for main Done',
    (tester) async {
      var nestedPickerCalls = 0;
      List<String>? submittedValues;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppDropdownField(
              label: 'Food Allergies & Intolerances',
              value: null,
              options: const ['Dairy', 'Other'],
              onChanged: (_) {},
              hintText: 'Select Allergies & Intolerances',
              multiSelect: true,
              selectedValues: const [],
              nestedOption: 'Other',
              onNestedOptionTap: () async {
                nestedPickerCalls++;
                return ['Peach', 'Apple'];
              },
              onChangedMulti: (values) {
                submittedValues = values;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Allergies & Intolerances'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();

      expect(nestedPickerCalls, 1);
      expect(find.text('Other: Peach, Apple'), findsOneWidget);
      expect(submittedValues, isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(submittedValues, isEmpty);
    },
  );

  testWidgets(
    'tapping checked Other reopens the picker; clearing inside it fires onNestedOptionCleared',
    (tester) async {
      var nestedPickerCalls = 0;
      var nestedCleared = false;
      var nestedValues = <String>['Peach'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return AppDropdownField(
                  label: 'Food Allergies & Intolerances',
                  value: null,
                  options: const ['Dairy', 'Other'],
                  onChanged: (_) {},
                  hintText: 'Select Allergies & Intolerances',
                  multiSelect: true,
                  selectedValues: const [],
                  nestedOption: 'Other',
                  nestedOptionValues: nestedValues,
                  onNestedOptionTap: () async {
                    nestedPickerCalls++;
                    // Simulates the user clearing the value from inside the
                    // nested picker (e.g. tapping "Clear") before confirming.
                    return <String>[];
                  },
                  onNestedOptionCleared: () {
                    nestedCleared = true;
                    setState(() {
                      nestedValues = [];
                    });
                  },
                  onChangedMulti: (_) {},
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Select Allergies & Intolerances'));
      await tester.pumpAndSettle();

      expect(find.text('Other: Peach'), findsOneWidget);

      // Tapping the checked Other row is a managed collection, not a boolean
      // toggle: it always reopens the picker so the user can edit or clear
      // the nested value (see form_fields.dart's onChanged for "Other").
      await tester.tap(find.text('Other: Peach'));
      await tester.pumpAndSettle();

      expect(nestedPickerCalls, 1);
      expect(nestedCleared, isTrue);
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Other: Peach'), findsNothing);
    },
  );
}
