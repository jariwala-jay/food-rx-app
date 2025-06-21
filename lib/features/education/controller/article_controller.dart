import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class ArticleController extends ChangeNotifier {
  final ArticleRepository _articleRepository;
  final AuthController _authProvider;

  ArticleController(this._articleRepository, this._authProvider);

  // State
  List<Article> _articles = [];
  List<Article> _recommendedArticles = [];
  List<Article> _searchSuggestions = [];
  List<Category> _categories = [];
  List<Article> _bookmarkedArticles = [];
  Category? _selectedCategory;
  bool _isLoading = false;
  String? _error;
  bool _bookmarksOnly = false;
  String _searchQuery = '';

  // Getters
  List<Article> get articles => _articles;
  List<Article> get recommendedArticles => _recommendedArticles;
  List<Article> get searchSuggestions => _searchSuggestions;
  List<Category> get categories => _categories;
  List<Article> get bookmarkedArticles => _bookmarkedArticles;
  Category? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get bookmarksOnly => _bookmarksOnly;
  String? get _userId => _authProvider.currentUser?.id;

  Future<void> initialize() async {
    await loadCategories();
    await loadArticles();
    if (_userId != null) {
      await loadBookmarkedArticles();
      await loadRecommendedArticles();
    }
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      final fetchedCategories = await _articleRepository.getCategories();
      _categories = fetchedCategories;
    } catch (e) {
      _error = 'Failed to load categories: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadArticles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _articles = await _articleRepository.getArticles(
        category: _selectedCategory?.name,
        userId: _userId,
        bookmarksOnly: _bookmarksOnly,
        searchQuery: _searchQuery,
      );
    } catch (e) {
      _error = 'Failed to load articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRecommendedArticles() async {
    if (_userId == null) return;
    final user = _authProvider.currentUser;
    if (user == null ||
        user.medicalConditions == null ||
        user.medicalConditions!.isEmpty) {
      _recommendedArticles = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final allArticles = await _articleRepository.getArticles();
      _recommendedArticles = allArticles
          .where(
              (article) => user.medicalConditions!.contains(article.category))
          .toList();
    } catch (e) {
      _error = 'Failed to load recommended articles: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadBookmarkedArticles() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _bookmarkedArticles = await _articleRepository.getArticles(
        userId: _userId,
        bookmarksOnly: true,
      );
    } catch (e) {
      _error = 'Failed to load bookmarks: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    _bookmarksOnly = false;
    _searchQuery = '';
    loadArticles();
  }

  void selectCategory(Category category) {
    if (_selectedCategory == category && !_bookmarksOnly) return;
    _searchQuery = '';
    _selectedCategory = category;
    _bookmarksOnly = false;
    loadArticles();
  }

  void selectAll() {
    if (_selectedCategory == null && !_bookmarksOnly) return;
    _searchQuery = '';
    _selectedCategory = null;
    _bookmarksOnly = false;
    loadArticles();
  }

  void selectBookmarks() {
    if (_bookmarksOnly) return;
    _searchQuery = '';
    _bookmarksOnly = true;
    _selectedCategory = null;
    loadArticles();
  }

  Future<void> toggleBookmark(String articleId) async {
    if (_userId == null) {
      _error = 'You must be logged in to bookmark articles.';
      notifyListeners();
      return;
    }

    Article? articleToUpdate;
    try {
      articleToUpdate = _articles.firstWhere((a) => a.id == articleId);
    } catch (e) {
      // Also check bookmarks
      try {
        articleToUpdate =
            _bookmarkedArticles.firstWhere((a) => a.id == articleId);
      } catch (e) {
        _error = 'Article not found.';
        notifyListeners();
        return;
      }
    }

    final newBookmarkStatus = !articleToUpdate.isBookmarked;
    final originalStatus = articleToUpdate.isBookmarked;

    // Optimistic UI update
    _updateArticleInLists(articleId, newBookmarkStatus);

    try {
      await _articleRepository.updateArticleBookmark(
          articleId, newBookmarkStatus,
          userId: _userId!);
      // If successful, we might want to refresh the bookmark list if we are on it
      if (_bookmarksOnly) {
        await loadBookmarkedArticles();
      }
    } catch (e) {
      _error = 'Failed to update bookmark: $e';
      // Revert on failure
      _updateArticleInLists(articleId, originalStatus);
    }
    notifyListeners();
  }

  void _updateArticleInLists(String articleId, bool isBookmarked) {
    final articleIndex = _articles.indexWhere((a) => a.id == articleId);
    if (articleIndex != -1) {
      _articles[articleIndex] =
          _articles[articleIndex].copyWith(isBookmarked: isBookmarked);
    }

    if (isBookmarked) {
      if (!_bookmarkedArticles.any((a) => a.id == articleId) &&
          articleIndex != -1) {
        _bookmarkedArticles
            .add(_articles[articleIndex].copyWith(isBookmarked: true));
      }
    } else {
      _bookmarkedArticles.removeWhere((a) => a.id == articleId);
    }
    notifyListeners();
  }

  Future<void> searchArticles(String query) async {
    if (query.isEmpty) {
      _searchSuggestions = [];
      notifyListeners();
      return;
    }
    _searchSuggestions =
        await _articleRepository.getArticles(searchQuery: query);
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchSuggestions = [];
    notifyListeners();
  }
}
