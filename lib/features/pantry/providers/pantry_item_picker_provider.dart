import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/constants/pantry_categories.dart';
import '../repositories/ingredient_repository.dart';
import '../repositories/spoonacular_ingredient_repository.dart';

class PantryItemPickerProvider extends ChangeNotifier {
  final IngredientRepository _ingredientRepository;
  final MongoDBService _mongoDBService;
  final AuthController _authProvider;
  final bool isFoodPantryItem;

  bool isLoading = false;
  String? error;
  List<Ingredient> items = [];
  List<Ingredient> commonItems = [];
  List<Ingredient> searchResults = [];
  String _currentCategoryKey = '';

  // Track which items have been selected and their quantities
  final Map<String, PantryItem> _selectedItems = {};

  bool get hasInitialized => _currentCategoryKey.isNotEmpty;
  bool get hasSelectedItems => _selectedItems.isNotEmpty;
  List<PantryItem> get selectedItemsList => _selectedItems.values.toList();

  PantryItemPickerProvider(
      this._ingredientRepository, this._mongoDBService, this._authProvider,
      {this.isFoodPantryItem = true});

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

    notifyListeners();

    try {
      // First, load common items from constants
      final commonItemsData =
          getCommonItemsForCategory(categoryKey, isFoodPantryItem);
      commonItems = commonItemsData
          .map((itemData) => Ingredient(
                id: itemData['id']?.toString() ?? '',
                name: itemData['name'] ?? '',
                image: itemData['imageUrl'] ?? '',
                imageName:
                    itemData['imageUrl']?.split('/').last ?? 'default.jpg',
                aisle: categoryKey,
              ))
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
      error = 'Failed to load items: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAdditionalItemsInBackground(String categoryKey) async {
    try {
      // Fetch additional ingredients from API
      final apiResults = await _ingredientRepository.searchIngredients(
          aisle: categoryKey, number: 30);

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

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      developer.log(
          'Searching Spoonacular for "$query" in category $_currentCategoryKey');

      // Check if repository is rate limited before making calls
      final repository = _ingredientRepository;
      if (repository is SpoonacularIngredientRepository &&
          repository.isRateLimited) {
        developer.log('Repository is rate limited, skipping API calls');
        // Fall back to local search
        searchItems(query);
        return;
      }

      // Search specifically within the current category/aisle
      final results = await _ingredientRepository.searchIngredients(
        query: query,
        aisle: _currentCategoryKey,
        number: 20,
      );

      if (results.isEmpty) {
        // Only try autocomplete if we're not rate limited
        if (repository is SpoonacularIngredientRepository &&
            !repository.isRateLimited) {
          developer.log(
              'No search results found for "$query" in aisle $_currentCategoryKey, trying autocomplete...');
          // If no results in search, try autocomplete as a fallback
          final autocompleteResults =
              await _ingredientRepository.autocompleteIngredient(query: query);

          searchResults = autocompleteResults;
        } else {
          // Rate limited or autocomplete failed, fall back to local search
          developer.log(
              'No search results found and rate limited, falling back to local search');
          searchItems(query);
        }
      } else {
        // Merge search results with existing items to avoid losing common items
        final mergedResults = <Ingredient>[...results];

        // Add relevant common items that match the search
        final matchingCommonItems = commonItems
            .where((commonItem) =>
                commonItem.name.toLowerCase().contains(query.toLowerCase()))
            .toList();

        for (final commonItem in matchingCommonItems) {
          final isDuplicate = mergedResults.any((result) =>
              result.name.toLowerCase().trim() ==
              commonItem.name.toLowerCase().trim());

          if (!isDuplicate) {
            mergedResults.insert(0, commonItem); // Add common items at the top
          }
        }

        searchResults = mergedResults;
      }

      developer
          .log('Spoonacular search returned ${searchResults.length} results');
    } catch (e) {
      developer.log('Spoonacular search error: $e');
      error = 'Failed to search ingredients: $e';
    } finally {
      isLoading = false;
      notifyListeners();
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
      final itemsToSave = _selectedItems.values.toList();
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
        await _mongoDBService.addPantryItem(userId, itemToSave.toMap());
      }
      _selectedItems.clear();
      isLoading = false;
      _currentCategoryKey = ''; // Force reload on next page visit if needed
      notifyListeners();
      developer.log('Provider: Successfully saved items.');
      return true;
    } catch (e) {
      developer.log('Error saving items to pantry: $e');
      error = 'Failed to save items: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
