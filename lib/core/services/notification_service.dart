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

    // Request permissions for iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
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

      // Request permissions on iOS
      if (Platform.isIOS) {
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
      _v('🔑 FCM Token generated');

      if (_fcmToken != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        _v('💾 FCM token saved locally');

        // Store in MongoDB for current user
        await _storeFCMTokenInDatabase(_fcmToken!);
      }
    } catch (e) {
      _v('❌ Error getting FCM token: $e');
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
        _v('⚠️ No current user ID found, cannot store FCM token');
      }
    } catch (e) {
      debugPrint('❌ Error storing FCM token in database: $e');
    }
  }

  // Setup message handlers
  Future<void> _setupMessageHandlers() async {
    if (_firebaseMessaging == null) {
      debugPrint('FirebaseMessaging not initialized');
      return;
    }

    // Listen for token changes (debugging)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _v('🔄 FCM token refreshed');
      _fcmToken = newToken;
      _storeFCMTokenInDatabase(newToken);
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
