import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../providers/article_provider.dart';
import '../providers/auth_provider.dart';
import '../services/image_cache_service.dart';

class RecommendedArticlesSection extends StatefulWidget {
  const RecommendedArticlesSection({super.key});

  @override
  State<RecommendedArticlesSection> createState() =>
      _RecommendedArticlesSectionState();
}

class _RecommendedArticlesSectionState
    extends State<RecommendedArticlesSection> {
  bool _isLoading = true;
  List<Article> _articles = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendedArticles();
  }

  Future<void> _loadRecommendedArticles() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final articleProvider = context.read<ArticleProvider>();
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser;
      final medicalConditions = user?.medicalConditions ?? [];

      List<Article> recommendedArticles = [];

      if (medicalConditions.isNotEmpty) {
        for (final condition in medicalConditions) {
          final articles = await articleProvider.getArticles(
            category: condition,
          );
          recommendedArticles.addAll(articles);
        }
      }

      if (recommendedArticles.isEmpty) {
        recommendedArticles = await articleProvider.getArticles(
          category: 'Nutrition',
        );
      }

      if (!mounted) return;

      setState(() {
        _articles = recommendedArticles.take(5).toList();
        _isLoading = false;
      });

      // Preload images for recommended articles
      if (_articles.isNotEmpty) {
        for (final article in _articles) {
          ImageCacheService().getImageProvider(article.imageUrl);
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Failed to load recommendations';
        _isLoading = false;
      });
    }
  }

  Widget _buildRecommendedCard(BuildContext context, Article article) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/article-detail',
          arguments: article,
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
              child: Image(
                image: ImageCacheService().getImageProvider(article.imageUrl),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          _buildLoadingShimmer()
        else if (_error != null)
          Center(
            child: Text(_error!),
          )
        else if (_articles.isEmpty)
          const Center(
            child: Text('No recommendations available'),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                final article = _articles[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index < _articles.length - 1 ? 16 : 0,
                  ),
                  child: _buildRecommendedCard(context, article),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingShimmer() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index < 2 ? 16 : 0),
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
