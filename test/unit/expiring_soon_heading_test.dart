import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/simple_notification_service.dart';

// Regression coverage for the finalized Expiring Soon copy: the day-count
// urgency signal moved from the body (previously dynamic) into the heading
// (now dynamic today/tomorrow/N-days), while the body became fixed. Mirrors
// expiringSoonHeading() in
// gcloud/functions/notification-scheduler/index.js — both must stay in sync.
void main() {
  group('SimpleNotificationService.expiringItemHeading', () {
    test('expiring today (0 days) reads "expires today"', () {
      final today = DateTime.now();
      expect(
        SimpleNotificationService.expiringItemHeading('Milk', today),
        'Milk expires today',
      );
    });

    test('already past due still reads "expires today", not a negative count', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(
        SimpleNotificationService.expiringItemHeading('Milk', yesterday),
        'Milk expires today',
      );
    });

    test('expiring tomorrow reads "expires tomorrow"', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(
        SimpleNotificationService.expiringItemHeading('Milk', tomorrow),
        'Milk expires tomorrow',
      );
    });

    test('expiring in 3 days reads "expires in 3 days"', () {
      final inThreeDays = DateTime.now().add(const Duration(days: 3));
      expect(
        SimpleNotificationService.expiringItemHeading('Milk', inThreeDays),
        'Milk expires in 3 days',
      );
    });

    test('day count is calendar-day based, not 24h based', () {
      // 23 hours from now can still be "tomorrow" if it crosses local
      // midnight — this is exactly the calendar-day semantics _dateOnly()
      // is meant to provide, not a raw duration check.
      final now = DateTime.now();
      final justAfterMidnightTomorrow = DateTime(now.year, now.month, now.day)
          .add(const Duration(days: 1, minutes: 1));
      expect(
        SimpleNotificationService.expiringItemHeading(
          'Milk',
          justAfterMidnightTomorrow,
        ),
        'Milk expires tomorrow',
      );
    });
  });

  group('SimpleNotificationService.expiringItemsListSummary', () {
    test('3 or fewer names are joined with no truncation', () {
      expect(SimpleNotificationService.expiringItemsListSummary(['Milk']), 'Milk');
      expect(
        SimpleNotificationService.expiringItemsListSummary(['Milk', 'Eggs']),
        'Milk, Eggs',
      );
      expect(
        SimpleNotificationService.expiringItemsListSummary(['Milk', 'Eggs', 'Yogurt']),
        'Milk, Eggs, Yogurt',
      );
    });

    test('more than 3 names truncates with an "and N more" tail', () {
      expect(
        SimpleNotificationService.expiringItemsListSummary(
          ['Milk', 'Eggs', 'Yogurt', 'Spinach'],
        ),
        'Milk, Eggs, Yogurt and 1 more',
      );
      expect(
        SimpleNotificationService.expiringItemsListSummary(
          ['Milk', 'Eggs', 'Yogurt', 'Spinach', 'Butter'],
        ),
        'Milk, Eggs, Yogurt and 2 more',
      );
    });
  });
}
