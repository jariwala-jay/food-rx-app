import 'package:flutter/material.dart';
import 'package:flutter_app/models/article.dart';
import 'package:flutter_app/models/category.dart';
import 'package:flutter_app/views/pages/article_detail_page.dart';
import 'package:flutter_app/widgets/education/article_card.dart';
import 'package:flutter_app/widgets/education/category_chips.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Category> categories = [
    const Category(name: 'All', isSelected: true),
    const Category(name: 'Hypertension', isSelected: false),
    const Category(name: 'Diabetes', isSelected: false),
    const Category(name: 'Heart Disease', isSelected: false),
  ];

  List<Article> articles = [
    Article(
      title: 'Why the Dash Eating Plan Works',
      category: 'Healthy Lifestyle',
      imageUrl: 'assets/images/dash_diet.png',
    ),
    Article(
      title: 'Why the Dash Eating Plan Works',
      category: 'Healthy Lifestyle',
      imageUrl: 'assets/images/dash_diet.png',
      isBookmarked: true,
    ),
    // Add more articles as needed
  ];

  void _onCategorySelected(Category category) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < categories.length; i++) {
        categories[i] = Category(
          name: categories[i].name,
          isSelected: categories[i].name == category.name,
        );
      }
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CategoryChips(
                categories: categories,
                onCategorySelected: _onCategorySelected,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  return ArticleCard(
                    article: articles[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArticleDetailPage(
                            article: articles[index],
                          ),
                        ),
                      );
                    },
                    onBookmarkTap: () {
                      if (!mounted) return;
                      setState(() {
                        articles[index] = Article(
                          title: articles[index].title,
                          category: articles[index].category,
                          imageUrl: articles[index].imageUrl,
                          isBookmarked: !articles[index].isBookmarked,
                        );
                      });
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
