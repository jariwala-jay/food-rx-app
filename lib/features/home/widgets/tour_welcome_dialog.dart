import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

class TourWelcomeDialog extends StatelessWidget {
  const TourWelcomeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Clamp text scale factor to prevent excessive scaling
    final textScaleFactor =
        MediaQuery.textScaleFactorOf(context).clamp(0.8, 1.2);
    final screenHeight = MediaQuery.of(context).size.height;
    final maxDialogHeight = screenHeight * 0.75; // Max 75% of screen height

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fixed header: Logo and title
              SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/icons/myfoodrx_logo.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 24 * textScaleFactor),
              // Title
              Text(
                'Welcome to MyFoodRx!',
                style: TextStyle(
                  fontSize: 24 * textScaleFactor,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 16 * textScaleFactor),

              // Scrollable middle section: Description
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    'We\'re excited to have you! Let\'s take you through a tour of the app to help you get familiar with all its features.',
                    style: AppTypography.bg_16_r.copyWith(
                      color: const Color(0xFF666666),
                      fontSize: 16 * textScaleFactor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: 24 * textScaleFactor),

              // Fixed footer: Button (always visible)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6A00),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: 16 * textScaleFactor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Start Tour',
                    style: TextStyle(
                      fontSize: 16 * textScaleFactor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
