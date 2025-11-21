import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_app/core/models/pantry_item.dart';
import 'package:flutter_app/features/pantry/controller/pantry_controller.dart';
import 'package:flutter_app/features/tracking/models/tracker_goal.dart';
import 'package:flutter_app/core/services/unit_conversion_service.dart';
import 'package:flutter_app/core/services/pantry_deduction_service.dart';
import 'package:flutter_app/core/services/diet_serving_service.dart';
import 'package:flutter_app/core/services/ingredient_substitution_service.dart';

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
  final TextEditingController _searchController = TextEditingController();
  List<PantryItem> _filteredItems = [];
  final Map<String, double> _selectedServings = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filterItems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final pantryController =
        Provider.of<PantryController>(context, listen: false);
    final allItems = [
      ...pantryController.pantryItems,
      ...pantryController.otherItems
    ];

    // Filter items that match the tracker category
    _filteredItems = allItems.where((item) {
      return _itemMatchesCategory(item, widget.tracker.category);
    }).toList();

    setState(() {});
  }

  bool _itemMatchesCategory(PantryItem item, TrackerCategory category) {
    // Get category keywords for the tracker category
    final keywords = _getCategoryKeywords(category);

    // Check if item name contains any keywords
    final itemName = item.name.toLowerCase();
    return keywords.any((keyword) => itemName.contains(keyword.toLowerCase()));
  }

  List<String> _getCategoryKeywords(TrackerCategory category) {
    switch (category) {
      case TrackerCategory.veggies:
        return [
          'tomato',
          'onion',
          'garlic',
          'carrot',
          'broccoli',
          'spinach',
          'lettuce',
          'cucumber',
          'pepper',
          'celery',
          'cabbage',
          'cauliflower',
          'zucchini',
          'squash',
          'eggplant',
          'mushroom',
          'asparagus',
          'green beans',
          'peas',
          'corn',
          'potato',
          'beet',
          'radish',
          'kale'
        ];
      case TrackerCategory.fruits:
        return [
          'apple',
          'banana',
          'orange',
          'lemon',
          'lime',
          'grape',
          'berry',
          'strawberry',
          'blueberry',
          'raspberry',
          'peach',
          'pear',
          'plum',
          'mango',
          'pineapple',
          'kiwi',
          'melon',
          'avocado'
        ];
      case TrackerCategory.grains:
        return [
          'rice',
          'wheat',
          'flour',
          'bread',
          'pasta',
          'noodle',
          'cereal',
          'oat',
          'barley',
          'quinoa',
          'couscous'
        ];
      case TrackerCategory.protein:
      case TrackerCategory.leanMeat:
        return [
          'chicken',
          'beef',
          'pork',
          'turkey',
          'fish',
          'salmon',
          'tuna',
          'shrimp',
          'egg',
          'tofu',
          'tempeh',
          'seitan',
          'bean',
          'lentil',
          'chickpea'
        ];
      case TrackerCategory.dairy:
        return ['milk', 'cheese', 'yogurt', 'butter', 'cream'];
      case TrackerCategory.nutsLegumes:
        return [
          'nut',
          'almond',
          'walnut',
          'peanut',
          'cashew',
          'pistachio',
          'bean',
          'lentil',
          'chickpea',
          'soy'
        ];
      case TrackerCategory.sweets:
        return [
          'sugar',
          'honey',
          'chocolate',
          'candy',
          'cookie',
          'cake',
          'dessert'
        ];
      default:
        return [];
    }
  }

  void _addServing(String itemId) {
    final item = _filteredItems.firstWhere((item) => item.id == itemId);
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

      // Convert pantry quantity to canonical unit
      final pantryQuantityInCanonicalUnit = conversionService.convert(
        amount: item.quantity,
        fromUnit: item.unitLabel,
        toUnit: canonicalUnit,
        ingredientName: item.name,
      );

      // If conversion failed, assume 1:1 ratio
      if (pantryQuantityInCanonicalUnit == 0.0) {
        return item.quantity;
      }

      // Calculate max servings: pantry quantity ÷ canonical amount per serving
      return pantryQuantityInCanonicalUnit / canonicalAmount;
    } catch (e) {
      // Fallback to pantry quantity if calculation fails
      return item.quantity;
    }
  }

  /// Calculate the actual physical amount to deduct from pantry for the given servings
  /// Uses the existing DietServingService logic in reverse
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

    // Convert from canonical unit to pantry item's unit
    final conversionService = UnitConversionService();
    final physicalAmountInPantryUnit = conversionService.convert(
      amount: physicalAmountInCanonicalUnit,
      fromUnit: canonicalUnit,
      toUnit: item.unitLabel,
      ingredientName: item.name,
    );

    // If conversion failed, assume 1:1 ratio
    if (physicalAmountInPantryUnit == 0.0) {
      return servings;
    }

    return physicalAmountInPantryUnit;
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

  /// Format quantity to show max 1 decimal place
  String _formatQuantity(double quantity) {
    if (quantity == quantity.truncateToDouble()) {
      return quantity.toStringAsFixed(0);
    } else {
      return quantity.toStringAsFixed(1);
    }
  }

  Future<void> _logToTracker() async {
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

      // Calculate servings for each selected item
      for (final entry in _selectedServings.entries) {
        final itemId = entry.key;
        final servings = entry.value;

        final item = _filteredItems.firstWhere((item) => item.id == itemId);

        // Calculate the actual physical amount to deduct from pantry
        final actualAmountToDeduct = _calculatePhysicalAmountForServings(
          dietServingService: dietServingService,
          item: item,
          servings: servings,
        );

        // The tracker servings should equal the user-selected servings
        // (since we're converting serving count to physical amount, not the reverse)
        totalServingsLogged += servings;

        // Prepare for pantry deduction with actual physical amount
        itemsToDeduct.add({
          'name': item.name,
          'amount': actualAmountToDeduct,
          'unit': item.unitLabel,
        });
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
        final item = [
          ...pantryController.pantryItems,
          ...pantryController.otherItems
        ].firstWhere((item) => item.id == itemId);
        await pantryController.removeItem(itemId, item.isPantryItem);
      }

      // Log to tracker
      await widget.onLog(totalServingsLogged);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to log items: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) {
                final textScaleFactor = MediaQuery.textScaleFactorOf(context);
                final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Log ${widget.tracker.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20 * clampedScale,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'BricolageGrotesque',
                          color: const Color(0xFF2C2C2C),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close,
                        color: const Color(0xFF2C2C2C),
                        size: 24 * clampedScale,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

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
                    fontFamily: 'BricolageGrotesque',
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
                  fontFamily: 'BricolageGrotesque',
                  fontSize: 14,
                  color: Color(0xFF2C2C2C),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _filterItems();
                    } else {
                      _filteredItems = _filteredItems
                          .where((item) => item.name
                              .toLowerCase()
                              .contains(value.toLowerCase()))
                          .toList();
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5275).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(
                  builder: (context) {
                    final textScaleFactor =
                        MediaQuery.textScaleFactorOf(context);
                    final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                    return Text(
                      _error!,
                      style: TextStyle(
                        color: const Color(0xFFFF5275),
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 14 * clampedScale,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ),

            // Items list
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F7F8),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 32,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final textScaleFactor =
                                  MediaQuery.textScaleFactorOf(context);
                              final clampedScale =
                                  textScaleFactor.clamp(0.8, 1.0);
                              return Column(
                                children: [
                                  Text(
                                    'No matching items in pantry',
                                    style: TextStyle(
                                      fontSize: 16 * clampedScale,
                                      fontFamily: 'BricolageGrotesque',
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF2C2C2C),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 8 * clampedScale),
                                  Text(
                                    'Add items to your pantry first',
                                    style: TextStyle(
                                      fontSize: 14 * clampedScale,
                                      fontFamily: 'BricolageGrotesque',
                                      color: const Color(0xFF8E8E93),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final servings = _selectedServings[item.id] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE5E5EA),
                              width: 1,
                            ),
                          ),
                          child: Builder(
                            builder: (context) {
                              final textScaleFactor =
                                  MediaQuery.textScaleFactorOf(context);
                              final clampedScale =
                                  textScaleFactor.clamp(0.8, 1.0);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Item image/icon
                                  Container(
                                    width: 48 * clampedScale.clamp(1.0, 1.1),
                                    height: 48 * clampedScale.clamp(1.0, 1.1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F8),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: item.imageUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(24),
                                            child: CachedNetworkImage(
                                              imageUrl: item.imageUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Icon(
                                                Icons.food_bank,
                                                color: const Color(0xFF8E8E93),
                                                size: 24 * clampedScale,
                                              ),
                                              errorWidget:
                                                  (context, url, error) => Icon(
                                                Icons.food_bank,
                                                color: const Color(0xFF8E8E93),
                                                size: 24 * clampedScale,
                                              ),
                                            ),
                                          )
                                        : Icon(
                                            Icons.food_bank,
                                            color: const Color(0xFF8E8E93),
                                            size: 24 * clampedScale,
                                          ),
                                  ),
                                  SizedBox(width: 12 * clampedScale),
                                  // Item details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 16 * clampedScale,
                                            fontFamily: 'BricolageGrotesque',
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF2C2C2C),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4 * clampedScale),
                                        Wrap(
                                          spacing: 8 * clampedScale,
                                          runSpacing: 4 * clampedScale,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '${_formatQuantity(item.quantity)} ${item.unitLabel}',
                                              style: TextStyle(
                                                fontSize: 14 * clampedScale,
                                                fontFamily:
                                                    'BricolageGrotesque',
                                                color: const Color(0xFF8E8E93),
                                              ),
                                            ),
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6 * clampedScale,
                                                vertical: 2 * clampedScale,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF7F7F8),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Max: ${_formatQuantity(_getMaxServingsAvailable(item))}',
                                                style: TextStyle(
                                                  fontSize: 10 * clampedScale,
                                                  fontFamily:
                                                      'BricolageGrotesque',
                                                  color:
                                                      const Color(0xFF8E8E93),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (servings > 0) ...[
                                          SizedBox(height: 6 * clampedScale),
                                          Text(
                                            'Deduct: ${_getDeductionAmountText(item, servings)}',
                                            style: TextStyle(
                                              fontSize: 10 *
                                                  clampedScale.clamp(0.8, 1.0),
                                              fontFamily: 'BricolageGrotesque',
                                              color: const Color(0xFFFF6A00),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 8 * clampedScale),
                                  // Quantity controls
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4 * clampedScale,
                                      vertical: 2 * clampedScale,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F7F8),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: servings > 0
                                            ? const Color(0xFFFF6A00)
                                                .withValues(alpha: 0.3)
                                            : const Color(0xFFE5E5EA),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: servings > 0
                                              ? () => _removeServing(item.id)
                                              : null,
                                          child: Container(
                                            width: 28 * clampedScale,
                                            height: 28 * clampedScale,
                                            decoration: BoxDecoration(
                                              color: servings > 0
                                                  ? const Color(0xFFFF5275)
                                                      .withValues(alpha: 0.15)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              Icons.remove,
                                              size: 16 * clampedScale,
                                              color: servings > 0
                                                  ? const Color(0xFFFF5275)
                                                  : const Color(0xFFC7C7CC),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8 * clampedScale),
                                        Container(
                                          constraints: BoxConstraints(
                                              minWidth: 24 * clampedScale),
                                          child: Text(
                                            servings.toString(),
                                            style: TextStyle(
                                              fontSize: 14 * clampedScale,
                                              fontFamily: 'BricolageGrotesque',
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF2C2C2C),
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        SizedBox(width: 8 * clampedScale),
                                        GestureDetector(
                                          onTap: () {
                                            final maxServings =
                                                _getMaxServingsAvailable(item);
                                            if (servings < maxServings) {
                                              _addServing(item.id);
                                            }
                                          },
                                          child: Container(
                                            width: 28 * clampedScale,
                                            height: 28 * clampedScale,
                                            decoration: BoxDecoration(
                                              color: servings <
                                                      _getMaxServingsAvailable(
                                                          item)
                                                  ? const Color(0xFFFF6A00)
                                                      .withValues(alpha: 0.15)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                            ),
                                            child: Icon(
                                              Icons.add,
                                              size: 16 * clampedScale,
                                              color: servings <
                                                      _getMaxServingsAvailable(
                                                          item)
                                                  ? const Color(0xFFFF6A00)
                                                  : const Color(0xFFC7C7CC),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),

            // Save button
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _logToTracker,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6A00),
                  foregroundColor: Colors.white,
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final textScaleFactor =
                              MediaQuery.textScaleFactorOf(context);
                          final clampedScale = textScaleFactor.clamp(0.8, 1.0);
                          return Text(
                            'Log to Tracker',
                            style: TextStyle(
                              fontSize: 16 * clampedScale,
                              fontFamily: 'BricolageGrotesque',
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
