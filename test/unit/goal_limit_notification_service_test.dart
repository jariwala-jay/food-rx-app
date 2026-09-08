import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/core/services/navigation_service.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification_service.dart';

// Regression coverage for the fix to GoalLimitNotificationService.checkAndNotify:
// a single action that crosses both a daily and a weekly goal must surface
// both warnings (daily first, then weekly once dismissed), not silently drop
// the weekly one.
//
// GoalLimitNotificationService.instance is a process-wide singleton whose
// _accumulatedDaily/_accumulatedWeekly maps are never cleared for a tracker
// id that isn't passed into a later checkAndNotify call, so earlier tests'
// categories can still be present when a later test's banner renders (e.g.
// making the title read "limits" instead of "limit"). Each test below uses a
// tracker *name* unique to that test and asserts on that chip's presence,
// plus the daily/weekly period word via textContaining, rather than the
// exact singular/plural title -- so cross-test accumulation can't produce a
// false pass or a false fail.
void main() {
  TrackerGoal sodiumGoal(String id, String name, {double current = 0}) =>
      TrackerGoal(
        id: id,
        userId: 'u1',
        name: name,
        category: TrackerCategory.sodium,
        goalValue: 100,
        currentValue: current,
        unit: TrackerUnit.mg,
        dietType: 'DASH',
        isWeeklyGoal: false,
      );

  TrackerGoal satFatWeeklyGoal(String id, String name, {double current = 0}) =>
      TrackerGoal(
        id: id,
        userId: 'u1',
        name: name,
        category: TrackerCategory.fatsOils,
        goalValue: 100,
        currentValue: current,
        unit: TrackerUnit.g,
        dietType: 'DASH',
        isWeeklyGoal: true,
      );

  Future<void> pumpHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  testWidgets('daily-only crossing shows only the daily banner',
      (tester) async {
    await pumpHost(tester);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final id = 'daily-only-$suffix';
    // Short, per-test-unique display name -- long enough to distinguish
    // this test's chip from another test's leftover accumulated one, short
    // enough not to overflow the chip row's fixed width.
    const name = 'SodiumT1';
    final goal = sodiumGoal(id, name, current: 150);

    GoalLimitNotificationService.instance.checkAndNotify(
      before: {id: 50},
      trackers: [goal],
    );
    await tester.pump();

    expect(find.textContaining('Daily limit'), findsOneWidget);
    expect(find.textContaining('Weekly limit'), findsNothing);
    expect(find.text(name), findsOneWidget);
  });

  testWidgets('weekly-only crossing shows only the weekly banner',
      (tester) async {
    await pumpHost(tester);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final id = 'weekly-only-$suffix';
    const name = 'FatT2';
    final goal = satFatWeeklyGoal(id, name, current: 150);

    GoalLimitNotificationService.instance.checkAndNotify(
      before: {id: 50},
      trackers: [goal],
    );
    await tester.pump();

    expect(find.textContaining('Weekly limit'), findsOneWidget);
    expect(find.textContaining('Daily limit'), findsNothing);
    expect(find.text(name), findsOneWidget);
  });

  testWidgets(
      'already-over-goal values never trigger a banner (no re-crossing)',
      (tester) async {
    await pumpHost(tester);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final id = 'already-over-$suffix';
    final goal = sodiumGoal(id, 'SodiumT3', current: 160);

    GoalLimitNotificationService.instance.checkAndNotify(
      before: {id: 150},
      trackers: [goal],
    );
    await tester.pump();

    expect(find.byType(GoalLimitNotification), findsNothing);
  });

  testWidgets(
      'crossing daily and weekly in the same action shows both, daily then weekly',
      (tester) async {
    await pumpHost(tester);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final dailyId = 'both-daily-$suffix';
    final weeklyId = 'both-weekly-$suffix';
    const dailyName = 'SodiumT4';
    const weeklyName = 'FatT4';
    final dailyGoal = sodiumGoal(dailyId, dailyName, current: 150);
    final weeklyGoal = satFatWeeklyGoal(weeklyId, weeklyName, current: 150);

    GoalLimitNotificationService.instance.checkAndNotify(
      before: {dailyId: 50, weeklyId: 50},
      trackers: [dailyGoal, weeklyGoal],
    );
    await tester.pump();

    // Daily banner shows first, carrying this test's daily category.
    expect(find.textContaining('Daily limit'), findsOneWidget);
    expect(find.textContaining('Weekly limit'), findsNothing);
    expect(find.text(dailyName), findsOneWidget);
    expect(find.text(weeklyName), findsNothing);

    // Dismissing it reveals the queued weekly banner instead of losing it.
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Weekly limit'), findsOneWidget);
    expect(find.textContaining('Daily limit'), findsNothing);
    expect(find.text(weeklyName), findsOneWidget);
  });

  testWidgets(
      'a second daily crossing before the first banner is dismissed does '
      'not lose a still-queued weekly banner', (tester) async {
    await pumpHost(tester);
    final suffix = DateTime.now().microsecondsSinceEpoch;
    final daily1Id = 'interleave-daily1-$suffix';
    final weeklyId = 'interleave-weekly-$suffix';
    final daily2Id = 'interleave-daily2-$suffix';
    const daily1Name = 'SodiumT5';
    const weeklyName = 'FatT5';
    const daily2Name = 'SugarT5';

    // Call 1: a daily and a weekly tracker cross together -- daily banner
    // shows now, weekly banner is queued for after it's dismissed.
    GoalLimitNotificationService.instance.checkAndNotify(
      before: {daily1Id: 50, weeklyId: 50},
      trackers: [
        sodiumGoal(daily1Id, daily1Name, current: 150),
        satFatWeeklyGoal(weeklyId, weeklyName, current: 150),
      ],
    );
    await tester.pump();
    expect(find.textContaining('Daily limit'), findsOneWidget);
    expect(find.text(daily1Name), findsOneWidget);

    // Call 2, before the first banner is ever dismissed: a *different*
    // daily tracker crosses. This replaces the still-showing daily banner
    // outright (GoalLimitNotificationOverlay.show() removes the old entry
    // directly, without running its onDismissed) -- the queued weekly
    // follow-up must survive this replacement.
    GoalLimitNotificationService.instance.checkAndNotify(
      before: {daily2Id: 50},
      trackers: [sodiumGoal(daily2Id, daily2Name, current: 150)],
    );
    await tester.pump();
    expect(find.textContaining('Daily limit'), findsOneWidget);
    expect(find.text(daily2Name), findsOneWidget);
    expect(find.textContaining('Weekly limit'), findsNothing);

    // Dismissing this (replaced) daily banner must still reveal the weekly
    // banner queued all the way back in call 1.
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Weekly limit'), findsOneWidget);
    expect(find.textContaining('Daily limit'), findsNothing);
    expect(find.text(weeklyName), findsOneWidget);
  });
}
