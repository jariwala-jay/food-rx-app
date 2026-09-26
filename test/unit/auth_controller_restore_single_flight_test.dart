import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_app/core/services/session_storage.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

// initialize() and a `resumed` lifecycle event could each start a session
// restore while the first /auth/me was still pending, sending /auth/me twice
// at launch. These tests drive the real AuthController against a fake backend
// to pin that concurrent restores share one attempt, without changing what a
// restore does (refresh on 401, clear on invalid refresh, Google onboarding,
// and resume recovery after a failed launch restore).

const _userId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const _email = 'user@test.com';

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, dynamic> _userJson(
        {bool google = false, String? dietType = 'DASH'}) =>
    {
      '_id': _userId,
      'email': _email,
      'name': 'Test User',
      if (google) 'authProvider': 'google',
      if (dietType != null) 'dietType': dietType,
    };

class _FakeBackend {
  int meCalls = 0;
  int refreshCalls = 0;

  /// Response for the Nth (1-based) GET /auth/me; may await or throw.
  Future<http.Response> Function(int call) onMe =
      (_) async => _json(200, _userJson());

  /// Defaults to a rejected refresh token.
  Future<http.Response> Function() onRefresh =
      () async => _json(401, {'detail': 'Invalid or expired refresh token'});

  http.Client client() => MockClient((req) async {
        switch ('${req.method} ${req.url.path}') {
          case 'GET /auth/me':
            meCalls++;
            return onMe(meCalls);
          case 'POST /auth/refresh':
            refreshCalls++;
            return onRefresh();
          case 'GET /notifications':
            return http.Response('[]', 200);
          default:
            // /auth/logout, PATCH /auth/profile (heartbeat, FCM, timezone), ...
            return _json(200, {});
        }
      });
}

void _seedSession() {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'old-access',
    'refresh_token': 'old-refresh',
    'user_id': _userId,
    'user_email': _email,
  });
}

Future<void> _run(
  _FakeBackend backend,
  Future<void> Function(AuthController auth) body,
) {
  return http.runWithClient(() async {
    _seedSession();
    final auth = AuthController();
    try {
      await body(auth);
    } finally {
      // Cancels the static onUnauthorized subscription so controllers from
      // earlier tests can't react to a later test's forced sign-out.
      auth.dispose();
    }
  }, backend.client);
}

Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

// Lets resumeSessionIfNeeded() get past its secure-storage checks and reach
// the restore before the test asserts on how many /auth/me calls were made.
Future<void> _letResumeReachRestore() =>
    Future<void>.delayed(const Duration(milliseconds: 100));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.test');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('initial restore', () {
    test('valid stored credentials: one /auth/me, authenticated, loading done',
        () async {
      final backend = _FakeBackend();
      await _run(backend, (auth) async {
        await auth.initialize();

        expect(backend.meCalls, 1);
        expect(auth.isAuthenticated, isTrue);
        expect(auth.isLoading, isFalse);
        expect(auth.currentUser?.email, _email);
        expect(auth.pendingGoogleOnboarding, isNull);
      });
    });
  });

  group('concurrent resume while a restore is in flight', () {
    test('shares the restore: exactly one /auth/me, both callers finish',
        () async {
      final gate = Completer<void>();
      final backend = _FakeBackend()
        ..onMe = (_) async {
          await gate.future;
          return _json(200, _userJson());
        };

      await _run(backend, (auth) async {
        final init = auth.initialize();
        await _waitFor(() => backend.meCalls == 1);

        final resume = auth.resumeSessionIfNeeded();
        await _letResumeReachRestore();

        expect(backend.meCalls, 1,
            reason: 'resume must not start a second /auth/me');
        expect(auth.isAuthenticated, isFalse,
            reason: 'a running restore is not an authenticated session');
        expect(auth.isLoading, isTrue);

        gate.complete();
        await Future.wait([init, resume]);

        expect(backend.meCalls, 1);
        expect(auth.isAuthenticated, isTrue);
        expect(auth.isLoading, isFalse);
        expect(auth.error, isNull);
      });
    });

    test('shares a failed restore too, then a later resume can retry',
        () async {
      final gate = Completer<void>();
      var healthy = false;
      final backend = _FakeBackend()
        ..onMe = (_) async {
          await gate.future;
          return healthy
              ? _json(200, _userJson())
              : _json(500, {'detail': 'down'});
        };

      await _run(backend, (auth) async {
        final init = auth.initialize();
        await _waitFor(() => backend.meCalls == 1);
        final resume = auth.resumeSessionIfNeeded();
        await _letResumeReachRestore();

        gate.complete();
        await Future.wait([init, resume]);

        expect(backend.meCalls, 1);
        expect(auth.isAuthenticated, isFalse);
        expect(auth.isLoading, isFalse);

        healthy = true;
        await auth.resumeSessionIfNeeded();

        expect(backend.meCalls, 2,
            reason: 'in-flight state must be cleared after a failure');
        expect(auth.isAuthenticated, isTrue);
      });
    });
  });

  group('resume recovery after a failed launch restore', () {
    test('transient network failure keeps credentials; resume restores later',
        () async {
      var online = false;
      final backend = _FakeBackend()
        ..onMe = (_) async {
          if (!online) throw const SocketException('offline');
          return _json(200, _userJson());
        };

      await _run(backend, (auth) async {
        await auth.initialize();

        // 5 attempts: _fetchAuthMeWithRetries retries transient errors.
        expect(backend.meCalls, 5);
        expect(auth.isAuthenticated, isFalse);
        expect(auth.isLoading, isFalse);
        expect(auth.error, isNotNull);
        expect(await SessionStorage.hasRefreshToken(), isTrue,
            reason: 'transient failure must not wipe stored credentials');

        online = true;
        await auth.resumeSessionIfNeeded();

        expect(backend.meCalls, 6,
            reason: 'resume must attempt a fresh restore');
        expect(auth.isAuthenticated, isTrue);
        expect(auth.error, isNull);
      });
    });

    test('in-flight state is cleared after a failure; each resume retries',
        () async {
      var healthy = false;
      final backend = _FakeBackend()
        ..onMe = (_) async =>
            healthy ? _json(200, _userJson()) : _json(500, {'detail': 'down'});

      await _run(backend, (auth) async {
        await auth.initialize();
        expect(backend.meCalls, 1);
        expect(auth.isAuthenticated, isFalse);
        expect(auth.error, contains('Failed to restore session'));

        await auth.resumeSessionIfNeeded();
        expect(backend.meCalls, 2);
        expect(auth.isAuthenticated, isFalse);

        healthy = true;
        await auth.resumeSessionIfNeeded();
        expect(backend.meCalls, 3);
        expect(auth.isAuthenticated, isTrue);
      });
    });
  });

  group('token refresh and invalid sessions are unchanged', () {
    test('expired access token: 401, refresh, retry; new tokens stored',
        () async {
      final backend = _FakeBackend()
        ..onMe = (call) async {
          return call == 1
              ? _json(401, {'detail': 'Invalid or expired token'})
              : _json(200, _userJson());
        }
        ..onRefresh = () async => _json(200, {
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
              'user_id': _userId,
              'email': _email,
            });

      await _run(backend, (auth) async {
        await auth.initialize();

        expect(backend.refreshCalls, 1);
        expect(backend.meCalls, 2);
        expect(auth.isAuthenticated, isTrue);
        expect(await SessionStorage.getAccessToken(), 'new-access');
        expect(await SessionStorage.getRefreshToken(), 'new-refresh');
      });
    });

    test('concurrent resume during a 401 refresh: one refresh, two /auth/me',
        () async {
      final refreshGate = Completer<void>();
      final backend = _FakeBackend()
        ..onMe = (call) async {
          return call == 1
              ? _json(401, {'detail': 'Invalid or expired token'})
              : _json(200, _userJson());
        }
        ..onRefresh = () async {
          await refreshGate.future;
          return _json(200, {
            'access_token': 'new-access',
            'refresh_token': 'new-refresh',
            'user_id': _userId,
            'email': _email,
          });
        };

      await _run(backend, (auth) async {
        final init = auth.initialize();
        await _waitFor(() => backend.refreshCalls == 1);
        final resume = auth.resumeSessionIfNeeded();
        await _letResumeReachRestore();

        refreshGate.complete();
        await Future.wait([init, resume]);

        expect(backend.refreshCalls, 1);
        expect(backend.meCalls, 2, reason: 'the 401 and its single retry only');
        expect(auth.isAuthenticated, isTrue);
      });
    });

    test('invalid refresh token clears the session and ends unauthenticated',
        () async {
      final backend = _FakeBackend()
        ..onMe =
            (_) async => _json(401, {'detail': 'Invalid or expired token'});

      await _run(backend, (auth) async {
        await auth.initialize();

        expect(auth.isAuthenticated, isFalse);
        expect(auth.isLoading, isFalse);
        expect(await SessionStorage.getRefreshToken(), isNull);
        expect(await SessionStorage.getAccessToken(), isNull);
        expect(await SessionStorage.getUserId(), isNull);
      });
    });
  });

  group('Google onboarding detection is unchanged', () {
    test('Google account without a dietType resumes onboarding', () async {
      final backend = _FakeBackend()
        ..onMe =
            (_) async => _json(200, _userJson(google: true, dietType: null));

      await _run(backend, (auth) async {
        await auth.initialize();

        expect(auth.pendingGoogleOnboarding, isNotNull);
        expect(auth.pendingGoogleOnboarding?.email, _email);
      });
    });

    test('completed Google account goes straight to Home', () async {
      final backend = _FakeBackend()
        ..onMe = (_) async => _json(200, _userJson(google: true));

      await _run(backend, (auth) async {
        await auth.initialize();

        expect(auth.isAuthenticated, isTrue);
        expect(auth.pendingGoogleOnboarding, isNull);
      });
    });

    test('a resume that shares the restore sees the same onboarding result',
        () async {
      final gate = Completer<void>();
      final backend = _FakeBackend()
        ..onMe = (_) async {
          await gate.future;
          return _json(200, _userJson(google: true, dietType: null));
        };

      await _run(backend, (auth) async {
        final init = auth.initialize();
        await _waitFor(() => backend.meCalls == 1);
        final resume = auth.resumeSessionIfNeeded();
        await _letResumeReachRestore();

        gate.complete();
        await Future.wait([init, resume]);

        expect(backend.meCalls, 1);
        expect(auth.pendingGoogleOnboarding, isNotNull);
      });
    });
  });
}
