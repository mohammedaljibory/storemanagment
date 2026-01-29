import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Central manager for offline data synchronization
/// Handles:
/// - Connectivity monitoring
/// - Local storage of pending operations
/// - Automatic sync when connection is restored
/// - Queue management for all services
class OfflineSyncManager {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Singleton
  static final OfflineSyncManager _instance = OfflineSyncManager._internal();
  factory OfflineSyncManager() => _instance;
  OfflineSyncManager._internal();

  // Connectivity state
  static bool _isOnline = true;
  static StreamSubscription<dynamic>? _connectivitySubscription;

  // Queue keys for SharedPreferences
  static const String _breakQueueKey = 'offline_break_queue';
  static const String _timeOffQueueKey = 'offline_timeoff_queue';
  static const String _locationQueueKey = 'offline_location_queue';
  static const String _shiftEndQueueKey = 'offline_shiftend_queue';
  static const String _activeBreakKey = 'offline_active_break';
  static const String _activeTimeOffKey = 'offline_active_timeoff';

  // Notification ID
  static const int _syncNotificationId = 9500;

  /// Check if device is online
  static bool get isOnline => _isOnline;

  /// Initialize the sync manager
  static Future<void> initialize() async {
    // Check initial connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    // Handle both old API (single result) and new API (list)
    if (connectivityResult is List) {
      _isOnline = !(connectivityResult as List).contains(ConnectivityResult.none);
    } else {
      _isOnline = connectivityResult != ConnectivityResult.none;
    }
    print('📶 Initial connectivity: ${_isOnline ? "Online" : "Offline"}');

    // Listen for connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      (dynamic result) async {
        final wasOffline = !_isOnline;
        // Handle both old API (single result) and new API (list)
        if (result is List) {
          _isOnline = !(result as List).contains(ConnectivityResult.none);
        } else {
          _isOnline = result != ConnectivityResult.none;
        }

        print('📶 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

        // If we just came back online, sync pending data
        if (_isOnline && wasOffline) {
          print('📶 Back online - syncing pending data...');
          await syncAllPendingData();
        }
      },
    );

    // Try to sync any pending data on startup
    if (_isOnline) {
      await syncAllPendingData();
    }
  }

  /// Dispose of subscriptions
  static void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Check connectivity (one-time check)
  static Future<bool> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    // Handle both old API (single result) and new API (list)
    if (connectivityResult is List) {
      _isOnline = !(connectivityResult as List).contains(ConnectivityResult.none);
    } else {
      _isOnline = connectivityResult != ConnectivityResult.none;
    }
    return _isOnline;
  }

  // ============ BREAK QUEUE MANAGEMENT ============

  /// Add break operation to offline queue
  static Future<void> addBreakToQueue({
    required String operation, // 'request', 'start', 'end', 'cancel'
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_breakQueueKey);
    final queue = queueJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(queueJson))
        : <Map<String, dynamic>>[];

    queue.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_breakQueueKey, jsonEncode(queue));
    print('📴 Break operation added to offline queue: $operation');
  }

  /// Get pending break operations
  static Future<List<Map<String, dynamic>>> getBreakQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_breakQueueKey);
    if (queueJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  /// Clear break queue
  static Future<void> clearBreakQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_breakQueueKey);
  }

  /// Save active break state locally
  static Future<void> saveActiveBreakState({
    required String attendanceId,
    required String userId,
    required String userName,
    required DateTime startTime,
    required int allowedMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeBreakKey, jsonEncode({
      'attendanceId': attendanceId,
      'userId': userId,
      'userName': userName,
      'startTime': startTime.toIso8601String(),
      'allowedMinutes': allowedMinutes,
    }));
    print('📴 Active break state saved locally');
  }

  /// Get active break state from local storage
  static Future<Map<String, dynamic>?> getActiveBreakState() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_activeBreakKey);
    if (json == null) return null;
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  /// Clear active break state
  static Future<void> clearActiveBreakState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeBreakKey);
  }

  // ============ TIME-OFF QUEUE MANAGEMENT ============

  /// Save active time-off state locally
  static Future<void> saveActiveTimeOffState({
    required String requestId,
    required String userId,
    required String userName,
    required String expectedReturnTime,
    required int graceMinutes,
    required String startTime,
    required String endTime,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeTimeOffKey, jsonEncode({
      'requestId': requestId,
      'userId': userId,
      'userName': userName,
      'expectedReturnTime': expectedReturnTime,
      'graceMinutes': graceMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'savedAt': DateTime.now().toIso8601String(),
    }));
    print('📴 Active time-off state saved locally');
  }

  /// Get active time-off state from local storage
  static Future<Map<String, dynamic>?> getActiveTimeOffState() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_activeTimeOffKey);
    if (json == null) return null;
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  /// Clear active time-off state
  static Future<void> clearActiveTimeOffState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeTimeOffKey);
  }

  /// Add time-off operation to queue
  static Future<void> addTimeOffToQueue({
    required String operation, // 'block', 'return', 'auto_checkout'
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_timeOffQueueKey);
    final queue = queueJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(queueJson))
        : <Map<String, dynamic>>[];

    queue.add({
      'operation': operation,
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_timeOffQueueKey, jsonEncode(queue));
    print('📴 Time-off operation added to offline queue: $operation');
  }

  /// Get pending time-off operations
  static Future<List<Map<String, dynamic>>> getTimeOffQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_timeOffQueueKey);
    if (queueJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  /// Clear time-off queue
  static Future<void> clearTimeOffQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_timeOffQueueKey);
  }

  // ============ LOCATION QUEUE MANAGEMENT ============

  /// Add location data to offline queue
  static Future<void> addLocationToQueue({
    required String attendanceId,
    required String userId,
    required double latitude,
    required double longitude,
    required double distance,
    required bool isOutsideRadius,
    required DateTime timestamp,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_locationQueueKey);
    final queue = queueJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(queueJson))
        : <Map<String, dynamic>>[];

    // Limit queue size to prevent memory issues (keep last 100)
    if (queue.length > 100) {
      queue.removeRange(0, queue.length - 100);
    }

    queue.add({
      'attendanceId': attendanceId,
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'isOutsideRadius': isOutsideRadius,
      'timestamp': timestamp.toIso8601String(),
    });

    await prefs.setString(_locationQueueKey, jsonEncode(queue));
  }

  /// Get pending location data
  static Future<List<Map<String, dynamic>>> getLocationQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_locationQueueKey);
    if (queueJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  /// Clear location queue
  static Future<void> clearLocationQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationQueueKey);
  }

  // ============ SHIFT END QUEUE MANAGEMENT ============

  /// Add shift end auto-checkout to queue
  static Future<void> addShiftEndToQueue({
    required String attendanceId,
    required String userId,
    required String userName,
    required String storeName,
    required DateTime checkoutTime,
    required double totalHours,
    required int lateMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_shiftEndQueueKey);
    final queue = queueJson != null
        ? List<Map<String, dynamic>>.from(jsonDecode(queueJson))
        : <Map<String, dynamic>>[];

    queue.add({
      'attendanceId': attendanceId,
      'userId': userId,
      'userName': userName,
      'storeName': storeName,
      'checkoutTime': checkoutTime.toIso8601String(),
      'totalHours': totalHours,
      'lateMinutes': lateMinutes,
    });

    await prefs.setString(_shiftEndQueueKey, jsonEncode(queue));
    print('📴 Shift end auto-checkout added to offline queue');
  }

  /// Get pending shift end operations
  static Future<List<Map<String, dynamic>>> getShiftEndQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queueJson = prefs.getString(_shiftEndQueueKey);
    if (queueJson == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
  }

  /// Clear shift end queue
  static Future<void> clearShiftEndQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shiftEndQueueKey);
  }

  // ============ SYNC ALL PENDING DATA ============

  /// Sync all pending data to Firestore
  static Future<void> syncAllPendingData() async {
    if (!_isOnline) {
      print('📴 Cannot sync - still offline');
      return;
    }

    print('🔄 Starting sync of all pending data...');

    int syncedCount = 0;

    // Sync breaks
    syncedCount += await _syncBreakQueue();

    // Sync time-off
    syncedCount += await _syncTimeOffQueue();

    // Sync locations
    syncedCount += await _syncLocationQueue();

    // Sync shift end auto-checkouts
    syncedCount += await _syncShiftEndQueue();

    if (syncedCount > 0) {
      print('✅ Synced $syncedCount pending operations');

      // Show notification
      await _notifications.show(
        _syncNotificationId,
        'تمت المزامنة',
        'تم مزامنة $syncedCount عملية معلقة',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sync_channel',
            'Sync Notifications',
            channelDescription: 'Offline sync notifications',
            importance: Importance.low,
            priority: Priority.low,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  /// Sync pending break operations
  static Future<int> _syncBreakQueue() async {
    final queue = await getBreakQueue();
    if (queue.isEmpty) return 0;

    int synced = 0;
    final failedItems = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        final operation = item['operation'] as String;
        final data = Map<String, dynamic>.from(item['data']);

        switch (operation) {
          case 'request':
            await _firestore.collection('break_requests').add(data);
            break;
          case 'start':
            await _firestore.collection('attendance').doc(data['attendanceId']).update({
              'breakStartTime': data['startTime'],
              'isOnBreak': true,
            });
            break;
          case 'end':
            await _firestore.collection('attendance').doc(data['attendanceId']).update({
              'breakEndTime': data['endTime'],
              'isOnBreak': false,
              'totalBreakMinutes': data['totalBreakMinutes'],
              'breakOvertimeMinutes': data['overtimeMinutes'],
            });
            break;
          case 'cancel':
            await _firestore.collection('break_requests').doc(data['requestId']).update({
              'status': 'cancelled',
              'cancelledAt': data['cancelledAt'],
            });
            break;
        }
        synced++;
      } catch (e) {
        print('❌ Failed to sync break operation: $e');
        failedItems.add(item);
      }
    }

    // Clear synced items, keep failed ones
    if (failedItems.isEmpty) {
      await clearBreakQueue();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_breakQueueKey, jsonEncode(failedItems));
    }

    return synced;
  }

  /// Sync pending time-off operations
  static Future<int> _syncTimeOffQueue() async {
    final queue = await getTimeOffQueue();
    if (queue.isEmpty) return 0;

    int synced = 0;
    final failedItems = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        final operation = item['operation'] as String;
        final data = Map<String, dynamic>.from(item['data']);

        switch (operation) {
          case 'block':
            await _firestore.collection('requests').doc(data['requestId']).update({
              'timeOffReturnStatus': 'blocked',
            });
            // Also auto-checkout if attendance ID provided
            if (data['attendanceId'] != null) {
              await _firestore.collection('attendance').doc(data['attendanceId']).update({
                'checkOut': data['checkoutTime'],
                'totalHours': data['totalHours'],
                'isCheckedOut': true,
                'isEarlyLeave': true,
                'notes': 'تسجيل خروج تلقائي - تجاوز فترة السماح للزمنية (مزامن)',
              });
            }
            break;
          case 'return':
            await _firestore.collection('requests').doc(data['requestId']).update({
              'timeOffReturnStatus': data['status'],
              'actualReturnTime': data['returnTime'],
            });
            break;
          case 'auto_checkout':
            await _firestore.collection('attendance').doc(data['attendanceId']).update({
              'checkOut': data['checkoutTime'],
              'totalHours': data['totalHours'],
              'totalTimeOffMinutes': data['totalTimeOffMinutes'],
              'isCheckedOut': true,
              'isEarlyLeave': true,
              'notes': data['notes'],
            });
            break;
        }
        synced++;
      } catch (e) {
        print('❌ Failed to sync time-off operation: $e');
        failedItems.add(item);
      }
    }

    if (failedItems.isEmpty) {
      await clearTimeOffQueue();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_timeOffQueueKey, jsonEncode(failedItems));
    }

    return synced;
  }

  /// Sync pending location data
  static Future<int> _syncLocationQueue() async {
    final queue = await getLocationQueue();
    if (queue.isEmpty) return 0;

    int synced = 0;

    try {
      // Batch write for efficiency
      final batch = _firestore.batch();
      int batchCount = 0;

      for (final item in queue) {
        final docRef = _firestore.collection('location_history').doc();
        batch.set(docRef, {
          'attendanceId': item['attendanceId'],
          'userId': item['userId'],
          'latitude': item['latitude'],
          'longitude': item['longitude'],
          'distance': item['distance'],
          'isOutsideRadius': item['isOutsideRadius'],
          'timestamp': DateTime.parse(item['timestamp']),
          'syncedAt': FieldValue.serverTimestamp(),
          'wasOffline': true,
        });

        batchCount++;
        synced++;

        // Firestore batch limit is 500
        if (batchCount >= 450) {
          await batch.commit();
          batchCount = 0;
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }

      await clearLocationQueue();
    } catch (e) {
      print('❌ Failed to sync location queue: $e');
    }

    return synced;
  }

  /// Sync pending shift end auto-checkouts
  static Future<int> _syncShiftEndQueue() async {
    final queue = await getShiftEndQueue();
    if (queue.isEmpty) return 0;

    int synced = 0;
    final failedItems = <Map<String, dynamic>>[];

    for (final item in queue) {
      try {
        await _firestore.collection('attendance').doc(item['attendanceId']).update({
          'checkOut': item['checkoutTime'],
          'totalHours': item['totalHours'],
          'isCheckedOut': true,
          'autoCheckout': true,
          'autoCheckoutReason': 'تسجيل خروج تلقائي - تجاوز وقت الشفت بـ ${item['lateMinutes']} دقيقة (مزامن)',
          'notes': 'تسجيل خروج تلقائي (مزامنة بعد استعادة الاتصال)',
        });

        // Also create admin notification
        await _firestore.collection('notifications').add({
          'type': 'auto_checkout_shift_end_synced',
          'title': 'تسجيل خروج تلقائي (مزامنة)',
          'body': '${item['userName']} تم تسجيل خروجه تلقائياً من ${item['storeName']} (مزامنة)',
          'userId': item['userId'],
          'userName': item['userName'],
          'totalHours': item['totalHours'],
          'lateCheckoutMinutes': item['lateMinutes'],
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'forAdmin': true,
          'wasOffline': true,
        });

        synced++;
      } catch (e) {
        print('❌ Failed to sync shift end: $e');
        failedItems.add(item);
      }
    }

    if (failedItems.isEmpty) {
      await clearShiftEndQueue();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_shiftEndQueueKey, jsonEncode(failedItems));
    }

    return synced;
  }

  // ============ UTILITY METHODS ============

  /// Get total pending operations count
  static Future<int> getPendingCount() async {
    final breaks = await getBreakQueue();
    final timeOffs = await getTimeOffQueue();
    final locations = await getLocationQueue();
    final shiftEnds = await getShiftEndQueue();
    return breaks.length + timeOffs.length + locations.length + shiftEnds.length;
  }

  /// Clear all offline data
  static Future<void> clearAllOfflineData() async {
    await clearBreakQueue();
    await clearTimeOffQueue();
    await clearLocationQueue();
    await clearShiftEndQueue();
    await clearActiveBreakState();
    await clearActiveTimeOffState();
    print('🗑️ All offline data cleared');
  }
}
