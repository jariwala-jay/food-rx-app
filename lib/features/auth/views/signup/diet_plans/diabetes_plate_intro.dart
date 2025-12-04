import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

class DiabetesPlateIntro extends StatelessWidget {
  final VoidCallback onNext;

  const DiabetesPlateIntro({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    "Your Personalized Plan",
                    style: AppTypography.bg_24_b,
                  ),
                ),
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    "ADA Diabetes Plate",
                    style: AppTypography.bg_24_b,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Based on the information you provided in your health profile, the American Diabetes Association Diabetes Plate is best suited to meet your diet-related health goals. The Diabetes Plate will help guide you in controlling your portion sizes and in choosing foods that have less impact on your blood sugar levels; thus, making diabetes management easier.",
                  style: AppTypography.bg_14_r
                      .copyWith(color: const Color(0xFF90909A)),
                  textAlign: TextAlign.justify,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Image.asset(
                    'assets/images/diabetes_plate.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              onPressed: onNext,
              child: Builder(
                builder: (context) {
                  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                  final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                  return Text(
                    "Learn More",
                    style: AppTypography.bg_16_sb.copyWith(
                      color: Colors.white,
                      fontSize: 16 * clampedScale,
                    ),
                    textAlign: TextAlign.center,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
