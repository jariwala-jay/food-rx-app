import 'package:mongo_dart/mongo_dart.dart';
import '../models/tip.dart';
import 'mongodb_service.dart';

class TipService {
  final MongoDBService _mongoDBService;
  final String _collectionName = 'tips';

  TipService(this._mongoDBService);

  Future<List<Tip>> getTipsByCategory(String category) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.db.collection(_collectionName);
      final cursor = await collection.find(where.eq('category', category));
      final tips = await cursor.toList();
      return tips.map((doc) => Tip.fromJson(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get tips by category: $e');
    }
  }

  Future<List<Tip>> getAllTips() async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.db.collection(_collectionName);
      final cursor = await collection.find();
      final tips = await cursor.toList();
      return tips.map((doc) => Tip.fromJson(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get all tips: $e');
    }
  }

  Future<void> updateTip(Tip tip) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.db.collection(_collectionName);
      await collection.update(
        where.eq('id', tip.id),
        tip.toJson(),
      );
    } catch (e) {
      throw Exception('Failed to update tip: $e');
    }
  }
}
