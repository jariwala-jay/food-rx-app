import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import '../models/tracker_goal.dart';
import 'tracker_card.dart'; // Import for the getProgressColor function

class TrackerEditDialog extends StatefulWidget {
  final TrackerGoal tracker;
  final Function(double) onUpdate;

  const TrackerEditDialog({
    Key? key,
    required this.tracker,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<TrackerEditDialog> createState() => _TrackerEditDialogState();
}

class _TrackerEditDialogState extends State<TrackerEditDialog> {
  late TextEditingController _valueController;
  late double _currentValue;
  bool _isUpdating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.tracker.currentValue;
    _valueController = TextEditingController(
      text: _currentValue.toString(),
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  void _incrementValue() {
    setState(() {
      _currentValue += 0.5;
      _valueController.text = _currentValue.toString();
    });
  }

  void _decrementValue() {
    if (_currentValue > 0) {
      setState(() {
        _currentValue = (_currentValue - 0.5).clamp(0, double.infinity);
        _valueController.text = _currentValue.toString();
      });
    }
  }

  Future<void> _handleUpdate() async {
    if (_isUpdating) return;

    setState(() {
      _isUpdating = true;
      _error = null;
    });

    try {
      await widget.onUpdate(_currentValue);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentValue / widget.tracker.goalValue;
    final progressColor =
        TrackerCard.getProgressColor(progress, widget.tracker.category);
    final iconPath = getTrackerIconAsset(widget.tracker.category);
    final isSvg = iconPath.endsWith('.svg');
    final progressPercent = (progress * 100).toStringAsFixed(0);
    final isOverAchieved = progress > 1.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Update ${widget.tracker.name}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            // Progress display with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSvg)
                  SvgPicture.asset(
                    iconPath,
                    width: 48,
                    height: 48,
                  )
                else
                  Image.asset(
                    iconPath,
                    width: 48,
                    height: 48,
                  ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$progressPercent%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_currentValue of ${widget.tracker.goalValue} ${widget.tracker.unitString}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (isOverAchieved)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5275).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "OVER",
                              style: TextStyle(
                                color: Color(0xFFFF5275),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    onPressed: _isUpdating ? null : _decrementValue,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _valueController,
                      enabled: !_isUpdating,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: progressColor, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*$')),
                      ],
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          setState(() {
                            _currentValue = double.parse(value);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    onPressed: _isUpdating ? null : _incrementValue,
                    color: Colors.green.shade400,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isUpdating ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isUpdating ? null : _handleUpdate,
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for progress circle
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
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius - 5, backgroundPaint);

    // Progress arc - if progress > 1.0, draw full circle in green then overflow in red
    if (progress > 1.0) {
      // First draw complete circle in green
      final completePaint = Paint()
        ..color = const Color(0xFF2CCC87) // Green for completed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        startAngle,
        fullCircle,
        false,
        completePaint,
      );

      // Then draw overflow in red (starts again from top)
      final overflowAngle = fullCircle * (progress - 1.0).clamp(0.0, 1.0);
      final overflowPaint = Paint()
        ..color = const Color(0xFFFF5275) // Red for overflow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
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
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;

      final sweepAngle = fullCircle * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
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
