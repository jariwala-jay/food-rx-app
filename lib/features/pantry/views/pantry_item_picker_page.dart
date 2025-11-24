import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/pantry_item_picker_provider.dart';
import 'dart:developer' as developer;
import 'dart:async';

import '../widgets/pantry_item_add_modal.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import '../repositories/spoonacular_ingredient_repository.dart';
import '../controller/pantry_controller.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:showcaseview/showcaseview.dart';

class PantryItemPickerPage extends StatelessWidget {
  final String categoryTitle;
  final String categoryKey;
  final bool isFoodPantryItem;

  const PantryItemPickerPage({
    Key? key,
    required this.categoryTitle,
    required this.categoryKey,
    this.isFoodPantryItem = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ingredientRepository = SpoonacularIngredientRepository();
    final mongoDBService = MongoDBService();
    final authController = Provider.of<AuthController>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) {
        final provider = PantryItemPickerProvider(
          ingredientRepository,
          mongoDBService,
          authController,
          isFoodPantryItem: isFoodPantryItem,
        );
        Future.microtask(() => provider.loadItems(categoryKey));
        return provider;
      },
      child: _PantryItemPickerView(
        title: categoryTitle,
        categoryKey: categoryKey,
        isFoodPantryItem: isFoodPantryItem,
      ),
    );
  }
}

class _PantryItemPickerView extends StatefulWidget {
  final String title;
  final String categoryKey;
  final bool isFoodPantryItem;

  const _PantryItemPickerView({
    required this.title,
    required this.categoryKey,
    required this.isFoodPantryItem,
  });
  @override
  State<_PantryItemPickerView> createState() => _PantryItemPickerViewState();
}

class _PantryItemPickerViewState extends State<_PantryItemPickerView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isTyping = false;
  Timer? _debounceTimer;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _appleItemKey = GlobalKey();
  bool _hasScrolledToApple = false;
  bool _hasTriggeredSaveShowcase = false;

  @override
  void initState() {
    super.initState();
    developer.log(
        'PantryItemPickerView initialized for category: ${widget.categoryKey}');
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveButtonClick(
      BuildContext context,
      PantryItemPickerProvider provider,
      ForcedTourProvider tourProvider) async {
    final success = await provider.saveSelectedItemsToPantry();
    if (!mounted) return;

    // Store context before async operations to avoid linter warnings
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tp = Provider.of<ForcedTourProvider>(context, listen: false);

    if (success) {
      // Refresh the pantry controller to show new items
      try {
        final pantryController =
            Provider.of<PantryController>(context, listen: false);
        await pantryController.refreshItems();
      } catch (e) {
        developer.log('Failed to refresh pantry controller: $e');
      }

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Items added to your pantry'),
          backgroundColor: Colors.green,
        ),
      );

      // Complete saveItem step if we're on it (during tour)
      if (tp.isOnStep(TourStep.saveItem)) {
        tp.completeCurrentStep();

        // Close the page and modal automatically during tour
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            // Pop item picker page
            navigator.pop();

            // Pop category picker modal
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                navigator.pop();

                // Trigger pantry items showcase after closing
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (!mounted) return;
                    try {
                      final tp2 = Provider.of<ForcedTourProvider>(context,
                          listen: false);
                      if (tp2.isOnStep(TourStep.pantryItems)) {
                        ShowcaseView.get()
                            .startShowCase([TourKeys.pantryItemsKey]);
                      }
                    } catch (e) {
                      print('Error triggering pantry items showcase: $e');
                    }
                  });
                });
              }
            });
          }
        });
      } else {
        // Normal behavior - just pop back
        navigator.pop();
      }
    } else {
      if (provider.error != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to save items: ${provider.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show modal dialog to add quantity and unit
  void _showAddItemModal(BuildContext context, Ingredient item) {
    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    // Complete selectCategory step if we're on it (user has chosen an item)
    if (tourProvider.isOnStep(TourStep.selectCategory)) {
      tourProvider.completeCurrentStep();
    }

    showDialog(
      context: context,
      builder: (dialogContext) => PantryItemAddModal(
        foodItem: item.toJson(),
        category: widget.categoryKey,
        isFoodPantryItem: widget.isFoodPantryItem,
        onAdd: (pantryItem) {
          final provider = Provider.of<PantryItemPickerProvider>(this.context,
              listen: false);
          provider.addItemToSelection(pantryItem);
        },
      ),
    );

    // Trigger quantity/unit showcase after modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        try {
          final tp = Provider.of<ForcedTourProvider>(context, listen: false);
          if (tp.isOnStep(TourStep.setQuantityUnit)) {
            ShowcaseView.get().startShowCase([TourKeys.quantityUnitKey]);
          }
        } catch (e) {
          print('Error triggering quantityUnit showcase: $e');
        }
      });
    });

    // After adding item, trigger save button showcase if on saveItem step
    // This will be triggered when the Save button appears (hasSelectedItems becomes true)
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PantryItemPickerProvider>(context);
    const primaryColor = Color(0xFFFF6A00);

    developer.log('Building PantryItemPickerView for ${widget.categoryKey}, '
        'isLoading: ${provider.isLoading}, '
        'hasError: ${provider.error != null}, '
        'itemCount: ${provider.searchResults.length}, '
        'selectedItems: ${provider.selectedItemsList.length}');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search,
                color: Colors.black),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _isTyping = false;
                if (!_isSearching) {
                  _searchController.clear();
                  provider.searchItems('');
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                onChanged: (query) {
                  setState(() {
                    _isTyping = query.isNotEmpty;
                  });

                  // Cancel previous debounce timer
                  _debounceTimer?.cancel();

                  // If query is empty, search locally immediately
                  if (query.isEmpty) {
                    provider.searchItems(query);
                    return;
                  }

                  // For short queries, use local search only
                  if (query.length < 3) {
                    provider.searchItems(query);
                    return;
                  }

                  // Debounce API calls: wait 500ms after user stops typing
                  _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                    if (mounted && _searchController.text == query) {
                      provider.searchSpoonacular(query);
                    }
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.title}...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _isTyping
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            provider.searchItems('');
                            setState(() {
                              _isTyping = false;
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                autofocus: true,
              ),
            ),
          if (provider.isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading ingredients...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (provider.error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadItems(widget.categoryKey),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      child: const Text('Retry',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            )
          else if (provider.searchResults.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _isTyping
                          ? 'No ingredients found for "${_searchController.text}"'
                          : 'No ingredients available in this category',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_isTyping)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextButton(
                          onPressed: () {
                            _searchController.clear();
                            provider.searchItems('');
                            setState(() {
                              _isTyping = false;
                            });
                          },
                          child: const Text(
                            'Clear search',
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                    if (!_isTyping && !provider.hasInitialized)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ElevatedButton(
                          onPressed: () =>
                              provider.loadItems(widget.categoryKey),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                          ),
                          child: const Text('Load Ingredients',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isTyping && _searchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Results for "${_searchController.text}" (${provider.searchResults.length})',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (provider.searchResults.isNotEmpty)
                    Expanded(
                      child: Consumer<ForcedTourProvider>(
                        builder: (context, tourProvider, child) {
                          // Check if we're on tour and in fresh_fruits category
                          final isTourStep =
                              tourProvider.isOnStep(TourStep.selectCategory);
                          final isFreshFruits =
                              widget.categoryKey == 'fresh_fruits';
                          final isTourInFreshFruits =
                              isTourStep && isFreshFruits;

                          // Use first item (index 0) for tour demo - it will always be apples in fresh_fruits
                          final firstItemIndex = isTourInFreshFruits &&
                                  provider.searchResults.isNotEmpty
                              ? 0
                              : null;

                          // Scroll to first item when items load during tour
                          if (isTourInFreshFruits &&
                              firstItemIndex != null &&
                              !_hasScrolledToApple) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_scrollController.hasClients && mounted) {
                                _hasScrolledToApple = true;
                                _scrollController.animateTo(
                                  0.0, // Scroll to top to show first item
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                );
                              }
                            });
                          }

                          return ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            itemCount: provider.searchResults.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = provider.searchResults[index];
                              final itemId = item.id.toString();
                              final isSelected =
                                  provider.isItemSelected(itemId);
                              final selectedItem = isSelected
                                  ? provider.getSelectedItem(itemId)
                                  : null;

                              // Check if this is the first item during tour (for demo)
                              final isFirstItem = index == 0;
                              final shouldHighlight =
                                  isTourInFreshFruits && isFirstItem;
                              final isOnlyAllowedItem =
                                  isTourInFreshFruits && !isFirstItem;

                              return Container(
                                key: shouldHighlight ? _appleItemKey : null,
                                decoration: BoxDecoration(
                                  color: shouldHighlight
                                      ? const Color(0xFFFFF3EB)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: shouldHighlight
                                      ? Border.all(
                                          color: const Color(0xFFFF6A00),
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: item.imageUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      memCacheWidth: 100,
                                      memCacheHeight: 100,
                                      placeholder: (context, url) => Container(
                                        width: 50,
                                        height: 50,
                                        color: const Color(0xFFEEEEEE),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Color(0xFFFF6A00)),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEEEEE),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.food_bank,
                                          color: Color(0xFFFF6A00),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: shouldHighlight
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 16,
                                      color: shouldHighlight
                                          ? const Color(0xFFFF6A00)
                                          : Colors.black,
                                    ),
                                  ),
                                  subtitle: isSelected
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            selectedItem!.quantityDisplay,
                                            style: const TextStyle(
                                              color: Color(0xFFFF6A00),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        )
                                      : shouldHighlight
                                          ? const Padding(
                                              padding: EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Tap + to add (example)',
                                                style: TextStyle(
                                                  color: Color(0xFFFF6A00),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            )
                                          : null,
                                  trailing: isSelected
                                      ? IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Color(0xFFFF6A00)),
                                          onPressed: () => provider
                                              .removeItemFromSelection(itemId),
                                        )
                                      : GestureDetector(
                                          onTap: isOnlyAllowedItem
                                              ? null
                                              : () => _showAddItemModal(
                                                  context, item),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: isOnlyAllowedItem
                                                  ? Colors.grey
                                                  : const Color(0xFFFF6A00),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              color: isOnlyAllowedItem
                                                  ? Colors.grey[400]
                                                  : Colors.white,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

          // Save button at the bottom
          if (provider.hasSelectedItems)
            Consumer<ForcedTourProvider>(
              builder: (context, tourProvider, child) {
                final isSaveStep = tourProvider.isOnStep(TourStep.saveItem);

                // Trigger showcase when Save button appears during tour
                if (isSaveStep && !_hasTriggeredSaveShowcase) {
                  _hasTriggeredSaveShowcase = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (!mounted) return;
                      try {
                        final tp = Provider.of<ForcedTourProvider>(context,
                            listen: false);
                        if (tp.isOnStep(TourStep.saveItem)) {
                          ShowcaseView.get()
                              .startShowCase([TourKeys.saveItemButtonKey]);
                        } else {
                          _hasTriggeredSaveShowcase =
                              false; // Reset if step changed
                        }
                      } catch (e) {
                        print('Error triggering saveItem showcase: $e');
                        _hasTriggeredSaveShowcase = false; // Reset on error
                      }
                    });
                  });
                } else if (!isSaveStep) {
                  _hasTriggeredSaveShowcase =
                      false; // Reset when not on save step
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Showcase(
                    key: isSaveStep ? TourKeys.saveItemButtonKey : GlobalKey(),
                    title: 'Save Item',
                    description:
                        'Now tap the \'Save\' button to add this item to your pantry. You MUST click the Save button to continue.',
                    targetShapeBorder: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    tooltipBackgroundColor: Colors.white,
                    tooltipPosition: TooltipPosition.top,
                    textColor: Colors.black,
                    overlayColor: Colors.black54,
                    overlayOpacity: 0.8,
                    showArrow: true,
                    onTargetClick: () {
                      // Handle click directly - trigger Save button
                      ShowcaseView.get().dismiss();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (!mounted) return;
                        // Directly trigger the button's onPressed
                        final buttonKey = GlobalKey();
                        // Find the button and trigger it
                        _handleSaveButtonClick(context, provider, tourProvider);
                      });
                    },
                    onToolTipClick: () {
                      // Handle click directly - trigger Save button
                      ShowcaseView.get().dismiss();
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (!mounted) return;
                        // Directly trigger the button's onPressed
                        _handleSaveButtonClick(context, provider, tourProvider);
                      });
                    },
                    disposeOnTap: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _handleSaveButtonClick(
                              context, provider, tourProvider);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Example usage (to be replaced with real navigation and data):
final mockFreshFruits = [];
