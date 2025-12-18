import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Service to listen for admin notifications in real-time
/// This is a client-side solution - for proper push notifications,
/// use Firebase Cloud Functions
class AdminNotificationListener {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription? _subscription;
  static bool _isListening = false;
  static DateTime? _startTime;

  /// Start listening for admin notifications
  static void startListening() {
    if (_isListening) return;

    _isListening = true;
    _startTime = DateTime.now();

    print('🔔 Admin notification listener started');

    _subscription = _firestore
        .collection('notifications')
        .where('forAdmin', isEqualTo: true)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _handleNewNotification(change.doc.id, data);
          }
        }
      }
    }, onError: (error) {
      print('❌ Error listening to notifications: $error');
    });
  }

  /// Handle new notification - just log it, Cloud Function handles push
  static Future<void> _handleNewNotification(
      String docId, Map<String, dynamic> data) async {
    // Don't show local notification - Cloud Function sends push to admin devices
    // This listener is only for tracking/logging purposes
    final title = data['title'] ?? 'إشعار جديد';
    print('🔔 New admin notification received: $title (push sent via Cloud Function)');
  }

  static String _getChannelId(String type) {
    switch (type) {
      case 'employee_checkin':
      case 'employee_checkout':
        return 'attendance_channel';
      case 'location_alert':
        return 'location_alert';
      case 'new_request':
        return 'request_channel';
      default:
        return 'store_channel';
    }
  }

  static String _getChannelName(String type) {
    switch (type) {
      case 'employee_checkin':
      case 'employee_checkout':
        return 'Attendance Notifications';
      case 'location_alert':
        return 'Location Alerts';
      case 'new_request':
        return 'Request Notifications';
      default:
        return 'Store Notifications';
    }
  }

  /// Stop listening
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    _startTime = null;
    print('🔔 Admin notification listener stopped');
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('notifications')
          .where('forAdmin', isEqualTo: true)
          .where('read', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Get unread notification count
  static Stream<int> unreadCountStream() {
    return _firestore
        .collection('notifications')
        .where('forAdmin', isEqualTo: true)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Check if listening
  static bool get isListening => _isListening;
}
