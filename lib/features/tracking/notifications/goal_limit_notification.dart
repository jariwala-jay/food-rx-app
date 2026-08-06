import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

/// Floating Material 3 banner shown when one or more tracker categories
/// cross their daily/weekly goal. Not a dialog or SnackBar — lives in an
/// [Overlay] so it can be triggered from any screen.
class GoalLimitNotification extends StatefulWidget {
  final bool isWeekly;
  final List<TrackerGoal> categories;
  final VoidCallback onDismissed;

  const GoalLimitNotification({
    super.key,
    required this.isWeekly,
    required this.categories,
    required this.onDismissed,
  });

  static const Color textPrimaryColor = Color(0xFF202124);
  static const Color textSecondaryColor = Color(0xFF5F6368);
  static const Color warningIconColor = Color(0xFFFF6A00);
  static const Color dividerColor = Color(0xFFE5E7EB);

  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const Duration visibleDuration = Duration(seconds: 5);
  static const Duration fadeOutDuration = Duration(milliseconds: 250);

  @override
  State<GoalLimitNotification> createState() => _GoalLimitNotificationState();
}

class _GoalLimitNotificationState extends State<GoalLimitNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _autoDismissTimer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GoalLimitNotification.fadeInDuration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
    _autoDismissTimer = Timer(
      GoalLimitNotification.fadeInDuration + GoalLimitNotification.visibleDuration,
      () => _dismiss(immediate: false),
    );
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss({required bool immediate}) async {
    if (_dismissing) return;
    _dismissing = true;
    _autoDismissTimer?.cancel();

    if (immediate) {
      widget.onDismissed();
      return;
    }

    await _controller.animateBack(
      0.0,
      duration: GoalLimitNotification.fadeOutDuration,
      curve: Curves.easeIn,
    );
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.isWeekly ? 'Weekly limit exceeded' : 'Daily limit exceeded';
    final periodPhrase = widget.isWeekly ? "this week's" : "today's";
    final body =
        "You've exceeded $periodPhrase recommended intake for";
    final categoryNames = widget.categories.map((t) => t.name).join(', ');

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '$title. $body $categoryNames.',
          child: Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: GoalLimitNotification.warningIconColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.scaleStyle(
                            context,
                            AppTypography.bg_16_sb,
                            maxScale: 1.4,
                          ).copyWith(
                              color: GoalLimitNotification.textPrimaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      body,
                      style: AppTypography.scaleStyle(
                        context,
                        AppTypography.bg_14_r,
                        maxScale: 1.4,
                      ).copyWith(
                          color: GoalLimitNotification.textSecondaryColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: widget.categories
                          .map((tracker) => _CategoryChip(tracker: tracker))
                          .toList(),
                    ),
                  ),
                  const Divider(
                    height: 20,
                    color: GoalLimitNotification.dividerColor,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _dismiss(immediate: true),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            GoalLimitNotification.warningIconColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'Dismiss',
                        style: AppTypography.scaleStyle(
                          context,
                          AppTypography.bg_14_sb,
                          maxScale: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final TrackerGoal tracker;

  const _CategoryChip({required this.tracker});

  @override
  Widget build(BuildContext context) {
    final iconPath = getTrackerIconAsset(tracker.category);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: iconPath.endsWith('.svg')
              ? SvgPicture.asset(iconPath, width: 18, height: 18)
              : Image.asset(iconPath, width: 18, height: 18),
        ),
        const SizedBox(width: 6),
        Text(
          tracker.name,
          style: AppTypography.scaleStyle(
            context,
            AppTypography.bg_14_m,
            maxScale: 1.4,
          ).copyWith(color: GoalLimitNotification.textPrimaryColor),
        ),
      ],
    );
  }
}
