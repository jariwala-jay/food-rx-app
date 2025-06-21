import 'package:flutter_app/features/pantry/models/ingredient.dart';

abstract class IngredientRepository {
  Future<List<Ingredient>> searchIngredients(
      {String? query, String? aisle, int number = 100});
  Future<List<Ingredient>> autocompleteIngredient(
      {required String query, int number = 10});
}
