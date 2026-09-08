import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/profile/views/notification_preferences_page.dart';

// Widget coverage for the meal reminders UI: a master "Meal reminders"
// switch that shows/hides the whole breakfast/lunch/dinner section and,
// when off, disables every meal regardless of its own toggle; and, within
// that section, each meal's own independent switch + time row with no
// cross-meal interference.
//
// AuthController talks to the network in updateUserProfile (ApiClient.patch
// + ApiClient.get). FakeAuthController below overrides it (same pattern as
// MockAuthController in forced_tour_provider_test.dart) to apply the update
// to an in-memory UserModel instead, so the widget under test never hits the
// network.
class FakeAuthController extends AuthController {
  UserModel _user;
  FakeAuthController(this._user);

  @override
  UserModel? get currentUser => _user;

  @override
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (updates.containsKey('mealLoggingReminderPrefs')) {
      _user = _user.copyWith(
        mealLoggingReminderPrefs:
            updates['mealLoggingReminderPrefs'] as Map<String, dynamic>,
      );
    }
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // NotificationService._scheduleDailyReminder (invoked indirectly via
  // _persistMealPrefs on every toggle) reads tz.local, a `late` field with
  // no implicit default.
  tz.setLocalLocation(tz.UTC);

  // The page also calls NotificationService().applyMealLoggingReminderPreferences
  // on every toggle/time change, which talks to flutter_local_notifications
  // over a platform channel — stub it out so toggling in the test doesn't
  // attempt a real platform call.
  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Map<String, dynamic> mealLoggingReminderPrefs,
  }) async {
    final fakeAuth = FakeAuthController(UserModel(
      email: 'user@example.com',
      mealLoggingReminderPrefs: mealLoggingReminderPrefs,
    ));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: fakeAuth,
        child: const MaterialApp(home: NotificationPreferencesPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A doc with every meal individually off self-heals its master flag to
  // false on load regardless of what's saved (see the "master switch stays
  // in sync" group below) — so this fixture always represents master off,
  // and callers that need the section visible must tap the master switch
  // first via masterOnAllMealsOffPrefs().
  Map<String, dynamic> allOffPrefs() => {
        'enabled': false,
        'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': false, 'hour': 20, 'minute': 0},
      };

  Finder switchFor(String mealTitle) =>
      find.widgetWithText(SwitchListTile, mealTitle);

  Future<void> tapMasterSwitch(WidgetTester tester) async {
    await tester.tap(switchFor('Meal reminders'));
    await tester.pumpAndSettle();
  }

  // The page grows a time row per enabled meal, which can push later
  // switches out of the small default test viewport — scroll each one into
  // view before tapping so the tap actually reaches it.
  Future<void> tapMealSwitch(WidgetTester tester, String mealTitle) async {
    final finder = switchFor(mealTitle);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
      '"Meal reminders" is a real master switch, on when at least one meal is',
      (tester) async {
    await pumpPage(
      tester,
      mealLoggingReminderPrefs: {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': false, 'hour': 20, 'minute': 0},
      },
    );

    final masterSwitch =
        tester.widget<SwitchListTile>(switchFor('Meal reminders'));
    expect(masterSwitch.value, isTrue);
  });

  testWidgets(
      'master off hides the entire breakfast/lunch/dinner section, even '
      'when meals are individually enabled underneath', (tester) async {
    await pumpPage(
      tester,
      mealLoggingReminderPrefs: {
        'enabled': false, // master off
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': true, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
      },
    );

    expect(switchFor('Breakfast'), findsNothing);
    expect(switchFor('Lunch'), findsNothing);
    expect(switchFor('Dinner'), findsNothing);
    expect(find.text('9:00 AM'), findsNothing);
    expect(find.text('1:00 PM'), findsNothing);
    expect(find.text('8:00 PM'), findsNothing);
  });

  testWidgets(
      'turning the master off then back on resets every meal to off with '
      'default times, instead of resuming the prior selection (reported bug)',
      (tester) async {
    await pumpPage(
      tester,
      mealLoggingReminderPrefs: {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 7, 'minute': 30}, // customized
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
      },
    );

    // Starts with Breakfast (customized 7:30) and Dinner on.
    expect(find.text('7:30 AM'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);

    await tapMasterSwitch(tester); // off
    expect(switchFor('Breakfast'), findsNothing); // section hidden

    await tapMasterSwitch(tester); // back on

    // Every meal comes back OFF — Breakfast and Dinner do NOT resume their
    // prior enabled state.
    final breakfastSwitch =
        tester.widget<SwitchListTile>(switchFor('Breakfast'));
    final lunchSwitch = tester.widget<SwitchListTile>(switchFor('Lunch'));
    final dinnerSwitch = tester.widget<SwitchListTile>(switchFor('Dinner'));
    expect(breakfastSwitch.value, isFalse);
    expect(lunchSwitch.value, isFalse);
    expect(dinnerSwitch.value, isFalse);
    expect(find.text('7:30 AM'), findsNothing);
    expect(find.text('8:00 PM'), findsNothing);

    // Re-enabling Breakfast shows the DEFAULT time (9:00 AM), not the
    // 7:30 AM it was customized to before the reset.
    await tapMealSwitch(tester, 'Breakfast');
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('7:30 AM'), findsNothing);
  });

  testWidgets(
      'all three meals start off: section revealed via the master shows no '
      'time rows', (tester) async {
    await pumpPage(tester, mealLoggingReminderPrefs: allOffPrefs());
    await tapMasterSwitch(tester); // reveal the section first

    expect(switchFor('Breakfast'), findsOneWidget); // section is visible
    expect(find.text('9:00 AM'), findsNothing);
    expect(find.text('1:00 PM'), findsNothing);
    expect(find.text('8:00 PM'), findsNothing);
  });

  testWidgets('enabling only Lunch shows only Lunch\'s time row',
      (tester) async {
    await pumpPage(tester, mealLoggingReminderPrefs: allOffPrefs());
    await tapMasterSwitch(tester); // reveal the section first

    await tapMealSwitch(tester, 'Lunch');

    expect(find.text('9:00 AM'), findsNothing); // breakfast still hidden
    expect(find.text('1:00 PM'), findsOneWidget); // lunch now shown
    expect(find.text('8:00 PM'), findsNothing); // dinner still hidden
  });

  testWidgets('enabling Breakfast + Dinner shows only those two time rows',
      (tester) async {
    await pumpPage(tester, mealLoggingReminderPrefs: allOffPrefs());
    await tapMasterSwitch(tester); // reveal the section first

    await tapMealSwitch(tester, 'Breakfast');
    await tapMealSwitch(tester, 'Dinner');

    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('1:00 PM'), findsNothing);
    expect(find.text('8:00 PM'), findsOneWidget);
  });

  testWidgets('all three toggles are independently controllable',
      (tester) async {
    await pumpPage(tester, mealLoggingReminderPrefs: allOffPrefs());
    await tapMasterSwitch(tester); // reveal the section first

    await tapMealSwitch(tester, 'Breakfast');
    await tapMealSwitch(tester, 'Lunch');
    await tapMealSwitch(tester, 'Dinner');

    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('1:00 PM'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);
  });

  testWidgets(
      'disabling one meal does not disable or hide the others',
      (tester) async {
    await pumpPage(
      tester,
      mealLoggingReminderPrefs: {
        'enabled': true, // master on
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': true, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
      },
    );

    // All three visible initially.
    expect(find.text('9:00 AM'), findsOneWidget);
    expect(find.text('1:00 PM'), findsOneWidget);
    expect(find.text('8:00 PM'), findsOneWidget);

    // Turn Lunch off.
    await tapMealSwitch(tester, 'Lunch');

    expect(find.text('9:00 AM'), findsOneWidget); // breakfast unaffected
    expect(find.text('1:00 PM'), findsNothing); // lunch hidden
    expect(find.text('8:00 PM'), findsOneWidget); // dinner unaffected

    final breakfastSwitch =
        tester.widget<SwitchListTile>(switchFor('Breakfast'));
    final dinnerSwitch = tester.widget<SwitchListTile>(switchFor('Dinner'));
    expect(breakfastSwitch.value, isTrue);
    expect(dinnerSwitch.value, isTrue);
  });

  group('master switch stays in sync with the meals underneath', () {
    testWidgets(
        'turning off the last individually-enabled meal collapses the '
        'master switch and hides the section', (tester) async {
      await pumpPage(
        tester,
        mealLoggingReminderPrefs: {
          'enabled': true,
          'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
          'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
          'dinner': {'enabled': true, 'hour': 20, 'minute': 0}, // only one on
        },
      );

      // Master starts on (matches saved state) with Dinner visibly on.
      expect(
          tester.widget<SwitchListTile>(switchFor('Meal reminders')).value,
          isTrue);
      expect(find.text('8:00 PM'), findsOneWidget);

      // Turn off Dinner — the only meal that was still on.
      await tapMealSwitch(tester, 'Dinner');

      // The master switch itself collapses to off, and the whole section
      // (including Breakfast/Lunch, which were already off) disappears.
      expect(
          tester.widget<SwitchListTile>(switchFor('Meal reminders')).value,
          isFalse);
      expect(switchFor('Breakfast'), findsNothing);
      expect(switchFor('Lunch'), findsNothing);
      expect(switchFor('Dinner'), findsNothing);
    });

    testWidgets(
        'turning off one of several enabled meals leaves the master on and '
        'the section visible', (tester) async {
      await pumpPage(
        tester,
        mealLoggingReminderPrefs: {
          'enabled': true,
          'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
          'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
          'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
        },
      );

      await tapMealSwitch(tester, 'Breakfast'); // Dinner is still on

      expect(
          tester.widget<SwitchListTile>(switchFor('Meal reminders')).value,
          isTrue);
      expect(switchFor('Dinner'), findsOneWidget);
    });

    testWidgets(
        'a saved doc with master on but every meal individually off '
        'self-heals to master off on load (the reported bug)',
        (tester) async {
      await pumpPage(
        tester,
        mealLoggingReminderPrefs: {
          'enabled': true, // stale: master left on...
          'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
          'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
          'dinner': {'enabled': false, 'hour': 20, 'minute': 0}, // ...but nothing is
        },
      );

      // The master switch must display off, and the section must be
      // collapsed, even though the saved doc said the master was on.
      expect(
          tester.widget<SwitchListTile>(switchFor('Meal reminders')).value,
          isFalse);
      expect(switchFor('Breakfast'), findsNothing);
      expect(switchFor('Lunch'), findsNothing);
      expect(switchFor('Dinner'), findsNothing);
    });
  });
}
