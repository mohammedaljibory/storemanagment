import 'dart:io';
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

  /// Get FCM token for this device
  static Future<String?> getToken() async {
    try {
      final token = await _messaging.getToken();
      print('📱 FCM Token: ${token?.substring(0, 20)}...');
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Register device token for a user
  static Future<void> registerToken(String userId) async {
    _currentUserId = userId;

    final token = await getToken();
    if (token == null) {
      print('❌ Cannot register: No FCM token');
      return;
    }

    try {
      // Add token to user's fcmTokens array (supports multiple devices)
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      print('✅ FCM token registered for user: $userId');
    } catch (e) {
      // If field doesn't exist, set it
      try {
        await _firestore.collection('users').doc(userId).set({
          'fcmTokens': [token],
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ FCM token created for user: $userId');
      } catch (e2) {
        print('❌ Error registering FCM token: $e2');
      }
    }
  }

  /// Unregister device token (on logout)
  static Future<void> unregisterToken(String userId) async {
    final token = await getToken();
    if (token == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      print('✅ FCM token unregistered for user: $userId');
    } catch (e) {
      print('❌ Error unregistering FCM token: $e');
    }

    _currentUserId = null;
  }

  /// Handle token refresh
  static Future<void> _handleTokenRefresh(String newToken) async {
    print('🔄 FCM Token refreshed');
    if (_currentUserId != null) {
      await registerToken(_currentUserId!);
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
