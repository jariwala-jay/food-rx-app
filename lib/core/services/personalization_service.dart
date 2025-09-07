import 'dart:math';
import 'nutrition_content_loader.dart';

class PersonalizationResult {
  final String dietType; // 'DASH' | 'MyPlate'
  final int targetCalories; // tier kcal
  final Map<String, dynamic> selectedDietPlan; // servings/targets
  final Map<String, dynamic> diagnostics; // bmr, pal, tdee, maintenance, rules

  PersonalizationResult(this.dietType, this.targetCalories,
      this.selectedDietPlan, this.diagnostics);
}

class PersonalizationService {
  final NutritionContent content;

  PersonalizationService(this.content);

  PersonalizationResult personalize({
    required DateTime dob,
    required String sex, // 'male' | 'female'
    required double heightFeet,
    required double heightInches,
    required double weightLb,
    required String
        activityLevel, // 'sedentary'|'light'|'moderate'|'very active'
    required List<String> medicalConditions,
    required List<String> healthGoals,
  }) {
    final age = DateTime.now().difference(dob).inDays ~/ 365;
    final heightCm = (heightFeet * 12 + heightInches) * 2.54;
    final weightKg = weightLb / 2.205;

    final isDash = medicalConditions
            .map((s) => s.toLowerCase())
            .contains('hypertension') ||
        healthGoals
            .map((s) => s.toLowerCase())
            .contains('lower blood pressure');

    if (isDash) {
      final maintenance = _dashMaintenanceKcal(age, sex, activityLevel);
      final wl =
          medicalConditions.any((m) => m.toLowerCase().contains('obesity')) ||
              healthGoals.map((s) => s.toLowerCase()).contains('weight loss');
      final kcal = wl ? _dashStepDown(maintenance) : maintenance;
      final tier = _nearestDashTier(kcal);
      final plan = _dashPlanFor(tier);
      return PersonalizationResult('DASH', tier, plan, {
        'maintenance': maintenance,
        'tier': tier,
        'mode': wl ? 'step-down' : 'maintain'
      });
    } else {
      final bmr = _msjBmr(sex, age, heightCm, weightKg);
      final pal = _pal(activityLevel);
      final tdee = bmr * pal;
      final wl =
          medicalConditions.any((m) => m.toLowerCase().contains('obesity')) ||
              healthGoals.map((s) => s.toLowerCase()).contains('weight loss');
      final target = wl
          ? max(tdee - 500, sex.toLowerCase() == 'male' ? 1500 : 1200)
          : tdee;
      final tier = _nearestMyPlateTier(target);
      final plan = _myPlatePlanFor(tier);
      return PersonalizationResult('MyPlate', tier, plan, {
        'bmr': bmr,
        'pal': pal,
        'tdee': tdee,
        'tier': tier,
        'mode': wl ? '-500' : 'maintain'
      });
    }
  }

  // ---- helpers (DASH) ----
  int _dashMaintenanceKcal(int age, String sex, String activity) {
    final data = content.dashCalorieMap['data'];
    final sexKey = sex.toLowerCase() == 'male' ? 'men' : 'women';
    final ageGroup = _getAgeGroup(age);
    final activityKey = _mapActivityLevel(activity);

    final ageData = data[sexKey][ageGroup];
    if (ageData is Map) {
      return ageData[activityKey] ?? ageData.values.first;
    }
    return ageData ?? 2000; // fallback
  }

  String _getAgeGroup(int age) {
    if (age >= 19 && age <= 30) return '19-30';
    if (age >= 31 && age <= 50) return '31-50';
    return '51+';
  }

  String _mapActivityLevel(String activity) {
    switch (activity.toLowerCase()) {
      case 'light':
        return 'moderate';
      case 'moderate':
        return 'moderate';
      case 'very active':
        return 'active';
      default:
        return 'sedentary';
    }
  }

  int _dashStepDown(int maintenance) {
    final tiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];
    // Find the next lower tier that's >= 1200 (minimum floor)
    for (int i = tiers.length - 1; i >= 0; i--) {
      if (tiers[i] < maintenance && tiers[i] >= 1200) {
        return tiers[i];
      }
    }
    return 1200; // fallback to minimum
  }

  int _nearestDashTier(num kcal) {
    final tiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];
    return tiers
        .reduce((a, b) => ((kcal - a).abs() <= (kcal - b).abs() ? a : b));
  }

  Map<String, dynamic> _dashPlanFor(int tier) {
    // Find the plan for the specific tier
    for (var plan in content.dashServings) {
      if (plan['kcal'] == tier) {
        return Map<String, dynamic>.from(plan);
      }
    }
    return {}; // fallback
  }

  // ---- helpers (MyPlate) ----
  double _msjBmr(String sex, int age, double cm, double kg) =>
      sex.toLowerCase() == 'male'
          ? (10 * kg + 6.25 * cm - 5 * age + 5)
          : (10 * kg + 6.25 * cm - 5 * age - 161);

  double _pal(String a) {
    switch (a.toLowerCase()) {
      case 'light':
        return 1.375;
      case 'moderate':
        return 1.55;
      case 'very active':
        return 1.725;
      default:
        return 1.2;
    }
  }

  int _nearestMyPlateTier(num kcal) {
    final tiers = [1600, 1800, 2000, 2200, 2400, 2600, 2800, 3000, 3200];
    return tiers
        .reduce((a, b) => ((kcal - a).abs() <= (kcal - b).abs() ? a : b));
  }

  Map<String, dynamic> _myPlatePlanFor(int tier) {
    // Find the plan for the specific tier
    for (var plan in content.myplateTargets) {
      if (plan['kcal'] == tier) {
        return Map<String, dynamic>.from(plan);
      }
    }
    return {}; // fallback
  }
}
