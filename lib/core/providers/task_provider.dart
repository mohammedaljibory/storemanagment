import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<TaskModel> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isCheckingRepeatingTasks = false; // Mutex to prevent concurrent recurring task checks

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
      TaskModel createdTask;
      if (task.assignedToList.isNotEmpty) {
        // Create a single shared task with all employees
        final docRef = await _firestore.collection('tasks').add(task.toJson());
        createdTask = task.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});
        _tasks.insert(0, createdTask);
      } else {
        // Single employee task
        final taskWithList = task.copyWith(
          assignedToList: [task.assignedTo],
          assignedToNamesList: [task.assignedToName],
        );
        final docRef = await _firestore.collection('tasks').add(taskWithList.toJson());
        createdTask = taskWithList.copyWith(id: docRef.id);
        await docRef.update({'id': docRef.id});
        _tasks.insert(0, createdTask);
      }

      // Schedule recurring task notification if enabled
      if (createdTask.isRepeating &&
          createdTask.repeatTime != null &&
          createdTask.repeatNotificationEnabled) {
        await NotificationService.scheduleRecurringTaskNotification(
          taskId: createdTask.id,
          taskTitle: createdTask.title,
          repeatTime: createdTask.repeatTime!,
          repeatType: createdTask.repeatType.toString().split('.').last,
          assignedToNames: createdTask.assignedToNamesList.isNotEmpty
              ? createdTask.assignedToNamesList
              : [createdTask.assignedToName],
        );

        // Save scheduled notification info to Firestore
        await _firestore.collection('scheduled_notifications').doc(createdTask.id).set({
          'taskId': createdTask.id,
          'taskTitle': createdTask.title,
          'repeatTime': createdTask.repeatTime,
          'repeatType': createdTask.repeatType.toString().split('.').last,
          'assignedToList': createdTask.assignedToList.isNotEmpty
              ? createdTask.assignedToList
              : [createdTask.assignedTo],
          'assignedToNamesList': createdTask.assignedToNamesList.isNotEmpty
              ? createdTask.assignedToNamesList
              : [createdTask.assignedToName],
          'enabled': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

      // Save notification to Firestore for in-app notification list
      // skipPush: true because Cloud Function (onTaskUpdated) already sends push
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
        'skipPush': true, // Cloud Function onTaskUpdated handles push
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
        final task = _tasks[index];
        _tasks[index] = task.copyWith(
          status: TaskStatus.rejected,
          rejectionReason: reason,
        );

        // Save notification to Firestore for in-app notification list
        // skipPush: true because Cloud Function (onTaskUpdated) already sends push
        if (task.completedBy != null) {
          await _firestore.collection('notifications').add({
            'type': 'task_rejected',
            'title': 'تم رفض المهمة ❌',
            'body': 'تم رفض مهمة "${task.title}"\nالسبب: $reason',
            'taskId': taskId,
            'taskTitle': task.title,
            'employeeId': task.completedBy,
            'employeeName': task.completedByName,
            'reason': reason,
            'createdAt': FieldValue.serverTimestamp(),
            'read': false,
            'forAdmin': false,
            'forEmployee': true,
            'targetUserId': task.completedBy,
            'skipPush': true, // Cloud Function onTaskUpdated handles push
          });
        }
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

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: $localPath');
      }

      final fileName = '${taskId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('task_images').child(fileName);

      // Add metadata for better compatibility
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'taskId': taskId},
      );

      // Upload with metadata
      await ref.putFile(file, metadata);
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
    // Mutex: prevent concurrent checks from creating duplicates
    if (_isCheckingRepeatingTasks) return;
    _isCheckingRepeatingTasks = true;

    try {
      final now = DateTime.now();
      final tasksToProcess = <TaskModel>[];

      // Collect tasks that need processing
      for (var task in _tasks) {
        if (task.isRepeating &&
            task.status == TaskStatus.completed &&
            task.nextRepeatDate != null &&
            task.nextRepeatDate!.isBefore(now)) {
          tasksToProcess.add(task);
        }
      }

      // Process each task (one at a time to prevent race conditions)
      for (var task in tasksToProcess) {
        // Double-check from Firestore to prevent duplicates due to stale local cache
        try {
          final freshDoc = await _firestore.collection('tasks').doc(task.id).get();
          if (freshDoc.exists) {
            final freshData = freshDoc.data()!;
            final isStillRepeating = freshData['isRepeating'] as bool? ?? false;
            if (isStillRepeating) {
              await _createNextRepeatingTask(task);
            }
          }
        } catch (e) {
          print('Error checking task for repeat: $e');
        }
      }
    } finally {
      _isCheckingRepeatingTasks = false;
    }
  }

  /// Create next occurrence of a repeating task (NEW)
  Future<void> _createNextRepeatingTask(TaskModel originalTask) async {
    final nextDeadline = _calculateNextDeadline(originalTask);
    if (nextDeadline == null) return;

    final parentId = originalTask.parentTaskId ?? originalTask.id;

    // === DEDUP CHECK: Query Firestore directly (not just local cache) ===
    try {
      final existingQuery = await _firestore
          .collection('tasks')
          .where('parentTaskId', isEqualTo: parentId)
          .where('status', whereIn: ['pending', 'inProgress'])
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        print('Skipping duplicate recurring task creation - pending task already exists in Firestore');
        return;
      }
    } catch (e) {
      print('Error checking for existing recurring task: $e');
      // Fall back to local check
      final existingLocally = _tasks.any((t) =>
          t.parentTaskId == parentId &&
          t.id != originalTask.id &&
          (t.status == TaskStatus.pending || t.status == TaskStatus.inProgress));
      if (existingLocally) return;
    }

    // === VACATION CHECK: Filter out employees on vacation for the deadline date ===
    List<String> filteredAssignedToList = List.from(originalTask.assignedToList);
    List<String> filteredAssignedToNamesList = List.from(originalTask.assignedToNamesList);

    try {
      // Query approved fullDayOff requests that may cover the next deadline date
      final vacationQuery = await _firestore
          .collection('requests')
          .where('status', isEqualTo: 'approved')
          .where('type', isEqualTo: 'fullDayOff')
          .get();

      final deadlineDate = DateTime(nextDeadline.year, nextDeadline.month, nextDeadline.day);

      // Collect employee IDs who are on vacation on the deadline date
      final employeesOnVacation = <String>{};
      for (var doc in vacationQuery.docs) {
        final data = doc.data();
        final employeeId = data['employeeId'] as String?;
        if (employeeId == null) continue;

        // Check if this vacation covers the deadline date
        final targetDateStr = data['targetDate'] as String?;
        if (targetDateStr == null) continue;
        final targetDate = DateTime.parse(targetDateStr);
        final startDate = DateTime(targetDate.year, targetDate.month, targetDate.day);

        final endDateStr = data['endDate'] as String?;
        final endDate = endDateStr != null
            ? DateTime.parse(endDateStr)
            : targetDate;
        final endDateNorm = DateTime(endDate.year, endDate.month, endDate.day);

        if (!deadlineDate.isBefore(startDate) && !deadlineDate.isAfter(endDateNorm)) {
          employeesOnVacation.add(employeeId);
        }
      }

      // Filter out employees on vacation
      if (employeesOnVacation.isNotEmpty) {
        for (int i = filteredAssignedToList.length - 1; i >= 0; i--) {
          if (employeesOnVacation.contains(filteredAssignedToList[i])) {
            print('Skipping employee ${filteredAssignedToNamesList.length > i ? filteredAssignedToNamesList[i] : filteredAssignedToList[i]} - on vacation');
            filteredAssignedToList.removeAt(i);
            if (i < filteredAssignedToNamesList.length) {
              filteredAssignedToNamesList.removeAt(i);
            }
          }
        }

        // Also check the primary assignee
        if (employeesOnVacation.contains(originalTask.assignedTo) && filteredAssignedToList.isEmpty) {
          print('All assigned employees are on vacation - skipping recurring task creation');
          // Still mark the original as non-repeating and set up the chain to continue
          // by creating a "skipped" entry that will chain to the next occurrence
          await _firestore.collection('tasks').doc(originalTask.id).update({
            'isRepeating': false,
            'nextRepeatDate': null,
          });
          // Create a placeholder to keep the chain going: schedule via a future task
          // that is immediately completed/skipped
          final skipTask = TaskModel(
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
            status: TaskStatus.cancelled,
            priority: originalTask.priority,
            repeatType: originalTask.repeatType,
            parentTaskId: parentId,
            isRepeating: true,
            nextRepeatDate: _calculateNextRepeatDate(nextDeadline, originalTask.repeatType),
            repeatTime: originalTask.repeatTime,
            repeatNotificationEnabled: originalTask.repeatNotificationEnabled,
          );
          final docRef = await _firestore.collection('tasks').add(skipTask.toJson());
          await docRef.update({'id': docRef.id});
          // Update local
          final idx = _tasks.indexWhere((t) => t.id == originalTask.id);
          if (idx != -1) {
            _tasks[idx] = _tasks[idx].copyWith(isRepeating: false, nextRepeatDate: null);
          }
          return;
        }
      }
    } catch (e) {
      print('Error checking vacation status for recurring task: $e');
      // Continue without filtering on error
    }

    // Determine primary assignee (use first from filtered list)
    final primaryAssignedTo = filteredAssignedToList.isNotEmpty
        ? filteredAssignedToList.first
        : originalTask.assignedTo;
    final primaryAssignedToName = filteredAssignedToNamesList.isNotEmpty
        ? filteredAssignedToNamesList.first
        : originalTask.assignedToName;

    final newTask = TaskModel(
      id: '',
      title: originalTask.title,
      description: originalTask.description,
      storeId: originalTask.storeId,
      storeName: originalTask.storeName,
      assignedTo: primaryAssignedTo,
      assignedToName: primaryAssignedToName,
      assignedToList: filteredAssignedToList,
      assignedToNamesList: filteredAssignedToNamesList,
      assignedBy: originalTask.assignedBy,
      assignedByName: originalTask.assignedByName,
      createdAt: DateTime.now(),
      deadline: nextDeadline,
      maxDurationMinutes: originalTask.maxDurationMinutes,
      status: TaskStatus.pending,
      priority: originalTask.priority,
      repeatType: originalTask.repeatType,
      parentTaskId: parentId,
      isRepeating: true,
      nextRepeatDate: _calculateNextRepeatDate(nextDeadline, originalTask.repeatType),
      repeatTime: originalTask.repeatTime,
      repeatNotificationEnabled: originalTask.repeatNotificationEnabled,
    );

    await createTask(newTask);

    // IMPORTANT: Mark the original task as no longer repeating
    // The chain continues with the newly created task
    await _firestore.collection('tasks').doc(originalTask.id).update({
      'isRepeating': false,
      'nextRepeatDate': null,
    });

    // Update local list
    final index = _tasks.indexWhere((t) => t.id == originalTask.id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(
        isRepeating: false,
        nextRepeatDate: null,
      );
    }

    // Send notification that task has recurred (if enabled)
    if (originalTask.repeatNotificationEnabled) {
      await NotificationService.notifyRecurringTask(
        taskTitle: originalTask.title,
        repeatType: originalTask.repeatType.toString().split('.').last,
        assignedToNames: originalTask.assignedToNamesList.isNotEmpty
            ? originalTask.assignedToNamesList
            : [originalTask.assignedToName],
      );

      // Save notification to Firestore for in-app list
      await _firestore.collection('notifications').add({
        'type': 'recurring_task',
        'title': '🔄 مهمة متكررة',
        'body': 'تم تجديد المهمة "${originalTask.title}" - يرجى البدء بالتنفيذ',
        'taskId': newTask.id,
        'taskTitle': originalTask.title,
        'assignedToList': originalTask.assignedToList,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
        'forAdmin': false,
        'forEmployee': true,
      });
    }
  }

  /// Calculate next deadline based on repeat type (NEW)
  DateTime? _calculateNextDeadline(TaskModel task) {
    final now = DateTime.now();

    // Use repeatTime if available, otherwise use original deadline time
    int hour = task.deadline.hour;
    int minute = task.deadline.minute;

    if (task.repeatTime != null) {
      final parts = task.repeatTime!.split(':');
      if (parts.length == 2) {
        hour = int.tryParse(parts[0]) ?? hour;
        minute = int.tryParse(parts[1]) ?? minute;
      }
    }

    DateTime nextDeadline;
    switch (task.repeatType) {
      case TaskRepeatType.daily:
        // Next occurrence is tomorrow at the specified time
        nextDeadline = DateTime(now.year, now.month, now.day, hour, minute);
        // If the time has already passed today, schedule for tomorrow
        if (nextDeadline.isBefore(now)) {
          nextDeadline = nextDeadline.add(const Duration(days: 1));
        }
        return nextDeadline;
      case TaskRepeatType.weekly:
        nextDeadline = DateTime(now.year, now.month, now.day, hour, minute);
        // Schedule for 7 days from now
        return nextDeadline.add(const Duration(days: 7));
      case TaskRepeatType.monthly:
        // Keep the same day of month (or closest valid day)
        int targetDay = task.deadline.day;
        int nextMonth = now.month + 1;
        int nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        // Handle edge case for months with fewer days
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay, hour, minute);
      case TaskRepeatType.yearly:
        return DateTime(now.year + 1, task.deadline.month, task.deadline.day, hour, minute);
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
        int nextMonth = deadline.month + 1;
        int nextYear = deadline.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        // Handle edge case for months with fewer days
        int targetDay = deadline.day;
        int daysInMonth = DateTime(nextYear, nextMonth + 1, 0).day;
        if (targetDay > daysInMonth) {
          targetDay = daysInMonth;
        }
        return DateTime(nextYear, nextMonth, targetDay, deadline.hour, deadline.minute);
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
        'repeatTime': task.repeatTime,
        'repeatNotificationEnabled': task.repeatNotificationEnabled,
      });

      // Update local list
      final index = _tasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        _tasks[index] = task;
      }

      // Update recurring notification if changed
      if (task.isRepeating && task.repeatTime != null && task.repeatNotificationEnabled) {
        // Cancel old notification and schedule new one
        await NotificationService.cancelRecurringTaskNotification(task.id);
        await NotificationService.scheduleRecurringTaskNotification(
          taskId: task.id,
          taskTitle: task.title,
          repeatTime: task.repeatTime!,
          repeatType: task.repeatType.toString().split('.').last,
          assignedToNames: task.assignedToNamesList.isNotEmpty
              ? task.assignedToNamesList
              : [task.assignedToName],
        );

        // Update scheduled notification in Firestore
        await _firestore.collection('scheduled_notifications').doc(task.id).set({
          'taskId': task.id,
          'taskTitle': task.title,
          'repeatTime': task.repeatTime,
          'repeatType': task.repeatType.toString().split('.').last,
          'assignedToList': task.assignedToList.isNotEmpty
              ? task.assignedToList
              : [task.assignedTo],
          'assignedToNamesList': task.assignedToNamesList.isNotEmpty
              ? task.assignedToNamesList
              : [task.assignedToName],
          'enabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else if (!task.isRepeating || !task.repeatNotificationEnabled) {
        // Cancel notification if repeat is disabled
        await NotificationService.cancelRecurringTaskNotification(task.id);
        await _firestore.collection('scheduled_notifications').doc(task.id).delete();
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
