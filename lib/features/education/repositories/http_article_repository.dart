import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';

class HttpArticleRepository implements ArticleRepository {
  @override
  Future<List<Article>> getArticles({
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? searchQuery,
  }) async {
    final query = <String, String>{};
    if (category != null) query['category'] = category;
    if (userId != null) query['userId'] = userId;
    if (bookmarksOnly) query['bookmarksOnly'] = 'true';
    if (searchQuery != null && searchQuery.isNotEmpty) query['searchQuery'] = searchQuery;

    final list = await ApiClient.get('/education/articles', queryParameters: query);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => Article.fromJson(json))
        .toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    final list = await ApiClient.get('/education/categories', requireAuth: false);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map((json) => Category(name: json['name'] as String? ?? ''))
        .toList();
  }

  @override
  Future<void> updateArticleBookmark(String articleId, bool isBookmarked,
      {required String userId}) async {
    await ApiClient.put(
      '/education/articles/$articleId/bookmark',
      body: {'isBookmarked': isBookmarked},
    );
  }
}
