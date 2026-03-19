import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';
import 'package:flutter_app/features/education/widgets/article_card.dart';
import 'package:flutter_app/features/education/widgets/category_chips.dart';
import 'package:flutter_app/features/education/widgets/recommended_articles_section.dart';
import 'package:flutter_app/features/education/views/education_plan_video_page.dart';
import 'package:flutter_app/features/education/widgets/article_filter_sheet.dart';
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
  bool _isPlanVideoBookmarked = true;

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
            // Header row: search bar spreads full width around icons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  AppSearchAnchor(
                    hintText: 'Search for articles',
                    barPadding: const EdgeInsets.only(
                        left: 12, right: 72, top: 10, bottom: 10),
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chatbot icon temporarily disabled
                      // IconButton(
                      //   icon: const Icon(Icons.chat_bubble_outline),
                      //   onPressed: () => Navigator.pushNamed(context, '/chatbot'),
                      // ),
                      IconButton(
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          final result = await showModalBottomSheet<Set<String>>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) => ArticleFilterSheet(
                              categories: controller.categories,
                              selectedCategories: controller.selectedFilterCategories,
                            ),
                          );
                          if (result != null && mounted) {
                            controller.applyFilterCategories(result);
                          }
                        },
                      ),
                    ],
                  ),
                ],
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
                title: 'Recommended For You',
                description: TourDescriptions.education,
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: TourTooltipStyle.tooltipBackgroundColor,
                textColor: TourTooltipStyle.textColor,
                overlayColor: TourTooltipStyle.overlayColor,
                overlayOpacity: TourTooltipStyle.overlayOpacity,
                toolTipMargin: TourTooltipStyle.toolTipMargin,
                titleTextStyle: TourTooltipStyle.titleStyle,
                descTextStyle: TourTooltipStyle.descriptionStyle,
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
                child: Consumer<AuthController>(
                  builder: (_, authController, __) {
                    final myPlanType = authController.currentUser?.myPlanType ??
                        authController.currentUser?.dietType ??
                        'MyPlate';
                    return RecommendedArticlesSection(
                      articles: controller.recommendedArticles,
                      myPlanType: myPlanType,
                    );
                  },
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
          // When on Bookmarks tab with no saved items, fall back to showing the
          // same recommended list (video + docs) as the All tab so the user
          // still sees content.
          controller.bookmarksOnly &&
                  controller.recommendedArticles.isNotEmpty
              ? Consumer<AuthController>(
                  builder: (_, authController, __) {
                    final myPlanType =
                        authController.currentUser?.myPlanType ??
                            authController.currentUser?.dietType ??
                            'MyPlate';

                    final itemCount =
                        1 + controller.recommendedArticles.length; // video + docs

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              final title = myPlanType == 'DiabetesPlate'
                                  ? 'Diabetes Plate'
                                  : myPlanType == 'DASH'
                                      ? 'DASH Diet'
                                      : 'MyPlate';
                              return _buildPlanVideoListRow(
                                  context, myPlanType, title);
                            }
                            final articleIndex = index - 1;
                            final article = controller
                                .recommendedArticles[articleIndex]
                                .copyWith(isBookmarked: true);
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
                          childCount: itemCount,
                        ),
                      ),
                    );
                  },
                )
              : const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: 50.0),
                    child: Center(
                        child: Text('No articles found in this section.')),
                  ),
                )
        else
          // When there ARE articles (including bookmarks), show a normal list.
          // Prepend the plan video as the first item only:
          // - on the Bookmarks tab, or
          // - when viewing the category that matches the user's plan
          (() {
            final auth =
                Provider.of<AuthController>(context, listen: false);
            final planType =
                auth.currentUser?.myPlanType ?? auth.currentUser?.dietType;
            String? planCategory;
            if (planType == 'DiabetesPlate') {
              planCategory = 'Diabetes';
            } else if (planType == 'DASH') {
              planCategory = 'Hypertension';
            } else if (planType == 'MyPlate') {
              planCategory = 'Obesity';
            }
            if (controller.bookmarksOnly) return true;
            if (planCategory == null) return false;
            return controller.selectedCategory?.name == planCategory;
          }())
              ? Consumer<AuthController>(
                  builder: (_, authController, __) {
                    final myPlanType =
                        authController.currentUser?.myPlanType ??
                            authController.currentUser?.dietType ??
                            'MyPlate';

                    final itemCount = 1 + controller.articles.length;

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == 0) {
                              final title = myPlanType == 'DiabetesPlate'
                                  ? 'Diabetes Plate'
                                  : myPlanType == 'DASH'
                                      ? 'DASH Diet'
                                      : 'MyPlate';
                              return _buildPlanVideoListRow(
                                  context, myPlanType, title);
                            }
                            final articleIndex = index - 1;
                            final article =
                                controller.articles[articleIndex];
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
                          childCount: itemCount,
                        ),
                      ),
                    );
                  },
                )
              : SliverPadding(
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

  Widget _buildPlanVideoListRow(
      BuildContext context, String planType, String title) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    String thumbnailPath(String planType) {
      switch (planType) {
        case 'DASH':
          return 'assets/nutrition/screenshots/dash/1.png';
        case 'MyPlate':
          return 'assets/nutrition/screenshots/myplate/1.png';
        case 'DiabetesPlate':
          return 'assets/nutrition/screenshots/diabetes_plate/1.png';
        default:
          return 'assets/nutrition/screenshots/myplate/1.png';
      }
    }

    String categoryLabel(String planType) {
      switch (planType) {
        case 'DiabetesPlate':
          return 'Diabetes';
        case 'DASH':
          return 'Hypertension';
        case 'MyPlate':
          return 'Obesity';
        default:
          return 'Video';
      }
    }

    return Card(
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
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EducationPlanVideoPage(
                      planType: planType,
                      title: title,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  Image.asset(
                    thumbnailPath(planType),
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.5),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.videocam,
                        color: Color(0xFFFF6A00),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16 * clampedScale,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    categoryLabel(planType),
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
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                _isPlanVideoBookmarked
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: const Color(0xFFFF6A00),
              ),
              onPressed: () {
                setState(() {
                  _isPlanVideoBookmarked = !_isPlanVideoBookmarked;
                });
              },
            ),
          ),
        ],
      ),
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
      height: maxExtent,
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
