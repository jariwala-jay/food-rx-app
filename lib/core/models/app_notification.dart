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
    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.parse(v.toString());
    }

    DateTime? _parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }

    return AppNotification(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId']?.toString() ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => NotificationType.admin,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      readAt: _parseDateNullable(json['readAt']),
      sentAt: _parseDateNullable(json['sentAt']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'message': message,
      // Store as BSON Date (Mongo will accept Dart DateTime directly)
      'readAt': readAt,
      'sentAt': sentAt,
      'createdAt': createdAt,
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
