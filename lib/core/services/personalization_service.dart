import 'nutrition_content_loader.dart';

class PersonalizationResult {
  final String dietType; // 'DASH' | 'MyPlate'
  final String myPlanType; // 'DASH' | 'MyPlate' | 'DiabetesPlate'
  final bool showGlycemicIndex; // true if diabetes detected
  final int targetCalories; // tier kcal
  final Map<String, dynamic> selectedDietPlan; // servings/targets
  final Map<String, dynamic> diagnostics; // bmr, pal, tdee, maintenance, rules

  PersonalizationResult(this.dietType, this.myPlanType, this.showGlycemicIndex,
      this.targetCalories, this.selectedDietPlan, this.diagnostics);
}

class PersonalizationService {
  final NutritionContent content;

  PersonalizationService(this.content);

  // Configurable default floors/caps
  static const int kDefaultSodiumDASH = 2300;
  static const int kDefaultSodiumMyPlate = 2300;
  static const int kHypertensionSodiumCap = 1500; // safeguard

  /// Matches a diet rule based on medical conditions and health goals
  Map<String, dynamic> _matchDietRule(List rules,
      {required String dm, required String ht, required String ow}) {
    int score(Map r) {
      int s = 0;
      s += (r['diabetes_prediabetes'] == 'ANY' ||
              r['diabetes_prediabetes'] == dm)
          ? (r['diabetes_prediabetes'] == 'ANY' ? 1 : 2)
          : -99;
      s += (r['hypertension'] == 'ANY' || r['hypertension'] == ht)
          ? (r['hypertension'] == 'ANY' ? 1 : 2)
          : -99;
      s += (r['overweight_obese'] == 'ANY' || r['overweight_obese'] == ow)
          ? (r['overweight_obese'] == 'ANY' ? 1 : 2)
          : -99;
      return s;
    }

    final sorted = List<Map<String, dynamic>>.from(rules)
      ..sort((a, b) => score(b).compareTo(score(a)));
    return sorted.first;
  }

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

    // Determine medical condition flags
    final dm =
        medicalConditions.any((m) => m.toLowerCase().contains('diabetes'))
            ? 'YES'
            : 'NO';
    final ht =
        medicalConditions.any((m) => m.toLowerCase().contains('hypertension'))
            ? 'YES'
            : 'NO';
    final ow = medicalConditions.any((m) =>
            m.toLowerCase().contains('obesity') ||
            m.toLowerCase().contains('overweight'))
        ? 'YES'
        : 'NO';

    // Match diet rule using matrix
    final rule =
        _matchDietRule(content.dietAssignmentRules, dm: dm, ht: ht, ow: ow);
    final chosenDiet = (rule['diet'] as String).trim();

    // Determine myPlanType and showGlycemicIndex
    final myPlanType = _determineMyPlanType(chosenDiet, dm);
    final showGlycemicIndex = rule.containsKey('glycemic_index_max');

    // Sodium cap logic with hypertension safeguard
    int sodiumCapFromRule() {
      final cap = rule['sodium_mg_max'];
      if (cap is int) return cap;
      if (cap is num) return cap.toInt();
      // fallback defaults by framework; with HTN safeguard
      if (ht == 'YES') return kHypertensionSodiumCap;
      return chosenDiet == 'DASH' ? kDefaultSodiumDASH : kDefaultSodiumMyPlate;
    }

    if (chosenDiet == 'DASH') {
      final maintenance = _dashMaintenanceKcal(age, sex, activityLevel);
      final wantingWL = ow == 'YES' ||
          healthGoals.any((g) => g.toLowerCase().contains('weight'));
      final kcal = wantingWL ? _dashStepDown(maintenance, sex) : maintenance;
      final tier = _nearestDashTier(kcal);
      final plan = _dashPlanFor(tier);

      // Apply sodium cap from rule/safeguard
      plan['sodium_mg_per_day_max'] = sodiumCapFromRule();

      final diagnostics = {
        'maintenance': maintenance,
        'tier': tier,
        'diet_rule': rule
      };
      return PersonalizationResult(
          'DASH', myPlanType, showGlycemicIndex, tier, plan, diagnostics);
    } else {
      final bmr = _msjBmr(sex, age, heightCm, weightKg);
      final pal = _pal(activityLevel);
      final tdee = bmr * pal;
      final wantingWL = ow == 'YES' ||
          healthGoals.any((g) => g.toLowerCase().contains('weight'));
      final floor = sex.toLowerCase() == 'male' ? 1500 : 1200;
      final target =
          wantingWL ? (tdee - 500).clamp(floor, 10000).toDouble() : tdee;
      final tier = _nearestMyPlateTier(target);
      final plan = _myPlatePlanFor(tier);

      // Apply sodium cap from rule/safeguard (MyPlate)
      plan['sodium_mg_per_day_max'] = sodiumCapFromRule();

      final diagnostics = {
        'bmr': bmr,
        'pal': pal,
        'tdee': tdee,
        'tier': tier,
        'diet_rule': rule
      };
      return PersonalizationResult(
          'MyPlate', myPlanType, showGlycemicIndex, tier, plan, diagnostics);
    }
  }

  // Determine myPlanType based on diet and diabetes status
  String _determineMyPlanType(String dietType, String diabetesStatus) {
    if (diabetesStatus == 'YES') {
      return 'DiabetesPlate'; // Educational content for diabetes
    }
    return dietType; // Otherwise same as diet (DASH or MyPlate)
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

  int _dashStepDown(int maintenance, String sex) {
    final tiers = [1200, 1400, 1600, 1800, 2000, 2600, 3100];
    final floor = sex.toLowerCase() == 'male' ? 1500 : 1200;
    // Find the next lower tier that's >= floor
    for (int i = tiers.length - 1; i >= 0; i--) {
      if (tiers[i] < maintenance && tiers[i] >= floor) {
        return tiers[i];
      }
    }
    return floor; // fallback to minimum floor
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
