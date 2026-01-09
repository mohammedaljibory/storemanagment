import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/attendance_model.dart';

class EmployeeProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<UserModel> _employees = [];
  UserModel? _selectedEmployee;
  bool _isLoading = false;
  String? _errorMessage;

  // Employee dashboard data
  Map<String, dynamic> _employeeStats = {};
  List<TaskModel> _employeeTasks = [];
  List<AttendanceModel> _employeeAttendance = [];

  // ============ GETTERS ============
  List<UserModel> get employees => [..._employees];
  List<UserModel> get activeEmployees => _employees.where((e) => e.isActive).toList();
  UserModel? get selectedEmployee => _selectedEmployee;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get employeeCount => _employees.length;
  int get activeEmployeeCount => activeEmployees.length;

  // Employee dashboard getters
  Map<String, dynamic> get employeeStats => _employeeStats;
  List<TaskModel> get employeeTasks => _employeeTasks;
  List<AttendanceModel> get employeeAttendance => _employeeAttendance;

  /// Fetch all employees from Firebase
  Future<void> fetchEmployees() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      _employees = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return UserModel.fromJson(data);
      }).where((e) => e.isActive).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الموظفين: $e';
      notifyListeners();
      print('Error fetching employees: $e');
    }
  }

  Future<void> fetchEmployeesByStore(String storeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .where('storeId', isEqualTo: storeId)
          .get();

      _employees = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTimestamps(data);
        return UserModel.fromJson(data);
      }).where((e) => e.isActive).toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب الموظفين: $e';
      notifyListeners();
      print('Error fetching employees by store: $e');
    }
  }

  /// Fetch employee dashboard data (stats, tasks, attendance)
  Future<void> fetchEmployeeDashboard(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Get employee tasks
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignedTo', isEqualTo: employeeId)
          .get();

      _employeeTasks = tasksSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertTaskTimestamps(data);
        return TaskModel.fromJson(data);
      }).toList();

      // Get employee attendance - fetch all records for accurate stats
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);

      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: employeeId)
          .orderBy('checkIn', descending: true)
          .get();

      _employeeAttendance = attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertAttendanceTimestamps(data);
        return AttendanceModel.fromJson(data);
      }).toList();

      // Get employee vacation requests for current month
      final vacationSnapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .where('status', isEqualTo: 'approved')
          .get();

      int vacationDays = 0;
      for (var doc in vacationSnapshot.docs) {
        final data = doc.data();
        if (data['type'] == 'fullDayOff') {
          final targetDate = (data['targetDate'] as Timestamp?)?.toDate();
          if (targetDate != null &&
              targetDate.year == now.year &&
              targetDate.month == now.month) {
            // Check for multi-day vacation
            final totalDaysVacation = data['totalDays'] as int? ?? 1;
            vacationDays += totalDaysVacation;
          }
        }
      }

      // Calculate stats for current month
      final thisMonthAttendance = _employeeAttendance.where((a) =>
          a.checkIn.year == now.year && a.checkIn.month == now.month).toList();

      int totalDays = thisMonthAttendance.length;
      int lateDays = thisMonthAttendance.where((a) => a.isLate).length;
      int earlyLeaveDays = thisMonthAttendance.where((a) => a.isEarlyLeave).length;
      int onTimeDays = thisMonthAttendance.where((a) => !a.isLate && !a.isEarlyLeave).length;

      double totalHours = 0;
      for (var a in thisMonthAttendance) {
        totalHours += a.totalHours ?? 0;
      }

      // Calculate total penalty minutes
      int totalPenaltyMinutes = 0;
      int totalLateMinutes = 0;
      int totalEarlyLeaveMinutes = 0;
      for (var a in thisMonthAttendance) {
        totalPenaltyMinutes += a.penaltyMinutes;
        totalLateMinutes += a.lateMinutes;
        totalEarlyLeaveMinutes += a.earlyLeaveMinutes;
      }

      int completedTasks = _employeeTasks.where((t) => t.status == TaskStatus.completed).length;
      int pendingTasks = _employeeTasks.where((t) =>
          t.status == TaskStatus.pending || t.status == TaskStatus.inProgress).length;
      int failedTasks = _employeeTasks.where((t) => t.status == TaskStatus.failed).length;

      // Calculate compliance rate (on-time percentage)
      double complianceRate = totalDays > 0 ? (onTimeDays / totalDays * 100) : 0;

      // Calculate task completion rate
      double taskCompletionRate = _employeeTasks.isNotEmpty
          ? (completedTasks / _employeeTasks.length * 100)
          : 0;

      _employeeStats = {
        'totalDays': totalDays,
        'lateDays': lateDays,
        'earlyLeaveDays': earlyLeaveDays,
        'onTimeDays': onTimeDays,
        'totalHours': totalHours,
        'averageHours': totalDays > 0 ? totalHours / totalDays : 0,
        'completedTasks': completedTasks,
        'pendingTasks': pendingTasks,
        'failedTasks': failedTasks,
        'totalTasks': _employeeTasks.length,
        'complianceRate': complianceRate,
        'taskCompletionRate': taskCompletionRate,
        'vacationDays': vacationDays,
        'totalPenaltyMinutes': totalPenaltyMinutes,
        'totalLateMinutes': totalLateMinutes,
        'totalEarlyLeaveMinutes': totalEarlyLeaveMinutes,
        'totalWorkDays': totalDays, // For backward compatibility
        'attendanceRate': complianceRate.round(), // For backward compatibility
      };

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب بيانات الموظف: $e';
      notifyListeners();
      print('Error fetching employee dashboard: $e');
    }
  }

  /// Get employees by store
  List<UserModel> getEmployeesByStore(String storeId) {
    return _employees.where((e) => e.storeId == storeId).toList();
  }

  /// Get employees by shift
  List<UserModel> getEmployeesByShift(String shiftId) {
    return _employees.where((e) => e.shiftId == shiftId).toList();
  }

  /// Get employees by store and shift
  List<UserModel> getEmployeesByStoreAndShift(String? storeId, String? shiftId) {
    var filtered = _employees.toList();
    
    if (storeId != null && storeId.isNotEmpty) {
      filtered = filtered.where((e) => e.storeId == storeId).toList();
    }
    
    if (shiftId != null && shiftId.isNotEmpty) {
      filtered = filtered.where((e) => e.shiftId == shiftId).toList();
    }
    
    return filtered;
  }

  /// Create new employee in Firebase
  Future<bool> createEmployee(UserModel employee) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Add to Firestore
      final docRef = await _firestore.collection('users').add(employee.toJson());
      
      // Create employee with the new ID
      final newEmployee = employee.copyWith(id: docRef.id);
      
      // Update Firestore with the ID
      await docRef.update({'id': docRef.id});
      
      // Add to local list
      _employees.insert(0, newEmployee);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إنشاء الموظف: $e';
      notifyListeners();
      print('Error creating employee: $e');
      return false;
    }
  }

  /// Update employee in Firebase (with UserModel)
  Future<bool> updateEmployeeModel(UserModel employee) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update in Firestore
      await _firestore.collection('users').doc(employee.id).update(employee.toJson());

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employee.id);
      if (index != -1) {
        _employees[index] = employee;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث الموظف: $e';
      notifyListeners();
      print('Error updating employee: $e');
      return false;
    }
  }

  /// Update employee with individual parameters
  Future<bool> updateEmployee({
    required String employeeId,
    String? name,
    String? phone,
    String? storeId,
    String? storeName,
    String? shiftId,
    String? shiftName,
    int? daysOffPerMonth,
    int? allowedVacationDays,
    EmployeeType? employeeType,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Find current employee
      final currentEmployee = _employees.firstWhere(
        (e) => e.id == employeeId,
        orElse: () => throw Exception('Employee not found'),
      );

      // Build update map
      final Map<String, dynamic> updateData = {};

      if (name != null) updateData['name'] = name;
      if (phone != null) updateData['phone'] = phone;

      // Handle employee type change
      if (employeeType != null) {
        updateData['employeeType'] = employeeType == EmployeeType.free ? 'free' : 'regular';

        if (employeeType == EmployeeType.free) {
          // Clear store/shift for free employees
          updateData['storeId'] = null;
          updateData['storeName'] = null;
          updateData['shiftId'] = null;
          updateData['shiftName'] = null;
        } else {
          // Set store/shift for regular employees
          updateData['storeId'] = storeId;
          updateData['storeName'] = storeName;
          updateData['shiftId'] = shiftId;
          updateData['shiftName'] = shiftName;
        }
      } else {
        // Only update store/shift if provided
        if (storeId != null) updateData['storeId'] = storeId;
        if (storeName != null) updateData['storeName'] = storeName;
        if (shiftId != null) updateData['shiftId'] = shiftId;
        if (shiftName != null) updateData['shiftName'] = shiftName;
      }

      if (daysOffPerMonth != null) updateData['daysOffPerMonth'] = daysOffPerMonth;
      if (allowedVacationDays != null) updateData['allowedVacationDays'] = allowedVacationDays;

      // Update in Firestore
      await _firestore.collection('users').doc(employeeId).update(updateData);

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = currentEmployee.copyWith(
          name: name ?? currentEmployee.name,
          phone: phone ?? currentEmployee.phone,
          storeId: employeeType == EmployeeType.free ? null : (storeId ?? currentEmployee.storeId),
          storeName: employeeType == EmployeeType.free ? null : (storeName ?? currentEmployee.storeName),
          shiftId: employeeType == EmployeeType.free ? null : (shiftId ?? currentEmployee.shiftId),
          shiftName: employeeType == EmployeeType.free ? null : (shiftName ?? currentEmployee.shiftName),
          daysOffPerMonth: daysOffPerMonth ?? currentEmployee.daysOffPerMonth,
          allowedVacationDays: allowedVacationDays ?? currentEmployee.allowedVacationDays,
          employeeType: employeeType ?? currentEmployee.employeeType,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث الموظف: $e';
      notifyListeners();
      print('Error updating employee: $e');
      return false;
    }
  }

  // ============ TEMPORARY SHIFT ASSIGNMENT ============

  /// Assign temporary shift to employee
  Future<bool> assignTemporaryShift({
    required String employeeId,
    required String shiftId,
    required String shiftName,
    required DateTime date,
    DateTime? expiry,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updateData = {
        'temporaryShiftId': shiftId,
        'temporaryShiftName': shiftName,
        'temporaryShiftDate': date.toIso8601String(),
        'temporaryShiftExpiry': expiry?.toIso8601String(),
      };

      // Update in Firestore
      await _firestore.collection('users').doc(employeeId).update(updateData);

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = _employees[index].copyWith(
          temporaryShiftId: shiftId,
          temporaryShiftName: shiftName,
          temporaryShiftDate: date,
          temporaryShiftExpiry: expiry,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تعيين الشفت المؤقت: $e';
      notifyListeners();
      print('Error assigning temporary shift: $e');
      return false;
    }
  }

  /// Clear temporary shift for employee
  Future<bool> clearTemporaryShift(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final updateData = {
        'temporaryShiftId': null,
        'temporaryShiftName': null,
        'temporaryShiftDate': null,
        'temporaryShiftExpiry': null,
      };

      // Update in Firestore
      await _firestore.collection('users').doc(employeeId).update(updateData);

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = _employees[index].clearTemporaryShift();
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إلغاء الشفت المؤقت: $e';
      notifyListeners();
      print('Error clearing temporary shift: $e');
      return false;
    }
  }

  /// Get employees with temporary shift for a date
  List<UserModel> getEmployeesWithTemporaryShiftForDate(DateTime date) {
    return _employees.where((e) => e.hasTemporaryShiftForDate(date)).toList();
  }

  /// Bulk assign temporary shift to multiple employees
  Future<bool> bulkAssignTemporaryShift({
    required List<String> employeeIds,
    required String shiftId,
    required String shiftName,
    required DateTime date,
    DateTime? expiry,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final batch = _firestore.batch();

      for (final employeeId in employeeIds) {
        final ref = _firestore.collection('users').doc(employeeId);
        batch.update(ref, {
          'temporaryShiftId': shiftId,
          'temporaryShiftName': shiftName,
          'temporaryShiftDate': date.toIso8601String(),
          'temporaryShiftExpiry': expiry?.toIso8601String(),
        });
      }

      await batch.commit();

      // Update local list
      for (final employeeId in employeeIds) {
        final index = _employees.indexWhere((e) => e.id == employeeId);
        if (index != -1) {
          _employees[index] = _employees[index].copyWith(
            temporaryShiftId: shiftId,
            temporaryShiftName: shiftName,
            temporaryShiftDate: date,
            temporaryShiftExpiry: expiry,
          );
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تعيين الشفت المؤقت: $e';
      notifyListeners();
      print('Error bulk assigning temporary shift: $e');
      return false;
    }
  }

  // ============ AUTHORIZED STORES MANAGEMENT ============

  /// Update authorized stores for an employee
  Future<bool> updateAuthorizedStores({
    required String employeeId,
    required List<String> authorizedStoreIds,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update in Firestore
      await _firestore.collection('users').doc(employeeId).update({
        'authorizedStoreIds': authorizedStoreIds,
      });

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = _employees[index].copyWith(
          authorizedStoreIds: authorizedStoreIds,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث المتاجر المصرح بها: $e';
      notifyListeners();
      print('Error updating authorized stores: $e');
      return false;
    }
  }

  /// Add store to employee's authorized list
  Future<bool> addAuthorizedStore({
    required String employeeId,
    required String storeId,
  }) async {
    final employee = getEmployeeById(employeeId);
    if (employee == null) return false;

    final newList = [...employee.authorizedStoreIds];
    if (!newList.contains(storeId)) {
      newList.add(storeId);
    }
    return updateAuthorizedStores(
      employeeId: employeeId,
      authorizedStoreIds: newList,
    );
  }

  /// Remove store from employee's authorized list
  Future<bool> removeAuthorizedStore({
    required String employeeId,
    required String storeId,
  }) async {
    final employee = getEmployeeById(employeeId);
    if (employee == null) return false;

    final newList = employee.authorizedStoreIds.where((id) => id != storeId).toList();
    return updateAuthorizedStores(
      employeeId: employeeId,
      authorizedStoreIds: newList,
    );
  }

  // ============ OTHER METHODS ============

  /// Deactivate employee (soft delete) in Firebase
  Future<bool> deactivateEmployee(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Soft delete in Firestore
      await _firestore.collection('users').doc(employeeId).update({
        'isActive': false,
      });

      // Update local list
      final index = _employees.indexWhere((e) => e.id == employeeId);
      if (index != -1) {
        _employees[index] = _employees[index].copyWith(isActive: false);
        _employees.removeAt(index);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في حذف الموظف: $e';
      notifyListeners();
      print('Error deactivating employee: $e');
      return false;
    }
  }

  /// Delete employee (soft delete - just deactivates)
  Future<bool> deleteEmployee(String employeeId) async {
    return deactivateEmployee(employeeId);
  }

  /// Permanently delete employee and all related data
  /// WARNING: This is irreversible!
  Future<bool> permanentlyDeleteEmployee(String employeeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final batch = _firestore.batch();

      // 1. Delete user document
      final userRef = _firestore.collection('users').doc(employeeId);
      batch.delete(userRef);

      // 2. Delete all attendance records
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: employeeId)
          .get();
      for (final doc in attendanceSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete all tasks assigned to this employee
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('assignedTo', isEqualTo: employeeId)
          .get();
      for (final doc in tasksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 4. Delete all requests from this employee
      final requestsSnapshot = await _firestore
          .collection('requests')
          .where('employeeId', isEqualTo: employeeId)
          .get();
      for (final doc in requestsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 5. Delete all notifications for this employee
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: employeeId)
          .get();
      for (final doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Commit all deletions
      await batch.commit();

      // Remove from local list
      _employees.removeWhere((e) => e.id == employeeId);

      _isLoading = false;
      notifyListeners();

      print('Permanently deleted employee: $employeeId');
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في حذف الموظف نهائياً: $e';
      notifyListeners();
      print('Error permanently deleting employee: $e');
      return false;
    }
  }

  /// Get employee by ID
  UserModel? getEmployeeById(String id) {
    try {
      return _employees.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Fetch single employee by ID
  Future<UserModel?> fetchEmployeeById(String employeeId) async {
    try {
      final doc = await _firestore.collection('users').doc(employeeId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        _convertTimestamps(data);
        return UserModel.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching employee by ID: $e');
      return null;
    }
  }

  /// Select an employee
  void selectEmployee(UserModel? employee) {
    _selectedEmployee = employee;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============ TIMESTAMP CONVERSION ============

  void _convertTimestamps(Map<String, dynamic> data) {
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['temporaryShiftDate'] is Timestamp) {
      data['temporaryShiftDate'] = (data['temporaryShiftDate'] as Timestamp).toDate().toIso8601String();
    }
    if (data['temporaryShiftExpiry'] is Timestamp) {
      data['temporaryShiftExpiry'] = (data['temporaryShiftExpiry'] as Timestamp).toDate().toIso8601String();
    }
  }

  void _convertTaskTimestamps(Map<String, dynamic> data) {
    if (data['createdAt'] is Timestamp) {
      data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['deadline'] is Timestamp) {
      data['deadline'] = (data['deadline'] as Timestamp).toDate().toIso8601String();
    }
    if (data['startedAt'] is Timestamp) {
      data['startedAt'] = (data['startedAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['completedAt'] is Timestamp) {
      data['completedAt'] = (data['completedAt'] as Timestamp).toDate().toIso8601String();
    }
  }

  void _convertAttendanceTimestamps(Map<String, dynamic> data) {
    if (data['checkIn'] is Timestamp) {
      data['checkIn'] = (data['checkIn'] as Timestamp).toDate().toIso8601String();
    }
    if (data['checkOut'] is Timestamp) {
      data['checkOut'] = (data['checkOut'] as Timestamp).toDate().toIso8601String();
    }
  }
}
