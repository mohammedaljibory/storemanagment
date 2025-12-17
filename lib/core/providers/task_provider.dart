import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/task_model.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  // ============ GETTERS ============
  List<TaskModel> get tasks => [..._tasks];
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Filtered getters
  List<TaskModel> get pendingTasks =>
      _tasks.where((t) => t.status == TaskStatus.pending).toList();
  List<TaskModel> get inProgressTasks =>
      _tasks.where((t) => t.status == TaskStatus.inProgress).toList();
  List<TaskModel> get completedTasks =>
      _tasks.where((t) => t.status == TaskStatus.completed).toList();
  List<TaskModel> get failedTasks =>
      _tasks.where((t) => t.status == TaskStatus.failed).toList();
  List<TaskModel> get cancelledTasks =>
      _tasks.where((t) => t.status == TaskStatus.cancelled).toList();
  List<TaskModel> get overdueTasks =>
      _tasks.where((t) => t.isOverdue && t.status != TaskStatus.completed).toList();
  List<TaskModel> get activeTasks =>
      _tasks.where((t) => t.status == TaskStatus.pending || t.status == TaskStatus.inProgress).toList();
  
  // NEW: Waiting approval tasks (for admin)
  List<TaskModel> get waitingApprovalTasks =>
      _tasks.where((t) => t.status == TaskStatus.waitingApproval).toList();
  
  // NEW: Rejected tasks
  List<TaskModel> get rejectedTasks =>
      _tasks.where((t) => t.status == TaskStatus.rejected).toList();

  // Counts
  int get totalTasks => _tasks.length;
  int get pendingCount => pendingTasks.length;
  int get inProgressCount => inProgressTasks.length;
  int get completedCount => completedTasks.length;
  int get failedCount => failedTasks.length;
  int get overdueCount => overdueTasks.length;
  int get waitingApprovalCount => waitingApprovalTasks.length;

  /// Fetch all tasks from Firebase
  Future<void> fetchTasks({String? userId, bool isAdmin = false}) async {
    try {
      _isLoading = true;
      notifyListeners();

      List<TaskModel> allTasks = [];

      if (isAdmin) {
        // Admin: fetch all tasks
        final snapshot = await _firestore
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .get();

        allTasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          _convertTaskTimestamps(data);
          return TaskModel.fromJson(data);
        }).toList();
      } else if (userId != null) {
        // Employee: fetch tasks assigned to them
        // Query 1: Tasks where user is in assignedToList
        try {
          final listSnapshot = await _firestore
              .collection('tasks')
              .where('assignedToList', arrayContains: userId)
              .get();

          for (var doc in listSnapshot.docs) {
            final data = doc.data();
            data['id'] = doc.id;
            _convertTaskTimestamps(data);
            allTasks.add(TaskModel.fromJson(data));
          }
        } catch (e) {
          print('Error in assignedToList query: $e');
        }

        // Query 2: Tasks where user is primary assignee (backup)
        try {
          final primarySnapshot = await _firestore
              .collection('tasks')
              .where('assignedTo', isEqualTo: userId)
              .get();

          for (var doc in primarySnapshot.docs) {
            // Avoid duplicates
            if (!allTasks.any((t) => t.id == doc.id)) {
              final data = doc.data();
              data['id'] = doc.id;
              _convertTaskTimestamps(data);
              allTasks.add(TaskModel.fromJson(data));
            }
          }
        } catch (e) {
          print('Error in assignedTo query: $e');
        }

        // Sort by createdAt descending
        allTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      _tasks = allTasks;

      // Check for overdue tasks
      _checkOverdueTasks();

      // Check for repeating tasks that need to be created
      await _checkAndCreateRepeatingTasks();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في جلب المهام: $e';
      notifyListeners();
      print('Error fetching tasks: $e');
    }
  }

  /// Convert Firestore Timestamps to ISO strings
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
    if (data['approvedAt'] is Timestamp) {
      data['approvedAt'] = (data['approvedAt'] as Timestamp).toDate().toIso8601String();
    }
    if (data['nextRepeatDate'] is Timestamp) {
      data['nextRepeatDate'] = (data['nextRepeatDate'] as Timestamp).toDate().toIso8601String();
    }
  }

  /// Create new task in Firebase (supports multiple employees and repeat)
  Future<bool> createTask(TaskModel task) async {
    try {
      _isLoading = true;
      notifyListeners();

      // If multiple employees selected, create task for each OR create single shared task
      if (task.assignedToList.isNotEmpty) {
        // Create a single shared task with all employees
        final docRef = await _firestore.collection('tasks').add(task.toJson());
        final newTask = task.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});
        _tasks.insert(0, newTask);
      } else {
        // Single employee task
        final taskWithList = task.copyWith(
          assignedToList: [task.assignedTo],
          assignedToNamesList: [task.assignedToName],
        );
        final docRef = await _firestore.collection('tasks').add(taskWithList.toJson());
        final newTask = taskWithList.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});
        _tasks.insert(0, newTask);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إنشاء المهمة: $e';
      notifyListeners();
      print('Error creating task: $e');
      return false;
    }
  }

  /// Update task status in Firebase
  Future<bool> updateTaskStatus(String taskId, TaskStatus status) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': status.toString().split('.').last,
      });

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(status: status);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في تحديث حالة المهمة: $e';
      notifyListeners();
      print('Error updating task status: $e');
      return false;
    }
  }

  /// Employee submits task for admin approval (NEW)
  Future<bool> submitForApproval(
    String taskId, {
    required String completionImage,
    String? completionNote,
    required String completedById,
    required String completedByName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Upload image to Firebase Storage
      String imageUrl = '';
      if (completionImage.isNotEmpty) {
        imageUrl = await _uploadTaskImage(taskId, completionImage);
      }

      // Update in Firestore
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'waitingApproval',
        'completedAt': DateTime.now().toIso8601String(),
        'completionImage': imageUrl,
        'completionNote': completionNote,
        'completedBy': completedById,
        'completedByName': completedByName,
      });

      // Update local list
      final index = _tasks.indexWhere((t) => t.id == taskId);
      String taskTitle = '';
      if (index != -1) {
        taskTitle = _tasks[index].title;
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.waitingApproval,
          completedAt: DateTime.now(),
          completionImage: imageUrl,
          completionNote: completionNote,
          completedBy: completedById,
          completedByName: completedByName,
        );
      }

      // Notify admin about task waiting approval
      await _firestore.collection('notifications').add({
        'type': 'task_waiting_approval',
        'title': 'مهمة تنتظر الموافقة ⏳',
        'body': '$completedByName أنجز مهمة "$taskTitle" وتنتظر موافقتك',
        'taskId': taskId,
        'taskTitle': taskTitle,
        'employeeId': completedById,
        'employeeName': completedByName,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': true,
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إرسال المهمة للموافقة: $e';
      notifyListeners();
      print('Error submitting for approval: $e');
      return false;
    }
  }

  /// Admin approves task (NEW)
  Future<bool> approveTask(String taskId, String approvedById) async {
    try {
      final task = _tasks.firstWhere((t) => t.id == taskId);
      
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'completed',
        'approvedAt': DateTime.now().toIso8601String(),
        'approvedBy': approvedById,
      });

      // Update local list
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.completed,
          approvedAt: DateTime.now(),
          approvedBy: approvedById,
        );
      }

      // If this is a repeating task, create the next occurrence
      if (task.isRepeating && task.repeatType != TaskRepeatType.none) {
        await _createNextRepeatingTask(task);
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في الموافقة على المهمة: $e';
      notifyListeners();
      print('Error approving task: $e');
      return false;
    }
  }

  /// Admin rejects task (NEW)
  Future<bool> rejectTask(String taskId, String reason) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'rejected',
        'rejectionReason': reason,
      });

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.rejected,
          rejectionReason: reason,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في رفض المهمة: $e';
      notifyListeners();
      print('Error rejecting task: $e');
      return false;
    }
  }

  /// Legacy complete task method (for backward compatibility)
  Future<bool> completeTask(
    String taskId, {
    required String completionImage,
    String? completionNote,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      String imageUrl = '';
      if (completionImage.isNotEmpty) {
        imageUrl = await _uploadTaskImage(taskId, completionImage);
      }

      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'completed',
        'completedAt': DateTime.now().toIso8601String(),
        'completionImage': imageUrl,
        'completionNote': completionNote,
      });

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.completed,
          completedAt: DateTime.now(),
          completionImage: imageUrl,
          completionNote: completionNote,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في إكمال المهمة: $e';
      notifyListeners();
      print('Error completing task: $e');
      return false;
    }
  }

  /// Upload task image to Firebase Storage
  Future<String> _uploadTaskImage(String taskId, String localPath) async {
    try {
      final file = File(localPath);
      final fileName = '${taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('task_images').child(fileName);
      
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }

  /// Start task (change to inProgress)
  Future<bool> startTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'inProgress',
        'startedAt': DateTime.now().toIso8601String(),
      });

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.inProgress,
          startedAt: DateTime.now(),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في بدء المهمة: $e';
      notifyListeners();
      return false;
    }
  }

  /// Mark task as failed
  Future<bool> markTaskFailed(String taskId, String reason) async {
    try {
      await _firestore.collection('tasks').doc(taskId).update({
        'status': 'failed',
        'failureReason': reason,
      });

      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(
          status: TaskStatus.failed,
          failureReason: reason,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في تحديث المهمة: $e';
      notifyListeners();
      return false;
    }
  }

  /// Cancel task
  Future<bool> cancelTask(String taskId) async {
    return updateTaskStatus(taskId, TaskStatus.cancelled);
  }

  /// Check and auto-mark overdue tasks as failed
  void _checkOverdueTasks() {
    for (int i = 0; i < _tasks.length; i++) {
      if (_tasks[i].shouldMarkAsFailed) {
        _firestore.collection('tasks').doc(_tasks[i].id).update({
          'status': 'failed',
          'failureReason': 'تجاوز الموعد النهائي',
        });

        _tasks[i] = _tasks[i].copyWith(
          status: TaskStatus.failed,
          failureReason: 'تجاوز الموعد النهائي',
        );
      }
    }
  }

  /// Check and create repeating tasks (NEW)
  Future<void> _checkAndCreateRepeatingTasks() async {
    final now = DateTime.now();
    for (var task in _tasks) {
      if (task.isRepeating && 
          task.status == TaskStatus.completed &&
          task.nextRepeatDate != null &&
          task.nextRepeatDate!.isBefore(now)) {
        await _createNextRepeatingTask(task);
      }
    }
  }

  /// Create next occurrence of a repeating task (NEW)
  Future<void> _createNextRepeatingTask(TaskModel originalTask) async {
    final nextDeadline = _calculateNextDeadline(originalTask);
    if (nextDeadline == null) return;

    final newTask = TaskModel(
      id: '',
      title: originalTask.title,
      description: originalTask.description,
      storeId: originalTask.storeId,
      storeName: originalTask.storeName,
      assignedTo: originalTask.assignedTo,
      assignedToName: originalTask.assignedToName,
      assignedToList: originalTask.assignedToList,
      assignedToNamesList: originalTask.assignedToNamesList,
      assignedBy: originalTask.assignedBy,
      assignedByName: originalTask.assignedByName,
      createdAt: DateTime.now(),
      deadline: nextDeadline,
      maxDurationMinutes: originalTask.maxDurationMinutes,
      status: TaskStatus.pending,
      priority: originalTask.priority,
      repeatType: originalTask.repeatType,
      parentTaskId: originalTask.parentTaskId ?? originalTask.id,
      isRepeating: true,
      nextRepeatDate: _calculateNextRepeatDate(nextDeadline, originalTask.repeatType),
    );

    await createTask(newTask);
  }

  /// Calculate next deadline based on repeat type (NEW)
  DateTime? _calculateNextDeadline(TaskModel task) {
    final now = DateTime.now();
    switch (task.repeatType) {
      case TaskRepeatType.daily:
        return DateTime(now.year, now.month, now.day, 
            task.deadline.hour, task.deadline.minute).add(const Duration(days: 1));
      case TaskRepeatType.weekly:
        return DateTime(now.year, now.month, now.day,
            task.deadline.hour, task.deadline.minute).add(const Duration(days: 7));
      case TaskRepeatType.monthly:
        return DateTime(now.year, now.month + 1, task.deadline.day,
            task.deadline.hour, task.deadline.minute);
      case TaskRepeatType.yearly:
        return DateTime(now.year + 1, task.deadline.month, task.deadline.day,
            task.deadline.hour, task.deadline.minute);
      case TaskRepeatType.none:
        return null;
    }
  }

  /// Calculate next repeat date (NEW)
  DateTime? _calculateNextRepeatDate(DateTime deadline, TaskRepeatType repeatType) {
    switch (repeatType) {
      case TaskRepeatType.daily:
        return deadline.add(const Duration(days: 1));
      case TaskRepeatType.weekly:
        return deadline.add(const Duration(days: 7));
      case TaskRepeatType.monthly:
        return DateTime(deadline.year, deadline.month + 1, deadline.day,
            deadline.hour, deadline.minute);
      case TaskRepeatType.yearly:
        return DateTime(deadline.year + 1, deadline.month, deadline.day,
            deadline.hour, deadline.minute);
      case TaskRepeatType.none:
        return null;
    }
  }

  /// Update task (for admin editing)
  Future<bool> updateTask(TaskModel task) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Update in Firestore
      await _firestore.collection('tasks').doc(task.id).update({
        'title': task.title,
        'description': task.description,
        'storeId': task.storeId,
        'storeName': task.storeName,
        'assignedTo': task.assignedTo,
        'assignedToName': task.assignedToName,
        'assignedToList': task.assignedToList,
        'assignedToNamesList': task.assignedToNamesList,
        'deadline': task.deadline.toIso8601String(),
        'maxDurationMinutes': task.maxDurationMinutes,
        'priority': task.priority.toString().split('.').last,
        'repeatType': task.repeatType.toString().split('.').last,
        'isRepeating': task.isRepeating,
        'nextRepeatDate': task.nextRepeatDate?.toIso8601String(),
      });

      // Update local list
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل في تحديث المهمة: $e';
      notifyListeners();
      print('Error updating task: $e');
      return false;
    }
  }

  /// Delete task
  Future<bool> deleteTask(String taskId) async {
    try {
      await _firestore.collection('tasks').doc(taskId).delete();
      _tasks.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'فشل في حذف المهمة: $e';
      notifyListeners();
      return false;
    }
  }

  /// Get task by ID
  TaskModel? getTaskById(String id) {
    try {
      return _tasks.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get tasks by store
  List<TaskModel> getTasksByStore(String storeId) {
    return _tasks.where((t) => t.storeId == storeId).toList();
  }

  /// Get tasks by employee
  List<TaskModel> getTasksByEmployee(String employeeId) {
    return _tasks.where((t) => 
      t.assignedTo == employeeId || 
      t.assignedToList.contains(employeeId)
    ).toList();
  }

  /// Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Listen to tasks in real-time
  Stream<List<TaskModel>> tasksStream({String? userId, bool isAdmin = false}) {
    if (isAdmin) {
      return _firestore
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        final tasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          _convertTaskTimestamps(data);
          return TaskModel.fromJson(data);
        }).toList();

        // Update local list
        _tasks = tasks;
        return tasks;
      });
    } else if (userId != null) {
      // For employees, listen to tasks where they are assigned
      return _firestore
          .collection('tasks')
          .where('assignedToList', arrayContains: userId)
          .snapshots()
          .asyncMap((snapshot) async {
        List<TaskModel> tasks = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          _convertTaskTimestamps(data);
          return TaskModel.fromJson(data);
        }).toList();

        // Also fetch primary assigned tasks
        try {
          final primarySnapshot = await _firestore
              .collection('tasks')
              .where('assignedTo', isEqualTo: userId)
              .get();

          for (var doc in primarySnapshot.docs) {
            if (!tasks.any((t) => t.id == doc.id)) {
              final data = doc.data();
              data['id'] = doc.id;
              _convertTaskTimestamps(data);
              tasks.add(TaskModel.fromJson(data));
            }
          }
        } catch (e) {
          print('Error fetching primary tasks: $e');
        }

        // Sort by createdAt descending
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Update local list
        _tasks = tasks;
        notifyListeners();
        return tasks;
      });
    }

    return const Stream.empty();
  }

  /// Start listening to real-time updates
  void startListening({String? userId, bool isAdmin = false}) {
    tasksStream(userId: userId, isAdmin: isAdmin).listen((tasks) {
      _tasks = tasks;
      notifyListeners();
    });
  }
}
