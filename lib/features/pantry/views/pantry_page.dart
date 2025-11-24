import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../controller/pantry_controller.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import '../widgets/category_filter_chips.dart';
import 'package:flutter_app/features/navigation/widgets/add_action_sheet.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({Key? key}) : super(key: key);

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> with RouteAware {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  RouteObserver<ModalRoute<void>>? _routeObserver;
  ForcedTourProvider?
      _tourProvider; // Store reference to avoid context access after disposal

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Store reference to tour provider to avoid context access after disposal
    _tourProvider = Provider.of<ForcedTourProvider>(context, listen: false);

    // It's safer to obtain RouteObserver here as context is available.
    // Ensure your RouteObserver is provided higher up in the widget tree.
    // For example, in your MaterialApp setup.
    final newRouteObserver = ModalRoute.of(context) != null
        ? Provider.of<RouteObserver<ModalRoute<void>>>(context, listen: false)
        : null;
    if (newRouteObserver != _routeObserver) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = newRouteObserver;
      _routeObserver?.subscribe(
          this,
          ModalRoute.of(context)!
              as PageRoute); // Cast to PageRoute if necessary for your setup
    }
  }

  // Helper method to handle tour progression after removing item
  void _handleRemoveItemTourProgression() {
    // Use stored reference instead of context
    final tourProvider = _tourProvider;
    if (tourProvider == null) {
      print('🎯 PantryPage: Tour provider not available');
      return;
    }

    // Use a post-frame callback to ensure widget is still mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        if (tourProvider.isOnStep(TourStep.removePantryItem)) {
          // Complete the current step
          tourProvider.completeCurrentStep();

          // Dismiss any active showcase
          try {
            ShowcaseView.get().dismiss();
          } catch (e) {
            // Ignore if showcase is not active
          }

          // Trigger recipes tab showcase after a delay
          Future.delayed(const Duration(milliseconds: 800), () {
            if (!mounted) return;
            try {
              // Refresh the provider reference in case it changed
              final currentProvider = _tourProvider;
              if (currentProvider != null &&
                  currentProvider.isOnStep(TourStep.recipes)) {
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  try {
                    final finalProvider = _tourProvider;
                    if (finalProvider != null &&
                        finalProvider.isOnStep(TourStep.recipes)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.recipesTabKey]);
                      print(
                          '🎯 PantryPage: Successfully triggered recipes showcase');
                    }
                  } catch (e) {
                    print('🎯 PantryPage: Error starting recipes showcase: $e');
                  }
                });
              } else {
                print(
                    '🎯 PantryPage: Not on recipes step. Current step: ${currentProvider?.currentStep}');
              }
            } catch (e) {
              print('🎯 PantryPage: Error checking recipes step: $e');
            }
          });
        } else {
          print(
              '🎯 PantryPage: Not on removePantryItem step. Current step: ${tourProvider.currentStep}');
        }
      } catch (e) {
        print('🎯 PantryPage: Error in _handleRemoveItemTourProgression: $e');
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initial load
      final controller = context.read<PantryController>();
      // Ensure RouteObserver is obtained here if not already, or in didChangeDependencies
      // This initial load is good, didPopNext will handle subsequent refreshes.
      if (!controller.isLoading) {
        // Avoid multiple loads if already loading
        await controller.loadItems();
      }
    });
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryController = Provider.of<PantryController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Segmented control
              Showcase(
                key: TourKeys.pantryTabToggleKey,
                title: 'Switch FoodRx and Home Items',
                description:
                    'Switch between FoodRx Items and Home Items to manage different types of pantry items.',
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: Colors.white,
                textColor: Colors.black,
                overlayColor: Colors.black54,
                overlayOpacity: 0.8,
                onTargetClick: () {
                  // Don't complete step here - just show the toggle info
                  // The pantry items showcase will complete the step

                  // Dismiss current showcase and trigger pantry items showcase if we're on the right step
                  final tourProvider =
                      Provider.of<ForcedTourProvider>(context, listen: false);
                  if (tourProvider.isOnStep(TourStep.pantryItems)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      try {
                        ShowcaseView.get().dismiss();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!mounted) return;
                          final tp = Provider.of<ForcedTourProvider>(context,
                              listen: false);
                          // Double-check step hasn't changed
                          if (tp.isOnStep(TourStep.pantryItems)) {
                            ShowcaseView.get()
                                .startShowCase([TourKeys.pantryItemsKey]);
                            print(
                                '🎯 PantryPage: Triggered pantry items showcase from toggle');
                          }
                        });
                      } catch (e) {
                        print(
                            '🎯 PantryPage: Error triggering pantry items showcase: $e');
                      }
                    });
                  }
                },
                onToolTipClick: () {
                  final tourProvider =
                      Provider.of<ForcedTourProvider>(context, listen: false);
                  if (tourProvider.isOnStep(TourStep.pantryItems)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      try {
                        ShowcaseView.get().dismiss();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (!mounted) return;
                          final tp = Provider.of<ForcedTourProvider>(context,
                              listen: false);
                          // Double-check step hasn't changed
                          if (tp.isOnStep(TourStep.pantryItems)) {
                            ShowcaseView.get()
                                .startShowCase([TourKeys.pantryItemsKey]);
                            print(
                                '🎯 PantryPage: Triggered pantry items showcase from toggle tooltip');
                          }
                        });
                      } catch (e) {
                        print(
                            '🎯 PantryPage: Error triggering pantry items showcase: $e');
                      }
                    });
                  }
                },
                disposeOnTap: true,
                child: Builder(
                  builder: (context) {
                    final textScaleFactor =
                        MediaQuery.textScaleFactorOf(context);
                    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                    return Container(
                      height: 46 * clampedScale.clamp(1.0, 1.1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedTabIndex = 0);
                                // Clear search when switching tabs
                                pantryController.clearFilters();
                                _searchController.clear();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 0
                                      ? const Color(0xFFFF6A00)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Builder(
                                    builder: (context) {
                                      final textScaleFactor =
                                          MediaQuery.textScaleFactorOf(context);
                                      final clampedScale =
                                          textScaleFactor.clamp(0.8, 1.0);
                                      return Text(
                                        'FoodRx Items',
                                        style: TextStyle(
                                          fontSize: 16 * clampedScale,
                                          fontWeight: FontWeight.w500,
                                          color: _selectedTabIndex == 0
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedTabIndex = 1);
                                // Clear search when switching tabs
                                pantryController.clearFilters();
                                _searchController.clear();
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _selectedTabIndex == 1
                                      ? const Color(0xFFFF6A00)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Builder(
                                    builder: (context) {
                                      final textScaleFactor =
                                          MediaQuery.textScaleFactorOf(context);
                                      final clampedScale =
                                          textScaleFactor.clamp(0.8, 1.0);
                                      return Text(
                                        'Home Items',
                                        style: TextStyle(
                                          fontSize: 16 * clampedScale,
                                          fontWeight: FontWeight.w500,
                                          color: _selectedTabIndex == 1
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AppSearchField(
                  controller: _searchController,
                  hintText: 'Search ingredients...',
                  onChanged: (value) {
                    pantryController.updateSearchQuery(value);
                  },
                ),
              ),

              // Category filter chips
              CategoryFilterChips(
                categories: pantryController
                    .getAvailableCategories(_selectedTabIndex == 0),
                selectedCategory: pantryController.selectedCategory,
                onCategorySelected: (category) {
                  pantryController.updateSelectedCategory(category);
                },
                isLoading: pantryController.isLoading,
              ),

              // Content
              Expanded(
                child: _selectedTabIndex == 0
                    ? _buildPantryItemsContent(pantryController)
                    : _buildOtherItemsContent(pantryController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPantryItemsContent(PantryController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
      );
    }

    if (controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${controller.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.loadItems(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!controller.hasPantryItems) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                return Text(
                  'Your FoodRx Items list is Empty. Add items to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16 * clampedScale,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: 20),
            _buildAddButton('Add FoodRx Items', () {
              // Show action sheet to add pantry items
              _showAddActionSheet();
            }),
          ],
        ),
      );
    }

    // Check if filtered results are empty
    if (controller.filteredPantryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                return Text(
                  controller.searchQuery.isNotEmpty ||
                          controller.selectedCategory != null
                      ? 'No items found matching your search'
                      : 'No pantry items available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16 * clampedScale,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            if (controller.searchQuery.isNotEmpty ||
                controller.selectedCategory != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  controller.clearFilters();
                  _searchController.clear();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    // When there are items, show the filtered list
    return Showcase(
      key: TourKeys.pantryItemsKey,
      title: 'Your Pantry Items',
      description:
          'Here you can see all the food items you\'ve added to your pantry. You can filter by category and manage your inventory.',
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

        // Only complete if we're on the pantryItems step
        if (tourProvider.isOnStep(TourStep.pantryItems)) {
          tourProvider.completeCurrentStep();

          // Trigger remove item showcase after completing pantryItems step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              try {
                final tp =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tp.isOnStep(TourStep.removePantryItem)) {
                  ShowcaseView.get().dismiss();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final tp2 =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    if (tp2.isOnStep(TourStep.removePantryItem)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.removePantryItemKey]);
                    }
                  });
                } else if (tp.isOnStep(TourStep.recipes)) {
                  ShowcaseView.get().dismiss();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final tp2 =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    if (tp2.isOnStep(TourStep.recipes)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.recipesTabKey]);
                    }
                  });
                }
              } catch (e) {
                print('Error triggering next showcase: $e');
              }
            });
          });
        }
      },
      onToolTipClick: () {
        final tourProvider =
            Provider.of<ForcedTourProvider>(context, listen: false);

        if (tourProvider.isOnStep(TourStep.pantryItems)) {
          tourProvider.completeCurrentStep();

          // Trigger remove item showcase after completing pantryItems step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              try {
                final tp =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tp.isOnStep(TourStep.removePantryItem)) {
                  ShowcaseView.get().dismiss();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final tp2 =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    if (tp2.isOnStep(TourStep.removePantryItem)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.removePantryItemKey]);
                    }
                  });
                } else if (tp.isOnStep(TourStep.recipes)) {
                  ShowcaseView.get().dismiss();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final tp2 =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    if (tp2.isOnStep(TourStep.recipes)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.recipesTabKey]);
                    }
                  });
                }
              } catch (e) {
                print('Error triggering next showcase: $e');
              }
            });
          });
        }
      },
      disposeOnTap: false,
      child: Consumer<ForcedTourProvider>(
        builder: (context, tourProvider, child) {
          final isRemoveStep = tourProvider.isOnStep(TourStep.removePantryItem);

          return ListView.builder(
            itemCount: controller.filteredPantryItems.length,
            itemBuilder: (context, index) {
              final item = controller.filteredPantryItems[index];
              final isFirstItem = index == 0;

              // Wrap first item with showcase during removePantryItem step
              if (isRemoveStep && isFirstItem) {
                return _SwipeDemoItem(
                  item: item,
                  parentContext:
                      context, // Pass parent context for removing item
                  onSwipeComplete: () {
                    // Handle tour progression using parent widget's method
                    // No context needed - uses stored provider reference
                    _handleRemoveItemTourProgression();
                  },
                );
              }

              return _buildPantryItemTile(item);
            },
          );
        },
      ),
    );
  }

  Widget _buildOtherItemsContent(PantryController controller) {
    if (controller.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
      );
    }

    if (controller.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${controller.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.loadItems(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!controller.hasOtherItems) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(
              builder: (context) {
                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                return Text(
                  'Your Home Items list is empty. Add what you have at home or bought from grocery store.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16 * clampedScale,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: 20),
            _buildAddButton('Add Home Items', () {
              // Show action sheet to add home items
              _showAddActionSheet();
            }),
          ],
        ),
      );
    }

    // Check if filtered results are empty
    if (controller.filteredOtherItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                return Text(
                  controller.searchQuery.isNotEmpty ||
                          controller.selectedCategory != null
                      ? 'No items found matching your search'
                      : 'No other items available',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16 * clampedScale,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            if (controller.searchQuery.isNotEmpty ||
                controller.selectedCategory != null) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  controller.clearFilters();
                  _searchController.clear();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    // When there are items, show the filtered list
    return ListView.builder(
      itemCount: controller.filteredOtherItems.length,
      itemBuilder: (context, index) {
        final item = controller.filteredOtherItems[index];
        return _buildPantryItemTile(item);
      },
    );
  }

  Widget _buildPantryItemTile(PantryItem item, {bool isRemoveStep = false}) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5275),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          'assets/icons/trash.svg',
          width: 28,
          height: 28,
        ),
      ),
      onDismissed: (_) {
        final tourProvider =
            Provider.of<ForcedTourProvider>(context, listen: false);

        // If we're on the remove step, complete it after dismissing
        if (isRemoveStep && tourProvider.isOnStep(TourStep.removePantryItem)) {
          tourProvider.completeCurrentStep();

          // Trigger recipes tab showcase after a delay
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              try {
                final tp =
                    Provider.of<ForcedTourProvider>(context, listen: false);
                if (tp.isOnStep(TourStep.recipes)) {
                  ShowcaseView.get().dismiss();
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (!mounted) return;
                    final tp2 =
                        Provider.of<ForcedTourProvider>(context, listen: false);
                    if (tp2.isOnStep(TourStep.recipes)) {
                      ShowcaseView.get()
                          .startShowCase([TourKeys.recipesTabKey]);
                    }
                  });
                }
              } catch (e) {
                print(
                    '🎯 PantryPage: Error triggering recipes tab showcase: $e');
              }
            });
          });
        }

        context.read<PantryController>().removeItem(item.id, item.isPantryItem);
      },
      child: GestureDetector(
        onTap: () => _showEditItemDialog(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Item image
              IngredientImage(
                imageUrl: item.imageUrl,
                width: 64,
                height: 64,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              // Item details
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Builder(
                    builder: (context) {
                      final textScaleFactor =
                          MediaQuery.textScaleFactorOf(context);
                      final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16 * clampedScale,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getExpiryText(item.expiryDate),
                            style: TextStyle(
                              fontSize: 14 * clampedScale,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // Qty tag
              Builder(
                builder: (context) {
                  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                  final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * clampedScale,
                      vertical: 6 * clampedScale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.quantityDisplay,
                      style: TextStyle(
                        fontSize: 13 * clampedScale,
                        color: const Color(0xFFFF6A00),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getExpiryText(DateTime? expiryDate) {
    if (expiryDate == null) return '';
    final days = expiryDate.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires Today';
    if (days == 1) return 'Expires Tomorrow';
    if (days > 30) {
      final months = days ~/ 30;
      return 'Expires in $months Month${months > 1 ? 's' : ''}';
    }
    return 'Expires in $days Day${days != 1 ? 's' : ''}';
  }

  Widget _buildAddButton(String label, VoidCallback onTap) {
    return Builder(
      builder: (context) {
        final textScaleFactor = MediaQuery.textScaleFactorOf(context);
        final clampedScale = textScaleFactor.clamp(0.8, 1.0);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 24 * clampedScale,
              vertical: 12 * clampedScale,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFEEFE4),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add,
                  color: const Color(0xFFFF6A00),
                  size: 20 * clampedScale,
                ),
                SizedBox(width: 8 * clampedScale),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: const Color(0xFFFF6A00),
                      fontWeight: FontWeight.w500,
                      fontSize: 14 * clampedScale,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddActionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddActionSheet(),
    );
  }

  void _showEditItemDialog(PantryItem item) {
    final qtyController = TextEditingController(text: item.quantity.toString());
    DateTime selectedDate = item.expiryDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                  final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                  return Text(
                    'Edit ${item.name}',
                    style: TextStyle(
                      fontSize: 20 * clampedScale,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.unitLabel})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                  final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                  return Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Expiration Date:',
                          style: TextStyle(fontSize: 16 * clampedScale),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 12 * clampedScale),
                      Flexible(
                        child: TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate.isBefore(DateTime.now())
                                  ? DateTime.now()
                                  : selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365 * 5)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFFF6A00),
                                      onPrimary: Colors.white,
                                      surface: Colors.white,
                                      onSurface: Color(0xFF2C2C2C),
                                      onSurfaceVariant: Colors.white,
                                    ),
                                    datePickerTheme: DatePickerThemeData(
                                      backgroundColor: Colors.white,
                                      headerBackgroundColor: Colors.white,
                                      headerForegroundColor: Color(0xFF2C2C2C),
                                      weekdayStyle: TextStyle(
                                        color: Color(0xFF8E8E93),
                                      ),
                                      dayStyle: TextStyle(
                                        color: Color(0xFF2C2C2C),
                                      ),
                                      cancelButtonStyle: TextButton.styleFrom(
                                        foregroundColor: Color(0xFFFF6A00),
                                      ),
                                      confirmButtonStyle: TextButton.styleFrom(
                                        foregroundColor: Color(0xFFFF6A00),
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null && mounted) {
                              // Check mounted before setState
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF6A00),
                                fontSize: 14 * clampedScale,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF6A00),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                    ),
                    onPressed: () {
                      // Get the quantity value and validate it
                      double qty = 1.0;
                      try {
                        qty = double.parse(qtyController.text);
                      } catch (_) {}

                      // Update the item in the controller
                      final updatedItem = item.copyWith(
                        quantity: qty,
                        expirationDate: selectedDate,
                        // unit: selectedUnit, // If you add unit editing
                      );
                      context
                          .read<PantryController>()
                          .updateItem(updatedItem); // Changed to updateItem
                      Navigator.pop(context);
                    },
                    child: const Text('Save',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget that demonstrates swipe-to-delete with animation
class _SwipeDemoItem extends StatefulWidget {
  final PantryItem item;
  final VoidCallback onSwipeComplete;
  final BuildContext parentContext; // Store parent context

  const _SwipeDemoItem({
    Key? key,
    required this.item,
    required this.onSwipeComplete,
    required this.parentContext,
  }) : super(key: key);

  @override
  State<_SwipeDemoItem> createState() => _SwipeDemoItemState();
}

class _SwipeDemoItemState extends State<_SwipeDemoItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1.0, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    // Start looping animation after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _startLoopingAnimation();
        }
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startLoopingAnimation() {
    if (_isAnimating) return;
    setState(() {
      _isAnimating = true;
    });

    _animationController.repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-dismiss showcase after 5 seconds so user can swipe immediately
    // This gives them time to read the instructions but then allows interaction
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          try {
            ShowcaseView.get().dismiss();
          } catch (e) {
            // Showcase might already be dismissed
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Detect any pan gesture and dismiss showcase immediately
      onPanStart: (_) {
        try {
          ShowcaseView.get().dismiss();
        } catch (e) {
          // Showcase might already be dismissed
        }
      },
      onPanUpdate: (details) {
        // Also dismiss on pan update (swipe movement)
        try {
          ShowcaseView.get().dismiss();
        } catch (e) {
          // Showcase might already be dismissed
        }
      },
      // Allow gestures to pass through to child
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // The actual interactive item - NOT wrapped by showcase so it's fully interactive
          Stack(
            children: [
              // The real item - fully interactive
              _buildPantryItemTile(widget.item, isRemoveStep: true),
              // Animated demo overlay that shows the swipe gesture (non-interactive)
              // This loops continuously until user swipes
              IgnorePointer(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF6A00),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        IngredientImage(
                          imageUrl: widget.item.imageUrl,
                          width: 64,
                          height: 64,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            bottomLeft: Radius.circular(12),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.item.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.swipe_left,
                                      color: const Color(0xFFFF6A00),
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Swipe left to remove',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Showcase positioned on top but with IgnorePointer so gestures pass through
          // This way it shows the tooltip but doesn't block interaction
          Positioned.fill(
            child: IgnorePointer(
              ignoring:
                  true, // Ignore all pointer events so they pass through to item below
              child: Showcase(
                key: TourKeys.removePantryItemKey,
                title: 'Remove Items',
                description:
                    'To remove an item, swipe from right to left. Watch the animation below, then try swiping left yourself.',
                targetShapeBorder: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                tooltipBackgroundColor: Colors.white,
                tooltipPosition: TooltipPosition.bottom,
                textColor: Colors.black,
                overlayColor: Colors.transparent,
                overlayOpacity: 0.0,
                showArrow: true,
                onTargetClick: () {
                  // Dismiss immediately on any touch
                  ShowcaseView.get().dismiss();
                },
                onToolTipClick: () {
                  // Dismiss immediately on any touch
                  ShowcaseView.get().dismiss();
                },
                onBarrierClick: () {
                  // Dismiss on barrier click (anywhere on overlay)
                  ShowcaseView.get().dismiss();
                },
                disposeOnTap: true,
                child: Container(
                  // Invisible container that matches the item size for highlighting
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantryItemTile(PantryItem item, {bool isRemoveStep = false}) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5275),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          'assets/icons/trash.svg',
          width: 28,
          height: 28,
        ),
      ),
      onDismissed: (_) {
        // Stop animation when item is dismissed
        if (_isAnimating) {
          _animationController.stop();
          _animationController.reset();
          setState(() {
            _isAnimating = false;
          });
        }

        // Dismiss showcase when item is actually swiped
        try {
          ShowcaseView.get().dismiss();
        } catch (e) {
          // Showcase might already be dismissed
        }

        // Remove item from pantry first
        widget.parentContext
            .read<PantryController>()
            .removeItem(item.id, item.isPantryItem);

        // Then handle tour progression using parent context
        // Use a small delay to ensure the widget tree is stable
        Future.microtask(() {
          widget.onSwipeComplete();
        });
      },
      child: GestureDetector(
        onTap: () => _showEditItemDialog(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Item image
              IngredientImage(
                imageUrl: item.imageUrl,
                width: 64,
                height: 64,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              // Item details
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Builder(
                    builder: (context) {
                      final textScaleFactor =
                          MediaQuery.textScaleFactorOf(context);
                      final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16 * clampedScale,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getExpiryText(item.expiryDate),
                            style: TextStyle(
                              fontSize: 14 * clampedScale,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // Qty tag
              Builder(
                builder: (context) {
                  final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                  final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                  return Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10 * clampedScale,
                      vertical: 6 * clampedScale,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.quantityDisplay,
                      style: TextStyle(
                        fontSize: 13 * clampedScale,
                        color: const Color(0xFFFF6A00),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getExpiryText(DateTime? expiryDate) {
    if (expiryDate == null) return '';
    final days = expiryDate.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired';
    if (days == 0) return 'Expires Today';
    if (days == 1) return 'Expires Tomorrow';
    if (days > 30) {
      final months = days ~/ 30;
      return 'Expires in $months Month${months > 1 ? 's' : ''}';
    }
    return 'Expires in $days Day${days != 1 ? 's' : ''}';
  }

  void _showEditItemDialog(PantryItem item) {
    // Same as parent class method
    final qtyController = TextEditingController(text: item.quantity.toString());
    DateTime selectedDate = item.expiryDate ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit ${item.name}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity (${item.unitLabel})',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Expiration Date:'),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate.isBefore(DateTime.now())
                            ? DateTime.now()
                            : selectedDate,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (picked != null && mounted) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: Text(
                      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6A00),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      double qty = 1.0;
                      try {
                        qty = double.parse(qtyController.text);
                      } catch (_) {}

                      final updatedItem = item.copyWith(
                        quantity: qty,
                        expirationDate: selectedDate,
                      );
                      context.read<PantryController>().updateItem(updatedItem);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                    ),
                    child: const Text('Save',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
