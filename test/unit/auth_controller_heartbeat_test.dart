import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

// Regression check for the app-inactivity false-positive bug: a user who
// opens the app daily but never force-quits it stayed on a live in-memory
// session, so resumeSessionIfNeeded() no-op'd and lastActiveAt was never
// refreshed on plain foreground resumes -- only on cold start/login. The fix
// adds a heartbeat on every resume, throttled to once per local calendar day
// via isSameLocalDay() so it doesn't spam the profile endpoint. This test
// covers that throttle boundary directly, without needing to mock ApiClient.
void main() {
  group('isSameLocalDay', () {
    test('same calendar day, different times of day, is same day', () {
      final morning = DateTime(2026, 8, 5, 8, 0);
      final evening = DateTime(2026, 8, 5, 23, 59);
      expect(isSameLocalDay(morning, evening), isTrue);
    });

    test('midnight boundary: one minute apart but different days is not same day', () {
      final justBeforeMidnight = DateTime(2026, 8, 5, 23, 59);
      final justAfterMidnight = DateTime(2026, 8, 6, 0, 1);
      expect(isSameLocalDay(justBeforeMidnight, justAfterMidnight), isFalse);
    });

    test('same day-of-month in a different month is not same day', () {
      final augFifth = DateTime(2026, 8, 5);
      final julyFifth = DateTime(2026, 7, 5);
      expect(isSameLocalDay(augFifth, julyFifth), isFalse);
    });

    test('same month/day in a different year is not same day', () {
      final thisYear = DateTime(2026, 8, 5);
      final lastYear = DateTime(2025, 8, 5);
      expect(isSameLocalDay(thisYear, lastYear), isFalse);
    });

    test('nearly 24 hours apart but crossing midnight is not same day', () {
      final today = DateTime(2026, 8, 5, 0, 30);
      final tomorrow = DateTime(2026, 8, 6, 0, 15);
      expect(isSameLocalDay(today, tomorrow), isFalse);
    });

    test('is reflexive and symmetric', () {
      final a = DateTime(2026, 8, 5, 10);
      final b = DateTime(2026, 8, 5, 20);
      expect(isSameLocalDay(a, a), isTrue);
      expect(isSameLocalDay(a, b), equals(isSameLocalDay(b, a)));
    });
  });
}
