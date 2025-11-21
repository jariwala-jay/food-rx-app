import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ModalActionButton extends StatelessWidget {
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final bool shouldClose;
  final bool enabled;

  const ModalActionButton({
    Key? key,
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.shouldClose = true,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
    
    // Calculate responsive height based on text scaling
    final baseHeight = 115.0;
    final cardHeight = baseHeight * clampedScale.clamp(1.0, 1.1);
    
    return SizedBox(
      width: 150,
      child: GestureDetector(
        onTap: !enabled
            ? null
            : () {
                if (shouldClose) Navigator.of(context).pop();
                onTap();
              },
        child: Container(
          height: cardHeight,
          padding: EdgeInsets.symmetric(
            vertical: 20 * clampedScale.clamp(1.0, 1.1),
          ),
          decoration: BoxDecoration(
            color: enabled ? const Color(0xFFF7F7F8) : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 45,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0x19FF6A00)
                      : const Color(0x11000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: iconAsset.endsWith('.svg')
                    ? SvgPicture.asset(
                        iconAsset,
                        width: 27,
                        height: 27,
                        fit: BoxFit.contain,
                        colorFilter: enabled
                            ? null
                            : const ColorFilter.mode(
                                Color(0xFFBDBDBD), BlendMode.srcIn),
                      )
                    : const Icon(Icons.circle, color: Color(0xFFFF6A00)),
              ),
              SizedBox(height: 8 * clampedScale),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: enabled
                        ? const Color(0xFF2C2C2C)
                        : const Color(0xFFBDBDBD),
                    fontSize: 12 * clampedScale,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Bricolage Grotesque',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
