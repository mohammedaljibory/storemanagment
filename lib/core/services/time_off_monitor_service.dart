import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/request_model.dart';
import '../models/shift_model.dart';
import 'notification_service.dart';
import 'offline_sync_manager.dart';

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

  // Threshold for considering time-off as "end of shift" (30 minutes before shift end)
  static const int _endOfShiftThresholdMinutes = 30;

  // Track notification state
  static bool _reminderSent = false;
  static bool _returnAlertSent = false;

  /// Check if there's an active time-off being monitored
  static bool get isMonitoring => _isMonitoring;

  /// Get the active time-off request
  static RequestModel? get activeTimeOff => _activeTimeOff;

  /// Start monitoring a time-off request
  /// Works offline - saves state locally for recovery
  /// If time-off is at end of shift, auto-checkouts instead of monitoring
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

    // Check if time-off is at end of shift (no return needed)
    final isEndOfShift = await isTimeOffAtEndOfShift(
      employeeId: userId,
      timeOffRequest: timeOffRequest,
    );

    if (isEndOfShift) {
      print('⏰ Time-off is at end of shift - auto-checkout, no return needed');
      await autoCheckoutForEndOfShiftTimeOff(
        userId: userId,
        timeOffRequest: timeOffRequest,
      );
      return; // Don't start monitoring - employee is done for the day
    }

    _currentUserId = userId;
    _activeTimeOff = timeOffRequest;
    _isMonitoring = true;
    _reminderSent = false;
    _returnAlertSent = false;

    print('⏰ Starting time-off monitoring for user $userId');
    print('⏰ Expected return: ${timeOffRequest.expectedReturnTime}');
    print('⏰ Grace period: ${timeOffRequest.graceMinutes} minutes');

    // Save state locally for offline recovery
    await OfflineSyncManager.saveActiveTimeOffState(
      requestId: timeOffRequest.id,
      userId: userId,
      userName: timeOffRequest.employeeName,
      expectedReturnTime: timeOffRequest.expectedReturnTime ?? '',
      graceMinutes: timeOffRequest.graceMinutes,
      startTime: timeOffRequest.startTime ?? '',
      endTime: timeOffRequest.endTime ?? '',
    );

    // Check connectivity before Firestore operations
    final isOnline = await OfflineSyncManager.checkConnectivity();

    if (isOnline) {
      // Update status to active
      await _updateTimeOffStatus(TimeOffReturnStatus.active);

      // Notify admin that time-off started
      await _notifyAdminTimeOffStarted();
    } else {
      print('⏰ Offline - time-off monitoring will use local timers only');
    }

    // Start periodic check (every minute) - works offline
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

    // Clear local state
    await OfflineSyncManager.clearActiveTimeOffState();

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
  /// Works offline - queues operations for sync
  static Future<void> _blockEmployee() async {
    if (_activeTimeOff == null || _currentUserId == null) return;

    print('⏰ Blocking employee - grace period exceeded');

    // Check connectivity
    final isOnline = await OfflineSyncManager.checkConnectivity();

    if (isOnline) {
      // Update status to blocked
      await _updateTimeOffStatus(TimeOffReturnStatus.blocked);

      // Auto checkout the employee if they have an active session
      await _autoCheckoutEmployee();

      // Notify admin
      await _notifyAdminEmployeeBlocked();
    } else {
      // Offline: Queue block operation for later sync
      await OfflineSyncManager.addTimeOffToQueue(
        operation: 'block',
        data: {
          'requestId': _activeTimeOff!.id,
          'userId': _currentUserId,
          'userName': _activeTimeOff!.employeeName,
          'blockedAt': DateTime.now().toIso8601String(),
        },
      );

      // Also queue auto checkout
      await _autoCheckoutEmployeeOffline();

      print('⏰ Block operation queued for offline sync');
    }

    // Show notification to employee (works offline)
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

    // Stop monitoring
    await stopMonitoring();
  }

  /// Queue auto checkout for offline sync
  static Future<void> _autoCheckoutEmployeeOffline() async {
    if (_currentUserId == null || _activeTimeOff == null) return;

    // Get local time-off state to calculate hours
    final localState = await OfflineSyncManager.getActiveTimeOffState();
    final now = DateTime.now();

    // Queue the auto checkout operation
    await OfflineSyncManager.addTimeOffToQueue(
      operation: 'auto_checkout',
      data: {
        'userId': _currentUserId,
        'userName': _activeTimeOff!.employeeName,
        'checkoutTime': now.toIso8601String(),
        'totalTimeOffMinutes': _activeTimeOff?.durationMinutes ?? 0,
        'notes': 'تسجيل خروج تلقائي - تجاوز فترة السماح للزمنية (بدون إنترنت)',
        'requestId': _activeTimeOff!.id,
      },
    );

    print('⏰ Auto checkout queued for offline sync');
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
  /// Falls back to offline queue if no connection
  static Future<void> _updateTimeOffStatus(TimeOffReturnStatus status, {DateTime? actualReturnTime}) async {
    if (_activeTimeOff == null) return;

    final updateData = <String, dynamic>{
      'timeOffReturnStatus': status.toString().split('.').last,
    };

    if (actualReturnTime != null) {
      updateData['actualReturnTime'] = actualReturnTime.toIso8601String();
    }

    // Check connectivity
    final isOnline = await OfflineSyncManager.checkConnectivity();

    if (isOnline) {
      try {
        await _firestore
            .collection('requests')
            .doc(_activeTimeOff!.id)
            .update(updateData);

        print('⏰ Time-off status updated to: $status');
      } catch (e) {
        print('⏰ Error updating time-off status: $e');
        // Queue for later sync
        await OfflineSyncManager.addTimeOffToQueue(
          operation: 'return',
          data: {
            'requestId': _activeTimeOff!.id,
            'status': status.toString().split('.').last,
            'returnTime': actualReturnTime?.toIso8601String(),
          },
        );
      }
    } else {
      // Queue for offline sync
      await OfflineSyncManager.addTimeOffToQueue(
        operation: 'return',
        data: {
          'requestId': _activeTimeOff!.id,
          'status': status.toString().split('.').last,
          'returnTime': actualReturnTime?.toIso8601String(),
        },
      );
      print('⏰ Time-off status update queued for offline sync');
    }

    // Update local reference
    _activeTimeOff = _activeTimeOff!.copyWith(
      timeOffReturnStatus: status,
      actualReturnTime: actualReturnTime,
    );
  }

  /// Called when employee successfully checks in (returns from time-off)
  /// Works offline - queues return update for sync
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

    // Check connectivity
    final isOnline = await OfflineSyncManager.checkConnectivity();

    if (isOnline) {
      // Notify admin about return
      await _notifyAdminEmployeeReturned(onTime: onTime);
      await _updateTimeOffStatus(status, actualReturnTime: now);
    } else {
      // Queue for offline sync
      await OfflineSyncManager.addTimeOffToQueue(
        operation: 'return',
        data: {
          'requestId': _activeTimeOff!.id,
          'status': status.toString().split('.').last,
          'returnTime': now.toIso8601String(),
          'onTime': onTime,
        },
      );
      print('⏰ Return status queued for offline sync');
    }

    await stopMonitoring();
  }

  /// Restore time-off monitoring from local state (for app restart)
  static Future<void> restoreFromLocalState(String userId) async {
    final localState = await OfflineSyncManager.getActiveTimeOffState();
    if (localState == null || localState['userId'] != userId) {
      return;
    }

    print('⏰ Restoring time-off monitoring from local state');

    _currentUserId = userId;
    _isMonitoring = true;
    _reminderSent = false;
    _returnAlertSent = false;

    // Create a minimal RequestModel-like state from local data
    // Note: We don't have full RequestModel, so we'll use local timers only
    final expectedReturnTime = localState['expectedReturnTime'] as String?;
    final graceMinutes = localState['graceMinutes'] as int? ?? 15;

    if (expectedReturnTime == null || expectedReturnTime.isEmpty) {
      print('⏰ Cannot restore - no expected return time');
      return;
    }

    // Parse expected return time
    final parts = expectedReturnTime.split(':');
    if (parts.length != 2) return;

    final now = DateTime.now();
    final returnHour = int.tryParse(parts[0]) ?? 0;
    final returnMinute = int.tryParse(parts[1]) ?? 0;
    var expectedReturn = DateTime(now.year, now.month, now.day, returnHour, returnMinute);

    // Handle if expected return is before now (might be next day)
    if (expectedReturn.isBefore(now.subtract(Duration(minutes: graceMinutes + 60)))) {
      // Time-off is long past - clear state
      await OfflineSyncManager.clearActiveTimeOffState();
      _isMonitoring = false;
      return;
    }

    final deadline = expectedReturn.add(Duration(minutes: graceMinutes));

    // Start local timer for monitoring
    _monitorTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentTime = DateTime.now();
      final minutesUntilReturn = expectedReturn.difference(currentTime).inMinutes;
      final minutesUntilDeadline = deadline.difference(currentTime).inMinutes;

      print('⏰ Local check: $minutesUntilReturn min until return, $minutesUntilDeadline min until deadline');

      // Send reminder 10 minutes before expected return
      if (!_reminderSent && minutesUntilReturn <= _reminderMinutesBefore && minutesUntilReturn > 0) {
        _sendReminderNotification(minutesUntilReturn);
        _reminderSent = true;
      }

      // Time-off has ended, employee should return
      if (minutesUntilReturn <= 0 && !_returnAlertSent) {
        _sendReturnNotification();
        _returnAlertSent = true;
      }

      // Grace period exceeded - block employee
      if (minutesUntilDeadline <= 0) {
        _blockEmployee();
      }
    });

    print('⏰ Time-off monitoring restored from local state');
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

        // Return if active, pending, or completed with no return (end-of-shift)
        if (request.timeOffReturnStatus == TimeOffReturnStatus.active ||
            request.timeOffReturnStatus == TimeOffReturnStatus.pending ||
            request.timeOffReturnStatus == TimeOffReturnStatus.completedNoReturn) {
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

  /// Check if time-off covers the end of shift (no return needed)
  /// Returns true if time-off end is within 30 minutes of shift end or after it
  static Future<bool> isTimeOffAtEndOfShift({
    required String employeeId,
    required RequestModel timeOffRequest,
  }) async {
    try {
      // Get employee's shift info
      final userDoc = await _firestore.collection('users').doc(employeeId).get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data()!;
      final shiftId = userData['shiftId'] as String?;
      if (shiftId == null || shiftId.isEmpty) return false;

      // Get shift details
      final shiftDoc = await _firestore.collection('shifts').doc(shiftId).get();
      if (!shiftDoc.exists) return false;

      final shiftData = shiftDoc.data()!;
      shiftData['id'] = shiftDoc.id;
      final shift = ShiftModel.fromJson(shiftData);

      // Parse time-off end time
      final timeOffEndTime = timeOffRequest.endTime;
      if (timeOffEndTime == null || timeOffEndTime.isEmpty) return false;

      final timeOffEndParts = timeOffEndTime.split(':');
      if (timeOffEndParts.length != 2) return false;

      final timeOffEndHour = int.tryParse(timeOffEndParts[0]) ?? 0;
      final timeOffEndMinute = int.tryParse(timeOffEndParts[1]) ?? 0;

      final now = DateTime.now();
      final timeOffEndDateTime = DateTime(
        now.year, now.month, now.day,
        timeOffEndHour, timeOffEndMinute,
      );

      // Get shift end time
      final shiftEndDateTime = shift.endDateTime(now);

      // Calculate difference
      final diffMinutes = shiftEndDateTime.difference(timeOffEndDateTime).inMinutes;

      // Time-off is at end of shift if:
      // 1. Time-off ends AT or AFTER shift end (diffMinutes <= 0)
      // 2. OR time-off ends within threshold minutes before shift end
      final isAtEndOfShift = diffMinutes <= _endOfShiftThresholdMinutes;

      print('⏰ Time-off end: $timeOffEndTime, Shift end: ${shift.endTime}');
      print('⏰ Diff minutes: $diffMinutes, Is at end of shift: $isAtEndOfShift');

      return isAtEndOfShift;
    } catch (e) {
      print('⏰ Error checking if time-off is at end of shift: $e');
      return false;
    }
  }

  /// Get employee's shift
  static Future<ShiftModel?> getEmployeeShift(String employeeId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(employeeId).get();
      if (!userDoc.exists) return null;

      final userData = userDoc.data()!;
      final shiftId = userData['shiftId'] as String?;
      if (shiftId == null || shiftId.isEmpty) return null;

      final shiftDoc = await _firestore.collection('shifts').doc(shiftId).get();
      if (!shiftDoc.exists) return null;

      final shiftData = shiftDoc.data()!;
      shiftData['id'] = shiftDoc.id;
      return ShiftModel.fromJson(shiftData);
    } catch (e) {
      print('⏰ Error getting employee shift: $e');
      return null;
    }
  }

  /// Auto-checkout for end-of-shift time-off (no return needed)
  static Future<void> autoCheckoutForEndOfShiftTimeOff({
    required String userId,
    required RequestModel timeOffRequest,
  }) async {
    try {
      print('⏰ Auto-checkout for end-of-shift time-off');

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      // Find active attendance session for today
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
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
          final timeOffMinutes = timeOffRequest.durationMinutes;

          await doc.reference.update({
            'checkOut': now.toIso8601String(),
            'totalHours': adjustedHours > 0 ? adjustedHours : 0,
            'totalTimeOffMinutes': timeOffMinutes,
            'isCheckedOut': true,
            'isEarlyLeave': false, // Not early leave - time-off covered end of shift
            'notes': 'تسجيل خروج تلقائي - زمنية حتى نهاية الدوام',
          });

          print('⏰ Auto checkout completed for end-of-shift time-off');
          break;
        }
      }

      // Update time-off status to completed (no return needed)
      await _firestore.collection('requests').doc(timeOffRequest.id).update({
        'timeOffReturnStatus': 'completedNoReturn',
        'actualReturnTime': now.toIso8601String(),
      });

      // Notify admin
      await _firestore.collection('notifications').add({
        'type': 'time_off_completed_end_of_shift',
        'title': '✅ زمنية حتى نهاية الدوام',
        'body': '${timeOffRequest.employeeName} أخذ زمنية حتى نهاية الدوام وتم تسجيل خروجه تلقائياً',
        'employeeId': timeOffRequest.employeeId,
        'employeeName': timeOffRequest.employeeName,
        'storeId': timeOffRequest.storeId,
        'storeName': timeOffRequest.storeName,
        'requestId': timeOffRequest.id,
        'startTime': timeOffRequest.startTime,
        'endTime': timeOffRequest.endTime,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      // Show notification to employee
      await _notifications.show(
        9004, // New notification ID for end-of-shift checkout
        '✅ تم تسجيل خروجك',
        'زمنيتك حتى نهاية الدوام. تم تسجيل خروجك تلقائياً. يوماً سعيداً!',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'time_off_end_of_shift',
            'زمنية نهاية الدوام',
            channelDescription: 'إشعارات زمنية نهاية الدوام',
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
    } catch (e) {
      print('⏰ Error auto-checkout for end-of-shift time-off: $e');
    }
  }
}
