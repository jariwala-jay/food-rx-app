import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';

class DiabetesPlatePlan extends StatelessWidget {
  final VoidCallback onFinish;

  const DiabetesPlatePlan({
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
                "Your Diabetes Plate Plan",
                style: AppTypography.bg_24_b,
              ),
              const SizedBox(height: 8),
              Text(
                "Let's make every meal count for your diabetes management!",
                style: AppTypography.bg_14_r
                    .copyWith(color: const Color(0xFF90909A)),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Key principles card
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
                          border: Border.all(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B35)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.bloodtype,
                                        color: Color(0xFFFF6B35),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        "Key Principles",
                                        style: TextStyle(
                                          fontSize: 18 * clampedScale,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF333333),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "• Fill half your plate with non-starchy vegetables\n• Fill one quarter with lean protein\n• Fill one quarter with carbohydrate foods\n• Include a serving of fruit or dairy\n• Drink water or zero-calorie beverages",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF666666),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Blood sugar management card
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                                return Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4CAF50)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.trending_down,
                                        color: Color(0xFF4CAF50),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        "Blood Sugar Management",
                                        style: TextStyle(
                                          fontSize: 18 * clampedScale,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF333333),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "• Choose foods with lower glycemic index\n• Eat regular meals and snacks\n• Monitor portion sizes carefully\n• Include fiber-rich foods\n• Limit added sugars and refined carbs",
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF666666),
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
                    onPressed: onFinish,
                    child: Builder(
                      builder: (context) {
                        final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                        final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                        return Text(
                          "Let's get Started!",
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
            ],
          ),
        ),
      ),
    );
  }
}
