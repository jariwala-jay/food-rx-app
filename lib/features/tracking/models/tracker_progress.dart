import 'package:flutter_app/core/utils/objectid_helper.dart';

/// TrackerProgress represents a completed tracking period (daily/weekly)
/// Used for analytics and historical data while TrackerGoal handles real-time tracking
class TrackerProgress {
  final String id;
  final String userId;
  final String trackerId; // Reference to the original TrackerGoal
  final String trackerName;
  final String trackerCategory;
  final double targetValue; // What the goal was
  final double achievedValue; // What the user actually achieved
  final DateTime progressDate; // Date this progress period ended
  final ProgressPeriodType periodType; // Daily or Weekly
  final String dietType; // DASH or MyPlate
  final String unit; // cups, servings, etc.
  final double completionPercentage; // achievedValue / targetValue * 100
  final bool goalMet; // true if achievedValue >= targetValue
  final DateTime createdAt;

  TrackerProgress({
    String? id,
    required this.userId,
    required this.trackerId,
    required this.trackerName,
    required this.trackerCategory,
    required this.targetValue,
    required this.achievedValue,
    required this.progressDate,
    required this.periodType,
    required this.dietType,
    required this.unit,
    DateTime? createdAt,
  })  : id = id ?? ObjectIdHelper.generateNew().toHexString(),
        completionPercentage =
            targetValue > 0 ? (achievedValue / targetValue * 100) : 0.0,
        goalMet = achievedValue >= targetValue,
        createdAt = createdAt ?? DateTime.now();

  // Convert from JSON
  factory TrackerProgress.fromJson(Map<String, dynamic> json) {
    return TrackerProgress(
      id: json['_id'] != null 
        ? ObjectIdHelper.toHexString(json['_id'])
        : ObjectIdHelper.generateNew().toHexString(),
      userId: json['userId']?.toString() ?? '',
      trackerId: json['trackerId']?.toString() ?? '',
      trackerName: json['trackerName']?.toString() ?? '',
      trackerCategory: json['trackerCategory']?.toString() ?? '',
      targetValue: _parseDoubleValue(json['targetValue']),
      achievedValue: _parseDoubleValue(json['achievedValue']),
      progressDate: json['progressDate'] != null
          ? DateTime.parse(json['progressDate'])
          : DateTime.now(),
      periodType: ProgressPeriodType.values.firstWhere(
        (e) => e.toString().split('.').last == json['periodType'],
        orElse: () => ProgressPeriodType.daily,
      ),
      dietType: json['dietType']?.toString() ?? 'MyPlate',
      unit: json['unit']?.toString() ?? 'servings',
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
      'trackerId': trackerId,
      'trackerName': trackerName,
      'trackerCategory': trackerCategory,
      'targetValue': targetValue,
      'achievedValue': achievedValue,
      'progressDate': progressDate.toIso8601String(),
      'periodType': periodType.toString().split('.').last,
      'dietType': dietType,
      'unit': unit,
      'completionPercentage': completionPercentage,
      'goalMet': goalMet,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  TrackerProgress copyWith({
    String? id,
    String? userId,
    String? trackerId,
    String? trackerName,
    String? trackerCategory,
    double? targetValue,
    double? achievedValue,
    DateTime? progressDate,
    ProgressPeriodType? periodType,
    String? dietType,
    String? unit,
    DateTime? createdAt,
  }) {
    return TrackerProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trackerId: trackerId ?? this.trackerId,
      trackerName: trackerName ?? this.trackerName,
      trackerCategory: trackerCategory ?? this.trackerCategory,
      targetValue: targetValue ?? this.targetValue,
      achievedValue: achievedValue ?? this.achievedValue,
      progressDate: progressDate ?? this.progressDate,
      periodType: periodType ?? this.periodType,
      dietType: dietType ?? this.dietType,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'TrackerProgress($trackerName: $achievedValue/$targetValue $unit - ${completionPercentage.toStringAsFixed(1)}%)';
  }
}

/// Period type for progress tracking
enum ProgressPeriodType { daily, weekly }

/// Helper function to safely convert dynamic values to double
double _parseDoubleValue(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
