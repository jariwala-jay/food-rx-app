import 'package:flutter_app/core/widgets/form_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import '../controller/pantry_controller.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/widgets/cached_network_image.dart';
import '../widgets/category_filter_chips.dart';
import 'package:flutter_app/features/navigation/widgets/add_action_sheet.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({Key? key}) : super(key: key);

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> with RouteAware {
  int _selectedTabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  RouteObserver<ModalRoute<void>>? _routeObserver;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
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
              Container(
                height: 46,
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
                            child: Text(
                              'FoodRx Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _selectedTabIndex == 0
                                    ? Colors.white
                                    : Colors.grey,
                              ),
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
                            child: Text(
                              'Home Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _selectedTabIndex == 1
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
      return const Center(child: CircularProgressIndicator());
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
            const Text(
              'Your FoodRx Items list is Empty. Add items to get started!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
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
            Text(
              controller.searchQuery.isNotEmpty ||
                      controller.selectedCategory != null
                  ? 'No items found matching your search'
                  : 'No pantry items available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
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
      itemCount: controller.filteredPantryItems.length,
      itemBuilder: (context, index) {
        final item = controller.filteredPantryItems[index];
        return _buildPantryItemTile(item);
      },
    );
  }

  Widget _buildOtherItemsContent(PantryController controller) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
            const Text(
              'Your Home Items list is empty. Add what you have at home or bought from grocery store.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
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
            Text(
              controller.searchQuery.isNotEmpty ||
                      controller.selectedCategory != null
                  ? 'No items found matching your search'
                  : 'No other items available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
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

  Widget _buildPantryItemTile(PantryItem item) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getExpiryText(item.expiryDate),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Qty tag
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.quantityDisplay,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF6A00),
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEEFE4),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add,
              color: Color(0xFFFF6A00),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF6A00),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
              Text('Edit ${item.name}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
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
                  const Text('Expiration Date:',
                      style: TextStyle(fontSize: 16)),
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
