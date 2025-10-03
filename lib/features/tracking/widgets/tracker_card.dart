import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../models/tracker_goal.dart';
import 'tracker_serving_info_modal.dart';
import 'package:flutter_app/core/utils/app_colors.dart';

class TrackerCard extends StatelessWidget {
  final TrackerGoal tracker;
  final VoidCallback? onTap;

  const TrackerCard({
    Key? key,
    required this.tracker,
    this.onTap,
  }) : super(key: key);

  // Get progress color based on percentage
  static Color getProgressColor(double progress, TrackerCategory category) {
    // Reverse logic for 'limit' trackers like sodium and sweets
    if (category == TrackerCategory.sodium ||
        category == TrackerCategory.sweets) {
      if (progress < 0.75) {
        return const Color(0xFF2CCC87); // Green for < 75%
      } else if (progress < 1.0) {
        return const Color(0xFFFFA800); // Yellow for < 100%
      } else {
        return const Color(0xFFFF5275); // Red for >= 100%
      }
    }

    // Normal logic for 'goal' trackers
    if (progress < 0.5) {
      return const Color(0xFFFF5275); // Accent/Red for < 50%
    } else if (progress < 0.75) {
      return const Color(0xFFFFA800); // Accent/Yellow for < 75%
    } else {
      return const Color(0xFF2CCC87); // Accent/Green for >= 75%
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate progress and determine color
    final progress = tracker.progress;
    final progressColor = getProgressColor(progress, tracker.category);
    final iconPath = getTrackerIconAsset(tracker.category);
    final isSvg = iconPath.endsWith('.svg');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 152,
        height: 68,
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
                  height: 68,
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
                      Text(
                        tracker.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5F5F5F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tracker.formattedProgress,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
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
              child: GestureDetector(
                onTap: () => _showInfoModal(context),
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
                  child: const Icon(
                    Icons.info_outline,
                    color: AppColors.textLight,
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TrackerServingInfoModal(
        category: tracker.category,
        dietType: tracker.dietType,
      ),
    );
  }
}

// Custom painter for full circle progress indicator
class ProgressCirclePainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;

  ProgressCirclePainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
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

    // Progress arc - if progress > 1.0, draw full circle in green then overflow in red
    if (progress > 1.0) {
      // First draw complete circle in green
      final completePaint = Paint()
        ..color = const Color(0xFF2CCC87) // Green for completed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle,
        fullCircle,
        false,
        completePaint,
      );

      // Then draw overflow in red
      final overflowAngle = fullCircle * (progress - 1.0).clamp(0.0, 1.0);
      final overflowPaint = Paint()
        ..color = const Color(0xFFFF5275) // Red for overflow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 3),
        startAngle,
        overflowAngle,
        false,
        overflowPaint,
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
        oldDelegate.backgroundColor != backgroundColor;
  }
}
