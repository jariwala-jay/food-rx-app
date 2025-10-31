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
import 'package:flutter_app/core/utils/app_logger.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({Key? key}) : super(key: key);

  @override
  _EducationPageState createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final _searchController = TextEditingController();
  bool _hasTriggeredShowcase = false;
  TourStep? _lastStep;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleController>(context, listen: false).initialize();

      // Check if tour is on education step and trigger recommended articles showcase
      final tourProvider =
          Provider.of<ForcedTourProvider>(context, listen: false);
      AppLogger.d(
          '🎯 EducationPage: Tour active: ${tourProvider.isTourActive}, Current step: ${tourProvider.currentStep}, Is on education step: ${tourProvider.isOnStep(TourStep.education)}');

      if (tourProvider.isOnStep(TourStep.education)) {
        // Wait for articles to load, then decide which showcase to show
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            try {
              final controller =
                  Provider.of<ArticleController>(context, listen: false);
              // If no recommended articles, show articles list showcase
              if (controller.recommendedArticles.isEmpty &&
                  controller.articles.isNotEmpty) {
                ShowcaseView.get().startShowCase([TourKeys.articlesListKey]);
                AppLogger.d(
                    '🎯 EducationPage: Showing articles list showcase (no recommended articles)');
              } else if (controller.recommendedArticles.isNotEmpty) {
                ShowcaseView.get()
                    .startShowCase([TourKeys.recommendedArticlesKey]);
                AppLogger.d(
                    '🎯 EducationPage: Showing recommended articles showcase');
              }
            } catch (e) {}
          }
        });
      } else if (tourProvider.isTourActive) {
        // If tour is active but not on education step, log it
        AppLogger.d(
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

    // Trigger showcase check when page becomes visible and tour is on education step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only trigger once per step change
      final currentStep = tourProvider.currentStep;
      final shouldTrigger = tourProvider.isOnStep(TourStep.education) &&
          !_hasTriggeredShowcase &&
          _lastStep != TourStep.education;

      if (shouldTrigger) {
        _hasTriggeredShowcase = true;
        _lastStep = currentStep;

        // Wait for articles to load, then decide which showcase to show
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          try {
            final controller =
                Provider.of<ArticleController>(context, listen: false);
            AppLogger.d(
                '🎯 EducationPage: recommendedArticles=${controller.recommendedArticles.length}, allArticles=${controller.articles.length}');

            // If no recommended articles, show articles list showcase
            if (controller.recommendedArticles.isEmpty &&
                controller.articles.isNotEmpty) {
              AppLogger.d(
                  '🎯 EducationPage: Triggering articles list showcase');
              ShowcaseView.get().startShowCase([TourKeys.articlesListKey]);
              AppLogger.d(
                  '🎯 EducationPage: Showing articles list showcase (no recommended articles)');
            } else if (controller.recommendedArticles.isNotEmpty) {
              AppLogger.d(
                  '🎯 EducationPage: Triggering recommended articles showcase');
              ShowcaseView.get()
                  .startShowCase([TourKeys.recommendedArticlesKey]);
              AppLogger.d(
                  '🎯 EducationPage: Showing recommended articles showcase');
            } else {
              AppLogger.d('🎯 EducationPage: No articles available');
            }
          } catch (e) {
            AppLogger.d('🎯 EducationPage: Error: $e');
          }
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

            // Content (stack allows us to overlay a full-area highlight box)
            Expanded(
              child: Stack(
                children: [
                  Consumer<ArticleController>(
                    builder: (context, articleController, child) {
                      // Trigger showcase based on what's available
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final tourProvider = Provider.of<ForcedTourProvider>(
                            context,
                            listen: false);

                        if (tourProvider.isOnStep(TourStep.education)) {
                          AppLogger.d(
                              '🎯 EducationPage Consumer: Tour on education step');
                          AppLogger.d(
                              '🎯 EducationPage Consumer: Recommended articles: ${articleController.recommendedArticles.length}');
                          AppLogger.d(
                              '🎯 EducationPage Consumer: All articles: ${articleController.articles.length}');

                          // Add delay to ensure articles are loaded
                          Future.delayed(const Duration(milliseconds: 500), () {
                            if (!context.mounted) return;

                            // If no recommended articles but we have articles, show articles list showcase
                            if (articleController.recommendedArticles.isEmpty &&
                                articleController.articles.isNotEmpty) {
                              try {
                                AppLogger.d(
                                    '🎯 EducationPage: Triggering articles list showcase');
                                ShowcaseView.get()
                                    .startShowCase([TourKeys.articlesListKey]);
                                AppLogger.d(
                                    '🎯 EducationPage: Showing articles list showcase (no recommended articles)');
                              } catch (e) {
                                AppLogger.d(
                                    '🎯 EducationPage: Error showing articles list showcase: $e');
                              }
                            }
                            // If we have recommended articles, show recommended articles showcase
                            else if (articleController
                                .recommendedArticles.isNotEmpty) {
                              try {
                                AppLogger.d(
                                    '🎯 EducationPage: Triggering recommended articles showcase');
                                ShowcaseView.get().startShowCase(
                                    [TourKeys.recommendedArticlesKey]);
                                AppLogger.d(
                                    '🎯 EducationPage: Showing recommended articles showcase');
                              } catch (e) {
                                AppLogger.d(
                                    '🎯 EducationPage: Error showing recommended articles showcase: $e');
                              }
                            }
                          });
                        }
                      });

                      return _buildContent(articleController);
                    },
                  ),
                ],
              ),
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
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
      );
    }

    if (controller.error != null) {
      return Center(child: Text('Error: ${controller.error}'));
    }

    return CustomScrollView(
      slivers: [
        if (controller.recommendedArticles.isNotEmpty) ...[
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
                  // Complete the tour
                  Provider.of<ForcedTourProvider>(context, listen: false)
                      .completeTour();
                },
                onToolTipClick: () {
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
        ],
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
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
              ),
            ),
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
            sliver: SliverList(
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
