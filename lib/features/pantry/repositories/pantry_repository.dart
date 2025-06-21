import 'package:flutter_app/features/pantry/models/pantry_item.dart';

abstract class PantryRepository {
  Future<List<PantryItem>> getPantryItems(String userId);
  Future<void> addPantryItem(String userId, PantryItem item);
  Future<void> updatePantryItem(String userId, PantryItem item);
  Future<void> removePantryItem(String userId, String itemId);
}
