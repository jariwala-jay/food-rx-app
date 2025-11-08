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
          await _requestFCMToken();
          await _setupMessageHandlers();
          _v('NotificationService initialized with Firebase');
        } catch (e) {
          _v('Firebase not initialized, using local notifications only: $e');
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
        debugPrint('FirebaseMessaging not initialized');
        return;
      }

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
          _v('✅ Notification permissions granted on iOS');
        } else if (currentSettings.authorizationStatus ==
                AuthorizationStatus.authorized ||
            currentSettings.authorizationStatus ==
                AuthorizationStatus.provisional) {
          _v('✅ Notification permissions already granted on iOS');
        } else {
          debugPrint('❌ Notification permissions denied on iOS');
          return;
        }

        // Wait for APNs token
        await Future.delayed(const Duration(seconds: 1));
        final apnsToken = await _firebaseMessaging!.getAPNSToken();
        if (apnsToken != null) {
          _v('✅ APNs Token received');
        } else {
          _v('⚠️ APNs token not available yet, retrying...');
          await Future.delayed(const Duration(seconds: 2));
          final retryApnsToken = await _firebaseMessaging!.getAPNSToken();
          if (retryApnsToken != null) {
            _v('✅ APNs Token received on retry');
          } else {
            _v('❌ APNs token still not available');
          }
        }
      }

      _fcmToken = await _firebaseMessaging!.getToken();

      if (_fcmToken != null) {
        _v('🔑 FCM Token generated: ${_fcmToken!.substring(0, 20)}...');

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        _v('💾 FCM token saved locally');

        // Store in MongoDB for current user
        await _storeFCMTokenInDatabase(_fcmToken!);
      } else {
        _v('❌ FCM token is null - this indicates a configuration issue');
        debugPrint('❌ FCM Token Generation Failed - Check:');
        debugPrint('   1. Firebase project configuration');
        debugPrint('   2. GoogleService-Info.plist matches bundle ID');
        debugPrint(
            '   3. APNs authentication key uploaded to Firebase Console');
        debugPrint('   4. Push notification capability enabled in Xcode');
      }
    } catch (e) {
      _v('❌ Error getting FCM token: $e');
      debugPrint('❌ FCM Token Error Details: $e');
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
        _v('✅ FCM token stored for user');
      } else {
        _v('⚠️ No current user ID found, cannot store FCM token (will sync after login)');
      }
    } catch (e) {
      debugPrint('❌ Error storing FCM token in database: $e');
    }
  }

  // Sync stored FCM token to database (call this after user login/registration)
  Future<void> syncFCMTokenToDatabase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final storedToken = prefs.getString('fcm_token');

      if (userId == null) {
        _v('⚠️ No user ID found, cannot sync FCM token');
        return;
      }

      // Use stored token if available, otherwise try to get current token
      String? tokenToSync = storedToken ?? _fcmToken;

      if (tokenToSync == null) {
        // Try to get a fresh token
        if (_firebaseMessaging != null) {
          tokenToSync = await _firebaseMessaging!.getToken();
          if (tokenToSync != null) {
            await prefs.setString('fcm_token', tokenToSync);
            _fcmToken = tokenToSync;
          }
        }
      }

      if (tokenToSync == null) {
        _v('⚠️ No FCM token available to sync');
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

      _v('✅ FCM token synced to database for user');
      _fcmToken = tokenToSync; // Update internal token reference
    } catch (e) {
      debugPrint('❌ Error syncing FCM token to database: $e');
    }
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers() async {
    if (_firebaseMessaging == null) {
      debugPrint('FirebaseMessaging not initialized');
      return;
    }

    // Listen for token changes (debugging)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _v('🔄 FCM token refreshed');
      _fcmToken = newToken;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', newToken);

      // Try to store in database (will work if user is logged in)
      await _storeFCMTokenInDatabase(newToken);
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
