/// Request types
enum RequestType {
  timeOff,    // زمنية - partial day off
  fullDayOff, // إجازة يوم كامل - full day leave
  shiftChange, // تغيير شفت - temporary shift change
}

/// Request status
enum RequestStatus {
  pending,   // قيد الانتظار
  approved,  // موافق عليه
  rejected,  // مرفوض
  cancelled, // ملغي
}

class RequestModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String storeId;
  final String storeName;
  final RequestType type;
  final RequestStatus status;
  final DateTime requestDate;      // تاريخ تقديم الطلب
  final DateTime targetDate;       // التاريخ المطلوب (أو تاريخ البداية للإجازات المتعددة الأيام)
  final DateTime? endDate;         // تاريخ النهاية (للإجازات المتعددة الأيام)
  final int? totalDays;            // إجمالي أيام الإجازة
  final String? startTime;         // وقت البداية (للزمنية)
  final String? endTime;           // وقت النهاية (للزمنية)
  final int? durationMinutes;      // مدة الزمنية بالدقائق
  final String reason;             // سبب الطلب
  final String? adminResponse;     // رد المدير
  final String? approvedBy;        // معرف المدير الموافق
  final String? approvedByName;    // اسم المدير الموافق
  final DateTime? respondedAt;     // تاريخ الرد
  final String? newShiftId;        // للتغيير المؤقت للشفت
  final String? newShiftName;      // اسم الشفت الجديد
  final bool isActive;

  RequestModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.storeId,
    required this.storeName,
    required this.type,
    this.status = RequestStatus.pending,
    required this.requestDate,
    required this.targetDate,
    this.endDate,
    this.totalDays,
    this.startTime,
    this.endTime,
    this.durationMinutes,
    required this.reason,
    this.adminResponse,
    this.approvedBy,
    this.approvedByName,
    this.respondedAt,
    this.newShiftId,
    this.newShiftName,
    this.isActive = true,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      id: json['id'] as String,
      employeeId: json['employeeId'] as String,
      employeeName: json['employeeName'] as String? ?? '',
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String? ?? '',
      type: RequestType.values.firstWhere(
        (t) => t.toString() == 'RequestType.${json['type']}',
        orElse: () => RequestType.timeOff,
      ),
      status: RequestStatus.values.firstWhere(
        (s) => s.toString() == 'RequestStatus.${json['status']}',
        orElse: () => RequestStatus.pending,
      ),
      requestDate: DateTime.parse(json['requestDate'] as String),
      targetDate: DateTime.parse(json['targetDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      totalDays: json['totalDays'] as int?,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      durationMinutes: json['durationMinutes'] as int?,
      reason: json['reason'] as String? ?? '',
      adminResponse: json['adminResponse'] as String?,
      approvedBy: json['approvedBy'] as String?,
      approvedByName: json['approvedByName'] as String?,
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      newShiftId: json['newShiftId'] as String?,
      newShiftName: json['newShiftName'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'storeId': storeId,
      'storeName': storeName,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'requestDate': requestDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'totalDays': totalDays,
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'reason': reason,
      'adminResponse': adminResponse,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'respondedAt': respondedAt?.toIso8601String(),
      'newShiftId': newShiftId,
      'newShiftName': newShiftName,
      'isActive': isActive,
    };
  }

  RequestModel copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? storeId,
    String? storeName,
    RequestType? type,
    RequestStatus? status,
    DateTime? requestDate,
    DateTime? targetDate,
    DateTime? endDate,
    int? totalDays,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    String? reason,
    String? adminResponse,
    String? approvedBy,
    String? approvedByName,
    DateTime? respondedAt,
    String? newShiftId,
    String? newShiftName,
    bool? isActive,
  }) {
    return RequestModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      type: type ?? this.type,
      status: status ?? this.status,
      requestDate: requestDate ?? this.requestDate,
      targetDate: targetDate ?? this.targetDate,
      endDate: endDate ?? this.endDate,
      totalDays: totalDays ?? this.totalDays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      reason: reason ?? this.reason,
      adminResponse: adminResponse ?? this.adminResponse,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      respondedAt: respondedAt ?? this.respondedAt,
      newShiftId: newShiftId ?? this.newShiftId,
      newShiftName: newShiftName ?? this.newShiftName,
      isActive: isActive ?? this.isActive,
    );
  }

  // ============ HELPERS ============

  String get typeText {
    switch (type) {
      case RequestType.timeOff:
        return 'زمنية';
      case RequestType.fullDayOff:
        return 'إجازة يوم كامل';
      case RequestType.shiftChange:
        return 'تغيير شفت';
    }
  }

  String get statusText {
    switch (status) {
      case RequestStatus.pending:
        return 'قيد الانتظار';
      case RequestStatus.approved:
        return 'موافق عليه';
      case RequestStatus.rejected:
        return 'مرفوض';
      case RequestStatus.cancelled:
        return 'ملغي';
    }
  }

  String get formattedTargetDate {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${targetDate.day} ${months[targetDate.month - 1]} ${targetDate.year}';
  }

  String get formattedRequestDate {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${requestDate.day} ${months[requestDate.month - 1]} ${requestDate.year}';
  }

  String get timeRangeText {
    if (startTime != null && endTime != null) {
      return '$startTime - $endTime';
    }
    return 'يوم كامل';
  }

  String get durationText {
    if (durationMinutes == null) return 'يوم كامل';
    final hours = durationMinutes! ~/ 60;
    final mins = durationMinutes! % 60;
    if (hours > 0 && mins > 0) {
      return '$hours ساعة و $mins دقيقة';
    } else if (hours > 0) {
      return '$hours ساعة';
    } else {
      return '$mins دقيقة';
    }
  }

  bool get isPending => status == RequestStatus.pending;
  bool get isApproved => status == RequestStatus.approved;
  bool get isRejected => status == RequestStatus.rejected;

  /// Check if this is a multi-day vacation request
  bool get isMultiDay => endDate != null && totalDays != null && totalDays! > 1;

  /// Get all dates covered by this vacation request
  List<DateTime> get vacationDates {
    if (type != RequestType.fullDayOff) return [];

    final List<DateTime> dates = [];
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final end = endDate != null
        ? DateTime(endDate!.year, endDate!.month, endDate!.day)
        : start;

    for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      dates.add(d);
    }
    return dates;
  }

  /// Check if a specific date is covered by this vacation
  bool coversDate(DateTime date) {
    if (type != RequestType.fullDayOff) return false;

    final checkDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (endDate == null) {
      return checkDate == start;
    }

    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !checkDate.isBefore(start) && !checkDate.isAfter(end);
  }

  /// Get formatted date range text
  String get dateRangeText {
    if (endDate == null || !isMultiDay) {
      return formattedTargetDate;
    }

    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    final startStr = '${targetDate.day} ${months[targetDate.month - 1]}';
    final endStr = '${endDate!.day} ${months[endDate!.month - 1]} ${endDate!.year}';

    return '$startStr - $endStr ($totalDays أيام)';
  }
}
