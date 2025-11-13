import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

class MyPlateIntro extends StatelessWidget {
  final VoidCallback onNext;

  const MyPlateIntro({
    Key? key,
    required this.onNext,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
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
                "Based on your health goals and dietary needs, the MyPlate Diet is a great fit for you! It helps balance essential nutrients while keeping you energized.",
                style: AppTypography.bg_14_r
                    .copyWith(color: const Color(0xFF90909A)),
              ),
              const SizedBox(height: 32),
              Center(
                child: Image.asset(
                  'assets/images/myplate_diet.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "This diet ensures you get the right mix of proteins, carbs, and healthy fats to support your lifestyle",
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
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
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
                    child: Text(
                      "See My Personalized Plan",
                      style:
                          AppTypography.bg_16_sb.copyWith(color: Colors.white),
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
