import 'package:flutter/material.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/core/utils/image_url_helper.dart';
import 'dart:developer' as developer;

class PantryItemAddModal extends StatefulWidget {
  final Map<String, dynamic> foodItem; // Spoonacular item or similar map
  final String category;
  final Function(PantryItem) onAdd;
  final bool isFoodPantryItem; // New field

  const PantryItemAddModal({
    Key? key,
    required this.foodItem,
    required this.category,
    required this.onAdd,
    this.isFoodPantryItem = true, // Default to true
  }) : super(key: key);

  @override
  State<PantryItemAddModal> createState() => _PantryItemAddModalState();
}

class _PantryItemAddModalState extends State<PantryItemAddModal> {
  final TextEditingController _quantityController = TextEditingController();
  UnitType _selectedUnit = UnitType.piece;
  bool _isQuantityValid = true;
  String _itemName = '';
  String _imageUrl = '';
  DateTime _calculatedExpiryDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _itemName = widget.foodItem['name'] ?? 'Unknown Item';
    _imageUrl = ImageUrlHelper.getValidImageUrl(widget.foodItem['image']);

    // Determine default unit and calculate smart expiration using public static methods
    _selectedUnit = PantryItem.getDefaultUnitForCategory(widget.category);
    _calculatedExpiryDate =
        PantryItem.calculateDefaultExpirationDate(widget.category);
    developer.log(
        'Modal: Initialized for $_itemName, category: ${widget.category}, isFoodPantry: ${widget.isFoodPantryItem}. Default unit: $_selectedUnit, Calculated Expiry: $_calculatedExpiryDate');
    // Initialize with a default quantity
    _quantityController.text = "1";
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _validateQuantity() {
    final text = _quantityController.text;
    if (text.isEmpty) {
      setState(() {
        _isQuantityValid = false;
      });
      return;
    }

    try {
      final quantity = double.parse(text);
      setState(() {
        _isQuantityValid = quantity > 0;
      });
    } catch (e) {
      setState(() {
        _isQuantityValid = false;
      });
    }
  }

  void _addItem() {
    if (!_isQuantityValid || _quantityController.text.isEmpty) {
      developer.log('Modal: Add item validation failed.');
      return;
    }

    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null) {
      developer.log('Modal: Invalid quantity format.');
      setState(() {
        _isQuantityValid = false;
      });
      return;
    }

    // Ensure foodItem['id'] exists and is a string, or generate one if necessary
    // For items from Spoonacular or CSV, an ID should always be present.
    // If adding a purely custom item in the future, ID generation would be needed here.
    final String itemId = widget.foodItem['id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final newItem = PantryItem(
      id: itemId, // Use the id from foodItem or generated
      name: _itemName,
      imageUrl: _imageUrl,
      category: widget.category,
      quantity: quantity,
      unit: _selectedUnit,
      expirationDate: _calculatedExpiryDate,
      addedDate: DateTime.now(),
      isPantryItem: widget.isFoodPantryItem,
    );

    developer.log(
        'Modal: Adding item: ${newItem.name}, ID: ${newItem.id}, isFoodPantryItem: ${newItem.isPantryItem}');
    widget.onAdd(newItem);
    Navigator.of(context).pop(); // Close modal after adding
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFFF6A00);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item name as title
            Text(
              widget.foodItem['name'],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Quantity input and unit selection row
            Row(
              children: [
                // Quantity field - takes 60% of the space
                Expanded(
                  flex: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _quantityController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _validateQuantity(),
                      decoration: InputDecoration(
                        hintText: 'Enter Quantity',
                        border: InputBorder.none,
                        errorText:
                            _isQuantityValid ? null : 'Enter valid quantity',
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Unit dropdown - takes 40% of the space
                Expanded(
                  flex: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UnitType>(
                        value: _selectedUnit,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: UnitType.values.map((UnitType unit) {
                          return DropdownMenuItem<UnitType>(
                            value: unit,
                            child: Text(_getUnitDisplayName(unit)),
                          );
                        }).toList(),
                        onChanged: (UnitType? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedUnit = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Add button
            ElevatedButton(
              onPressed: _addItem,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Add',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to get user-friendly unit names
  String _getUnitDisplayName(UnitType unit) {
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
      default:
        return unit.toString().split('.').last;
    }
  }
}
