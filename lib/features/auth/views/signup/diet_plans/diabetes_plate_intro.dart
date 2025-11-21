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
                const Text(
                  "Great! We've Got Your Info!",
                  style: AppTypography.bg_24_b,
                ),
                const SizedBox(height: 8),
                Text(
                  "Based on your health profile, the Diabetes Plate is perfect for managing blood sugar levels. It focuses on portion control and choosing the right foods to help you maintain stable glucose levels.",
                  style: AppTypography.bg_14_r
                      .copyWith(color: const Color(0xFF90909A)),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Diabetes Plate visual representation
                        Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFFFF6B35), width: 3),
                          ),
                          child: Stack(
                            children: [
                              // Non-starchy vegetables (half plate)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: 100,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF4CAF50),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(100),
                                      topRight: Radius.circular(100),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Non-starchy\nVegetables\n(50%)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Protein (quarter plate)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                width: 100,
                                height: 100,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2196F3),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(100),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Lean\nProtein\n(25%)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Carbohydrates (quarter plate)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                width: 100,
                                height: 100,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFF9800),
                                    borderRadius: BorderRadius.only(
                                      bottomRight: Radius.circular(100),
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      'Carbohydrates\n(25%)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Diabetes Plate Method',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  "This method helps you control portion sizes and choose foods that have less impact on your blood sugar levels, making diabetes management easier.",
                  style: AppTypography.bg_14_r
                      .copyWith(color: const Color(0xFF90909A)),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEFE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFF6A00).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_outline,
                        color: Color(0xFFFF6A00),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "We'll walk you through this plan in detail with a video tutorial once you're set up!",
                          style: AppTypography.bg_14_r.copyWith(
                            color: const Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    ],
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
                    "See My Personalized Diet Plan",
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
