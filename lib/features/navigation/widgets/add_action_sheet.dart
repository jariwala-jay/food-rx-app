import 'package:flutter/material.dart';
import 'modal_action_button.dart';
import 'package:flutter_app/features/pantry/widgets/pantry_category_picker.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/features/recipes/views/create_recipe_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/tracking/views/meal_goals_history_page.dart';

class AddActionSheet extends StatefulWidget {
  const AddActionSheet({Key? key}) : super(key: key);

  @override
  State<AddActionSheet> createState() => _AddActionSheetState();
}

class _AddActionSheetState extends State<AddActionSheet> {
  bool showPantryPicker = false;
  bool showOtherPantryPicker = false;

  @override
  Widget build(BuildContext context) {
    const double maxWidth = 400;
    final double sheetWidth = MediaQuery.of(context).size.width > maxWidth
        ? maxWidth
        : MediaQuery.of(context).size.width;

    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        Widget content;
        if (showPantryPicker) {
          content = PantryCategoryPicker(
            key: const ValueKey('food-pantry-picker'),
            title: 'Add FoodRx Items',
            categories: foodPantryCategories,
            onBack: () {
              setState(() => showPantryPicker = false);
            },
            isFoodPantryItem: true,
          );
        } else if (showOtherPantryPicker) {
          content = PantryCategoryPicker(
            key: const ValueKey('other-pantry-picker'),
            title: 'Add Home Items',
            categories: otherPantryItemCategories,
            onBack: () => setState(() => showOtherPantryPicker = false),
            isFoodPantryItem: false,
          );
        } else {
          // Check if tour is on addButton step - only allow Add FoodRx Items
          final isAddButtonStep = tourProvider.isOnStep(TourStep.addButton);

          content = Wrap(
            key: const ValueKey('action-buttons'),
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              ModalActionButton(
                iconAsset: 'assets/icons/gen_recipe.svg',
                label: 'Generate Recipe',
                shouldClose: false,
                enabled: !isAddButtonStep, // Disable during tour
                onTap: () async {
                  if (isAddButtonStep) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please tap "Add FoodRx Items" to continue the tour'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFF6A00),
                      ),
                    );
                    return;
                  }
                  // Push Create Recipe and wait for result; then close sheet and switch to Recipe tab if user generated
                  final switched = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const CreateRecipeView(),
                    ),
                  );
                  if (switched == true && context.mounted) {
                    Navigator.of(context).pop(2); // close sheet, tell MainScreen to switch to Recipe tab (index 2)
                  }
                },
              ),
              ModalActionButton(
                iconAsset: 'assets/icons/activity.svg',
                icon: const Icon(Icons.calendar_today_outlined),
                label: 'Goal Progress',
                shouldClose: true,
                enabled: !isAddButtonStep,
                onTap: () {
                  if (isAddButtonStep) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please tap \"Add FoodRx Items\" to continue the tour'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFF6A00),
                      ),
                    );
                    return;
                  }
                  final auth =
                      Provider.of<AuthController>(context, listen: false);
                  final user = auth.currentUser;
                  if (user == null || user.id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please log in again to view history.'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFF6A00),
                      ),
                    );
                    return;
                  }
                  // Close the sheet first
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => MealGoalsHistoryPage(
                        userId: user.id!,
                        dietType: user.dietType,
                        accountCreatedAt: user.createdAt,
                      ),
                    ),
                  );
                },
              ),
              Showcase(
                key: TourKeys.addFoodRxItemsKey,
                title: 'Add FoodRx Items',
                description:
                    'Add items from food pharmacy for recipe suggestions.\n\n Tap to continue',
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
                  print(
                      '🎯 AddActionSheet: User clicked on Add FoodRx Items showcase');
                  final tourProvider =
                      Provider.of<ForcedTourProvider>(context, listen: false);

                  // Complete addButton step and move to selectCategory
                  if (tourProvider.isOnStep(TourStep.addButton)) {
                    tourProvider.completeCurrentStep();
                  }

                  setState(() => showPantryPicker = true);

                  // Trigger category list showcase after opening
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    try {
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      // Check if we're now on selectCategory step
                      if (tp.isOnStep(TourStep.selectCategory)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.pantryCategoryListKey]);
                        print(
                            '🎯 AddActionSheet: Triggered category list showcase');
                      }
                    } catch (e) {
                      print(
                          '🎯 AddActionSheet: Error triggering category list showcase: $e');
                    }
                  });
                },
                onToolTipClick: () {
                  print(
                      '🎯 AddActionSheet: User clicked on Add FoodRx Items tooltip');
                  final tourProvider =
                      Provider.of<ForcedTourProvider>(context, listen: false);

                  // Complete addButton step and move to selectCategory
                  if (tourProvider.isOnStep(TourStep.addButton)) {
                    tourProvider.completeCurrentStep();
                  }

                  setState(() => showPantryPicker = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    try {
                      final tp = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      // Check if we're now on selectCategory step
                      if (tp.isOnStep(TourStep.selectCategory)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.pantryCategoryListKey]);
                        print(
                            '🎯 AddActionSheet: Triggered category list showcase');
                      }
                    } catch (e) {
                      print(
                          '🎯 AddActionSheet: Error triggering category list showcase: $e');
                    }
                  });
                },
                disposeOnTap: true,
                child: ModalActionButton(
                  iconAsset: 'assets/icons/pantry_add.svg',
                  label: 'Add FoodRx Items',
                  shouldClose: false,
                  onTap: () {
                    // The showcase's onTargetClick handles the logic
                    // Just trigger the tap manually to proceed
                    setState(() => showPantryPicker = true);
                  },
                ),
              ),
              ModalActionButton(
                iconAsset: 'assets/icons/shopping_cart.svg',
                label: 'Add Home Items',
                shouldClose: false,
                enabled: !isAddButtonStep, // Disable during tour
                onTap: () {
                  if (isAddButtonStep) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please tap "Add FoodRx Items" to continue the tour'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFF6A00),
                      ),
                    );
                    return;
                  }
                  setState(() => showOtherPantryPicker = true);
                },
              ),
            ],
          );
        }

        // Check if we're in the middle of tour steps that use this sheet
        final isTourAddFlow = tourProvider.isTourActive &&
            (tourProvider.isOnStep(TourStep.addButton) ||
                tourProvider.isOnStep(TourStep.selectCategory) ||
                tourProvider.isOnStep(TourStep.selectItem) ||
                tourProvider.isOnStep(TourStep.setQuantityUnit) ||
                tourProvider.isOnStep(TourStep.saveItem));

        // Wrap with PopScope to block system back gesture during tour
        return PopScope(
          canPop: !isTourAddFlow,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && isTourAddFlow) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please complete the tour step first'),
                  duration: Duration(seconds: 2),
                  backgroundColor: Color(0xFFFF6A00),
                ),
              );
            }
          },
          child: Stack(
            children: [
              // Tappable background - block dismissal during tour
              GestureDetector(
                onTap: () {
                  if (isTourAddFlow) {
                    // Don't allow dismissal during tour - show message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please complete the tour step first'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Color(0xFFFF6A00),
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.transparent,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              // Centered modal with content (no animation)
              Center(
                child: Container(
                  width: sheetWidth,
                  margin:
                      const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: content,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
