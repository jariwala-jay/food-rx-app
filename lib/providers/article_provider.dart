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

  ArticleProvider(this._articleService, this._authProvider);

  List<Article> get articles => _articles;
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;

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
        medicalConditions: user.medicalConditions,
        healthGoals: user.healthGoals ?? [],
        category: _selectedCategory,
        userId: user.id,
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
    loadArticles();
  }

  void clearCategory() {
    _selectedCategory = null;
    loadArticles();
  }

  Future<void> toggleBookmark(Article article) async {
    try {
      final user = _authProvider.currentUser;
      if (user == null) return;

      final success =
          await _articleService.toggleBookmark(article.title, user.id!);
      if (success) {
        await loadArticles(); // Reload articles to update bookmark status
      }
    } catch (e) {
      _error = 'Failed to toggle bookmark: $e';
      notifyListeners();
    }
  }
}
