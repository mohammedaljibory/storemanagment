import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, employee }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final String? photoUrl;
  final String? storeId;
  final String? storeName;
  final String? shiftId;
  final String? shiftName;
  final DateTime createdAt;
  final bool isActive;
  final int daysOffPerMonth;

  // Vacation balance tracking
  final int allowedVacationDays;    // Total vacation days allowed per year (set by admin)
  final int usedVacationDays;       // Vacation days used this year
  final int vacationYear;           // Year for vacation tracking (resets annually)

  // NEW: Temporary shift override fields
  final String? temporaryShiftId;
  final String? temporaryShiftName;
  final DateTime? temporaryShiftDate;  // The date this temporary shift applies to
  final DateTime? temporaryShiftExpiry; // When the temporary assignment expires

  // FCM Push Notification tokens (supports multiple devices)
  final List<String> fcmTokens;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.photoUrl,
    this.storeId,
    this.storeName,
    this.shiftId,
    this.shiftName,
    required this.createdAt,
    this.isActive = true,
    this.daysOffPerMonth = 0,
    this.allowedVacationDays = 0,
    this.usedVacationDays = 0,
    this.vacationYear = 0,
    this.temporaryShiftId,
    this.temporaryShiftName,
    this.temporaryShiftDate,
    this.temporaryShiftExpiry,
    this.fcmTokens = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: _parseRole(json['role']),
      photoUrl: json['photoUrl'] as String?,
      storeId: json['storeId'] as String?,
      storeName: json['storeName'] as String?,
      shiftId: json['shiftId'] as String?,
      shiftName: json['shiftName'] as String?,
      createdAt: _parseDateTime(json['createdAt']),
      isActive: json['isActive'] as bool? ?? true,
      daysOffPerMonth: json['daysOffPerMonth'] as int? ?? 0,
      allowedVacationDays: json['allowedVacationDays'] as int? ?? 0,
      usedVacationDays: json['usedVacationDays'] as int? ?? 0,
      vacationYear: json['vacationYear'] as int? ?? DateTime.now().year,
      temporaryShiftId: json['temporaryShiftId'] as String?,
      temporaryShiftName: json['temporaryShiftName'] as String?,
      temporaryShiftDate: _parseDateTimeNullable(json['temporaryShiftDate']),
      temporaryShiftExpiry: _parseDateTimeNullable(json['temporaryShiftExpiry']),
      fcmTokens: _parseStringList(json['fcmTokens']),
    );
  }

  /// Parse role from various formats
  static UserRole _parseRole(dynamic role) {
    if (role == null) return UserRole.employee;
    
    String roleStr = role.toString().toLowerCase();
    
    // Handle "UserRole.admin" format
    if (roleStr.contains('.')) {
      roleStr = roleStr.split('.').last;
    }
    
    if (roleStr == 'admin') return UserRole.admin;
    return UserRole.employee;
  }

  /// Parse DateTime from Firestore Timestamp or String
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    
    // Handle Firestore Timestamp
    if (value is Timestamp) {
      return value.toDate();
    }
    
    // Handle String (ISO 8601 format)
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    
    // Handle DateTime directly
    if (value is DateTime) {
      return value;
    }
    
    return DateTime.now();
  }

  /// Parse nullable DateTime
  static DateTime? _parseDateTimeNullable(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  /// Parse list of strings (for FCM tokens)
  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.toString().split('.').last,
      'photoUrl': photoUrl,
      'storeId': storeId,
      'storeName': storeName,
      'shiftId': shiftId,
      'shiftName': shiftName,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'daysOffPerMonth': daysOffPerMonth,
      'allowedVacationDays': allowedVacationDays,
      'usedVacationDays': usedVacationDays,
      'vacationYear': vacationYear,
      'temporaryShiftId': temporaryShiftId,
      'temporaryShiftName': temporaryShiftName,
      'temporaryShiftDate': temporaryShiftDate?.toIso8601String(),
      'temporaryShiftExpiry': temporaryShiftExpiry?.toIso8601String(),
      'fcmTokens': fcmTokens,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? photoUrl,
    String? storeId,
    String? storeName,
    String? shiftId,
    String? shiftName,
    DateTime? createdAt,
    bool? isActive,
    int? daysOffPerMonth,
    int? allowedVacationDays,
    int? usedVacationDays,
    int? vacationYear,
    String? temporaryShiftId,
    String? temporaryShiftName,
    DateTime? temporaryShiftDate,
    DateTime? temporaryShiftExpiry,
    List<String>? fcmTokens,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      shiftId: shiftId ?? this.shiftId,
      shiftName: shiftName ?? this.shiftName,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      daysOffPerMonth: daysOffPerMonth ?? this.daysOffPerMonth,
      allowedVacationDays: allowedVacationDays ?? this.allowedVacationDays,
      usedVacationDays: usedVacationDays ?? this.usedVacationDays,
      vacationYear: vacationYear ?? this.vacationYear,
      temporaryShiftId: temporaryShiftId ?? this.temporaryShiftId,
      temporaryShiftName: temporaryShiftName ?? this.temporaryShiftName,
      temporaryShiftDate: temporaryShiftDate ?? this.temporaryShiftDate,
      temporaryShiftExpiry: temporaryShiftExpiry ?? this.temporaryShiftExpiry,
      fcmTokens: fcmTokens ?? this.fcmTokens,
    );
  }

  /// Clear temporary shift (returns new instance with null values)
  UserModel clearTemporaryShift() {
    return UserModel(
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: role,
      photoUrl: photoUrl,
      storeId: storeId,
      storeName: storeName,
      shiftId: shiftId,
      shiftName: shiftName,
      createdAt: createdAt,
      isActive: isActive,
      daysOffPerMonth: daysOffPerMonth,
      allowedVacationDays: allowedVacationDays,
      usedVacationDays: usedVacationDays,
      vacationYear: vacationYear,
      temporaryShiftId: null,
      temporaryShiftName: null,
      temporaryShiftDate: null,
      temporaryShiftExpiry: null,
      fcmTokens: fcmTokens,
    );
  }

  // ============ VACATION HELPERS ============

  /// Get remaining vacation days
  int get remainingVacationDays {
    final currentYear = DateTime.now().year;
    // Reset if year changed
    if (vacationYear != currentYear) {
      return allowedVacationDays;
    }
    return allowedVacationDays - usedVacationDays;
  }

  /// Check if user has vacation balance available
  bool hasVacationBalance(int days) {
    return remainingVacationDays >= days;
  }

  /// Check if user is admin
  bool get isAdmin => role == UserRole.admin;

  /// Check if user is employee
  bool get isEmployee => role == UserRole.employee;

  /// Check if user has an active temporary shift for today
  bool get hasActiveTemporaryShift {
    if (temporaryShiftId == null || temporaryShiftDate == null) return false;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tempDate = DateTime(
      temporaryShiftDate!.year, 
      temporaryShiftDate!.month, 
      temporaryShiftDate!.day,
    );
    
    // Check if temporary shift is for today
    if (tempDate != today) return false;
    
    // Check if not expired
    if (temporaryShiftExpiry != null && now.isAfter(temporaryShiftExpiry!)) {
      return false;
    }
    
    return true;
  }

  /// Get the effective shift ID for today (considers temporary shift)
  String? get effectiveShiftId {
    if (hasActiveTemporaryShift) {
      return temporaryShiftId;
    }
    return shiftId;
  }

  /// Get the effective shift name for today (considers temporary shift)
  String? get effectiveShiftName {
    if (hasActiveTemporaryShift) {
      return temporaryShiftName;
    }
    return shiftName;
  }

  /// Check if temporary shift is for a specific date
  bool hasTemporaryShiftForDate(DateTime date) {
    if (temporaryShiftId == null || temporaryShiftDate == null) return false;
    
    final targetDate = DateTime(date.year, date.month, date.day);
    final tempDate = DateTime(
      temporaryShiftDate!.year, 
      temporaryShiftDate!.month, 
      temporaryShiftDate!.day,
    );
    
    return tempDate == targetDate;
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role)';
  }
}
