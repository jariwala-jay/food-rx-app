import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class NutritionContent {
  final Map<String, dynamic> dashCalorieMap;
  final List<dynamic> dashServings;
  final List<dynamic> myplateTargets;
  final List<dynamic> dietAssignmentRules;

  NutritionContent(this.dashCalorieMap, this.dashServings, this.myplateTargets,
      this.dietAssignmentRules);
}

class NutritionContentLoader {
  static Future<NutritionContent> load() async {
    try {
      final dashCal = jsonDecode(await rootBundle
          .loadString('assets/nutrition/dash_calorie_map.json'));
      final dashSrv = jsonDecode(
          await rootBundle.loadString('assets/nutrition/dash_servings.json'));
      final mpl = jsonDecode(
          await rootBundle.loadString('assets/nutrition/myplate_targets.json'));
      final matrix = jsonDecode(await rootBundle
          .loadString('assets/nutrition/diet_assignment_matrix.json'));
      return NutritionContent(dashCal, dashSrv, mpl, matrix['rules'] as List);
    } catch (e) {
      throw Exception('Failed to load nutrition content: $e');
    }
  }
}
