import 'package:flutter/foundation.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

// createdAt/readAt/sentAt are always UTC instants server-side (Node's
// `new Date()` and Python's `datetime.now(timezone.utc)` both are), but the
// Python backend's Motor client deserializes BSON dates as *naive* datetimes
// (no tz_aware=True), so a notification created by the Node Cloud Functions
// round-trips through the API as an ISO string with no "Z"/offset -- e.g.
// "2026-09-16T17:45:00.000000". `DateTime.parse` treats an offset-less
// string as LOCAL time, silently shifting the instant it represents by the
// device's UTC offset (on a UTC-negative device, into the apparent future).
// That's what made a real 36-minute-old notification compute a *negative*
// age and fall through to "Just now". Forcing UTC here fixes it at the
// parsing boundary rather than papering over it in every display site.
// Not private (and @visibleForTesting) so it's directly unit-testable --
// same rationale as NotificationService.timezoneSyncCacheKey.
@visibleForTesting
DateTime? parseUtcTimestamp(String s) {
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

enum NotificationType {
  expiring_ingredient,
  expired_items,
  tracker_reminder,
  app_inactivity_reminder,
  admin,
  education,
  lunch_reminder_fallback,
  dinner_reminder_fallback,
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
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return parseUtcTimestamp(v.toString()) ?? DateTime.now();
    }

    DateTime? parseDateNullable(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return parseUtcTimestamp(v.toString());
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
      readAt: parseDateNullable(json['readAt']),
      sentAt: parseDateNullable(json['sentAt']),
      createdAt: parseDate(json['createdAt']),
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
