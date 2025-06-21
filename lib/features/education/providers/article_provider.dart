import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/models/category.dart'
    as app_category;
import 'package:flutter_app/features/education/repositories/article_repository.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';

class ArticleProvider extends ChangeNotifier {
  final ArticleRepository _articleRepository;
  final Map<String, List<Article>> _categoryArticles = {};
  final Map<String, List<Article>> _cachedArticles = {};
  List<Article> _articles = [];
  List<Article> _searchResults = [];
  List<Article> _searchSuggestions = [];
  List<Article> _recommendedArticles = [];
  List<app_category.Category> _categories = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  String? _selectedCategory;
  bool _showBookmarksOnly = false;
  String? _searchQuery;

  // Reference to AuthProvider
  AuthController? _authProvider;

  ArticleProvider(this._articleRepository);

  // Method to set the auth provider reference
  void setAuthProvider(AuthController authProvider) {
    if (_authProvider != authProvider) {
      _authProvider = authProvider;
      // Clear cache and reload articles when auth provider changes
      clearCache();
      loadArticles();
    }
  }

  List<Article> get articles => _articles;
  List<Article> get searchResults => _searchResults;
  List<Article> get searchSuggestions => _searchSuggestions;
  List<Article> get recommendedArticles => _recommendedArticles;
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get showBookmarksOnly => _showBookmarksOnly;
  String? get searchQuery => _searchQuery;
  Set<String> get availableCategoryNames => _categoryArticles.keys.toSet();

  // Add a method to pre-fetch articles for all categories
  Future<void> preFetchArticles() async {
    try {
      if (_categories.isEmpty) {
        _categories = await _articleRepository.getCategories();
      }

      final userId = _authProvider?.currentUser?.id;

      // Pre-fetch articles for each category in parallel
      await Future.wait([
        // Pre-fetch "All" articles
        getArticles().then((articles) {
          final cacheKey = 'all_${_searchQuery ?? ''}';
          _cachedArticles[cacheKey] = articles;
        }),
        // Pre-fetch bookmarked articles if user is logged in
        if (userId != null)
          _articleRepository
              .getArticles(bookmarksOnly: true, userId: userId)
              .then((articles) {
            final cacheKey = 'bookmarks_${_searchQuery ?? ''}';
            _cachedArticles[cacheKey] = articles;
          }),
        // Pre-fetch articles for each category
        ..._categories.map((category) => getArticles(category: category.name)),
      ]);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<List<Article>> getArticles({String? category}) async {
    try {
      final userId = _authProvider?.currentUser?.id;

      // Check if we have cached articles for this category and search query
      final cacheKey = '${category ?? 'all'}_${_searchQuery ?? ''}';
      if (_cachedArticles.containsKey(cacheKey)) {
        return _cachedArticles[cacheKey]!;
      }

      final List<Article> articles = await _articleRepository.getArticles(
        category: category,
        userId: userId,
      );

      // Cache the articles
      _cachedArticles[cacheKey] = articles;
      if (category != null) {
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
        _categories = await _articleRepository.getCategories();
      }

      final userId = _authProvider?.currentUser?.id;
      final cacheKey = _showBookmarksOnly
          ? 'bookmarks_${_searchQuery ?? ''}'
          : '${_selectedCategory ?? 'all'}_${_searchQuery ?? ''}';

      // Try to get articles from cache first
      if (_cachedArticles.containsKey(cacheKey)) {
        _articles = _cachedArticles[cacheKey]!;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // If not in cache, load from service
      List<Article> articles;
      if (_showBookmarksOnly) {
        articles = await _articleRepository.getArticles(
          bookmarksOnly: true,
          userId: userId,
        );
        _cachedArticles[cacheKey] = articles;
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

  Future<void> searchArticles(String query) async {
    if (query.isEmpty) {
      _searchResults = [];
      _searchSuggestions = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _searchQuery = query;
    notifyListeners();

    try {
      final userId = _authProvider?.currentUser?.id;

      // Get all articles first
      final allArticles = await _articleRepository.getArticles(
        userId: userId,
      );

      // Filter articles based on search query
      final filteredArticles = allArticles.where((article) {
        final titleMatch =
            article.title.toLowerCase().contains(query.toLowerCase());
        final contentMatch =
            article.content?.toLowerCase().contains(query.toLowerCase()) ??
                false;
        final categoryMatch =
            article.category.toLowerCase().contains(query.toLowerCase());
        return titleMatch || contentMatch || categoryMatch;
      }).toList();

      // Sort by relevance (title matches first, then content, then category)
      filteredArticles.sort((a, b) {
        final aTitleMatch = a.title.toLowerCase().contains(query.toLowerCase());
        final bTitleMatch = b.title.toLowerCase().contains(query.toLowerCase());
        if (aTitleMatch != bTitleMatch) {
          return aTitleMatch ? -1 : 1;
        }

        final aContentMatch =
            a.content?.toLowerCase().contains(query.toLowerCase()) ?? false;
        final bContentMatch =
            b.content?.toLowerCase().contains(query.toLowerCase()) ?? false;
        if (aContentMatch != bContentMatch) {
          return aContentMatch ? -1 : 1;
        }

        final aCategoryMatch =
            a.category.toLowerCase().contains(query.toLowerCase());
        final bCategoryMatch =
            b.category.toLowerCase().contains(query.toLowerCase());
        if (aCategoryMatch != bCategoryMatch) {
          return aCategoryMatch ? -1 : 1;
        }

        return 0;
      });

      // Update search results
      _searchResults = filteredArticles;

      // Generate suggestions (top 5 most relevant results)
      _searchSuggestions = filteredArticles.take(5).toList();

      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = null;
    _searchResults = [];
    _searchSuggestions = [];
    _isSearching = false;
    loadArticles();
  }

  void selectSearchSuggestion(Article article) {
    _searchQuery = article.title;
    _searchResults = [article];
    _searchSuggestions = [];
    _isSearching = false;
    notifyListeners();
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    _showBookmarksOnly = false;
    notifyListeners();
    loadArticles();
  }

  void clearCategory() {
    _selectedCategory = null;
    _showBookmarksOnly = false;
    notifyListeners();
    loadArticles();
  }

  void showBookmarks() {
    _showBookmarksOnly = true;
    _selectedCategory = null;
    notifyListeners();
    loadArticles();
  }

  Future<void> toggleBookmark(String articleId) async {
    final userId = _authProvider?.currentUser?.id;
    if (userId == null) {
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
            _recommendedArticles.firstWhere((a) => a.id == articleId);
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
      await _articleRepository
          .updateArticleBookmark(articleId, newBookmarkStatus, userId: userId);
      // If successful, we might want to refresh the bookmark list if we are on it
      if (_showBookmarksOnly) {
        await loadArticles();
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

    final recommendedArticleIndex =
        _recommendedArticles.indexWhere((a) => a.id == articleId);
    if (recommendedArticleIndex != -1) {
      _recommendedArticles[recommendedArticleIndex] =
          _recommendedArticles[recommendedArticleIndex]
              .copyWith(isBookmarked: isBookmarked);
    }

    if (isBookmarked) {
      if (!_articles.any((a) => a.id == articleId) && articleIndex != -1) {
        _articles.add(_articles[articleIndex].copyWith(isBookmarked: true));
      }
    } else {
      _articles.removeWhere((a) => a.id == articleId);
    }
    notifyListeners();
  }

  void clearCache() {
    _cachedArticles.clear();
    _categoryArticles.clear();
    _articles = [];
    _searchResults = [];
    _searchSuggestions = [];
    _categories = [];
    _selectedCategory = null;
    _showBookmarksOnly = false;
    _searchQuery = null;
    notifyListeners();
  }

  Article getArticleById(String id) {
    // First check in the main articles list
    final article = _articles.firstWhere(
      (article) => article.id == id,
      orElse: () => throw Exception('Article not found with ID: $id'),
    );
    return article;
  }

  Future<void> fetchRecommendedArticles() async {
    try {
      final user = _authProvider?.currentUser;
      final medicalConditions = user?.medicalConditions ?? [];

      List<Article> recommendedArticles = [];

      if (medicalConditions.isNotEmpty) {
        for (final condition in medicalConditions) {
          final articles = await getArticles(
            category: condition,
          );
          recommendedArticles.addAll(articles);
        }
      }

      if (recommendedArticles.isEmpty) {
        recommendedArticles = await getArticles(
          category: 'Nutrition',
        );
      }
      _recommendedArticles = recommendedArticles.take(5).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
