import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_app/core/models/user_model.dart';
import 'package:flutter_app/core/services/api_client.dart';
import 'package:flutter_app/core/auth/biometric_sign_in_labels.dart';
import 'package:flutter_app/core/services/credential_storage.dart';
import 'package:flutter_app/core/services/session_storage.dart';
import 'package:flutter_app/features/auth/models/signup_data.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_app/features/chatbot/services/rag_chatbot_service.dart';
import 'package:flutter_app/core/services/nutrition_content_loader.dart';
import 'package:flutter_app/core/services/personalization_service.dart';
import 'package:flutter_app/core/services/replan_service.dart';
import 'package:flutter_app/core/services/notification_manager.dart';
import 'package:flutter_app/core/services/notification_service.dart';
import 'package:flutter_app/core/services/email_service.dart';
import 'package:flutter_app/core/services/gmail_smtp_email_service.dart';
import 'package:flutter_app/core/utils/user_facing_errors.dart';
import 'package:http/http.dart' show ClientException;

// Top-level (not private, not a method) so it's directly unit-testable
// without needing to construct an AuthController or mock ApiClient.
bool isSameLocalDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class AuthController with ChangeNotifier {
  final EmailService _emailService = GmailSMTPEmailService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  BiometricSignInLabels? _cachedBiometricLabels;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  ReplanService? _replanService;
  ReplanTrigger? _pendingReplanTrigger;
  NotificationManager? _notificationManager;
  Uint8List? _localProfilePhotoData;
  StreamSubscription<void>? _unauthorizedSubscription;

  // Non-null while a new Google user needs to complete health-profile onboarding.
  // The root widget shows SignupPage instead of MainScreen when this is set.
  SignupData? _pendingGoogleOnboarding;
  SignupData? get pendingGoogleOnboarding => _pendingGoogleOnboarding;

  void clearGoogleOnboarding() {
    _pendingGoogleOnboarding = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _markUserActive() async {
    try {
      await ApiClient.patch('/auth/profile', body: {
        'lastActiveAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  // Cold starts and logins already call _markUserActive directly. This
  // covers the far more common case — resuming an already-live session
  // from the background — which resumeSessionIfNeeded otherwise no-ops on,
  // leaving lastActiveAt (and the app-inactivity reminder it drives) stale
  // for users who open the app daily without ever force-quitting it.
  // Throttled to once per local calendar day so routine foreground/
  // background switching doesn't spam the profile endpoint.
  DateTime? _lastActiveHeartbeatAt;

  Future<void> _recordAppOpenHeartbeat() async {
    final now = DateTime.now();
    final last = _lastActiveHeartbeatAt;
    if (last != null && isSameLocalDay(last, now)) {
      return;
    }
    _lastActiveHeartbeatAt = now;
    await _markUserActive();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  ReplanTrigger? get pendingReplanTrigger => _pendingReplanTrigger;
  NotificationManager? get notificationManager => _notificationManager;
  Uint8List? get localProfilePhotoData => _localProfilePhotoData;

  bool _isTransientNetworkError(Object e) =>
      e is SocketException ||
      e is TimeoutException ||
      e is ClientException ||
      e is HandshakeException ||
      e is TlsException;

  /// Full session teardown — called on both explicit logout and forced expiry.
  /// Must clear every piece of user-specific state so the next login starts
  /// clean. Feature providers (Pantry, Tracker) clear themselves reactively
  /// via ProxyProvider in main.dart when isAuthenticated flips to false; new
  /// user-specific providers should hook in there or be added below.
  Future<void> _clearAuthSession() async {
    await ApiClient.revokeRefreshTokenOnLogout();
    await ApiClient.clearSession();
    await RagChatbotService.resetConversation();
    // Cancel local reminders and dispose notification manager on every sign-out
    // path (explicit logout AND forced session expiry), so reminders don't keep
    // firing when the user is no longer authenticated.
    await NotificationService().cancelDailyReminders();
    _notificationManager?.dispose();
    _notificationManager = null;
    _localProfilePhotoData = null;
  }

  /// True if the user has biometric login enabled AND a usable refresh token,
  /// OR has legacy saved credentials. Used to decide whether to show the
  /// biometric sign-in button on the login screen.
  ///
  /// After logout the refresh token is cleared, so even if biometricEnabled
  /// is still true the button correctly hides — preventing a dead-end Face ID
  /// prompt that immediately fails.
  Future<bool> hasSavedLogin() async {
    if (await SessionStorage.isBiometricEnabled()) {
      if (await SessionStorage.hasRefreshToken()) return true;
    }
    return CredentialStorage.hasSavedCredentials();
  }

  Future<bool> isBiometricEnabled() => SessionStorage.isBiometricEnabled();

  /// Enable biometric login: authenticate once to confirm it works, then save
  /// the flag. Works for both email and Google users — no password stored.
  Future<bool> enableBiometricLogin() async {
    _error = null;
    try {
      final canUse = await canUseBiometricLogin();
      if (!canUse) {
        _error = 'Biometric login is not available on this device';
        notifyListeners();
        return false;
      }
      final ok = await authenticateWithBiometrics();
      if (!ok) {
        _error ??= 'Authentication cancelled';
        notifyListeners();
        return false;
      }
      await SessionStorage.setBiometricEnabled(true);
      notifyListeners();
      return true;
    } on PlatformException catch (e) {
      _error = biometricAuthUserMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Disable biometric login and clear any stored credentials.
  Future<void> disableBiometricLogin() async {
    await SessionStorage.setBiometricEnabled(false);
    await CredentialStorage.clearCredentials();
    invalidateBiometricSignInLabelsCache();
    notifyListeners();
  }

  Future<void> clearSavedLogin() => disableBiometricLogin();

  // ── One-time biometric suggestion ─────────────────────────────────────────

  bool _shouldSuggestBiometric = false;
  bool get shouldSuggestBiometric => _shouldSuggestBiometric;

  Future<void> _checkBiometricSuggestion() async {
    if (_shouldSuggestBiometric) return;
    if (await SessionStorage.isBiometricEnabled()) return;
    if (await CredentialStorage.hasSavedCredentials()) return;
    if (await SessionStorage.isBiometricSuggestionShown()) return;
    final count = await SessionStorage.getLoginCount();
    if (count < 2) return;
    if (!await canUseBiometricLogin()) return;
    _shouldSuggestBiometric = true;
    notifyListeners();
  }

  Future<void> dismissBiometricSuggestion() async {
    await SessionStorage.markBiometricSuggestionShown();
    _shouldSuggestBiometric = false;
    notifyListeners();
  }

  Future<bool> _completeAuthFromResponse(
    Map<String, dynamic> res, {
    bool saveLogin = false,
    String? loginEmail,
    String? loginPassword,
  }) async {
    final token = res['access_token'] as String?;
    final refresh = res['refresh_token'] as String?;
    final userId = res['user_id'] as String?;
    final emailRes = res['email'] as String?;
    final user = res['user'] as Map<String, dynamic>?;

    if (token == null ||
        refresh == null ||
        userId == null ||
        emailRes == null) {
      return false;
    }

    await ApiClient.setSession(
      accessToken: token,
      refreshToken: refresh,
      userId: userId,
      email: emailRes,
    );

    if (saveLogin && loginEmail != null && loginPassword != null) {
      await CredentialStorage.saveCredentials(
        email: loginEmail,
        password: loginPassword,
      );
    }

    if (user != null) {
      _currentUser = _createUserModel(user);
    } else {
      final me = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      if (me != null) _currentUser = _createUserModel(me);
    }

    if (_currentUser?.id != null) {
      // Unawaited so navigation isn't blocked on notification init, which
      // can take several seconds (network calls + FCM retry loops).
      unawaited(_initializeNotificationServices(_currentUser!.id!));
      unawaited(_markUserActive());
      unawaited(SessionStorage.incrementLoginCount());
      unawaited(_checkBiometricSuggestion());
    }
    return _currentUser != null;
  }

  Future<BiometricSignInLabels> getBiometricSignInLabels({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cachedBiometricLabels != null) {
      return _cachedBiometricLabels!;
    }
    final labels = await resolveBiometricSignInLabels(_localAuth);
    _cachedBiometricLabels = labels;
    return labels;
  }

  void invalidateBiometricSignInLabelsCache() {
    _cachedBiometricLabels = null;
  }

  Future<bool> canUseBiometricLogin() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        _error = 'Biometric login is not available on this device';
        notifyListeners();
        return false;
      }

      final ok = await _localAuth.authenticate(
        localizedReason: 'Sign in to MyFoodRx',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: false,
        ),
      );
      if (!ok) {
        _error = 'Authentication cancelled';
        notifyListeners();
      }
      return ok;
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      _error = biometricAuthUserMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      _error = userFacingErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithSavedCredentials() async {
    // New approach: flag-based biometric → restore from stored refresh token.
    // Works for Google users and email users alike — no password needed.
    final biometricEnabled = await SessionStorage.isBiometricEnabled();
    final hasRefresh = await SessionStorage.hasRefreshToken();

    if (biometricEnabled && hasRefresh) {
      _error = null;
      final ok = await authenticateWithBiometrics();
      if (!ok) {
        _error ??= 'Authentication cancelled';
        return false;
      }
      final restored = await _restoreSessionFromStorage();
      if (!restored) {
        // Refresh token expired or revoked. Clear the biometric flag so the
        // button doesn't keep showing on the login page, and give the user
        // a clear message prompting a fresh sign-in.
        await SessionStorage.setBiometricEnabled(false);
        _error =
            'Your session has expired. Please sign in again to re-enable biometric login.';
        notifyListeners();
      }
      return restored;
    }

    // Legacy: email+password saved in CredentialStorage (old checkbox flow).
    final creds = await CredentialStorage.readCredentials();
    if (creds == null) {
      _error = 'No saved login on this device';
      return false;
    }

    final ok = await authenticateWithBiometrics();
    if (!ok) {
      _error = 'Authentication cancelled';
      return false;
    }

    return login(creds.email, creds.password, saveLogin: true);
  }

  Future<bool> _restoreSessionFromStorage() async {
    final userId = await ApiClient.userId;
    final userEmail = await ApiClient.userEmail;
    final hasRefresh = await ApiClient.hasRefreshToken();

    if (userId == null || userEmail == null) {
      if (!hasRefresh) return false;
    }

    if (userId != null && userId.length != 24) {
      await _clearAuthSession();
      return false;
    }

    final access = await ApiClient.getToken();
    if ((access == null || access.isEmpty) && hasRefresh) {
      final outcome = await ApiClient.refreshSessionDetailed();
      if (outcome != SessionRefreshOutcome.success) {
        // Only clear on a server-confirmed rejection. A network/server
        // error says nothing about whether the refresh token is still
        // good, so wiping the session here would log users out over a
        // dropped connection rather than an actually-expired session.
        if (outcome == SessionRefreshOutcome.invalid) {
          await _clearAuthSession();
        }
        return false;
      }
    }

    if (!hasRefresh && (access == null || access.isEmpty)) {
      return false;
    }

    final userData = await _fetchAuthMeWithRetries();
    final email = await ApiClient.userEmail;
    if (userData != null && email != null && userData['email'] == email) {
      _currentUser = _createUserModel(userData);

      // If this is a Google user whose onboarding was interrupted (no dietType
      // means they never completed the health-profile signup), resume onboarding
      // instead of sending them to Home with an empty profile.
      final isGoogleUser = userData['authProvider'] == 'google';
      final onboardingIncomplete =
          (userData['dietType'] == null || (userData['dietType'] as String?)?.isEmpty == true);
      if (isGoogleUser && onboardingIncomplete) {
        debugPrint('[AuthController] Google user has incomplete onboarding — resuming signup flow');
        _pendingGoogleOnboarding = SignupData(
          name: _currentUser!.name,
          email: _currentUser!.email,
          profilePhotoUrl: userData['profilePhotoUrl'] as String?,
        );
      }

      unawaited(_initializeNotificationServices(_currentUser!.id!));
      unawaited(_markUserActive());
      return true;
    }
    await _clearAuthSession();
    return false;
  }

  /// [GET /auth/me] with short backoff — cellular/Wi‑Fi often lags right after boot.
  Future<Map<String, dynamic>?> _fetchAuthMeWithRetries() async {
    const maxAttempts = 5;
    var attempt = 0;
    while (true) {
      try {
        return await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      } on ApiException {
        rethrow;
      } catch (e) {
        final shouldRetry =
            _isTransientNetworkError(e) && attempt < maxAttempts - 1;
        if (!shouldRetry) {
          rethrow;
        }
        attempt++;
        await Future<void>.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Listen once for unrecoverable 401s that occur during normal API usage
    // (not just at startup). When the token is truly expired/revoked mid-session
    // this immediately clears local state and returns the user to the login screen.
    _unauthorizedSubscription ??= ApiClient.onUnauthorized.listen((_) async {
      if (_currentUser != null) {
        try {
          await _clearAuthSession();
        } catch (e) {
          debugPrint('Warning: error during forced sign-out: $e');
        }
        _currentUser = null;
        notifyListeners();
      }
    });

    try {
      try {
        final nutritionContent = await NutritionContentLoader.load();
        final personalizationService = PersonalizationService(nutritionContent);
        _replanService = ReplanService(personalizationService);
      } catch (e) {
        debugPrint('Warning: Failed to initialize re-plan service: $e');
      }

      final hasRefresh = await ApiClient.hasRefreshToken();
      final token = await ApiClient.getToken();
      if (hasRefresh || (token != null && token.isNotEmpty)) {
        try {
          final restored = await _restoreSessionFromStorage();
          if (!restored && !hasRefresh && token != null && token.isNotEmpty) {
            await _clearAuthSession();
          }
        } on ApiException catch (e) {
          if (e.statusCode == 401 || e.statusCode == 404) {
            final outcome = await ApiClient.refreshSessionDetailed();
            if (outcome == SessionRefreshOutcome.success) {
              try {
                await _restoreSessionFromStorage();
              } catch (_) {
                await _clearAuthSession();
              }
            } else if (outcome == SessionRefreshOutcome.invalid) {
              await _clearAuthSession();
            } else {
              // Couldn't confirm the refresh token is bad — keep the
              // session and let the user retry instead of signing out.
              _error = 'Could not verify your session. Check your connection.';
            }
          } else {
            _error = 'Failed to restore session: ${e.message}';
          }
        } catch (e) {
          if (_isTransientNetworkError(e)) {
            _error = userFacingErrorMessage(e);
          } else {
            await _clearAuthSession();
          }
        }
      }
    } catch (e) {
      _error = userFacingErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resumeSessionIfNeeded() async {
    if (_currentUser != null) {
      unawaited(_recordAppOpenHeartbeat());
      return;
    }
    final hasRefresh = await ApiClient.hasRefreshToken();
    final token = await ApiClient.getToken();
    if (!hasRefresh && (token == null || token.isEmpty)) return;

    try {
      final restored = await _restoreSessionFromStorage();
      if (restored) {
        _error = null;
        notifyListeners();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 404) {
        final outcome = await ApiClient.refreshSessionDetailed();
        if (outcome == SessionRefreshOutcome.success) {
          try {
            if (await _restoreSessionFromStorage()) {
              _error = null;
              notifyListeners();
              return;
            }
          } catch (_) {}
        } else if (outcome == SessionRefreshOutcome.networkError) {
          // Transient — keep stored tokens for a later retry.
          return;
        }
        await _clearAuthSession();
        notifyListeners();
      }
    } catch (_) {
      // Keep stored tokens for a later retry.
    }
  }

  UserModel _createUserModel(Map<String, dynamic> userData) {
    final id = userData['_id']?.toString() ?? '';
    return UserModel.fromJson({...userData, '_id': id});
  }

  Future<bool> register({
    required String email,
    required String password,
    required Map<String, dynamic> userData,
    File? profilePhoto,
    bool saveLogin = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cleanUserData = Map<String, dynamic>.from(userData);
      cleanUserData.remove('password');
      cleanUserData['email'] = email;
      cleanUserData['password'] = password;

      final res = await ApiClient.post('/auth/register', body: cleanUserData, requireAuth: false)
          as Map<String, dynamic>;
      if (await _completeAuthFromResponse(
        res,
        saveLogin: saveLogin,
        loginEmail: email.trim().toLowerCase(),
        loginPassword: password,
      )) {
        if (profilePhoto != null) {
          try {
            _localProfilePhotoData = await profilePhoto.readAsBytes();
            notifyListeners();
          } catch (_) {
            // Non-fatal preview miss; upload may still succeed.
          }
          try {
            final photoRes = await ApiClient.uploadFile('/auth/profile-photo', profilePhoto)
                as Map<String, dynamic>?;
            final photoId = photoRes?['profilePhotoId'] as String?;
            if (photoId != null) {
              await ApiClient.patch('/auth/profile', body: {'profilePhotoId': photoId});
              final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
              if (updated != null) _currentUser = _createUserModel(updated);
            }
          } catch (e) {
            debugPrint('Warning: Failed to upload profile photo: $e');
          }
        }

        return true;
      }
      _error = 'Registration failed';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on SocketException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } on ClientException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } on TimeoutException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkEmailExists(String email) async {
    if (email.trim().isEmpty) return false;
    try {
      final res = await ApiClient.post(
        '/auth/check-email',
        body: {'email': email.trim().toLowerCase()},
        requireAuth: false,
      ) as Map<String, dynamic>?;
      return res?['exists'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(
    String email,
    String password, {
    bool saveLogin = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.post('/auth/login', body: {'email': email, 'password': password},
              requireAuth: false)
          as Map<String, dynamic>?;
      if (res == null) {
        _error = 'Invalid email or password';
        return false;
      }

      if (await _completeAuthFromResponse(
        res,
        saveLogin: saveLogin,
        loginEmail: email,
        loginPassword: password,
      )) {
        return true;
      }
      if (!saveLogin) {
        await CredentialStorage.clearCredentials();
      }
      _error = 'Invalid email or password';
      return false;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _error = 'Invalid email or password';
        await CredentialStorage.clearCredentials();
      } else if (e.statusCode == 403) {
        _error = e.message;
      } else {
        _error = e.message;
      }
      return false;
    } on SocketException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } on ClientException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } on TimeoutException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Signs in with Google and returns true on success.
  /// For new users, sets [pendingGoogleOnboarding] so the root widget routes
  /// to the health-profile onboarding instead of MainScreen.
  Future<bool> loginWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final googleSignIn = GoogleSignIn();

      // Sign out first: iOS can silently restore a cached session and return
      // a null accessToken instead of doing a fresh OAuth round-trip.
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the sheet intentionally — not an error, no message needed.
        debugPrint('[Google] Sign-in cancelled by user');
        return false;
      }

      debugPrint('[Google] User selected: ${googleUser.email}');

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      if (accessToken == null) {
        _error = 'Failed to get Google access token';
        debugPrint('[Google] accessToken is null — authentication object: idToken=${googleAuth.idToken != null}');
        return false;
      }

      final res = await ApiClient.post(
        '/auth/google',
        body: {'accessToken': accessToken},
        requireAuth: false,
      ) as Map<String, dynamic>?;

      if (res == null) {
        _error = 'Google Sign-In failed';
        debugPrint('[Backend] /auth/google returned null response');
        return false;
      }

      final isNewUser = res['isNewUser'] == true;
      debugPrint('[Backend] Existing user found: ${!isNewUser}');
      debugPrint('[Backend] accessToken: ${res['access_token'] != null}, refreshToken: ${res['refresh_token'] != null}, isNewUser: $isNewUser');

      if (await _completeAuthFromResponse(res)) {
        debugPrint('[AuthController] currentUser updated: ${_currentUser != null}, isAuthenticated: $isAuthenticated');
        debugPrint('[Navigation] Going to: ${isNewUser ? "Signup/Onboarding" : "Home"}');

        // For new Google users, set the onboarding flag BEFORE notifyListeners()
        // so the root widget routes to SignupPage (step 2) instead of MainScreen.
        if (isNewUser) {
          _pendingGoogleOnboarding = SignupData(
            name: googleUser.displayName,
            email: googleUser.email,
            profilePhotoUrl: googleUser.photoUrl,
          );
        }
        return true;
      }

      debugPrint('[AuthController] _completeAuthFromResponse returned false — currentUser: $_currentUser');
      _error = 'Google Sign-In failed';
      return false;
    } on ApiException catch (e) {
      debugPrint('[Google] ApiException: ${e.statusCode} ${e.message}');
      _error = e.message;
      return false;
    } on SocketException catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } on PlatformException catch (e) {
      // Most codes here (sign_in_canceled, access_denied, etc.) are just the
      // user backing out — stay silent, only surface network errors.
      debugPrint('[Google] PlatformException: ${e.code} — ${e.message}');
      if (e.code == 'network_error') {
        _error = 'Network error. Please check your connection and try again.';
      }
      // Any other code (cancel, dismissed, access denied) → no message shown.
      return false;
    } catch (e) {
      debugPrint('[Google] Unexpected error: $e');
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      try {
        await ApiClient.patch('/auth/profile', body: {'fcmToken': null});
      } catch (_) {
        // Ignore; logout should proceed regardless.
      }
      // Clear cached Google credentials so the next loginWithGoogle() call
      // does a fresh OAuth flow instead of silently reusing this session.
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      await _clearAuthSession();
      _currentUser = null;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await ApiClient.patch('/auth/profile', body: updates);
      final updatedUser = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      if (updatedUser != null) {
        final oldUser = _currentUser!;
        _currentUser = _createUserModel(updatedUser);
        if (_replanService != null) {
          final trigger = await _replanService!.checkReplanTriggers(oldUser, _currentUser!);
          if (trigger != null) {
            try {
              final userForReplan = _currentUser!;
              double? weightLb = userForReplan.weight;
              if (weightLb != null && userForReplan.weightUnit == 'kg') {
                weightLb = weightLb * 2.205;
              }
              final tempUser = UserModel(
                id: userForReplan.id,
                email: userForReplan.email,
                name: userForReplan.name,
                dateOfBirth: userForReplan.dateOfBirth,
                sex: userForReplan.sex,
                heightFeet: userForReplan.heightFeet,
                heightInches: userForReplan.heightInches,
                weight: weightLb,
                activityLevel: userForReplan.activityLevel,
                medicalConditions: userForReplan.medicalConditions,
                healthGoals: userForReplan.healthGoals,
              );
              final result = await _replanService!.generateNewPlan(tempUser);
              await ApiClient.patch('/auth/profile', body: {
                'dietType': result.dietType,
                'myPlanType': result.myPlanType,
                'showGlycemicIndex': result.showGlycemicIndex,
                'targetCalories': result.targetCalories,
                'selectedDietPlan': result.selectedDietPlan,
                'diagnostics': result.diagnostics,
              });
              final refreshed = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
              if (refreshed != null) _currentUser = _createUserModel(refreshed);
              _pendingReplanTrigger = null;
            } catch (e) {
              debugPrint('Error auto-regenerating diet plan: $e');
              _pendingReplanTrigger = trigger;
            }
            notifyListeners();
          }
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = userFacingErrorMessage(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfilePhoto(File photo) async {
    if (_currentUser == null) return;
    // Do not toggle global _isLoading here: it replaces the app's root with a
    // loading scaffold and conflicts with in-page upload UI on Profile.
    try {
      try {
        _localProfilePhotoData = await photo.readAsBytes();
      } catch (_) {
        // Keep network upload path even if local preview cannot be read.
      }
      final photoRes = await ApiClient.uploadFile('/auth/profile-photo', photo)
          as Map<String, dynamic>?;
      final photoId = photoRes?['profilePhotoId'] as String?;
      if (photoId != null) {
        await ApiClient.patch('/auth/profile', body: {'profilePhotoId': photoId});
        final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
        if (updated != null) _currentUser = _createUserModel(updated);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = userFacingErrorMessage(e);
    } finally {
      notifyListeners();
    }
  }

  Future<List<int>?> getProfilePhoto() async {
    if (_currentUser?.profilePhotoId == null) return null;
    try {
      return await ApiClient.getBytes('/api/profile-photos/${_currentUser!.profilePhotoId}');
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return null;
    }
  }

  Future<bool> regenerateDietPlan() async {
    if (_currentUser == null || _replanService == null) return false;
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _replanService!.generateNewPlan(_currentUser!);
      await ApiClient.patch('/auth/profile', body: {
        'dietType': result.dietType,
        'myPlanType': result.myPlanType,
        'showGlycemicIndex': result.showGlycemicIndex,
        'targetCalories': result.targetCalories,
        'selectedDietPlan': result.selectedDietPlan,
        'diagnostics': result.diagnostics,
      });
      final updated = await ApiClient.get('/auth/me') as Map<String, dynamic>?;
      if (updated != null) _currentUser = _createUserModel(updated);
      _pendingReplanTrigger = null;
      return true;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void dismissReplanTrigger() {
    _pendingReplanTrigger = null;
    notifyListeners();
  }

  bool shouldOfferReplan() {
    if (_currentUser == null || _replanService == null) return false;
    return _replanService!.shouldOfferReplan(_currentUser!);
  }

  List<String> getReplanSuggestions() {
    if (_currentUser == null || _replanService == null) return [];
    return _replanService!.getReplanSuggestions(_currentUser!);
  }

  Future<void> _initializeNotificationServices(String userId) async {
    try {
      _notificationManager = NotificationManager();
      await _notificationManager!.initialize(userId);
      final notificationService = NotificationService();
      await notificationService.syncFCMTokenToDatabase();
      await notificationService.applyMealLoggingReminderPreferences(
        _currentUser?.mealLoggingReminderPrefs,
        accountCreatedAt: _currentUser?.createdAt,
      );
    } catch (e) {
      debugPrint('Error initializing notification services: $e');
    }
  }

  @override
  void dispose() {
    _unauthorizedSubscription?.cancel();
    super.dispose();
  }

  Future<bool> requestPasswordReset(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await ApiClient.post('/auth/forgot-password',
          body: {'email': email}, requireAuth: false) as Map<String, dynamic>?;
      final token = res?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        final userName = res?['userName'] as String?;
        final emailSent = await _emailService.sendPasswordResetEmail(
          email: email,
          resetToken: token,
          userName: userName,
        );
        if (!emailSent) {
          _error = 'Failed to send password reset email. Please try again later.';
          return false;
        }
      }
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 429) {
        _error = 'Too many reset requests. Please try again later.';
      } else {
        _error = e.message;
      }
      return false;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> validatePasswordResetToken(String token) async {
    _error = null;
    try {
      final res = await ApiClient.post('/auth/validate-reset-token',
          body: {'token': token}, requireAuth: false) as Map<String, dynamic>?;
      return res?['valid'] == true;
    } catch (e) {
      _error = 'Invalid or expired reset token';
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (newPassword.length < 8) {
        _error = 'Password must be at least 8 characters';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[A-Z]'))) {
        _error = 'Password must contain at least one uppercase letter';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[a-z]'))) {
        _error = 'Password must contain at least one lowercase letter';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[0-9]'))) {
        _error = 'Password must contain at least one number';
        return false;
      }
      if (!newPassword.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
        _error = 'Password must contain at least one special character';
        return false;
      }
      await ApiClient.post('/auth/reset-password',
          body: {'token': token, 'newPassword': newPassword}, requireAuth: false);
      await CredentialStorage.clearCredentials();
      await _clearAuthSession();
      _currentUser = null;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
