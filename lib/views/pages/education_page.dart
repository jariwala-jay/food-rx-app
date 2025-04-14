import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/category.dart';
import '../../providers/article_provider.dart';
import '../../widgets/education/article_card.dart';
import '../../widgets/education/category_chips.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load articles when the page is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('Loading articles...');
      context.read<ArticleProvider>().loadArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search here',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                  ),
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
            Consumer<ArticleProvider>(
              builder: (context, articleProvider, _) {
                print('Categories: ${articleProvider.categories}');
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CategoryChips(
                    categories: [
                      Category(
                          name: 'All',
                          isSelected: articleProvider.selectedCategory == null),
                      ...articleProvider.categories.map((category) => Category(
                            name: category.name,
                            isSelected: articleProvider.selectedCategory ==
                                category.name,
                          )),
                    ],
                    onCategorySelected: (category) {
                      if (category.name == 'All') {
                        articleProvider.clearCategory();
                      } else {
                        articleProvider.selectCategory(category.name);
                      }
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Consumer<ArticleProvider>(
                builder: (context, articleProvider, _) {
                  print('Loading: ${articleProvider.isLoading}');
                  print('Error: ${articleProvider.error}');
                  print('Articles count: ${articleProvider.articles.length}');

                  if (articleProvider.isLoading) {
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

                  if (articleProvider.articles.isEmpty) {
                    return const Center(
                      child: Text(
                        'No articles found. Please check your internet connection or try again later.',
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
                          // TODO: Implement article detail navigation
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
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
