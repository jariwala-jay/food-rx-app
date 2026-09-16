import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/features/notifications/views/notification_center_page.dart';

// Regression coverage for two bugs fixed together:
//
// 1. AppNotification.parseUtcTimestamp: notifications created by the Node
//    Cloud Functions (tracker_reminder, expiring_ingredient, etc.) round-trip
//    through the Python backend as a naive-datetime ISO string with no "Z"/
//    offset (Motor deserializes BSON dates without tz_aware=True). Plain
//    DateTime.parse() on such a string is interpreted as LOCAL time instead
//    of UTC, shifting the represented instant by the device's UTC offset --
//    on a UTC-negative device, into the apparent future. A genuinely
//    36-minute-old notification then computed a *negative* age and fell
//    through formatNotificationTimeAgo's "> 0" checks straight to "Just
//    now". parseUtcTimestamp forces UTC interpretation at the parsing
//    boundary so this can't happen regardless of device timezone.
//
// 2. formatNotificationTimeAgo: relative time only for today's notifications
//    (by local calendar date, not difference.inDays), switching to an
//    absolute date once createdAt is on a previous calendar day -- so it
//    never grows into "47d ago" forever, and a notification from just after
//    midnight correctly reads as a date rather than "10m ago", even though
//    very little real time has elapsed.
//
// All DateTime values here are fixed/deterministic -- nothing depends on the
// real system clock or the machine's timezone.
void main() {
  group('formatNotificationTimeAgo', () {
    final now = DateTime(2026, 9, 16, 14, 21, 0); // Sep 16, 2026, 2:21 PM

    test('same instant / a few seconds ago -> Just now', () {
      expect(
        formatNotificationTimeAgo(
          now.subtract(const Duration(seconds: 5)),
          now,
        ),
        'Just now',
      );
      expect(formatNotificationTimeAgo(now, now), 'Just now');
    });

    test('1 minute ago -> 1m ago', () {
      expect(
        formatNotificationTimeAgo(
          now.subtract(const Duration(minutes: 1)),
          now,
        ),
        '1m ago',
      );
    });

    test('36 minutes ago -> 36m ago (the original regression)', () {
      expect(
        formatNotificationTimeAgo(
          now.subtract(const Duration(minutes: 36)),
          now,
        ),
        '36m ago',
      );
    });

    test('59 minutes ago -> 59m ago', () {
      expect(
        formatNotificationTimeAgo(
          now.subtract(const Duration(minutes: 59)),
          now,
        ),
        '59m ago',
      );
    });

    test('1 hour ago -> 1h ago', () {
      expect(
        formatNotificationTimeAgo(now.subtract(const Duration(hours: 1)), now),
        '1h ago',
      );
    });

    test('23 hours ago, still the same calendar day -> 23h ago', () {
      final lateNow = DateTime(2026, 9, 16, 23, 30, 0);
      expect(
        formatNotificationTimeAgo(
          lateNow.subtract(const Duration(hours: 23)),
          lateNow,
        ),
        '23h ago',
      );
    });

    test('yesterday -> Sep 15 (calendar date, not "1d ago")', () {
      expect(
        formatNotificationTimeAgo(DateTime(2026, 9, 15, 10, 0, 0), now),
        'Sep 15',
      );
    });

    test('several days ago -> Sep 10', () {
      expect(
        formatNotificationTimeAgo(DateTime(2026, 9, 10, 10, 0, 0), now),
        'Sep 10',
      );
    });

    test('earlier this year -> Aug 28', () {
      expect(
        formatNotificationTimeAgo(DateTime(2026, 8, 28, 10, 0, 0), now),
        'Aug 28',
      );
    });

    test('previous calendar year -> Sep 16, 2025', () {
      expect(
        formatNotificationTimeAgo(DateTime(2025, 9, 16, 10, 0, 0), now),
        'Sep 16, 2025',
      );
    });

    test('midnight boundary: 11:55 PM yesterday, viewed 12:05 AM today -> Sep 15, not 10m ago', () {
      final justAfterMidnight = DateTime(2026, 9, 16, 0, 5, 0);
      final lateLastNight = DateTime(2026, 9, 15, 23, 55, 0);
      expect(
        formatNotificationTimeAgo(lateLastNight, justAfterMidnight),
        'Sep 15',
      );
    });

    test('future/clock-skewed timestamp -> Just now, never a negative duration', () {
      expect(
        formatNotificationTimeAgo(now.add(const Duration(minutes: 10)), now),
        'Just now',
      );
      expect(
        formatNotificationTimeAgo(now.add(const Duration(days: 2)), now),
        'Just now',
      );
    });
  });

  group('AppNotification.parseUtcTimestamp', () {
    test('explicit UTC timestamp ending in Z parses to the correct instant', () {
      final parsed = parseUtcTimestamp('2026-09-16T17:45:00.000Z');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 9, 16, 17, 45, 0));
    });

    test('explicit +00:00 timestamp parses to the correct instant', () {
      final parsed = parseUtcTimestamp('2026-09-16T17:45:00.000000+00:00');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 9, 16, 17, 45, 0));
    });

    test('naive UTC timestamp with no timezone suffix (the Motor/Node round-trip shape) still parses as UTC', () {
      // No "Z", no offset -- exactly what Motor's naive-datetime
      // deserialization + FastAPI's default isoformat() encoding produces
      // for a notification created by the Node Cloud Functions.
      final parsed = parseUtcTimestamp('2026-09-16T17:45:00.000000');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 9, 16, 17, 45, 0));
    });

    test('all three representations of the same instant parse identically', () {
      final withZ = parseUtcTimestamp('2026-09-16T17:45:00.000Z');
      final withOffset = parseUtcTimestamp('2026-09-16T17:45:00.000000+00:00');
      final naive = parseUtcTimestamp('2026-09-16T17:45:00.000000');
      expect(withZ, withOffset);
      expect(withOffset, naive);
    });

    test('regression: a genuinely 36-minute-old naive-UTC notification must show 36m ago, not Just now', () {
      // "Now" is 2:21 PM UTC-equivalent wall-clock; the notification was
      // created 36 real minutes earlier and reaches the app the same way a
      // Node-created notification does -- via the API as a naive,
      // offset-less ISO string once Motor/FastAPI have round-tripped it.
      final now = DateTime.utc(2026, 9, 16, 14, 21, 0);
      final naiveCreatedAtString = now
          .subtract(const Duration(minutes: 36))
          .toIso8601String()
          .replaceFirst('Z', ''); // simulate the offset-less Motor/FastAPI shape

      final createdAt = parseUtcTimestamp(naiveCreatedAtString);
      expect(createdAt, isNotNull);

      final result = formatNotificationTimeAgo(createdAt!, now);
      expect(result, '36m ago');
      expect(result, isNot('Just now'));
    });
  });
}
