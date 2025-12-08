import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../models/tracker_goal.dart';
import 'tracker_serving_info_modal.dart';
import 'package:flutter_app/core/utils/app_colors.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';

class TrackerCard extends StatelessWidget {
  final TrackerGoal tracker;
  final VoidCallback? onTap;
  final GlobalKey? infoShowcaseKey;

  const TrackerCard({
    Key? key,
    required this.tracker,
    this.onTap,
    this.infoShowcaseKey,
  }) : super(key: key);

  // Get progress color based on percentage and goal value
  // goalValue is needed to calculate the "0.5 below goal" threshold
  static Color getProgressColor(
    double progress,
    TrackerCategory category, {
    double goalValue = 5.0, // Default goal for backwards compatibility
  }) {
    // Categories that stay green above goal (no red overflow)
    final alwaysGreenAboveGoal = category == TrackerCategory.fruits ||
        category == TrackerCategory.veggies ||
        category == TrackerCategory.water;

    // For sodium (measured in mg), use fixed 75% threshold instead of 0.5 rule
    // Orange: 0-50%, Yellow: 50-75%, Green: 75-100%, Red: >100%
    if (category == TrackerCategory.sodium) {
      if (progress < 0.5) {
        return const Color(0xFFFF6A00); // Orange for < 50%
      } else if (progress < 0.75) {
        return const Color(0xFFFFA800); // Yellow for 50% - 75%
      } else if (progress <= 1.0) {
        return const Color(0xFF2CCC87); // Green for 75% - 100%
      } else {
        return const Color(0xFFFF5275); // Red for > 100%
      }
    }

    // Calculate the threshold for "0.5 below goal" (e.g., 4.5/5 = 90%)
    final nearGoalThreshold =
        goalValue > 0 ? (goalValue - 0.5) / goalValue : 0.9;

    // Color scheme for other trackers:
    // Orange: 0% - 50%
    // Yellow: 50% - 0.5 below goal
    // Green: 0.5 below goal - 100% (and above for fruits/veggies/water)
    // Red: above 100% (except fruits/veggies/water)
    if (progress < 0.5) {
      return const Color(0xFFFF6A00); // Orange for < 50%
    } else if (progress < nearGoalThreshold) {
      return const Color(0xFFFFA800); // Yellow for < near goal
    } else if (progress <= 1.0 || alwaysGreenAboveGoal) {
      return const Color(
          0xFF2CCC87); // Green for near goal to 100% (or above for special categories)
    } else {
      return const Color(0xFFFF5275); // Red for > 100% (for regular trackers)
    }
  }

  // Helper to check if a category should stay green above goal
  static bool shouldStayGreenAboveGoal(TrackerCategory category) {
    return category == TrackerCategory.fruits ||
        category == TrackerCategory.veggies ||
        category == TrackerCategory.water;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress and determine color
    final progress = tracker.progress;
    final progressColor = getProgressColor(
      progress,
      tracker.category,
      goalValue: tracker.goalValue,
    );
    final iconPath = getTrackerIconAsset(tracker.category);
    final isSvg = iconPath.endsWith('.svg');

    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(1.0, 1.3);

    // Calculate responsive card height based on text scaling
    final baseHeight = 68.0;
    final cardHeight = baseHeight * clampedScale;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        height: cardHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            // Main content row
            Row(
              children: [
                // Left - Progress circle with icon
                SizedBox(
                  width: 68,
                  height: cardHeight - 16, // Account for padding
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background for icon - light circle
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade100,
                        ),
                      ),

                      // Progress indicator - full circle
                      CustomPaint(
                        size: const Size(62, 62),
                        painter: ProgressCirclePainter(
                          progress: progress,
                          progressColor: progressColor,
                          backgroundColor: Colors.grey.shade200,
                          category: tracker.category,
                        ),
                      ),

                      // Icon in the center
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: isSvg
                            ? SvgPicture.asset(
                                iconPath,
                              )
                            : Image.asset(
                                iconPath,
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Right - Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tracker.name,
                          style: TextStyle(
                            fontSize: 14 * clampedScale,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tracker.formattedProgress,
                          style: TextStyle(
                            fontSize: 12 * clampedScale,
                            fontWeight: FontWeight.bold,
                            color: progressColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Info icon positioned in top-right
            Positioned(
              top: 4,
              right: 4,
              child: _buildInfoIcon(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInfoAndMaybeAdvanceTour(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => TrackerServingInfoModal(
        category: tracker.category,
        dietType: tracker.dietType,
      ),
    );

    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    // Only complete if we're on the trackerInfo step
    if (tourProvider.isOnStep(TourStep.trackerInfo) &&
        tourProvider.isTourActive) {
      tourProvider.completeCurrentStep();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        try {
          // Dismiss any active showcase first
          ShowcaseView.get().dismiss();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            final tp = Provider.of<ForcedTourProvider>(context, listen: false);
            // Double-check we're on the dailyTips step
            if (tp.isOnStep(TourStep.dailyTips)) {
              ShowcaseView.get().startShowCase([TourKeys.dailyTipsKey]);
            }
          });
        } catch (e) {
          debugPrint('🎯 TrackerCard: Error triggering dailyTips showcase: $e');
        }
      });
    }
  }

  Widget _buildInfoIcon(BuildContext context) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(1.0, 1.3);
    final iconSize = (14 * clampedScale).clamp(14.0, 18.0);

    final iconButton = GestureDetector(
      onTap: () => _openInfoAndMaybeAdvanceTour(context),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          Icons.info_outline,
          color: AppColors.textTertiary,
          size: iconSize,
        ),
      ),
    );

    if (infoShowcaseKey == null) {
      return iconButton;
    }

    return Showcase(
      key: infoShowcaseKey!,
      title: 'Serving Size Info',
      description: 'Tap to see what counts as 1 serving for ${tracker.name}.',
      tooltipPosition: TooltipPosition.top,
      targetShapeBorder: const CircleBorder(),
      tooltipBackgroundColor: Colors.white,
      textColor: Colors.black,
      overlayColor: Colors.black54,
      overlayOpacity: 0.8,
      disposeOnTap: true,
      onTargetClick: () => _openInfoAndMaybeAdvanceTour(context),
      onToolTipClick: () => _openInfoAndMaybeAdvanceTour(context),
      child: iconButton,
    );
  }
}

// Custom painter for full circle progress indicator
class ProgressCirclePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final TrackerCategory? category;

  ProgressCirclePainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    this.category,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Start at the top (270 degrees in radians) and go clockwise
    const startAngle = -math.pi / 2; // -90 degrees in radians
    const fullCircle = 2 * math.pi; // 360 degrees in radians

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 3, backgroundPaint);

    // Check if this category should stay green above goal
    final stayGreenAboveGoal =
        category != null && TrackerCard.shouldStayGreenAboveGoal(category!);

    // Progress arc - if progress > 1.0, show full circle in appropriate color
    if (progress > 1.0) {
      // Full circle - green for fruits/veggies/water, red for others
      final overColor = stayGreenAboveGoal
          ? const Color(0xFF2CCC87) // Green for fruits/veggies/water
          : const Color(0xFFFF5275); // Red for other trackers
      final overPaint = Paint()
        ..color = overColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle,
        fullCircle,
        false,
        overPaint,
      );
    } else {
      // Normal progress arc
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      final sweepAngle = fullCircle * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(ProgressCirclePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.category != category;
  }
}
