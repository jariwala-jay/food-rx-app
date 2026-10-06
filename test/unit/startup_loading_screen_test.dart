import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/utils/app_colors.dart';
import 'package:flutter_app/features/auth/controller/auth_controller.dart';
import 'package:flutter_app/features/auth/views/startup_loading_screen.dart';
import 'package:flutter_app/features/auth/views/welcome_page.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The loading screen replaces the orange spinner while AuthController.isLoading
// is true. The "Starting up" message must show only for the first session
// load, not for later isLoading operations such as login, so those cases
// drive the real MyApp + AuthController against a fake backend.

const _userId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const _email = 'user@test.com';
const _message = StartupLoadingScreen.messageText;

http.Response _json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

class _FakeBackend {
  Completer<http.Response> me = Completer<http.Response>();
  Completer<http.Response> login = Completer<http.Response>();
  int meCalls = 0;

  http.Client client() => MockClient((req) async {
        switch ('${req.method} ${req.url.path}') {
          case 'GET /auth/me':
            meCalls++;
            return me.future;
          case 'POST /auth/login':
            return login.future;
          default:
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

// AuthController awaits asset/storage I/O. Real time must pass for the I/O and
// a zero-duration pump flushes the FakeAsync microtasks that continue it
// (without advancing fake time, so the 3s message timer is unaffected).
Future<void> _settleUntil(
    WidgetTester tester, bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for condition');
    }
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)));
    await tester.pump();
  }
  await tester.pump();
}

Future<void> _pumpApp(WidgetTester tester, AuthController auth) {
  return tester.pumpWidget(
    ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: const MyApp(),
    ),
  );
}

Future<void> _pumpScreen(WidgetTester tester,
    {required bool showStartupMessage}) {
  return tester.pumpWidget(
    MaterialApp(
      home: StartupLoadingScreen(showStartupMessage: showStartupMessage),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://api.test');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    // rootBundle caches asset futures created under an earlier test's
    // FakeAsync zone; in a later test they never resolve and
    // AuthController.initialize() hangs on its nutrition-content load.
    for (final asset in const [
      'assets/nutrition/dash_calorie_map.json',
      'assets/nutrition/dash_servings.json',
      'assets/nutrition/myplate_targets.json',
      'assets/nutrition/diet_assignment_matrix.json',
    ]) {
      rootBundle.evict(asset);
    }

    // MyApp subscribes to deep links; there is no platform side in tests.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'com.llfbandit.app_links/messages',
      'com.llfbandit.app_links/events',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (_) async => null);
    }
    addTearDown(() {
      for (final channel in const [
        'com.llfbandit.app_links/messages',
        'com.llfbandit.app_links/events',
      ]) {
        messenger.setMockMethodCallHandler(MethodChannel(channel), null);
      }
    });
  });

  group('StartupLoadingScreen', () {
    testWidgets('shows the logo on the launch-screen background, no spinner',
        (tester) async {
      await _pumpScreen(tester, showStartupMessage: true);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.bySemanticsLabel('MyFoodRx'), findsOneWidget);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        AppColors.backgroundPrimary,
      );
      expect(AppColors.backgroundPrimary, const Color(0xFFF7F7F8));
    });

    testWidgets('logo asset is bundled', (tester) async {
      final data = await rootBundle.load(StartupLoadingScreen.logoAsset);
      expect(data.lengthInBytes, greaterThan(0));
    });

    testWidgets('message is hidden at first and appears after ~3s',
        (tester) async {
      await _pumpScreen(tester, showStartupMessage: true);
      expect(find.text(_message), findsNothing);

      await tester.pump(const Duration(milliseconds: 2900));
      expect(find.text(_message), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(_message), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('message never appears when showStartupMessage is false',
        (tester) async {
      await _pumpScreen(tester, showStartupMessage: false);

      await tester.pump(const Duration(seconds: 10));
      expect(find.text(_message), findsNothing);
    });

    testWidgets('timer is cancelled when disposed before it fires',
        (tester) async {
      await _pumpScreen(tester, showStartupMessage: true);
      await tester.pump(const Duration(seconds: 1));

      // Removing the screen mid-wait; testWidgets fails the test if a Timer
      // is still pending, and a late setState would surface as an exception.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
      expect(find.text(_message), findsNothing);
    });
  });

  group('startup-only gating in MyApp', () {
    testWidgets('initial session restore: spinner-free screen, message at 3s',
        (tester) async {
      final backend = _FakeBackend();
      await http.runWithClient(() async {
        _seedSession();
        final auth = AuthController()..initialize();
        addTearDown(auth.dispose);

        await _pumpApp(tester, auth);
        await _settleUntil(tester, () => backend.meCalls == 1);

        expect(auth.isLoading, isTrue);
        expect(find.byType(StartupLoadingScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(_message), findsNothing);

        await tester.pump(const Duration(seconds: 3));
        expect(find.text(_message), findsOneWidget);

        // Restore fails (transient 5xx) -> existing routing to WelcomePage.
        backend.me.complete(_json(500, {'detail': 'down'}));
        await _settleUntil(tester, () => !auth.isLoading);

        expect(auth.isLoading, isFalse);
        expect(find.byType(StartupLoadingScreen), findsNothing);
        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.text(_message), findsNothing);
      }, backend.client);
    });

    testWidgets('initial load finishing before 3s never shows the message',
        (tester) async {
      final backend = _FakeBackend();
      await http.runWithClient(() async {
        _seedSession();
        final auth = AuthController()..initialize();
        addTearDown(auth.dispose);

        await _pumpApp(tester, auth);
        await _settleUntil(tester, () => backend.meCalls == 1);
        await tester.pump(const Duration(milliseconds: 1500));
        expect(find.byType(StartupLoadingScreen), findsOneWidget);
        expect(find.text(_message), findsNothing);

        backend.me.complete(_json(500, {'detail': 'down'}));
        await _settleUntil(tester, () => !auth.isLoading);
        await tester.pump(const Duration(seconds: 5));

        expect(find.byType(WelcomePage), findsOneWidget);
        expect(find.text(_message), findsNothing);
      }, backend.client);
    });

    testWidgets('a later isLoading operation (login) does not show the message',
        (tester) async {
      final backend = _FakeBackend();
      await http.runWithClient(() async {
        // No stored session: the initial load ends immediately.
        final auth = AuthController()..initialize();
        addTearDown(auth.dispose);

        await _pumpApp(tester, auth);
        await _settleUntil(tester, () => !auth.isLoading);
        expect(auth.isLoading, isFalse);
        expect(find.byType(WelcomePage), findsOneWidget);

        final loginFuture = auth.login(_email, 'password');
        await tester.pump();

        expect(auth.isLoading, isTrue);
        expect(find.byType(StartupLoadingScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.pump(const Duration(seconds: 10));
        expect(find.text(_message), findsNothing);

        backend.login.complete(_json(401, {'detail': 'bad credentials'}));
        await tester.runAsync(() => loginFuture);
        await tester.pump();

        expect(auth.isLoading, isFalse);
        expect(find.byType(WelcomePage), findsOneWidget);
      }, backend.client);
    });
  });
}
