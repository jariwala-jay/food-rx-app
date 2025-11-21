import 'package:flutter/material.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/core/services/image_cache_service.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;
  final bool isRecommended;

  const ArticleCard({
    Key? key,
    required this.article,
    required this.onTap,
    required this.onBookmarkTap,
    this.isRecommended = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return isRecommended
        ? _buildRecommendedCard(context)
        : _buildListCard(context);
  }

  Widget _buildRecommendedCard(BuildContext context) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image, size: 50),
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  article.title,
                  style: TextStyle(
                    fontSize: 16 * clampedScale,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(BuildContext context) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
        child: Row(
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Image(
                image: ImageCacheService().getImageProvider(article.imageUrl),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.image, size: 50),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 16 * clampedScale,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.category,
                      style: TextStyle(
                        fontSize: 12 * clampedScale,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                article.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: const Color(0xFFFF6A00),
              ),
              onPressed: onBookmarkTap,
            ),
          ],
        ),
      ),
    );
  }
}
