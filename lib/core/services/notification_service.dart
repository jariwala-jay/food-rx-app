import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/navigation_service.dart';
import 'package:flutter_app/features/navigation/views/main_screen.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final MongoDBService _mongoDBService = MongoDBService();
  String? _fcmToken;
  bool _verbose = false; // Toggle to reduce console noise

  void setVerboseLogging(bool enabled) {
    _verbose = enabled;
  }

  void _v(String message) {
    if (_verbose) debugPrint(message);
  }

  // Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Platform-specific Firebase initialization
      if (Platform.isIOS || Platform.isAndroid) {
        try {
          Firebase.app(); // This will throw if not initialized
          _firebaseMessaging = FirebaseMessaging.instance;
          debugPrint('✅ Firebase Messaging instance created');
          await _requestFCMToken();
          await _setupMessageHandlers();
          debugPrint('✅ NotificationService initialized with Firebase');
        } catch (e) {
          debugPrint(
              '❌ Firebase not initialized, using local notifications only: $e');
          debugPrint('Stack trace: ${StackTrace.current}');
        }
      }
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      rethrow;
    }
  }

  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions for iOS only if not already granted
    // Note: We skip this here because Firebase Messaging will handle it
    // This prevents duplicate permission requests
    // If you need local notifications without Firebase, uncomment below:
    /*
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        // Check current permission status first
        final permissionStatus = await iosImplementation.checkPermissions();
        if (permissionStatus == null || 
            !permissionStatus.isEnabled ||
            !permissionStatus.isAlertEnabled) {
          await iosImplementation.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
        }
      }
    }
    */
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    _navigateFromPayload(response.payload);
  }

  // Request FCM token and save it
  Future<void> _requestFCMToken() async {
    try {
      if (_firebaseMessaging == null) {
        debugPrint('❌ FirebaseMessaging not initialized');
        return;
      }

      debugPrint('🔄 Attempting to get FCM token...');

      // Request permissions on iOS only if not already granted
      if (Platform.isIOS) {
        // Check current permission status first
        final currentSettings =
            await _firebaseMessaging!.getNotificationSettings();

        // Only request if permission is not determined (first time) or denied
        // If already authorized or provisional, skip the request
        if (currentSettings.authorizationStatus ==
            AuthorizationStatus.notDetermined) {
          final NotificationSettings settings =
              await _firebaseMessaging!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          );

          if (settings.authorizationStatus != AuthorizationStatus.authorized &&
              settings.authorizationStatus != AuthorizationStatus.provisional) {
            debugPrint('❌ Notification permissions not granted on iOS');
            return;
          }
          debugPrint('✅ Notification permissions granted on iOS');
        } else if (currentSettings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            currentSettings.authorizationStatus ==
                AuthorizationStatus.provisional) {
          debugPrint('✅ Notification permissions already granted on iOS');
        } else {
          debugPrint('❌ Notification permissions denied on iOS');
          return;
        }

        // Wait for APNs token
        await Future.delayed(const Duration(seconds: 1));
        final apnsToken = await _firebaseMessaging!.getAPNSToken();
        if (apnsToken != null) {
          debugPrint('✅ APNs Token received');
        } else {
          debugPrint('⚠️ APNs token not available yet, retrying...');
          await Future.delayed(const Duration(seconds: 2));
          final retryApnsToken = await _firebaseMessaging!.getAPNSToken();
          if (retryApnsToken != null) {
            debugPrint('✅ APNs Token received on retry');
          } else {
            debugPrint('❌ APNs token still not available');
          }
        }
      } else if (Platform.isAndroid) {
        // Check Android notification settings
        final settings = await _firebaseMessaging!.getNotificationSettings();
        debugPrint(
            '📱 Android notification settings: ${settings.authorizationStatus}');

        // On Android 13+, check if permissions are granted
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          debugPrint(
              '⚠️ Android notification permissions denied - token may not be available');
        }
      }

      // Attempt to get FCM token with retries
      String? token = await _firebaseMessaging!.getToken();

      // If token is null on Android, wait and retry (Android sometimes needs more time)
      if (token == null && Platform.isAndroid) {
        debugPrint(
            '⚠️ FCM token null on first attempt, waiting and retrying...');
        await Future.delayed(const Duration(seconds: 2));
        token = await _firebaseMessaging!.getToken();

        if (token == null) {
          debugPrint(
              '⚠️ FCM token still null after first retry, trying once more...');
          await Future.delayed(const Duration(seconds: 2));
          token = await _firebaseMessaging!.getToken();
        }
      }

      _fcmToken = token;

      if (_fcmToken != null) {
        debugPrint('✅ FCM Token generated: ${_fcmToken!.substring(0, 20)}...');

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        debugPrint('💾 FCM token saved locally');

        // Store in MongoDB for current user
        await _storeFCMTokenInDatabase(_fcmToken!);
      } else {
        debugPrint(
            '❌ FCM token is null - this indicates a configuration issue');
        if (Platform.isAndroid) {
          debugPrint('❌ Android FCM Token Generation Failed - Check:');
          debugPrint('   1. Firebase project configuration');
          debugPrint('   2. google-services.json is in android/app/ directory');
          debugPrint(
              '   3. google-services.json package_name matches app package');
          debugPrint('   4. Google Services plugin applied in build.gradle');
          debugPrint('   5. Internet permission in AndroidManifest.xml');
          debugPrint(
              '   6. Firebase Cloud Messaging enabled in Firebase Console');
          debugPrint('');
          debugPrint('📱 If testing on Android Emulator:');
          debugPrint('   - Emulator MUST have Google Play Services enabled');
          debugPrint('   - Use an AVD with "Google APIs" (not AOSP)');
          debugPrint('   - Check: AVD Manager > System Image > Google APIs');
          debugPrint(
              '   - Without Google Play Services, FCM tokens cannot be generated');
          debugPrint('   - Physical devices always have Google Play Services');
        } else {
          debugPrint('❌ iOS FCM Token Generation Failed - Check:');
          debugPrint('   1. Firebase project configuration');
          debugPrint('   2. GoogleService-Info.plist matches bundle ID');
          debugPrint(
              '   3. APNs authentication key uploaded to Firebase Console');
          debugPrint('   4. Push notification capability enabled in Xcode');
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Store FCM token in MongoDB
  Future<void> _storeFCMTokenInDatabase(String token) async {
    try {
      await _mongoDBService.ensureConnection();
      final usersCollection = _mongoDBService.usersCollection;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        await usersCollection.updateOne(
          {'_id': ObjectIdHelper.parseObjectId(userId)},
          {
            '\$set': {
              'fcmToken': token,
              'updatedAt': DateTime.now().toIso8601String()
            }
          },
        );
        debugPrint('✅ FCM token stored in database for user');
      } else {
        debugPrint(
            '⚠️ No current user ID found, cannot store FCM token (will sync after login)');
      }
    } catch (e) {
      debugPrint('❌ Error storing FCM token in database: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Sync stored FCM token to database (call this after user login/registration)
  Future<void> syncFCMTokenToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null) {
        debugPrint('⚠️ No user ID found, cannot sync FCM token');
        return;
      }

      // Use stored token if available, otherwise try to get current token
      String? tokenToSync = prefs.getString('fcm_token') ?? _fcmToken;

      // If token is not available, try to get it with retries (especially important on Android)
      if (tokenToSync == null) {
        // Ensure Firebase Messaging is initialized
        if (_firebaseMessaging == null) {
          try {
            Firebase.app(); // Check if Firebase is initialized
            _firebaseMessaging = FirebaseMessaging.instance;
            debugPrint(
                '🔄 Firebase Messaging instance created for token retrieval');
          } catch (e) {
            debugPrint('❌ Firebase not initialized, cannot get FCM token: $e');
            return;
          }
        }

        debugPrint('🔄 FCM token not found, attempting to retrieve...');

        // First attempt
        try {
          tokenToSync = await _firebaseMessaging!.getToken();
        } catch (e) {
          debugPrint('❌ Error getting FCM token (first attempt): $e');
        }

        // If still null, wait and retry (Android sometimes needs a moment)
        if (tokenToSync == null) {
          debugPrint('⚠️ FCM token not available yet, retrying after delay...');
          await Future.delayed(const Duration(seconds: 2));
          try {
            tokenToSync = await _firebaseMessaging!.getToken();
          } catch (e) {
            debugPrint('❌ Error getting FCM token (second attempt): $e');
          }

          // Second retry if still null
          if (tokenToSync == null) {
            debugPrint('⚠️ FCM token still not available, final retry...');
            await Future.delayed(const Duration(seconds: 2));
            try {
              tokenToSync = await _firebaseMessaging!.getToken();
            } catch (e) {
              debugPrint('❌ Error getting FCM token (third attempt): $e');
            }
          }
        }

        if (tokenToSync != null) {
          await prefs.setString('fcm_token', tokenToSync);
          _fcmToken = tokenToSync;
          debugPrint('✅ FCM token retrieved and saved locally');
        } else {
          debugPrint('❌ FCM token still null after all retries');
        }
      }

      if (tokenToSync == null) {
        debugPrint('❌ No FCM token available to sync after retries');
        return;
      }

      await _mongoDBService.ensureConnection();
      final usersCollection = _mongoDBService.usersCollection;

      await usersCollection.updateOne(
        {'_id': ObjectIdHelper.parseObjectId(userId)},
        {
          '\$set': {
            'fcmToken': tokenToSync,
            'updatedAt': DateTime.now().toIso8601String()
          }
        },
      );

      debugPrint('✅ FCM token synced to database for user');
      _fcmToken = tokenToSync; // Update internal token reference
    } catch (e) {
      debugPrint('❌ Error syncing FCM token to database: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers() async {
    if (_firebaseMessaging == null) {
      debugPrint('FirebaseMessaging not initialized');
      return;
    }

    // Listen for token changes - critical for Android where token might be generated later
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 20)}...');
      _fcmToken = newToken;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);
      debugPrint('💾 FCM token saved to SharedPreferences');

      // Try to store in database (will work if user is logged in)
      try {
        await _storeFCMTokenInDatabase(newToken);
        debugPrint('✅ Refreshed FCM token synced to database');
      } catch (e) {
        debugPrint('⚠️ Failed to store refreshed token in database: $e');
        // Token will be synced on next login/registration via syncFCMTokenToDatabase
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages (app opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle notification when app was terminated
    final RemoteMessage? initialMessage =
        await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    _v('✅ Message handlers registered');
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    _v('✅ Foreground message: ${message.messageId}');

    // Show local notification when app is in foreground
    if (message.notification != null) {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'food_rx_notifications',
        'Food Rx Notifications',
        channelDescription: 'Notifications for your health tracking',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      await _localNotifications.show(
        message.hashCode,
        message.notification?.title,
        message.notification?.body,
        details,
      );
      _v('✅ Local notification shown');
    }
  }

  // Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    _v('✅ Background message: ${message.messageId}');

    // Navigate based on data payload
    final type = message.data['type'];
    _navigateByType(type);
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationsCollection;

      final result = await collection.updateOne(
        {'_id': ObjectIdHelper.parseObjectId(notificationId)},
        {
          '\$set': {
            'readAt': DateTime.now(),
          }
        },
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Diagnostic method to check FCM/APNs status
  Future<Map<String, dynamic>> getDiagnostics() async {
    final diagnostics = <String, dynamic>{
      'fcmToken': _fcmToken,
      'firebaseInitialized': _firebaseMessaging != null,
    };

    if (Platform.isIOS && _firebaseMessaging != null) {
      try {
        final apnsToken = await _firebaseMessaging!.getAPNSToken();
        final settings = await _firebaseMessaging!.getNotificationSettings();

        diagnostics['apnsToken'] = apnsToken;
        diagnostics['apnsTokenAvailable'] = apnsToken != null;
        diagnostics['authorizationStatus'] =
            settings.authorizationStatus.toString();
        diagnostics['alertSetting'] = settings.alert.toString();
        diagnostics['badgeSetting'] = settings.badge.toString();
        diagnostics['soundSetting'] = settings.sound.toString();

        _v('📊 Diagnostics - APNs Token: ${apnsToken != null ? "✅ Available" : "❌ Not Available"}');
        _v('📊 Diagnostics - Authorization: ${settings.authorizationStatus}');
      } catch (e) {
        diagnostics['apnsError'] = e.toString();
        _v('❌ Error getting APNs diagnostics: $e');
      }
    }

    if (Platform.isAndroid && _firebaseMessaging != null) {
      try {
        final settings = await _firebaseMessaging!.getNotificationSettings();
        diagnostics['authorizationStatus'] =
            settings.authorizationStatus.toString();
        diagnostics['alertSetting'] = settings.alert.toString();
        diagnostics['badgeSetting'] = settings.badge.toString();
        diagnostics['soundSetting'] = settings.sound.toString();
      } catch (e) {
        diagnostics['androidError'] = e.toString();
      }
    }

    return diagnostics;
  }

  // Force refresh FCM token (useful after bundle ID change)
  Future<String?> refreshToken() async {
    try {
      if (_firebaseMessaging == null) {
        debugPrint('❌ FirebaseMessaging not initialized');
        return null;
      }

      _v('🔄 Refreshing FCM token...');

      // Delete old token to force refresh
      await _firebaseMessaging!.deleteToken();
      _v('🗑️ Old token deleted');

      // Wait a bit
      await Future.delayed(const Duration(seconds: 1));

      // Get new token
      _fcmToken = await _firebaseMessaging!.getToken();

      if (_fcmToken != null) {
        _v('✅ New FCM token generated: ${_fcmToken!.substring(0, 20)}...');

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        _v('💾 FCM token saved locally');

        // Store in MongoDB for current user
        await _storeFCMTokenInDatabase(_fcmToken!);
      } else {
        _v('❌ Failed to generate new FCM token');
      }

      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error refreshing FCM token: $e');
      return null;
    }
  }

  // Dispose resources
  void dispose() {
    // No subscriptions to cancel in simplified version
  }
}

// Top-level function for background message handling (when app is killed)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Keep logs minimal in background isolate
}

// Navigation helpers
void _navigateFromPayload(String? payload) {
  // If payload is a JSON string you could parse here. We currently rely on FCM data route.
}

void _navigateByType(dynamic type) {
  final nav = NavigationService.navigatorKey.currentState;
  if (nav == null) return;

  // 0 = Home, 1 = Pantry
  int targetIndex = 0;
  if (type == 'expiring_ingredient') {
    targetIndex = 1;
  } else if (type == 'tracker_reminder') {
    targetIndex = 0;
  }

  nav.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => MainScreen(initialIndex: targetIndex)),
    (route) => false,
  );
}
