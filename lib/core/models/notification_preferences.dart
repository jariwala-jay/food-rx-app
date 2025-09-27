import 'package:flutter_app/core/utils/objectid_helper.dart';
import 'app_notification.dart';

enum NotificationFrequency {
  low,
  medium,
  high,
}

class NotificationPreferences {
  final String id;
  final String userId;
  final List<NotificationType> enabledTypes;
  final List<NotificationType> disabledTypes;
  final Map<String, String> preferredTimes;
  final NotificationFrequency frequency;
  final int maxDailyNotifications;
  final Map<String, String> quietHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  NotificationPreferences({
    String? id,
    required this.userId,
    List<NotificationType>? enabledTypes,
    List<NotificationType>? disabledTypes,
    Map<String, String>? preferredTimes,
    this.frequency = NotificationFrequency.medium,
    this.maxDailyNotifications = 3,
    Map<String, String>? quietHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? ObjectIdHelper.generateNew().toHexString(),
        enabledTypes = enabledTypes ?? NotificationType.values,
        disabledTypes = disabledTypes ?? [],
        preferredTimes = preferredTimes ??
            {
              'morning': '08:00',
              'afternoon': '14:00',
              'evening': '19:00',
            },
        quietHours = quietHours ??
            {
              'start': '22:00',
              'end': '07:00',
            },
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId'] ?? '',
      enabledTypes: (json['enabledTypes'] as List<dynamic>?)
              ?.map((e) => NotificationType.values.firstWhere(
                    (type) => type.toString().split('.').last == e,
                    orElse: () => NotificationType.system,
                  ))
              .toList() ??
          NotificationType.values,
      disabledTypes: (json['disabledTypes'] as List<dynamic>?)
              ?.map((e) => NotificationType.values.firstWhere(
                    (type) => type.toString().split('.').last == e,
                    orElse: () => NotificationType.system,
                  ))
              .toList() ??
          [],
      preferredTimes: Map<String, String>.from(json['preferredTimes'] ??
          {
            'morning': '08:00',
            'afternoon': '14:00',
            'evening': '19:00',
          }),
      frequency: NotificationFrequency.values.firstWhere(
        (e) => e.toString().split('.').last == json['frequency'],
        orElse: () => NotificationFrequency.medium,
      ),
      maxDailyNotifications: json['maxDailyNotifications'] ?? 3,
      quietHours: Map<String, String>.from(json['quietHours'] ??
          {
            'start': '22:00',
            'end': '07:00',
          }),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'enabledTypes':
          enabledTypes.map((e) => e.toString().split('.').last).toList(),
      'disabledTypes':
          disabledTypes.map((e) => e.toString().split('.').last).toList(),
      'preferredTimes': preferredTimes,
      'frequency': frequency.toString().split('.').last,
      'maxDailyNotifications': maxDailyNotifications,
      'quietHours': quietHours,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotificationPreferences copyWith({
    String? id,
    String? userId,
    List<NotificationType>? enabledTypes,
    List<NotificationType>? disabledTypes,
    Map<String, String>? preferredTimes,
    NotificationFrequency? frequency,
    int? maxDailyNotifications,
    Map<String, String>? quietHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationPreferences(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      disabledTypes: disabledTypes ?? this.disabledTypes,
      preferredTimes: preferredTimes ?? this.preferredTimes,
      frequency: frequency ?? this.frequency,
      maxDailyNotifications:
          maxDailyNotifications ?? this.maxDailyNotifications,
      quietHours: quietHours ?? this.quietHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool isTypeEnabled(NotificationType type) {
    return enabledTypes.contains(type) && !disabledTypes.contains(type);
  }

  void enableType(NotificationType type) {
    if (!enabledTypes.contains(type)) {
      enabledTypes.add(type);
    }
    disabledTypes.remove(type);
  }

  void disableType(NotificationType type) {
    if (!disabledTypes.contains(type)) {
      disabledTypes.add(type);
    }
    enabledTypes.remove(type);
  }

  String getMorningTime() => preferredTimes['morning'] ?? '08:00';
  String getAfternoonTime() => preferredTimes['afternoon'] ?? '14:00';
  String getEveningTime() => preferredTimes['evening'] ?? '19:00';

  String getQuietStartTime() => quietHours['start'] ?? '22:00';
  String getQuietEndTime() => quietHours['end'] ?? '07:00';

  @override
  String toString() {
    return 'NotificationPreferences(userId: $userId, enabledTypes: $enabledTypes, frequency: $frequency)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationPreferences && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
