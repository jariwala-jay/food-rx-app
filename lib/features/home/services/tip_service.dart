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

  /// Persists engagement for [userId] only (server merges; does not trust full maps).
  Future<void> updateTip(Tip tip, String userId) async {
    final last = tip.getLastShownForUser(userId);
    final count = tip.getViewCountForUser(userId);
    final body = <String, dynamic>{
      if (last != null) 'lastShownAt': last.toIso8601String(),
      'viewCount': count,
    };
    await ApiClient.patch(
      '/tips/${Uri.encodeComponent(tip.id)}',
      body: body,
      requireAuth: true,
    );
  }
}
