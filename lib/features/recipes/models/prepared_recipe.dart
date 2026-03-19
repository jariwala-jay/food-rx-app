import 'package:flutter_app/features/recipes/models/recipe.dart';

/// A prepared recipe (leftover) from "I Cooked This" with remaining servings.
class PreparedRecipe {
  final String id;
  final int recipeId;
  final Recipe recipe;
  final double remainingServings;
  final double totalServings;
  final double consumedServings;

  const PreparedRecipe({
    required this.id,
    required this.recipeId,
    required this.recipe,
    required this.remainingServings,
    this.totalServings = 0,
    this.consumedServings = 0,
  });

  factory PreparedRecipe.fromJson(Map<String, dynamic> json) {
    final recipeJson = json['recipe'];
    final recipe = recipeJson is Map<String, dynamic>
        ? Recipe.fromJson(recipeJson)
        : Recipe.fromJson({});

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is double) return v;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    return PreparedRecipe(
      id: json['id']?.toString() ?? '',
      recipeId: (json['recipeId'] is int)
          ? json['recipeId'] as int
          : int.tryParse(json['recipeId']?.toString() ?? '0') ?? 0,
      recipe: recipe,
      remainingServings: toDouble(json['remainingServings']),
      totalServings: toDouble(json['totalServings']),
      consumedServings: toDouble(json['consumedServings']),
    );
  }
}
