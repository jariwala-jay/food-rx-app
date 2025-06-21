import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';

abstract class ArticleRepository {
  Future<List<Article>> getArticles({
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? searchQuery,
  });

  Future<List<Category>> getCategories();

  Future<void> updateArticleBookmark(String articleId, bool isBookmarked,
      {required String userId});
}
