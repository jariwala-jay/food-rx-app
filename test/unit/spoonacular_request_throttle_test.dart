import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';

/// Regression coverage for [SpoonacularRequestThrottle], added after RapidAPI's
/// 2 requests/second rate limit started 429'ing real generation runs. The
/// fallback ladder's sequential tiers, pagination's page-2 follow-ups, and
/// the No-Preference path's two concurrent tier batches all funnel through
/// one shared throttle instance per [SpoonacularRecipeRepository] — this
/// verifies the slot-reservation math directly (via injected clock/delay,
/// no real elapsed time) rather than the full network call.
void main() {
  group('SpoonacularRequestThrottle', () {
    test('the first call needs no wait', () async {
      final throttle = SpoonacularRequestThrottle(
        minInterval: const Duration(milliseconds: 500),
        now: () => DateTime(2026),
        delay: (_) async {},
      );

      expect(await throttle.waitForSlot(), Duration.zero);
    });

    test(
        'a second call at the same instant waits the full minInterval',
        () async {
      final fixedNow = DateTime(2026);
      final throttle = SpoonacularRequestThrottle(
        minInterval: const Duration(milliseconds: 500),
        now: () => fixedNow,
        delay: (_) async {},
      );

      expect(await throttle.waitForSlot(), Duration.zero);
      expect(await throttle.waitForSlot(), const Duration(milliseconds: 500));
    });

    test(
        'concurrent callers queue in call order, each spaced minInterval '
        'apart — the No-Preference path\'s two simultaneous batches never '
        'both slip through in the same instant', () async {
      final fixedNow = DateTime(2026);
      final throttle = SpoonacularRequestThrottle(
        minInterval: const Duration(milliseconds: 500),
        now: () => fixedNow,
        delay: (_) async {},
      );

      // Reservation is synchronous (no await before _nextSlot is updated),
      // so listing three calls together reserves slots in that exact order
      // even though all three "arrive" at the same fixed instant.
      final waits = await Future.wait([
        throttle.waitForSlot(),
        throttle.waitForSlot(),
        throttle.waitForSlot(),
      ]);

      expect(waits, [
        Duration.zero,
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 1000),
      ]);
    });

    test(
        'a call made after minInterval has already naturally elapsed needs '
        'no additional wait — sequential tiers whose own network latency '
        'already exceeds minInterval pay no throttle penalty',
        () async {
      var fixedNow = DateTime(2026);
      final throttle = SpoonacularRequestThrottle(
        minInterval: const Duration(milliseconds: 500),
        now: () => fixedNow,
        delay: (_) async {},
      );

      expect(await throttle.waitForSlot(), Duration.zero);

      // Simulate 600ms of real elapsed time (e.g. the previous call's own
      // network round-trip) before the next call arrives.
      fixedNow = fixedNow.add(const Duration(milliseconds: 600));

      expect(await throttle.waitForSlot(), Duration.zero);
    });

    test('actually awaits the injected delay for the computed wait duration',
        () async {
      final fixedNow = DateTime(2026);
      final delayedFor = <Duration>[];
      final throttle = SpoonacularRequestThrottle(
        minInterval: const Duration(milliseconds: 500),
        now: () => fixedNow,
        delay: (d) async {
          delayedFor.add(d);
        },
      );

      await throttle.waitForSlot();
      await throttle.waitForSlot();

      // Only the second call needed to wait — the first got Duration.zero
      // and returns without ever invoking the injected delay function.
      expect(delayedFor, [const Duration(milliseconds: 500)]);
    });
  });
}
