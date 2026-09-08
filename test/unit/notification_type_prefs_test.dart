import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/user_model.dart';

// Regression coverage for UserModel.notificationTypePrefs — the field
// backing the four Notification Settings toggles (Expiring Ingredients,
// Tracker Reminders, Education, Administrative Updates) that previously
// only changed local UI state and were never persisted. Mirrors the
// existing round-trip guarantees mealLoggingReminderPrefs already relies on.
void main() {
  UserModel baseUser({Map<String, dynamic>? notificationTypePrefs}) {
    return UserModel(
      email: 'user@example.com',
      notificationTypePrefs: notificationTypePrefs,
    );
  }

  group('UserModel.notificationTypePrefs', () {
    test('fromJson reads the field through unchanged', () {
      final json = {
        'email': 'user@example.com',
        'notificationTypePrefs': {
          'expiringIngredients': false,
          'trackerReminders': true,
        },
      };
      final user = UserModel.fromJson(json);
      expect(user.notificationTypePrefs, {
        'expiringIngredients': false,
        'trackerReminders': true,
      });
    });

    test('fromJson tolerates a missing field (existing accounts)', () {
      final user = UserModel.fromJson({'email': 'user@example.com'});
      expect(user.notificationTypePrefs, isNull);
    });

    test('toJson round-trips the exact map back out', () {
      final prefs = {
        'expiringIngredients': false,
        'trackerReminders': false,
        'education': true,
        'adminUpdates': true,
      };
      final user = baseUser(notificationTypePrefs: prefs);
      expect(user.toJson()['notificationTypePrefs'], prefs);
    });

    test('copyWith replaces the map wholesale, not merges', () {
      final original = baseUser(
        notificationTypePrefs: {'expiringIngredients': false},
      );
      final updated = original.copyWith(
        notificationTypePrefs: {'trackerReminders': false},
      );
      expect(updated.notificationTypePrefs, {'trackerReminders': false});
    });

    test('copyWith with no argument preserves the existing map', () {
      final original = baseUser(
        notificationTypePrefs: {'education': false},
      );
      final updated = original.copyWith(name: 'New Name');
      expect(updated.notificationTypePrefs, {'education': false});
    });

    test('a user who never touched Settings has a null map (defaults to enabled everywhere)', () {
      final user = baseUser();
      expect(user.notificationTypePrefs, isNull);
    });
  });
}
