import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/widgets/article_card.dart';
import 'package:flutter_app/features/education/widgets/category_chips.dart';
import 'package:flutter_app/features/education/widgets/recommended_articles_section.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({Key? key}) : super(key: key);

  @override
  _EducationPageState createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleController>(context, listen: false).initialize();

      // Check if tour is on education step and trigger recommended articles showcase
      final tourProvider =
          Provider.of<ForcedTourProvider>(context, listen: false);
      print(
          '🎯 EducationPage: Tour active: ${tourProvider.isTourActive}, Current step: ${tourProvider.currentStep}, Is on education step: ${tourProvider.isOnStep(TourStep.education)}');

      if (tourProvider.isOnStep(TourStep.education)) {
        // Trigger recommended articles showcase
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            try {
              ShowcaseView.get().startShowCase([TourKeys.educationKey]);
            } catch (e) {}
          }
        });
      } else if (tourProvider.isTourActive) {
        // If tour is active but not on education step, log it
        print(
            '🎯 EducationPage: Tour is active but not on education step. Current: ${tourProvider.currentStep}');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ArticleController>(context);
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    // Trigger education showcase when page becomes visible and tour is on education step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print(
          '🎯 EducationPage: Build callback - Tour active: ${tourProvider.isTourActive}, Step: ${tourProvider.currentStep}');
      if (tourProvider.isOnStep(TourStep.education)) {
        Future.delayed(const Duration(milliseconds: 300), () {
          try {
            ShowcaseView.get().startShowCase([TourKeys.educationKey]);
          } catch (e) {}
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: AppSearchAnchor(
                hintText: 'Search for articles',
                trailing: [Icon(Icons.tune, color: Colors.grey[600])],
                suggestionsBuilder: (BuildContext context,
                    SearchController searchController) async {
                  await controller.searchArticles(searchController.text);
                  return controller.searchSuggestions.map((article) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 2.0),
                      child: ArticleCard(
                        article: article,
                        onTap: () {
                          searchController.closeView(article.title);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ArticleDetailPage(article: article),
                            ),
                          );
                        },
                        onBookmarkTap: () =>
                            controller.toggleBookmark(article.id),
                      ),
                    );
                  }).toList();
                },
              ),
            ),

            // Content
            Expanded(
              child: _buildContent(controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ArticleController controller) {
    if (controller.isLoading &&
        controller.articles.isEmpty &&
        controller.recommendedArticles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.error != null) {
      return Center(child: Text('Error: ${controller.error}'));
    }

    return CustomScrollView(
      slivers: [
        if (controller.recommendedArticles.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Showcase(
                key: TourKeys.recommendedArticlesKey,
                title: 'Recommended Articles',
                description:
                    'These articles are specially selected for your health condition and goals.',
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: Colors.white,
                textColor: Colors.black,
                overlayColor: Colors.black54,
                overlayOpacity: 0.8,
                onTargetClick: () {
                  print(
                      '🎯 EducationPage: User clicked on recommended articles showcase');
                  // Complete the tour
                  Provider.of<ForcedTourProvider>(context, listen: false)
                      .completeTour();
                },
                onToolTipClick: () {
                  print(
                      '🎯 EducationPage: User clicked on recommended articles tooltip');
                  // Complete the tour
                  Provider.of<ForcedTourProvider>(context, listen: false)
                      .completeTour();
                },
                disposeOnTap: true,
                child: RecommendedArticlesSection(
                    articles: controller.recommendedArticles),
              ),
            ),
          ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverAppBarDelegate(
            child: CategoryChips(
              categories: controller.categories,
              onAllSelected: () => controller.selectAll(),
              onCategorySelected: (category) =>
                  controller.selectCategory(category),
              onBookmarksSelected: () => controller.selectBookmarks(),
              selectedCategory: controller.selectedCategory,
              bookmarksSelected: controller.bookmarksOnly,
            ),
          ),
        ),
        if (controller.isLoading && controller.articles.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (controller.articles.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(top: 50.0),
              child: Center(child: Text('No articles found in this section.')),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: Showcase(
              key: TourKeys.articlesListKey,
              title: 'Browse All Articles',
              description:
                  'Scroll through articles by category or bookmark your favorites to read later.',
              targetShapeBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              tooltipBackgroundColor: Colors.white,
              textColor: Colors.black,
              overlayColor: Colors.black54,
              overlayOpacity: 0.8,
              onTargetClick: () {
                print(
                    '🎯 EducationPage: User clicked on articles list showcase');
                // Complete the tour
                Provider.of<ForcedTourProvider>(context, listen: false)
                    .completeTour();
              },
              disposeOnTap: true,
              child: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final article = controller.articles[index];
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
                        controller.toggleBookmark(article.id);
                      },
                    );
                  },
                  childCount: controller.articles.length,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => 52.0;
  @override
  double get maxExtent => 52.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: const Color(0xFFF7F7F8), // Match page background
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: child, // CategoryChips
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
