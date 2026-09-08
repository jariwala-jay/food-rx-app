import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

/// Centered modal-style card shown when one or more tracker categories
/// cross their daily/weekly goal. Not a dialog or SnackBar — lives in an
/// [Overlay] (over a dimming scrim) so it can be triggered from any screen.
/// Stays on screen until the user taps "Dismiss"; there is no auto-dismiss
/// timer, since the whole point is that it shouldn't be missed.
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

  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const Duration fadeOutDuration = Duration(milliseconds: 250);

  /// "Daily/Weekly limit(s) exceeded" -- singular vs. plural "limit" tracks
  /// how many categories were crossed, independent of the daily/weekly
  /// period. Extracted as a pure function (rather than inline in [build])
  /// so the copy is unit-testable without pumping the widget.
  static String buildTitle({required bool isWeekly, required int categoryCount}) {
    final period = isWeekly ? 'Weekly' : 'Daily';
    final limitWord = categoryCount > 1 ? 'limits' : 'limit';
    return '$period $limitWord exceeded';
  }

  /// This reflects what the feature actually does -- warns when a category
  /// crosses ABOVE its recommended ceiling (sodium, calories, ...), not a
  /// "reached a target" congratulatory message. The actual category names
  /// are left to the chip row below rather than spelled out in the
  /// sentence, so the copy stays the same whether one or several categories
  /// are listed.
  static String buildBody({required bool isWeekly}) {
    final periodWord = isWeekly ? "weekly" : "daily";
    return "You've exceeded your $periodWord recommended intake for";
  }

  @override
  State<GoalLimitNotification> createState() => _GoalLimitNotificationState();
}

class _GoalLimitNotificationState extends State<GoalLimitNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GoalLimitNotification.fadeInDuration,
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;

    await _controller.animateBack(
      0.0,
      duration: GoalLimitNotification.fadeOutDuration,
      curve: Curves.easeIn,
    );
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final categoryNames = widget.categories.map((t) => t.name).toList();
    final title = GoalLimitNotification.buildTitle(
      isWeekly: widget.isWeekly,
      categoryCount: categoryNames.length,
    );
    final body = GoalLimitNotification.buildBody(isWeekly: widget.isWeekly);

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '$title. $body',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.30),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.white,
              elevation: 0,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
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
                                    color:
                                        GoalLimitNotification.textPrimaryColor),
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
                              AppTypography.bg_14_sb,
                              maxScale: 1.4,
                            ).copyWith(
                                color:
                                    GoalLimitNotification.textSecondaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _dismiss,
                            style: TextButton.styleFrom(
                              foregroundColor:
                                  GoalLimitNotification.warningIconColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
