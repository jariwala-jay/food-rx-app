import 'package:flutter/material.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/core/services/image_cache_service.dart';
import 'package:provider/provider.dart';

class ArticleDetailPage extends StatelessWidget {
  final Article article;

  const ArticleDetailPage({
    Key? key,
    required this.article,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use a Consumer to get the latest state of the article
    return Consumer<ArticleController>(
      builder: (context, controller, child) {
        // Find the article from the controller's list to get the latest bookmark status
        final latestArticle = controller.articles.firstWhere(
          (a) => a.id == article.id,
          orElse: () => article, // Fallback to the initial article
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      latestArticle.isBookmarked
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: latestArticle.isBookmarked
                          ? const Color(0xFFFF6A00)
                          : Colors.black,
                      size: 28,
                    ),
                    onPressed: () {
                      controller.toggleBookmark(latestArticle.id);
                    },
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240.0,
                  width: double.infinity,
                  child: Image(
                    image: ImageCacheService()
                        .getImageProvider(latestArticle.imageUrl),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported, size: 50),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          latestArticle.category,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        latestArticle.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        latestArticle.content ?? 'No content available.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
