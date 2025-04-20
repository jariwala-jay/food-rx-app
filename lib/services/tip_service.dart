import 'package:mongo_dart/mongo_dart.dart';
import '../models/tip.dart';

class TipService {
  final Db _db;
  final String _collectionName = 'tips';

  TipService(this._db);

  Future<List<Tip>> getTipsByCategory(String category) async {
    try {
      final collection = _db.collection(_collectionName);
      final cursor = await collection.find(where.eq('category', category));
      final tips = await cursor.toList();
      return tips.map((doc) => Tip.fromJson(doc)).toList();
    } catch (e) {
      print('Error fetching tips: $e');
      return [];
    }
  }

  Future<List<Tip>> getAllTips() async {
    try {
      final collection = _db.collection(_collectionName);
      final cursor = await collection.find();
      final tips = await cursor.toList();
      return tips.map((doc) => Tip.fromJson(doc)).toList();
    } catch (e) {
      print('Error fetching all tips: $e');
      return [];
    }
  }

  Future<void> updateTip(Tip tip) async {
    try {
      final collection = _db.collection(_collectionName);
      await collection.update(
        where.eq('id', tip.id),
        tip.toJson(),
      );
    } catch (e) {
      print('Error updating tip: $e');
    }
  }
}
