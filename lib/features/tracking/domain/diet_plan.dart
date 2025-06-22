import 'package:flutter_app/features/tracking/models/tracker_goal.dart';

enum DietPlanType { myPlate, dash }

abstract class DietPlan {
  DietPlanType get type;
  List<TrackerGoal> getGoals(String userId);
  Map<TrackerCategory, double> getServingsForIngredient({
    required String ingredientName,
    required double amount,
    required String unit,
  });
}
