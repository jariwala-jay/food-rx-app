import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class NutritionContent {
  final Map<String, dynamic> dashCalorieMap;
  final List<dynamic> dashServings;
  final List<dynamic> myplateTargets;

  NutritionContent(this.dashCalorieMap, this.dashServings, this.myplateTargets);
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
      return NutritionContent(dashCal, dashSrv, mpl);
    } catch (e) {
      throw Exception('Failed to load nutrition content: $e');
    }
  }
}
