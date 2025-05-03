import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../models/article.dart';
import '../../providers/article_provider.dart';
import '../../widgets/education/article_card.dart';
import '../../widgets/education/category_chips.dart';
import '../../services/image_cache_service.dart';
import 'article_detail_page.dart';
import 'dart:async';

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Load articles when the page is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ArticleProvider>().loadArticles();
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isEmpty) {
        setState(() {
          _showSearchResults = false;
        });
        context.read<ArticleProvider>().clearSearch();
      } else {
        setState(() {
          _showSearchResults = true;
        });
        context.read<ArticleProvider>().searchArticles(query);
      }
    });
  }

  void _onSearchSubmitted(String query) {
    if (query.isNotEmpty) {
      setState(() {
        _showSearchResults = true;
      });
      context.read<ArticleProvider>().searchArticles(query);
    }
    // Dismiss keyboard on submit
    _searchFocusNode.unfocus();
  }

  void _onSuggestionSelected(Article article) {
    // Dismiss keyboard before navigation
    _searchFocusNode.unfocus();
    // Navigate directly to article detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(article: article),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _showSearchResults = false;
    });
    context.read<ArticleProvider>().clearSearch();
    // Dismiss keyboard when clearing search
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => _searchFocusNode.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  decoration: InputDecoration(
                    hintText: 'Search articles...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[400],
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (!_showSearchResults) ...[
                Consumer<ArticleProvider>(
                  builder: (context, articleProvider, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CategoryChips(
                        categories: [
                          Category(
                              name: 'All',
                              isSelected:
                                  articleProvider.selectedCategory == null &&
                                      !articleProvider.showBookmarksOnly),
                          Category(
                            name: 'Bookmarks',
                            isSelected: articleProvider.showBookmarksOnly,
                            icon: Icons.bookmark,
                          ),
                          ...articleProvider.categories
                              .map((category) => Category(
                                    name: category.name,
                                    isSelected:
                                        articleProvider.selectedCategory ==
                                            category.name,
                                  )),
                        ],
                        onCategorySelected: (category) {
                          if (category.name == 'All') {
                            articleProvider.clearCategory();
                          } else if (category.name == 'Bookmarks') {
                            articleProvider.showBookmarks();
                          } else {
                            articleProvider.selectCategory(category.name);
                          }
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              Expanded(
                child: Consumer<ArticleProvider>(
                  builder: (context, articleProvider, _) {
                    if (articleProvider.isLoading ||
                        articleProvider.isSearching) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (articleProvider.error != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            articleProvider.error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }

                    if (_showSearchResults) {
                      if (articleProvider.searchSuggestions.isNotEmpty &&
                          _searchController.text.isNotEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: articleProvider.searchSuggestions.length,
                          itemBuilder: (context, index) {
                            final article =
                                articleProvider.searchSuggestions[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image(
                                  image: ImageCacheService()
                                      .getImageProvider(article.imageUrl),
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child:
                                          const Icon(Icons.image_not_supported),
                                    );
                                  },
                                ),
                              ),
                              title: Text(article.title),
                              subtitle: Text(article.category),
                              onTap: () => _onSuggestionSelected(article),
                            );
                          },
                        );
                      }

                      if (articleProvider.searchResults.isEmpty) {
                        return const Center(
                          child: Text(
                            'No articles found matching your search.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: articleProvider.searchResults.length,
                        itemBuilder: (context, index) {
                          final article = articleProvider.searchResults[index];
                          return ArticleCard(
                            article: article,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ArticleDetailPage(article: article),
                                ),
                              );
                            },
                            onBookmarkTap: () {
                              articleProvider.toggleBookmark(article);
                            },
                          );
                        },
                      );
                    }

                    if (articleProvider.articles.isEmpty) {
                      return const Center(
                        child: Text(
                          'No articles found!',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: articleProvider.articles.length,
                      itemBuilder: (context, index) {
                        final article = articleProvider.articles[index];
                        return ArticleCard(
                          article: article,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ArticleDetailPage(article: article),
                              ),
                            );
                          },
                          onBookmarkTap: () {
                            articleProvider.toggleBookmark(article);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }
}
