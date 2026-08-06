import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification_overlay.dart';
import 'package:flutter_app/features/tracking/widgets/tracker_card.dart';

/// Watches tracker state (already computed elsewhere by [TrackerProvider] /
/// [TrackerService]) and shows a single floating banner the first time a
/// category crosses its goal during the current tracking period.
///
/// Doesn't compute goals/progress itself — just compares before/after
/// [TrackerGoal.currentValue] snapshots and defers to
/// [TrackerCard.shouldStayGreenAboveGoal] for categories that never warn.
class GoalLimitNotificationService {
  GoalLimitNotificationService._();

  static final GoalLimitNotificationService instance =
      GoalLimitNotificationService._();

  /// trackerId -> period key ("day-..." or "week-...") already notified for.
  final Map<String, String> _lastNotifiedPeriod = {};

  /// Captures current values for [trackers] to compare against after a
  /// meal-logging update completes.
  Map<String, double> snapshot(Iterable<TrackerGoal> trackers) {
    return {for (final tracker in trackers) tracker.id: tracker.currentValue};
  }

  /// Compares [before] values against the current state of [trackers] and,
  /// if any eligible category just crossed its goal for the first time this
  /// period, shows one banner listing all of them.
  void checkAndNotify({
    required Map<String, double> before,
    required Iterable<TrackerGoal> trackers,
  }) {
    final crossed = <TrackerGoal>[];

    for (final tracker in trackers) {
      final beforeValue = before[tracker.id];
      if (beforeValue == null) continue;
      if (tracker.goalValue <= 0) continue;

      // Categories that intentionally stay green above goal never warn.
      if (TrackerCard.shouldStayGreenAboveGoal(tracker.category)) continue;

      final justCrossed =
          beforeValue <= tracker.goalValue && tracker.currentValue > tracker.goalValue;
      if (!justCrossed) continue;

      final periodKey = _periodKey(tracker.isWeeklyGoal);
      if (_lastNotifiedPeriod[tracker.id] == periodKey) continue;

      _lastNotifiedPeriod[tracker.id] = periodKey;
      crossed.add(tracker);
    }

    if (crossed.isEmpty) return;

    final isWeekly = crossed.every((tracker) => tracker.isWeeklyGoal);
    GoalLimitNotificationOverlay.show(isWeekly: isWeekly, categories: crossed);
  }

  /// Daily keys change every calendar day; weekly keys change every 7 days.
  /// Overwriting the stored key on period change is how state "clears" for a
  /// tracker without needing a separate reset pass or persistence.
  String _periodKey(bool isWeeklyGoal) {
    final now = DateTime.now();
    if (isWeeklyGoal) {
      final weekIndex = now.difference(DateTime(2000, 1, 3)).inDays ~/ 7;
      return 'week-$weekIndex';
    }
    return 'day-${now.year}-${now.month}-${now.day}';
  }
}
