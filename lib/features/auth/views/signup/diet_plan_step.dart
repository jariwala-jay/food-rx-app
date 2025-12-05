import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/providers/signup_provider.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'diet_plans/dash_diet_intro.dart';
import 'diet_plans/dash_diet_plan.dart';
import 'diet_plans/my_plate_intro.dart';
import 'diet_plans/my_plate_plan.dart';
import 'diet_plans/diabetes_plate_intro.dart';
import 'diet_plans/diabetes_plate_plan.dart';

class DietPlanStep extends StatefulWidget {
  final VoidCallback onFinish;

  const DietPlanStep({
    Key? key,
    required this.onFinish,
  }) : super(key: key);

  @override
  State<DietPlanStep> createState() => _DietPlanStepState();
}

class _DietPlanStepState extends State<DietPlanStep> {
  int _currentStep = 0; // 0: intro, 1: details

  @override
  Widget build(BuildContext context) {
    final signupData = context.read<SignupProvider>().data;
    final myPlanType = signupData.myPlanType;

    // Step 1: Show plan details
    if (_currentStep == 1 && myPlanType != null) {
      if (myPlanType == 'DiabetesPlate') {
        return DiabetesPlatePlan(onFinish: widget.onFinish);
      } else if (myPlanType == 'DASH') {
        return DashDietPlan(onFinish: widget.onFinish);
      } else {
        return MyPlatePlan(onFinish: widget.onFinish);
      }
    }

    // Step 0: Show intro page
    if (myPlanType != null) {
      if (myPlanType == 'DiabetesPlate') {
        return DiabetesPlateIntro(
            onNext: () => setState(() => _currentStep = 1));
      } else if (myPlanType == 'DASH') {
        return DashDietIntro(onNext: () => setState(() => _currentStep = 1));
      } else {
        return MyPlateIntro(onNext: () => setState(() => _currentStep = 1));
      }
    }

    // Fallback if personalization data is not available
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xFF666666),
              ),
              const SizedBox(height: 16),
              Text(
                'Meal Plan Not Available',
                style: AppTypography.bg_24_sb.copyWith(
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unable to generate your personalized Meal plan. Please try again.',
                style: AppTypography.bg_16_r.copyWith(
                  color: const Color(0xFF666666),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Continue Anyway',
                  style: AppTypography.bg_16_sb.copyWith(
                    color: Colors.white,
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
