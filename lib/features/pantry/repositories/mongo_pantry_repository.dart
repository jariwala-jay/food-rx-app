import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/utils/image_url_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoPantryRepository {
  final MongoDBService _mongoDBService;
  final String _collectionName = 'pantry_items';

  MongoPantryRepository(this._mongoDBService);

  Future<List<PantryItem>> getPantryItems(String userId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    final itemsJson =
        await collection.find(where.eq('userId', userId)).toList();
    return itemsJson.map((json) {
      final item = PantryItem.fromJson(json);
      return item.copyWith(
        imageUrl: ImageUrlHelper.getValidImageUrl(item.imageUrl),
      );
    }).toList();
  }

  Future<void> addPantryItem(String userId, PantryItem item) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.insertOne(item.toJson()..['userId'] = userId);
  }

  Future<void> updatePantryItem(String userId, PantryItem item) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.updateOne(
      where.id(ObjectId.fromHexString(item.id)),
      item.toJson(),
    );
  }

  Future<void> removePantryItem(String userId, String itemId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.deleteOne(where.id(ObjectId.fromHexString(itemId)));
  }
}
