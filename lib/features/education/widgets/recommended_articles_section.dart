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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommended',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220, // Adjust height to fit cards
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
