import 'package:flutter/material.dart';
import 'modal_action_button.dart';
import 'package:flutter_app/features/pantry/widgets/pantry_category_picker.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/features/recipes/views/create_recipe_view.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

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
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateRecipeView(),
                    ),
                  );
                },
              ),
              ModalActionButton(
                iconAsset: 'assets/icons/activity.svg',
                label: 'Add Physically Activity',
                onTap: () {},
              ),
              Showcase(
                key: TourKeys.addFoodRxItemsKey,
                title: 'Add Your Pantry Items',
                description:
                    'Let\'s add items you got from food pharmacy. This helps us suggest recipes you can actually make!',
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: Colors.white,
                textColor: Colors.black,
                overlayColor: Colors.black54,
                overlayOpacity: 0.8,
                onTargetClick: () {
                  print(
                      '🎯 AddActionSheet: User clicked on Add FoodRx Items showcase');
                  // Don't complete step yet - wait for user to add items
                  setState(() => showPantryPicker = true);

                  // Trigger category list showcase after opening
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    try {
                      ShowCaseWidget.of(context)
                          .startShowCase([TourKeys.pantryCategoryListKey]);
                      print(
                          '🎯 AddActionSheet: Triggered category list showcase');
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
                onTap: () => setState(() => showOtherPantryPicker = true),
              ),
            ],
          );
        }

        return Stack(
          children: [
            // Tappable background
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
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
        );
      },
    );
  }
}
