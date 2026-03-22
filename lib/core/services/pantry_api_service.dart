import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/services/api_client.dart';

/// Pantry operations via backend API (replaces MongoDBService for pantry).
class PantryApiService {
  Future<List<PantryItem>> getPantryItems(String userId,
      {bool isPantryItem = true}) async {
    final list = await ApiClient.get(
      '/pantry/items',
      queryParameters: {'isPantryItem': isPantryItem.toString()},
    );
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => PantryItem.fromMap(json))
        .toList();
  }

  Future<String> addPantryItem(String userId, Map<String, dynamic> itemData) async {
    final res = await ApiClient.post('/pantry/items', body: itemData)
        as Map<String, dynamic>?;
    final id = res?['id'] as String?;
    if (id == null) throw Exception('API did not return item id');
    return id;
  }

  Future<void> updatePantryItem(String itemId, Map<String, dynamic> updates) async {
    await ApiClient.patch('/pantry/items/$itemId', body: updates);
  }

  Future<void> deletePantryItem(String itemId) async {
    await ApiClient.delete('/pantry/items/$itemId');
  }

  Future<List<Map<String, dynamic>>> getExpiringItems(String userId,
      {int daysThreshold = 7}) async {
    final list = await ApiClient.get(
      '/pantry/expiring',
      queryParameters: {'daysThreshold': daysThreshold.toString()},
    );
    if (list is! List) return [];
    return list.whereType<Map<String, dynamic>>().toList();
  }
}
