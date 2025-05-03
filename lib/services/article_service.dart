import '../models/article.dart';
import '../models/category.dart';
import 'mongodb_service.dart';
import 'package:mongo_dart/mongo_dart.dart';

class ArticleService {
  final MongoDBService _mongoDBService;

  ArticleService(this._mongoDBService);

  Future<List<Article>> getArticles({
    List<String>? medicalConditions,
    List<String>? healthGoals,
    String? category,
    String? userId,
    bool bookmarksOnly = false,
    String? search,
  }) async {
    try {
      final query = <String, dynamic>{};

      if (category != null && category != 'All' && !bookmarksOnly) {
        query['category'] = category;
      }

      // If bookmarksOnly is true, only fetch bookmarked articles
      if (bookmarksOnly && userId != null) {
        query['bookmarkedBy'] = ObjectId.fromHexString(userId);
      }

      // Get all articles matching the category
      var articles = await _mongoDBService.educationalContentCollection
          .find(query)
          .toList();

      if (articles.isEmpty && category != null) {
        articles =
            await _mongoDBService.educationalContentCollection.find().toList();
      }

      // Get user's bookmarked articles
      final bookmarkedArticles = userId != null
          ? await _mongoDBService.getBookmarkedArticles(userId)
          : [];

      final bookmarkedIds =
          bookmarkedArticles.map((doc) => doc['_id'].toString()).toSet();

      return articles
          .map((doc) => Article(
                id: (doc['_id'] is ObjectId)
                    ? (doc['_id'] as ObjectId).toHexString()
                    : doc['_id'].toString(),
                title: doc['title'],
                category: doc['category'],
                imageUrl: doc['imageUrl'],
                isBookmarked: bookmarkedIds.contains(doc['_id'].toString()),
                content: doc['content'],
              ))
          .toList();
    } catch (e) {
      // On error, try to return all articles
      try {
        final allArticles =
            await _mongoDBService.educationalContentCollection.find().toList();
        return allArticles
            .map((doc) => Article(
                  id: doc['_id'].toString(),
                  title: doc['title'],
                  category: doc['category'],
                  imageUrl: doc['imageUrl'],
                  isBookmarked: false,
                  content: doc['content'],
                ))
            .toList();
      } catch (e) {
        return [];
      }
    }
  }

  Future<List<Category>> getCategories() async {
    try {
      // Get all articles first
      final articles =
          await _mongoDBService.educationalContentCollection.find().toList();

      // Extract unique categories
      final categories = articles
          .map((doc) => doc['category'] as String)
          .toSet()
          .toList()
        ..sort();

      return categories
          .map((category) => Category(
                name: category,
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> updateArticleBookmark(String articleId, bool isBookmarked,
      {String? userId}) async {
    try {
      if (userId == null) {
        return;
      }

      // Update bookmark in MongoDB
      await _mongoDBService.updateArticleBookmark(
        articleId,
        isBookmarked,
        userId,
      );
    } catch (e) {
      throw Exception('Failed to update bookmark: $e');
    }
  }
}
