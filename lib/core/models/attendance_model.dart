class LocationData {
  final double latitude;
  final double longitude;
  final String address;

  const LocationData({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}

class AttendanceModel {
  final String id;
  final String userId;
  final String userName;
  final String storeId;
  final String storeName;
  final String shiftId;
  final String shiftName;
  final String expectedStartTime;
  final String expectedEndTime;
  final DateTime checkIn;
  final DateTime? checkOut;
  final LocationData checkInLocation;
  final LocationData? checkOutLocation;
  final double? totalHours;
  final bool isLate;
  final int lateMinutes;
  final bool isEarlyLeave;
  final int earlyLeaveMinutes;
  final String? notes;
  final int penaltyMinutes;  // NEW: Penalty for being late beyond tolerance

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.storeId,
    required this.storeName,
    required this.shiftId,
    required this.shiftName,
    required this.expectedStartTime,
    required this.expectedEndTime,
    required this.checkIn,
    this.checkOut,
    required this.checkInLocation,
    this.checkOutLocation,
    this.totalHours,
    this.isLate = false,
    this.lateMinutes = 0,
    this.isEarlyLeave = false,
    this.earlyLeaveMinutes = 0,
    this.notes,
    this.penaltyMinutes = 0,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? '',
      storeId: json['storeId'] as String,
      storeName: json['storeName'] as String? ?? '',
      shiftId: json['shiftId'] as String,
      shiftName: json['shiftName'] as String? ?? '',
      expectedStartTime: json['expectedStartTime'] as String? ?? '',
      expectedEndTime: json['expectedEndTime'] as String? ?? '',
      checkIn: DateTime.parse(json['checkIn'] as String),
      checkOut: json['checkOut'] != null
          ? DateTime.parse(json['checkOut'] as String)
          : null,
      checkInLocation: LocationData.fromJson(
        json['checkInLocation'] as Map<String, dynamic>,
      ),
      checkOutLocation: json['checkOutLocation'] != null
          ? LocationData.fromJson(
              json['checkOutLocation'] as Map<String, dynamic>,
            )
          : null,
      totalHours: (json['totalHours'] as num?)?.toDouble(),
      isLate: json['isLate'] as bool? ?? false,
      lateMinutes: json['lateMinutes'] as int? ?? 0,
      isEarlyLeave: json['isEarlyLeave'] as bool? ?? false,
      earlyLeaveMinutes: json['earlyLeaveMinutes'] as int? ?? 0,
      notes: json['notes'] as String?,
      penaltyMinutes: json['penaltyMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'storeId': storeId,
      'storeName': storeName,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'expectedStartTime': expectedStartTime,
      'expectedEndTime': expectedEndTime,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'checkInLocation': checkInLocation.toJson(),
      'checkOutLocation': checkOutLocation?.toJson(),
      'totalHours': totalHours,
      'isLate': isLate,
      'lateMinutes': lateMinutes,
      'isEarlyLeave': isEarlyLeave,
      'earlyLeaveMinutes': earlyLeaveMinutes,
      'notes': notes,
      'penaltyMinutes': penaltyMinutes,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? storeId,
    String? storeName,
    String? shiftId,
    String? shiftName,
    String? expectedStartTime,
    String? expectedEndTime,
    DateTime? checkIn,
    DateTime? checkOut,
    LocationData? checkInLocation,
    LocationData? checkOutLocation,
    double? totalHours,
    bool? isLate,
    int? lateMinutes,
    bool? isEarlyLeave,
    int? earlyLeaveMinutes,
    String? notes,
    int? penaltyMinutes,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      expectedStartTime: expectedStartTime ?? this.expectedStartTime,
      expectedEndTime: expectedEndTime ?? this.expectedEndTime,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      checkInLocation: checkInLocation ?? this.checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      totalHours: totalHours ?? this.totalHours,
      isLate: isLate ?? this.isLate,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      isEarlyLeave: isEarlyLeave ?? this.isEarlyLeave,
      earlyLeaveMinutes: earlyLeaveMinutes ?? this.earlyLeaveMinutes,
      notes: notes ?? this.notes,
      penaltyMinutes: penaltyMinutes ?? this.penaltyMinutes,
    );
  }

  // Helpers
  String get formattedCheckIn {
    return '${checkIn.hour.toString().padLeft(2, '0')}:${checkIn.minute.toString().padLeft(2, '0')}';
  }

  String? get formattedCheckOut {
    if (checkOut == null) return null;
    return '${checkOut!.hour.toString().padLeft(2, '0')}:${checkOut!.minute.toString().padLeft(2, '0')}';
  }

  String get formattedTotalHours {
    if (totalHours == null) return '--';
    final hours = totalHours!.floor();
    final minutes = ((totalHours! - hours) * 60).round();
    return '${hours}س ${minutes}د';
  }

  // NEW: Get effective hours after penalty
  double get effectiveHours {
    if (totalHours == null) return 0;
    final penaltyHours = penaltyMinutes / 60.0;
    final effective = totalHours! - penaltyHours;
    return effective > 0 ? effective : 0;
  }

  String get formattedEffectiveHours {
    final hours = effectiveHours.floor();
    final minutes = ((effectiveHours - hours) * 60).round();
    return '${hours}س ${minutes}د';
  }

  String get dateString {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${checkIn.day} ${months[checkIn.month - 1]} ${checkIn.year}';
  }

  String get complianceStatus {
    if (isLate && isEarlyLeave) {
      return 'تأخير وخروج مبكر';
    } else if (isLate) {
      return 'تأخير $lateMinutes دقيقة';
    } else if (isEarlyLeave) {
      return 'خروج مبكر $earlyLeaveMinutes دقيقة';
    }
    return 'ملتزم';
  }

  // NEW: Get penalty status text
  String get penaltyStatus {
    if (penaltyMinutes > 0) {
      final hours = penaltyMinutes ~/ 60;
      final mins = penaltyMinutes % 60;
      if (hours > 0 && mins > 0) {
        return 'خصم $hours ساعة و $mins دقيقة';
      } else if (hours > 0) {
        return 'خصم $hours ساعة';
      } else {
        return 'خصم $mins دقيقة';
      }
    }
    return 'لا يوجد خصم';
  }

  bool get isCompliant => !isLate && !isEarlyLeave;
  
  // NEW: Check if has penalty
  bool get hasPenalty => penaltyMinutes > 0;
}
