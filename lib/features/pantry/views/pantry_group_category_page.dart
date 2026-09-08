import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/constants/tour_constants.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/core/services/ingredient_fuzzy_matcher.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/home/providers/forced_tour_provider.dart';
import 'package:flutter_app/features/pantry/repositories/ingredient_repository.dart';
import 'package:flutter_app/features/pantry/repositories/spoonacular_ingredient_repository.dart';
import 'package:flutter_app/features/pantry/views/pantry_item_picker_page.dart';
import 'package:flutter_app/features/pantry/widgets/pantry_category_icon.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

/// Fruits / Vegetables landing: search across storage types + Fresh / Frozen / Canned.
class PantryGroupCategoryPage extends StatefulWidget {
  final String groupTitle;
  final String groupKey;
  final bool isFoodPantryItem;

  const PantryGroupCategoryPage({
    Key? key,
    required this.groupTitle,
    required this.groupKey,
    this.isFoodPantryItem = true,
  }) : super(key: key);

  @override
  State<PantryGroupCategoryPage> createState() =>
      _PantryGroupCategoryPageState();
}

class _PantryGroupCategoryPageState extends State<PantryGroupCategoryPage> {
  final TextEditingController _searchController = TextEditingController();
  // Resolved from the shared app-wide Provider in initState so rate-limit
  // backoff state is shared with every other screen that searches
  // ingredients, instead of each screen tracking its own.
  late final SpoonacularIngredientRepository _ingredientRepository;
  Timer? _debounceTimer;
  String _query = '';
  bool _hasStartedFreshShowcase = false;
  bool _isGlobalSearching = false;
  bool _showingGlobalResults = false;
  bool _isRateLimited = false;
  bool _isEmptyDueToAllergyFilter = false;
  List<Ingredient> _globalResults = const [];

  // Measured so the empty-state message below can be shifted up by half
  // this height, centering it on the full screen instead of just the
  // Expanded area left over below the search bar.
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
    final repository =
        Provider.of<IngredientRepository>(context, listen: false);
    _ingredientRepository = repository is SpoonacularIngredientRepository
        ? repository
        : SpoonacularIngredientRepository();
  }

  bool _isAllergyItemName(String itemName) {
    final currentUser =
        Provider.of<AuthController>(context, listen: false).currentUser;
    return AllergyFilteringService.itemNameConflictsWithUser(
      itemName,
      currentUser,
    );
  }

  List<Map<String, String>> get _subcategories =>
      foodPantrySubcategories[widget.groupKey] ?? const [];

  Map<String, String> get _defaultStorageSub => _subcategories.isNotEmpty
      ? _subcategories.first
      : {
          'title': 'Fresh',
          'key': widget.groupKey == 'fruits' ? 'fresh_fruits' : 'fresh_veggies',
        };

  /// Flattened curated items tagged with their storage category key.
  List<_GroupedIngredient> get _allGroupedItems {
    final results = <_GroupedIngredient>[];
    for (final sub in _subcategories) {
      final key = sub['key']!;
      final storageLabel = sub['title']!;
      final items = getCommonItemsForCategory(key, widget.isFoodPantryItem);
      for (final itemData in items) {
        final asset = itemData['imageAsset'] as String?;
        results.add(
          _GroupedIngredient(
            storageKey: key,
            storageLabel: storageLabel,
            ingredient: Ingredient(
              id: itemData['id']?.toString() ?? '',
              name: itemData['name'] ?? '',
              image: itemData['imageUrl'] ?? '',
              imageName: asset != null
                  ? 'default.jpg'
                  : (itemData['imageUrl']?.split('/').last ?? 'default.jpg'),
              aisle: key,
              localAssetPath: asset,
            ),
          ),
        );
      }
    }
    return results
        .where((g) => !_isAllergyItemName(g.ingredient.name))
        .toList();
  }

  List<_GroupedIngredient> get _filteredItems {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _allGroupedItems
        .where((g) => g.ingredient.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runGlobalSearchIfNeeded(String query) async {
    final q = query.trim();
    if (q.length < 3) {
      if (_showingGlobalResults ||
          _globalResults.isNotEmpty ||
          _isGlobalSearching) {
        setState(() {
          _showingGlobalResults = false;
          _globalResults = const [];
          _isGlobalSearching = false;
          _isRateLimited = false;
          _isEmptyDueToAllergyFilter = false;
        });
      }
      return;
    }

    // Local curated hits take priority — no Spoonacular call.
    final local = _allGroupedItems
        .where((g) => g.ingredient.name.toLowerCase().contains(q.toLowerCase()))
        .toList();
    if (local.isNotEmpty) {
      if (_showingGlobalResults ||
          _globalResults.isNotEmpty ||
          _isGlobalSearching) {
        setState(() {
          _showingGlobalResults = false;
          _globalResults = const [];
          _isGlobalSearching = false;
          _isRateLimited = false;
          _isEmptyDueToAllergyFilter = false;
        });
      }
      return;
    }

    setState(() {
      _isGlobalSearching = true;
      _showingGlobalResults = true;
      _globalResults = const [];
      _isRateLimited = false;
      _isEmptyDueToAllergyFilter = false;
    });

    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      final allergies = auth.currentUser?.allergies ?? const <String>[];
      final intolerances =
          AllergyFilteringService.intoleranceApiNamesFor(allergies);

      var results = await _ingredientRepository.searchIngredients(
        query: q,
        number: 20,
        intolerances: intolerances,
      );
      // `intolerances` only covers Spoonacular's fixed categories; custom
      // "other" allergies (and derivatives like "applesauce") need this
      // local re-check too — same fix as PantryItemPickerProvider.
      var hadAllergyFilteredResults = false;
      var beforeFilterCount = results.length;
      results = results.where((r) => !_isAllergyItemName(r.name)).toList();
      if (results.length != beforeFilterCount) hadAllergyFilteredResults = true;
      final rateLimitedAfterSearch = _ingredientRepository.isRateLimited;
      if (results.isEmpty && !rateLimitedAfterSearch) {
        results = await _ingredientRepository.autocompleteIngredient(query: q);
        beforeFilterCount = results.length;
        results = results.where((r) => !_isAllergyItemName(r.name)).toList();
        if (results.length != beforeFilterCount)
          hadAllergyFilteredResults = true;
      }
      final rateLimited =
          rateLimitedAfterSearch || _ingredientRepository.isRateLimited;

      if (!mounted || _searchController.text.trim() != q) return;
      setState(() {
        _globalResults = results;
        _isGlobalSearching = false;
        _showingGlobalResults = true;
        _isRateLimited = results.isEmpty && rateLimited;
        _isEmptyDueToAllergyFilter =
            results.isEmpty && !_isRateLimited && hadAllergyFilteredResults;
      });
    } catch (_) {
      if (!mounted || _searchController.text.trim() != q) return;
      setState(() {
        _globalResults = const [];
        _isGlobalSearching = false;
        _showingGlobalResults = true;
      });
    }
  }

  void _onQueryChanged(String value) {
    _debounceTimer?.cancel();
    setState(() => _query = value);
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _runGlobalSearchIfNeeded(value);
    });
  }

  /// Applies a spelling-correction suggestion by fixing the search box
  /// text itself and re-running the normal search — this is a correction
  /// to what the user meant to type, not a different item to add, so it
  /// goes through the exact same path as if they'd typed it correctly
  /// themselves.
  void _applyTypoCorrection(IngredientSuggestion correction) {
    final name = correction.ingredient.name;
    _searchController.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    _onQueryChanged(name);
  }

  void _openStorageType(Map<String, String> sub) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: '${sub['title']} ${widget.groupTitle}',
          categoryKey: sub['key']!,
          isFoodPantryItem: widget.isFoodPantryItem,
        ),
      ),
    );
  }

  void _openItemInStorage(_GroupedIngredient grouped) {
    final sub = _subcategories.firstWhere(
      (s) => s['key'] == grouped.storageKey,
      orElse: () => {
        'title': grouped.storageLabel,
        'key': grouped.storageKey,
      },
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: '${sub['title']} ${widget.groupTitle}',
          categoryKey: grouped.storageKey,
          isFoodPantryItem: widget.isFoodPantryItem,
          initialSearchQuery: grouped.ingredient.name,
        ),
      ),
    );
  }

  void _openGlobalItem(Ingredient ingredient) {
    final sub = _defaultStorageSub;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: '${sub['title']} ${widget.groupTitle}',
          categoryKey: sub['key']!,
          isFoodPantryItem: widget.isFoodPantryItem,
          initialSearchQuery: ingredient.name,
        ),
      ),
    );
  }

  /// Display title for an arbitrary curated category key — a "Did you
  /// mean?" suggestion can belong to any category, not just the current
  /// group's own subcategories (e.g. suggesting a seasoning while
  /// browsing Vegetables), so this isn't limited to `_subcategories`.
  String _categoryTitleForKey(String key) {
    for (final cat in foodPantryCategories) {
      if (cat['key'] == key) return cat['title']!;
    }
    for (final subs in foodPantrySubcategories.values) {
      for (final sub in subs) {
        if (sub['key'] == key) return sub['title']!;
      }
    }
    for (final cat in otherPantryItemCategories) {
      if (cat['key'] == key) return cat['title']!;
    }
    return key;
  }

  /// Opens a "Did you mean?" suggestion through the normal item-picker add
  /// flow, targeting its actual curated category directly (which may well
  /// differ from this group's own domain) rather than reusing the current
  /// screen's category. Auto-opens the add modal on arrival — the user
  /// already chose to add this by tapping the suggestion here, so making
  /// them tap it again on the next screen would just repeat the same
  /// action.
  void _openSuggestedIngredient(IngredientSuggestion suggestion) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: _categoryTitleForKey(suggestion.category),
          categoryKey: suggestion.category,
          isFoodPantryItem: widget.isFoodPantryItem,
          initialSearchQuery: suggestion.ingredient.name,
          autoAddOnArrival: true,
        ),
      ),
    );
  }

  /// Lets the user carry a typed name (misspelled or outside Spoonacular's
  /// database) into the item picker, where it can be added directly even
  /// with no curated or API match — see `_addCustomIngredient` there.
  /// Auto-opens the add modal on arrival — the user already tapped "Add"
  /// here, so a second tap on the next screen would just repeat it.
  void _openCustomItemSearch(String query) {
    final sub = _defaultStorageSub;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PantryItemPickerPage(
          categoryTitle: '${sub['title']} ${widget.groupTitle}',
          categoryKey: sub['key']!,
          isFoodPantryItem: widget.isFoodPantryItem,
          initialSearchQuery: query,
          autoAddOnArrival: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF6A00);
    final showingSearch = _query.trim().isNotEmpty;
    _measureSearchBarHeight();

    return Consumer<ForcedTourProvider>(
      builder: (context, tourProvider, _) {
        final isTourCategory = tourProvider.isTourActive &&
            tourProvider.isOnStep(TourStep.selectCategory);

        // After opening Fruits during tour, spotlight Fresh.
        if (isTourCategory &&
            widget.groupKey == 'fruits' &&
            !_hasStartedFreshShowcase) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _hasStartedFreshShowcase) return;
            _hasStartedFreshShowcase = true;
            try {
              ShowcaseView.get()
                  .startShowCase([TourKeys.pantryFreshStorageKey]);
            } catch (_) {}
          });
        }

        return PopScope(
          canPop: !isTourCategory,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && isTourCategory) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Please complete the tour step first - tap on "Fresh"'),
                  duration: Duration(seconds: 2),
                  backgroundColor: primaryColor,
                ),
              );
            }
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.black, size: 20),
                onPressed: () {
                  if (isTourCategory) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Please complete the tour step first - tap on "Fresh"'),
                        duration: Duration(seconds: 2),
                        backgroundColor: primaryColor,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).pop();
                },
              ),
              title: Text(
                widget.groupTitle,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Padding(
                    key: _searchBarKey,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      enabled: !isTourCategory,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText:
                            'Search ${widget.groupTitle.toLowerCase()}...',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _debounceTimer?.cancel();
                                  _searchController.clear();
                                  setState(() {
                                    _query = '';
                                    _showingGlobalResults = false;
                                    _globalResults = const [];
                                    _isGlobalSearching = false;
                                    _isRateLimited = false;
                                    _isEmptyDueToAllergyFilter = false;
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: showingSearch
                        ? _buildSearchResults(primaryColor)
                        : _buildStorageList(tourProvider, isTourCategory),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStorageList(
      ForcedTourProvider tourProvider, bool isTourCategory) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
      itemCount: _subcategories.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final sub = _subcategories[index];
        final isFresh =
            sub['key'] == 'fresh_fruits' || sub['key'] == 'fresh_veggies';
        final shouldHighlight =
            isTourCategory && widget.groupKey == 'fruits' && isFresh;

        final tile = ListTile(
          tileColor: shouldHighlight ? const Color(0xFFFFF3EB) : null,
          shape: shouldHighlight
              ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFFF6A00), width: 2),
                )
              : null,
          leading: PantryCategoryIcon(assetPath: sub['icon']!),
          title: Text(
            sub['title']!,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: shouldHighlight ? const Color(0xFFFF6A00) : Colors.black,
            ),
          ),
          subtitle: widget.isFoodPantryItem
              ? Text(
                  sub['subtitle']!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                )
              : null,
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: shouldHighlight ? const Color(0xFFFF6A00) : Colors.grey,
          ),
          onTap: () {
            if (isTourCategory && widget.groupKey == 'fruits' && !isFresh) {
              return;
            }
            if (shouldHighlight) {
              try {
                ShowcaseView.get().dismiss();
              } catch (_) {}
            }
            _openStorageType(sub);
          },
        );

        if (shouldHighlight) {
          return Showcase(
            key: TourKeys.pantryFreshStorageKey,
            title: 'Choose Fresh',
            description: TourDescriptions.selectFreshStorage,
            targetShapeBorder: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            tooltipBackgroundColor: TourTooltipStyle.tooltipBackgroundColor,
            tooltipPosition: TooltipPosition.bottom,
            textColor: TourTooltipStyle.textColor,
            overlayColor: TourTooltipStyle.overlayColor,
            overlayOpacity: TourTooltipStyle.overlayOpacity,
            toolTipMargin: TourTooltipStyle.toolTipMargin,
            titleTextStyle: TourTooltipStyle.titleStyle,
            descTextStyle: TourTooltipStyle.descriptionStyle,
            showArrow: true,
            disposeOnTap: false,
            onTargetClick: () {
              ShowcaseView.get().dismiss();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _openStorageType(sub);
              });
            },
            onToolTipClick: () {
              ShowcaseView.get().dismiss();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (!mounted) return;
                _openStorageType(sub);
              });
            },
            child: tile,
          );
        }

        return tile;
      },
    );
  }

  Widget _buildSearchResults(Color primaryColor) {
    final localResults = _filteredItems;

    if (localResults.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        itemCount: localResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final grouped = localResults[index];
          final item = grouped.ingredient;
          return ListTile(
            leading: CachedNetworkImageWidget(
              imageUrl: item.displayImageUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(8),
            ),
            title: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
            ),
            subtitle: Text(
              grouped.storageLabel,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing:
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            onTap: () => _openItemInStorage(grouped),
          );
        },
      );
    }

    if (_isGlobalSearching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6A00)),
        ),
      );
    }

    if (_showingGlobalResults && _globalResults.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD7B8)),
              ),
              child: Text(
                '"$_query" not found in ${widget.groupTitle}.\n'
                'Showing results from all ingredients.',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
              itemCount: _globalResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _globalResults[index];
                return ListTile(
                  leading: CachedNetworkImageWidget(
                    imageUrl: item.displayImageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'All ingredients',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Colors.grey),
                  onTap: () => _openGlobalItem(item),
                );
              },
            ),
          ),
        ],
      );
    }

    final waitingForGlobal =
        _query.trim().length >= 3 && !_showingGlobalResults;
    final trimmedQuery = _query.trim();

    // Two distinct offline suggestions, only meaningful once the search
    // has actually come up empty; recomputed each build is fine since
    // both are pure, local lookups against the curated list, never a
    // network call. See IngredientFuzzyMatcher's doc comment for why
    // these stay separate: relatedSuggestion is a different, recognizable
    // ingredient ("pickled onions" -> "Onions"); typoCorrection is a
    // spelling fix for the query itself ("cocnut" -> "Coconut Oil").
    final canSuggest = !waitingForGlobal && trimmedQuery.isNotEmpty;
    final relatedSuggestion = canSuggest
        ? IngredientFuzzyMatcher.findRelatedSuggestion(
            trimmedQuery,
            isFoodPantryItem: widget.isFoodPantryItem,
            isExcluded: _isAllergyItemName,
          )
        : null;
    final typoCorrection = canSuggest
        ? IngredientFuzzyMatcher.findTypoCorrection(
            trimmedQuery,
            isFoodPantryItem: widget.isFoodPantryItem,
            isExcluded: _isAllergyItemName,
          )
        : null;

    return Center(
      child: Transform.translate(
        // Centers on the full screen instead of just the space left over
        // below the search bar (see `_searchBarHeight`).
        offset: Offset(0, -_searchBarHeight / 2),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                waitingForGlobal
                    ? 'Searching all ingredients...'
                    : _query.trim().length < 3
                        ? 'Type at least 3 characters to search all ingredients'
                        : _isRateLimited
                            ? 'Search is temporarily unavailable.'
                            : _isEmptyDueToAllergyFilter
                                ? "Results matching your allergies or foods you avoid aren't shown."
                                : 'No match for "$trimmedQuery"',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              // Add-as-typed is the primary action here — it always works
              // and preserves exactly what the user entered, regardless of
              // whether a suggestion below happens to exist. Never offered
              // when the typed text itself conflicts with an
              // allergy/exclusion — checked directly (not via
              // _isEmptyDueToAllergyFilter, which only reflects a search
              // that actually ran a network call) so a short query never
              // slips past.
              if (!waitingForGlobal &&
                  trimmedQuery.isNotEmpty &&
                  !_isAllergyItemName(trimmedQuery))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: OutlinedButton.icon(
                    onPressed: () => _openCustomItemSearch(trimmedQuery),
                    icon: Icon(Icons.add, color: primaryColor),
                    label: Text(
                      'Add "$trimmedQuery"',
                      style: TextStyle(color: primaryColor),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              // One secondary, lighter-weight suggestion below Add — never
              // both at once. relatedSuggestion ("Did you mean?") takes
              // priority since it's a suggestion to add something else
              // entirely; typoCorrection ("Search instead for?") only
              // shows when there's no related item, since it's just a fix
              // to the search text itself. If both happen to resolve to
              // the same curated ingredient (e.g. "tomatoe" -> "Tomatoes"
              // via both), show only the typo correction — it's the more
              // direct explanation, and showing both would just repeat
              // the same name twice.
              if (relatedSuggestion != null &&
                  !IngredientFuzzyMatcher.sameIngredient(
                      relatedSuggestion, typoCorrection))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: GestureDetector(
                    onTap: () => _openSuggestedIngredient(relatedSuggestion),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        children: [
                          const TextSpan(text: 'Did you mean '),
                          TextSpan(
                            text: relatedSuggestion.ingredient.name,
                            style: const TextStyle(
                              color: Color(0xFFFF6A00),
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
                    onTap: () => _applyTypoCorrection(typoCorrection),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                        children: [
                          const TextSpan(text: 'Search instead for '),
                          TextSpan(
                            text: typoCorrection.ingredient.name,
                            style: const TextStyle(
                              color: Color(0xFFFF6A00),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: '?'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupedIngredient {
  final String storageKey;
  final String storageLabel;
  final Ingredient ingredient;

  const _GroupedIngredient({
    required this.storageKey,
    required this.storageLabel,
    required this.ingredient,
  });
}
