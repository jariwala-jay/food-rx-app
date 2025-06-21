import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

// Helper function to safely convert dynamic values to double
double _parseDoubleValue(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  // Fallback for other types, like Int64, by converting to String first
  return double.tryParse(value.toString()) ?? 0.0;
}

// Helper function to safely convert dynamic values to int
int? _parseIntValue(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  if (value is num) return value.toInt();
  // Fallback for other types, like Int64, by converting to String first
  return int.tryParse(value.toString());
}

String getTrackerIconAsset(TrackerCategory category) {
  switch (category) {
    case TrackerCategory.veggies:
      return 'assets/icons/tracker_icons/veggies.svg';
    case TrackerCategory.fruits:
      return 'assets/icons/tracker_icons/fruits.svg';
    case TrackerCategory.protein:
    case TrackerCategory.leanMeat:
      return 'assets/icons/tracker_icons/protein.svg';
    case TrackerCategory.grains:
      return 'assets/icons/tracker_icons/grains.svg';
    case TrackerCategory.dairy:
      return 'assets/icons/tracker_icons/dairy.svg';
    case TrackerCategory.water:
      return 'assets/icons/tracker_icons/water.svg';
    case TrackerCategory.fatsOils:
      return 'assets/icons/tracker_icons/fats.png';
    case TrackerCategory.sweets:
      return 'assets/icons/tracker_icons/sweets.png';
    case TrackerCategory.nutsLegumes:
      return 'assets/icons/tracker_icons/nuts.png';
    case TrackerCategory.sodium:
      return 'assets/icons/tracker_icons/sodium.png';
    default:
      return 'assets/icons/tracker_icons/veggies.svg';
  }
}

/// Types of trackers for different diet plans
enum TrackerCategory {
  veggies,
  fruits,
  protein,
  grains,
  dairy,
  water,
  leanMeat,
  fatsOils,
  sweets,
  nutsLegumes,
  sodium,
  cholesterol,
  fiber,
  other
}

/// Units for trackers
enum TrackerUnit { cups, servings, oz, g, mg, ml, percent, count }

/// TrackerGoal represents a nutritional target that a user should aim for
class TrackerGoal {
  final String id;
  final String userId;
  final String name;
  final TrackerCategory category;
  final double goalValue;
  double currentValue;
  final TrackerUnit unit;
  final Color? colorStart;
  final Color? colorEnd;
  final String dietType; // "DASH" or "MyPlate"
  final bool isWeeklyGoal; // Daily vs Weekly
  DateTime lastUpdated;
  final DateTime createdAt;

  TrackerGoal({
    String? id,
    required this.userId,
    required this.name,
    required this.category,
    required this.goalValue,
    this.currentValue = 0.0,
    required this.unit,
    this.colorStart,
    this.colorEnd,
    required this.dietType,
    this.isWeeklyGoal = false,
    DateTime? lastUpdated,
    DateTime? createdAt,
  })  : id = id ?? ObjectId().toHexString(),
        lastUpdated = lastUpdated ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// Calculate the progress percentage (can be greater than 1.0 for over 100%)
  double get progress => goalValue > 0 ? (currentValue / goalValue) : 0.0;

  /// Get the formatted current value with unit (e.g., "1/3 Cups")
  String get formattedProgress {
    return "${currentValue.toStringAsFixed(currentValue.truncateToDouble() == currentValue ? 0 : 1)}/${goalValue.toStringAsFixed(goalValue.truncateToDouble() == goalValue ? 0 : 1)} $unitString";
  }

  /// Format the unit for display
  String get unitString {
    switch (unit) {
      case TrackerUnit.cups:
        return "Cups";
      case TrackerUnit.servings:
        return "Servings";
      case TrackerUnit.oz:
        return "oz";
      case TrackerUnit.g:
        return "g";
      case TrackerUnit.mg:
        return "mg";
      case TrackerUnit.ml:
        return "ml";
      case TrackerUnit.percent:
        return "%";
      case TrackerUnit.count:
        return "";
    }
  }

  // Convert from JSON
  factory TrackerGoal.fromJson(Map<String, dynamic> json) {
    final id = json['_id']?.toString();
    final userId = json['userId']?.toString();

    if (id == null) {
      throw ArgumentError.notNull("id in TrackerGoal.fromJson");
    }
    if (userId == null) {
      throw ArgumentError.notNull("userId in TrackerGoal.fromJson");
    }

    String categoryStr = json['category']?.toString() ?? 'other';
    // Handle the case where category comes with the enum prefix
    if (categoryStr.contains('.')) {
      categoryStr = categoryStr.split('.').last;
    }

    String unitStr = json['unit']?.toString() ?? 'servings';
    // Handle the case where unit comes with the enum prefix
    if (unitStr.contains('.')) {
      unitStr = unitStr.split('.').last;
    }

    return TrackerGoal(
      id: id,
      userId: userId,
      name: json['name'] ?? 'Unnamed Goal',
      category: TrackerCategory.values.firstWhere(
        (e) => e.toString().split('.').last == categoryStr,
        orElse: () => TrackerCategory.other,
      ),
      goalValue: _parseDoubleValue(json['goalValue']),
      currentValue: _parseDoubleValue(json['currentValue']),
      unit: TrackerUnit.values.firstWhere(
        (e) => e.toString().split('.').last == unitStr,
        orElse: () => TrackerUnit.servings,
      ),
      colorStart: json['colorStart'] != null
          ? Color(_parseIntValue(json['colorStart'])!)
          : null,
      colorEnd: json['colorEnd'] != null
          ? Color(_parseIntValue(json['colorEnd'])!)
          : null,
      dietType: json['dietType'] ?? 'MyPlate',
      isWeeklyGoal: json['isWeeklyGoal'] ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'name': name,
      'category': category.toString().split('.').last,
      'goalValue': goalValue,
      'currentValue': currentValue,
      'unit': unit.toString().split('.').last,
      'colorStart': colorStart?.value,
      'colorEnd': colorEnd?.value,
      'dietType': dietType,
      'isWeeklyGoal': isWeeklyGoal,
      'lastUpdated': lastUpdated.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create a copy with updated values
  TrackerGoal copyWith({
    String? id,
    String? userId,
    String? name,
    TrackerCategory? category,
    double? goalValue,
    double? currentValue,
    TrackerUnit? unit,
    Color? colorStart,
    Color? colorEnd,
    String? dietType,
    bool? isWeeklyGoal,
    DateTime? lastUpdated,
    DateTime? createdAt,
  }) {
    return TrackerGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      category: category ?? this.category,
      goalValue: goalValue ?? this.goalValue,
      currentValue: currentValue ?? this.currentValue,
      unit: unit ?? this.unit,
      colorStart: colorStart ?? this.colorStart,
      colorEnd: colorEnd ?? this.colorEnd,
      dietType: dietType ?? this.dietType,
      isWeeklyGoal: isWeeklyGoal ?? this.isWeeklyGoal,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
