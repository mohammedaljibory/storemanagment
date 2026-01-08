import 'dart:io';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📬 Background message received: ${message.messageId}');
  // Handle background message - show local notification
  await FCMService._showNotificationFromMessage(message);
}

class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;
  static String? _currentUserId;
  static String? _currentToken; // Store the current token for logout

  /// Initialize FCM service
  static Future<void> init() async {
    if (_initialized) return;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    await requestPermission();

    // Setup foreground notification presentation
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Listen to when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Listen to token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    _initialized = true;
    print('✅ FCM Service initialized');
  }

  /// Request notification permission
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    print('🔔 FCM Permission: ${settings.authorizationStatus}');
    return granted;
  }

  /// Get FCM token for this device (with iOS APNS retry)
  static Future<String?> getToken() async {
    try {
      print('🔍 FCM: Getting token, platform=${Platform.operatingSystem}');

      // On iOS, APNS token may not be available immediately (especially on simulators)
      if (Platform.isIOS) {
        try {
          // Try to get APNS token with shorter timeout
          String? apnsToken;
          for (int i = 0; i < 3; i++) {
            print('🔍 FCM: Attempting to get APNS token (attempt ${i + 1}/3)');
            apnsToken = await _messaging.getAPNSToken();
            if (apnsToken != null) {
              print('✅ FCM: APNS token obtained');
              break;
            }
            await Future.delayed(const Duration(seconds: 1));
          }

          if (apnsToken == null) {
            print('❌ FCM ERROR: APNS token not available - FCM will not work on this iOS device');
            print('❌ FCM ERROR: Make sure you have a valid APNs key configured in Firebase Console');
            // On iOS simulator or without proper APNS setup, skip FCM
            return null;
          }
        } catch (e) {
          print('❌ FCM ERROR: APNS exception: $e');
          return null;
        }
      }

      print('🔍 FCM: Calling getToken()...');
      final token = await _messaging.getToken();
      if (token != null) {
        print('✅ FCM Token obtained: ${token.substring(0, 20)}...');
      } else {
        print('❌ FCM ERROR: getToken() returned null');
      }
      return token;
    } catch (e, stackTrace) {
      print('❌ FCM ERROR: Exception getting token: $e');
      print('❌ FCM ERROR: Stack trace: $stackTrace');
      return null;
    }
  }

  /// Debug method to check FCM status - call this to diagnose issues
  static Future<Map<String, dynamic>> debugFCMStatus() async {
    final Map<String, dynamic> status = {
      'platform': Platform.operatingSystem,
      'initialized': _initialized,
      'currentUserId': _currentUserId,
    };

    try {
      // Check permission
      final settings = await _messaging.getNotificationSettings();
      status['permissionStatus'] = settings.authorizationStatus.toString();
      status['permissionGranted'] = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // Try to get token
      if (Platform.isIOS) {
        try {
          final apnsToken = await _messaging.getAPNSToken();
          status['apnsToken'] = apnsToken != null ? '${apnsToken.substring(0, 10)}...' : null;
          status['apnsConfigured'] = apnsToken != null;
        } catch (e) {
          status['apnsError'] = e.toString();
          status['apnsConfigured'] = false;
        }
      }

      try {
        final fcmToken = await _messaging.getToken();
        status['fcmToken'] = fcmToken != null ? '${fcmToken.substring(0, 20)}...' : null;
        status['fcmTokenAvailable'] = fcmToken != null;
      } catch (e) {
        status['fcmError'] = e.toString();
        status['fcmTokenAvailable'] = false;
      }

      // Check if token is in Firestore
      if (_currentUserId != null) {
        try {
          final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
          final userData = userDoc.data();
          final tokens = userData?['fcmTokens'] as List<dynamic>? ?? [];
          status['tokensInFirestore'] = tokens.length;
          status['firestoreOK'] = true;
        } catch (e) {
          status['firestoreError'] = e.toString();
          status['firestoreOK'] = false;
        }
      }

    } catch (e) {
      status['error'] = e.toString();
    }

    print('🔍 FCM Debug Status: $status');
    return status;
  }

  /// Register device token for a user
  static Future<void> registerToken(String userId) async {
    print('🔍 FCM: registerToken called for user: $userId');
    _currentUserId = userId;

    final token = await getToken();
    if (token == null) {
      print('❌ FCM ERROR: Cannot register - no token available');
      print('❌ FCM ERROR: Check Firebase configuration and notification permissions');
      return;
    }

    // Store token for later use (logout)
    _currentToken = token;

    print('🔍 FCM: Token obtained, saving to Firestore...');
    try {
      // Add token to user's fcmTokens array (supports multiple devices)
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('✅ FCM token registered for user: $userId');
    } catch (e) {
      print('⚠️ FCM: Update failed ($e), trying set with merge...');
      // If field doesn't exist, set it
      try {
        await _firestore.collection('users').doc(userId).set({
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ FCM token created for user: $userId');
      } catch (e2) {
        print('❌ FCM ERROR: Failed to save token to Firestore: $e2');
      }
    }
  }

  /// Unregister device token (on logout)
  static Future<void> unregisterToken(String userId) async {
    print('🔍 FCM: unregisterToken called for user: $userId');

    // Use stored token first, fallback to getting new token
    String? token = _currentToken;
    if (token == null) {
      print('🔍 FCM: No stored token, trying to get token...');
      token = await getToken();
    }

    if (token == null) {
      print('⚠️ FCM: No token available to unregister');
      // Still clear local state
      _currentUserId = null;
      _currentToken = null;
      return;
    }

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      print('✅ FCM token unregistered for user: $userId');
    } catch (e) {
      print('❌ Error unregistering FCM token: $e');
    }

    // Clear local state
    _currentUserId = null;
    _currentToken = null;
  }

  /// Handle token refresh
  static Future<void> _handleTokenRefresh(String newToken) async {
    print('🔄 FCM Token refreshed: ${newToken.substring(0, 20)}...');

    // Remove old token if exists
    if (_currentUserId != null && _currentToken != null) {
      try {
        await _firestore.collection('users').doc(_currentUserId).update({
          'fcmTokens': FieldValue.arrayRemove([_currentToken]),
        });
        print('✅ Old FCM token removed');
      } catch (e) {
        print('⚠️ Error removing old token: $e');
      }
    }

    // Store new token
    _currentToken = newToken;

    // Register new token
    if (_currentUserId != null) {
      try {
        await _firestore.collection('users').doc(_currentUserId).update({
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('✅ New FCM token registered');
      } catch (e) {
        print('⚠️ Error registering new token: $e');
      }
    }
  }

  /// Handle foreground message
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📬 Foreground message: ${message.notification?.title}');
    await _showNotificationFromMessage(message);
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    print('👆 Notification tapped: ${message.data}');
    // You can navigate to specific screen based on message.data
    // For example: if (message.data['type'] == 'task') navigateToTask(message.data['taskId'])
  }

  /// Show local notification from FCM message
  static Future<void> _showNotificationFromMessage(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification == null) return;

    // Determine notification channel based on type
    String channelId = 'store_channel';
    String channelName = 'Store Notifications';
    Importance importance = Importance.high;
    Priority priority = Priority.high;

    final type = data['type'] ?? '';
    switch (type) {
      case 'task':
        channelId = 'task_channel';
        channelName = 'Task Notifications';
        importance = Importance.max;
        priority = Priority.max;
        break;
      case 'attendance':
        channelId = 'attendance_channel';
        channelName = 'Attendance Notifications';
        break;
      case 'request':
        channelId = 'request_channel';
        channelName = 'Request Notifications';
        break;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: importance,
      priority: priority,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      // Full screen intent for urgent notifications
      fullScreenIntent: type == 'task',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: data['taskId'] ?? data['requestId'] ?? '',
    );
  }

  /// Subscribe to topic (for broadcast notifications)
  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    print('📡 Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    print('📡 Unsubscribed from topic: $topic');
  }

  /// Subscribe employee to store notifications
  static Future<void> subscribeToStore(String storeId) async {
    await subscribeToTopic('store_$storeId');
  }

  /// Subscribe admin to all admin notifications
  static Future<void> subscribeToAdminNotifications() async {
    await subscribeToTopic('admins');
  }
}
