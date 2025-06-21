import 'package:flutter/material.dart';
import 'package:flutter_app/core/utils/typography.dart';
import 'package:flutter_app/features/education/providers/article_provider.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';

class RecommendedArticlesSection extends StatelessWidget {
  const RecommendedArticlesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Provider.of<ArticleProvider>(context, listen: false)
          .fetchRecommendedArticles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return Consumer<ArticleProvider>(
            builder: (context, articleProvider, child) {
              final articles = articleProvider.recommendedArticles;
              if (articles.isEmpty) {
                return const Center(child: Text('No recommended articles.'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Recommended For You',
                      style: AppTypography.bg_18_b),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: articles.length,
                      itemBuilder: (context, index) {
                        final article = articles[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: _buildRecommendedCard(context, article),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        }
      },
    );
  }

  Widget _buildRecommendedCard(BuildContext context, Article article) {
    final authController = context.read<AuthController>();
    final articleProvider = context.read<ArticleProvider>();
    final user = authController.currentUser;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArticleDetailPage(article: article),
          ),
        );
      },
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                article.imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 120,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 30,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                article.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: Colors.orange,
              ),
              onPressed: () {
                if (user != null) {
                  articleProvider.toggleBookmark(article.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
