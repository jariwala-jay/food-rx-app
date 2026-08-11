import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';

// The verified https App-Link/Universal-Link path carries the token in the
// URL *fragment* (#token=...), not a query string, since browsers never
// transmit the fragment to the server. The foodrx:// fallback keeps using a
// query string — it's an OS-level intent, never an HTTP request.
const _apiHost = 'foodrx-api-609996001749.us-central1.run.app';

void main() {
  group('extractPasswordResetToken — verified https App Link (fragment)', () {
    test('extracts token from #token=... fragment', () {
      final uri = Uri.parse(
        'https://$_apiHost/auth/reset-password/open#token=abc123',
      );
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        'abc123',
      );
    });

    test('round-trips a base64-shaped token containing +, /, = once percent-encoded', () {
      // Matches the backend's urllib.parse.quote(token, safe=''), which
      // percent-encodes '+', '/', '=' — proves Uri.splitQueryString's
      // "+ means space" rule doesn't corrupt this (no literal '+' survives).
      const rawToken = 'AbC+de/f==';
      const percentEncoded = 'AbC%2Bde%2Ff%3D%3D';
      final uri = Uri.parse(
        'https://$_apiHost/auth/reset-password/open#token=$percentEncoded',
      );
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        rawToken,
      );
    });

    test('does NOT read the token from a query string on the https path', () {
      final uri = Uri.parse(
        'https://$_apiHost/auth/reset-password/open?token=leaked123',
      );
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null when the fragment is missing', () {
      final uri = Uri.parse('https://$_apiHost/auth/reset-password/open');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null when the fragment has no token key', () {
      final uri = Uri.parse(
        'https://$_apiHost/auth/reset-password/open#somethingElse=1',
      );
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null for the wrong host (not our verified domain)', () {
      final uri = Uri.parse(
        'https://evil.example/auth/reset-password/open#token=abc123',
      );
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null for the wrong path on the right host', () {
      final uri = Uri.parse('https://$_apiHost/something/else#token=abc123');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });
  });

  group('extractPasswordResetToken — foodrx:// custom-scheme fallback', () {
    test('extracts token from foodrx://reset-password?token=... (query string)', () {
      final uri = Uri.parse('foodrx://reset-password?token=abc123');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        'abc123',
      );
    });

    test('extracts token from foodrx://?token=... (no host form)', () {
      final uri = Uri.parse('foodrx://?token=abc123');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        'abc123',
      );
    });

    test('round-trips a base64-shaped token via query-string percent-encoding', () {
      const rawToken = 'AbC+de/f==';
      const percentEncoded = 'AbC%2Bde%2Ff%3D%3D';
      final uri = Uri.parse('foodrx://reset-password?token=$percentEncoded');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        rawToken,
      );
    });

    test('returns null when foodrx:// link has no token', () {
      final uri = Uri.parse('foodrx://reset-password');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null for an empty token value', () {
      final uri = Uri.parse('foodrx://reset-password?token=');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null for an unrelated foodrx:// host even with a token param', () {
      final uri = Uri.parse('foodrx://evil-host?token=attacker-controlled');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });
  });

  group('extractPasswordResetToken — unrelated links', () {
    test('returns null for a scheme that is neither https nor foodrx', () {
      final uri = Uri.parse('mailto:someone@example.com');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });

    test('returns null for an unrelated https link even with a token param', () {
      final uri = Uri.parse('https://$_apiHost/some/other/route?token=abc123');
      expect(
        extractPasswordResetToken(uri, verifiedResetHost: _apiHost),
        isNull,
      );
    });
  });
}
