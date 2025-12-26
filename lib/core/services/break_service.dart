import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/attendance_model.dart';
import 'notification_service.dart';
import 'location_monitor_service.dart';

/// Break request status
enum BreakRequestStatus { pending, approved, rejected, completed, cancelled }

/// Service to manage employee break time during shift
/// - Break requires admin approval
/// - 1 hour break allowed after approval
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
  bool _hasPendingRequest = false;
  String? _pendingRequestId;
  DateTime? _breakStartTime;
  Timer? _breakTimer;
  Timer? _warningTimer;
  String? _currentAttendanceId;
  String? _currentUserId;
  String? _currentUserName;
  int _remainingSeconds = 0;
  BreakRequestStatus _requestStatus = BreakRequestStatus.pending;

  // Getters
  bool get isOnBreak => _isOnBreak;
  bool get hasPendingRequest => _hasPendingRequest;
  String? get pendingRequestId => _pendingRequestId;
  BreakRequestStatus get requestStatus => _requestStatus;
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

  /// Request break (sends to admin for approval)
  Future<bool> requestBreak({
    required String attendanceId,
    required String userId,
    required String userName,
    required String storeId,
    required String storeName,
  }) async {
    if (_isOnBreak || _hasPendingRequest) {
      return false;
    }

    try {
      final now = DateTime.now();

      // Create break request in Firestore
      final docRef = await _firestore.collection('break_requests').add({
        'attendanceId': attendanceId,
        'userId': userId,
        'userName': userName,
        'storeId': storeId,
        'storeName': storeName,
        'requestedAt': now.toIso8601String(),
        'status': 'pending',
        'allowedMinutes': allowedBreakMinutes,
      });

      _pendingRequestId = docRef.id;
      _hasPendingRequest = true;
      _currentAttendanceId = attendanceId;
      _currentUserId = userId;
      _currentUserName = userName;
      _requestStatus = BreakRequestStatus.pending;

      // Notify admin about break request
      await _firestore.collection('notifications').add({
        'type': 'break_request',
        'title': 'طلب استراحة',
        'body': '$userName يطلب استراحة لمدة $allowedBreakMinutes دقيقة',
        'userId': userId,
        'userName': userName,
        'storeId': storeId,
        'storeName': storeName,
        'breakRequestId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      // Show notification to employee
      await NotificationService.showNotification(
        id: 9100,
        title: 'تم إرسال طلب الاستراحة',
        body: 'بانتظار موافقة المدير',
        channelId: 'break_channel',
        channelName: 'Break Notifications',
      );

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Admin approves break request
  Future<bool> approveBreakRequest(String requestId) async {
    try {
      final doc = await _firestore.collection('break_requests').doc(requestId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;
      final now = DateTime.now();

      // Update request status
      await _firestore.collection('break_requests').doc(requestId).update({
        'status': 'approved',
        'approvedAt': now.toIso8601String(),
      });

      // Update attendance record
      await _firestore.collection('attendance').doc(data['attendanceId']).update({
        'breakStartTime': now.toIso8601String(),
        'isOnBreak': true,
        'breakApproved': true,
      });

      // Notify employee
      await _firestore.collection('notifications').add({
        'type': 'break_approved',
        'title': 'تمت الموافقة على الاستراحة ✅',
        'body': 'يمكنك الآن أخذ استراحتك لمدة $allowedBreakMinutes دقيقة',
        'userId': data['userId'],
        'breakRequestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': false,
        'targetUserId': data['userId'],
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Admin rejects break request
  Future<bool> rejectBreakRequest(String requestId, String reason) async {
    try {
      final doc = await _firestore.collection('break_requests').doc(requestId).get();
      if (!doc.exists) return false;

      final data = doc.data()!;

      // Update request status
      await _firestore.collection('break_requests').doc(requestId).update({
        'status': 'rejected',
        'rejectedAt': DateTime.now().toIso8601String(),
        'rejectionReason': reason,
      });

      // Notify employee
      await _firestore.collection('notifications').add({
        'type': 'break_rejected',
        'title': 'تم رفض طلب الاستراحة ❌',
        'body': 'السبب: $reason',
        'userId': data['userId'],
        'breakRequestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': false,
        'targetUserId': data['userId'],
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Start break after admin approval (called by employee or auto-triggered)
  Future<bool> startApprovedBreak({
    required String attendanceId,
    required String userId,
    required String userName,
  }) async {
    if (_isOnBreak) {
      return false;
    }

    try {
      final now = DateTime.now();
      _breakStartTime = now;
      _isOnBreak = true;
      _hasPendingRequest = false;
      _currentAttendanceId = attendanceId;
      _currentUserId = userId;
      _currentUserName = userName;
      _remainingSeconds = allowedBreakMinutes * 60;
      _requestStatus = BreakRequestStatus.approved;

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
        id: 9101,
        title: 'بدأت الاستراحة',
        body: 'لديك $allowedBreakMinutes دقيقة استراحة\nسيتم تنبيهك قبل انتهائها',
        channelId: 'break_channel',
        channelName: 'Break Notifications',
      );

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel pending break request
  Future<bool> cancelBreakRequest() async {
    if (!_hasPendingRequest || _pendingRequestId == null) {
      return false;
    }

    try {
      await _firestore.collection('break_requests').doc(_pendingRequestId).update({
        'status': 'cancelled',
        'cancelledAt': DateTime.now().toIso8601String(),
      });

      _hasPendingRequest = false;
      _pendingRequestId = null;
      _requestStatus = BreakRequestStatus.cancelled;

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// End break and return to work
  Future<bool> endBreak() async {
    if (!_isOnBreak || _currentAttendanceId == null) {
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

      // Update break request if exists
      if (_pendingRequestId != null) {
        await _firestore.collection('break_requests').doc(_pendingRequestId).update({
          'status': 'completed',
          'completedAt': now.toIso8601String(),
          'actualDuration': breakDuration,
          'overtimeMinutes': overtime,
        });
      }

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
        id: 9102,
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
      _requestStatus = BreakRequestStatus.completed;

      notifyListeners();
      return true;
    } catch (e) {
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
          id: 9103,
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
      id: 9104,
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
    } catch (e) {
      // Silent fail
    }
  }

  /// Reset break state (call when employee checks out)
  void reset() {
    _breakTimer?.cancel();
    _warningTimer?.cancel();
    _breakTimer = null;
    _warningTimer = null;
    _isOnBreak = false;
    _hasPendingRequest = false;
    _pendingRequestId = null;
    _breakStartTime = null;
    _currentAttendanceId = null;
    _currentUserId = null;
    _currentUserName = null;
    _remainingSeconds = 0;
    _requestStatus = BreakRequestStatus.pending;
    notifyListeners();
  }

  /// Check break status from Firestore (for app restart)
  Future<void> checkBreakStatus(String attendanceId, String userId) async {
    try {
      // Check for pending break request
      final pendingRequests = await _firestore
          .collection('break_requests')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingRequests.docs.isNotEmpty) {
        final request = pendingRequests.docs.first;
        _hasPendingRequest = true;
        _pendingRequestId = request.id;
        _requestStatus = BreakRequestStatus.pending;
        notifyListeners();
        return;
      }

      // Check attendance for active break
      final doc = await _firestore.collection('attendance').doc(attendanceId).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['isOnBreak'] == true && data['breakStartTime'] != null) {
          _isOnBreak = true;
          _breakStartTime = DateTime.parse(data['breakStartTime']);
          _currentAttendanceId = attendanceId;
          _currentUserId = userId;
          _requestStatus = BreakRequestStatus.approved;

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
      // Silent fail
    }
  }

  /// Listen for break request approval (real-time)
  Stream<DocumentSnapshot> breakRequestStream(String requestId) {
    return _firestore.collection('break_requests').doc(requestId).snapshots();
  }

  /// Get pending break requests (for admin)
  Future<List<Map<String, dynamic>>> getPendingBreakRequests() async {
    try {
      final snapshot = await _firestore
          .collection('break_requests')
          .where('status', isEqualTo: 'pending')
          .orderBy('requestedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Stream of pending break requests (for admin real-time)
  Stream<QuerySnapshot> pendingBreakRequestsStream() {
    return _firestore
        .collection('break_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots();
  }
}
