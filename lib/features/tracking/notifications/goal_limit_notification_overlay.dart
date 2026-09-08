import 'package:flutter/material.dart';

import 'package:flutter_app/core/services/navigation_service.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/features/tracking/notifications/goal_limit_notification.dart';

/// Inserts/removes the floating [GoalLimitNotification] into the app's root
/// [Overlay], centered over a dimming scrim, so it can appear from any
/// screen without needing a local BuildContext at the call site. The scrim
/// blocks taps to the app behind it (it's meant to be read and explicitly
/// dismissed, not glanced past) but never dismisses on its own tap — only
/// the notification's own "Dismiss" button does.
class GoalLimitNotificationOverlay {
  GoalLimitNotificationOverlay._();

  static const double _horizontalMargin = 16.0;
  static const double _maxWidth = 400.0;

  static OverlayEntry? _entry;

  static void show({
    required bool isWeekly,
    required List<TrackerGoal> categories,
    VoidCallback? onDismissed,
  }) {
    if (categories.isEmpty) return;

    final overlayState = NavigationService.navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _removeCurrent();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        void handleDismissed() {
          if (identical(_entry, entry)) {
            _entry = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
          onDismissed?.call();
        }

        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: Container(color: Colors.black.withOpacity(0.45)),
                ),
              ),
              Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _horizontalMargin),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxWidth),
                    child: GoalLimitNotification(
                      isWeekly: isWeekly,
                      categories: categories,
                      onDismissed: handleDismissed,
                    ),
                  ),
                ),
              ),
            ],
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
