import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_app/core/models/excluded_ingredient.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/core/services/ingredient_category_mapper.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';

class PantryTrackerLoggingModal extends StatefulWidget {
  final TrackerGoal tracker;
  final Function(double) onLog;

  const PantryTrackerLoggingModal({
    Key? key,
    required this.tracker,
    required this.onLog,
  }) : super(key: key);

  @override
  State<PantryTrackerLoggingModal> createState() =>
      _PantryTrackerLoggingModalState();
}

class _PantryTrackerLoggingModalState extends State<PantryTrackerLoggingModal> {
  // Tab selection: 0 = Quick Log, 1 = From Pantry
  int _selectedTab = 0;

  // Manual entry state
  late TextEditingController _manualValueController;
  double _manualValue = 0.0;

  // Pantry selection state
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _pantryListScrollController = ScrollController();
  List<PantryItem> _filteredItems = [];
  final Map<String, double> _selectedServings = {};

  /// Ids of pantry/home items that conflict with the user's allergies or
  /// excluded ingredients, computed once per pantry load rather than on
  /// every search keystroke — neither the pantry contents nor the user's
  /// restrictions change while this modal's search field is being typed
  /// into.
  Set<String> _allergyConflictItemIds = {};

  // Shared state
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _manualValueController = TextEditingController(text: '0');
    _refreshAllergyConflicts();
    _filterItems();
  }

  @override
  void dispose() {
    _manualValueController.dispose();
    _searchController.dispose();
    _pantryListScrollController.dispose();
    super.dispose();
  }

  /// Fixed list viewport height for Quick Log / From Pantry tabs (220 or 260).
  double get _pantryListHeight {
    // 260 for empty list or more than two items; 220 for one–two items.
    if (_filteredItems.isEmpty) return 260.0;
    return _filteredItems.length <= 2 ? 220.0 : 260.0;
  }

  /// [_pantryListHeight] plus 64px search bar row.
  double get _tabContentHeight => 64.0 + _pantryListHeight;

  // ==================== MANUAL ENTRY METHODS ====================

  void _incrementManualValue() {
    setState(() {
      _manualValue += 0.5;
      _manualValueController.text = _formatValue(_manualValue);
    });
  }

  void _decrementManualValue() {
    if (_manualValue > 0) {
      setState(() {
        _manualValue = (_manualValue - 0.5).clamp(0, double.infinity);
        _manualValueController.text = _formatValue(_manualValue);
      });
    }
  }

  Future<void> _handleManualLog() async {
    if (_isLoading) return;

    if (_manualValue <= 0) {
      setState(() {
        _error = 'Please enter a value greater than 0';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.onLog(_manualValue);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = userFacingErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==================== PANTRY METHODS ====================

  List<PantryItem> _allPantryAndHomeItems() {
    final pantryController =
        Provider.of<PantryController>(context, listen: false);
    return [...pantryController.pantryItems, ...pantryController.otherItems];
  }

  /// Recomputes [_allergyConflictItemIds] from the current pantry/home items
  /// and the user's current restrictions. Called once up front rather than
  /// per keystroke -- see the field doc.
  void _refreshAllergyConflicts() {
    _allergyConflictItemIds = _allPantryAndHomeItems()
        .where(_conflictsWithAllergies)
        .map((item) => item.id)
        .toSet();
  }

  /// Filters to items matching the tracker category, the (optional) search
  /// [query], and not in [_allergyConflictItemIds].
  void _filterItems([String query = '']) {
    final normalizedQuery = query.toLowerCase();
    _filteredItems = _allPantryAndHomeItems().where((item) {
      final matchesCategory =
          _itemMatchesCategory(item, widget.tracker.category);
      final matchesSearch = normalizedQuery.isEmpty ||
          item.name.toLowerCase().contains(normalizedQuery);
      return matchesCategory &&
          matchesSearch &&
          !_allergyConflictItemIds.contains(item.id);
    }).toList();

    setState(() {});
  }

  /// Excludes items the user is allergic to (or has listed as avoided) from
  /// being loggable here, mirroring the pantry-add and recipe-search checks.
  bool _conflictsWithAllergies(PantryItem item) {
    final currentUser =
        Provider.of<AuthController>(context, listen: false).currentUser;
    return AllergyFilteringService.itemNameConflictsWithUser(
      item.name,
      currentUser,
    );
  }

  bool _itemMatchesCategory(PantryItem item, TrackerCategory category) {
    // Sweets has no clean pantry-category equivalent — sugar/honey/chocolate/
    // cake/cookie items are filed under the grab-bag 'seasonings' (FoodRx) or
    // 'snacks_beverages' (Home) pantry buckets. Keep the legacy name-keyword
    // check as a deliberate, scoped exception.
    if (category == TrackerCategory.sweets) {
      return _matchesSweetsKeyword(item);
    }

    // Eggs are curated under the pantry's 'dairy' bucket, but have only ever
    // shown under Log Protein/Lean Meat (never Log Dairy) — preserve that
    // exactly via an explicit override rather than letting the resolved
    // category move them.
    if (_isEggItem(item)) {
      return category == TrackerCategory.protein ||
          category == TrackerCategory.leanMeat;
    }

    final pantryCategoryKey = _resolvedPantryCategoryKey(item);
    return _trackerCategoriesForPantryCategoryKey(pantryCategoryKey)
        .contains(category);
  }

  /// The pantry-category key to classify by: the item's own stored `category`
  /// when recognized, else a fresh derivation from its name via the same
  /// mapper used at add-time. Covers legacy items stuck at 'miscellaneous'/
  /// 'General' without a data migration, and self-heals as the mapper
  /// improves.
  String _resolvedPantryCategoryKey(PantryItem item) {
    if (_recognizedPantryCategoryKeys.contains(item.category)) {
      return item.category;
    }
    return IngredientCategoryMapper.resolveCategory(name: item.name);
  }

  static const Set<String> _recognizedPantryCategoryKeys = {
    'fresh_fruits', 'frozen_fruits', 'canned_fruits',
    'fresh_veggies', 'frozen_veggies', 'canned_veggies',
    'grains', 'meat', 'protein', 'beans', 'dairy', 'nuts_seeds', 'seasonings',
  };

  /// Maps a resolved FoodRx pantry-category key to the TrackerCategory
  /// value(s) it's loggable under. Not 1:1 — 'beans' intentionally maps to
  /// veggies AND protein/leanMeat AND nutsLegumes: USDA MyPlate guidance
  /// allows legumes to count toward either the vegetable or protein group,
  /// and DASH shows leanMeat+nutsLegumes as separate trackers while MyPlate
  /// has no nutsLegumes tracker at all — so beans must stay reachable
  /// regardless of diet plan.
  Set<TrackerCategory> _trackerCategoriesForPantryCategoryKey(String key) {
    switch (key) {
      case 'fresh_fruits':
      case 'frozen_fruits':
      case 'canned_fruits':
        return const {TrackerCategory.fruits};
      case 'fresh_veggies':
      case 'frozen_veggies':
      case 'canned_veggies':
        return const {TrackerCategory.veggies};
      case 'grains':
        return const {TrackerCategory.grains};
      case 'meat':
      case 'protein': // legacy FoodRx key
        return const {TrackerCategory.protein, TrackerCategory.leanMeat};
      case 'beans':
        return const {
          TrackerCategory.veggies,
          TrackerCategory.protein,
          TrackerCategory.leanMeat,
          TrackerCategory.nutsLegumes,
        };
      case 'dairy':
        return const {TrackerCategory.dairy};
      case 'nuts_seeds':
        return const {TrackerCategory.nutsLegumes};
      default: // seasonings, snacks_beverages, miscellaneous, General, ...
        return const {};
    }
  }

  bool _isEggItem(PantryItem item) {
    final words = ExcludedIngredient.normalize(item.name).split(' ');
    return words.contains('egg') || words.contains('eggs');
  }

  bool _matchesSweetsKeyword(PantryItem item) {
    const keywords = [
      'sugar', 'honey', 'chocolate', 'candy', 'cookie', 'cake', 'dessert'
    ];
    final normalizedItemName = ExcludedIngredient.normalize(item.name);
    return keywords.any((keyword) =>
        normalizedItemName.contains(ExcludedIngredient.normalize(keyword)));
  }

  void _addServing(String itemId) {
    final matchingItems = _filteredItems.where((item) => item.id == itemId);
    if (matchingItems.isEmpty) {
      // Item fell out of the filtered list (removed from pantry, or no
      // longer matches the current search/allergy filter) between being
      // rendered and being tapped -- drop any stale selection instead of
      // crashing with "Bad state: No element".
      setState(() {
        _selectedServings.remove(itemId);
      });
      return;
    }
    final item = matchingItems.first;
    final currentServings = _selectedServings[itemId] ?? 0;
    final maxServings = _getMaxServingsAvailable(item);

    if (currentServings < maxServings) {
      setState(() {
        _selectedServings[itemId] = currentServings + 1;
      });
    }
  }

  void _removeServing(String itemId) {
    setState(() {
      if (_selectedServings[itemId] != null && _selectedServings[itemId]! > 0) {
        _selectedServings[itemId] = _selectedServings[itemId]! - 1;
        if (_selectedServings[itemId] == 0) {
          _selectedServings.remove(itemId);
        }
      }
    });
  }

  /// Calculate the maximum servings available based on pantry quantity
  double _getMaxServingsAvailable(PantryItem item) {
    try {
      final conversionService = UnitConversionService();
      final dietServingService =
          DietServingService(conversionService: conversionService);

      // Get the serving definition for this category
      final servingDefinition = dietServingService.getServingDefinition(
        category: widget.tracker.category,
        dietType: widget.tracker.dietType,
      );

      if (servingDefinition == null) {
        // If no serving definition, assume 1:1 ratio
        return item.quantity;
      }

      final canonicalAmount = servingDefinition['canonical_amount'] as double;
      final canonicalUnit = servingDefinition['canonical_unit'] as String;

      // Convert pantry quantity to canonical unit. Uses the confidence-
      // reporting variant, not the legacy `convert()`, which returns the
      // original unconverted amount (not 0.0) when no conversion path
      // exists — checking for a literal 0.0 result would silently miss
      // that failure and divide a bogus number by canonicalAmount.
      final conversionResult = conversionService.convertWithConfidence(
        amount: item.quantity,
        fromUnit: item.unitLabel,
        toUnit: canonicalUnit,
        ingredientName: item.name,
      );

      // If conversion failed, assume 1:1 ratio
      if (conversionResult['conversionPath'] == 'failed') {
        return item.quantity;
      }

      // Calculate max servings: pantry quantity ÷ canonical amount per serving
      final pantryQuantityInCanonicalUnit = conversionResult['amount'] as double;
      return pantryQuantityInCanonicalUnit / canonicalAmount;
    } catch (e) {
      // Fallback to pantry quantity if calculation fails
      return item.quantity;
    }
  }

  /// Calculate the actual physical amount to deduct from pantry for the given servings
  double _calculatePhysicalAmountForServings({
    required DietServingService dietServingService,
    required PantryItem item,
    required double servings,
  }) {
    // Get the serving definition for this category
    final servingDefinition = dietServingService.getServingDefinition(
      category: widget.tracker.category,
      dietType: widget.tracker.dietType,
    );

    if (servingDefinition == null) {
      // If no serving definition, assume 1:1 ratio
      return servings;
    }

    final canonicalAmount = servingDefinition['canonical_amount'] as double;
    final canonicalUnit = servingDefinition['canonical_unit'] as String;

    // Calculate physical amount in canonical unit: servings × canonicalAmount
    final physicalAmountInCanonicalUnit = servings * canonicalAmount;

    // Convert from canonical unit to pantry item's unit. Uses the
    // confidence-reporting variant, not the legacy `convert()`, which
    // returns the original unconverted amount (not 0.0) when no conversion
    // path exists — checking for a literal 0.0 result would silently miss
    // that failure and display the un-converted canonical-unit amount as
    // if it were already in the pantry item's unit.
    final conversionService = UnitConversionService();
    final conversionResult = conversionService.convertWithConfidence(
      amount: physicalAmountInCanonicalUnit,
      fromUnit: canonicalUnit,
      toUnit: item.unitLabel,
      ingredientName: item.name,
    );

    // If conversion failed, assume 1:1 ratio
    if (conversionResult['conversionPath'] == 'failed') {
      return servings;
    }

    return conversionResult['amount'] as double;
  }

  /// Get the text showing what amount will be deducted
  String _getDeductionAmountText(PantryItem item, double servings) {
    try {
      final conversionService = UnitConversionService();
      final dietServingService =
          DietServingService(conversionService: conversionService);

      final actualAmount = _calculatePhysicalAmountForServings(
        dietServingService: dietServingService,
        item: item,
        servings: servings,
      );

      return '${_formatQuantity(actualAmount)} ${item.unitLabel}';
    } catch (e) {
      return '${_formatQuantity(servings)} ${item.unitLabel}';
    }
  }

  Future<void> _logFromPantry() async {
    if (_selectedServings.isEmpty) {
      setState(() {
        _error = 'Please select at least one item to log';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pantryController =
          Provider.of<PantryController>(context, listen: false);
      final conversionService = UnitConversionService();
      final dietServingService =
          DietServingService(conversionService: conversionService);
      final substitutionService =
          IngredientSubstitutionService(conversionService: conversionService);
      final pantryDeductionService = PantryDeductionService(
        conversionService: conversionService,
        substitutionService: substitutionService,
      );

      double totalServingsLogged = 0.0;
      final itemsToDeduct = <Map<String, dynamic>>[];
      String? staleItemId;

      // Calculate servings for each selected item
      for (final entry in _selectedServings.entries) {
        final itemId = entry.key;
        final servings = entry.value;

        final matchingItems =
            _filteredItems.where((item) => item.id == itemId);
        if (matchingItems.isEmpty) {
          // Selected item is no longer in the pantry list (e.g. it was
          // removed, or the search/allergy filter changed) -- don't crash
          // with "Bad state: No element"; abort the submit below instead
          // of logging a partial/wrong amount.
          staleItemId = itemId;
          break;
        }
        final item = matchingItems.first;

        // Calculate the actual physical amount to deduct from pantry
        final actualAmountToDeduct = _calculatePhysicalAmountForServings(
          dietServingService: dietServingService,
          item: item,
          servings: servings,
        );

        // The tracker servings should equal the user-selected servings
        totalServingsLogged += servings;

        // Prepare for pantry deduction with actual physical amount
        itemsToDeduct.add({
          'name': item.name,
          'amount': actualAmountToDeduct,
          'unit': item.unitLabel,
        });
      }

      if (staleItemId != null) {
        _selectedServings.remove(staleItemId);
        setState(() {
          _error =
              'One of your selected items is no longer available. Please review your selection and try again.';
        });
        _filterItems(_searchController.text);
        return;
      }

      // Deduct from pantry
      final deductionResult =
          await pantryDeductionService.deductIngredientsFromPantry(
        scaledIngredients: itemsToDeduct,
        pantryItems: [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ],
      );

      // Update pantry items
      for (final updatedItem in deductionResult.updatedItems) {
        await pantryController.updateItem(updatedItem);
      }

      // Remove items that are now empty
      for (final itemId in deductionResult.itemsToRemove) {
        final matchingItems = [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ].where((item) => item.id == itemId);
        if (matchingItems.isEmpty) {
          // Already removed by a concurrent update; nothing left to do.
          continue;
        }
        await pantryController.removeItem(
            itemId, matchingItems.first.isPantryItem);
      }

      // Log to tracker
      await widget.onLog(totalServingsLogged);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = userFacingErrorMessage(e);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==================== HELPER METHODS ====================

  String _formatValue(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    } else if ((value * 10) == (value * 10).truncateToDouble()) {
      return value.toStringAsFixed(1);
    } else {
      return value.toStringAsFixed(2);
    }
  }

  String _formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toStringAsFixed(0);
    } else {
      return quantity.toStringAsFixed(1);
    }
  }

  double get _totalSelectedServings {
    return _selectedServings.values.fold(0.0, (sum, v) => sum + v);
  }

  // ==================== BUILD METHODS ====================

  @override
  Widget build(BuildContext context) {
    final isQuickLog = _selectedTab == 0;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: screenHeight * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with close button
              _buildHeader(),
              const SizedBox(height: 14),

              // Tab selector
              _buildTabSelector(),
              const SizedBox(height: 8),

              // Error message
              if (_error != null) _buildErrorMessage(),

              // Content based on selected tab
              if (isQuickLog)
                _buildQuickLogContent()
              else
                _buildPantryContent(),

              // Action button
              const SizedBox(height: 16),
              _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) {
        final textScaleFactor = MediaQuery.textScaleFactorOf(context);
        final clampedScale = textScaleFactor.clamp(0.8, 1.0);
        final iconPath = getTrackerIconAsset(widget.tracker.category);
        final isSvg = iconPath.endsWith('.svg');

        return Row(
          children: [
            // Tracker icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: isSvg
                      ? SvgPicture.asset(iconPath)
                      : Image.asset(iconPath),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log ${widget.tracker.name}',
                    style: TextStyle(
                      fontSize: 18 * clampedScale,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                      color: const Color(0xFF2C2C2C),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_formatValue(widget.tracker.currentValue)}/${_formatValue(widget.tracker.goalValue)} ${widget.tracker.unitString}',
                    style: TextStyle(
                      fontSize: 13 * clampedScale,
                      fontFamily: 'Inter',
                      color: const Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.close,
                  color: const Color(0xFF8E8E93),
                  size: 18 * clampedScale,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _buildTabButton(
              index: 0,
              icon: Icons.edit_outlined,
              label: 'Quick Log',
              subtitle: 'Ate outside?',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabButton(
              index: 1,
              icon: Icons.kitchen_outlined,
              label: 'From Pantry',
              subtitle: 'Use ingredients',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedTab == index;
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
          _error = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22 * clampedScale,
              color: isSelected
                  ? const Color(0xFFFF6A00)
                  : const Color(0xFF8E8E93),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13 * clampedScale,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontFamily: 'Inter',
                color: isSelected
                    ? const Color(0xFF2C2C2C)
                    : const Color(0xFF8E8E93),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10 * clampedScale,
                fontFamily: 'Inter',
                color: const Color(0xFFAEAEB2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5275).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: const Color(0xFFFF5275),
            size: 18 * clampedScale,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(
                color: const Color(0xFFFF5275),
                fontFamily: 'Inter',
                fontSize: 13 * clampedScale,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== QUICK LOG TAB ====================

  Widget _buildQuickLogContent() {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return SizedBox(
      height: _tabContentHeight,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: _tabContentHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
                // Description
                Text(
                  'How many servings did you have?',
                  style: TextStyle(
                    fontSize: 16 * clampedScale,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    color: const Color(0xFF2C2C2C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Perfect for meals eaten outside or when\nyou don\'t have ingredients in your pantry',
                  style: TextStyle(
                    fontSize: 13 * clampedScale,
                    fontFamily: 'Inter',
                    color: const Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),

                // Quantity selector
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Decrement button
                      GestureDetector(
                        onTap: _isLoading ? null : _decrementManualValue,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _manualValue > 0
                                ? const Color(0xFFFF5275).withOpacity(0.15)
                                : const Color(0xFFE5E5EA),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.remove,
                            size: 24,
                            color: _manualValue > 0
                                ? const Color(0xFFFF5275)
                                : const Color(0xFFC7C7CC),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Value display
                      SizedBox(
                        width: 100,
                        child: Column(
                          children: [
                            TextField(
                              controller: _manualValueController,
                              enabled: !_isLoading,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 32 * clampedScale,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2C2C2C),
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
                              ],
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  setState(() {
                                    _manualValue =
                                        double.tryParse(value) ?? _manualValue;
                                  });
                                } else {
                                  setState(() {
                                    _manualValue = 0;
                                  });
                                }
                              },
                            ),
                            Text(
                              widget.tracker.unitString,
                              style: TextStyle(
                                fontSize: 14 * clampedScale,
                                fontFamily: 'Inter',
                                color: const Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),

                      // Increment button
                      GestureDetector(
                        onTap: _isLoading ? null : _incrementManualValue,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6A00).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 24,
                            color: Color(0xFFFF6A00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Quick add buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [0.5, 1.0, 1.5, 2.0].map((value) {
                    return GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _manualValue = value;
                                _manualValueController.text = _formatValue(value);
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _manualValue == value
                              ? const Color(0xFFFF6A00)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _manualValue == value
                                ? const Color(0xFFFF6A00)
                                : const Color(0xFFE5E5EA),
                          ),
                        ),
                        child: Text(
                          '${_formatValue(value)} ${widget.tracker.unitString}',
                          style: TextStyle(
                            fontSize: 13 * clampedScale,
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w500,
                            color: _manualValue == value
                                ? Colors.white
                                : const Color(0xFF2C2C2C),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PANTRY TAB ====================

  Widget _buildPantryContent() {
    return SizedBox(
      height: _tabContentHeight,
      child: Column(
      children: [
        // Search bar
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search pantry items...',
              hintStyle: TextStyle(
                color: Color(0xFF8E8E93),
                fontFamily: 'Inter',
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF2C2C2C),
            ),
            onChanged: _filterItems,
          ),
        ),
        const SizedBox(height: 16),

        // Selected count indicator
        if (_selectedServings.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Color(0xFFFF6A00),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_formatValue(_totalSelectedServings)} ${widget.tracker.unitString} selected',
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF6A00),
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: _filteredItems.isEmpty
              ? SingleChildScrollView(
                  child: _buildEmptyPantryState(),
                )
              : Scrollbar(
                  controller: _pantryListScrollController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _pantryListScrollController,
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildPantryItemCard(item);
                    },
                  ),
                ),
        ),
      ],
      ),
    );
  }

  Widget _buildEmptyPantryState() {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: Color(0xFF8E8E93),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No matching items in pantry',
            style: TextStyle(
              fontSize: 16 * clampedScale,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              color: const Color(0xFF2C2C2C),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Quick Log to track manually',
            style: TextStyle(
              fontSize: 14 * clampedScale,
              fontFamily: 'Inter',
              color: const Color(0xFF8E8E93),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6A00).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 16 * clampedScale,
                    color: const Color(0xFFFF6A00),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Switch to Quick Log',
                    style: TextStyle(
                      fontSize: 13 * clampedScale,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF6A00),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantryItemCard(PantryItem item) {
    final servings = _selectedServings[item.id] ?? 0;
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
    final maxServings = _getMaxServingsAvailable(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: servings > 0
              ? const Color(0xFFFF6A00).withOpacity(0.3)
              : const Color(0xFFE5E5EA),
          width: servings > 0 ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item image/icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl.isNotEmpty
                ? CachedNetworkImageWidget(
                    imageUrl: item.imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    fallbackIcon: Icons.food_bank,
                    fallbackIconColor: const Color(0xFF8E8E93),
                    fallbackBackgroundColor: const Color(0xFFF7F7F8),
                  )
                : Icon(
                    Icons.food_bank,
                    color: const Color(0xFF8E8E93),
                    size: 22 * clampedScale,
                  ),
          ),
          const SizedBox(width: 12),
          // Item details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15 * clampedScale,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C2C2C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${_formatQuantity(item.quantity)} ${item.unitLabel}',
                      style: TextStyle(
                        fontSize: 13 * clampedScale,
                        fontFamily: 'Inter',
                        color: const Color(0xFF8E8E93),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Max: ${_formatQuantity(maxServings)}',
                        style: TextStyle(
                          fontSize: 10 * clampedScale,
                          fontFamily: 'Inter',
                          color: const Color(0xFF8E8E93),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (servings > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Will deduct: ${_getDeductionAmountText(item, servings)}',
                    style: TextStyle(
                      fontSize: 11 * clampedScale,
                      fontFamily: 'Inter',
                      color: const Color(0xFFFF6A00),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Quantity controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: servings > 0
                    ? const Color(0xFFFF6A00).withOpacity(0.3)
                    : const Color(0xFFE5E5EA),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: servings > 0 ? () => _removeServing(item.id) : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: servings > 0
                          ? const Color(0xFFFF5275).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: servings > 0
                          ? const Color(0xFFFF5275)
                          : const Color(0xFFC7C7CC),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 32),
                  child: Text(
                    servings.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14 * clampedScale,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2C2C2C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: servings < maxServings
                      ? () => _addServing(item.id)
                      : null,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: servings < maxServings
                          ? const Color(0xFFFF6A00).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: servings < maxServings
                          ? const Color(0xFFFF6A00)
                          : const Color(0xFFC7C7CC),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    final textScaleFactor = MediaQuery.textScaleFactorOf(context);
    final clampedScale = textScaleFactor.clamp(0.8, 1.0);

    final isQuickLog = _selectedTab == 0;
    final hasValue =
        isQuickLog ? _manualValue > 0 : _selectedServings.isNotEmpty;
    final valueText = isQuickLog
        ? '${_formatValue(_manualValue)} ${widget.tracker.unitString}'
        : '${_formatValue(_totalSelectedServings)} ${widget.tracker.unitString}';

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (isQuickLog ? _handleManualLog : _logFromPantry),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              hasValue ? const Color(0xFFFF6A00) : const Color(0xFFE5E5EA),
          foregroundColor: hasValue ? Colors.white : const Color(0xFF8E8E93),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20 * clampedScale,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasValue ? 'Log $valueText' : 'Select servings to log',
                    style: TextStyle(
                      fontSize: 15 * clampedScale,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
