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

  /// Categories currently over their goal for the active day/week, in the
  /// order they first crossed it. Kept separate so a daily crossing and a
  /// weekly crossing never get merged into one confusing "today's/this
  /// week's" sentence. Cleared per-tracker as its period rolls over (see
  /// [checkAndNotify]), which is how this list "resets" in step with the
  /// same day/week boundary the trackers themselves use.
  final Map<String, TrackerGoal> _accumulatedDaily = {};
  final Map<String, TrackerGoal> _accumulatedWeekly = {};

  /// Whether a daily/weekly banner has an unshown crossing waiting to be
  /// displayed. Durable (not derived from a single [checkAndNotify] call)
  /// so a second crossing arriving before the first banner is dismissed
  /// doesn't lose track of a still-queued one — see [_presentPendingBanners].
  bool _dailyBannerPending = false;
  bool _weeklyBannerPending = false;

  /// Captures current values for [trackers] to compare against after a
  /// meal-logging update completes.
  Map<String, double> snapshot(Iterable<TrackerGoal> trackers) {
    return {for (final tracker in trackers) tracker.id: tracker.currentValue};
  }

  /// Compares [before] values against the current state of [trackers]. If
  /// any eligible category just crossed its goal for the first time this
  /// period, it's added to the running "exceeded today/this week" list and
  /// the banner is shown (or updated) with the full accumulated list — not
  /// just the category that just crossed. Re-logging more of a category
  /// that was already over its goal doesn't re-trigger anything, since it
  /// can't "just cross" a line it was already past.
  void checkAndNotify({
    required Map<String, double> before,
    required Iterable<TrackerGoal> trackers,
  }) {
    bool dailyChanged = false;
    bool weeklyChanged = false;

    for (final tracker in trackers) {
      final beforeValue = before[tracker.id];
      if (beforeValue == null) continue;
      if (tracker.goalValue <= 0) continue;

      // Categories that intentionally stay green above goal never warn.
      if (TrackerCard.shouldStayGreenAboveGoal(tracker.category)) continue;

      final periodKey = _periodKey(tracker.isWeeklyGoal);
      final accumulated =
          tracker.isWeeklyGoal ? _accumulatedWeekly : _accumulatedDaily;

      // New day/week for this tracker: drop its stale accumulated entry.
      if (_lastNotifiedPeriod[tracker.id] != periodKey) {
        accumulated.remove(tracker.id);
      }

      final justCrossed =
          beforeValue <= tracker.goalValue && tracker.currentValue > tracker.goalValue;
      if (!justCrossed) continue;
      if (_lastNotifiedPeriod[tracker.id] == periodKey) continue;

      _lastNotifiedPeriod[tracker.id] = periodKey;
      accumulated[tracker.id] = tracker;
      if (tracker.isWeeklyGoal) {
        weeklyChanged = true;
      } else {
        dailyChanged = true;
      }
    }

    if (dailyChanged) _dailyBannerPending = true;
    if (weeklyChanged) _weeklyBannerPending = true;
    _presentPendingBanners();
  }

  /// Only one banner can occupy the overlay at a time. If both a daily and a
  /// weekly category are pending, shows the daily banner first (it's the
  /// more common case) and re-queues itself as the weekly banner's
  /// [onDismissed] callback — rather than dropping it, since a weekly goal
  /// that's already been crossed can't "just cross" again to re-trigger it
  /// later.
  ///
  /// Re-derives which banner(s) are pending from the durable
  /// [_dailyBannerPending]/[_weeklyBannerPending] flags each time it runs,
  /// rather than a single [checkAndNotify] call's local result — calling
  /// [GoalLimitNotificationOverlay.show] again to update an already-showing
  /// banner (e.g. a second daily crossing arriving before the first is
  /// dismissed) replaces the entry directly, without invoking the previous
  /// entry's own [onDismissed]. A queued weekly follow-up captured only from
  /// that earlier call would otherwise be silently discarded; re-checking
  /// the flags fresh means every subsequent show() carries the correct
  /// still-pending follow-up instead.
  void _presentPendingBanners() {
    if (_dailyBannerPending) {
      _dailyBannerPending = false;
      GoalLimitNotificationOverlay.show(
        isWeekly: false,
        categories: _accumulatedDaily.values.toList(),
        onDismissed: _weeklyBannerPending ? _presentPendingBanners : null,
      );
    } else if (_weeklyBannerPending) {
      _weeklyBannerPending = false;
      GoalLimitNotificationOverlay.show(
        isWeekly: true,
        categories: _accumulatedWeekly.values.toList(),
      );
    }
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
