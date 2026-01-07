import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/request_model.dart';

class RequestProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<RequestModel> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ============ GETTERS ============
  List<RequestModel> get requests => [..._requests];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filtered getters
  List<RequestModel> get pendingRequests =>
      _requests.where((r) => r.status == RequestStatus.pending).toList();
  List<RequestModel> get approvedRequests =>
      _requests.where((r) => r.status == RequestStatus.approved).toList();
  List<RequestModel> get rejectedRequests =>
      _requests.where((r) => r.status == RequestStatus.rejected).toList();

  // Counts
  int get pendingCount => pendingRequests.length;
  int get approvedCount => approvedRequests.length;
  int get rejectedCount => rejectedRequests.length;

  /// Fetch requests for employee
  Future<void> fetchEmployeeRequests(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .orderBy('requestDate', descending: true)
          .get();

      _requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return RequestModel.fromJson(data);
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الطلبات: $e';
      notifyListeners();
      print('Error fetching employee requests: $e');
    }
  }

  /// Fetch all requests (for admin)
  Future<void> fetchAllRequests() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('requests')
          .orderBy('requestDate', descending: true)
          .get();

      _requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return RequestModel.fromJson(data);
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الطلبات: $e';
      notifyListeners();
      print('Error fetching all requests: $e');
    }
  }

  /// Fetch requests by store (for admin)
  Future<void> fetchRequestsByStore(String storeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('requests')
          .where('storeId', isEqualTo: storeId)
          .orderBy('requestDate', descending: true)
          .get();

      _requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return RequestModel.fromJson(data);
      }).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الطلبات: $e';
      notifyListeners();
      print('Error fetching requests by store: $e');
    }
  }

  /// Create new request
  Future<bool> createRequest(RequestModel request) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Add to Firestore
      final docRef = await _firestore.collection('requests').add(request.toJson());

      // Update with ID
      await docRef.update({'id': docRef.id});

      // Create with the new ID
      final newRequest = request.copyWith(id: docRef.id);

      // Add to local list
      _requests.insert(0, newRequest);

      // Save notification to Firestore for in-app notification list
      // skipPush: true because Cloud Function (onRequestCreated) already sends push
      await _firestore.collection('notifications').add({
        'type': 'new_request',
        'title': 'طلب جديد 📋',
        'body': '${request.employeeName} قدم طلب ${request.typeText}',
        'employeeId': request.employeeId,
        'employeeName': request.employeeName,
        'requestId': docRef.id,
        'requestType': request.type.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
        'skipPush': true, // Cloud Function onRequestCreated handles push
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إرسال الطلب: $e';
      notifyListeners();
      print('Error creating request: $e');
      return false;
    }
  }

  /// Approve request (admin)
  Future<bool> approveRequest({
    required String requestId,
    required String adminId,
    required String adminName,
    String? response,
    int? approvedDurationMinutes,
    String? approvedStartTime,
    String? approvedEndTime,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final Map<String, dynamic> updateData = {
        'status': 'approved',
        'approvedBy': adminId,
        'approvedByName': adminName,
        'respondedAt': DateTime.now().toIso8601String(),
        'adminResponse': response,
      };

      // If admin modified the time
      if (approvedDurationMinutes != null) {
        updateData['durationMinutes'] = approvedDurationMinutes;
      }
      if (approvedStartTime != null) {
        updateData['startTime'] = approvedStartTime;
      }
      if (approvedEndTime != null) {
        updateData['endTime'] = approvedEndTime;
      }

      await _firestore.collection('requests').doc(requestId).update(updateData);

      // Update local list
      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(
          status: RequestStatus.approved,
          approvedBy: adminId,
          approvedByName: adminName,
          respondedAt: DateTime.now(),
          adminResponse: response,
          durationMinutes: approvedDurationMinutes ?? _requests[index].durationMinutes,
          startTime: approvedStartTime ?? _requests[index].startTime,
          endTime: approvedEndTime ?? _requests[index].endTime,
        );

        // Save notification to Firestore for in-app notification list
        // skipPush: true because Cloud Function (onRequestUpdated) already sends push
        await _firestore.collection('notifications').add({
          'type': 'request_approved',
          'title': 'تمت الموافقة على طلبك ✅',
          'body': 'تمت الموافقة على ${_requests[index].typeText}',
          'employeeId': _requests[index].employeeId,
          'employeeName': _requests[index].employeeName,
          'requestId': requestId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'forAdmin': false,
          'forEmployee': true,
          'targetUserId': _requests[index].employeeId,
          'skipPush': true, // Cloud Function onRequestUpdated handles push
        });

        // Update vacation balance if this is a vacation request
        if (_requests[index].type == RequestType.fullDayOff) {
          final daysUsed = _requests[index].totalDays ?? 1;
          await _updateVacationBalance(_requests[index].employeeId, daysUsed);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في الموافقة على الطلب: $e';
      notifyListeners();
      print('Error approving request: $e');
      return false;
    }
  }

  /// Reject request (admin)
  Future<bool> rejectRequest({
    required String requestId,
    required String adminId,
    required String adminName,
    required String reason,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('requests').doc(requestId).update({
        'status': 'rejected',
        'approvedBy': adminId,
        'approvedByName': adminName,
        'respondedAt': DateTime.now().toIso8601String(),
        'adminResponse': reason,
      });

      // Update local list
      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(
          status: RequestStatus.rejected,
          approvedBy: adminId,
          approvedByName: adminName,
          respondedAt: DateTime.now(),
          adminResponse: reason,
        );

        // Save notification to Firestore for in-app notification list
        // skipPush: true because Cloud Function (onRequestUpdated) already sends push
        await _firestore.collection('notifications').add({
          'type': 'request_rejected',
          'title': 'تم رفض طلبك ❌',
          'body': 'تم رفض ${_requests[index].typeText}: $reason',
          'employeeId': _requests[index].employeeId,
          'employeeName': _requests[index].employeeName,
          'requestId': requestId,
          'reason': reason,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'forAdmin': false,
          'forEmployee': true,
          'targetUserId': _requests[index].employeeId,
          'skipPush': true, // Cloud Function onRequestUpdated handles push
        });
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في رفض الطلب: $e';
      notifyListeners();
      print('Error rejecting request: $e');
      return false;
    }
  }

  /// Cancel request (employee)
  Future<bool> cancelRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).update({
        'status': 'cancelled',
      });

      final index = _requests.indexWhere((r) => r.id == requestId);
      if (index != -1) {
        _requests[index] = _requests[index].copyWith(
          status: RequestStatus.cancelled,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في إلغاء الطلب: $e';
      notifyListeners();
      print('Error cancelling request: $e');
      return false;
    }
  }

  /// Delete request
  Future<bool> deleteRequest(String requestId) async {
    try {
      await _firestore.collection('requests').doc(requestId).delete();
      _requests.removeWhere((r) => r.id == requestId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في حذف الطلب: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get request by ID
  RequestModel? getRequestById(String id) {
    try {
      return _requests.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get requests for a specific date
  List<RequestModel> getRequestsForDate(DateTime date) {
    return _requests.where((r) =>
        r.targetDate.year == date.year &&
        r.targetDate.month == date.month &&
        r.targetDate.day == date.day).toList();
  }

  /// Check if employee has approved leave for a date
  bool hasApprovedLeave(String employeeId, DateTime date) {
    return _requests.any((r) =>
        r.employeeId == employeeId &&
        r.status == RequestStatus.approved &&
        r.targetDate.year == date.year &&
        r.targetDate.month == date.month &&
        r.targetDate.day == date.day &&
        r.type == RequestType.fullDayOff);
  }

  /// Get all approved day offs for an employee in a given month
  List<RequestModel> getApprovedDayOffsForMonth(String employeeId, int year, int month) {
    return _requests.where((r) =>
        r.employeeId == employeeId &&
        r.status == RequestStatus.approved &&
        r.targetDate.year == year &&
        r.targetDate.month == month &&
        r.type == RequestType.fullDayOff).toList();
  }

  /// Get all approved requests (day offs and time offs) for an employee in a given month
  List<RequestModel> getApprovedRequestsForMonth(String employeeId, int year, int month) {
    return _requests.where((r) =>
        r.employeeId == employeeId &&
        r.status == RequestStatus.approved &&
        r.targetDate.year == year &&
        r.targetDate.month == month).toList();
  }

  /// Get approved day off dates as a Set for quick lookup
  Set<DateTime> getApprovedDayOffDates(String employeeId, int year, int month) {
    return getApprovedDayOffsForMonth(employeeId, year, month)
        .map((r) => DateTime(r.targetDate.year, r.targetDate.month, r.targetDate.day))
        .toSet();
  }

  /// Check if employee has approved time-off for a specific time
  RequestModel? getApprovedTimeOff(String employeeId, DateTime dateTime) {
    try {
      return _requests.firstWhere((r) =>
          r.employeeId == employeeId &&
          r.status == RequestStatus.approved &&
          r.targetDate.year == dateTime.year &&
          r.targetDate.month == dateTime.month &&
          r.targetDate.day == dateTime.day &&
          r.type == RequestType.timeOff);
    } catch (e) {
      return null;
    }
  }

  /// Check if employee has approved vacation for a specific date (supports multi-day)
  RequestModel? getApprovedVacationForDate(String employeeId, DateTime date) {
    try {
      return _requests.firstWhere((r) =>
          r.employeeId == employeeId &&
          r.status == RequestStatus.approved &&
          r.type == RequestType.fullDayOff &&
          r.coversDate(date));
    } catch (e) {
      return null;
    }
  }

  /// Check if today is a vacation day for the employee
  bool isOnVacationToday(String employeeId) {
    final today = DateTime.now();
    return getApprovedVacationForDate(employeeId, today) != null;
  }

  /// Get all approved vacations for an employee
  List<RequestModel> getApprovedVacations(String employeeId) {
    return _requests.where((r) =>
        r.employeeId == employeeId &&
        r.status == RequestStatus.approved &&
        r.type == RequestType.fullDayOff).toList();
  }

  /// Get upcoming approved vacations for an employee
  List<RequestModel> getUpcomingVacations(String employeeId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _requests.where((r) =>
        r.employeeId == employeeId &&
        r.status == RequestStatus.approved &&
        r.type == RequestType.fullDayOff &&
        (r.endDate ?? r.targetDate).isAfter(today.subtract(const Duration(days: 1)))).toList();
  }

  /// Update employee vacation balance after approval
  Future<void> _updateVacationBalance(String employeeId, int daysUsed) async {
    try {
      final userDoc = await _firestore.collection('users').doc(employeeId).get();
      if (!userDoc.exists) return;

      final currentYear = DateTime.now().year;
      final data = userDoc.data()!;
      final storedYear = data['vacationYear'] as int? ?? currentYear;
      int currentUsed = data['usedVacationDays'] as int? ?? 0;

      // Reset if year changed
      if (storedYear != currentYear) {
        currentUsed = 0;
      }

      await _firestore.collection('users').doc(employeeId).update({
        'usedVacationDays': currentUsed + daysUsed,
        'vacationYear': currentYear,
      });
    } catch (e) {
      print('Error updating vacation balance: $e');
    }
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Convert Firestore Timestamps to ISO strings
  void _convertTimestamps(Map<String, dynamic> data) {
    if (data['requestDate'] is Timestamp) {
      data['requestDate'] = (data['requestDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['targetDate'] is Timestamp) {
      data['targetDate'] = (data['targetDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['respondedAt'] is Timestamp) {
      data['respondedAt'] = (data['respondedAt'] as Timestamp).toDate().toIso8601String();
    }
  }

  /// Stream of pending requests (for admin real-time updates)
  Stream<List<RequestModel>> pendingRequestsStream() {
    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              _convertTimestamps(data);
              return RequestModel.fromJson(data);
            }).toList());
  }

  /// Stream of all requests (for admin real-time updates)
  Stream<List<RequestModel>> allRequestsStream() {
    return _firestore
        .collection('requests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return RequestModel.fromJson(data);
      }).toList();

      // Update local list
      _requests = requests;
      notifyListeners();
      return requests;
    });
  }

  /// Stream of employee requests (for employee real-time updates)
  Stream<List<RequestModel>> employeeRequestsStream(String employeeId) {
    return _firestore
        .collection('requests')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return RequestModel.fromJson(data);
      }).toList();

      // Update local list
      _requests = requests;
      notifyListeners();
      return requests;
    });
  }

  /// Get all employees on vacation today
  List<RequestModel> getEmployeesOnVacationToday() {
    final today = DateTime.now();
    return _requests.where((r) =>
        r.status == RequestStatus.approved &&
        r.type == RequestType.fullDayOff &&
        r.coversDate(today)).toList();
  }

  /// Get count of employees on vacation today
  int get employeesOnVacationTodayCount => getEmployeesOnVacationToday().length;

  /// Stream of approved vacations that cover today
  Stream<List<RequestModel>> vacationsTodayStream() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    return _firestore
        .collection('requests')
        .where('status', isEqualTo: 'approved')
        .where('type', isEqualTo: 'fullDayOff')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            _convertTimestamps(data);
            return RequestModel.fromJson(data);
          })
          .where((r) => r.coversDate(today))
          .toList();
    });
  }
}
