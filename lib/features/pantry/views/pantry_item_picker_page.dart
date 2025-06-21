import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/pantry_item_picker_provider.dart';
import 'dart:developer' as developer;

import '../widgets/pantry_item_add_modal.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/core/models/ingredient.dart';
import '../repositories/spoonacular_ingredient_repository.dart';

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

  @override
  void initState() {
    super.initState();
    developer.log(
        'PantryItemPickerView initialized for category: ${widget.categoryKey}');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Show modal dialog to add quantity and unit
  void _showAddItemModal(BuildContext context, Ingredient item) {
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
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PantryItemPickerProvider>(context);
    final primaryColor = Color(0xFFFF6A00);

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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
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

                  if (query.length >= 2) {
                    provider.searchSpoonacular(query);
                  } else {
                    provider.searchItems(query);
                  }
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
                      style: TextStyle(color: Colors.grey, fontSize: 16),
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
                          child: Text(
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
                    )
                  else if (!_isTyping && provider.searchResults.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Popular ${widget.title}',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap + to add items to your pantry',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      itemCount: provider.searchResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = provider.searchResults[index];
                        final itemId = item.id.toString();
                        final isSelected = provider.isItemSelected(itemId);
                        final selectedItem = isSelected
                            ? provider.getSelectedItem(itemId)
                            : null;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFFFF6A00)),
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEEEEE),
                                    borderRadius: BorderRadius.circular(8),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: isSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      selectedItem!.quantityDisplay,
                                      style: const TextStyle(
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
                                    onTap: () =>
                                        _showAddItemModal(context, item),
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF6A00),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.add,
                                          color: Colors.white, size: 22),
                                    ),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Save button at the bottom
          if (provider.hasSelectedItems)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final success = await provider.saveSelectedItemsToPantry();
                    if (mounted) {
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Items added to your pantry'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        Navigator.of(context).pop();
                      } else {
                        if (provider.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to save items: ${provider.error}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
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
        ],
      ),
    );
  }
}

// Example usage (to be replaced with real navigation and data):
final mockFreshFruits = [];
