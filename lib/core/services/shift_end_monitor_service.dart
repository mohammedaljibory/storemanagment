import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to monitor shift end times and auto checkout employees
/// who forget to manually check out after their shift ends.
///
/// Features:
/// - Monitors active attendance sessions
/// - Auto checkouts employees after shift end + grace period
/// - Notifies admin of auto checkouts
/// - Can be triggered periodically or on demand
class ShiftEndMonitorService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Timer? _monitorTimer;
  static bool _isRunning = false;

  // Default grace period after shift ends (in minutes)
  static const int defaultGraceMinutes = 30;

  // Notification ID for auto checkout
  static const int _autoCheckoutNotificationId = 8001;

  /// Check if monitoring is running
  static bool get isRunning => _isRunning;

  /// Start periodic monitoring (checks every 5 minutes)
  static void startPeriodicMonitoring() {
    if (_isRunning) return;

    _isRunning = true;
    print('ShiftEnd Monitor started - checking every 5 minutes');

    // Check immediately
    checkAndAutoCheckout();

    // Then check every 5 minutes
    _monitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      checkAndAutoCheckout();
    });
  }

  /// Stop periodic monitoring
  static void stopPeriodicMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isRunning = false;
    print('ShiftEnd Monitor stopped');
  }

  /// Check all active attendance sessions and auto checkout if needed
  /// This can be called periodically or on demand
  static Future<int> checkAndAutoCheckout({int? graceMinutes}) async {
    final grace = graceMinutes ?? defaultGraceMinutes;
    int autoCheckedOutCount = 0;

    try {
      final now = DateTime.now();

      // Fetch all active attendance records (not checked out)
      final snapshot = await _firestore
          .collection('attendance')
          .where('isCheckedOut', isEqualTo: false)
          .get();

      // Also check records without isCheckedOut field (old records)
      final oldRecordsSnapshot = await _firestore
          .collection('attendance')
          .where('checkOut', isNull: true)
          .get();

      // Combine and deduplicate
      final Map<String, QueryDocumentSnapshot> allRecords = {};
      for (var doc in snapshot.docs) {
        allRecords[doc.id] = doc;
      }
      for (var doc in oldRecordsSnapshot.docs) {
        if (!allRecords.containsKey(doc.id)) {
          allRecords[doc.id] = doc;
        }
      }

      for (var doc in allRecords.values) {
        final data = doc.data() as Map<String, dynamic>;

        // Skip if already checked out
        if (data['checkOut'] != null || data['isCheckedOut'] == true) {
          continue;
        }

        // Get check-in time
        DateTime? checkIn;
        if (data['checkIn'] is Timestamp) {
          checkIn = (data['checkIn'] as Timestamp).toDate();
        } else if (data['checkIn'] is String) {
          checkIn = DateTime.tryParse(data['checkIn']);
        }

        if (checkIn == null) continue;

        // Get expected end time
        final expectedEndTime = data['expectedEndTime'] as String?;
        if (expectedEndTime == null) continue;

        // Parse expected end time
        final endTimeParts = expectedEndTime.split(':');
        if (endTimeParts.length != 2) continue;

        try {
          final endHour = int.parse(endTimeParts[0]);
          final endMinute = int.parse(endTimeParts[1]);

          // Calculate expected end DateTime based on check-in
          DateTime expectedEnd = DateTime(
            checkIn.year,
            checkIn.month,
            checkIn.day,
            endHour,
            endMinute,
          );

          // Handle overnight shifts (end time is before start time)
          if (expectedEnd.isBefore(checkIn)) {
            expectedEnd = expectedEnd.add(const Duration(days: 1));
          }

          // Add grace period
          final deadline = expectedEnd.add(Duration(minutes: grace));

          // Check if deadline has passed
          if (now.isAfter(deadline)) {
            // Auto checkout this employee
            final success = await _autoCheckoutEmployee(
              doc: doc,
              data: data,
              checkIn: checkIn,
              expectedEnd: expectedEnd,
              now: now,
            );

            if (success) {
              autoCheckedOutCount++;
            }
          }
        } catch (e) {
          print('Error parsing end time for ${doc.id}: $e');
          continue;
        }
      }

      if (autoCheckedOutCount > 0) {
        print('Auto checkout complete: $autoCheckedOutCount employees');
      }
    } catch (e) {
      print('Error in checkAndAutoCheckout: $e');
    }

    return autoCheckedOutCount;
  }

  /// Auto checkout a specific employee
  static Future<bool> _autoCheckoutEmployee({
    required QueryDocumentSnapshot doc,
    required Map<String, dynamic> data,
    required DateTime checkIn,
    required DateTime expectedEnd,
    required DateTime now,
  }) async {
    try {
      final userId = data['userId'] as String?;
      final userName = data['userName'] as String?;
      final storeName = data['storeName'] as String?;
      final storeId = data['storeId'] as String?;

      // Calculate total hours
      double totalHours = now.difference(checkIn).inMinutes / 60.0;

      // Subtract break time if any
      final breakMinutes = (data['totalBreakMinutes'] as int?) ?? 0;
      if (breakMinutes > 0) {
        totalHours -= (breakMinutes / 60.0);
        if (totalHours < 0) totalHours = 0;
      }

      // Get time-off minutes if any
      int totalTimeOffMinutes = 0;
      try {
        final timeOffMinutes = data['totalTimeOffMinutes'];
        if (timeOffMinutes != null) {
          totalTimeOffMinutes = timeOffMinutes as int;
        }
      } catch (_) {}

      // Calculate how late they are (in minutes after expected end)
      final lateCheckoutMinutes = now.difference(expectedEnd).inMinutes;

      // Update attendance record
      await doc.reference.update({
        'checkOut': now.toIso8601String(),
        'totalHours': totalHours,
        'totalTimeOffMinutes': totalTimeOffMinutes,
        'isCheckedOut': true,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
        'autoCheckout': true,
        'autoCheckoutReason': 'تسجيل خروج تلقائي - تجاوز وقت الشفت بـ $lateCheckoutMinutes دقيقة',
        'notes': (data['notes'] as String? ?? '') + '\nتسجيل خروج تلقائي: ${now.toIso8601String()}',
      });

      print('Auto checkout: $userName from $storeName (${doc.id})');

      // Send notification to employee
      await _sendAutoCheckoutNotification(
        userName: userName ?? 'موظف',
        storeName: storeName ?? 'المتجر',
        totalHours: totalHours,
      );

      // Notify admin
      await _notifyAdminAutoCheckout(
        userId: userId,
        userName: userName ?? 'غير معروف',
        storeId: storeId ?? '',
        storeName: storeName ?? 'غير معروف',
        totalHours: totalHours,
        lateCheckoutMinutes: lateCheckoutMinutes,
      );

      return true;
    } catch (e) {
      print('Error auto checking out employee: $e');
      return false;
    }
  }

  /// Send notification to employee about auto checkout
  static Future<void> _sendAutoCheckoutNotification({
    required String userName,
    required String storeName,
    required double totalHours,
  }) async {
    try {
      await _notifications.show(
        _autoCheckoutNotificationId,
        'تم تسجيل خروجك تلقائياً',
        'تم تسجيل خروجك من $storeName بعد انتهاء وقت الشفت\nإجمالي الساعات: ${totalHours.toStringAsFixed(1)}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_checkout',
            'تسجيل خروج تلقائي',
            channelDescription: 'إشعارات تسجيل الخروج التلقائي',
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
      print('Error sending auto checkout notification: $e');
    }
  }

  /// Notify admin about auto checkout
  static Future<void> _notifyAdminAutoCheckout({
    required String? userId,
    required String userName,
    required String storeId,
    required String storeName,
    required double totalHours,
    required int lateCheckoutMinutes,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'type': 'auto_checkout_shift_end',
        'title': 'تسجيل خروج تلقائي - انتهاء الشفت',
        'body': '$userName تم تسجيل خروجه تلقائياً من $storeName\n'
            'تأخر $lateCheckoutMinutes دقيقة عن تسجيل الخروج\n'
            'إجمالي الساعات: ${totalHours.toStringAsFixed(1)}',
        'userId': userId,
        'userName': userName,
        'storeId': storeId,
        'storeName': storeName,
        'totalHours': totalHours,
        'lateCheckoutMinutes': lateCheckoutMinutes,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      print('Admin notified about auto checkout for $userName');
    } catch (e) {
      print('Error notifying admin about auto checkout: $e');
    }
  }

  /// Get all employees who should be auto checked out
  /// (for preview before actually checking them out)
  static Future<List<Map<String, dynamic>>> getEmployeesNeedingAutoCheckout({int? graceMinutes}) async {
    final grace = graceMinutes ?? defaultGraceMinutes;
    final List<Map<String, dynamic>> result = [];

    try {
      final now = DateTime.now();

      // Fetch all active attendance records
      final snapshot = await _firestore
          .collection('attendance')
          .where('isCheckedOut', isEqualTo: false)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Skip if already checked out
        if (data['checkOut'] != null) continue;

        // Get check-in time
        DateTime? checkIn;
        if (data['checkIn'] is Timestamp) {
          checkIn = (data['checkIn'] as Timestamp).toDate();
        } else if (data['checkIn'] is String) {
          checkIn = DateTime.tryParse(data['checkIn']);
        }

        if (checkIn == null) continue;

        // Get expected end time
        final expectedEndTime = data['expectedEndTime'] as String?;
        if (expectedEndTime == null) continue;

        // Parse expected end time
        final endTimeParts = expectedEndTime.split(':');
        if (endTimeParts.length != 2) continue;

        try {
          final endHour = int.parse(endTimeParts[0]);
          final endMinute = int.parse(endTimeParts[1]);

          DateTime expectedEnd = DateTime(
            checkIn.year,
            checkIn.month,
            checkIn.day,
            endHour,
            endMinute,
          );

          // Handle overnight shifts
          if (expectedEnd.isBefore(checkIn)) {
            expectedEnd = expectedEnd.add(const Duration(days: 1));
          }

          // Add grace period
          final deadline = expectedEnd.add(Duration(minutes: grace));

          // Check if deadline has passed
          if (now.isAfter(deadline)) {
            final lateMinutes = now.difference(expectedEnd).inMinutes;

            result.add({
              'id': doc.id,
              'userId': data['userId'],
              'userName': data['userName'],
              'storeName': data['storeName'],
              'storeId': data['storeId'],
              'checkIn': checkIn,
              'expectedEnd': expectedEnd,
              'deadline': deadline,
              'lateMinutes': lateMinutes,
            });
          }
        } catch (e) {
          continue;
        }
      }
    } catch (e) {
      print('Error getting employees needing auto checkout: $e');
    }

    return result;
  }

  /// Force auto checkout for a specific attendance record
  static Future<bool> forceAutoCheckout(String attendanceId) async {
    try {
      final docRef = _firestore.collection('attendance').doc(attendanceId);
      final doc = await docRef.get();
      if (!doc.exists) return false;

      final data = doc.data()!;

      // Get check-in time
      DateTime? checkIn;
      if (data['checkIn'] is Timestamp) {
        checkIn = (data['checkIn'] as Timestamp).toDate();
      } else if (data['checkIn'] is String) {
        checkIn = DateTime.tryParse(data['checkIn']);
      }

      if (checkIn == null) return false;

      // Get expected end time
      final expectedEndTime = data['expectedEndTime'] as String?;
      if (expectedEndTime == null) return false;

      final endTimeParts = expectedEndTime.split(':');
      if (endTimeParts.length != 2) return false;

      final endHour = int.parse(endTimeParts[0]);
      final endMinute = int.parse(endTimeParts[1]);

      DateTime expectedEnd = DateTime(
        checkIn.year,
        checkIn.month,
        checkIn.day,
        endHour,
        endMinute,
      );

      if (expectedEnd.isBefore(checkIn)) {
        expectedEnd = expectedEnd.add(const Duration(days: 1));
      }

      final now = DateTime.now();
      final userId = data['userId'] as String?;
      final userName = data['userName'] as String?;
      final storeName = data['storeName'] as String?;
      final storeId = data['storeId'] as String?;

      // Calculate total hours
      double totalHours = now.difference(checkIn).inMinutes / 60.0;

      // Subtract break time if any
      final breakMinutes = (data['totalBreakMinutes'] as int?) ?? 0;
      if (breakMinutes > 0) {
        totalHours -= (breakMinutes / 60.0);
        if (totalHours < 0) totalHours = 0;
      }

      // Get time-off minutes if any
      int totalTimeOffMinutes = 0;
      try {
        final timeOffMinutes = data['totalTimeOffMinutes'];
        if (timeOffMinutes != null) {
          totalTimeOffMinutes = timeOffMinutes as int;
        }
      } catch (_) {}

      // Calculate how late they are (in minutes after expected end)
      final lateCheckoutMinutes = now.difference(expectedEnd).inMinutes;

      // Update attendance record
      await docRef.update({
        'checkOut': now.toIso8601String(),
        'totalHours': totalHours,
        'totalTimeOffMinutes': totalTimeOffMinutes,
        'isCheckedOut': true,
        'isEarlyLeave': false,
        'earlyLeaveMinutes': 0,
        'autoCheckout': true,
        'autoCheckoutReason': 'تسجيل خروج تلقائي - تجاوز وقت الشفت بـ $lateCheckoutMinutes دقيقة',
        'notes': (data['notes'] as String? ?? '') + '\nتسجيل خروج تلقائي: ${now.toIso8601String()}',
      });

      print('Force auto checkout: $userName from $storeName ($attendanceId)');

      // Send notification to employee
      await _sendAutoCheckoutNotification(
        userName: userName ?? 'موظف',
        storeName: storeName ?? 'المتجر',
        totalHours: totalHours,
      );

      // Notify admin
      await _notifyAdminAutoCheckout(
        userId: userId,
        userName: userName ?? 'غير معروف',
        storeId: storeId ?? '',
        storeName: storeName ?? 'غير معروف',
        totalHours: totalHours,
        lateCheckoutMinutes: lateCheckoutMinutes,
      );

      return true;
    } catch (e) {
      print('Error in forceAutoCheckout: $e');
      return false;
    }
  }
}
