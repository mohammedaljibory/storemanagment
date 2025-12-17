class ShiftModel {
  final String id;
  final String storeId;
  final String name;
  final String startTime; // "08:00" or "16:00"
  final String endTime; // "14:00" or "01:00" (next day)
  final List<int> workDays; // 0=Sunday, 1=Monday, ... 6=Saturday
  final int lateToleranceMinutes; // allowed late minutes before marked late
  final int checkInWindowMinutes; // can check in X minutes before/after start
  final int checkOutWindowMinutes; // can't check out before X minutes from end
  final int maxLateMinutes; // maximum late minutes allowed (after this, can't check in)
  final DateTime createdAt;
  final bool isActive;

  ShiftModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.workDays,
    this.lateToleranceMinutes = 15,
    this.checkInWindowMinutes = 30,
    this.checkOutWindowMinutes = 15,
    this.maxLateMinutes = 60,
    required this.createdAt,
    this.isActive = true,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      workDays: List<int>.from(json['workDays'] as List),
      lateToleranceMinutes: json['lateToleranceMinutes'] as int? ?? 15,
      checkInWindowMinutes: json['checkInWindowMinutes'] as int? ?? 30,
      checkOutWindowMinutes: json['checkOutWindowMinutes'] as int? ?? 15,
      maxLateMinutes: json['maxLateMinutes'] as int? ?? 60,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'startTime': startTime,
      'endTime': endTime,
      'workDays': workDays,
      'lateToleranceMinutes': lateToleranceMinutes,
      'checkInWindowMinutes': checkInWindowMinutes,
      'checkOutWindowMinutes': checkOutWindowMinutes,
      'maxLateMinutes': maxLateMinutes,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  ShiftModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? startTime,
    String? endTime,
    List<int>? workDays,
    int? lateToleranceMinutes,
    int? checkInWindowMinutes,
    int? checkOutWindowMinutes,
    int? maxLateMinutes,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return ShiftModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      workDays: workDays ?? this.workDays,
      lateToleranceMinutes: lateToleranceMinutes ?? this.lateToleranceMinutes,
      checkInWindowMinutes: checkInWindowMinutes ?? this.checkInWindowMinutes,
      checkOutWindowMinutes: checkOutWindowMinutes ?? this.checkOutWindowMinutes,
      maxLateMinutes: maxLateMinutes ?? this.maxLateMinutes,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  // ============ OVERNIGHT SHIFT DETECTION ============
  
  /// Check if this is an overnight shift (crosses midnight)
  bool get isOvernightShift {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startHour = int.parse(startParts[0]);
    final endHour = int.parse(endParts[0]);
    
    // If end hour is less than start hour, it's overnight
    // e.g., 16:00 - 01:00 or 22:00 - 06:00
    return endHour < startHour;
  }

  // Parse time string to DateTime for a specific date
  DateTime startDateTime([DateTime? date]) {
    final parts = startTime.split(':');
    final targetDate = date ?? DateTime.now();
    return DateTime(
      targetDate.year, 
      targetDate.month, 
      targetDate.day,
      int.parse(parts[0]), 
      int.parse(parts[1]),
    );
  }

  /// Get end DateTime - handles overnight shifts by adding a day if needed
  DateTime endDateTime([DateTime? date]) {
    final parts = endTime.split(':');
    final targetDate = date ?? DateTime.now();
    
    DateTime endDt = DateTime(
      targetDate.year, 
      targetDate.month, 
      targetDate.day,
      int.parse(parts[0]), 
      int.parse(parts[1]),
    );
    
    // If overnight shift, add one day to end time
    if (isOvernightShift) {
      endDt = endDt.add(const Duration(days: 1));
    }
    
    return endDt;
  }

  /// Get end DateTime based on check-in time (for accurate checkout calculation)
  DateTime endDateTimeFromCheckIn(DateTime checkInTime) {
    final parts = endTime.split(':');
    final endHour = int.parse(parts[0]);
    final endMinute = int.parse(parts[1]);
    
    DateTime endDt = DateTime(
      checkInTime.year, 
      checkInTime.month, 
      checkInTime.day,
      endHour, 
      endMinute,
    );
    
    // If overnight shift or end time is before check-in time, add one day
    if (isOvernightShift || endDt.isBefore(checkInTime)) {
      endDt = endDt.add(const Duration(days: 1));
    }
    
    return endDt;
  }

  // Check if today is a work day
  bool isWorkDay(DateTime date) {
    final dayIndex = date.weekday == 7 ? 0 : date.weekday;
    return workDays.contains(dayIndex);
  }

  String get workDaysText {
    const days = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'];
    return workDays.map((d) => days[d]).join('، ');
  }

  /// Get shift duration in hours - handles overnight shifts
  String get shiftDuration {
    final start = startDateTime();
    final end = endDateTime();
    final diff = end.difference(start);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    
    if (minutes > 0) {
      return '$hours ساعات و $minutes دقيقة';
    }
    return '$hours ساعات';
  }

  /// Get shift duration in minutes
  int get shiftDurationMinutes {
    final start = startDateTime();
    final end = endDateTime();
    return end.difference(start).inMinutes;
  }

  // ============ CHECK-IN VALIDATION ============

  /// Get earliest allowed check-in time
  DateTime earliestCheckIn([DateTime? date]) {
    return startDateTime(date).subtract(Duration(minutes: checkInWindowMinutes));
  }

  /// Get latest allowed check-in time (after this = rejected)
  DateTime latestCheckIn([DateTime? date]) {
    return startDateTime(date).add(Duration(minutes: maxLateMinutes));
  }

  /// Check if can check in at given time
  Map<String, dynamic> canCheckIn([DateTime? time]) {
    final now = time ?? DateTime.now();
    final start = startDateTime(now);
    final earliest = earliestCheckIn(now);
    final latest = latestCheckIn(now);
    final end = endDateTime(now);

    // Too early
    if (now.isBefore(earliest)) {
      final waitMinutes = earliest.difference(now).inMinutes;
      return {
        'allowed': false,
        'reason': 'tooEarly',
        'message': 'لم يبدأ وقت التسجيل بعد\nيمكنك التسجيل بعد $waitMinutes دقيقة',
        'waitMinutes': waitMinutes,
      };
    }

    // Too late (exceeded max late)
    if (now.isAfter(latest)) {
      return {
        'allowed': false,
        'reason': 'tooLate',
        'message': 'انتهى وقت التسجيل\nتجاوزت الحد المسموح ($maxLateMinutes دقيقة)',
      };
    }

    // Shift already ended (for non-overnight shifts)
    if (!isOvernightShift && now.isAfter(end)) {
      return {
        'allowed': false,
        'reason': 'shiftEnded',
        'message': 'انتهى وقت الشفت',
      };
    }

    // Calculate late status
    final lateThreshold = start.add(Duration(minutes: lateToleranceMinutes));
    final isLate = now.isAfter(lateThreshold);
    final lateMinutes = now.isAfter(start) ? now.difference(start).inMinutes : 0;

    return {
      'allowed': true,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'message': isLate ? 'تسجيل متأخر ($lateMinutes دقيقة)' : 'تسجيل في الوقت المحدد',
    };
  }

  // ============ CHECK-OUT VALIDATION ============

  /// Get earliest allowed check-out time based on check-in
  DateTime earliestCheckOutFromCheckIn(DateTime checkInTime) {
    final end = endDateTimeFromCheckIn(checkInTime);
    return end.subtract(Duration(minutes: checkOutWindowMinutes));
  }

  /// Get earliest allowed check-out time (legacy - uses current date)
  DateTime earliestCheckOut([DateTime? date]) {
    return endDateTime(date).subtract(Duration(minutes: checkOutWindowMinutes));
  }

  /// Check if can check out at given time (considering check-in time for overnight)
  Map<String, dynamic> canCheckOutFromCheckIn(DateTime checkInTime, [DateTime? time]) {
    final now = time ?? DateTime.now();
    final end = endDateTimeFromCheckIn(checkInTime);
    final earliest = earliestCheckOutFromCheckIn(checkInTime);

    // Too early to check out
    if (now.isBefore(earliest)) {
      final waitMinutes = earliest.difference(now).inMinutes;
      return {
        'allowed': false,
        'reason': 'tooEarly',
        'message': 'لا يمكن تسجيل الخروج الآن\nيجب الانتظار $waitMinutes دقيقة',
        'waitMinutes': waitMinutes,
      };
    }

    // Calculate early leave status
    final isEarlyLeave = now.isBefore(end);
    final earlyMinutes = isEarlyLeave ? end.difference(now).inMinutes : 0;

    return {
      'allowed': true,
      'isEarlyLeave': isEarlyLeave,
      'earlyMinutes': earlyMinutes,
      'message': isEarlyLeave ? 'خروج مبكر ($earlyMinutes دقيقة)' : 'خروج في الوقت المحدد',
      'expectedEndTime': end,
    };
  }

  /// Check if can check out at given time (legacy)
  Map<String, dynamic> canCheckOut([DateTime? time]) {
    final now = time ?? DateTime.now();
    final earliest = earliestCheckOut(now);
    final end = endDateTime(now);

    // Too early to check out
    if (now.isBefore(earliest)) {
      final waitMinutes = earliest.difference(now).inMinutes;
      return {
        'allowed': false,
        'reason': 'tooEarly',
        'message': 'لا يمكن تسجيل الخروج الآن\nيجب الانتظار $waitMinutes دقيقة',
        'waitMinutes': waitMinutes,
      };
    }

    // Calculate early leave status
    final isEarlyLeave = now.isBefore(end);
    final earlyMinutes = isEarlyLeave ? end.difference(now).inMinutes : 0;

    return {
      'allowed': true,
      'isEarlyLeave': isEarlyLeave,
      'earlyMinutes': earlyMinutes,
      'message': isEarlyLeave ? 'خروج مبكر ($earlyMinutes دقيقة)' : 'خروج في الوقت المحدد',
    };
  }

  // ============ HELPER METHODS ============

  /// Check if late (after start + tolerance)
  bool isLate([DateTime? time]) {
    final now = time ?? DateTime.now();
    final lateThreshold = startDateTime(now).add(Duration(minutes: lateToleranceMinutes));
    return now.isAfter(lateThreshold);
  }

  /// Get late minutes
  int getLateMinutes([DateTime? time]) {
    final now = time ?? DateTime.now();
    final start = startDateTime(now);
    if (now.isBefore(start)) return 0;
    return now.difference(start).inMinutes;
  }

  /// Get time remaining in shift (considering overnight)
  Duration getTimeRemaining([DateTime? time]) {
    final now = time ?? DateTime.now();
    final end = endDateTime(now);
    
    // For overnight shifts, we need to check if we're past midnight
    if (isOvernightShift) {
      final start = startDateTime(now);
      // If current time is before start time (e.g., it's 2am and shift was 4pm-1am)
      // we need to check yesterday's shift
      if (now.isBefore(start) && now.hour < 12) {
        final yesterdayEnd = endDateTime(now.subtract(const Duration(days: 1)));
        if (now.isBefore(yesterdayEnd)) {
          return yesterdayEnd.difference(now);
        }
      }
    }
    
    if (now.isAfter(end)) return Duration.zero;
    return end.difference(now);
  }

  /// Get formatted time remaining
  String getTimeRemainingText([DateTime? time]) {
    final remaining = getTimeRemaining(time);
    if (remaining == Duration.zero) return 'انتهى الشفت';
    
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    
    if (hours > 0) {
      return 'متبقي $hours ساعة و $minutes دقيقة';
    }
    return 'متبقي $minutes دقيقة';
  }

  /// Calculate total hours between check-in and check-out (handles overnight)
  double calculateTotalHours(DateTime checkIn, DateTime checkOut) {
    return checkOut.difference(checkIn).inMinutes / 60.0;
  }

  /// Calculate expected end time from check-in
  DateTime getExpectedEndTime(DateTime checkInTime) {
    return endDateTimeFromCheckIn(checkInTime);
  }
}
