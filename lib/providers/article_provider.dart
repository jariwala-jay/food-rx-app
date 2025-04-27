import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/category.dart' as app_category;
import '../services/article_service.dart';
import '../providers/auth_provider.dart';

class ArticleProvider extends ChangeNotifier {
  final ArticleService _articleService;
  final Map<String, List<Article>> _categoryArticles = {};
  final Map<String, List<Article>> _cachedArticles = {};
  List<Article> _articles = [];
  List<app_category.Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;
  bool _showBookmarksOnly = false;

  // Reference to AuthProvider
  AuthProvider? _authProvider;

  ArticleProvider(this._articleService);

  // Method to set the auth provider reference
  void setAuthProvider(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  List<Article> get articles => _articles;
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get showBookmarksOnly => _showBookmarksOnly;
  Set<String> get availableCategoryNames => _categoryArticles.keys.toSet();

  Future<List<Article>> getArticles({String? category}) async {
    try {
      final userId = _authProvider?.currentUser?.id;

      // Check if we have cached articles for this category
      if (_cachedArticles.containsKey(category)) {
        return _cachedArticles[category]!;
      }

      final List<Article> articles =
          await _articleService.getArticles(category: category, userId: userId);

      // Cache the articles
      if (category != null) {
        _cachedArticles[category] = articles;
        _categoryArticles[category] = articles;
      }

      return articles;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<void> loadArticles() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load categories first if they're not already loaded
      if (_categories.isEmpty) {
        _categories = await _articleService.getCategories();
      }

      final userId = _authProvider?.currentUser?.id;

      List<Article> articles;
      if (_showBookmarksOnly) {
        articles = await _articleService.getArticles(
          bookmarksOnly: true,
          userId: userId,
        );
      } else if (_selectedCategory != null) {
        articles = await getArticles(category: _selectedCategory);
      } else {
        articles = await getArticles();
      }

      _articles = articles;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _showBookmarksOnly = false;
    loadArticles();
  }

  void clearCategory() {
    _selectedCategory = null;
    _showBookmarksOnly = false;
    loadArticles();
  }

  void showBookmarks() {
    _showBookmarksOnly = true;
    _selectedCategory = null;
    loadArticles();
  }

  Future<void> toggleBookmark(Article article) async {
    try {
      final userId = _authProvider?.currentUser?.id;

      // Create a new article instance with updated bookmark status
      final updatedArticle =
          article.copyWith(isBookmarked: !article.isBookmarked);

      // Update the article in all cached lists first
      _updateArticleInCache(updatedArticle);
      notifyListeners();

      try {
        // Persist the change to the backend
        await _articleService.updateArticleBookmark(
            updatedArticle.id, updatedArticle.isBookmarked,
            userId: userId);

        // If we're in bookmarks view, we need to update the list
        if (_showBookmarksOnly) {
          if (!updatedArticle.isBookmarked) {
            // Remove from list if unbookmarked
            _articles.removeWhere((a) => a.id == updatedArticle.id);
          } else {
            // Add to list if bookmarked
            _articles.add(updatedArticle);
          }
          notifyListeners();
        }
      } catch (e) {
        // Revert the change if the API call fails
        final revertedArticle =
            article.copyWith(isBookmarked: article.isBookmarked);
        _updateArticleInCache(revertedArticle);
        notifyListeners();
      }
    } catch (e) {
      throw Exception(e);
    }
  }

  void _updateArticleInCache(Article updatedArticle) {
    // Update in main articles list
    final mainIndex = _articles.indexWhere((a) => a.id == updatedArticle.id);
    if (mainIndex != -1) {
      _articles[mainIndex] = updatedArticle;
    }

    // Update in category cache
    for (var category in _categoryArticles.keys) {
      final categoryList = _categoryArticles[category]!;
      final index = categoryList.indexWhere((a) => a.id == updatedArticle.id);
      if (index != -1) {
        categoryList[index] = updatedArticle;
      }
    }

    // Update in general cache
    for (var category in _cachedArticles.keys) {
      final cachedList = _cachedArticles[category]!;
      final index = cachedList.indexWhere((a) => a.id == updatedArticle.id);
      if (index != -1) {
        cachedList[index] = updatedArticle;
      }
    }
  }

  void clearCache() {
    _cachedArticles.clear();
    _categoryArticles.clear();
  }

  Article getArticleById(String id) {
    // First check in the main articles list
    final article = _articles.firstWhere(
      (article) => article.id == id,
      orElse: () => throw Exception('Article not found with ID: $id'),
    );
    return article;
  }
}
