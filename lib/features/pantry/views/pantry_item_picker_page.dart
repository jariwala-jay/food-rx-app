import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/widgets/app_scrollbar.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import '../providers/pantry_item_picker_provider.dart';
import 'dart:developer' as developer;
import 'dart:async';

import '../widgets/pantry_item_add_modal.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import '../repositories/ingredient_repository.dart';
import '../controller/pantry_controller.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_app/core/services/ingredient_category_mapper.dart';
import 'package:flutter_app/core/services/ingredient_fuzzy_matcher.dart';
import 'package:showcaseview/showcaseview.dart';

class PantryItemPickerPage extends StatelessWidget {
  final String categoryTitle;
  final String categoryKey;
  final bool isFoodPantryItem;
  final String? initialSearchQuery;
  final bool autoAddOnArrival;

  const PantryItemPickerPage({
    Key? key,
    required this.categoryTitle,
    required this.categoryKey,
    this.isFoodPantryItem = true,
    this.initialSearchQuery,
    this.autoAddOnArrival = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Shared instance so rate-limit backoff state is visible to every screen
    // that searches ingredients, instead of each screen tracking its own.
    final ingredientRepository =
        Provider.of<IngredientRepository>(context, listen: false);
    final authController = Provider.of<AuthController>(context, listen: false);

    return ChangeNotifierProvider(
      create: (_) {
        final provider = PantryItemPickerProvider(
          ingredientRepository,
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
        initialSearchQuery: initialSearchQuery,
        autoAddOnArrival: autoAddOnArrival,
      ),
    );
  }
}

class _PantryItemPickerView extends StatefulWidget {
  final String title;
  final String categoryKey;
  final bool isFoodPantryItem;
  final String? initialSearchQuery;
  final bool autoAddOnArrival;

  const _PantryItemPickerView({
    required this.title,
    required this.categoryKey,
    required this.isFoodPantryItem,
    this.initialSearchQuery,
    this.autoAddOnArrival = false,
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
  bool _didApplyInitialSearch = false;

  // Measured so the empty-state content below can be shifted up by half
  // this height, centering it on the full screen instead of just the
  // leftover space below the search bar (same technique as
  // PantryGroupCategoryPage's _searchBarHeight).
  final GlobalKey _searchBarKey = GlobalKey();
  double _searchBarHeight = 0;

  void _measureSearchBarHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = _searchBarKey.currentContext?.size?.height;
      if (height != null && height != _searchBarHeight) {
        setState(() => _searchBarHeight = height);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    developer.log(
        'PantryItemPickerView initialized for category: ${widget.categoryKey}');
    final initial = widget.initialSearchQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _searchController.text = initial;
      _isSearching = true;
      _isTyping = true;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchTextChanged(String query, PantryItemPickerProvider provider) {
    setState(() {
      _isTyping = query.isNotEmpty;
    });

    // Cancel previous debounce timer
    _debounceTimer?.cancel();

    // Local filtering is instant on every keystroke so curated matches
    // never wait on the API debounce.
    provider.searchItems(query);

    if (query.trim().length < 3) return;

    // Only hit Spoonacular once the user pauses, so "coc" -> "coco" ->
    // "coconut" fires one request instead of one per keystroke.
    _debounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted && _searchController.text == query) {
        provider.searchSpoonacular(query);
      }
    });
  }

  /// Applies a spelling-correction suggestion by fixing the search box
  /// text itself and re-running the normal search — this is a correction
  /// to what the user meant to type, not a different item to add, so it
  /// goes through the exact same path as if they'd typed it correctly
  /// themselves.
  void _applyTypoCorrection(
      PantryItemPickerProvider provider, IngredientSuggestion correction) {
    final name = correction.ingredient.name;
    _searchController.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _onSearchTextChanged(name, provider);
  }

  Future<void> _handleSaveButtonClick(
      BuildContext context,
      PantryItemPickerProvider provider,
      ForcedTourProvider tourProvider) async {
    final success = await provider.saveSelectedItemsToPantry();
    if (!context.mounted) return;

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
                    if (!context.mounted) return;
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
        // Close the whole add flow — not just this search screen. A
        // single pop leaves the category-picker sheet (Fruits/Vegetables/
        // Grains/...) sitting open underneath as an extra screen the user
        // has to dismiss themselves before actually landing back on their
        // tab. This works regardless of how deep the item picker was
        // opened from (direct category, or via the Fruits/Vegetables
        // handoff) since the tab screen is always the first route.
        navigator.popUntil((route) => route.isFirst);
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

  /// One more chance to adjust quantity/unit for an item already staged
  /// for save — tapping its QTY pill in the selected-items list below.
  Future<void> _editSelectedItemQuantity(BuildContext context,
      PantryItemPickerProvider provider, PantryItem item) async {
    final quantityController = TextEditingController(
      text: item.quantity.toStringAsFixed(
          item.quantity.truncateToDouble() == item.quantity ? 0 : 1),
    );
    UnitType selectedUnit = item.unit;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Quantity',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<UnitType>(
                      value: selectedUnit,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87),
                      items: UnitType.values
                          .map((u) => DropdownMenuItem(
                                value: u,
                                child: Text(_unitDisplayName(u)),
                              ))
                          .toList(),
                      onChanged: (u) {
                        if (u != null) setDialogState(() => selectedUnit = u);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A00),
              ),
              onPressed: () {
                final qty = double.tryParse(quantityController.text.trim());
                if (qty == null || qty <= 0) return;
                provider.updateSelectedItemQuantity(item.id, qty, selectedUnit);
                Navigator.of(dialogContext).pop();
              },
              child:
                  const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    quantityController.dispose();
  }

  String _unitDisplayName(UnitType unit) {
    switch (unit) {
      case UnitType.pound:
        return 'Pound (lb)';
      case UnitType.ounces:
        return 'Ounces (oz)';
      case UnitType.gallon:
        return 'Gallon';
      case UnitType.milliliter:
        return 'Milliliter (ml)';
      case UnitType.liter:
        return 'Liter (L)';
      case UnitType.piece:
        return 'Piece';
      case UnitType.grams:
        return 'Grams (g)';
      case UnitType.kilograms:
        return 'Kilograms (kg)';
      case UnitType.cup:
        return 'Cup';
      case UnitType.tablespoon:
        return 'Tablespoon';
      case UnitType.teaspoon:
        return 'Teaspoon';
    }
  }

  /// Lets the user add exactly what they typed, even with no curated or
  /// Spoonacular match — a misspelling or an ingredient outside Spoonacular's
  /// database shouldn't block adding it. Category is resolved the same way
  /// as any other item; we don't try to "correct" the typed name.
  void _addCustomIngredient(BuildContext context, String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final custom = Ingredient(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed,
      image: '',
      imageName: 'default.jpg',
    );
    _showAddItemModal(context, custom);
  }

  /// Adds a "Did you mean?" suggestion via the normal add flow, using its
  /// real curated category directly rather than letting the usual
  /// category-inference logic run — we already know exactly where this
  /// ingredient belongs since it came from our own curated data.
  void _addSuggestedIngredient(
      BuildContext context, IngredientSuggestion suggestion) {
    _showAddItemModal(context, suggestion.ingredient,
        explicitCategory: suggestion.category);
  }

  // Show modal dialog to add quantity and unit
  Future<void> _showAddItemModal(BuildContext context, Ingredient item,
      {String? explicitCategory}) async {
    // Only global-search results need re-filing; curated items already
    // belong to this category (their `aisle` is a FoodRx key, not Spoonacular's).
    // Applies to both FoodRx and Home items — the Home Tracker merges both
    // lists for nutrition logging, so both need an accurate category, not
    // just whichever tab the item happened to be searched from.
    final pickerProvider =
        Provider.of<PantryItemPickerProvider>(context, listen: false);
    String category = widget.categoryKey;
    if (explicitCategory != null) {
      category = explicitCategory;
    } else if (pickerProvider.isShowingGlobalIngredientSearch) {
      // Name matching first — resolves the vast majority of items with no
      // API call. Only fall back to a lazy aisle lookup when the name alone
      // is inconclusive.
      var resolved = IngredientCategoryMapper.resolveCategory(name: item.name);
      if (resolved == IngredientCategoryMapper.miscellaneous) {
        final aisle = await pickerProvider.resolveAisleForAdd(item);
        resolved = IngredientCategoryMapper.resolveCategory(
            name: item.name, aisle: aisle);
      }
      category = resolved;
    }
    if (!context.mounted) return;

    final tourProvider =
        Provider.of<ForcedTourProvider>(context, listen: false);

    // Complete selectCategory step if we're on it (user has chosen an item)
    if (tourProvider.isOnStep(TourStep.selectCategory)) {
      tourProvider.completeCurrentStep();
    }

    // Check if tour is active to determine if modal can be dismissed
    final isTourActive = tourProvider.isTourActive;

    showDialog(
      context: context,
      barrierDismissible: !isTourActive, // Block dismissal during tour
      builder: (dialogContext) => PopScope(
        canPop: !isTourActive, // Block system back during tour
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isTourActive) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please set quantity and tap "Add" to continue'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFFFF6A00),
              ),
            );
          }
        },
        child: PantryItemAddModal(
          foodItem: item.toJson(),
          category: category,
          isFoodPantryItem: widget.isFoodPantryItem,
          onAdd: (pantryItem) {
            final provider = Provider.of<PantryItemPickerProvider>(this.context,
                listen: false);
            provider.addItemToSelection(pantryItem);
          },
        ),
      ),
    );

    // Trigger quantity/unit showcase after modal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!context.mounted) return;
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
    _measureSearchBarHeight();

    // Two distinct offline suggestions, only meaningful once the search
    // has actually come up empty; recomputed each build is fine since
    // both are pure, local lookups against the curated list, never a
    // network call. Kept separate rather than one combined signal:
    //  - relatedSuggestion: a different, recognizable ingredient the
    //    query is describing ("pickled onions" -> "Onions") — offered as
    //    "Did you mean?", a suggestion to add *instead*.
    //  - typoCorrection: a spelling fix for what was typed ("cocnut" ->
    //    "Coconut Oil") — offered as a "search instead for X?" prompt
    //    near the search field, to fix the query itself, not to replace
    //    what gets added.
    final hasEmptyResults = _isTyping &&
        _searchController.text.trim().isNotEmpty &&
        provider.searchResults.isEmpty;
    final relatedSuggestion = hasEmptyResults
        ? IngredientFuzzyMatcher.findRelatedSuggestion(
            _searchController.text,
            isFoodPantryItem: widget.isFoodPantryItem,
            isExcluded: provider.isAllergyConflict,
          )
        : null;
    final typoCorrection = hasEmptyResults
        ? IngredientFuzzyMatcher.findTypoCorrection(
            _searchController.text,
            isFoodPantryItem: widget.isFoodPantryItem,
            isExcluded: provider.isAllergyConflict,
          )
        : null;

    developer.log('Building PantryItemPickerView for ${widget.categoryKey}, '
        'isLoading: ${provider.isLoading}, '
        'hasError: ${provider.error != null}, '
        'itemCount: ${provider.searchResults.length}, '
        'selectedItems: ${provider.selectedItemsList.length}');

    return Consumer<ForcedTourProvider>(
        builder: (context, tourProvider, child) {
      // Apply deep-link search from Fruits/Vegetables group search.
      if (!_didApplyInitialSearch &&
          widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.trim().isNotEmpty &&
          !provider.isLoading &&
          provider.hasInitialized) {
        _didApplyInitialSearch = true;
        final q = widget.initialSearchQuery!.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          // Prefer in-category curated match; only go global if none found.
          provider.searchItems(q);
          if (q.length >= 3 && provider.searchResults.isEmpty) {
            await provider.searchSpoonacular(q);
          }
          if (!context.mounted || !widget.autoAddOnArrival) return;

          // Arrived here already having tapped "Add" or a suggestion on
          // the previous screen (Fruits/Vegetables group page) — opening
          // the add modal again automatically avoids making the user
          // repeat that tap on this screen for a search that already
          // told them there was nothing else to pick from.
          Ingredient? exactMatch;
          for (final item in provider.searchResults) {
            if (item.name.toLowerCase() == q.toLowerCase()) {
              exactMatch = item;
              break;
            }
          }
          if (exactMatch != null) {
            _showAddItemModal(context, exactMatch);
          } else if (!provider.isAllergyConflict(q)) {
            _addCustomIngredient(context, q);
          }
        });
      }

      // Check if we're in the middle of tour steps that use this page
      final isTourItemFlow = tourProvider.isTourActive &&
          (tourProvider.isOnStep(TourStep.selectCategory) ||
              tourProvider.isOnStep(TourStep.selectItem) ||
              tourProvider.isOnStep(TourStep.setQuantityUnit) ||
              tourProvider.isOnStep(TourStep.saveItem));

      return PopScope(
        canPop: !isTourItemFlow, // Block system back gesture during tour
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && isTourItemFlow) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please complete the tour step first'),
                duration: Duration(seconds: 2),
                backgroundColor: Color(0xFFFF6A00),
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.black),
              onPressed: () {
                if (isTourItemFlow) {
                  // Block back navigation during tour
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
            ),
            title: Text(
              provider.isShowingGlobalIngredientSearch
                  ? 'Search Results'
                  : widget.title,
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
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: Column(
              children: [
                if (_isSearching)
                  Padding(
                    key: _searchBarKey,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) =>
                          _onSearchTextChanged(query, provider),
                      decoration: InputDecoration(
                        hintText: provider.isShowingGlobalIngredientSearch
                            ? 'Search all ingredients...'
                            : 'Search in ${widget.title}...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _isTyping
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear, color: Colors.grey),
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
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      autofocus: true,
                    ),
                  ),
                if (provider.isShowingGlobalIngredientSearch &&
                    _isTyping &&
                    !provider.isLoading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4EB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFD7B8)),
                      ),
                      child: Text(
                        '"${_searchController.text}" not found in ${widget.title}.\n'
                        'Showing results from all ingredients.',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                if (provider.isLoading)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFFF6A00)),
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
                            onPressed: () =>
                                provider.loadItems(widget.categoryKey),
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
                    child: Transform.translate(
                      // Centers on the full screen instead of just the
                      // space left over below the search bar.
                      offset: Offset(0, -_searchBarHeight / 2),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isTyping
                                  ? (provider.isRateLimitedSearch
                                      ? 'Search is temporarily unavailable.'
                                      : provider.isEmptyDueToAllergyFilter
                                          ? "Results matching your allergies or foods you avoid aren't shown."
                                          : 'No match for "${_searchController.text.trim()}"')
                                  : 'No ingredients available in this category',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            // Add-as-typed is the primary action here — it
                            // always works and preserves exactly what the
                            // user entered, regardless of whether a
                            // suggestion below happens to exist. Never
                            // offered when the typed text itself conflicts
                            // with an allergy/exclusion (checked directly,
                            // not via isEmptyDueToAllergyFilter, so a short
                            // query that never reached Spoonacular is still
                            // caught).
                            if (_isTyping &&
                                _searchController.text.trim().isNotEmpty &&
                                !provider.isAllergyConflict(
                                    _searchController.text.trim()))
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 16, 24, 0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _addCustomIngredient(
                                        context, _searchController.text),
                                    icon: const Icon(Icons.add,
                                        color: primaryColor),
                                    label: Text(
                                      'Add "${_searchController.text.trim()}"',
                                      style:
                                          const TextStyle(color: primaryColor),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side:
                                          const BorderSide(color: primaryColor),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // One secondary, lighter-weight suggestion below
                            // Add — never both at once. relatedSuggestion
                            // ("Did you mean?") takes priority since it's a
                            // suggestion to add something else entirely;
                            // typoCorrection ("Search instead for?") only
                            // shows when there's no related item, since it's
                            // just a fix to the search text itself. If both
                            // happen to resolve to the same curated
                            // ingredient (e.g. "tomatoe" -> "Tomatoes" via
                            // both), show only the typo correction — it's
                            // the more direct explanation, and showing both
                            // would just repeat the same name twice.
                            if (relatedSuggestion != null &&
                                !IngredientFuzzyMatcher.sameIngredient(
                                    relatedSuggestion, typoCorrection))
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: GestureDetector(
                                  onTap: () => _addSuggestedIngredient(
                                      context, relatedSuggestion),
                                  child: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                      children: [
                                        const TextSpan(text: 'Did you mean '),
                                        TextSpan(
                                          text:
                                              relatedSuggestion.ingredient.name,
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(text: '?'),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else if (typoCorrection != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: GestureDetector(
                                  onTap: () => _applyTypoCorrection(
                                      provider, typoCorrection),
                                  child: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold),
                                      children: [
                                        const TextSpan(
                                            text: 'Search instead for '),
                                        TextSpan(
                                          text: typoCorrection.ingredient.name,
                                          style: const TextStyle(
                                            color: primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const TextSpan(text: '?'),
                                      ],
                                    ),
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
                              provider.isShowingGlobalIngredientSearch
                                  ? 'All ingredients for "${_searchController.text}" (${provider.searchResults.length})'
                                  : 'Results for "${_searchController.text}" (${provider.searchResults.length})',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        if (_isTyping &&
                            _searchController.text.trim().isNotEmpty &&
                            !provider.isAllergyConflict(
                                _searchController.text.trim()) &&
                            !provider.searchResults.any((r) =>
                                r.name.toLowerCase() ==
                                _searchController.text.trim().toLowerCase()))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: GestureDetector(
                              onTap: () => _addCustomIngredient(
                                  context, _searchController.text),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: primaryColor),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add,
                                        color: primaryColor, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add "${_searchController.text.trim()}"',
                                      style: const TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (provider.searchResults.isNotEmpty)
                          Expanded(
                            child: Consumer<ForcedTourProvider>(
                              builder: (context, tourProvider, child) {
                                // Check if we're on tour and in fresh_fruits category
                                final isTourStep = tourProvider
                                    .isOnStep(TourStep.selectCategory);
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
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    if (_scrollController.hasClients &&
                                        mounted) {
                                      _hasScrolledToApple = true;
                                      _scrollController.animateTo(
                                        0.0, // Scroll to top to show first item
                                        duration:
                                            const Duration(milliseconds: 500),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  });
                                }

                                return AppScrollbar(
                                  controller: _scrollController,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 16),
                                    itemCount: provider.searchResults.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final item =
                                          provider.searchResults[index];
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
                                        key: shouldHighlight
                                            ? _appleItemKey
                                            : null,
                                        decoration: BoxDecoration(
                                          color: shouldHighlight
                                              ? const Color(0xFFFFF3EB)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: shouldHighlight
                                              ? Border.all(
                                                  color:
                                                      const Color(0xFFFF6A00),
                                                  width: 2,
                                                )
                                              : null,
                                        ),
                                        child: ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 6,
                                          ),
                                          leading: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: CachedNetworkImageWidget(
                                              imageUrl: item.displayImageUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              fallbackIcon: Icons.food_bank,
                                              fallbackIconColor:
                                                  const Color(0xFFFF6A00),
                                              fallbackBackgroundColor:
                                                  const Color(0xFFEEEEEE),
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
                                                      const EdgeInsets.only(
                                                          top: 4),
                                                  child: Text(
                                                    selectedItem!
                                                        .quantityDisplay,
                                                    style: const TextStyle(
                                                      color: Color(0xFFFF6A00),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                )
                                              : shouldHighlight
                                                  ? const Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 4),
                                                      child: Text(
                                                        'Tap + to add (example)',
                                                        style: TextStyle(
                                                          color:
                                                              Color(0xFFFF6A00),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    )
                                                  : null,
                                          trailing: isSelected
                                              ? IconButton(
                                                  icon: const Icon(
                                                      Icons
                                                          .remove_circle_outline,
                                                      color: Color(0xFFFF6A00)),
                                                  onPressed: () => provider
                                                      .removeItemFromSelection(
                                                          itemId),
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
                                                          : const Color(
                                                              0xFFFF6A00),
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
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

                // Selected items summary — shown regardless of whether an
                // item still appears in the current search results, since a
                // custom/typo'd add never does (it has no search match to
                // show a tile for). Otherwise the Save button below appears
                // with no visible confirmation of what it's about to save.
                if (provider.hasSelectedItems)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 160),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: provider.selectedItemsList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = provider.selectedItemsList[index];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2C2C2C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _editSelectedItemQuantity(
                                      context, provider, item),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3EB),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.quantityDisplay,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      provider.removeItemFromSelection(item.id),
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Colors.grey),
                                  padding: const EdgeInsets.only(left: 4),
                                  constraints: const BoxConstraints(),
                                  splashRadius: 16,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Save button at the bottom
                if (provider.hasSelectedItems)
                  Consumer<ForcedTourProvider>(
                    builder: (context, tourProvider, child) {
                      final isSaveStep =
                          tourProvider.isOnStep(TourStep.saveItem);

                      // Trigger showcase when Save button appears during tour
                      if (isSaveStep && !_hasTriggeredSaveShowcase) {
                        _hasTriggeredSaveShowcase = true;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!context.mounted) return;
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (!context.mounted) return;
                            try {
                              final tp = Provider.of<ForcedTourProvider>(
                                  context,
                                  listen: false);
                              if (tp.isOnStep(TourStep.saveItem)) {
                                ShowcaseView.get().startShowCase(
                                    [TourKeys.saveItemButtonKey]);
                              } else {
                                _hasTriggeredSaveShowcase =
                                    false; // Reset if step changed
                              }
                            } catch (e) {
                              print('Error triggering saveItem showcase: $e');
                              _hasTriggeredSaveShowcase =
                                  false; // Reset on error
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
                          key: isSaveStep
                              ? TourKeys.saveItemButtonKey
                              : GlobalKey(),
                          title: 'Save Item',
                          description: TourDescriptions.saveItem,
                          targetShapeBorder: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          tooltipBackgroundColor:
                              TourTooltipStyle.tooltipBackgroundColor,
                          tooltipPosition: TooltipPosition.top,
                          textColor: TourTooltipStyle.textColor,
                          overlayColor: TourTooltipStyle.overlayColor,
                          overlayOpacity: TourTooltipStyle.overlayOpacity,
                          toolTipMargin: TourTooltipStyle.toolTipMargin,
                          titleTextStyle: TourTooltipStyle.titleStyle,
                          descTextStyle: TourTooltipStyle.descriptionStyle,
                          showArrow: true,
                          onTargetClick: () {
                            // Handle click directly - trigger Save button
                            ShowcaseView.get().dismiss();
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
                              if (!context.mounted) return;
                              // Directly trigger the button's onPressed
                              _handleSaveButtonClick(
                                  context, provider, tourProvider);
                            });
                          },
                          onToolTipClick: () {
                            // Handle click directly - trigger Save button
                            ShowcaseView.get().dismiss();
                            Future.delayed(const Duration(milliseconds: 100),
                                () {
                              if (!context.mounted) return;
                              // Directly trigger the button's onPressed
                              _handleSaveButtonClick(
                                  context, provider, tourProvider);
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
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
          ),
        ),
      );
    });
  }
}

// Example usage (to be replaced with real navigation and data):
final mockFreshFruits = [];
