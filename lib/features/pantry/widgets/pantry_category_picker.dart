import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_app/features/pantry/views/pantry_item_picker_page.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';
import 'dart:async';

class PantryCategoryPicker extends StatelessWidget {
  final String title;
  final List<Map<String, String>> categories;
  final VoidCallback onBack;
  final bool isFoodPantryItem;

  const PantryCategoryPicker({
    Key? key,
    required this.title,
    required this.categories,
    required this.onBack,
    required this.isFoodPantryItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get text scale factor and clamp it for UI elements that must fit
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
    
    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: onBack,
                  splashRadius: 20,
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18 * clampedScale,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 40), // To balance the back button
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Showcase(
                key: TourKeys.pantryCategoryListKey,
                title: 'Add All Your Pantry Items',
                description:
                    'Add all items from your food pantry visit today. More items = better recipe recommendations! Tap any category to continue.',
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: Colors.white,
                tooltipPosition: TooltipPosition.bottom,
                textColor: Colors.black,
                overlayColor: Colors.black54,
                overlayOpacity: 0.8,
                showArrow: true,
                onTargetClick: () {
                  // Dismiss showcase to allow category selection
                  ShowcaseView.get().dismiss();
                },
                onToolTipClick: () {
                  // Dismiss showcase to allow category selection
                  ShowcaseView.get().dismiss();
                },
                disposeOnTap: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: categories
                        .map((cat) => ListTile(
                              leading: SvgPicture.asset(cat['icon']!,
                                  width: 40, height: 40),
                              title: Text(
                                cat['title']!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15 * clampedScale,
                                  color: Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: cat['subtitle'] != null &&
                                      cat['subtitle']!.isNotEmpty
                                  ? Text(
                                      cat['subtitle']!,
                                      style: TextStyle(
                                        fontSize: 12 * clampedScale,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right_rounded,
                                  color: Colors.grey),
                              onTap: () {
                                // Dismiss showcase if it's showing
                                try {
                                  ShowcaseView.get().dismiss();
                                } catch (e) {
                                  // Showcase might not be active
                                }

                                // Complete selectCategory step if we're on it
                                final tp = Provider.of<ForcedTourProvider>(context,
                                    listen: false);
                                if (tp.isOnStep(TourStep.selectCategory)) {
                                  tp.completeCurrentStep();
                                }

                                // Small delay to ensure showcase is dismissed
                                Future.delayed(const Duration(milliseconds: 100),
                                    () {
                                  if (!context.mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PantryItemPickerPage(
                                        categoryTitle: cat['title']!,
                                        categoryKey: cat['key']!,
                                        isFoodPantryItem: isFoodPantryItem,
                                      ),
                                    ),
                                  );
                                });
                              },
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
