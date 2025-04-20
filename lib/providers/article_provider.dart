import 'package:flutter/foundation.dart';
import '../models/article.dart';
import '../models/category.dart' as app_category;
import '../services/article_service.dart';
import '../providers/auth_provider.dart';

class ArticleProvider with ChangeNotifier {
  final ArticleService _articleService;
  final AuthProvider _authProvider;

  List<Article> _articles = [];
  List<app_category.Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedCategory;
  bool _showBookmarksOnly = false;

  ArticleProvider(this._articleService, this._authProvider);

  List<Article> get articles => _articles;
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get showBookmarksOnly => _showBookmarksOnly;

  Future<void> loadArticles() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = _authProvider.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        return;
      }

      _categories = await _articleService.getCategories();

      _articles = await _articleService.getArticles(
        category: _showBookmarksOnly ? null : _selectedCategory,
        userId: user.id,
        bookmarksOnly: _showBookmarksOnly,
      );

      _error = null;
    } catch (e) {
      _error = 'Failed to load articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _showBookmarksOnly = false;
    loadArticles();
  }

  void showBookmarks() {
    _showBookmarksOnly = true;
    _selectedCategory = null;
    loadArticles();
  }

  void clearCategory() {
    _selectedCategory = null;
    _showBookmarksOnly = false;
    loadArticles();
  }

  Future<void> toggleBookmark(Article article) async {
    try {
      final user = _authProvider.currentUser;
      if (user == null) return;

      final success =
          await _articleService.toggleBookmark(article.title, user.id!);
      if (success) {
        // Update the local state instead of reloading all articles
        final index = _articles.indexWhere((a) => a.title == article.title);
        if (index != -1) {
          _articles[index] = Article(
            title: article.title,
            category: article.category,
            imageUrl: article.imageUrl,
            isBookmarked: !article.isBookmarked,
            content: article.content,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      _error = 'Failed to toggle bookmark: $e';
      notifyListeners();
    }
  }

  Future<List<Article>> getArticles({String? category}) async {
    try {
      final user = _authProvider.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        return [];
      }

      return await _articleService.getArticles(
        category: category,
        userId: user.id,
      );
    } catch (e) {
      _error = 'Failed to load articles: $e';
      return [];
    }
  }
}
