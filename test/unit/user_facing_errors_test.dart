import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:flutter_app/features/recipes/repositories/spoonacular_recipe_repository.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('recipe generation rate limit (429) surfaces the dedicated message',
        () {
      final error = ApiException(429, recipeRateLimitMessage);
      expect(userFacingErrorMessage(error), recipeRateLimitMessage);
      expect(userFacingErrorMessage(error),
          isNot(contains('check your internet connection')));
    });

    test('a non-rate-limit ApiException surfaces its own message, not the '
        'generic fallback', () {
      final error = ApiException(500, 'Failed to load recipes (Error: 500).');
      expect(userFacingErrorMessage(error),
          'Failed to load recipes (Error: 500).');
    });

    test('an untyped exception falls back to the generic message', () {
      final error = Exception('boom');
      expect(userFacingErrorMessage(error),
          'Something went wrong. Please try again.');
    });

    test('rate limit and generic messages are distinguishable', () {
      final rateLimited = userFacingErrorMessage(
        ApiException(429, recipeRateLimitMessage),
      );
      final generic = userFacingErrorMessage(Exception('boom'));
      expect(rateLimited, isNot(equals(generic)));
    });

    test('a missing API_BASE_URL surfaces the build-config message', () {
      final error =
          const MissingApiConfigurationException('API_BASE_URL is not set');
      expect(userFacingErrorMessage(error),
          'This build is missing configuration. Please contact support.');
    });

    test(
        'an unrelated StateError (e.g. Iterable.firstWhere finding no match) '
        'falls back to the generic message, not the build-config one', () {
      final error = StateError('Bad state: No element');
      expect(userFacingErrorMessage(error),
          'Something went wrong. Please try again.');
    });
  });
}
