import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/notification_service.dart';

// Regression coverage for scoping the "last synced timezone" cache key per
// user: a global key meant a shared/reused device could skip a genuinely
// unsynced account's first sync just because a different account already
// wrote a matching zone under the same key.
void main() {
  group('NotificationService.timezoneSyncCacheKey', () {
    test('includes the userId, not just the base key', () {
      final key = NotificationService.timezoneSyncCacheKey('user123');
      expect(key, contains('user123'));
    });

    test('different users get different cache keys', () {
      final keyA = NotificationService.timezoneSyncCacheKey('userA');
      final keyB = NotificationService.timezoneSyncCacheKey('userB');
      expect(keyA, isNot(equals(keyB)));
    });

    test('the same user always gets the same cache key', () {
      expect(
        NotificationService.timezoneSyncCacheKey('user123'),
        NotificationService.timezoneSyncCacheKey('user123'),
      );
    });
  });
}
