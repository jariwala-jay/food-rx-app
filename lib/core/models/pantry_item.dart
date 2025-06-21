class PantryItem {
  final String id;
  final String name;
  final String category;
  final String quantity;
  final String? unit;
  final DateTime? expiryDate;
  final DateTime? addedDate;
  final String? imageUrl;
  final bool isPantryItem; // true = pantry item, false = other item

  PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.unit,
    this.expiryDate,
    this.addedDate,
    this.imageUrl,
    required this.isPantryItem,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    return PantryItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      quantity: json['quantity'] ?? '',
      unit: json['unit'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'])
          : null,
      addedDate:
          json['addedDate'] != null ? DateTime.parse(json['addedDate']) : null,
      imageUrl: json['imageUrl'],
      isPantryItem: json['isPantryItem'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'expiryDate': expiryDate?.toIso8601String(),
      'addedDate': addedDate?.toIso8601String(),
      'imageUrl': imageUrl,
      'isPantryItem': isPantryItem,
    };
  }

  PantryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? quantity,
    String? unit,
    DateTime? expiryDate,
    DateTime? addedDate,
    String? imageUrl,
    bool? isPantryItem,
  }) {
    return PantryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expiryDate: expiryDate ?? this.expiryDate,
      addedDate: addedDate ?? this.addedDate,
      imageUrl: imageUrl ?? this.imageUrl,
      isPantryItem: isPantryItem ?? this.isPantryItem,
    );
  }

  // Validation methods
  bool get isValid {
    return name.isNotEmpty &&
        category.isNotEmpty &&
        quantity.isNotEmpty &&
        (expiryDate == null || expiryDate!.isAfter(DateTime.now()));
  }

  static List<String> get validUnits => [
        'g',
        'kg',
        'ml',
        'l',
        'oz',
        'lb',
        'piece',
        'pieces',
        'cup',
        'cups',
        'tbsp',
        'tsp',
        'pinch'
      ];

  static bool isValidUnit(String? unit) {
    if (unit == null) return true;
    return validUnits.contains(unit.toLowerCase());
  }
}
