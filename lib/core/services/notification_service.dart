import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/models/app_notification.dart';
import 'package:flutter_app/core/models/notification_preferences.dart';
import 'package:flutter_app/core/models/notification_analytics.dart';
import 'package:flutter_app/core/services/mongodb_service.dart';
import 'package:flutter_app/core/services/notification_navigation_handler.dart';
import 'package:flutter_app/core/utils/objectid_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _firebaseMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final MongoDBService _mongoDBService = MongoDBService();
  final NotificationNavigationHandler _navigationHandler =
      NotificationNavigationHandler();

  String? _fcmToken;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _backgroundMessageSubscription;

  // Initialize the notification service
  Future<void> initialize() async {
    try {
      // Initialize local notifications first (works on all platforms)
      await _initializeLocalNotifications();

      // Platform-specific initialization
      if (Platform.isIOS) {
        // iOS: Try Firebase first, fallback to local notifications if it fails
        try {
          // Check if Firebase is initialized
          try {
            Firebase.app(); // This will throw if not initialized
            _firebaseMessaging = FirebaseMessaging.instance;
            await _requestFCMToken();
            await _setupMessageHandlers();
            debugPrint(
                'NotificationService initialized (iOS - Firebase enabled)');
          } catch (e) {
            debugPrint(
                'Firebase not initialized, using local notifications only: $e');
            debugPrint(
                'NotificationService initialized (iOS - Local notifications only)');
          }
        } catch (firebaseError) {
          debugPrint(
              'Firebase initialization failed on iOS, falling back to local notifications: $firebaseError');
          debugPrint(
              'NotificationService initialized (iOS - Local notifications only)');
        }
      } else {
        // Android: Use Firebase + local notifications
        try {
          // Check if Firebase is initialized
          try {
            Firebase.app(); // This will throw if not initialized
            _firebaseMessaging = FirebaseMessaging.instance;
            await _requestFCMToken();
            await _setupMessageHandlers();
            debugPrint(
                'NotificationService initialized (Android - Firebase enabled)');
          } catch (e) {
            debugPrint(
                'Firebase not initialized, using local notifications only: $e');
            debugPrint(
                'NotificationService initialized (Android - Local notifications only)');
          }
        } catch (firebaseError) {
          debugPrint(
              'Firebase initialization failed, falling back to local notifications: $firebaseError');
          debugPrint(
              'NotificationService initialized (Android - Local notifications only)');
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

  // Handle foreground messages
  // TODO: Temporarily disabled due to iOS build issues
  /*
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification for foreground messages
    await _showLocalNotification(message);

    // Track analytics
    await _trackNotificationAction(
      message.data['notificationId'] ?? '',
      NotificationAction.delivered,
    );
  }
  */

  // Handle background messages
  // TODO: Temporarily disabled due to iOS build issues
  /*
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Received background message: ${message.messageId}');

    // Track analytics
    await _trackNotificationAction(
      message.data['notificationId'] ?? '',
      NotificationAction.opened,
    );

    // Handle navigation based on notification data
    _handleNotificationNavigation(message.data);
  }
  */

  // Show local notification
  // TODO: Temporarily disabled due to iOS build issues
  /*
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'food_rx_notifications',
      'Food Rx Notifications',
      channelDescription:
          'Notifications for health goals, pantry alerts, and tips',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'Food Rx',
      message.notification?.body ?? '',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }
  */

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');

    if (response.payload != null) {
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      _handleNotificationNavigation(data);

      // Track analytics
      _trackNotificationAction(
        data['notificationId'] ?? '',
        NotificationAction.clicked,
      );
    }
  }

  // Handle notification navigation
  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      // Create a mock notification object for navigation
      final notification = AppNotification(
        userId: '',
        type: NotificationType.values.firstWhere(
          (e) => e.toString().split('.').last == data['type'],
          orElse: () => NotificationType.system,
        ),
        category: NotificationCategory.values.firstWhere(
          (e) => e.toString().split('.').last == data['category'],
          orElse: () => NotificationCategory.tip,
        ),
        title: data['title'] ?? '',
        message: data['body'] ?? '',
        actionData: data['actionData'] != null
            ? Map<String, dynamic>.from(jsonDecode(data['actionData']))
            : null,
      );

      _navigationHandler.handleNotificationTap(notification);
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
    }
  }

  // Request notification permissions
  Future<bool> requestPermissions() async {
    try {
      if (_firebaseMessaging == null) {
        debugPrint('FirebaseMessaging not initialized');
        return false;
      }

      // Request Firebase permissions
      final NotificationSettings settings =
          await _firebaseMessaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Request local notification permissions
      final bool? localResult = await _localNotifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      final bool firebaseGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      final bool localGranted = localResult ?? false;

      debugPrint('Firebase permissions: $firebaseGranted');
      debugPrint('Local permissions: $localGranted');

      return firebaseGranted && localGranted;
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  // Request FCM token and save it
  Future<void> _requestFCMToken() async {
    try {
      if (_firebaseMessaging == null) {
        debugPrint('FirebaseMessaging not initialized');
        return;
      }

      // Request permissions first on iOS
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
        debugPrint('✅ Notification permissions granted on iOS');

        // Wait a bit for APNs token to be set
        await Future.delayed(const Duration(seconds: 1));

        // Check if APNs token is available
        final apnsToken = await _firebaseMessaging!.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('⚠️ APNs token not available yet, retrying...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      _fcmToken = await _firebaseMessaging!.getToken();
      debugPrint('🔑 FCM Token Generated: $_fcmToken');

      if (_fcmToken != null) {
        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', _fcmToken!);
        debugPrint('💾 FCM Token saved to SharedPreferences');

        // Store in MongoDB for current user
        await _storeFCMTokenInDatabase(_fcmToken!);
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  // Store FCM token in MongoDB
  Future<void> _storeFCMTokenInDatabase(String token) async {
    try {
      await _mongoDBService.ensureConnection();
      final usersCollection = _mongoDBService.usersCollection;

      // Get current user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs
          .getString('user_id'); // Changed from 'current_user_id' to 'user_id'

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
        debugPrint('✅ FCM Token stored in MongoDB for user: $userId');
      } else {
        debugPrint('⚠️ No current user ID found, cannot store FCM token');
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

    // Handle foreground messages
    _messageSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    _backgroundMessageSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle notification tap when app is terminated
    final RemoteMessage? initialMessage =
        await _firebaseMessaging!.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }
  }

  // Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message: ${message.messageId}');

    // Show local notification
    await _showLocalNotification(message);
  }

  // Handle background messages
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    debugPrint('Received background message: ${message.messageId}');

    // Handle navigation based on notification data
    if (message.data.isNotEmpty) {
      // Create a temporary AppNotification from message data for navigation
      final notification = AppNotification(
        id: message.messageId ??
            'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: message.data['userId'] ?? '',
        type: NotificationType.values.firstWhere(
          (type) => type.toString().split('.').last == message.data['type'],
          orElse: () => NotificationType.system,
        ),
        category: NotificationCategory.values.firstWhere(
          (category) =>
              category.toString().split('.').last == message.data['category'],
          orElse: () => NotificationCategory.tip,
        ),
        title: message.notification?.title ?? 'Notification',
        message: message.notification?.body ?? 'You have a new notification',
        priority: NotificationPriority.medium,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _navigationHandler.handleNotificationTap(notification);
    }
  }

  // Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new notification',
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }

  // Get notification preferences
  Future<NotificationPreferences?> getPreferences(String userId) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationPreferencesCollection;

      final result = await collection.findOne({'userId': userId});

      if (result != null) {
        return NotificationPreferences.fromJson(result);
      }

      // Return default preferences if none exist
      return NotificationPreferences(userId: userId);
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
      return null;
    }
  }

  // Update notification preferences
  Future<bool> updatePreferences(NotificationPreferences preferences) async {
    try {
      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationPreferencesCollection;

      final result = await collection.updateOne(
        {'userId': preferences.userId},
        preferences.toJson(),
        upsert: true,
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      return false;
    }
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
            'readAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }
        },
      );

      return result.isSuccess;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  // Track notification action
  Future<void> _trackNotificationAction(
      String notificationId, NotificationAction action) async {
    try {
      if (notificationId.isEmpty) return;

      await _mongoDBService.ensureConnection();
      final collection = _mongoDBService.notificationAnalyticsCollection;

      final analytics = NotificationAnalytics(
        userId: '', // This should be passed from the calling context
        notificationId: notificationId,
        action: action,
      );

      await collection.insertOne({
        '_id': ObjectIdHelper.parseObjectId(analytics.id),
        ...analytics.toJson(),
      });
    } catch (e) {
      debugPrint('Error tracking notification action: $e');
    }
  }

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Dispose resources
  void dispose() {
    _messageSubscription?.cancel();
    _backgroundMessageSubscription?.cancel();
  }
}

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}
