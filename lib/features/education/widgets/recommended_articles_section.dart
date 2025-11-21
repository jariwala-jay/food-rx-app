import 'package:flutter/material.dart';
import 'package:flutter_app/features/education/models/article.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/features/education/widgets/article_card.dart';

class RecommendedArticlesSection extends StatelessWidget {
  final List<Article> articles;

  const RecommendedArticlesSection({
    Key? key,
    required this.articles,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(1.0, 1.3);

    // Calculate dynamic height based on text scaling
    // Base: 120 (image) + 24 (padding) + ~40 (text) = ~184, add buffer for scaling
    final baseHeight = 220.0;
    final sectionHeight = baseHeight * clampedScale.clamp(1.0, 1.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended',
          style: TextStyle(
            fontSize: 22 * clampedScale.clamp(0.8, 1.0),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: sectionHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: articles.length,
            itemBuilder: (context, index) {
              final article = articles[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.7,
                margin: const EdgeInsets.only(right: 16),
                child: ArticleCard(
                  article: article,
                  isRecommended: true, // Use different layout for recommended
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailPage(
                          article: article,
                        ),
                      ),
                    );
                  },
                  onBookmarkTap: () {
                    // This should be handled by the controller
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
