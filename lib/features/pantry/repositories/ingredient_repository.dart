import 'package:flutter_app/core/models/ingredient.dart';

abstract class IngredientRepository {
  Future<List<Ingredient>> searchIngredients(
      {String? query,
      String? aisle,
      int number = 100,
      List<String>? intolerances});
  Future<List<Ingredient>> autocompleteIngredient(
      {required String query, int number = 10});
}
