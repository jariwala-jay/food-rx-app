import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import '../models/pantry_item.dart';
import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../repositories/ingredient_repository.dart';

class PantryItemPickerProvider extends ChangeNotifier {
  final IngredientRepository _ingredientRepository;
  final MongoDBService _mongoDBService;
  final AuthController _authProvider;
  final bool isFoodPantryItem;

  bool isLoading = false;
  String? error;
  List<Ingredient> items = [];
  List<Ingredient> mostUsedItems = [];
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
    mostUsedItems = [];

    notifyListeners();

    try {
      // Fetch ingredients for the category by searching with an aisle
      final results = await _ingredientRepository.searchIngredients(
          aisle: categoryKey, number: 50);

      developer.log('Loaded ${results.length} items for category $categoryKey');

      items = results;
      mostUsedItems = items.take(3).toList();
      searchResults = List<Ingredient>.from(items);

      if (items.isEmpty) {
        developer.log('Warning: No items found for category $categoryKey');
      }
    } catch (e) {
      developer.log('Error loading items: $e');
      error = 'Failed to load items: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void searchItems(String query) {
    if (query.isEmpty) {
      searchResults = List<Ingredient>.from(items);
    } else {
      // Local filtering for immediate feedback (can be removed if API is fast enough)
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
    if (query.length < 2) return;

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      developer.log(
          'Searching Spoonacular for "$query" in category $_currentCategoryKey');

      // Search specifically within the current category/aisle
      final results = await _ingredientRepository.searchIngredients(
        query: query,
        aisle: _currentCategoryKey,
        number: 20,
      );

      if (results.isEmpty) {
        developer.log(
            'No search results found for "$query" in aisle $_currentCategoryKey, trying autocomplete...');
        // If no results in search, try autocomplete as a fallback
        final autocompleteResults =
            await _ingredientRepository.autocompleteIngredient(query: query);

        searchResults = autocompleteResults;
      } else {
        searchResults = results;
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
