import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification.dart';

// Regression coverage for the finalized Goal Limit copy: it must accurately
// describe what the feature actually does (crossing ABOVE a recommended
// ceiling, possibly for several categories at once) rather than a "reached a
// target" congratulatory message. This is in-app-only — no push notification
// — but the copy still needs to match the real user experience.
void main() {
  group('GoalLimitNotification.buildTitle', () {
    test('daily, single category', () {
      expect(
        GoalLimitNotification.buildTitle(isWeekly: false, categoryCount: 1),
        'Daily limit exceeded',
      );
    });

    test('daily, multiple categories -> plural "limits"', () {
      expect(
        GoalLimitNotification.buildTitle(isWeekly: false, categoryCount: 2),
        'Daily limits exceeded',
      );
    });

    test('weekly, single category', () {
      expect(
        GoalLimitNotification.buildTitle(isWeekly: true, categoryCount: 1),
        'Weekly limit exceeded',
      );
    });

    test('weekly, multiple categories -> plural "limits"', () {
      expect(
        GoalLimitNotification.buildTitle(isWeekly: true, categoryCount: 3),
        'Weekly limits exceeded',
      );
    });
  });

  group('GoalLimitNotification.buildBody', () {
    // The category names themselves are no longer spelled out in the body
    // sentence — they're shown as chips below it instead, so the same
    // sentence fragment works whether one or several categories crossed
    // their goal. buildBody() doesn't take categoryNames at all anymore.
    test('daily body', () {
      expect(
        GoalLimitNotification.buildBody(isWeekly: false),
        "You've exceeded your daily recommended intake for",
      );
    });

    test('weekly body', () {
      expect(
        GoalLimitNotification.buildBody(isWeekly: true),
        "You've exceeded your weekly recommended intake for",
      );
    });
  });
}
