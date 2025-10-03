import 'nutrition_content_loader.dart';

/// Centralized service for managing diet constraints based on the diet assignment matrix
class DietConstraintsService {
  NutritionContent? _content;

  DietConstraintsService();

  /// Get nutrition content, loading it if necessary
  Future<NutritionContent> get content async {
    if (_content == null) {
      _content = await NutritionContentLoader.load();
    }
    return _content!;
  }

  /// Set nutrition content (for testing)
  void setContentForTesting(NutritionContent? content) {
    _content = content;
  }

  /// Get constraints for a specific diet rule
  Future<Map<String, dynamic>> getConstraintsForRule(
      Map<String, dynamic> rule) async {
    final constraints = <String, dynamic>{};

    // Sodium constraints
    final sodiumCap = rule['sodium_mg_max'];
    if (sodiumCap is int) {
      constraints['maxSodiumPerDay'] = sodiumCap;
      constraints['maxSodiumPerServing'] = _calculatePerServingLimit(sodiumCap);
    }

    // Glycemic index constraints
    final glycemicIndexMax = rule['glycemic_index_max'];
    if (glycemicIndexMax is int) {
      constraints['maxGlycemicIndex'] = glycemicIndexMax;
    }

    // Diet-specific constraints
    final diet = rule['diet'] as String;
    if (diet == 'DASH') {
      constraints.addAll(_getDashConstraints());
    } else if (diet == 'MyPlate') {
      constraints.addAll(_getMyPlateConstraints());
    }

    return constraints;
  }

  /// Get constraints for Spoonacular API parameters
  Future<Map<String, String>> getSpoonacularConstraints(
      Map<String, dynamic> rule) async {
    final constraints = await getConstraintsForRule(rule);
    final params = <String, String>{};

    // Convert constraints to Spoonacular API parameters
    if (constraints.containsKey('maxSodiumPerServing')) {
      params['maxSodium'] = constraints['maxSodiumPerServing'].toString();
    }

    if (constraints.containsKey('maxGlycemicIndex')) {
      // Note: Spoonacular doesn't directly support glycemic index filtering
      // This would need to be handled in post-processing
      params['veryHealthy'] = 'true'; // Use as proxy for better nutrition
    }

    // Add diet-specific Spoonacular parameters
    final diet = rule['diet'] as String;
    if (diet == 'DASH') {
      params['veryHealthy'] = 'true';
    } else if (diet == 'MyPlate') {
      params['veryHealthy'] = 'true';
    }

    return params;
  }

  /// Calculate per-serving sodium limit from daily limit
  int _calculatePerServingLimit(int dailyLimit) {
    // Assume 3 meals per day, with some buffer for snacks
    return (dailyLimit / 3).round();
  }

  /// Get DASH-specific constraints
  Map<String, dynamic> _getDashConstraints() {
    return {
      'veryHealthy': true,
      'lowFat': true,
    };
  }

  /// Get MyPlate-specific constraints
  Map<String, dynamic> _getMyPlateConstraints() {
    return {
      'veryHealthy': true,
    };
  }

  /// Validate recipe against constraints
  Future<bool> validateRecipe(Map<String, dynamic> recipeNutrition,
      Map<String, dynamic> constraints) async {
    // Sodium validation
    if (constraints.containsKey('maxSodiumPerServing')) {
      final sodium = _getNutrientAmount(recipeNutrition, 'Sodium');
      if (sodium > constraints['maxSodiumPerServing']) {
        return false;
      }
    }

    // Glycemic index validation (if available in nutrition data)
    if (constraints.containsKey('maxGlycemicIndex')) {
      final glycemicIndex =
          _getNutrientAmount(recipeNutrition, 'Glycemic Index');
      if (glycemicIndex > 0 &&
          glycemicIndex > constraints['maxGlycemicIndex']) {
        return false;
      }
    }

    // Saturated fat validation
    if (constraints.containsKey('maxSaturatedFatPerServing')) {
      final saturatedFat = _getNutrientAmount(recipeNutrition, 'Saturated Fat');
      if (saturatedFat > constraints['maxSaturatedFatPerServing']) {
        return false;
      }
    }

    // Sugar validation
    if (constraints.containsKey('maxSugarPerServing')) {
      final sugar = _getNutrientAmount(recipeNutrition, 'Sugar');
      if (sugar > constraints['maxSugarPerServing']) {
        return false;
      }
    }

    // Calories validation
    if (constraints.containsKey('maxCaloriesPerServing')) {
      final calories = _getNutrientAmount(recipeNutrition, 'Calories');
      if (calories > constraints['maxCaloriesPerServing']) {
        return false;
      }
    }

    // Fiber validation (only if fiber data is available)
    if (constraints.containsKey('minFiberPerServing')) {
      final fiber = _getNutrientAmount(recipeNutrition, 'Fiber');
      if (fiber > 0 && fiber < constraints['minFiberPerServing']) {
        return false;
      }
    }

    // Potassium validation (only if potassium data is available)
    if (constraints.containsKey('minPotassiumPerServing')) {
      final potassium = _getNutrientAmount(recipeNutrition, 'Potassium');
      if (potassium > 0 && potassium < constraints['minPotassiumPerServing']) {
        return false;
      }
    }

    return true;
  }

  /// Extract nutrient amount from nutrition data
  double _getNutrientAmount(
      Map<String, dynamic> nutrition, String nutrientName) {
    if (nutrition['nutrients'] == null) return 0.0;

    final nutrients = nutrition['nutrients'] as List;
    for (final nutrient in nutrients) {
      if (nutrient['name'] == nutrientName) {
        return (nutrient['amount'] as num).toDouble();
      }
    }
    return 0.0;
  }
}
