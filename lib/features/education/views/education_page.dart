import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/widgets/article_card.dart';
import 'package:flutter_app/features/education/widgets/category_chips.dart';
import 'package:flutter_app/features/education/widgets/recommended_articles_section.dart';
import 'package:flutter_app/features/education/views/article_detail_page.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/features/home/widgets/tour_completion_dialog.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_app/core/services/navigation_service.dart';
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
    // Only initialize data here. Do NOT start showcases from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ArticleController>(context, listen: false).initialize();
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

    // Single, debounced entry point to start a showcase on this page.
    // Only trigger once when we transition to education step
    final currentStep = tourProvider.currentStep;
    final shouldTrigger = tourProvider.isOnStep(TourStep.education) &&
        !_hasTriggeredShowcase &&
        _lastStep != TourStep.education;

    if (shouldTrigger) {
      _hasTriggeredShowcase = true;
      _lastStep = currentStep;

      // Wait for article lists to render, then decide which target to highlight.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          try {
            final tp = Provider.of<ForcedTourProvider>(context, listen: false);
            // Double-check we're still on education step
            if (!tp.isOnStep(TourStep.education)) {
              _hasTriggeredShowcase = false;
              return;
            }

            final c = Provider.of<ArticleController>(context, listen: false);
            AppLogger.d(
              '🎯 EducationPage: recommended=${c.recommendedArticles.length}, all=${c.articles.length}',
            );

            if (c.recommendedArticles.isEmpty && c.articles.isNotEmpty) {
              ShowcaseView.get().startShowCase([TourKeys.articlesListKey]);
              AppLogger.d('🎯 EducationPage: Showing articles list showcase');
            } else if (c.recommendedArticles.isNotEmpty) {
              ShowcaseView.get()
                  .startShowCase([TourKeys.recommendedArticlesKey]);
              AppLogger.d('🎯 EducationPage: Showing recommended showcase');
            } else {
              AppLogger.d(
                  '🎯 EducationPage: No articles available to showcase');
            }
          } catch (e) {
            AppLogger.d('🎯 EducationPage: Error starting showcase: $e');
            _hasTriggeredShowcase = false; // Reset on error
          }
        });
      });
    }

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
              child: Stack(
                children: [
                  Consumer<ArticleController>(
                    builder: (consumerContext, articleController, child) {
                      // No showcase starts here anymore — just render content.
                      // Pass the widget's context (from build method) to _buildContent
                      return _buildContent(context, articleController);
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

  Widget _buildContent(
      BuildContext widgetContext, ArticleController controller) {
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
                onTargetClick: () async {
                  debugPrint(
                      '🎯 EducationPage: onTargetClick - completing tour');
                  final tourProvider = Provider.of<ForcedTourProvider>(
                      widgetContext,
                      listen: false);
                  // Complete tour
                  await tourProvider.completeTour();
                  debugPrint('🎯 EducationPage: Tour completed');
                  // Show completion dialog after delay using global navigator key
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    final navigator =
                        NavigationService.navigatorKey.currentState;
                    if (navigator != null && navigator.overlay != null) {
                      try {
                        showDialog(
                          context: navigator.overlay!.context,
                          barrierDismissible: false,
                          builder: (dialogContext) =>
                              const TourCompletionDialog(),
                        );
                        debugPrint(
                            '🎯 EducationPage: Dialog shown successfully using navigator overlay');
                      } catch (e) {
                        debugPrint(
                            '🎯 EducationPage: Error showing completion dialog: $e');
                      }
                    } else {
                      debugPrint(
                          '🎯 EducationPage: Navigator or overlay is null, cannot show dialog');
                    }
                  });
                },
                onToolTipClick: () async {
                  debugPrint(
                      '🎯 EducationPage: onToolTipClick - completing tour');
                  final tourProvider = Provider.of<ForcedTourProvider>(
                      widgetContext,
                      listen: false);
                  // Complete tour
                  await tourProvider.completeTour();
                  debugPrint('🎯 EducationPage: Tour completed');
                  // Show completion dialog after delay using global navigator key
                  Future.delayed(const Duration(milliseconds: 1000), () {
                    final navigator =
                        NavigationService.navigatorKey.currentState;
                    if (navigator != null && navigator.overlay != null) {
                      try {
                        showDialog(
                          context: navigator.overlay!.context,
                          barrierDismissible: false,
                          builder: (dialogContext) =>
                              const TourCompletionDialog(),
                        );
                        debugPrint(
                            '🎯 EducationPage: Dialog shown successfully using navigator overlay');
                      } catch (e) {
                        debugPrint(
                            '🎯 EducationPage: Error showing completion dialog: $e');
                      }
                    } else {
                      debugPrint(
                          '🎯 EducationPage: Navigator or overlay is null, cannot show dialog');
                    }
                  });
                },
                disposeOnTap: true,
                child: RecommendedArticlesSection(
                  articles: controller.recommendedArticles,
                ),
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
    return SizedBox(
      height: 52.0,
      child: Container(
        color: const Color(0xFFF7F7F8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return child != oldDelegate.child;
  }
}
