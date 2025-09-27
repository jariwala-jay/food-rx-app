import 'package:flutter_app/core/utils/objectid_helper.dart';

enum NotificationAction {
  sent,
  delivered,
  opened,
  clicked,
  dismissed,
}

class NotificationAnalytics {
  final String id;
  final String userId;
  final String notificationId;
  final NotificationAction action;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  NotificationAnalytics({
    String? id,
    required this.userId,
    required this.notificationId,
    required this.action,
    DateTime? timestamp,
    this.metadata,
  })  : id = id ?? ObjectIdHelper.generateNew().toHexString(),
        timestamp = timestamp ?? DateTime.now();

  factory NotificationAnalytics.fromJson(Map<String, dynamic> json) {
    return NotificationAnalytics(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      userId: json['userId'] ?? '',
      notificationId: json['notificationId'] ?? '',
      action: NotificationAction.values.firstWhere(
        (e) => e.toString().split('.').last == json['action'],
        orElse: () => NotificationAction.sent,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'notificationId': notificationId,
      'action': action.toString().split('.').last,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  NotificationAnalytics copyWith({
    String? id,
    String? userId,
    String? notificationId,
    NotificationAction? action,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationAnalytics(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      notificationId: notificationId ?? this.notificationId,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  String toString() {
    return 'NotificationAnalytics(userId: $userId, notificationId: $notificationId, action: $action)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationAnalytics && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
