import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/attendance_model.dart';
import '../models/store_model.dart';
import '../models/shift_model.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<AttendanceModel> _attendanceHistory = [];
  AttendanceModel? _todayAttendance;
  AttendanceModel? _currentSession;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckedIn = false;
  
  // Offline queue
  List<Map<String, dynamic>> _offlineQueue = [];
  bool _isSyncing = false;

  // ============ GETTERS ============
  List<AttendanceModel> get attendanceHistory => [..._attendanceHistory];
  AttendanceModel? get todayAttendance => _todayAttendance;
  AttendanceModel? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isCheckedIn => _isCheckedIn;
  List<Map<String, dynamic>> get offlineQueue => [..._offlineQueue];
  bool get hasOfflineData => _offlineQueue.isNotEmpty;

  // Monthly stats getter (no arguments - returns current month)
  Map<String, dynamic> get monthlyStats {
    final now = DateTime.now();
    return getMonthlyStats(now.year, now.month);
  }

  /// Get monthly stats for a specific year and month
  Map<String, dynamic> getMonthlyStats(int year, int month) {
    final monthAttendance = _attendanceHistory.where((a) =>
        a.checkIn.year == year && a.checkIn.month == month).toList();

    int totalDays = monthAttendance.length;
    int lateDays = monthAttendance.where((a) => a.isLate).length;
    int earlyLeaveDays = monthAttendance.where((a) => a.isEarlyLeave).length;
    int onTimeDays = monthAttendance.where((a) => !a.isLate && !a.isEarlyLeave).length;

    double totalHours = 0;
    int totalLateMinutes = 0;
    for (var a in monthAttendance) {
      totalHours += a.totalHours ?? 0;
      totalLateMinutes += a.lateMinutes;
    }

    return {
      'totalDays': totalDays,
      'lateDays': lateDays,
      'earlyLeaveDays': earlyLeaveDays,
      'onTimeDays': onTimeDays,
      'totalHours': totalHours,
      'averageHours': totalDays > 0 ? totalHours / totalDays : 0.0,
      'averageHoursPerDay': totalDays > 0 ? totalHours / totalDays : 0.0,
      'totalLateMinutes': totalLateMinutes,
    };
  }

  /// Get attendance for a specific month
  List<AttendanceModel> getAttendanceForMonth(int year, int month) {
    return _attendanceHistory.where((a) =>
        a.checkIn.year == year && a.checkIn.month == month).toList();
  }

  // ============ OFFLINE SUPPORT ============

  /// Load offline queue from local storage
  Future<void> loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_attendance_queue');
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _offlineQueue = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading offline queue: $e');
    }
  }

  /// Save offline queue to local storage
  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_attendance_queue', jsonEncode(_offlineQueue));
    } catch (e) {
      print('Error saving offline queue: $e');
    }
  }

  /// Add to offline queue
  Future<void> _addToOfflineQueue(Map<String, dynamic> data) async {
    _offlineQueue.add(data);
    await _saveOfflineQueue();
    notifyListeners();
  }

  /// Check connectivity
  Future<bool> _hasConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  /// Sync offline data when connection is restored
  Future<void> syncOfflineData() async {
    if (_isSyncing || _offlineQueue.isEmpty) return;
    
    final hasConnection = await _hasConnectivity();
    if (!hasConnection) return;

    _isSyncing = true;
    notifyListeners();

    final List<Map<String, dynamic>> failedItems = [];

    for (final item in _offlineQueue) {
      try {
        final type = item['type'];
        
        if (type == 'checkIn') {
          final attendanceData = Map<String, dynamic>.from(item['data']);
          final docRef = await _firestore.collection('attendance').add(attendanceData);
          await docRef.update({'id': docRef.id});
        } else if (type == 'checkOut') {
          final docId = item['docId'];
          final updateData = Map<String, dynamic>.from(item['data']);
          await _firestore.collection('attendance').doc(docId).update(updateData);
        }
      } catch (e) {
        print('Error syncing item: $e');
        failedItems.add(item);
      }
    }

    _offlineQueue = failedItems;
    await _saveOfflineQueue();
    _isSyncing = false;
    notifyListeners();

    if (failedItems.isEmpty && _offlineQueue.isEmpty) {
      // Refresh data after successful sync
      // Note: This requires userId which should be passed or stored
    }
  }

  // ============ FETCH METHODS ============

  /// Fetch attendance history for a user from Firebase
  Future<void> fetchAttendanceHistory(String userId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load offline queue first
      await loadOfflineQueue();

      final snapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .orderBy('checkIn', descending: true)
          .limit(100)
          .get();

      _attendanceHistory = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return AttendanceModel.fromJson(data);
      }).toList();

      // Check for today's attendance
      _updateTodayAttendance();

      _isLoading = false;
      notifyListeners();

      // Try to sync any offline data
      await syncOfflineData();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب سجل الحضور: $e';
      notifyListeners();
      print('Error fetching attendance: $e');
    }
  }

  /// Update today's attendance from history
  void _updateTodayAttendance() {
    final now = DateTime.now();
    final todayRecords = _attendanceHistory.where((a) =>
        a.checkIn.year == now.year &&
        a.checkIn.month == now.month &&
        a.checkIn.day == now.day).toList();

    // Also check yesterday for overnight shifts
    final yesterdayRecords = _attendanceHistory.where((a) {
      final yesterday = now.subtract(const Duration(days: 1));
      return a.checkIn.year == yesterday.year &&
          a.checkIn.month == yesterday.month &&
          a.checkIn.day == yesterday.day &&
          a.checkOut == null; // Still checked in from yesterday
    }).toList();

    if (todayRecords.isNotEmpty) {
      _todayAttendance = todayRecords.first;
      _currentSession = _todayAttendance;
      _isCheckedIn = _todayAttendance?.checkOut == null;
    } else if (yesterdayRecords.isNotEmpty) {
      // Overnight shift still active
      _todayAttendance = yesterdayRecords.first;
      _currentSession = _todayAttendance;
      _isCheckedIn = true;
    } else {
      _todayAttendance = null;
      _currentSession = null;
      _isCheckedIn = false;
    }
  }

  /// Check if user has checked in today
  Future<void> checkTodayAttendance(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // Check today's records
      final snapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkIn', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        data['id'] = snapshot.docs.first.id;
        _convertTimestamps(data);
        _todayAttendance = AttendanceModel.fromJson(data);
        _currentSession = _todayAttendance;
        _isCheckedIn = _todayAttendance?.checkOut == null;
      } else {
        // Check for overnight shift from yesterday
        final yesterdayStart = startOfDay.subtract(const Duration(days: 1));
        final overnightSnapshot = await _firestore
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .where('checkIn', isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart))
            .where('checkIn', isLessThan: Timestamp.fromDate(startOfDay))
            .where('checkOut', isNull: true)
            .limit(1)
            .get();

        if (overnightSnapshot.docs.isNotEmpty) {
          final data = overnightSnapshot.docs.first.data();
          data['id'] = overnightSnapshot.docs.first.id;
          _convertTimestamps(data);
          _todayAttendance = AttendanceModel.fromJson(data);
          _currentSession = _todayAttendance;
          _isCheckedIn = true;
        } else {
          _todayAttendance = null;
          _currentSession = null;
          _isCheckedIn = false;
        }
      }

      notifyListeners();
    } catch (e) {
      print('Error checking today attendance: $e');
    }
  }

  // ============ CHECK IN ============

  /// Check in with full validation
  Future<bool> checkIn({
    required String userId,
    required String userName,
    required StoreModel store,
    required ShiftModel shift,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final now = DateTime.now();

      // 1. Validate work day
      if (!shift.isWorkDay(now)) {
        _isLoading = false;
        _errorMessage = 'اليوم ليس من أيام عملك\nأيام العمل: ${shift.workDaysText}';
        notifyListeners();
        return false;
      }

      // 2. Validate time window
      final checkInResult = shift.canCheckIn(now);
      if (!checkInResult['allowed']) {
        _isLoading = false;
        _errorMessage = checkInResult['message'];
        notifyListeners();
        return false;
      }

      // 3. Get current location
      Position position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        _isLoading = false;
        _errorMessage = 'فشل في الحصول على الموقع: $e';
        notifyListeners();
        return false;
      }

      // 4. Validate distance from store
      final distance = store.getDistanceFrom(position.latitude, position.longitude);
      if (!store.isWithinRadius(position.latitude, position.longitude)) {
        _isLoading = false;
        _errorMessage = 'يجب أن تكون داخل نطاق المتجر\n'
            'النطاق المسموح: ${store.allowedRadius.toStringAsFixed(0)} متر\n'
            'المسافة الحالية: ${distance.toStringAsFixed(0)} متر';
        notifyListeners();
        return false;
      }

      // 5. Calculate expected end time (handles overnight shifts)
      final expectedEndTime = shift.endDateTimeFromCheckIn(now);

      // 6. Create attendance record
      final attendance = AttendanceModel(
        id: '',
        userId: userId,
        userName: userName,
        storeId: store.id,
        storeName: store.name,
        shiftId: shift.id,
        shiftName: shift.name,
        expectedStartTime: shift.startTime,
        expectedEndTime: shift.endTime,
        checkIn: now,
        checkInLocation: LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: store.name,
        ),
        isLate: checkInResult['isLate'] ?? false,
        lateMinutes: checkInResult['lateMinutes'] ?? 0,
      );

      // 7. Check connectivity and save
      final hasConnection = await _hasConnectivity();
      
      if (hasConnection) {
        // Save to Firebase
        final docRef = await _firestore.collection('attendance').add(attendance.toJson());
        await docRef.update({'id': docRef.id});

        final savedAttendance = attendance.copyWith(id: docRef.id);
        _todayAttendance = savedAttendance;
        _currentSession = savedAttendance;
        _isCheckedIn = true;
        _attendanceHistory.insert(0, savedAttendance);
      } else {
        // Save to offline queue
        final offlineId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
        final offlineAttendance = attendance.copyWith(id: offlineId);
        
        await _addToOfflineQueue({
          'type': 'checkIn',
          'data': offlineAttendance.toJson(),
          'timestamp': now.toIso8601String(),
        });

        _todayAttendance = offlineAttendance;
        _currentSession = offlineAttendance;
        _isCheckedIn = true;
        _attendanceHistory.insert(0, offlineAttendance);

        _errorMessage = 'تم تسجيل الحضور محلياً (بدون إنترنت)\nسيتم المزامنة عند توفر الاتصال';
      }

      // 8. Schedule sign-out reminders
      await NotificationService.scheduleSignOutReminders(
        shiftEndTime: expectedEndTime,
        employeeName: userName,
      );

      // 9. Notify if late
      if (checkInResult['isLate'] == true) {
        NotificationService.notifyLateAttendance(
          userName,
          checkInResult['lateMinutes'] ?? 0,
        );
      }

      // 10. Notify check-in success
      NotificationService.notifyCheckInSuccess(shift.name, expectedEndTime);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ أثناء تسجيل الدخول: $e';
      notifyListeners();
      print('Check in error: $e');
      return false;
    }
  }

  // ============ CHECK OUT ============

  /// Check out - handles overnight shifts correctly
  Future<bool> checkOut({ShiftModel? shift}) async {
    try {
      if (_todayAttendance == null && _currentSession == null) {
        _errorMessage = 'لم تقم بتسجيل الدخول اليوم';
        notifyListeners();
        return false;
      }

      final currentAttendance = _currentSession ?? _todayAttendance!;

      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final now = DateTime.now();

      // Get current location
      Position position;
      try {
        position = await _getCurrentLocation();
      } catch (e) {
        _isLoading = false;
        _errorMessage = 'فشل في الحصول على الموقع: $e';
        notifyListeners();
        return false;
      }

      // Calculate total hours (handles overnight correctly)
      final checkInTime = currentAttendance.checkIn;
      final totalHours = now.difference(checkInTime).inMinutes / 60.0;

      // Calculate early leave based on expected end time (handles overnight)
      bool isEarlyLeave = false;
      int earlyLeaveMinutes = 0;

      try {
        final endTimeParts = currentAttendance.expectedEndTime.split(':');
        final endHour = int.parse(endTimeParts[0]);
        final endMinute = int.parse(endTimeParts[1]);
        
        // Calculate expected end time from check-in (handles overnight)
        DateTime expectedEnd = DateTime(
          checkInTime.year,
          checkInTime.month,
          checkInTime.day,
          endHour,
          endMinute,
        );

        // If end time is before check-in time (overnight shift), add a day
        if (expectedEnd.isBefore(checkInTime)) {
          expectedEnd = expectedEnd.add(const Duration(days: 1));
        }

        if (now.isBefore(expectedEnd)) {
          isEarlyLeave = true;
          earlyLeaveMinutes = expectedEnd.difference(now).inMinutes;
        }
      } catch (e) {
        print('Error parsing end time: $e');
      }

      // Prepare update data
      final updateData = {
        'checkOut': now.toIso8601String(),
        'checkOutLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'address': currentAttendance.storeName,
        },
        'totalHours': totalHours,
        'isEarlyLeave': isEarlyLeave,
        'earlyLeaveMinutes': earlyLeaveMinutes,
      };

      // Check connectivity and save
      final hasConnection = await _hasConnectivity();

      if (hasConnection && !currentAttendance.id.startsWith('offline_')) {
        // Update in Firebase
        await _firestore.collection('attendance').doc(currentAttendance.id).update(updateData);
      } else {
        // Add to offline queue
        await _addToOfflineQueue({
          'type': 'checkOut',
          'docId': currentAttendance.id,
          'data': updateData,
          'timestamp': now.toIso8601String(),
        });

        if (!hasConnection) {
          _errorMessage = 'تم تسجيل الخروج محلياً (بدون إنترنت)\nسيتم المزامنة عند توفر الاتصال';
        }
      }

      // Update local state
      final updatedAttendance = currentAttendance.copyWith(
        checkOut: now,
        checkOutLocation: LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: currentAttendance.storeName,
        ),
        totalHours: totalHours,
        isEarlyLeave: isEarlyLeave,
        earlyLeaveMinutes: earlyLeaveMinutes,
      );
      
      _todayAttendance = updatedAttendance;
      _currentSession = updatedAttendance;
      _isCheckedIn = false;

      // Update in history list
      final index = _attendanceHistory.indexWhere((a) => a.id == currentAttendance.id);
      if (index != -1) {
        _attendanceHistory[index] = updatedAttendance;
      }

      // Cancel sign-out reminders
      await NotificationService.cancelSignOutReminders();

      // Notify check-out success
      NotificationService.notifyCheckOutSuccess(totalHours);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'حدث خطأ أثناء تسجيل الخروج: $e';
      notifyListeners();
      print('Check out error: $e');
      return false;
    }
  }

  // ============ LOCATION ============

  /// Get current GPS location
  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمة الموقع غير مفعلة');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('تم رفض إذن الموقع');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('إذن الموقع مرفوض بشكل دائم');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ============ HELPERS ============

  /// Convert Firestore Timestamps to ISO strings
  void _convertTimestamps(Map<String, dynamic> data) {
    if (data['checkIn'] is Timestamp) {
      data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
    }
    if (data['checkOut'] is Timestamp) {
      data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _attendanceHistory = [];
    _todayAttendance = null;
    _currentSession = null;
    _isCheckedIn = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Listen to attendance in real-time
  Stream<List<AttendanceModel>> attendanceStream(String userId) {
    return _firestore
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .orderBy('checkIn', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              _convertTimestamps(data);
              return AttendanceModel.fromJson(data);
            }).toList());
  }
}
