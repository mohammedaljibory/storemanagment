import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_model.dart';
import '../models/attendance_model.dart';
import 'notification_service.dart';

/// Service to monitor employee location while checked in
/// Alerts if employee moves too far from store
class LocationMonitorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static String? _currentUserId;
  static String? _currentUserName;
  static StoreModel? _currentStore;
  static AttendanceModel? _currentAttendance;

  // Distance threshold in meters
  static const double _alertDistanceMeters = 400.0;

  // Check interval in seconds
  static const int _checkIntervalSeconds = 60; // Check every minute

  // Track if we already sent an alert (to avoid spam)
  static bool _alertSent = false;
  static DateTime? _lastAlertTime;

  /// Start monitoring employee location
  static Future<void> startMonitoring({
    required String userId,
    required String userName,
    required StoreModel store,
    required AttendanceModel attendance,
  }) async {
    // Stop any existing monitoring
    stopMonitoring();

    _currentUserId = userId;
    _currentUserName = userName;
    _currentStore = store;
    _currentAttendance = attendance;
    _isMonitoring = true;
    _alertSent = false;

    print('📍 Started location monitoring for $userName at ${store.name}');

    // Start periodic location checks
    _monitorTimer = Timer.periodic(
      const Duration(seconds: _checkIntervalSeconds),
      (_) => _checkLocation(),
    );

    // Do initial check
    await _checkLocation();
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _alertSent = false;
    _currentUserId = null;
    _currentUserName = null;
    _currentStore = null;
    _currentAttendance = null;
    print('📍 Stopped location monitoring');
  }

  /// Check current location against store
  static Future<void> _checkLocation() async {
    if (!_isMonitoring || _currentStore == null || _currentUserId == null) {
      return;
    }

    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate distance from store
      final distance = _currentStore!.getDistanceFrom(
        position.latitude,
        position.longitude,
      );

      print('📍 Distance from store: ${distance.toStringAsFixed(0)}m');

      // Check if too far
      if (distance > _alertDistanceMeters) {
        await _sendDistanceAlert(distance, position);
      } else {
        // Reset alert flag when back in range
        if (_alertSent) {
          print('📍 Employee back in range');
          _alertSent = false;
        }
      }
    } catch (e) {
      print('📍 Error checking location: $e');
    }
  }

  /// Send alert to employee and admin
  static Future<void> _sendDistanceAlert(double distance, Position position) async {
    // Don't spam alerts - wait at least 5 minutes between alerts
    if (_alertSent && _lastAlertTime != null) {
      final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
      if (timeSinceLastAlert.inMinutes < 5) {
        return;
      }
    }

    _alertSent = true;
    _lastAlertTime = DateTime.now();

    final distanceText = distance.toStringAsFixed(0);

    // 1. Alert employee (local notification)
    await NotificationService.showNotification(
      id: 9001,
      title: 'تنبيه: أنت بعيد عن موقع العمل',
      body: 'أنت على بعد $distanceText متر من ${_currentStore!.name}. يرجى العودة إلى موقع العمل.',
      channelId: 'location_alert',
      channelName: 'Location Alerts',
    );

    // 2. Notify admin (save to Firestore for FCM to pick up)
    await _notifyAdminAboutDistance(distance, position);

    print('⚠️ Distance alert sent: ${_currentUserName} is ${distanceText}m away');
  }

  /// Notify admin about employee being far from store
  static Future<void> _notifyAdminAboutDistance(double distance, Position position) async {
    try {
      // Create notification record for admin
      await _firestore.collection('notifications').add({
        'type': 'location_alert',
        'title': 'تنبيه موقع الموظف',
        'body': '${_currentUserName} بعيد عن ${_currentStore!.name} بمسافة ${distance.toStringAsFixed(0)} متر',
        'userId': _currentUserId,
        'userName': _currentUserName,
        'storeId': _currentStore!.id,
        'storeName': _currentStore!.name,
        'distance': distance,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'attendanceId': _currentAttendance?.id,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      // Also update attendance record with location warning
      if (_currentAttendance != null) {
        await _firestore.collection('attendance').doc(_currentAttendance!.id).update({
          'locationWarnings': FieldValue.arrayUnion([{
            'timestamp': DateTime.now().toIso8601String(),
            'distance': distance,
            'latitude': position.latitude,
            'longitude': position.longitude,
          }]),
        });
      }
    } catch (e) {
      print('Error notifying admin about distance: $e');
    }
  }

  /// Notify admin when employee checks in
  static Future<void> notifyAdminOfCheckIn({
    required String userId,
    required String userName,
    required String storeName,
    required String storeId,
    required DateTime checkInTime,
    bool isLate = false,
    int lateMinutes = 0,
  }) async {
    try {
      String body = '$userName سجل حضوره في $storeName';
      if (isLate) {
        body += ' (متأخر $lateMinutes دقيقة)';
      }

      // Create notification record
      await _firestore.collection('notifications').add({
        'type': 'employee_checkin',
        'title': 'تسجيل حضور موظف',
        'body': body,
        'userId': userId,
        'userName': userName,
        'storeId': storeId,
        'storeName': storeName,
        'checkInTime': checkInTime.toIso8601String(),
        'isLate': isLate,
        'lateMinutes': lateMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('✅ Admin notified of check-in: $userName at $storeName');
    } catch (e) {
      print('Error notifying admin of check-in: $e');
    }
  }

  /// Notify admin when employee checks out
  static Future<void> notifyAdminOfCheckOut({
    required String userId,
    required String userName,
    required String storeName,
    required String storeId,
    required double totalHours,
    bool isEarlyLeave = false,
    int earlyLeaveMinutes = 0,
  }) async {
    try {
      final hours = totalHours.floor();
      final minutes = ((totalHours - hours) * 60).round();

      String body = '$userName سجل انصرافه من $storeName (${hours}س ${minutes}د)';
      if (isEarlyLeave) {
        body += ' - خروج مبكر $earlyLeaveMinutes دقيقة';
      }

      await _firestore.collection('notifications').add({
        'type': 'employee_checkout',
        'title': 'تسجيل انصراف موظف',
        'body': body,
        'userId': userId,
        'userName': userName,
        'storeId': storeId,
        'storeName': storeName,
        'totalHours': totalHours,
        'isEarlyLeave': isEarlyLeave,
        'earlyLeaveMinutes': earlyLeaveMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('✅ Admin notified of check-out: $userName from $storeName');
    } catch (e) {
      print('Error notifying admin of check-out: $e');
    }
  }

  /// Check if currently monitoring
  static bool get isMonitoring => _isMonitoring;
}
