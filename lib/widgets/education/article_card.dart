import 'package:flutter/material.dart';
import 'package:flutter_app/models/article.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;
  final VoidCallback? onBookmarkTap;

  const ArticleCard({
    super.key,
    required this.article,
    this.onTap,
    this.onBookmarkTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                article.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF181818),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.category,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                article.isBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border_outlined,
                color: article.isBookmarked
                    ? const Color(0xFFFF6A00)
                    : Colors.grey[400],
              ),
              onPressed: onBookmarkTap,
            ),
          ],
        ),
      ),
    );
  }
}
