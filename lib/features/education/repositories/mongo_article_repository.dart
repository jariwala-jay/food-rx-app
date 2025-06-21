import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoArticleRepository implements ArticleRepository {
  final MongoDBService _mongoDBService;
  final String _collectionName = 'educational_content';
  final String _bookmarksCollectionName = 'user_bookmarks';

  MongoArticleRepository(this._mongoDBService);

  @override
  Future<List<Article>> getArticles({
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? searchQuery,
  }) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_collectionName);
    var selector = <String, dynamic>{};

    if (bookmarksOnly) {
      if (userId == null) {
        throw Exception('User ID is required to fetch bookmarks');
      }
      final userBookmarks = await _getUserBookmarks(userId);
      selector['_id'] = {r'$in': userBookmarks};
    } else if (category != null && category != 'All') {
      selector['category'] = category;
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      selector['title'] = {
        r'$regex': searchQuery,
        r'$options': 'i',
      };
    }

    final articlesJson = await collection.find(selector).toList();
    final articles =
        articlesJson.map((json) => Article.fromJson(json)).toList();

    if (userId != null) {
      final bookmarkedBookmarkIds = await _getUserBookmarks(userId);
      final bookmarkedIds =
          bookmarkedBookmarkIds.map((id) => id.toHexString()).toSet();
      return articles.map((article) {
        return article.copyWith(
            isBookmarked: bookmarkedIds.contains(article.id));
      }).toList();
    }

    return articles;
  }

  Future<List<ObjectId>> _getUserBookmarks(String userId) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_bookmarksCollectionName);
    final bookmarks = await collection
        .find(where.eq('userId', ObjectId.fromHexString(userId)))
        .toList();
    return bookmarks.map((doc) => doc['articleId'] as ObjectId).toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    try {
      final categoriesData = await _mongoDBService.educationalContentCollection
          .distinct('category');

      final categories = (categoriesData['values'] as List)
          .map((categoryName) => Category(name: categoryName as String))
          .toList();

      categories.sort((a, b) => a.name.compareTo(b.name));
      return categories;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> updateArticleBookmark(String articleId, bool isBookmarked,
      {required String userId}) async {
    await _mongoDBService.ensureConnection();
    final collection = _mongoDBService.db.collection(_bookmarksCollectionName);
    if (isBookmarked) {
      await collection.insertOne({
        'userId': ObjectId.fromHexString(userId),
        'articleId': ObjectId.fromHexString(articleId),
        'savedAt': DateTime.now(),
      });
    } else {
      await collection.deleteOne({
        'userId': ObjectId.fromHexString(userId),
        'articleId': ObjectId.fromHexString(articleId),
      });
    }
  }
}
