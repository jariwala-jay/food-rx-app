import 'package:flutter/material.dart';
import '../../../utils/typography.dart';

class DashDietIntro extends StatelessWidget {
  final VoidCallback onNext;

  const DashDietIntro({
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
                "Based on your health goals and dietary needs, the Dash Diet is a great fit for you! It helps balance essential nutrients while keeping you energized.",
                style: AppTypography.bg_14_r
                    .copyWith(color: const Color(0xFF90909A)),
              ),
              const SizedBox(height: 32),
              Center(
                child: Image.asset(
                  'assets/images/dash_diet.jpg',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "This diet ensures you get the flexible and balanced eating plan that helps create a heart-healthy eating style for life",
                style: AppTypography.bg_14_r
                    .copyWith(color: const Color(0xFF90909A)),
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
