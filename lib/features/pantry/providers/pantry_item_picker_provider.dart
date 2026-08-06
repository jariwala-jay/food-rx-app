import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_app/core/services/pantry_api_service.dart';
import 'package:flutter_app/core/services/allergy_filtering_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/spoonacular_ingredient_repository.dart';

class PantryItemPickerProvider extends ChangeNotifier {
  final IngredientRepository _ingredientRepository;
  final PantryApiService _pantryApi = PantryApiService();
  final AuthController _authProvider;
  final bool isFoodPantryItem;

  bool isLoading = false;
  String? error;
  List<Ingredient> items = [];
  List<Ingredient> commonItems = [];
  List<Ingredient> searchResults = [];
  String _currentCategoryKey = '';

  /// True when aisle search returned nothing and results come from global
  /// Spoonacular autocomplete (Phase A: communicate browse → search mode).
  bool isShowingGlobalIngredientSearch = false;

  /// True when the last global search came back empty because the
  /// Spoonacular API was rate-limited, not because there were no matches.
  /// Lets the UI show "try again in a moment" instead of "not found".
  bool isRateLimitedSearch = false;

  // Track which items have been selected and their quantities
  final Map<String, PantryItem> _selectedItems = {};

  bool get hasInitialized => _currentCategoryKey.isNotEmpty;
  bool get hasSelectedItems => _selectedItems.isNotEmpty;
  List<PantryItem> get selectedItemsList => _selectedItems.values.toList();

  PantryItemPickerProvider(this._ingredientRepository, this._authProvider,
      {this.isFoodPantryItem = true});

  List<String> _mapUserAllergiesToIntolerances() {
    final allergies = _authProvider.currentUser?.allergies ?? [];
    return AllergyFilteringService.intoleranceApiNamesFor(allergies);
  }

  bool _isAllergyItemName(String itemName) {
    final allergies = _authProvider.currentUser?.allergies ?? [];
    final excluded = _authProvider.currentUser?.excludedIngredients ?? const [];
    return AllergyFilteringService.conflictsWithRestrictions(
      itemName,
      allergies: allergies,
      excludedIngredients: excluded,
    );
  }

  Future<void> loadItems(String categoryKey) async {
    isLoading = true;
    error = null;
    _currentCategoryKey = categoryKey;
    developer.log(
        'Loading items for category: $categoryKey, isFoodPantryItem: $isFoodPantryItem');

    // Clear previous results to avoid mixing categories
    items = [];
    searchResults = [];
    commonItems = [];
    isShowingGlobalIngredientSearch = false;

    notifyListeners();

    try {
      // First, load common items from constants
      final commonItemsData =
          getCommonItemsForCategory(categoryKey, isFoodPantryItem);
      commonItems = commonItemsData
          .map((itemData) {
            final asset = itemData['imageAsset'] as String?;
            return Ingredient(
              id: itemData['id']?.toString() ?? '',
              name: itemData['name'] ?? '',
              image: itemData['imageUrl'] ?? '',
              imageName: asset != null
                  ? 'default.jpg'
                  : (itemData['imageUrl']?.split('/').last ?? 'default.jpg'),
              aisle: categoryKey,
              localAssetPath: asset,
            );
          })
          .where((ing) => !_isAllergyItemName(ing.name))
          .toList();

      developer.log(
          'Loaded ${commonItems.length} common items for category $categoryKey');

      // Set common items as initial search results
      items = List<Ingredient>.from(commonItems);
      searchResults = List<Ingredient>.from(commonItems);

      // Optionally load additional items from API in background
      // This provides immediate results while still allowing for expanded search
      _loadAdditionalItemsInBackground(categoryKey);
    } catch (e) {
      developer.log('Error loading items: $e');
      error = userFacingErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAdditionalItemsInBackground(String categoryKey) async {
    final aisle = spoonacularAisleForFoodRxCategory(categoryKey);
    if (aisle == null) {
      // No reliable Spoonacular aisle (e.g. 'miscellaneous') — an unfiltered
      // fetch would return arbitrary ingredients unrelated to the category.
      return;
    }
    try {
      // Fetch additional ingredients from API using a real Spoonacular aisle
      final apiResults = await _ingredientRepository.searchIngredients(
          aisle: aisle,
          number: 30,
          intolerances: _mapUserAllergiesToIntolerances());

      developer.log(
          'Loaded ${apiResults.length} additional API items for category $categoryKey');

      // Merge API results with common items, avoiding duplicates
      final allItems = <Ingredient>[...commonItems];

      for (final apiItem in apiResults) {
        // Check if item already exists in common items (by name similarity)
        final isDuplicate = commonItems.any((commonItem) =>
            commonItem.name.toLowerCase().trim() ==
            apiItem.name.toLowerCase().trim());

        if (!isDuplicate) {
          allItems.add(apiItem);
        }
      }

      items = allItems;

      // Update search results only if user hasn't started searching
      if (searchResults.length == commonItems.length) {
        searchResults = List<Ingredient>.from(allItems);
      }

      notifyListeners();
    } catch (e) {
      developer.log('Error loading additional items in background: $e');
      // Don't set error here as common items are already loaded
    }
  }

  void searchItems(String query) {
    isShowingGlobalIngredientSearch = false;
    if (query.isEmpty) {
      // Show all items (common + API results)
      searchResults = List<Ingredient>.from(items);
    } else {
      // Local filtering for immediate feedback
      searchResults = items
          .where(
              (item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    developer.log(
        'Local search for "$query" returned ${searchResults.length} results');
    notifyListeners();
  }

  Future<void> searchSpoonacular(String query) async {
    // Increased minimum to 3 characters to reduce API calls
    if (query.length < 3) return;

    isRateLimitedSearch = false;

    // Prefer curated / already-loaded items in this category first.
    // e.g. "Frozen Peas" from Vegetables → Frozen should stay in-category,
    // not show "not found in Frozen Vegetables" via global search.
    searchItems(query);
    if (searchResults.isNotEmpty) {
      developer.log('In-category match for "$query" in $_currentCategoryKey '
          '(${searchResults.length} results) — skipping global search');
      return;
    }

    isLoading = true;
    error = null;
    // No local category hits — search the global ingredient DB and label UI.
    isShowingGlobalIngredientSearch = true;
    notifyListeners();

    try {
      developer.log(
          'Global ingredient search for "$query" (opened from category $_currentCategoryKey)');

      final repository = _ingredientRepository;
      if (repository is SpoonacularIngredientRepository &&
          repository.isRateLimited) {
        developer.log('Repository is rate limited, skipping API calls');
        isRateLimitedSearch = true;
        searchItems(query);
        isShowingGlobalIngredientSearch = false;
        return;
      }

      // Search is primary (supports server-side `intolerances` filtering,
      // unlike autocomplete) but never returns `aisle`; resolved lazily
      // in resolveAisleForAdd() only for the item the user actually adds.
      var results = await _ingredientRepository.searchIngredients(
        query: query,
        number: 20,
        intolerances: _mapUserAllergiesToIntolerances(),
      );

      final rateLimitedAfterSearch =
          repository is SpoonacularIngredientRepository &&
              repository.isRateLimited;

      if (results.isEmpty && !rateLimitedAfterSearch) {
        developer.log('No search results for "$query", trying autocomplete...');
        results =
            await _ingredientRepository.autocompleteIngredient(query: query);
      }

      final rateLimitedAfterAutocomplete =
          repository is SpoonacularIngredientRepository &&
              repository.isRateLimited;

      if (results.isEmpty) {
        // A 429 masquerades as an empty result — tell the UI apart from a
        // genuine "no matches" so it doesn't claim the ingredient isn't found.
        isRateLimitedSearch =
            rateLimitedAfterSearch || rateLimitedAfterAutocomplete;
        searchItems(query);
        isShowingGlobalIngredientSearch = false;
      } else {
        isRateLimitedSearch = false;
        searchResults = results;
        isShowingGlobalIngredientSearch = true;
      }

      developer.log(
          'Global ingredient search returned ${searchResults.length} results '
          '(isShowingGlobalIngredientSearch=$isShowingGlobalIngredientSearch, '
          'isRateLimitedSearch=$isRateLimitedSearch)');
    } catch (e) {
      developer.log('Spoonacular search error: $e');
      error = userFacingErrorMessage(e);
      isShowingGlobalIngredientSearch = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Global-search results never carry `aisle`, so this does one autocomplete
  /// lookup by exact name to resolve it for correct category filing on add.
  Future<String?> resolveAisleForAdd(Ingredient item) async {
    if (item.aisle != null && item.aisle!.isNotEmpty) return item.aisle;

    final repository = _ingredientRepository;
    if (repository is SpoonacularIngredientRepository &&
        repository.isRateLimited) {
      return null;
    }

    try {
      final results = await _ingredientRepository.autocompleteIngredient(
          query: item.name, number: 1);
      return results.isNotEmpty ? results.first.aisle : null;
    } catch (e) {
      developer.log('Error resolving aisle for "${item.name}": $e');
      return null;
    }
  }

  // Add item to pantry selection
  void addItemToSelection(PantryItem item) {
    if (_authProvider.currentUser == null) {
      error = "User not logged in. Cannot add items.";
      notifyListeners();
      developer.log(error!);
      return;
    }
    if (_isAllergyItemName(item.name)) {
      error =
          "${item.name} can't be added because it matches a food you marked as an allergy or intolerance.";
      notifyListeners();
      developer.log(error!);
      return;
    }
    final itemWithCorrectFlag = item.copyWith(isPantryItem: isFoodPantryItem);
    _selectedItems[item.id] = itemWithCorrectFlag;
    developer.log(
        'Provider: Added item ${itemWithCorrectFlag.name} (isFoodPantryItem: ${itemWithCorrectFlag.isPantryItem}) to selection. Total selected: ${_selectedItems.length}');
    notifyListeners();
  }

  // Remove item from pantry selection
  void removeItemFromSelection(String itemId) {
    _selectedItems.remove(itemId);
    developer.log(
        'Removed item with ID $itemId from selection. Total selected: ${_selectedItems.length}');
    notifyListeners();
  }

  // Update quantity or unit for a selected item
  void updateSelectedItemQuantity(
      String itemId, double quantity, UnitType unit) {
    if (_selectedItems.containsKey(itemId)) {
      final item = _selectedItems[itemId]!;
      _selectedItems[itemId] = item.copyWith(
        quantity: quantity,
        unit: unit,
      );
      notifyListeners();
    }
  }

  // Check if an item is selected
  bool isItemSelected(String itemId) {
    return _selectedItems.containsKey(itemId);
  }

  // Get a selected item
  PantryItem? getSelectedItem(String itemId) {
    return _selectedItems[itemId];
  }

  // Clear all selected items
  void clearSelection() {
    _selectedItems.clear();
    notifyListeners();
  }

  // Save all selected items to MongoDB
  Future<bool> saveSelectedItemsToPantry() async {
    if (_selectedItems.isEmpty) {
      developer.log('No items selected to save.');
      return false;
    }
    if (_authProvider.currentUser == null ||
        _authProvider.currentUser!.id == null) {
      error = "User not logged in. Cannot save items.";
      notifyListeners();
      developer.log(error!);
      return false;
    }

    final String userId = _authProvider.currentUser!.id!;
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      var itemsToSave = _selectedItems.values.toList();
      // Prevent saving allergy items
      final beforeCount = itemsToSave.length;
      itemsToSave =
          itemsToSave.where((i) => !_isAllergyItemName(i.name)).toList();
      if (itemsToSave.length != beforeCount) {
        developer.log(
            'Filtered out ${beforeCount - itemsToSave.length} allergy item(s) from save.');
      }
      if (itemsToSave.isEmpty) {
        error = 'No items selected to save.';
        isLoading = false;
        notifyListeners();
        return true;
      }

      developer.log(
          'Provider: Saving ${itemsToSave.length} items to pantry for user $userId. isFoodPantryItem context: $isFoodPantryItem');

      for (var item in itemsToSave) {
        // Ensure isPantryItem is set based on the context of this provider
        final itemToSave = item.copyWith(isPantryItem: isFoodPantryItem);
        developer.log(
            'Attempting to save item: ${itemToSave.name} with isPantryItem: ${itemToSave.isPantryItem}');
        await _pantryApi.addPantryItem(userId, itemToSave.toMap());
      }
      _selectedItems.clear();
      isLoading = false;
      _currentCategoryKey = ''; // Force reload on next page visit if needed
      notifyListeners();
      developer.log('Provider: Successfully saved items.');
      return true;
    } catch (e) {
      developer.log('Error saving items to pantry: $e');
      error = userFacingErrorMessage(e);
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
