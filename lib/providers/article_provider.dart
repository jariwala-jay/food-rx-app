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
  List<Article> _searchResults = [];
  List<Article> _searchSuggestions = [];
  List<app_category.Category> _categories = [];
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;
  String? _selectedCategory;
  bool _showBookmarksOnly = false;
  String? _searchQuery;

  // Reference to AuthProvider
  AuthProvider? _authProvider;

  ArticleProvider(this._articleService);

  // Method to set the auth provider reference
  void setAuthProvider(AuthProvider authProvider) {
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
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;
  String? get selectedCategory => _selectedCategory;
  bool get showBookmarksOnly => _showBookmarksOnly;
  String? get searchQuery => _searchQuery;
  Set<String> get availableCategoryNames => _categoryArticles.keys.toSet();

  Future<List<Article>> getArticles({String? category}) async {
    try {
      final userId = _authProvider?.currentUser?.id;

      // Check if we have cached articles for this category and search query
      final cacheKey = '${category ?? 'all'}_${_searchQuery ?? ''}';
      if (_cachedArticles.containsKey(cacheKey)) {
        return _cachedArticles[cacheKey]!;
      }

      final List<Article> articles = await _articleService.getArticles(
        category: category,
        userId: userId,
        search: _searchQuery,
      );

      // Cache the articles
      if (category != null) {
        _cachedArticles[cacheKey] = articles;
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
          search: _searchQuery,
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
      final allArticles = await _articleService.getArticles(
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
      if (userId == null) {
        throw Exception('User must be logged in to bookmark articles');
      }

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
        throw Exception('Failed to update bookmark: $e');
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
}
