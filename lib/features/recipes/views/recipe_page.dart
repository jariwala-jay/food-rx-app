import 'package:flutter/material.dart';
import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter_app/core/widgets/tab_load_error_view.dart';
import 'package:flutter_app/core/utils/app_logger.dart';
import 'package:flutter_app/features/recipes/widgets/recipe_card.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/recipes/controller/recipe_controller.dart';
import 'package:flutter_app/features/recipes/models/recipe.dart';
import 'package:flutter_app/features/recipes/models/recipe_filter.dart';
import 'package:flutter_app/features/recipes/views/create_recipe_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/features/recipes/views/saved_recipes_page.dart';
import 'package:flutter_app/features/recipes/views/prepared_recipes_page.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

// State class for efficient rebuilds
class RecipePageState {
  final List<Recipe> recipes;
  final bool isLoading;
  final String? error;
  final bool hasAttemptedGeneration;
  final bool isGeneratingRecipes; // NEW: Tracks actual recipe generation
  final List<String> userMedicalConditionsDisplay;

  const RecipePageState({
    required this.recipes,
    required this.isLoading,
    required this.error,
    required this.hasAttemptedGeneration,
    required this.isGeneratingRecipes,
    required this.userMedicalConditionsDisplay,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RecipePageState &&
        other.recipes.length == recipes.length &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.hasAttemptedGeneration == hasAttemptedGeneration &&
        other.isGeneratingRecipes == isGeneratingRecipes &&
        other.userMedicalConditionsDisplay.length ==
            userMedicalConditionsDisplay.length;
  }

  @override
  int get hashCode {
    return recipes.length.hashCode ^
        isLoading.hashCode ^
        error.hashCode ^
        hasAttemptedGeneration.hashCode ^
        isGeneratingRecipes.hashCode ^
        userMedicalConditionsDisplay.length.hashCode;
  }
}

class RecipePage extends StatefulWidget {
  const RecipePage({Key? key}) : super(key: key);

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> with TickerProviderStateMixin {
  bool _hasInitialized = false;
  bool _hasTriggeredRecipesShowcase = false;
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  /// Local filter for generated recipes (title match).
  final TextEditingController _recipeSearchController = TextEditingController();
  final FocusNode _recipeSearchFocusNode = FocusNode();
  bool _recipeSearchMode = false;

  @override
  void initState() {
    super.initState();
    _recipeSearchController.addListener(() {
      if (mounted) setState(() {});
    });

    // Initialize animations
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    // Initialize the recipe controller when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        final controller =
            Provider.of<RecipeController>(context, listen: false);
        controller.initialize();

        // If tour is active and on recipes step, generate fallback recipes
        final tourProvider =
            Provider.of<ForcedTourProvider>(context, listen: false);
        if (tourProvider.isOnStep(TourStep.recipes)) {
          _generateFallbackRecipes(controller);
        }
      }
    });
  }

  Future<void> _generateFallbackRecipes(RecipeController controller) async {
    // Use a simple query that always returns results
    final fallbackFilter = const RecipeFilter(
      query: 'healthy',
      veryHealthy: true,
    );

    await controller.generateRecipes(filter: fallbackFilter);
  }

  @override
  void dispose() {
    _recipeSearchController.dispose();
    _recipeSearchFocusNode.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  List<Recipe> _visibleRecipesForSearch(List<Recipe> all) {
    final q = _recipeSearchController.text.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((r) => r.title.toLowerCase().contains(q))
        .toList();
  }

  void _closeRecipeSearch() {
    _recipeSearchController.clear();
    _recipeSearchFocusNode.unfocus();
    setState(() => _recipeSearchMode = false);
  }

  void _openCreateRecipe() {
    _closeRecipeSearch();
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const CreateRecipeView(),
      ),
    );
  }

  Widget _buildPreparedAndSearchRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreparedRecipesPage(),
                ),
              );
            },
            child: Container(
              height: 50,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A00),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Prepared recipes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (!_recipeSearchMode)
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _recipeSearchMode = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _recipeSearchFocusNode.requestFocus();
                  }
                });
              },
              child: Container(
                height: 50,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6A00),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Search recipes',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Expanded(
            child: AppSearchField(
              controller: _recipeSearchController,
              focusNode: _recipeSearchFocusNode,
              hintText: 'Search recipes',
              onChanged: (_) => setState(() {}),
              suffixIcon: IconButton(
                icon: Icon(Icons.close, color: Colors.grey[600]),
                onPressed: _closeRecipeSearch,
                tooltip: 'Close search',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset showcase flag if we're no longer on recipes step
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);
    if (!tourProvider.isOnStep(TourStep.recipes)) {
      _hasTriggeredRecipesShowcase = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              // Header with title
              Row(
                children: [
                  const Text(
                    'Recipes',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Chatbot icon temporarily disabled
                  // IconButton(
                  //   icon: const Icon(Icons.chat_bubble_outline),
                  //   iconSize: 24,
                  //   onPressed: () {
                  //     Navigator.pushNamed(context, '/chatbot');
                  //   },
                  // ),
                  IconButton(
                    icon: const Icon(Icons.star_border_rounded),
                    iconSize: 28,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SavedRecipesPage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Main content
              Expanded(
                child: Selector<RecipeController, (RecipePageState, String, bool)>(
                  selector: (_, controller) => (
                    RecipePageState(
                      recipes: controller.recipes,
                      isLoading: controller.isLoading,
                      error: controller.error,
                      hasAttemptedGeneration: controller.hasAttemptedGeneration,
                      isGeneratingRecipes: controller.isLoading ||
                          _isGenerationInProgress(controller), // NEW
                      userMedicalConditionsDisplay:
                          controller.userMedicalConditionsDisplay,
                    ),
                    _recipeSearchController.text,
                    _recipeSearchMode,
                  ),
                  builder: (context, data, child) {
                    final state = data.$1;
                    if (kDebugMode) {
                      AppLogger.d(
                          '🏗️ RecipePage Selector rebuild: ${state.recipes.length} recipes, loading: ${state.isLoading}, generating: ${state.isGeneratingRecipes}, error: ${state.error}, hasAttempted: ${state.hasAttemptedGeneration}');
                    }

                    // Always show loading state when loading OR generating recipes
                    if (state.isGeneratingRecipes) {
                      if (kDebugMode) {
                        print(
                            '⏳ Showing loading state - recipes being generated');
                      }
                      return _buildAnimatedLoadingState();
                    }

                    // Prioritize showing recipes if they exist, even if there was an error
                    if (state.recipes.isNotEmpty) {
                      if (kDebugMode) {
                        print('🍽️ Showing ${state.recipes.length} recipes');
                      }

                      // Trigger recipes showcase when recipes first appear if tour is active
                      // Use a flag to prevent multiple triggers
                      if (!_hasTriggeredRecipesShowcase) {
                        _hasTriggeredRecipesShowcase = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final tourProvider = Provider.of<ForcedTourProvider>(
                              context,
                              listen: false);
                          print(
                              '🎯 RecipePage: Recipes loaded, tour active: ${tourProvider.isTourActive}, current step: ${tourProvider.currentStep}');
                          // Only trigger if we're on the recipes step
                          if (tourProvider.isOnStep(TourStep.recipes)) {
                            try {
                              ShowcaseView.get()
                                  .startShowCase([TourKeys.recipesKey]);
                              print(
                                  '🎯 RecipePage: Triggered recipes showcase (on recipes step)');
                            } catch (e) {
                              print(
                                  '🎯 RecipePage: Error triggering showcase: $e');
                            }
                          } else {
                            // Reset flag if step changed
                            _hasTriggeredRecipesShowcase = false;
                          }
                        });
                      }

                      _fadeAnimationController.forward();
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildRecipeList(state),
                      );
                    }

                    // Only show error state if loading is complete AND there are no recipes AND there's an error AND generation was attempted
                    if (state.error != null && state.hasAttemptedGeneration) {
                      if (kDebugMode) {
                        print('🚨 Showing error state: ${state.error}');
                      }
                      return _buildErrorState(context);
                    }

                    // Only show empty state if generation has been attempted and no results and no error and no longer generating
                    if (state.hasAttemptedGeneration &&
                        !state.isGeneratingRecipes) {
                      if (kDebugMode) {
                        print(
                            '📝 Showing empty state - generation completed with no recipes');
                      }

                      // If tour is active, try fallback recipes
                      final tourProvider = Provider.of<ForcedTourProvider>(
                          context,
                          listen: false);
                      final recipeController =
                          Provider.of<RecipeController>(context, listen: false);
                      if (tourProvider.isOnStep(TourStep.recipes) &&
                          state.recipes.isEmpty) {
                        // Generate fallback recipes for tour
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _generateFallbackRecipes(recipeController);
                        });
                        // Return loading state while generating
                        return _buildAnimatedLoadingState();
                      }

                      // Trigger recipes showcase when showing empty state if tour is active
                      // Use a flag to prevent multiple triggers
                      if (!_hasTriggeredRecipesShowcase) {
                        _hasTriggeredRecipesShowcase = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final tp = Provider.of<ForcedTourProvider>(context,
                              listen: false);
                          if (tp.isOnStep(TourStep.recipes)) {
                            try {
                              ShowcaseView.get()
                                  .startShowCase([TourKeys.recipesKey]);
                            } catch (e) {
                              // Silently handle error
                            }
                          } else {
                            // Reset flag if step changed
                            _hasTriggeredRecipesShowcase = false;
                          }
                        });
                      }

                      return _buildEmptyState(context);
                    }

                    // Default behavior for users who haven't generated recipes yet
                    if (kDebugMode) {}
                    return _buildDefaultDiscovery();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to detect if generation is in progress
  bool _isGenerationInProgress(RecipeController controller) {
    // Consider generation in progress ONLY if:
    // 1. Currently loading (still calling API/extracting recipes)
    // 2. Has attempted but no recipes yet AND no evidence of completion
    return controller.isLoading ||
        (controller.hasAttemptedGeneration &&
            controller.recipes.isEmpty &&
            controller.error == null &&
            !_hasGenerationCompleted(controller));
  }

  // Check if generation has completed but resulted in no recipes
  bool _hasGenerationCompleted(RecipeController controller) {
    // If not loading anymore, generation is complete regardless of results
    return !controller.isLoading;
  }

  Widget _buildAnimatedLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple circular progress indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),

            Text(
              'Finding Perfect Recipes for You...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _getLoadingMessage(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(RecipePageState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Medical conditions indicator with Generate button
        if (state.userMedicalConditionsDisplay.isNotEmpty) ...[
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F8FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE3F2FD)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.health_and_safety,
                        color: Colors.blue[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Filtered for: ${state.userMedicalConditionsDisplay.join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openCreateRecipe,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEEFE4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add,
                        color: Color(0xFFFF6A00),
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Generate',
                        style: TextStyle(
                          color: Color(0xFFFF6A00),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        _buildPreparedAndSearchRow(),
        const SizedBox(height: 16),
        Text(
          'Recommended for you (${_visibleRecipesForSearch(state.recipes).length})',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        const SizedBox(height: 16),
        Expanded(
          child: Showcase(
            key: TourKeys.recipesKey,
            title: 'Your Recipes',
            description: TourDescriptions.recipes,
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
            onTargetClick: () {
              final tourProvider =
                  Provider.of<ForcedTourProvider>(context, listen: false);
              print(
                  '🎯 RecipePage: Current step before completion: ${tourProvider.currentStep}');

              // Only complete the step if we're on the recipes step
              // If we're already on education, the tour has progressed too far
              if (tourProvider.isOnStep(TourStep.recipes)) {
                tourProvider.completeCurrentStep();

                // Dismiss current showcase and trigger education tab showcase after completing step
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  try {
                    ShowcaseView.get().dismiss();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      if (tp.isOnStep(TourStep.education)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.educationTabKey]);
                      }
                    });
                  } catch (e) {
                    print(
                        '🎯 RecipePage: Error triggering education tab showcase: $e');
                  }
                });
              } else {
                print(
                    '🎯 RecipePage: Already past recipes step, skipping completion');
                // If we're past recipes step, just complete the tour
                tourProvider.completeTour();
              }
            },
            onToolTipClick: () {
              final tourProvider =
                  Provider.of<ForcedTourProvider>(context, listen: false);
              if (tourProvider.isOnStep(TourStep.recipes)) {
                tourProvider.completeCurrentStep();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  try {
                    ShowcaseView.get().dismiss();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      if (tp.isOnStep(TourStep.education)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.educationTabKey]);
                      }
                    });
                  } catch (e) {
                    print(
                        '🎯 RecipePage: Error triggering education tab showcase: $e');
                  }
                });
              } else {
                tourProvider.completeTour();
              }
            },
            disposeOnTap: true,
            child: Builder(
              builder: (context) {
                final visible = _visibleRecipesForSearch(state.recipes);
                final q = _recipeSearchController.text.trim();
                if (visible.isEmpty && q.isNotEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No recipes match "$q"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    return RecipeCard(recipe: visible[index]);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEEFE4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search,
              color: Color(0xFFFF6A00),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF6A00),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultDiscovery() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          const Text(
            'Turn Your Pantry into Delicious Meals',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          // Prepared recipes button (centered) shown before first generation
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreparedRecipesPage(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A00),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Prepared recipes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Showcase(
            key: TourKeys.generateRecipeButtonKey,
            title: 'Generate Recipes',
            description:
                'Create recipes from your pantry items.\n\n Tap to continue',
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(24)),
            ),
            tooltipBackgroundColor: TourTooltipStyle.tooltipBackgroundColor,
            textColor: TourTooltipStyle.textColor,
            overlayColor: TourTooltipStyle.overlayColor,
            overlayOpacity: TourTooltipStyle.overlayOpacity,
            toolTipMargin: TourTooltipStyle.toolTipMargin,
            titleTextStyle: TourTooltipStyle.titleStyle,
            descTextStyle: TourTooltipStyle.descriptionStyle,
            onTargetClick: () {
              // Don't complete step here - let them explore the recipe creation
              // The tour will end after this step
              _openCreateRecipe();
            },
            onToolTipClick: () {
              _openCreateRecipe();
            },
            disposeOnTap: true,
            child: _buildButton('Generate Recipes', _openCreateRecipe),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 20),

            // Enhanced empty state messaging with showcase
            Showcase(
              key: TourKeys.recipesKey,
              title: 'No Recipes Available',
              description:
                  'Try adding more pantry items or removing all cuisine preferences and try again later.\n\n Tap the highlighted area to continue',
              targetShapeBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              tooltipBackgroundColor: Colors.white,
              textColor: Colors.black,
              overlayColor: Colors.black54,
              overlayOpacity: 0.8,
              onTargetClick: () {
                final tourProvider =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tourProvider.isOnStep(TourStep.recipes)) {
                  tourProvider.completeCurrentStep();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.educationTabKey]);
                    } catch (e) {
                      // Silently handle error
                    }
                  });
                } else {
                  tourProvider.completeTour();
                }
              },
              onToolTipClick: () {
                final tourProvider =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tourProvider.isOnStep(TourStep.recipes)) {
                  tourProvider.completeCurrentStep();
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.educationTabKey]);
                    } catch (e) {
                      // Silently handle error
                    }
                  });
                } else {
                  tourProvider.completeTour();
                }
              },
              disposeOnTap: true,
              child: Column(
                children: [
                  Text(
                    'No Recipes Available',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getEmptyStateMessage(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Prepared recipes button (matches FoodRx Items pill style)
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PreparedRecipesPage(),
                    ),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6A00),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Prepared recipes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Showcase(
              key: TourKeys.generateRecipeButtonKey,
              title: 'Generate Recipes',
              description:
                  'Tap to set cuisine preferences, meal type, servings, and cooking time, then generate personalized recipes from your pantry.\n\n Tap the highlighted area to continue',
              targetShapeBorder: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              tooltipBackgroundColor: Colors.white,
              textColor: Colors.black,
              overlayColor: Colors.black54,
              overlayOpacity: 0.8,
              onTargetClick: () {
                _openCreateRecipe();
              },
              onToolTipClick: () {
                _openCreateRecipe();
              },
              disposeOnTap: true,
              child: _buildButton('Generate Recipes', _openCreateRecipe),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                final controller =
                    Provider.of<RecipeController>(context, listen: false);
                controller.generateRecipes();
              },
              child: Text(
                'Try Again',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmptyStateMessage() {
    final controller = Provider.of<RecipeController>(context, listen: false);
    final pantryItems = controller.pantryItems;

    if (pantryItems.isEmpty) {
      return 'Start by adding ingredients to your pantry.\nThen we can suggest personalized recipes based on your dietary needs and preferences.';
    } else if (controller.error != null) {
      return 'We encountered an issue loading recipes.\nPlease check your connection and try again.';
    } else {
      return 'No recipes met all your dietary constraints and pantry requirements.\nThis can happen when recipes don’t match your health conditions or available ingredients.\nTry adding more ingredients or generate custom recipes with relaxed filters.';
    }
  }

  Widget _buildErrorState(BuildContext context) {
    return TabLoadErrorView(
      title: 'Unable to load recipes',
      onRetry: () {
        final controller =
            Provider.of<RecipeController>(context, listen: false);
        controller.clearError();
        if (!_hasInitialized) {
          _hasInitialized = true;
          controller.initialize();
        }
        controller.generateRecipes();
      },
    );
  }

  String _getLoadingMessage() {
    final controller = Provider.of<RecipeController>(context, listen: false);
    final pantryItems = controller.pantryItems;

    if (pantryItems.isEmpty) {
      return 'Loading your pantry items and creating personalized recommendations...';
    } else {
      return 'Analyzing your pantry and filtering recipes based on your dietary preferences and health goals...';
    }
  }
}
