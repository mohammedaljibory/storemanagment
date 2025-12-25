import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/store_model.dart';
import '../models/attendance_model.dart';
import 'notification_service.dart';

/// Service to monitor employee location while checked in
/// Alerts if employee moves too far from store (400+ meters)
class LocationMonitorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<Position>? _positionSubscription;
  static bool _isMonitoring = false;
  static String? _currentUserId;
  static String? _currentUserName;
  static StoreModel? _currentStore;
  static AttendanceModel? _currentAttendance;

  // Distance threshold in meters
  static const double _alertDistanceMeters = 400.0;

  // Track if we already sent an alert (to avoid spam)
  static bool _alertSent = false;
  static DateTime? _lastAlertTime;

  // Foreground notification ID for Android
  static const int _foregroundNotificationId = 8888;

  /// Start monitoring employee location using position stream
  static Future<void> startMonitoring({
    required String userId,
    required String userName,
    required StoreModel store,
    required AttendanceModel attendance,
  }) async {
    // Stop any existing monitoring
    await stopMonitoring();

    _currentUserId = userId;
    _currentUserName = userName;
    _currentStore = store;
    _currentAttendance = attendance;
    _isMonitoring = true;
    _alertSent = false;

    print('📍 Starting location monitoring for $userName at ${store.name}');

    // Check and request permissions
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      print('📍 Location permission denied, cannot monitor');
      return;
    }

    // Show foreground notification (keeps monitoring alive on Android)
    await _showForegroundNotification();

    // Start position stream with background support
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters movement
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('📍 Position stream error: $error');
      },
    );

    // Do initial check
    await _checkCurrentLocation();
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _isMonitoring = false;
    _alertSent = false;
    _currentUserId = null;
    _currentUserName = null;
    _currentStore = null;
    _currentAttendance = null;

    // Cancel foreground notification
    await _notifications.cancel(_foregroundNotificationId);

    print('📍 Stopped location monitoring');
  }

  /// Handle position updates from stream
  static void _onPositionUpdate(Position position) {
    if (!_isMonitoring || _currentStore == null) return;

    final distance = _currentStore!.getDistanceFrom(
      position.latitude,
      position.longitude,
    );

    print('📍 Position update: ${distance.toStringAsFixed(0)}m from store');

    if (distance > _alertDistanceMeters) {
      _sendDistanceAlert(distance, position);
    } else {
      // Reset alert flag when back in range
      if (_alertSent) {
        print('📍 Employee back in range');
        _alertSent = false;
        _notifyBackInRange();
      }
    }
  }

  /// Check current location (one-time)
  static Future<void> _checkCurrentLocation() async {
    if (!_isMonitoring || _currentStore == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distance = _currentStore!.getDistanceFrom(
        position.latitude,
        position.longitude,
      );

      print('📍 Initial check: ${distance.toStringAsFixed(0)}m from store');

      if (distance > _alertDistanceMeters) {
        await _sendDistanceAlert(distance, position);
      }
    } catch (e) {
      print('📍 Error checking location: $e');
    }
  }

  /// Check and request location permission
  static Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('📍 Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('📍 Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('📍 Location permission denied forever');
      return false;
    }

    // For background location on Android 10+
    if (permission == LocationPermission.whileInUse) {
      // Request "always" permission for background tracking
      permission = await Geolocator.requestPermission();
    }

    return true;
  }

  /// Show foreground notification to keep service alive
  static Future<void> _showForegroundNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'location_monitoring',
      'Location Monitoring',
      channelDescription: 'Monitors your location during work shift',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      showWhen: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      _foregroundNotificationId,
      'تتبع الموقع نشط',
      'يتم مراقبة موقعك خلال فترة العمل',
      details,
    );
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

    // 1. Alert employee (local notification with alarm)
    await NotificationService.showAlarmNotification(
      id: 9001,
      title: 'تنبيه: أنت بعيد عن موقع العمل!',
      body: 'أنت على بعد $distanceText متر من ${_currentStore!.name}.\nيرجى العودة إلى موقع العمل فوراً.',
    );

    // 2. Notify admin (save to Firestore for FCM to pick up)
    await _notifyAdminAboutDistance(distance, position);

    print('⚠️ Distance alert sent: ${_currentUserName} is ${distanceText}m away');
  }

  /// Notify when employee returns to range
  static Future<void> _notifyBackInRange() async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'location_return',
        'title': 'موظف عاد لموقع العمل',
        'body': '${_currentUserName} عاد إلى نطاق ${_currentStore!.name}',
        'userId': _currentUserId,
        'userName': _currentUserName,
        'storeId': _currentStore!.id,
        'storeName': _currentStore!.name,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });
    } catch (e) {
      print('Error notifying admin about return: $e');
    }
  }

  /// Notify admin about employee being far from store
  static Future<void> _notifyAdminAboutDistance(double distance, Position position) async {
    try {
      // Create notification record for admin
      await _firestore.collection('notifications').add({
        'type': 'location_alert',
        'title': 'تنبيه: موظف بعيد عن موقع العمل',
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
