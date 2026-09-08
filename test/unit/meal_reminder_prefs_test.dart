import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/utils/meal_reminder_prefs.dart';

// Regression coverage for meal reminders' two-level toggle model:
// - a master "Meal reminders" switch (top-level `enabled`) that, when off,
//   disables every meal's notification regardless of that meal's own flag,
//   while leaving each meal's own stored state untouched underneath;
// - each meal's own independent `enabled` + time, preserved across the
//   master being flipped off and back on.
//
// isMealRemindersMasterEnabled / mealReminderOwnEnabled / isMealReminderEnabled
// are the single source of truth read by both notification_preferences_page.dart
// (UI state + the "should this meal's row be shown as on" question) and
// notification_service.dart (the "should this meal actually fire" question)
// so they can't drift apart on how a doc is interpreted.
void main() {
  group('isMealRemindersMasterEnabled', () {
    test('true when the top-level enabled flag is true', () {
      expect(isMealRemindersMasterEnabled({'enabled': true}), isTrue);
    });

    test('false when the top-level enabled flag is false', () {
      expect(isMealRemindersMasterEnabled({'enabled': false}), isFalse);
    });

    test('false when prefs is null or the flag is absent', () {
      expect(isMealRemindersMasterEnabled(null), isFalse);
      expect(isMealRemindersMasterEnabled({}), isFalse);
    });
  });

  group('mealReminderOwnEnabled — a meal\'s own stored state, master ignored',
      () {
    test('reads each meal\'s own enabled key regardless of master state', () {
      final masterOff = {
        'enabled': false,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
      };
      // Master is off, but each meal's *own* stored toggle position is
      // still readable — this is what preserves UI state while the
      // section is hidden.
      expect(mealReminderOwnEnabled(masterOff, 'breakfast'), isTrue);
      expect(mealReminderOwnEnabled(masterOff, 'lunch'), isFalse);
    });

    test('old-format doc (no per-meal key) inherits the single top-level flag',
        () {
      final oldFormat = {
        'enabled': true,
        'breakfast': {'hour': 9, 'minute': 0},
      };
      expect(mealReminderOwnEnabled(oldFormat, 'breakfast'), isTrue);
    });

    test('a fully missing prefs map resolves to false', () {
      expect(mealReminderOwnEnabled(null, 'breakfast'), isFalse);
    });
  });

  group('isMealReminderEnabled — master gates every meal', () {
    test('master off disables a meal even though its own flag is true', () {
      final prefs = {
        'enabled': false,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isFalse);
    });

    test('master on + own flag on resolves enabled', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isTrue);
    });

    test('master on + own flag off resolves disabled', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isFalse);
    });

    test('master off with no prefs at all resolves every meal disabled', () {
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(null, meal), isFalse, reason: meal);
      }
    });
  });

  group('isMealReminderEnabled — old format (single top-level enabled)', () {
    test('top-level enabled=true makes all three meals resolve enabled', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'hour': 9, 'minute': 0},
        'lunch': {'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0},
      };
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(prefs, meal), isTrue, reason: meal);
      }
    });

    test('top-level enabled=false makes all three meals resolve disabled',
        () {
      final prefs = {
        'enabled': false,
        'breakfast': {'hour': 9, 'minute': 0},
        'lunch': {'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0},
      };
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(prefs, meal), isFalse, reason: meal);
      }
    });
  });

  group('isMealReminderEnabled — new format, master on (per-meal enabled)',
      () {
    test('mixed per-meal flags are each respected independently', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isTrue);
      expect(isMealReminderEnabled(prefs, 'lunch'), isFalse);
      expect(isMealReminderEnabled(prefs, 'dinner'), isTrue);
    });

    test('all three enabled', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': true, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': true, 'hour': 20, 'minute': 0},
      };
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(prefs, meal), isTrue, reason: meal);
      }
    });

    test('all three disabled', () {
      final prefs = {
        'enabled': true,
        'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': false, 'hour': 13, 'minute': 0},
        'dinner': {'enabled': false, 'hour': 20, 'minute': 0},
      };
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(prefs, meal), isFalse, reason: meal);
      }
    });

    test(
        'an explicit per-meal enabled=false overrides a top-level enabled=true '
        'that also exists on the doc', () {
      final prefs = {
        'enabled': true, // master on
        'breakfast': {'enabled': false, 'hour': 9, 'minute': 0},
        'lunch': {'enabled': true, 'hour': 13, 'minute': 0},
        'dinner': {'hour': 20, 'minute': 0}, // no per-meal key at all
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isFalse);
      expect(isMealReminderEnabled(prefs, 'lunch'), isTrue);
      // dinner has no per-meal 'enabled' key, so it falls back to the
      // top-level flag, which is true here.
      expect(isMealReminderEnabled(prefs, 'dinner'), isTrue);
    });

    test('malformed per-meal entry (not a Map) falls back to top-level flag',
        () {
      final prefs = {
        'enabled': true,
        'breakfast': 'not a map',
      };
      expect(isMealReminderEnabled(prefs, 'breakfast'), isTrue);
    });
  });

  test('all 8 enabled/disabled combinations resolve independently when the '
      'master is on', () {
    for (final b in [false, true]) {
      for (final l in [false, true]) {
        for (final d in [false, true]) {
          final prefs = {
            'enabled': true,
            'breakfast': {'enabled': b, 'hour': 9, 'minute': 0},
            'lunch': {'enabled': l, 'hour': 13, 'minute': 0},
            'dinner': {'enabled': d, 'hour': 20, 'minute': 0},
          };
          expect(isMealReminderEnabled(prefs, 'breakfast'), b);
          expect(isMealReminderEnabled(prefs, 'lunch'), l);
          expect(isMealReminderEnabled(prefs, 'dinner'), d);
        }
      }
    }
  });

  test('the same 8 combinations all resolve false when the master is off',
      () {
    for (final b in [false, true]) {
      for (final l in [false, true]) {
        for (final d in [false, true]) {
          final prefs = {
            'enabled': false,
            'breakfast': {'enabled': b, 'hour': 9, 'minute': 0},
            'lunch': {'enabled': l, 'hour': 13, 'minute': 0},
            'dinner': {'enabled': d, 'hour': 20, 'minute': 0},
          };
          expect(isMealReminderEnabled(prefs, 'breakfast'), isFalse);
          expect(isMealReminderEnabled(prefs, 'lunch'), isFalse);
          expect(isMealReminderEnabled(prefs, 'dinner'), isFalse);
          // But each meal's own stored state survives underneath.
          expect(mealReminderOwnEnabled(prefs, 'breakfast'), b);
          expect(mealReminderOwnEnabled(prefs, 'lunch'), l);
          expect(mealReminderOwnEnabled(prefs, 'dinner'), d);
        }
      }
    }
  });

  group('buildMealReminderPrefsPayload', () {
    test('includes the master flag as a top-level enabled field', () {
      final payload = buildMealReminderPrefsPayload(
        masterEnabled: true,
        enabled: {'breakfast': true, 'lunch': false, 'dinner': true},
        times: {
          'breakfast': const TimeOfDay(hour: 7, minute: 15),
          'lunch': const TimeOfDay(hour: 12, minute: 30),
          'dinner': const TimeOfDay(hour: 19, minute: 45),
        },
      );

      expect(payload['enabled'], isTrue);
      expect(payload, {
        'enabled': true,
        'breakfast': {'enabled': true, 'hour': 7, 'minute': 15},
        'lunch': {'enabled': false, 'hour': 12, 'minute': 30},
        'dinner': {'enabled': true, 'hour': 19, 'minute': 45},
      });
    });

    test('master can be false while per-meal flags are preserved untouched',
        () {
      final payload = buildMealReminderPrefsPayload(
        masterEnabled: false,
        enabled: {'breakfast': true, 'lunch': false, 'dinner': true},
        times: {
          'breakfast': const TimeOfDay(hour: 7, minute: 15),
          'lunch': const TimeOfDay(hour: 12, minute: 30),
          'dinner': const TimeOfDay(hour: 19, minute: 45),
        },
      );

      expect(payload['enabled'], isFalse);
      expect(payload['breakfast'], {'enabled': true, 'hour': 7, 'minute': 15});
      expect(payload['dinner'], {'enabled': true, 'hour': 19, 'minute': 45});
    });

    test('a disabled meal keeps its selected time in the payload', () {
      final payload = buildMealReminderPrefsPayload(
        masterEnabled: true,
        enabled: {'breakfast': false, 'lunch': false, 'dinner': false},
        times: {
          'breakfast': const TimeOfDay(hour: 6, minute: 0),
          'lunch': const TimeOfDay(hour: 13, minute: 0),
          'dinner': const TimeOfDay(hour: 20, minute: 0),
        },
      );

      expect(payload['breakfast'], {'enabled': false, 'hour': 6, 'minute': 0});
    });
  });

  group('mealReminderTimeOfDay', () {
    const fallback = TimeOfDay(hour: 9, minute: 0);

    test('reads hour/minute from a well-formed meal entry', () {
      final prefs = {
        'breakfast': {'hour': 7, 'minute': 45},
      };
      expect(mealReminderTimeOfDay(prefs, 'breakfast', fallback),
          const TimeOfDay(hour: 7, minute: 45));
    });

    test('falls back to the default when the meal key is missing', () {
      expect(mealReminderTimeOfDay({}, 'breakfast', fallback), fallback);
    });

    test('falls back to the default when prefs is null', () {
      expect(mealReminderTimeOfDay(null, 'breakfast', fallback), fallback);
    });

    test('falls back to the default when the meal entry is not a Map', () {
      final prefs = {'breakfast': 'garbage'};
      expect(mealReminderTimeOfDay(prefs, 'breakfast', fallback), fallback);
    });

    test('falls back to the default when hour/minute are missing or wrong type',
        () {
      expect(
        mealReminderTimeOfDay(
            {'breakfast': {'hour': '9', 'minute': 0}}, 'breakfast', fallback),
        fallback,
      );
      expect(
        mealReminderTimeOfDay(
            {'breakfast': {'minute': 0}}, 'breakfast', fallback),
        fallback,
      );
    });

    test('this also works against the new per-meal-enabled format', () {
      final prefs = {
        'breakfast': {'enabled': true, 'hour': 6, 'minute': 15},
      };
      expect(mealReminderTimeOfDay(prefs, 'breakfast', fallback),
          const TimeOfDay(hour: 6, minute: 15));
    });

    test('a disabled/hidden meal still returns its stored time (never reset)',
        () {
      final prefs = {
        'enabled': false, // master off
        'breakfast': {'enabled': false, 'hour': 6, 'minute': 15},
      };
      expect(mealReminderTimeOfDay(prefs, 'breakfast', fallback),
          const TimeOfDay(hour: 6, minute: 15));
    });
  });

  group('UserModel.mealLoggingReminderPrefs backward compatibility', () {
    test('an old-format doc loads without crashing and round-trips as-is',
        () {
      final oldFormatJson = {
        'email': 'user@example.com',
        'mealLoggingReminderPrefs': {
          'enabled': true,
          'breakfast': {'hour': 9, 'minute': 0},
          'lunch': {'hour': 13, 'minute': 0},
          'dinner': {'hour': 20, 'minute': 0},
        },
      };

      final user = UserModel.fromJson(oldFormatJson);
      expect(user.mealLoggingReminderPrefs, oldFormatJson['mealLoggingReminderPrefs']);

      for (final meal in mealReminderOrder) {
        expect(
            isMealReminderEnabled(user.mealLoggingReminderPrefs, meal), isTrue);
      }
    });

    test('a missing mealLoggingReminderPrefs field loads without crashing',
        () {
      final user = UserModel.fromJson({'email': 'user@example.com'});
      expect(user.mealLoggingReminderPrefs, isNull);
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(user.mealLoggingReminderPrefs, meal),
            isFalse);
      }
    });
  });

  group('round trip: master and per-meal state survive being toggled off '
      'and back on', () {
    test('a meal turned off and back on keeps its previously chosen time',
        () {
      // Simulates the page's in-memory state: _mealTimes is independent of
      // _mealEnabled and is never reset when a meal is toggled off.
      final times = {
        'breakfast': const TimeOfDay(hour: 7, minute: 30),
        'lunch': const TimeOfDay(hour: 13, minute: 0),
        'dinner': const TimeOfDay(hour: 20, minute: 0),
      };
      var enabled = {'breakfast': true, 'lunch': true, 'dinner': true};

      // Turn breakfast off — times map is untouched.
      enabled = {...enabled, 'breakfast': false};
      var payload = buildMealReminderPrefsPayload(
          masterEnabled: true, enabled: enabled, times: times);
      expect(payload['breakfast'], {'enabled': false, 'hour': 7, 'minute': 30});

      // Turn breakfast back on — the 7:30 time survived the round trip.
      enabled = {...enabled, 'breakfast': true};
      payload = buildMealReminderPrefsPayload(
          masterEnabled: true, enabled: enabled, times: times);
      expect(payload['breakfast'], {'enabled': true, 'hour': 7, 'minute': 30});
    });

    test(
        'flipping the master off and back on restores each meal\'s prior '
        'enabled state without needing to re-toggle them', () {
      // Started with a mixed state.
      const enabled = {'breakfast': true, 'lunch': false, 'dinner': true};
      const times = {
        'breakfast': TimeOfDay(hour: 7, minute: 0),
        'lunch': TimeOfDay(hour: 13, minute: 0),
        'dinner': TimeOfDay(hour: 19, minute: 0),
      };

      // Master turned off: payload keeps every per-meal flag as-is.
      final masterOffPayload = buildMealReminderPrefsPayload(
          masterEnabled: false, enabled: enabled, times: times);
      expect(mealReminderOwnEnabled(masterOffPayload, 'breakfast'), isTrue);
      expect(mealReminderOwnEnabled(masterOffPayload, 'lunch'), isFalse);
      expect(mealReminderOwnEnabled(masterOffPayload, 'dinner'), isTrue);
      // But nothing is actually enabled while the master is off.
      for (final meal in mealReminderOrder) {
        expect(isMealReminderEnabled(masterOffPayload, meal), isFalse);
      }

      // Master turned back on with the same per-meal map: exactly the
      // original mixed state re-emerges, with no re-toggling needed.
      final masterOnPayload = buildMealReminderPrefsPayload(
          masterEnabled: true, enabled: enabled, times: times);
      expect(isMealReminderEnabled(masterOnPayload, 'breakfast'), isTrue);
      expect(isMealReminderEnabled(masterOnPayload, 'lunch'), isFalse);
      expect(isMealReminderEnabled(masterOnPayload, 'dinner'), isTrue);
    });
  });
}
