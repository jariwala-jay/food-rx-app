import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/widgets/app_scrollbar.dart';
import 'package:flutter_app/features/pantry/views/pantry_group_category_page.dart';
import 'package:flutter_app/features/pantry/views/pantry_item_picker_page.dart';
import 'package:flutter_app/features/pantry/widgets/pantry_category_icon.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class PantryCategoryPicker extends StatefulWidget {
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
  State<PantryCategoryPicker> createState() => _PantryCategoryPickerState();
}

class _PantryCategoryPickerState extends State<PantryCategoryPicker> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openCategory(BuildContext context, Map<String, String> cat) {
    final key = cat['key']!;
    if (isFoodPantryGroupCategory(key)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PantryGroupCategoryPage(
            groupTitle: cat['title']!,
            groupKey: key,
            isFoodPantryItem: widget.isFoodPantryItem,
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: cat['title']!,
          categoryKey: key,
          isFoodPantryItem: widget.isFoodPantryItem,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, child) {
        final isTourCategoryFlow = tourProvider.isTourActive &&
            tourProvider.isOnStep(TourStep.selectCategory);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () {
                    if (isTourCategoryFlow) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please complete the tour step first - tap on "Fruits"'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Color(0xFFFF6A00),
                        ),
                      );
                      return;
                    }
                    widget.onBack();
                  },
                  splashRadius: 20,
                ),
                Expanded(
                  child: Text(
                    widget.title,
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
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: AppScrollbar(
                  controller: _scrollController,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 12),
                    shrinkWrap: true,
                    children: widget.categories.map((cat) {
                      final isTourStep =
                          tourProvider.isOnStep(TourStep.selectCategory);
                      final isFruits = cat['key'] == 'fruits';
                      final shouldHighlight = isTourStep && isFruits;

                      final listTile = ListTile(
                        tileColor:
                            shouldHighlight ? const Color(0xFFFFF3EB) : null,
                        shape: shouldHighlight
                            ? RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(
                                  color: Color(0xFFFF6A00),
                                  width: 2,
                                ),
                              )
                            : null,
                        leading: PantryCategoryIcon(assetPath: cat['icon']!),
                        title: Text(
                          cat['title']!,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15 * clampedScale,
                            color: shouldHighlight
                                ? const Color(0xFFFF6A00)
                                : Colors.black,
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
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: shouldHighlight
                              ? const Color(0xFFFF6A00)
                              : Colors.grey,
                        ),
                        onTap: () {
                          if (isTourStep && !isFruits) {
                            return;
                          }
                          _openCategory(context, cat);
                        },
                      );

                      if (shouldHighlight) {
                        return Showcase(
                          key: TourKeys.pantryCategoryListKey,
                          title: 'Add Food Items',
                          description: TourDescriptions.selectCategory,
                          targetShapeBorder: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          tooltipBackgroundColor:
                              TourTooltipStyle.tooltipBackgroundColor,
                          tooltipPosition: TooltipPosition.bottom,
                          textColor: TourTooltipStyle.textColor,
                          overlayColor: TourTooltipStyle.overlayColor,
                          overlayOpacity: TourTooltipStyle.overlayOpacity,
                          toolTipMargin: TourTooltipStyle.toolTipMargin,
                          titleTextStyle: TourTooltipStyle.titleStyle,
                          descTextStyle: TourTooltipStyle.descriptionStyle,
                          showArrow: true,
                          onTargetClick: () {
                            if (isFruits) {
                              ShowcaseView.get().dismiss();
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                if (!context.mounted) return;
                                _openCategory(context, cat);
                              });
                            }
                          },
                          onToolTipClick: () {
                            if (isFruits) {
                              ShowcaseView.get().dismiss();
                              Future.delayed(const Duration(milliseconds: 100),
                                  () {
                                if (!context.mounted) return;
                                _openCategory(context, cat);
                              });
                            }
                          },
                          disposeOnTap: false,
                          child: listTile,
                        );
                      }

                      return listTile;
                    }).toList(),
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
