// Task Status with new approval states
enum TaskStatus { 
  pending, 
  inProgress, 
  waitingApproval,  // NEW: Employee submitted, waiting admin approval
  completed, 
  failed, 
  cancelled,
  rejected  // NEW: Admin rejected the task
}

enum TaskPriority { low, medium, high, urgent }

// NEW: Repeat types for recurring tasks
enum TaskRepeatType { none, daily, weekly, monthly, yearly }

class TaskModel {
  final String id;
  final String title;
  final String description;
  final String storeId;
  final String storeName;
  final String assignedTo;  // Primary assignee (for single) or first employee
  final String assignedToName;
  final List<String> assignedToList;  // NEW: Multiple employees
  final List<String> assignedToNamesList;  // NEW: Multiple employee names
  final String assignedBy;
  final String assignedByName;
  final DateTime createdAt;
  final DateTime deadline;
  final int maxDurationMinutes;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionImage;
  final String? completionNote;
  final String? failureReason;
  
  // NEW: Approval system fields
  final String? rejectionReason;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? completedBy;  // Which employee completed it
  final String? completedByName;
  
  // NEW: Repeat task fields
  final TaskRepeatType repeatType;
  final String? parentTaskId;  // For repeated tasks, reference to original
  final bool isRepeating;
  final DateTime? nextRepeatDate;

  TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.storeId,
    required this.storeName,
    required this.assignedTo,
    required this.assignedToName,
    this.assignedToList = const [],
    this.assignedToNamesList = const [],
    required this.assignedBy,
    required this.assignedByName,
    required this.createdAt,
    required this.deadline,
    required this.maxDurationMinutes,
    required this.status,
    required this.priority,
    this.startedAt,
    this.completedAt,
    this.completionImage,
    this.completionNote,
    this.failureReason,
    this.rejectionReason,
    this.approvedAt,
    this.approvedBy,
    this.completedBy,
    this.completedByName,
    this.repeatType = TaskRepeatType.none,
    this.parentTaskId,
    this.isRepeating = false,
    this.nextRepeatDate,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String? ?? '',
      assignedTo: json['assignedTo'] as String,
      assignedToName: json['assignedToName'] as String? ?? '',
      assignedToList: (json['assignedToList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      assignedToNamesList: (json['assignedToNamesList'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      assignedBy: json['assignedBy'] as String,
      assignedByName: json['assignedByName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      deadline: DateTime.parse(json['deadline'] as String),
      maxDurationMinutes: json['maxDurationMinutes'] as int? ?? 60,
      status: TaskStatus.values.firstWhere(
        (s) => s.toString() == 'TaskStatus.${json['status']}',
        orElse: () => TaskStatus.pending,
      ),
      priority: TaskPriority.values.firstWhere(
        (p) => p.toString() == 'TaskPriority.${json['priority']}',
        orElse: () => TaskPriority.medium,
      ),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      completionImage: json['completionImage'] as String?,
      completionNote: json['completionNote'] as String?,
      failureReason: json['failureReason'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      approvedBy: json['approvedBy'] as String?,
      completedBy: json['completedBy'] as String?,
      completedByName: json['completedByName'] as String?,
      repeatType: TaskRepeatType.values.firstWhere(
        (r) => r.toString() == 'TaskRepeatType.${json['repeatType']}',
        orElse: () => TaskRepeatType.none,
      ),
      parentTaskId: json['parentTaskId'] as String?,
      isRepeating: json['isRepeating'] as bool? ?? false,
      nextRepeatDate: json['nextRepeatDate'] != null
          ? DateTime.parse(json['nextRepeatDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'storeId': storeId,
      'storeName': storeName,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'assignedToList': assignedToList,
      'assignedToNamesList': assignedToNamesList,
      'assignedBy': assignedBy,
      'assignedByName': assignedByName,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline.toIso8601String(),
      'maxDurationMinutes': maxDurationMinutes,
      'status': status.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'completionImage': completionImage,
      'completionNote': completionNote,
      'failureReason': failureReason,
      'rejectionReason': rejectionReason,
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'completedBy': completedBy,
      'completedByName': completedByName,
      'repeatType': repeatType.toString().split('.').last,
      'parentTaskId': parentTaskId,
      'isRepeating': isRepeating,
      'nextRepeatDate': nextRepeatDate?.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    String? storeId,
    String? storeName,
    String? assignedTo,
    String? assignedToName,
    List<String>? assignedToList,
    List<String>? assignedToNamesList,
    String? assignedBy,
    String? assignedByName,
    DateTime? createdAt,
    DateTime? deadline,
    int? maxDurationMinutes,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completionImage,
    String? completionNote,
    String? failureReason,
    String? rejectionReason,
    DateTime? approvedAt,
    String? approvedBy,
    String? completedBy,
    String? completedByName,
    TaskRepeatType? repeatType,
    String? parentTaskId,
    bool? isRepeating,
    DateTime? nextRepeatDate,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      assignedToList: assignedToList ?? this.assignedToList,
      assignedToNamesList: assignedToNamesList ?? this.assignedToNamesList,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedByName: assignedByName ?? this.assignedByName,
      createdAt: createdAt ?? this.createdAt,
      deadline: deadline ?? this.deadline,
      maxDurationMinutes: maxDurationMinutes ?? this.maxDurationMinutes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completionImage: completionImage ?? this.completionImage,
      completionNote: completionNote ?? this.completionNote,
      failureReason: failureReason ?? this.failureReason,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      completedBy: completedBy ?? this.completedBy,
      completedByName: completedByName ?? this.completedByName,
      repeatType: repeatType ?? this.repeatType,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      isRepeating: isRepeating ?? this.isRepeating,
      nextRepeatDate: nextRepeatDate ?? this.nextRepeatDate,
    );
  }

  // Status helpers
  String get statusText {
    switch (status) {
      case TaskStatus.pending:
        return 'في الانتظار';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.waitingApproval:
        return 'بانتظار الموافقة';
      case TaskStatus.completed:
        return 'مكتملة';
      case TaskStatus.failed:
        return 'فشلت';
      case TaskStatus.cancelled:
        return 'ملغية';
      case TaskStatus.rejected:
        return 'مرفوضة';
    }
  }

  String get priorityText {
    switch (priority) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.urgent:
        return 'عاجلة';
    }
  }

  String get repeatTypeText {
    switch (repeatType) {
      case TaskRepeatType.none:
        return 'لا يتكرر';
      case TaskRepeatType.daily:
        return 'يومياً';
      case TaskRepeatType.weekly:
        return 'أسبوعياً';
      case TaskRepeatType.monthly:
        return 'شهرياً';
      case TaskRepeatType.yearly:
        return 'سنوياً';
    }
  }

  // Check if task is for multiple employees
  bool get isMultiEmployee => assignedToList.length > 1;

  // Check if task is overdue
  bool get isOverdue {
    return status != TaskStatus.completed &&
        status != TaskStatus.cancelled &&
        status != TaskStatus.waitingApproval &&
        DateTime.now().isAfter(deadline);
  }

  // Check if task should be marked as failed
  bool get shouldMarkAsFailed {
    return isOverdue && status != TaskStatus.failed;
  }

  // Time remaining
  Duration get timeRemaining {
    return deadline.difference(DateTime.now());
  }

  String get timeRemainingText {
    if (isOverdue) {
      final overdue = DateTime.now().difference(deadline);
      if (overdue.inDays > 0) {
        return 'متأخر ${overdue.inDays} يوم';
      } else if (overdue.inHours > 0) {
        return 'متأخر ${overdue.inHours} ساعة';
      } else {
        return 'متأخر ${overdue.inMinutes} دقيقة';
      }
    }

    final remaining = timeRemaining;
    if (remaining.inDays > 0) {
      return 'متبقي ${remaining.inDays} يوم';
    } else if (remaining.inHours > 0) {
      return 'متبقي ${remaining.inHours} ساعة';
    } else {
      return 'متبقي ${remaining.inMinutes} دقيقة';
    }
  }

  String get maxDurationText {
    if (maxDurationMinutes < 60) {
      return '$maxDurationMinutes دقيقة';
    } else {
      final hours = maxDurationMinutes ~/ 60;
      final mins = maxDurationMinutes % 60;
      if (mins == 0) {
        return '$hours ساعة';
      }
      return '$hours ساعة و $mins دقيقة';
    }
  }

  // Get all assigned employee names as comma-separated string
  String get allAssignedNames {
    if (assignedToNamesList.isEmpty) {
      return assignedToName;
    }
    return assignedToNamesList.join('، ');
  }
}
