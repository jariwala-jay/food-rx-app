// SET PANTRY ITEM DEFFAULTS, EXPIRY DATE, UNIT, AND QUANTITY HERE
import 'package:flutter_app/core/models/ingredient.dart';
import 'package:flutter_app/core/utils/image_url_helper.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

enum UnitType {
  pound,
  ounces,
  gallon,
  milliliter,
  liter,
  piece,
  grams,
  kilograms,
  cup,
  tablespoon,
  teaspoon
}

class PantryItem {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final double quantity;
  final UnitType unit;
  final DateTime expirationDate;
  final DateTime addedDate;
  final bool isSelected; // Used for multi-selection in the UI
  final bool isPantryItem; // For MongoDBService compatibility

  PantryItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.expirationDate,
    DateTime? addedDate,
    this.isSelected = false,
    this.isPantryItem = true, // Default to true for items added via new UI
  }) : addedDate = addedDate ?? DateTime.now();

  // Compatibility getters for old code if any still uses them directly
  DateTime? get expiryDate => expirationDate;
  String get legacyQuantityString => quantity.toString();

  PantryItem copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? category,
    double? quantity,
    UnitType? unit,
    DateTime? expirationDate,
    DateTime? addedDate,
    bool? isSelected,
    bool? isPantryItem,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expirationDate: expirationDate ?? this.expirationDate,
      addedDate: addedDate ?? this.addedDate,
      isSelected: isSelected ?? this.isSelected,
      isPantryItem: isPantryItem ?? this.isPantryItem,
    );
  }

  factory PantryItem.fromSpoonacularItem(
    Map<String, dynamic> item, // This is a Spoonacular search result item
    String category, {
    double quantity = 1.0,
    UnitType? unit,
    DateTime? expirationDate,
    bool isFoodPantryItem = true,
  }) {
    unit ??= getDefaultUnitForCategory(category);
    expirationDate ??= calculateDefaultExpirationDate(category);

    return PantryItem(
      id: item['id'].toString(), // Spoonacular ID
      name: item['name'] ?? 'Unknown Item',
      imageUrl: ImageUrlHelper.getValidImageUrl(item['image']),
      category: category,
      quantity: quantity,
      unit: unit,
      expirationDate: expirationDate,
      isPantryItem: isFoodPantryItem,
    );
  }

  factory PantryItem.fromIngredient(
    Ingredient ingredient,
    String category, {
    double quantity = 1.0,
    UnitType? unit,
    DateTime? expirationDate,
    bool isFoodPantryItem = true,
  }) {
    unit ??= getDefaultUnitForCategory(category);
    expirationDate ??= calculateDefaultExpirationDate(category);

    return PantryItem(
      id: ingredient.id.toString(), // Spoonacular ID
      name: ingredient.name,
      imageUrl: ImageUrlHelper.getValidImageUrl(ingredient.imageUrl),
      category: category,
      quantity: quantity,
      unit: unit,
      expirationDate: expirationDate,
      isPantryItem: isFoodPantryItem,
    );
  }

  // Converts this PantryItem to a Map suitable for MongoDBService itemData argument
  Map<String, dynamic> toMap() {
    // Renamed from toMapForMongoDBService
    return {
      // MongoDBService adds _id, userId, addedDate, updatedAt itself.
      // We provide the core item data.
      'name': name,
      'category': category,
      'quantity': quantity
          .toString(), // MongoDBService might expect string quantity from old model
      'unit':
          unitLabel, // Convert UnitType enum to string label e.g. "lb", "kg"
      'expiryDate': expirationDate
          .toIso8601String(), // Use 'expiryDate' key as per old model
      'imageUrl': imageUrl,
      'isPantryItem': isPantryItem,
    };
  }

  // Creates a PantryItem from a Map retrieved by MongoDBService
  factory PantryItem.fromMap(Map<String, dynamic> map) {
    double qty = 1.0;
    if (map['quantity'] != null) {
      if (map['quantity'] is double) {
        qty = map['quantity'];
      } else if (map['quantity'] is String) {
        qty = double.tryParse(map['quantity']) ?? 1.0;
      } else if (map['quantity'] is int) {
        qty = (map['quantity'] as int).toDouble();
      }
    }

    // Use robust ObjectId handling for ID parsing
    String itemId;
    try {
      if (map['_id'] != null) {
        // Try to parse the MongoDB _id using ObjectIdHelper
        if (ObjectIdHelper.isValidObjectId(map['_id'])) {
          itemId = ObjectIdHelper.toHexString(map['_id']);
        } else {
          // If _id is not a valid ObjectId format, create a deterministic one
          itemId = ObjectIdHelper.convertTimestampToObjectIdHex(
              DateTime.now().millisecondsSinceEpoch);
        }
      } else if (map['id'] != null) {
        // Try to parse the id field
        if (ObjectIdHelper.isValidObjectId(map['id'])) {
          itemId = ObjectIdHelper.toHexString(map['id']);
        } else {
          // If id is not a valid ObjectId format, create a deterministic one
          itemId = ObjectIdHelper.convertTimestampToObjectIdHex(
              DateTime.now().millisecondsSinceEpoch);
        }
      } else {
        // No ID found, create a new one
        itemId = ObjectIdHelper.generateNew().toHexString();
      }
    } catch (e) {
      // If all else fails, create a new ObjectId
      itemId = ObjectIdHelper.generateNew().toHexString();
    }

    return PantryItem(
      id: itemId,
      name: map['name'] ?? 'Unknown Item',
      imageUrl: ImageUrlHelper.getValidImageUrl(map['imageUrl']),
      category: map['category'] ?? 'General',
      quantity: qty,
      unit: _parseUnitFromString(map['unit']),
      expirationDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'])
          : DateTime.now().add(const Duration(days: 7)), // Default expiry
      addedDate: map['addedDate'] != null
          ? DateTime.parse(map['addedDate'])
          : DateTime.now(),
      isPantryItem: map['isPantryItem'] ?? true,
      isSelected: false, // isSelected is a UI state, not stored in DB
    );
  }

  // Legacy compatibility - toJson (used by PantryController's conversion methods)
  Map<String, dynamic> toJson() => toMap(); // toMap now serves this purpose

  // Legacy compatibility - fromJson (used by PantryController's conversion methods)
  factory PantryItem.fromJson(Map<String, dynamic> json) =>
      PantryItem.fromMap(json);

  static UnitType _parseUnitFromString(String? unitStr) {
    if (unitStr == null) return UnitType.piece;
    String lowerUnit = unitStr.toLowerCase();
    for (UnitType type in UnitType.values) {
      if (type.toString().split('.').last == lowerUnit ||
          _getUnitLabel(type).toLowerCase() == lowerUnit) {
        return type;
      }
    }
    return UnitType.piece; // Default
  }

  static String _getUnitLabel(UnitType unit) {
    switch (unit) {
      case UnitType.pound:
        return 'lb';
      case UnitType.ounces:
        return 'oz';
      case UnitType.gallon:
        return 'gal';
      case UnitType.milliliter:
        return 'ml';
      case UnitType.liter:
        return 'L';
      case UnitType.piece:
        return 'pc';
      case UnitType.grams:
        return 'g';
      case UnitType.kilograms:
        return 'kg';
      case UnitType.cup:
        return 'cup';
      case UnitType.tablespoon:
        return 'tbsp';
      case UnitType.teaspoon:
        return 'tsp';
      default:
        return '';
    }
  }

  static UnitType getDefaultUnitForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'fresh_fruits':
        return UnitType.piece;
      case 'canned_fruits':
        return UnitType.ounces;
      case 'fresh_veggies':
        return UnitType.pound;
      case 'canned_veggies':
        return UnitType.ounces;
      case 'grains':
        return UnitType.pound;
      case 'protein':
        return UnitType.pound;
      case 'dairy':
        return UnitType.ounces;
      case 'seasonings':
        return UnitType.ounces;
      case 'oils':
        return UnitType.ounces;
      case 'baking':
        return UnitType.cup;
      case 'condiments':
        return UnitType.ounces;
      case 'beverages':
        return UnitType.gallon;
      default:
        return UnitType.piece;
    }
  }

  static DateTime calculateDefaultExpirationDate(String category) {
    final now = DateTime.now();
    switch (category.toLowerCase()) {
      case 'fresh_fruits':
        return now.add(const Duration(days: 5));
      case 'canned_fruits':
        return now.add(const Duration(days: 365));
      case 'fresh_veggies':
        return now.add(const Duration(days: 7));
      case 'canned_veggies':
        return now.add(const Duration(days: 365));
      case 'grains':
        return now.add(const Duration(days: 180));
      case 'protein':
        if (category.contains('fish') || category.contains('seafood')) {
          return now.add(const Duration(days: 2));
        }
        if (category.contains('beef') ||
            category.contains('pork') ||
            category.contains('chicken')) {
          return now.add(const Duration(days: 3));
        }
        return now.add(const Duration(days: 5));
      case 'dairy':
        return now.add(const Duration(days: 7));
      case 'seasonings':
        return now.add(const Duration(days: 365));
      case 'oils':
        return now.add(const Duration(days: 180));
      case 'baking':
        return now.add(const Duration(days: 180));
      case 'condiments':
        return now.add(const Duration(days: 180));
      case 'beverages':
        return now.add(const Duration(days: 7));
      default:
        return now.add(const Duration(days: 7));
    }
  }

  String get unitLabel => _getUnitLabel(unit);

  String get quantityDisplay {
    return 'QTY: ${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 1)} ${unitLabel.toUpperCase()}';
  }
}
