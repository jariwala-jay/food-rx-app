import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/signup_provider.dart';
import 'diet_plans/dash_diet_intro.dart';
import 'diet_plans/dash_diet_plan.dart';
import 'diet_plans/my_plate_intro.dart';
import 'diet_plans/my_plate_plan.dart';
import '../../utils/typography.dart';

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
  bool _showDetailedPlan = false;

  bool _hasHypertension(List<String> conditions) {
    return conditions.contains('Hypertension');
  }

  bool _hasLowerBloodPressureGoal(List<String> goals) {
    return goals.contains('Lower blood pressure');
  }

  void _showPlan() {
    setState(() {
      _showDetailedPlan = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final signupData = context.read<SignupProvider>().data;
    final bool isDashDiet = _hasHypertension(signupData.medicalConditions) ||
        _hasLowerBloodPressureGoal(signupData.healthGoals);

    if (!_showDetailedPlan) {
      return isDashDiet
          ? DashDietIntro(onNext: _showPlan)
          : MyPlateIntro(onNext: _showPlan);
    } else {
      return isDashDiet
          ? DashDietPlan(onFinish: widget.onFinish)
          : MyPlatePlan(onFinish: widget.onFinish);
    }
  }

  Widget _buildNutritionItem({
    required Color color,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bg_16_m),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bg_14_r
                      .copyWith(color: const Color(0xFF90909A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
