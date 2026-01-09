import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/store_model.dart';
import '../models/attendance_model.dart';
import 'notification_service.dart';

/// Service to monitor employee location while checked in
/// Alerts if employee moves outside the store's monitoring radius
/// Auto-checkout after 10 minutes outside radius (unless on break)
class LocationMonitorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription<Position>? _positionSubscription;
  static Timer? _periodicLocationTimer;
  static bool _isMonitoring = false;
  static String? _currentUserId;
  static String? _currentUserName;
  static StoreModel? _currentStore;
  static AttendanceModel? _currentAttendance;

  // Track if we already sent an alert (to avoid spam)
  static bool _alertSent = false;
  static DateTime? _lastAlertTime;

  // Auto-checkout tracking
  static DateTime? _outsideRadiusSince;
  static Timer? _autoCheckoutTimer;
  static const int _autoCheckoutMinutes = 10; // 10 minutes outside = auto checkout
  static const int _warningMinutes = 5; // Warning at 5 minutes
  static bool _warningShown = false;

  // Callback for auto-checkout
  static Future<void> Function()? _onAutoCheckout;

  // Foreground notification ID for Android
  static const int _foregroundNotificationId = 8888;

  // Break pause state
  static bool _isPausedForBreak = false;

  /// Get the monitoring radius from current store (or default 400m)
  static double get _alertDistanceMeters => _currentStore?.monitoringRadius ?? 400.0;

  /// Check if employee is currently outside radius
  static bool get isOutsideRadius => _outsideRadiusSince != null;

  /// Get minutes outside radius
  static int get minutesOutsideRadius {
    if (_outsideRadiusSince == null) return 0;
    return DateTime.now().difference(_outsideRadiusSince!).inMinutes;
  }

  /// Set auto-checkout callback
  static void setAutoCheckoutCallback(Future<void> Function() callback) {
    _onAutoCheckout = callback;
  }

  /// Start monitoring employee location using position stream
  static Future<void> startMonitoring({
    required String userId,
    required String userName,
    required StoreModel store,
    required AttendanceModel attendance,
    Future<void> Function()? onAutoCheckout,
  }) async {
    // Stop any existing monitoring
    await stopMonitoring();

    _currentUserId = userId;
    _currentUserName = userName;
    _currentStore = store;
    _currentAttendance = attendance;
    _isMonitoring = true;
    _alertSent = false;
    _outsideRadiusSince = null;
    _warningShown = false;
    if (onAutoCheckout != null) {
      _onAutoCheckout = onAutoCheckout;
    }

    print('📍 Starting location monitoring for $userName at ${store.name}');

    // Check and request permissions
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      print('📍 Location permission denied, cannot monitor');
      return;
    }

    // Show foreground notification (keeps monitoring alive on Android)
    await _showForegroundNotification();

    // Platform-specific location settings for better background support
    late LocationSettings locationSettings;

    if (Platform.isIOS) {
      // iOS-specific settings for background location
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true, // Shows blue bar on iOS
        allowBackgroundLocationUpdates: true,
      );
      print('📍 Using iOS AppleSettings for background location');
    } else {
      // Android settings
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'يتم تتبع موقعك خلال فترة العمل',
          notificationTitle: 'تتبع الموقع نشط',
          enableWakeLock: true,
        ),
      );
      print('📍 Using Android settings for background location');
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('📍 Position stream error: $error');
        // Retry connection on error
        _retryLocationStream();
      },
    );

    // Start periodic location check (every 1-2 minutes)
    _periodicLocationTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkCurrentLocation(),
    );

    // Do initial check
    await _checkCurrentLocation();
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicLocationTimer?.cancel();
    _periodicLocationTimer = null;
    _autoCheckoutTimer?.cancel();
    _autoCheckoutTimer = null;
    _isMonitoring = false;
    _alertSent = false;
    _outsideRadiusSince = null;
    _warningShown = false;
    _currentUserId = null;
    _currentUserName = null;
    _currentStore = null;
    _currentAttendance = null;

    // Cancel foreground notification
    await _notifications.cancel(_foregroundNotificationId);

    print('📍 Stopped location monitoring');
  }

  /// Retry location stream on error
  static Future<void> _retryLocationStream() async {
    if (!_isMonitoring || _currentStore == null) return;

    print('📍 Retrying location stream connection...');
    await Future.delayed(const Duration(seconds: 5));

    if (!_isMonitoring) return;

    // Cancel existing subscription
    await _positionSubscription?.cancel();

    // Recreate location stream
    late LocationSettings locationSettings;

    if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 50,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 30),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'يتم تتبع موقعك خلال فترة العمل',
          notificationTitle: 'تتبع الموقع نشط',
          enableWakeLock: true,
        ),
      );
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onPositionUpdate,
      onError: (error) {
        print('📍 Position stream error on retry: $error');
        // Try again after delay
        Future.delayed(const Duration(seconds: 30), () => _retryLocationStream());
      },
    );

    print('📍 Location stream reconnected');
  }

  /// Pause monitoring during break (no 400m alerts, no auto-checkout)
  static void pauseForBreak() {
    _isPausedForBreak = true;
    // Cancel auto-checkout timer during break
    _autoCheckoutTimer?.cancel();
    _autoCheckoutTimer = null;
    _outsideRadiusSince = null;
    _warningShown = false;
    print('📍 Location monitoring paused for break');
  }

  /// Resume monitoring after break
  static void resumeFromBreak() {
    _isPausedForBreak = false;
    _alertSent = false; // Reset alert state
    _outsideRadiusSince = null;
    _warningShown = false;
    print('📍 Location monitoring resumed after break');
    // Do immediate location check after resuming
    _checkCurrentLocation();
  }

  /// Check if paused for break
  static bool get isPausedForBreak => _isPausedForBreak;

  /// Handle position updates from stream
  static void _onPositionUpdate(Position position) {
    if (!_isMonitoring || _currentStore == null) return;

    // Skip location alerts during break
    if (_isPausedForBreak) {
      print('📍 On break - skipping location check');
      return;
    }

    final distance = _currentStore!.getDistanceFrom(
      position.latitude,
      position.longitude,
    );

    print('📍 Position update: ${distance.toStringAsFixed(0)}m from store');

    if (distance > _alertDistanceMeters) {
      _handleOutsideRadius(distance, position);
    } else {
      _handleInsideRadius();
    }

    // Store location history
    _storeLocationHistory(position, distance);
  }

  /// Handle when employee is outside the allowed radius
  static Future<void> _handleOutsideRadius(double distance, Position position) async {
    // Start tracking time outside radius
    if (_outsideRadiusSince == null) {
      _outsideRadiusSince = DateTime.now();
      print('📍 Employee left store radius at ${_outsideRadiusSince}');
    }

    final minutesOutside = DateTime.now().difference(_outsideRadiusSince!).inMinutes;

    // Send initial alert
    if (!_alertSent) {
      await _sendDistanceAlert(distance, position);
    }

    // Show warning at 5 minutes
    if (minutesOutside >= _warningMinutes && !_warningShown) {
      _warningShown = true;
      await NotificationService.showAlarmNotification(
        id: 9002,
        title: '⚠️ تحذير: ستسجل خروج تلقائي!',
        body: 'أنت خارج نطاق العمل منذ $minutesOutside دقائق.\nسيتم تسجيل خروجك تلقائياً بعد ${_autoCheckoutMinutes - minutesOutside} دقائق.',
      );

      // Notify admin about warning
      await _firestore.collection('notifications').add({
        'type': 'location_warning',
        'title': 'تحذير: موظف خارج نطاق العمل',
        'body': '${_currentUserName} خارج نطاق ${_currentStore!.name} منذ $minutesOutside دقائق',
        'userId': _currentUserId,
        'userName': _currentUserName,
        'storeId': _currentStore!.id,
        'storeName': _currentStore!.name,
        'distance': distance,
        'minutesOutside': minutesOutside,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });
    }

    // Auto-checkout at 10 minutes
    if (minutesOutside >= _autoCheckoutMinutes && _onAutoCheckout != null) {
      print('📍 Auto-checkout triggered after $minutesOutside minutes outside radius');

      // Notify before auto-checkout
      await NotificationService.showAlarmNotification(
        id: 9003,
        title: '🚨 تم تسجيل خروجك تلقائياً',
        body: 'تم تسجيل خروجك من ${_currentStore!.name} لأنك كنت خارج نطاق العمل لأكثر من $_autoCheckoutMinutes دقائق.',
      );

      // Notify admin about auto-checkout
      await _firestore.collection('notifications').add({
        'type': 'auto_checkout',
        'title': 'تسجيل خروج تلقائي',
        'body': 'تم تسجيل خروج ${_currentUserName} تلقائياً لخروجه عن نطاق ${_currentStore!.name} لأكثر من $_autoCheckoutMinutes دقائق',
        'userId': _currentUserId,
        'userName': _currentUserName,
        'storeId': _currentStore!.id,
        'storeName': _currentStore!.name,
        'distance': distance,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'minutesOutside': minutesOutside,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      // Execute auto-checkout callback
      await _onAutoCheckout!();
    }
  }

  /// Handle when employee is back inside the allowed radius
  static void _handleInsideRadius() {
    // Reset alert flag when back in range
    if (_alertSent || _outsideRadiusSince != null) {
      print('📍 Employee back in range');
      _alertSent = false;
      _outsideRadiusSince = null;
      _warningShown = false;
      _notifyBackInRange();
    }
  }

  /// Store location history in Firestore
  static Future<void> _storeLocationHistory(Position position, double distance) async {
    if (_currentAttendance == null) return;

    try {
      await _firestore.collection('location_history').add({
        'attendanceId': _currentAttendance!.id,
        'userId': _currentUserId,
        'userName': _currentUserName,
        'storeId': _currentStore?.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'distance': distance,
        'isOutsideRadius': distance > _alertDistanceMeters,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('📍 Error storing location history: $e');
    }
  }

  /// Check current location (one-time)
  static Future<void> _checkCurrentLocation() async {
    if (!_isMonitoring || _currentStore == null) return;
    if (_isPausedForBreak) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final distance = _currentStore!.getDistanceFrom(
        position.latitude,
        position.longitude,
      );

      print('📍 Periodic check: ${distance.toStringAsFixed(0)}m from store');

      if (distance > _alertDistanceMeters) {
        await _handleOutsideRadius(distance, position);
      } else {
        _handleInsideRadius();
      }

      // Store location history
      await _storeLocationHistory(position, distance);
    } catch (e) {
      print('📍 Error checking location: $e');
    }
  }

  /// Check and request location permission
  static Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('📍 Location services disabled');
      // Show notification to user
      await NotificationService.showAlarmNotification(
        id: 9999,
        title: 'خدمة الموقع معطلة',
        body: 'يرجى تفعيل خدمة الموقع لتتبع الحضور',
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    print('📍 Current location permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('📍 Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('📍 Location permission denied forever');
      await NotificationService.showAlarmNotification(
        id: 9998,
        title: 'صلاحية الموقع مرفوضة',
        body: 'يرجى تفعيل صلاحية الموقع من الإعدادات',
      );
      return false;
    }

    // For background location (especially on iOS)
    if (permission == LocationPermission.whileInUse) {
      print('📍 Have "while in use" permission, requesting "always" for background...');
      // On iOS, this will prompt for "always" permission
      // On Android 10+, need to request separately
      if (Platform.isAndroid) {
        permission = await Geolocator.requestPermission();
      }
      // On iOS, "while in use" should still work with allowBackgroundLocationUpdates
      // but user will see blue bar in status bar
    }

    print('📍 Final location permission: $permission');
    return permission == LocationPermission.always ||
           permission == LocationPermission.whileInUse;
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

  // ============ FREE EMPLOYEE LOCATION TRACKING ============

  static bool _isFreeEmployeeTracking = false;
  static String? _freeEmployeeId;
  static String? _freeEmployeeName;
  static String? _freeEmployeeAttendanceId;
  static Timer? _freeEmployeeLocationTimer;
  static Position? _lastKnownPosition;

  /// Check if free employee tracking is active
  static bool get isFreeEmployeeTracking => _isFreeEmployeeTracking;

  /// Get last known position of free employee
  static Position? get lastKnownPosition => _lastKnownPosition;

  /// Start tracking a free employee (no store constraint)
  static Future<void> startFreeEmployeeTracking({
    required String userId,
    required String userName,
    required String attendanceId,
  }) async {
    // Stop any existing tracking
    await stopFreeEmployeeTracking();

    _freeEmployeeId = userId;
    _freeEmployeeName = userName;
    _freeEmployeeAttendanceId = attendanceId;
    _isFreeEmployeeTracking = true;

    print('📍 Starting free employee tracking for $userName');

    // Check and request permissions
    final hasPermission = await _checkAndRequestPermission();
    if (!hasPermission) {
      print('📍 Location permission denied, cannot track');
      return;
    }

    // Show foreground notification
    await _showFreeEmployeeForegroundNotification();

    // Start position stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // Update every 50 meters movement
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      _onFreeEmployeePositionUpdate,
      onError: (error) {
        print('📍 Free employee position stream error: $error');
      },
    );

    // Start periodic location tracking (every 2 minutes)
    _freeEmployeeLocationTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _trackFreeEmployeeLocation(),
    );

    // Do initial tracking
    await _trackFreeEmployeeLocation();
  }

  /// Stop free employee tracking
  static Future<void> stopFreeEmployeeTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _freeEmployeeLocationTimer?.cancel();
    _freeEmployeeLocationTimer = null;
    _isFreeEmployeeTracking = false;
    _freeEmployeeId = null;
    _freeEmployeeName = null;
    _freeEmployeeAttendanceId = null;
    _lastKnownPosition = null;

    // Cancel foreground notification
    await _notifications.cancel(_foregroundNotificationId);

    print('📍 Stopped free employee tracking');
  }

  /// Handle position updates for free employee
  static Future<void> _onFreeEmployeePositionUpdate(Position position) async {
    if (!_isFreeEmployeeTracking) return;

    _lastKnownPosition = position;
    print('📍 Free employee position update: ${position.latitude}, ${position.longitude}');

    // Store location in Firestore
    await _storeFreeEmployeeLocation(position);
  }

  /// Track free employee location (periodic)
  static Future<void> _trackFreeEmployeeLocation() async {
    if (!_isFreeEmployeeTracking) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastKnownPosition = position;
      print('📍 Free employee periodic location: ${position.latitude}, ${position.longitude}');

      // Store location in Firestore
      await _storeFreeEmployeeLocation(position);
    } catch (e) {
      print('📍 Error tracking free employee location: $e');
    }
  }

  /// Store free employee location in Firestore
  static Future<void> _storeFreeEmployeeLocation(Position position) async {
    if (_freeEmployeeAttendanceId == null) return;

    try {
      // Store in location_history collection
      await _firestore.collection('location_history').add({
        'attendanceId': _freeEmployeeAttendanceId,
        'userId': _freeEmployeeId,
        'userName': _freeEmployeeName,
        'employeeType': 'free',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'heading': position.heading,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update current location in attendance record
      await _firestore.collection('attendance').doc(_freeEmployeeAttendanceId).update({
        'currentLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('📍 Error storing free employee location: $e');
    }
  }

  /// Show foreground notification for free employee
  static Future<void> _showFreeEmployeeForegroundNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'location_monitoring',
      'Location Monitoring',
      channelDescription: 'Monitors your location during work',
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
      'يتم تسجيل موقعك خلال فترة العمل',
      details,
    );
  }

  /// Get free employee's current location (for admin to view)
  static Future<Map<String, dynamic>?> getFreeEmployeeCurrentLocation(String attendanceId) async {
    try {
      final doc = await _firestore.collection('attendance').doc(attendanceId).get();
      if (doc.exists && doc.data()?['currentLocation'] != null) {
        return doc.data()!['currentLocation'] as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting free employee location: $e');
      return null;
    }
  }

  /// Get free employee's location history (for admin to view)
  static Future<List<Map<String, dynamic>>> getFreeEmployeeLocationHistory(String attendanceId) async {
    try {
      final snapshot = await _firestore
          .collection('location_history')
          .where('attendanceId', isEqualTo: attendanceId)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Error getting free employee location history: $e');
      return [];
    }
  }

  /// Stream of free employee's location (for real-time admin view)
  static Stream<QuerySnapshot> freeEmployeeLocationStream(String attendanceId) {
    return _firestore
        .collection('location_history')
        .where('attendanceId', isEqualTo: attendanceId)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();
  }
}
