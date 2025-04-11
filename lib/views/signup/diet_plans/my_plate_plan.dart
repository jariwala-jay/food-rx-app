import 'package:flutter/material.dart';
import '../../../utils/typography.dart';
import '../../../views/pages/main_screen.dart';

class MyPlatePlan extends StatelessWidget {
  final VoidCallback onFinish;

  const MyPlatePlan({
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
                "Your MyPlate Nutrition Plan",
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
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/myplate_veggies.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Vary your Veggies",
                                    style: AppTypography.bg_16_m,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Choose a variety of colorful fresh, frozen, and canned vegetables",
                                    style: AppTypography.bg_14_r.copyWith(
                                        color: const Color(0xFF90909A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/myplate_fruits.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Focus on whole Fruits",
                                    style: AppTypography.bg_16_m,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Focus on whole fruits that are fresh, frozen, canned, or dried",
                                    style: AppTypography.bg_14_r.copyWith(
                                        color: const Color(0xFF90909A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/myplate_grains.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Make half your grains whole",
                                    style: AppTypography.bg_16_m,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Find whole-grain foods by reading the Nutrition Facts label and ingredients list",
                                    style: AppTypography.bg_14_r.copyWith(
                                        color: const Color(0xFF90909A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/myplate_protein.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Vary your protein routine",
                                    style: AppTypography.bg_16_m,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Mix up your protein foods to include seafood, beans, peas, and lentils; unsalted nuts and seeds; soy products; eggs; and lean meats and poultry",
                                    style: AppTypography.bg_14_r.copyWith(
                                        color: const Color(0xFF90909A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Image.asset(
                              'assets/images/myplate_dairy.png',
                              width: 70,
                              height: 70,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Move to low-fat or fat-free dairy milk or yogurt",
                                    style: AppTypography.bg_16_m,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Look for ways to include dairy or fortified soy alternatives at meals and snacks throughout the day",
                                    style: AppTypography.bg_14_r.copyWith(
                                        color: const Color(0xFF90909A)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
