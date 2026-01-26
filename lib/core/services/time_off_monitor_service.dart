import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/request_model.dart';
import 'notification_service.dart';

/// Service to monitor time-off requests and track employee return
/// - Sends reminder before time-off ends
/// - Alerts admin if employee doesn't return on time
/// - Blocks check-in if employee exceeds grace period
class TimeOffMonitorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static String? _currentUserId;
  static RequestModel? _activeTimeOff;

  // Notification IDs
  static const int _reminderNotificationId = 9001;
  static const int _returnNotificationId = 9002;
  static const int _blockedNotificationId = 9003;

  // Reminder minutes before end
  static const int _reminderMinutesBefore = 10;

  // Track notification state
  static bool _reminderSent = false;
  static bool _returnAlertSent = false;

  /// Check if there's an active time-off being monitored
  static bool get isMonitoring => _isMonitoring;

  /// Get the active time-off request
  static RequestModel? get activeTimeOff => _activeTimeOff;

  /// Start monitoring a time-off request
  static Future<void> startMonitoring({
    required String userId,
    required RequestModel timeOffRequest,
  }) async {
    // Stop any existing monitoring
    await stopMonitoring();

    if (timeOffRequest.type != RequestType.timeOff ||
        timeOffRequest.status != RequestStatus.approved) {
      print('⏰ Cannot monitor: not an approved time-off request');
      return;
    }

    _currentUserId = userId;
    _activeTimeOff = timeOffRequest;
    _isMonitoring = true;
    _reminderSent = false;
    _returnAlertSent = false;

    print('⏰ Starting time-off monitoring for user $userId');
    print('⏰ Expected return: ${timeOffRequest.expectedReturnTime}');
    print('⏰ Grace period: ${timeOffRequest.graceMinutes} minutes');

    // Update status to active
    await _updateTimeOffStatus(TimeOffReturnStatus.active);

    // Notify admin that time-off started
    await _notifyAdminTimeOffStarted();

    // Start periodic check (every minute)
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkTimeOffStatus();
    });

    // Also check immediately
    _checkTimeOffStatus();
  }

  /// Stop monitoring
  static Future<void> stopMonitoring() async {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    _currentUserId = null;
    _activeTimeOff = null;
    _reminderSent = false;
    _returnAlertSent = false;

    print('⏰ Time-off monitoring stopped');
  }

  /// Check time-off status and send notifications
  static Future<void> _checkTimeOffStatus() async {
    if (_activeTimeOff == null || _currentUserId == null) return;

    final now = DateTime.now();
    final expectedReturn = _activeTimeOff!.expectedReturnDateTime;
    final deadline = _activeTimeOff!.returnDeadline;

    if (expectedReturn == null || deadline == null) return;

    // Calculate time differences
    final minutesUntilReturn = expectedReturn.difference(now).inMinutes;
    final minutesUntilDeadline = deadline.difference(now).inMinutes;

    print('⏰ Check: $minutesUntilReturn min until return, $minutesUntilDeadline min until deadline');

    // Send reminder 10 minutes before expected return
    if (!_reminderSent && minutesUntilReturn <= _reminderMinutesBefore && minutesUntilReturn > 0) {
      await _sendReminderNotification(minutesUntilReturn);
      _reminderSent = true;
    }

    // Time-off has ended, employee should return
    if (minutesUntilReturn <= 0 && !_returnAlertSent) {
      await _sendReturnNotification();
      _returnAlertSent = true;
    }

    // Grace period exceeded - block employee
    if (minutesUntilDeadline <= 0) {
      await _blockEmployee();
    }
  }

  /// Send reminder notification to employee
  static Future<void> _sendReminderNotification(int minutesRemaining) async {
    print('⏰ Sending reminder: $minutesRemaining minutes remaining');

    await _notifications.show(
      _reminderNotificationId,
      'تذكير: زمنيتك على وشك الانتهاء ⏰',
      'يرجى العودة للعمل خلال $minutesRemaining دقيقة',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'time_off_reminder',
          'تذكيرات الزمنية',
          channelDescription: 'تذكيرات انتهاء الزمنية',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Send return notification to employee
  static Future<void> _sendReturnNotification() async {
    if (_activeTimeOff == null) return;

    print('⏰ Sending return alert');

    await _notifications.show(
      _returnNotificationId,
      'انتهت زمنيتك! 🔔',
      'يرجى العودة للعمل وتسجيل الدخول خلال ${_activeTimeOff!.graceMinutes} دقيقة',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'time_off_return',
          'تنبيهات العودة',
          channelDescription: 'تنبيهات العودة من الزمنية',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// Block employee, auto checkout, and notify admin
  static Future<void> _blockEmployee() async {
    if (_activeTimeOff == null || _currentUserId == null) return;

    print('⏰ Blocking employee - grace period exceeded');

    // Update status to blocked
    await _updateTimeOffStatus(TimeOffReturnStatus.blocked);

    // Auto checkout the employee if they have an active session
    await _autoCheckoutEmployee();

    // Show notification to employee
    await _notifications.show(
      _blockedNotificationId,
      '⛔ تم تسجيل خروجك تلقائياً',
      'تأخرت عن العودة من الزمنية أكثر من 15 دقيقة.\nلا يمكنك الدخول مجدداً اليوم.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'time_off_blocked',
          'حظر الدخول',
          channelDescription: 'إشعارات حظر الدخول',
          importance: Importance.max,
          priority: Priority.max,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );

    // Notify admin
    await _notifyAdminEmployeeBlocked();

    // Stop monitoring
    await stopMonitoring();
  }

  /// Auto checkout employee when grace period is exceeded
  static Future<void> _autoCheckoutEmployee() async {
    if (_currentUserId == null) return;

    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Find active attendance session for today
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: _currentUserId)
          .where('isCheckedOut', isEqualTo: false)
          .get();

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        DateTime? checkIn;
        if (data['checkIn'] is Timestamp) {
          checkIn = (data['checkIn'] as Timestamp).toDate();
        } else if (data['checkIn'] is String) {
          checkIn = DateTime.tryParse(data['checkIn']);
        }

        if (checkIn != null && checkIn.isAfter(todayStart)) {
          // This is today's session - auto checkout
          final totalHours = now.difference(checkIn).inMinutes / 60.0;
          final breakMinutes = (data['totalBreakMinutes'] as int?) ?? 0;
          final adjustedHours = totalHours - (breakMinutes / 60.0);

          // Calculate time-off minutes
          int timeOffMinutes = _activeTimeOff?.durationMinutes ?? 0;

          await doc.reference.update({
            'checkOut': now.toIso8601String(),
            'totalHours': adjustedHours > 0 ? adjustedHours : 0,
            'totalTimeOffMinutes': timeOffMinutes,
            'isCheckedOut': true,
            'isEarlyLeave': true,
            'notes': 'تسجيل خروج تلقائي - تجاوز فترة السماح للزمنية',
          });

          print('⏰ Auto checkout completed for attendance: ${doc.id}');
          break;
        }
      }
    } catch (e) {
      print('⏰ Error during auto checkout: $e');
    }
  }

  /// Notify admin that employee didn't return and was auto checked out
  static Future<void> _notifyAdminEmployeeBlocked() async {
    if (_activeTimeOff == null) return;

    try {
      await _firestore.collection('notifications').add({
        'type': 'time_off_blocked',
        'title': '⛔ تسجيل خروج تلقائي - تجاوز زمنية',
        'body': '${_activeTimeOff!.employeeName} تجاوز فترة السماح (15 دقيقة) ولم يعد من الزمنية.\nتم تسجيل خروجه تلقائياً وحظر دخوله لبقية اليوم.',
        'employeeId': _activeTimeOff!.employeeId,
        'employeeName': _activeTimeOff!.employeeName,
        'storeId': _activeTimeOff!.storeId,
        'storeName': _activeTimeOff!.storeName,
        'requestId': _activeTimeOff!.id,
        'expectedReturnTime': _activeTimeOff!.expectedReturnTime,
        'graceMinutes': _activeTimeOff!.graceMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('⏰ Admin notified about blocked employee');
    } catch (e) {
      print('⏰ Error notifying admin: $e');
    }
  }

  /// Notify admin that time-off has started
  static Future<void> _notifyAdminTimeOffStarted() async {
    if (_activeTimeOff == null) return;

    try {
      await _firestore.collection('notifications').add({
        'type': 'time_off_started',
        'title': '🕐 بدأت زمنية موظف',
        'body': '${_activeTimeOff!.employeeName} بدأ زمنيته من ${_activeTimeOff!.startTime} حتى ${_activeTimeOff!.expectedReturnTime}',
        'employeeId': _activeTimeOff!.employeeId,
        'employeeName': _activeTimeOff!.employeeName,
        'storeId': _activeTimeOff!.storeId,
        'storeName': _activeTimeOff!.storeName,
        'requestId': _activeTimeOff!.id,
        'startTime': _activeTimeOff!.startTime,
        'expectedReturnTime': _activeTimeOff!.expectedReturnTime,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('⏰ Admin notified about time-off started');
    } catch (e) {
      print('⏰ Error notifying admin about time-off start: $e');
    }
  }

  /// Notify admin that employee returned from time-off
  static Future<void> _notifyAdminEmployeeReturned({required bool onTime}) async {
    if (_activeTimeOff == null) return;

    try {
      final statusText = onTime ? 'في الوقت المحدد ✅' : 'متأخر (ضمن فترة السماح) ⚠️';

      await _firestore.collection('notifications').add({
        'type': 'time_off_returned',
        'title': '✅ عاد موظف من الزمنية',
        'body': '${_activeTimeOff!.employeeName} عاد من الزمنية $statusText',
        'employeeId': _activeTimeOff!.employeeId,
        'employeeName': _activeTimeOff!.employeeName,
        'storeId': _activeTimeOff!.storeId,
        'storeName': _activeTimeOff!.storeName,
        'requestId': _activeTimeOff!.id,
        'returnedOnTime': onTime,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('⏰ Admin notified about employee return');
    } catch (e) {
      print('⏰ Error notifying admin about return: $e');
    }
  }

  /// Update time-off request status in Firestore
  static Future<void> _updateTimeOffStatus(TimeOffReturnStatus status, {DateTime? actualReturnTime}) async {
    if (_activeTimeOff == null) return;

    try {
      final updateData = {
        'timeOffReturnStatus': status.toString().split('.').last,
      };

      if (actualReturnTime != null) {
        updateData['actualReturnTime'] = actualReturnTime.toIso8601String();
      }

      await _firestore
          .collection('requests')
          .doc(_activeTimeOff!.id)
          .update(updateData);

      // Update local reference
      _activeTimeOff = _activeTimeOff!.copyWith(
        timeOffReturnStatus: status,
        actualReturnTime: actualReturnTime,
      );

      print('⏰ Time-off status updated to: $status');
    } catch (e) {
      print('⏰ Error updating time-off status: $e');
    }
  }

  /// Called when employee successfully checks in (returns from time-off)
  static Future<void> markAsReturned() async {
    if (_activeTimeOff == null) return;

    final now = DateTime.now();
    final expectedReturn = _activeTimeOff!.expectedReturnDateTime;

    TimeOffReturnStatus status;
    bool onTime;
    if (expectedReturn != null && now.isAfter(expectedReturn)) {
      // Returned late (but within grace period)
      status = TimeOffReturnStatus.late;
      onTime = false;
      print('⏰ Employee returned late');
    } else {
      // Returned on time
      status = TimeOffReturnStatus.returned;
      onTime = true;
      print('⏰ Employee returned on time');
    }

    // Notify admin about return
    await _notifyAdminEmployeeReturned(onTime: onTime);

    await _updateTimeOffStatus(status, actualReturnTime: now);
    await stopMonitoring();
  }

  /// Check if employee has an active time-off that blocks check-in
  static Future<Map<String, dynamic>?> checkTimeOffBlockStatus(String employeeId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .where('type', isEqualTo: 'timeOff')
          .where('status', isEqualTo: 'approved')
          .where('targetDate', isGreaterThanOrEqualTo: todayStart.toIso8601String())
          .where('targetDate', isLessThan: todayStart.add(const Duration(days: 1)).toIso8601String())
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        // Convert Firestore Timestamps to ISO strings
        if (data['requestDate'] is Timestamp) {
          data['requestDate'] = (data['requestDate'] as Timestamp).toDate().toIso8601String();
        }
        if (data['targetDate'] is Timestamp) {
          data['targetDate'] = (data['targetDate'] as Timestamp).toDate().toIso8601String();
        }
        if (data['respondedAt'] is Timestamp) {
          data['respondedAt'] = (data['respondedAt'] as Timestamp).toDate().toIso8601String();
        }
        if (data['actualReturnTime'] is Timestamp) {
          data['actualReturnTime'] = (data['actualReturnTime'] as Timestamp).toDate().toIso8601String();
        }
        final request = RequestModel.fromJson(data);

        // Check if blocked
        if (request.timeOffReturnStatus == TimeOffReturnStatus.blocked) {
          return {
            'blocked': true,
            'reason': 'تم حظر تسجيل الدخول لتجاوز فترة السماح من الزمنية',
            'request': request,
          };
        }

        // Check if time-off is still active and return deadline passed
        if (request.isTimeOffActive && request.isReturnDeadlinePassed) {
          return {
            'blocked': true,
            'reason': 'تجاوزت فترة السماح للعودة من الزمنية',
            'request': request,
          };
        }

        // Check if time-off ended but within grace period
        if (request.isTimeOffActive && request.isExpectedReturnTimePassed) {
          return {
            'blocked': false,
            'late': true,
            'minutesLate': request.minutesLate,
            'remainingGraceMinutes': request.remainingMinutesUntilDeadline,
            'request': request,
          };
        }

        // FIX: Block check-in if time-off is still active (before expected return time)
        if (request.isTimeOffActive && !request.isExpectedReturnTimePassed) {
          final returnTime = request.expectedReturnDateTime;
          final remainingMinutes = returnTime != null
              ? returnTime.difference(DateTime.now()).inMinutes
              : 0;
          return {
            'blocked': true,
            'reason': 'الزمنية لا تزال نشطة. يجب الانتظار حتى الساعة ${request.expectedReturnTime}',
            'remainingMinutes': remainingMinutes,
            'request': request,
          };
        }
      }

      return null; // No blocking time-off
    } catch (e) {
      print('⏰ Error checking time-off block status: $e');
      return null;
    }
  }

  /// Get active time-off for employee today
  static Future<RequestModel?> getActiveTimeOffToday(String employeeId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);

      final snapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .where('type', isEqualTo: 'timeOff')
          .where('status', isEqualTo: 'approved')
          .where('targetDate', isGreaterThanOrEqualTo: todayStart.toIso8601String())
          .where('targetDate', isLessThan: todayStart.add(const Duration(days: 1)).toIso8601String())
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;

        // Convert timestamps
        if (data['requestDate'] is Timestamp) {
          data['requestDate'] = (data['requestDate'] as Timestamp).toDate().toIso8601String();
        }
        if (data['targetDate'] is Timestamp) {
          data['targetDate'] = (data['targetDate'] as Timestamp).toDate().toIso8601String();
        }
        if (data['respondedAt'] is Timestamp) {
          data['respondedAt'] = (data['respondedAt'] as Timestamp).toDate().toIso8601String();
        }

        final request = RequestModel.fromJson(data);

        // Return if active or pending return
        if (request.timeOffReturnStatus == TimeOffReturnStatus.active ||
            request.timeOffReturnStatus == TimeOffReturnStatus.pending) {
          return request;
        }
      }

      return null;
    } catch (e) {
      print('⏰ Error getting active time-off: $e');
      return null;
    }
  }

  /// Activate time-off (called when time-off period starts)
  static Future<void> activateTimeOff(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'timeOffReturnStatus': 'active',
      });
      print('⏰ Time-off activated: $requestId');
    } catch (e) {
      print('⏰ Error activating time-off: $e');
    }
  }
}
