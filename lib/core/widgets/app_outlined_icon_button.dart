import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

/// Full width outlined button with icon and text label.
class AppOutlinedIconButton extends StatelessWidget {
  const AppOutlinedIconButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.foregroundColor = const Color(0xFFFF6A00),
    this.borderColor = const Color(0xFFFF6A00),
    this.labelStyle = AppTypography.bg_16_sb,
    this.largeTextLayoutThreshold = 1.1,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color borderColor;
  final TextStyle labelStyle;
  final double largeTextLayoutThreshold;

  bool _usesStackedLayout(BuildContext context) {
    return MediaQuery.textScaleFactorOf(context) > largeTextLayoutThreshold;
  }

  @override
  Widget build(BuildContext context) {
    final stacked = _usesStackedLayout(context);
    final textStyle = labelStyle.copyWith(color: foregroundColor);

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: stacked ? 14 : 12,
          ),
          minimumSize: const Size(double.infinity, 48),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: foregroundColor),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: textStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: foregroundColor),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: textStyle,
                      textAlign: TextAlign.center,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
