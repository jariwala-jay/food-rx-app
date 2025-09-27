import 'package:flutter_app/core/utils/objectid_helper.dart';

enum NotificationType {
  healthGoal,
  pantryExpiry,
  education,
  system,
}

enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

enum NotificationCategory {
  dailyProgress,
  streak,
  expiryAlert,
  tip,
  mealReminder,
  onboarding,
  reengagement,
  newContent,
  bookmarkReminder,
  lowStock,
  recipeSuggestion,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final NotificationCategory category;
  final String title;
  final String message;
  final NotificationPriority priority;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final DateTime? readAt;
  final bool actionRequired;
  final Map<String, dynamic>? actionData;
  final Map<String, dynamic>? personalizationData;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppNotification({
    String? id,
    required this.userId,
    required this.type,
    required this.category,
    required this.title,
    required this.message,
    this.priority = NotificationPriority.medium,
    this.scheduledFor,
    this.sentAt,
    this.readAt,
    this.actionRequired = false,
    this.actionData,
    this.personalizationData,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? ObjectIdHelper.generateNew().toHexString(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.system,
      ),
      category: NotificationCategory.values.firstWhere(
        (e) => e.toString().split('.').last == json['category'],
        orElse: () => NotificationCategory.tip,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'],
        orElse: () => NotificationPriority.medium,
      ),
      scheduledFor: json['scheduledFor'] != null
          ? DateTime.parse(json['scheduledFor'])
          : null,
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      actionRequired: json['actionRequired'] ?? false,
      actionData: json['actionData'],
      personalizationData: json['personalizationData'],
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
      'type': type.toString().split('.').last,
      'category': category.toString().split('.').last,
      'title': title,
      'message': message,
      'priority': priority.toString().split('.').last,
      'scheduledFor': scheduledFor?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'actionRequired': actionRequired,
      'actionData': actionData,
      'personalizationData': personalizationData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    NotificationCategory? category,
    String? title,
    String? message,
    NotificationPriority? priority,
    DateTime? scheduledFor,
    DateTime? sentAt,
    DateTime? readAt,
    bool? actionRequired,
    Map<String, dynamic>? actionData,
    Map<String, dynamic>? personalizationData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      category: category ?? this.category,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      actionRequired: actionRequired ?? this.actionRequired,
      actionData: actionData ?? this.actionData,
      personalizationData: personalizationData ?? this.personalizationData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isRead => readAt != null;
  bool get isSent => sentAt != null;
  bool get isScheduled => scheduledFor != null && sentAt == null;

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, type: $type, category: $category, priority: $priority)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
