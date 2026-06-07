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

  /// [TextScaler] threshold for [_buildLargeTextLayout] instead of inline layout.
  static const double largeTextLayoutThreshold = 1.1;

  const TrackerCard({
    Key? key,
    required this.tracker,
    this.onTap,
    this.infoShowcaseKey,
  }) : super(key: key);

  static bool usesLargeTextLayout(BuildContext context) {
    return MediaQuery.textScaleFactorOf(context) > largeTextLayoutThreshold;
  }

  static const double progressInlineNormalFontSize = 14;
  static const double progressFractionAccessibleMaxFontSize = 16;
  static const double progressLargeLayoutFractionBaseFontSize = 14;
  static const double progressLargeLayoutFractionMinFontSize = 11;
  static const double progressUnitFontSize = 12;

  static const double infoIconReserveWidth = 22;

  static double progressInlineFontSizeFor(BuildContext context) {
    final scale = MediaQuery.textScaleFactorOf(context);
    if (usesLargeTextLayout(context)) {
      return progressFractionAccessibleMaxFontSize * scale;
    }
    if (scale <= 1.0) {
      return progressInlineNormalFontSize;
    }
    final t =
        ((scale - 1.0) / (largeTextLayoutThreshold - 1.0)).clamp(0.0, 1.0);
    return progressInlineNormalFontSize +
        t *
            (progressFractionAccessibleMaxFontSize -
                progressInlineNormalFontSize);
  }

  static double progressFractionMaxFontSizeFor(BuildContext context) {
    if (usesLargeTextLayout(context)) {
      return progressLargeLayoutFractionBaseFontSize;
    }
    return progressInlineFontSizeFor(context);
  }

  static FontWeight progressFractionWeightFor(BuildContext context) {
    return usesLargeTextLayout(context) ? FontWeight.bold : FontWeight.w600;
  }

  /// Height used by [TrackerGrid] for grid aspect ratio.
  static double preferredHeight(BuildContext context) {
    final textScale = MediaQuery.textScaleFactorOf(context);
    if (usesLargeTextLayout(context)) {
      return 72 + (textScale - 1.0) * 20;
    }
    return 68.0 * textScale.clamp(1.0, 1.3);
  }

  static EdgeInsets cardPaddingFor(BuildContext context) {
    if (usesLargeTextLayout(context)) {
      return const EdgeInsets.fromLTRB(6, 10, 6, 2);
    }
    return const EdgeInsets.all(8);
  }

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
      return const Color(0xFFFF3B30); // Red for > 100% (for regular trackers)
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
    final progress = tracker.progress;
    final progressColor = getProgressColor(
      progress,
      tracker.category,
      goalValue: tracker.goalValue,
    );
    final iconPath = getTrackerIconAsset(tracker.category);
    final isSvg = iconPath.endsWith('.svg');
    final cardHeight = preferredHeight(context);
    final useLargeLayout = usesLargeTextLayout(context);
    final cardPadding = cardPaddingFor(context);

    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    final isTourActive = tourProvider.isTourActive;

    return GestureDetector(
      onTap: () {
        if (isTourActive) {
          return;
        }
        onTap?.call();
      },
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
        padding: cardPadding,
        child: useLargeLayout
            ? _buildLargeTextLayout(
                context,
                progress: progress,
                progressColor: progressColor,
                iconPath: iconPath,
                isSvg: isSvg,
                cardHeight: cardHeight,
                cardPadding: cardPadding,
              )
            : _buildCompactLayout(
                context,
                progress: progress,
                progressColor: progressColor,
                iconPath: iconPath,
                isSvg: isSvg,
                cardHeight: cardHeight,
                cardPadding: cardPadding,
              ),
      ),
    );
  }

  Widget _buildCompactLayout(
    BuildContext context, {
    required double progress,
    required Color progressColor,
    required String iconPath,
    required bool isSvg,
    required double cardHeight,
    required EdgeInsets cardPadding,
  }) {
    final clampedScale = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.3);
    final innerHeight = cardHeight - cardPadding.vertical;

    return Stack(
      children: [
        Row(
          children: [
            SizedBox(
              width: 68,
              height: innerHeight,
              child: _buildProgressIcon(
                progress: progress,
                progressColor: progressColor,
                iconPath: iconPath,
                isSvg: isSvg,
                diameter: 62,
                iconSize: 30,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: infoIconReserveWidth),
                    child: FittedBox(
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
                  ),
                  const SizedBox(height: 2),
                  _buildInlineProgressLine(
                    context,
                    progressColor: progressColor,
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _buildInfoIcon(context),
        ),
      ],
    );
  }

  /// Inline progress fraction; shrinks font via [TextPainter] to fit [constraints.maxWidth].
  Widget _buildInlineProgressLine(
    BuildContext context, {
    required Color progressColor,
  }) {
    final unit = tracker.unitString;
    final weight = progressFractionWeightFor(context);
    final label = unit.isEmpty
        ? tracker.formattedProgressFraction
        : '${tracker.formattedProgressFraction} $unit';

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseSize = progressInlineFontSizeFor(context);
        const minSize = 11.0;

        double fitFontSize(double size) {
          final painter = TextPainter(
            text: TextSpan(
              text: label,
              style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                color: progressColor,
                height: 1.1,
              ),
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: double.infinity);

          if (painter.width <= constraints.maxWidth) {
            return size;
          }
          // Fit against 96% of max width to absorb kerning/rounding overflow.
          final safeMaxWidth = math.max(0.0, constraints.maxWidth * 0.96);
          final scaled =
              (size * (safeMaxWidth / painter.width)).clamp(minSize, size);
          return scaled;
        }

        final fontSize = fitFontSize(baseSize);
        final textStyle = TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: progressColor,
          height: 1.1,
        );

        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
        );
      },
    );
  }

  /// Stacked text: category, then counts, then unit — aligned under the label.
  Widget _buildLargeTextLayout(
    BuildContext context, {
    required double progress,
    required Color progressColor,
    required String iconPath,
    required bool isSvg,
    required double cardHeight,
    required EdgeInsets cardPadding,
  }) {
    final unit = tracker.unitString;
    final innerHeight = cardHeight - cardPadding.vertical;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: innerHeight,
          child: Padding(
            padding: const EdgeInsets.only(right: infoIconReserveWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: innerHeight,
                  child: _buildProgressIcon(
                    progress: progress,
                    progressColor: progressColor,
                    iconPath: iconPath,
                    isSvg: isSvg,
                    diameter: 48,
                    iconSize: 24,
                  ),
                ),
                const SizedBox(width: 6),
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _buildLargeLayoutProgressFraction(
                        context,
                        progressColor: progressColor,
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: progressUnitFontSize,
                            fontWeight: FontWeight.w600,
                            color: progressColor,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: _buildInfoIcon(context),
        ),
      ],
    );
  }

  /// Large-layout progress fraction; same width-based font fitting as [_buildInlineProgressLine].
  Widget _buildLargeLayoutProgressFraction(
    BuildContext context, {
    required Color progressColor,
  }) {
    final fraction = tracker.formattedProgressFraction;
    final weight = progressFractionWeightFor(context);
    final baseSize = progressLargeLayoutFractionBaseFontSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        double fitFontSize(double size) {
          final painter = TextPainter(
            text: TextSpan(
              text: fraction,
              style: TextStyle(
                fontSize: size,
                fontWeight: weight,
                color: progressColor,
                height: 1.1,
              ),
            ),
            maxLines: 1,
            textDirection: Directionality.of(context),
          )..layout(maxWidth: double.infinity);

          if (painter.width <= constraints.maxWidth) {
            return size;
          }
          final safeMaxWidth = math.max(0.0, constraints.maxWidth * 0.94);
          return (size * (safeMaxWidth / painter.width))
              .clamp(progressLargeLayoutFractionMinFontSize, size);
        }

        final fontSize = fitFontSize(baseSize);
        return Align(
          alignment: Alignment.centerLeft,
          child: Text(
            fraction,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: progressColor,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
          ),
        );
      },
    );
  }

  Widget _buildProgressIcon({
    required double progress,
    required Color progressColor,
    required String iconPath,
    required bool isSvg,
    required double diameter,
    required double iconSize,
  }) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade100,
          ),
        ),
        CustomPaint(
          size: Size(diameter, diameter),
          painter: ProgressCirclePainter(
            progress: progress,
            progressColor: progressColor,
            backgroundColor: Colors.grey.shade200,
            category: tracker.category,
          ),
        ),
        SizedBox(
          width: iconSize,
          height: iconSize,
          child: isSvg ? SvgPicture.asset(iconPath) : Image.asset(iconPath),
        ),
      ],
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
      description: TourDescriptions.trackerInfo,
      tooltipPosition: TooltipPosition.top,
      targetShapeBorder: const CircleBorder(),
      tooltipBackgroundColor: TourTooltipStyle.tooltipBackgroundColor,
      textColor: TourTooltipStyle.textColor,
      overlayColor: TourTooltipStyle.overlayColor,
      overlayOpacity: TourTooltipStyle.overlayOpacity,
      toolTipMargin: TourTooltipStyle.toolTipMargin,
      titleTextStyle: TourTooltipStyle.titleStyle,
      descTextStyle: TourTooltipStyle.descriptionStyle,
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
          : const Color(0xFFFF3B30); // Red for other trackers
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
