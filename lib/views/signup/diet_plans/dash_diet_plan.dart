import 'package:flutter/material.dart';
import '../../../utils/typography.dart';
import '../../../views/pages/main_screen.dart';

class DashDietPlan extends StatelessWidget {
  final VoidCallback onFinish;

  const DashDietPlan({
    Key? key,
    required this.onFinish,
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
                "Your Dash Diet Plan",
                style: AppTypography.bg_24_b,
              ),
              const SizedBox(height: 8),
              Text(
                "Let's make every meal count for your health!",
                style: AppTypography.bg_14_r
                    .copyWith(color: const Color(0xFF90909A)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/images/dash_diet_details.jpg',
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
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
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const MainScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(
                      "Let's get Started!",
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
