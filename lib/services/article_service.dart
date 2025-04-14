import '../models/article.dart';
import '../models/category.dart';
import 'mongodb_service.dart';

class ArticleService {
  final MongoDBService _mongoDBService;

  ArticleService(this._mongoDBService);

  Future<List<Article>> getArticles({
    List<String>? medicalConditions,
    List<String>? healthGoals,
    String? category,
    String? userId,
  }) async {
    try {
      final query = <String, dynamic>{};

      if (medicalConditions != null && medicalConditions.isNotEmpty) {
        // Convert conditions to lowercase for case-insensitive matching
        final lowerConditions =
            medicalConditions.map((c) => c.toLowerCase()).toList();
        print('Searching for conditions: $lowerConditions');

        // Get all articles first to debug the tags
        final allArticles =
            await _mongoDBService.educationalContentCollection.find().toList();
        print('All articles and their tags:');
        for (var article in allArticles) {
          print('${article['title']}: ${article['medicalConditionTags']}');
        }

        // Try to find articles with matching tags
        query['medicalConditionTags'] = {'\$in': lowerConditions};
      }

      if (category != null && category != 'All') {
        query['category'] = category;
      }

      print('Final query: $query');

      // If no articles found with the query, return all articles
      var articles = await _mongoDBService.educationalContentCollection
          .find(query)
          .toList();

      if (articles.isEmpty &&
          (medicalConditions?.isNotEmpty == true || category != null)) {
        print('No articles found with filters, showing all articles');
        articles =
            await _mongoDBService.educationalContentCollection.find().toList();
      }

      print('Found ${articles.length} articles');

      // Get user's bookmarked articles
      final bookmarkedArticles = userId != null
          ? await _mongoDBService.educationalContentCollection
              .find({'bookmarkedBy': userId}).toList()
          : [];

      final bookmarkedTitles =
          bookmarkedArticles.map((doc) => doc['title'] as String).toSet();

      return articles
          .map((doc) => Article(
                title: doc['title'],
                category: doc['category'],
                imageUrl: doc['imageUrl'],
                isBookmarked: bookmarkedTitles.contains(doc['title']),
              ))
          .toList();
    } catch (e) {
      print('Error fetching articles: $e');
      // On error, try to return all articles
      try {
        final allArticles =
            await _mongoDBService.educationalContentCollection.find().toList();
        return allArticles
            .map((doc) => Article(
                  title: doc['title'],
                  category: doc['category'],
                  imageUrl: doc['imageUrl'],
                  isBookmarked: false,
                ))
            .toList();
      } catch (e) {
        print('Error fetching all articles: $e');
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
      print('Error fetching categories: $e');
      return [];
    }
  }

  Future<bool> toggleBookmark(String articleTitle, String userId) async {
    try {
      final article = await _mongoDBService.educationalContentCollection
          .findOne({'title': articleTitle});

      if (article == null) return false;

      final isBookmarked = article['bookmarkedBy']?.contains(userId) ?? false;

      if (isBookmarked) {
        // Remove bookmark
        await _mongoDBService.educationalContentCollection.updateOne(
          {'title': articleTitle},
          {
            '\$pull': {'bookmarkedBy': userId}
          },
        );
      } else {
        // Add bookmark
        await _mongoDBService.educationalContentCollection.updateOne(
          {'title': articleTitle},
          {
            '\$addToSet': {'bookmarkedBy': userId}
          },
        );
      }

      return true;
    } catch (e) {
      print('Error toggling bookmark: $e');
      return false;
    }
  }
}
