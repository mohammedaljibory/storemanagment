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

      // Get employee attendance
      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: employeeId)
          .orderBy('checkIn', descending: true)
          .limit(30)
          .get();

      _employeeAttendance = attendanceSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        _convertAttendanceTimestamps(data);
        return AttendanceModel.fromJson(data);
      }).toList();

      // Calculate stats
      final now = DateTime.now();
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

      int completedTasks = _employeeTasks.where((t) => t.status == TaskStatus.completed).length;
      int pendingTasks = _employeeTasks.where((t) =>
          t.status == TaskStatus.pending || t.status == TaskStatus.inProgress).length;
      int failedTasks = _employeeTasks.where((t) => t.status == TaskStatus.failed).length;

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
        'attendanceRate': totalDays > 0 ? (onTimeDays / totalDays * 100).round() : 0,
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

  /// Update employee in Firebase
  Future<bool> updateEmployee(UserModel employee) async {
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

  /// Delete employee
  Future<bool> deleteEmployee(String employeeId) async {
    return deactivateEmployee(employeeId);
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
