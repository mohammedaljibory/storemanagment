import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import 'notification_service.dart';
import 'location_monitor_service.dart';

/// Service to manage employee break time during shift
/// - 1 hour break allowed
/// - Pauses location monitoring during break
/// - Alerts if break exceeds time limit
class BreakService extends ChangeNotifier {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton instance
  static final BreakService _instance = BreakService._internal();
  factory BreakService() => _instance;
  BreakService._internal();

  // Break configuration
  static const int allowedBreakMinutes = 60; // 1 hour
  static const int warningBeforeEndMinutes = 5; // Warn 5 min before break ends

  // State
  bool _isOnBreak = false;
  DateTime? _breakStartTime;
  Timer? _breakTimer;
  Timer? _warningTimer;
  String? _currentAttendanceId;
  String? _currentUserId;
  String? _currentUserName;
  int _remainingSeconds = 0;

  // Getters
  bool get isOnBreak => _isOnBreak;
  DateTime? get breakStartTime => _breakStartTime;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedMinutes => _breakStartTime != null
      ? DateTime.now().difference(_breakStartTime!).inMinutes
      : 0;
  bool get isOvertime => elapsedMinutes > allowedBreakMinutes;
  int get overtimeMinutes => isOvertime ? elapsedMinutes - allowedBreakMinutes : 0;

  String get remainingTimeText {
    if (!_isOnBreak) return '--:--';
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get elapsedTimeText {
    if (_breakStartTime == null) return '--:--';
    final elapsed = DateTime.now().difference(_breakStartTime!);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Start break for employee
  Future<bool> startBreak({
    required String attendanceId,
    required String userId,
    required String userName,
  }) async {
    if (_isOnBreak) {
      print('Already on break');
      return false;
    }

    try {
      final now = DateTime.now();
      _breakStartTime = now;
      _isOnBreak = true;
      _currentAttendanceId = attendanceId;
      _currentUserId = userId;
      _currentUserName = userName;
      _remainingSeconds = allowedBreakMinutes * 60;

      // Update Firestore
      await _firestore.collection('attendance').doc(attendanceId).update({
        'breakStartTime': now.toIso8601String(),
        'isOnBreak': true,
      });

      // Pause location monitoring
      LocationMonitorService.pauseForBreak();

      // Start countdown timer
      _startBreakTimer();

      // Schedule warning notification (5 min before break ends)
      _scheduleWarningNotification();

      // Show break started notification
      await NotificationService.showNotification(
        id: 9100,
        title: 'بدأت الاستراحة',
        body: 'لديك $allowedBreakMinutes دقيقة استراحة\nسيتم تنبيهك قبل انتهائها',
        channelId: 'break_channel',
        channelName: 'Break Notifications',
      );

      notifyListeners();
      print('Break started for $userName');
      return true;
    } catch (e) {
      print('Error starting break: $e');
      return false;
    }
  }

  /// End break and return to work
  Future<bool> endBreak() async {
    if (!_isOnBreak || _currentAttendanceId == null) {
      print('Not on break');
      return false;
    }

    try {
      final now = DateTime.now();
      final breakDuration = now.difference(_breakStartTime!).inMinutes;
      final overtime = breakDuration > allowedBreakMinutes
          ? breakDuration - allowedBreakMinutes
          : 0;

      // Update Firestore
      await _firestore.collection('attendance').doc(_currentAttendanceId).update({
        'breakEndTime': now.toIso8601String(),
        'isOnBreak': false,
        'totalBreakMinutes': breakDuration,
        'breakOvertimeMinutes': overtime,
      });

      // Resume location monitoring
      LocationMonitorService.resumeFromBreak();

      // Cancel timers
      _breakTimer?.cancel();
      _warningTimer?.cancel();
      _breakTimer = null;
      _warningTimer = null;

      // Show notification
      String message = 'تم إنهاء الاستراحة - مدة الاستراحة: $breakDuration دقيقة';
      if (overtime > 0) {
        message += '\nتجاوزت وقت الاستراحة بـ $overtime دقيقة';
      }

      await NotificationService.showNotification(
        id: 9101,
        title: 'انتهت الاستراحة',
        body: message,
        channelId: 'break_channel',
        channelName: 'Break Notifications',
      );

      // Reset state
      _isOnBreak = false;
      _breakStartTime = null;
      _currentAttendanceId = null;
      _remainingSeconds = 0;

      notifyListeners();
      print('Break ended');
      return true;
    } catch (e) {
      print('Error ending break: $e');
      return false;
    }
  }

  /// Start countdown timer
  void _startBreakTimer() {
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // Break time exceeded
        _onBreakTimeExceeded();
      }
    });
  }

  /// Schedule warning before break ends
  void _scheduleWarningNotification() {
    final warningTime = (allowedBreakMinutes - warningBeforeEndMinutes) * 60;
    _warningTimer = Timer(Duration(seconds: warningTime), () async {
      if (_isOnBreak) {
        await NotificationService.showAlarmNotification(
          id: 9102,
          title: 'تنبيه: الاستراحة ستنتهي قريباً!',
          body: 'متبقي $warningBeforeEndMinutes دقائق على نهاية الاستراحة\nيرجى العودة للعمل',
        );
      }
    });
  }

  /// Called when break time is exceeded
  Future<void> _onBreakTimeExceeded() async {
    if (!_isOnBreak) return;

    // Send alert to employee
    await NotificationService.showAlarmNotification(
      id: 9103,
      title: 'انتهى وقت الاستراحة!',
      body: 'يرجى العودة للعمل فوراً\nسيتم إبلاغ المدير في حال التأخير',
    );

    // Notify admin
    await _notifyAdminBreakOvertime();

    // Continue tracking overtime
    _breakTimer?.cancel();
    _breakTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isOnBreak) {
        _notifyAdminBreakOvertime();
      } else {
        timer.cancel();
      }
    });
  }

  /// Notify admin about break overtime
  Future<void> _notifyAdminBreakOvertime() async {
    if (_currentUserId == null || _currentUserName == null) return;

    try {
      await _firestore.collection('notifications').add({
        'type': 'break_overtime',
        'title': 'تجاوز وقت الاستراحة',
        'body': '$_currentUserName تجاوز وقت الاستراحة بـ $overtimeMinutes دقيقة',
        'userId': _currentUserId,
        'userName': _currentUserName,
        'attendanceId': _currentAttendanceId,
        'overtimeMinutes': overtimeMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });
      print('Admin notified about break overtime');
    } catch (e) {
      print('Error notifying admin: $e');
    }
  }

  /// Reset break state (call when employee checks out)
  void reset() {
    _breakTimer?.cancel();
    _warningTimer?.cancel();
    _breakTimer = null;
    _warningTimer = null;
    _isOnBreak = false;
    _breakStartTime = null;
    _currentAttendanceId = null;
    _currentUserId = null;
    _currentUserName = null;
    _remainingSeconds = 0;
    notifyListeners();
  }

  /// Check if employee is currently on break (from Firestore)
  Future<void> checkBreakStatus(String attendanceId) async {
    try {
      final doc = await _firestore.collection('attendance').doc(attendanceId).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['isOnBreak'] == true && data['breakStartTime'] != null) {
          _isOnBreak = true;
          _breakStartTime = DateTime.parse(data['breakStartTime']);
          _currentAttendanceId = attendanceId;

          // Calculate remaining time
          final elapsed = DateTime.now().difference(_breakStartTime!).inSeconds;
          final allowed = allowedBreakMinutes * 60;
          _remainingSeconds = allowed - elapsed;
          if (_remainingSeconds < 0) _remainingSeconds = 0;

          // Pause location monitoring
          LocationMonitorService.pauseForBreak();

          // Start timer
          _startBreakTimer();

          notifyListeners();
        }
      }
    } catch (e) {
      print('Error checking break status: $e');
    }
  }
}
