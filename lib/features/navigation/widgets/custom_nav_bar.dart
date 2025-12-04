import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_app/features/education/controller/article_controller.dart';

class CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHomeTap;
  final VoidCallback onPantryTap;
  final VoidCallback onRecipeTap;
  final VoidCallback onChatTap;
  final VoidCallback onEducationTap;
  final bool isAddActive;
  final VoidCallback onAddTap;

  const CustomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onHomeTap,
    required this.onPantryTap,
    required this.onRecipeTap,
    required this.onChatTap,
    required this.onEducationTap,
    required this.isAddActive,
    required this.onAddTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Make sure the navigation bar is at the bottom with no margins
    return Container(
      height: 70,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(
                  svgPath: 'assets/icons/home.svg',
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: onHomeTap,
                ),
                Showcase(
                  key: TourKeys.pantryTabKey,
                  title: 'View Your Pantry',
                  description:
                      'Tap here to see all your pantry items and manage your inventory.',
                  targetShapeBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  tooltipBackgroundColor: Colors.white,
                  textColor: Colors.black,
                  overlayColor: Colors.black54,
                  overlayOpacity: 0.8,
                  onTargetClick: () {
                    print(
                        '🎯 CustomNavBar: User clicked on Pantry tab showcase');
                    // Don't complete step here - let the pantry items showcase complete it
                    // We need to stay on pantryItems step so the toggle showcase can trigger the pantry items showcase
                    onPantryTap();

                    // Trigger toggle showcase after navigation
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (!context.mounted) return;
                        try {
                          final tp = Provider.of<ForcedTourProvider>(context,
                              listen: false);
                          // Only trigger if we're still on pantryItems step
                          if (tp.isOnStep(TourStep.pantryItems)) {
                            ShowcaseView.get().dismiss();
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              if (!context.mounted) return;
                              final tp2 = Provider.of<ForcedTourProvider>(
                                  context,
                                  listen: false);
                              if (tp2.isOnStep(TourStep.pantryItems)) {
                                ShowcaseView.get().startShowCase(
                                    [TourKeys.pantryTabToggleKey]);
                                print(
                                    '🎯 CustomNavBar: Triggered Pantry tab toggle showcase');
                              }
                            });
                          }
                        } catch (e) {
                          print(
                              '🎯 CustomNavBar: Error triggering toggle showcase: $e');
                        }
                      });
                    });
                  },
                  onToolTipClick: () {
                    print(
                        '🎯 CustomNavBar: User clicked on Pantry tab tooltip');
                    // Don't complete step here - let the pantry items showcase complete it
                    // We need to stay on pantryItems step so the toggle showcase can trigger the pantry items showcase
                    onPantryTap();

                    // Trigger toggle showcase after navigation
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (!context.mounted) return;
                        try {
                          final tp = Provider.of<ForcedTourProvider>(context,
                              listen: false);
                          // Only trigger if we're still on pantryItems step
                          if (tp.isOnStep(TourStep.pantryItems)) {
                            ShowcaseView.get().dismiss();
                            Future.delayed(const Duration(milliseconds: 300),
                                () {
                              if (!context.mounted) return;
                              final tp2 = Provider.of<ForcedTourProvider>(
                                  context,
                                  listen: false);
                              if (tp2.isOnStep(TourStep.pantryItems)) {
                                ShowcaseView.get().startShowCase(
                                    [TourKeys.pantryTabToggleKey]);
                                print(
                                    '🎯 CustomNavBar: Triggered Pantry tab toggle showcase');
                              }
                            });
                          }
                        } catch (e) {
                          print(
                              '🎯 CustomNavBar: Error triggering toggle showcase: $e');
                        }
                      });
                    });
                  },
                  disposeOnTap: true,
                  child: _buildNavItem(
                    svgPath: 'assets/icons/pantry.svg',
                    label: 'Pantry',
                    isSelected: currentIndex == 1,
                    onTap: onPantryTap,
                  ),
                ),
                // Empty space for center button
                const SizedBox(width: 60),
                Showcase(
                  key: TourKeys.recipesTabKey,
                  title: 'Explore Recipes',
                  description:
                      'Tap here to see personalized recipes based on your pantry items and meal plan.',
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
                    print(
                        '🎯 CustomNavBar: User clicked on Recipe tab showcase');
                    print(
                        '🎯 CustomNavBar: Current step: ${tourProvider.currentStep}');
                    // Don't complete step here - let RecipePage handle it
                    onRecipeTap();

                    // Trigger Generate Recipes button showcase after navigation
                    // Only if we're on the recipes step
                    if (tourProvider.isOnStep(TourStep.recipes)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!context.mounted) return;
                          try {
                            final tp = Provider.of<ForcedTourProvider>(context,
                                listen: false);
                            // Double-check step hasn't changed
                            if (tp.isOnStep(TourStep.recipes)) {
                              ShowcaseView.get().startShowCase(
                                  [TourKeys.generateRecipeButtonKey]);
                              print(
                                  '🎯 CustomNavBar: Triggered Generate Recipes button showcase');
                            }
                          } catch (e) {
                            print(
                                '🎯 CustomNavBar: Error triggering Generate Recipes showcase: $e');
                          }
                        });
                      });
                    }
                  },
                  onToolTipClick: () {
                    print(
                        '🎯 CustomNavBar: User clicked on Recipe tab tooltip');
                    final tourProvider =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    onRecipeTap();
                    // Only trigger if we're on the recipes step
                    if (tourProvider.isOnStep(TourStep.recipes)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!context.mounted) return;
                          try {
                            final tp = Provider.of<ForcedTourProvider>(context,
                                listen: false);
                            // Double-check step hasn't changed
                            if (tp.isOnStep(TourStep.recipes)) {
                              ShowcaseView.get().startShowCase(
                                  [TourKeys.generateRecipeButtonKey]);
                              print(
                                  '🎯 CustomNavBar: Triggered Generate Recipes button showcase');
                            }
                          } catch (e) {
                            print(
                                '🎯 CustomNavBar: Error triggering Generate Recipes showcase: $e');
                          }
                        });
                      });
                    }
                  },
                  disposeOnTap: true,
                  child: _buildNavItem(
                    svgPath: 'assets/icons/recipe.svg',
                    label: 'Recipe',
                    isSelected: currentIndex == 2,
                    onTap: onRecipeTap,
                  ),
                ),
                Showcase(
                  key: TourKeys.educationTabKey,
                  title: 'Access tips and additional resources',
                  description:
                      'Access expert articles and tips to help you manage your health condition.',
                  targetShapeBorder: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  tooltipBackgroundColor: Colors.white,
                  textColor: Colors.black,
                  overlayColor: Colors.black54,
                  overlayOpacity: 0.8,
                  onTargetClick: () {
                    print(
                        '🎯 CustomNavBar: User clicked on Education tab showcase');
                    final tourProvider =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    print(
                        '🎯 CustomNavBar: Current step: ${tourProvider.currentStep}');

                    // Complete the recipes step (if we're coming from recipes)
                    if (tourProvider.isOnStep(TourStep.recipes)) {
                      tourProvider.completeCurrentStep();
                    }

                    // Navigate to Education page - let EducationPage initState handle showcase trigger
                    onEducationTap();

                    // Trigger appropriate showcase after navigation
                    Future.delayed(const Duration(milliseconds: 500), () {
                      try {
                        final articleController =
                            Provider.of<ArticleController>(context,
                                listen: false);

                        if (articleController.recommendedArticles.isNotEmpty) {
                          ShowcaseView.get()
                              .startShowCase([TourKeys.recommendedArticlesKey]);
                        }
                      } catch (e) {}
                    });
                  },
                  onToolTipClick: () {
                    print(
                        '🎯 CustomNavBar: User clicked on Education tab tooltip');
                    final tourProvider =
                        Provider.of<ForcedTourProvider>(context, listen: false);

                    // Complete the recipes step (if we're coming from recipes)
                    if (tourProvider.isOnStep(TourStep.recipes)) {
                      tourProvider.completeCurrentStep();
                    }

                    // Navigate to Education page - let EducationPage initState handle showcase trigger
                    onEducationTap();

                    // Trigger appropriate showcase after navigation
                    Future.delayed(const Duration(milliseconds: 500), () {
                      try {
                        final articleController =
                            Provider.of<ArticleController>(context,
                                listen: false);

                        if (articleController.recommendedArticles.isNotEmpty) {
                          ShowcaseView.get()
                              .startShowCase([TourKeys.recommendedArticlesKey]);
                        }
                      } catch (e) {}
                    });
                  },
                  disposeOnTap: true,
                  child: _buildNavItem(
                    svgPath: 'assets/icons/education.svg',
                    label: 'Education',
                    isSelected: currentIndex == 3,
                    onTap: onEducationTap,
                  ),
                ),
              ],
            ),
          ),
          // Center floating button with animation
          Positioned(
            top: -20,
            child: Showcase(
              key: TourKeys.addButtonKey,
              title: 'Add Items & Recipes',
              description:
                  'Tap the + button to add food items to your pantry or create new recipes.',
              targetShapeBorder: const CircleBorder(),
              tooltipBackgroundColor: Colors.white,
              textColor: Colors.black,
              overlayColor: Colors.black54,
              overlayOpacity: 0.8,
              onTargetClick: () {
                // Don't complete the step here - let MainScreen._handleAddTap complete it
                // after the action sheet closes. This prevents premature step completion
                // and ensures the pantry showcase triggers at the right time.

                // Open the action sheet
                onAddTap();

                // Dismiss current showcase and trigger the next showcase step (Add FoodRx Items) after action sheet opens
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  try {
                    ShowcaseView.get().dismiss();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!context.mounted) return;
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      // Only trigger if we're still on the addButton step
                      // (step will be completed after action sheet closes)
                      if (tp.isOnStep(TourStep.addButton)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.addFoodRxItemsKey]);
                      }
                    });
                  } catch (e) {
                    debugPrint(
                        '🎯 CustomNavBar: Error triggering addFoodRxItems showcase: $e');
                  }
                });
              },
              onToolTipClick: () {
                // Don't complete the step here - let MainScreen._handleAddTap complete it
                // after the action sheet closes.

                // Open the action sheet
                onAddTap();

                // Dismiss current showcase and trigger the next showcase step (Add FoodRx Items) after action sheet opens
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  try {
                    ShowcaseView.get().dismiss();
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!context.mounted) return;
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      // Only trigger if we're still on the addButton step
                      // (step will be completed after action sheet closes)
                      if (tp.isOnStep(TourStep.addButton)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.addFoodRxItemsKey]);
                      }
                    });
                  } catch (e) {
                    debugPrint(
                        '🎯 CustomNavBar: Error triggering addFoodRxItems showcase: $e');
                  }
                });
              },
              disposeOnTap: false,
              child: GestureDetector(
                onTap: onAddTap,
                child: AnimatedRotation(
                  turns: isAddActive ? 0.125 : 0.0, // 45deg = 1/8 turn
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6A00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/icons/add.svg',
                        width: 32,
                        height: 32,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required String svgPath,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    const Color activeColor = Color(0xFF181818);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            svgPath,
            width: 22,
            height: 22,
            colorFilter: ColorFilter.mode(
              isSelected ? activeColor : Colors.grey,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? activeColor : Colors.grey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
