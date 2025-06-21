class Nutrition {
  final List<Nutrient> nutrients;
  final List<IngredientNutrition> ingredients;

  Nutrition({required this.nutrients, required this.ingredients});

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      nutrients: (json['nutrients'] as List<dynamic>?)
              ?.map((e) => Nutrient.fromJson(e))
              .toList() ??
          [],
      ingredients: (json['ingredients'] as List<dynamic>?)
              ?.map((e) => IngredientNutrition.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nutrients': nutrients.map((e) => e.toJson()).toList(),
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
    };
  }
}

class Nutrient {
  final String name;
  final double amount;
  final String unit;

  Nutrient({required this.name, required this.amount, required this.unit});

  factory Nutrient.fromJson(Map<String, dynamic> json) {
    return Nutrient(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
    };
  }
}

class IngredientNutrition {
  final String name;
  final double amount;
  final String unit;
  final List<Nutrient> nutrients;

  IngredientNutrition({
    required this.name,
    required this.amount,
    required this.unit,
    required this.nutrients,
  });

  factory IngredientNutrition.fromJson(Map<String, dynamic> json) {
    return IngredientNutrition(
      name: json['name'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      nutrients: (json['nutrients'] as List<dynamic>?)
              ?.map((e) => Nutrient.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      'nutrients': nutrients.map((e) => e.toJson()).toList(),
    };
  }
}
