import 'package:flutter/material.dart';

import 'package:flutter_app/core/services/navigation_service.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification.dart';

/// Inserts/removes the floating [GoalLimitNotification] into the app's root
/// [Overlay] so it can appear above the bottom navigation bar from any
/// screen, without needing a local BuildContext at the call site.
class GoalLimitNotificationOverlay {
  GoalLimitNotificationOverlay._();

  static const double _bottomNavHeight = 70.0;
  static const double _bottomMargin = 12.0;
  static const double _horizontalMargin = 16.0;

  static OverlayEntry? _entry;

  static void show({
    required bool isWeekly,
    required List<TrackerGoal> categories,
  }) {
    if (categories.isEmpty) return;

    final overlayState = NavigationService.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _removeCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        final bottomSafeInset = MediaQuery.of(context).padding.bottom;
        return Positioned(
          left: _horizontalMargin,
          right: _horizontalMargin,
          bottom: _bottomNavHeight + bottomSafeInset + _bottomMargin,
          child: GoalLimitNotification(
            isWeekly: isWeekly,
            categories: categories,
            onDismissed: () {
              if (identical(_entry, entry)) {
                _entry = null;
              }
              if (entry.mounted) {
                entry.remove();
              }
            },
          ),
        );
      },
    );

    _entry = entry;
    overlayState.insert(entry);
  }

  static void _removeCurrent() {
    final current = _entry;
    _entry = null;
    if (current != null && current.mounted) {
      current.remove();
    }
  }
}
