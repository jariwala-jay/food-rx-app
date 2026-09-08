import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_app/core/services/notification_service.dart';

// Regression coverage for NotificationService.applyMealLoggingReminderPreferences
// after the breakfast/lunch/dinner independent-toggle refactor: each meal must
// be scheduled or cancelled based on both the master "Meal reminders" switch
// (top-level `enabled`) and its own per-meal enabled flag, with no dependency
// between meals, and the legacy generic reminder id (1004) must always be
// cancelled alongside the three per-meal ids (1001/1002/1003). When the
// master is off, nothing is scheduled regardless of the per-meal flags, but
// those flags are preserved so turning the master back on reschedules
// exactly the meals that were individually enabled before.
//
// flutter_local_notifications talks to native code over a single platform
// MethodChannel ('dexterous.com/flutter/local_notifications'). Registering
// AndroidFlutterLocalNotificationsPlugin as the platform implementation (as
// happens for real on a device) and installing a mock handler on that exact
// channel name lets us intercept every cancel/zonedSchedule call the service
// makes and assert on the ids involved, instead of only checking the method
// call completes without throwing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // NotificationService._scheduleDailyReminder reads tz.local, which is a
  // `late` field with no implicit default — set it once for the whole file
  // so scheduling math (today vs. tomorrow, notBefore floor) has a location
  // to work against.
  tz.setLocalLocation(tz.UTC);

  const channel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Set<int> scheduledIds() => calls
      .where((c) => c.method == 'zonedSchedule')
      .map((c) => (c.arguments as Map)['id'] as int)
      .toSet();

  Set<int> cancelledIds() => calls
      .where((c) => c.method == 'cancel')
      .map((c) => (c.arguments as Map)['id'] as int)
      .toSet();

  const breakfastId = 1001;
  const lunchId = 1002;
  const dinnerId = 1003;
  const legacyGenericId = 1004;
  const allMealIds = {breakfastId, lunchId, dinnerId};

  Map<String, dynamic> newFormatPrefs({
    bool master = true,
    required bool breakfast,
    required bool lunch,
    required bool dinner,
  }) {
    return {
      'enabled': master,
      'breakfast': {'enabled': breakfast, 'hour': 9, 'minute': 0},
      'lunch': {'enabled': lunch, 'hour': 13, 'minute': 0},
      'dinner': {'enabled': dinner, 'hour': 20, 'minute': 0},
    };
  }

  group('applyMealLoggingReminderPreferences — every id it touches', () {
    test('always cancels all 4 ids (3 per-meal + legacy 1004) up front', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: true,
        lunch: false,
        dinner: false,
      ));
      expect(cancelledIds(), {breakfastId, lunchId, dinnerId, legacyGenericId});
    });

    test('breakfast only schedules just 1001', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: true,
        lunch: false,
        dinner: false,
      ));
      expect(scheduledIds(), {breakfastId});
    });

    test('lunch only schedules just 1002', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: false,
        lunch: true,
        dinner: false,
      ));
      expect(scheduledIds(), {lunchId});
    });

    test('dinner only schedules just 1003', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: false,
        lunch: false,
        dinner: true,
      ));
      expect(scheduledIds(), {dinnerId});
    });

    test('breakfast + lunch schedules exactly those two', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: true,
        lunch: true,
        dinner: false,
      ));
      expect(scheduledIds(), {breakfastId, lunchId});
    });

    test('breakfast + dinner schedules exactly those two', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: true,
        lunch: false,
        dinner: true,
      ));
      expect(scheduledIds(), {breakfastId, dinnerId});
    });

    test('lunch + dinner schedules exactly those two', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: false,
        lunch: true,
        dinner: true,
      ));
      expect(scheduledIds(), {lunchId, dinnerId});
    });

    test('all three enabled schedules all three', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: true,
        lunch: true,
        dinner: true,
      ));
      expect(scheduledIds(), allMealIds);
    });

    test('none enabled schedules nothing', () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        breakfast: false,
        lunch: false,
        dinner: false,
      ));
      expect(scheduledIds(), isEmpty);
    });

    test('old-format prefs with top-level enabled=true schedules all three',
        () async {
      await NotificationService().applyMealLoggingReminderPreferences({
        'enabled': true,
        'breakfast': {'hour': 9, 'minute': 0},
        'lunch': {'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0},
      });
      expect(scheduledIds(), allMealIds);
    });

    test('old-format prefs with top-level enabled=false schedules nothing',
        () async {
      await NotificationService().applyMealLoggingReminderPreferences({
        'enabled': false,
        'breakfast': {'hour': 9, 'minute': 0},
        'lunch': {'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0},
      });
      expect(scheduledIds(), isEmpty);
    });

    test(
        'an explicit per-meal enabled=false overrides a stale top-level enabled=true',
        () async {
      await NotificationService().applyMealLoggingReminderPreferences({
        'enabled': true,
        'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': true, 'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0}, // no per-meal key -> falls back
      });
      // breakfast explicitly off despite legacy enabled=true; lunch
      // explicitly on; dinner has no per-meal key so inherits the legacy
      // top-level flag (true).
      expect(scheduledIds(), {lunchId, dinnerId});
    });

    test('null prefs schedules nothing but still cancels all 4 ids',
        () async {
      await NotificationService().applyMealLoggingReminderPreferences(null);
      expect(scheduledIds(), isEmpty);
      expect(cancelledIds(), {breakfastId, lunchId, dinnerId, legacyGenericId});
    });
  });

  test('all 8 enabled/disabled combinations schedule exactly the right ids',
      () async {
    final idFor = {'breakfast': breakfastId, 'lunch': lunchId, 'dinner': dinnerId};
    for (final b in [false, true]) {
      for (final l in [false, true]) {
        for (final d in [false, true]) {
          calls = [];
          await NotificationService()
              .applyMealLoggingReminderPreferences(newFormatPrefs(
            breakfast: b,
            lunch: l,
            dinner: d,
          ));
          final expected = <int>{
            if (b) idFor['breakfast']!,
            if (l) idFor['lunch']!,
            if (d) idFor['dinner']!,
          };
          expect(scheduledIds(), expected, reason: 'b=$b l=$l d=$d');
        }
      }
    }
  });

  group('master "Meal reminders" switch gates every meal', () {
    test('master off schedules nothing even though all three meals are on',
        () async {
      await NotificationService()
          .applyMealLoggingReminderPreferences(newFormatPrefs(
        master: false,
        breakfast: true,
        lunch: true,
        dinner: true,
      ));
      expect(scheduledIds(), isEmpty);
      expect(cancelledIds(), {breakfastId, lunchId, dinnerId, legacyGenericId});
    });

    test(
        'flipping the master back on reschedules exactly the meals that were '
        'individually enabled — no re-toggling needed', () async {
      final prefs = newFormatPrefs(
        master: false,
        breakfast: true,
        lunch: false,
        dinner: true,
      );

      // Master off: nothing scheduled.
      await NotificationService().applyMealLoggingReminderPreferences(prefs);
      expect(scheduledIds(), isEmpty);

      // Master back on, same per-meal map (as the settings page would send
      // after just flipping the master switch): breakfast and dinner —
      // which were already individually enabled — resume; lunch, which was
      // individually off, still doesn't fire.
      calls = [];
      final restored = {...prefs, 'enabled': true};
      await NotificationService()
          .applyMealLoggingReminderPreferences(restored);
      expect(scheduledIds(), {breakfastId, dinnerId});
    });

    test('all 8 per-meal combinations schedule nothing while master is off',
        () async {
      for (final b in [false, true]) {
        for (final l in [false, true]) {
          for (final d in [false, true]) {
            calls = [];
            await NotificationService()
                .applyMealLoggingReminderPreferences(newFormatPrefs(
              master: false,
              breakfast: b,
              lunch: l,
              dinner: d,
            ));
            expect(scheduledIds(), isEmpty, reason: 'b=$b l=$l d=$d');
          }
        }
      }
    });
  });
}
