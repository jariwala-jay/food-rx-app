import 'package:flutter_app/core/utils/objectid_helper.dart';

enum NotificationType {
  expiring_ingredient,
  tracker_reminder,
  admin,
  education,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? sentAt;

  AppNotification({
    String? id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.readAt,
    this.sentAt,
    DateTime? createdAt,
  })  : id = id ?? ObjectIdHelper.generateNew().toHexString(),
        createdAt = createdAt ?? DateTime.now();

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.admin,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      'readAt': readAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? createdAt,
    DateTime? readAt,
    DateTime? sentAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }

  bool get isRead => readAt != null;
  bool get isSent => sentAt != null;

  @override
  String toString() {
    return 'AppNotification(id: $id, title: $title, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppNotification && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
