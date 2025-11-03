import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart';
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class ArticleController extends ChangeNotifier {
  final ArticleRepository _articleRepository;
  AuthController _authProvider;

  ArticleController(this._articleRepository, this._authProvider) {
    _authProvider.addListener(_onAuthChanged);
    initialize();
  }

  set authProvider(AuthController authProvider) {
    _authProvider = authProvider;
    _onAuthChanged();
  }

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

  // Cache
  final Map<String, List<Article>> _cachedArticles = {};

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

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    clearCache();
    initialize();
  }

  void clearCache() {
    _cachedArticles.clear();
    _articles = [];
    _recommendedArticles = [];
    _searchSuggestions = [];
    _categories = [];
    _bookmarkedArticles = [];
    _selectedCategory = null;
    _bookmarksOnly = false;
    _searchQuery = '';
    notifyListeners();
  }

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

    final cacheKey =
        '${_bookmarksOnly ? 'bookmarks' : _selectedCategory?.name ?? 'all'}_$_searchQuery';

    if (_cachedArticles.containsKey(cacheKey)) {
      _articles = _cachedArticles[cacheKey]!;
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final fetchedArticles = await _articleRepository.getArticles(
        category: _selectedCategory?.name,
        userId: _userId,
        bookmarksOnly: _bookmarksOnly,
        searchQuery: _searchQuery,
      );
      _articles = fetchedArticles;
      _cachedArticles[cacheKey] = fetchedArticles;
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

      // Normalize medical conditions for comparison
      // Handle case sensitivity, hyphens, slashes, and common variations
      final normalizedConditions = user.medicalConditions!.expand((condition) {
        final normalized = condition
            .toLowerCase()
            .replaceAll('-', '')
            .replaceAll('/', '')
            .replaceAll(' ', '');

        // Create variations for common condition names
        final variations = <String>[normalized];

        // Handle "Overweight/Obesity" -> match both "Obesity" and "Overweight"
        if (normalized.contains('overweight') ||
            normalized.contains('obesity')) {
          variations.add('obesity');
          variations.add('overweight');
        }

        // Handle "Pre-Diabetes" or "PreDiabetes" -> match "Diabetes"
        if (normalized.contains('prediabetes') ||
            normalized.contains('prediabetes')) {
          variations.add('diabetes');
        }

        return variations.toSet(); // Remove duplicates
      }).toSet();

      _recommendedArticles = allArticles.where(
        (article) {
          // Normalize article category the same way
          final normalizedCategory = article.category
              .toLowerCase()
              .replaceAll('-', '')
              .replaceAll('/', '')
              .replaceAll(' ', '');

          return normalizedConditions.contains(normalizedCategory);
        },
      ).toList();
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

    final article = _findArticleById(articleId);
    if (article == null) {
      _error = 'Article not found.';
      notifyListeners();
      return;
    }

    final newBookmarkStatus = !article.isBookmarked;

    // Optimistic UI update
    _updateArticleInLists(articleId, newBookmarkStatus);
    notifyListeners();

    try {
      await _articleRepository.updateArticleBookmark(
        articleId,
        newBookmarkStatus,
        userId: _userId!,
      );
      // Invalidate cache for the lists that might have changed
      _cachedArticles.removeWhere(
        (key, value) => key.contains('bookmarks') || key.contains('all'),
      );
    } catch (e) {
      _error = 'Failed to update bookmark: $e';
      // Revert on failure
      _updateArticleInLists(articleId, !newBookmarkStatus);
      notifyListeners();
    }
  }

  Article? _findArticleById(String articleId) {
    try {
      return _articles.firstWhere((a) => a.id == articleId);
    } catch (e) {
      try {
        return _bookmarkedArticles.firstWhere((a) => a.id == articleId);
      } catch (e) {
        try {
          return _recommendedArticles.firstWhere((a) => a.id == articleId);
        } catch (e) {
          return null;
        }
      }
    }
  }

  void _updateArticleInLists(String articleId, bool isBookmarked) {
    final articleIndex = _articles.indexWhere((a) => a.id == articleId);
    if (articleIndex != -1) {
      _articles[articleIndex] = _articles[articleIndex].copyWith(
        isBookmarked: isBookmarked,
      );
    }

    final recommendedIndex = _recommendedArticles.indexWhere(
      (a) => a.id == articleId,
    );
    if (recommendedIndex != -1) {
      _recommendedArticles[recommendedIndex] =
          _recommendedArticles[recommendedIndex].copyWith(
        isBookmarked: isBookmarked,
      );
    }

    if (isBookmarked) {
      final article = _findArticleById(articleId);
      if (article != null &&
          !_bookmarkedArticles.any((a) => a.id == articleId)) {
        _bookmarkedArticles.add(article.copyWith(isBookmarked: true));
      }
    } else {
      _bookmarkedArticles.removeWhere((a) => a.id == articleId);
    }
  }

  Future<void> searchArticles(String query) async {
    if (query.isEmpty) {
      _searchSuggestions = [];
      notifyListeners();
      return;
    }
    _searchSuggestions = await _articleRepository.getArticles(
      searchQuery: query,
      userId: _userId,
    );
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchSuggestions = [];
    loadArticles();
  }
}
