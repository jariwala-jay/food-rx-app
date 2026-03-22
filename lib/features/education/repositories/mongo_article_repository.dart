import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';
import 'package:mongo_dart/mongo_dart.dart';

class MongoArticleRepository implements ArticleRepository {
  final MongoDBService _mongoDBService;
  final String _collectionName = 'educational_content';
  final String _bookmarksCollectionName = 'user_bookmarks';

  MongoArticleRepository(this._mongoDBService);

  static bool _isConnectionError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('state.closed') ||
        s.contains('wrong state') ||
        s.contains('connection closed') ||
        s.contains('reset by peer') ||
        s.contains('mongodb connection failed');
  }

  @override
  Future<List<Article>> getArticles({
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? searchQuery,
  }) async {
    try {
      return await _getArticlesImpl(
        category: category,
        userId: userId,
        bookmarksOnly: bookmarksOnly,
        searchQuery: searchQuery,
      );
    } catch (e) {
      if (_isConnectionError(e)) {
        await _mongoDBService.ensureConnection();
        return await _getArticlesImpl(
          category: category,
          userId: userId,
          bookmarksOnly: bookmarksOnly,
          searchQuery: searchQuery,
        );
      }
      rethrow;
    }
  }

  Future<List<Article>> _getArticlesImpl({
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
    try {
      await _mongoDBService.ensureConnection();
      final collection =
          _mongoDBService.db.collection(_bookmarksCollectionName);
      final bookmarks = await collection
          .find(where.eq('userId', ObjectIdHelper.parseObjectId(userId)))
          .toList();
      return bookmarks.map((doc) => doc['articleId'] as ObjectId).toList();
    } catch (e) {
      if (_isConnectionError(e)) {
        await _mongoDBService.ensureConnection();
        final collection =
            _mongoDBService.db.collection(_bookmarksCollectionName);
        final bookmarks = await collection
            .find(where.eq('userId', ObjectIdHelper.parseObjectId(userId)))
            .toList();
        return bookmarks.map((doc) => doc['articleId'] as ObjectId).toList();
      }
      rethrow;
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    try {
      return await _getCategoriesImpl();
    } catch (e) {
      if (_isConnectionError(e)) {
        try {
          await _mongoDBService.ensureConnection();
          return await _getCategoriesImpl();
        } catch (_) {
          return [];
        }
      }
      return [];
    }
  }

  Future<List<Category>> _getCategoriesImpl() async {
    await _mongoDBService.ensureConnection();
    final categoriesData = await _mongoDBService.educationalContentCollection
        .distinct('category');

    final categories = (categoriesData['values'] as List)
        .map((categoryName) => Category(name: categoryName as String))
        .toList();

    categories.sort((a, b) => a.name.compareTo(b.name));
    return categories;
  }

  @override
  Future<void> updateArticleBookmark(String articleId, bool isBookmarked,
      {required String userId}) async {
    try {
      await _updateArticleBookmarkImpl(
          articleId, isBookmarked, userId: userId);
    } catch (e) {
      if (_isConnectionError(e)) {
        await _mongoDBService.ensureConnection();
        await _updateArticleBookmarkImpl(
            articleId, isBookmarked, userId: userId);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _updateArticleBookmarkImpl(String articleId, bool isBookmarked,
      {required String userId}) async {
    await _mongoDBService.ensureConnection();
    final collection =
        _mongoDBService.db.collection(_bookmarksCollectionName);
    if (isBookmarked) {
      await collection.insertOne({
        'userId': ObjectIdHelper.parseObjectId(userId),
        'articleId': ObjectIdHelper.parseObjectId(articleId),
        'savedAt': DateTime.now(),
      });
    } else {
      await collection.deleteOne({
        'userId': ObjectIdHelper.parseObjectId(userId),
        'articleId': ObjectIdHelper.parseObjectId(articleId),
      });
    }
  }
}
