import 'package:flutter/material.dart';
import 'modal_action_button.dart';
import 'package:flutter_app/features/pantry/widgets/pantry_category_picker.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';

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

    Widget content;
    if (showPantryPicker) {
      content = PantryCategoryPicker(
        key: const ValueKey('food-pantry-picker'),
        title: 'Add Food Pantry Items',
        categories: foodPantryCategories,
        onBack: () => setState(() => showPantryPicker = false),
        isFoodPantryItem: true,
      );
    } else if (showOtherPantryPicker) {
      content = PantryCategoryPicker(
        key: const ValueKey('other-pantry-picker'),
        title: 'Other Pantry Items',
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
            onTap: () {},
          ),
          ModalActionButton(
            iconAsset: 'assets/icons/activity.svg',
            label: 'Add Physically Activity',
            onTap: () {},
          ),
          ModalActionButton(
            iconAsset: 'assets/icons/pantry_add.svg',
            label: 'Add Food Pantry Items',
            shouldClose: false,
            onTap: () => setState(() => showPantryPicker = true),
          ),
          ModalActionButton(
            iconAsset: 'assets/icons/shopping_cart.svg',
            label: 'Add Other pantry Items',
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
            margin: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
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
  }
}
