import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/pantry/models/pantry_item.dart';
import 'package:flutter_app/features/pantry/repositories/pantry_repository.dart';
import 'package:mongo_dart/mongo_dart.dart';

const String spoonacularImageBaseUrl =
    'https://img.spoonacular.com/ingredients_100x100/';

class MongoPantryRepository implements PantryRepository {
  final MongoDBService _mongoDBService;
  final String _collectionName = 'pantry_items';

  MongoPantryRepository(this._mongoDBService);

  @override
  Future<List<PantryItem>> getPantryItems(String userId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    final itemsJson =
        await collection.find(where.eq('userId', userId)).toList();
    return itemsJson.map((json) {
      final item = PantryItem.fromJson(json);
      return item.copyWith(
        imageUrl: item.imageUrl.startsWith('http')
            ? item.imageUrl
            : '$spoonacularImageBaseUrl${item.imageUrl}',
      );
    }).toList();
  }

  @override
  Future<void> addPantryItem(String userId, PantryItem item) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.insertOne(item.toJson()..['userId'] = userId);
  }

  @override
  Future<void> updatePantryItem(String userId, PantryItem item) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.updateOne(
      where.id(ObjectId.fromHexString(item.id)),
      item.toJson(),
    );
  }

  @override
  Future<void> removePantryItem(String userId, String itemId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    await collection.deleteOne(where.id(ObjectId.fromHexString(itemId)));
  }
}
