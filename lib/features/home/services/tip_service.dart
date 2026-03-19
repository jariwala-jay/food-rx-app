import 'package:flutter_app/features/home/models/tip.dart';
import 'package:flutter_app/core/services/api_client.dart';

class TipService {
  Future<List<Tip>> getTipsByCategory(String category) async {
    try {
      final list = await ApiClient.get(
        '/tips',
        queryParameters: {'category': category},
        requireAuth: false,
      );
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((doc) => Tip.fromJson(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get tips by category: $e');
    }
  }

  Future<List<Tip>> getAllTips() async {
    try {
      final list = await ApiClient.get('/tips', requireAuth: false);
      if (list is! List) return [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((doc) => Tip.fromJson(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to get all tips: $e');
    }
  }

  Future<void> updateTip(Tip tip) async {
    throw UnimplementedError('Update tip via API not implemented');
  }
}
