import 'package:flutter_app/features/tracking/domain/dash_diet_plan.dart';
import 'package:flutter_app/features/tracking/domain/diet_plan.dart';
import 'package:flutter_app/features/tracking/domain/my_plate_diet_plan.dart';

class DietPlanService {
  final Map<DietPlanType, DietPlan> _plans = {
    DietPlanType.dash: DashDietPlan(),
    DietPlanType.myPlate: MyPlateDietPlan(),
  };

  DietPlan getDietPlan(String dietType) {
    if (dietType.toLowerCase() == 'dash') {
      return _plans[DietPlanType.dash]!;
    }
    // Default to MyPlate for any other value
    return _plans[DietPlanType.myPlate]!;
  }
}
