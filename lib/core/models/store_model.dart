class StoreModel {
  final String id;
  final String name;
  final String address;
  final String adminId;
  final String? phone;
  final double latitude; // Required - GPS coordinates
  final double longitude; // Required - GPS coordinates
  final double allowedRadius; // meters for check-in/check-out
  final double monitoringRadius; // meters for during-shift monitoring alerts
  final DateTime createdAt;
  final bool isActive;

  StoreModel({
    required this.id,
    required this.name,
    required this.address,
    required this.adminId,
    this.phone,
    required this.latitude,
    required this.longitude,
    this.allowedRadius = 100, // Default: 100m for check-in/out
    this.monitoringRadius = 400, // Default: 400m for during-shift
    required this.createdAt,
    this.isActive = true,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    return StoreModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      adminId: json['adminId'] as String,
      phone: json['phone'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      allowedRadius: (json['allowedRadius'] as num?)?.toDouble() ?? 100,
      monitoringRadius: (json['monitoringRadius'] as num?)?.toDouble() ?? 400,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'adminId': adminId,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'allowedRadius': allowedRadius,
      'monitoringRadius': monitoringRadius,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  StoreModel copyWith({
    String? id,
    String? name,
    String? address,
    String? adminId,
    String? phone,
    double? latitude,
    double? longitude,
    double? allowedRadius,
    double? monitoringRadius,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return StoreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      adminId: adminId ?? this.adminId,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      allowedRadius: allowedRadius ?? this.allowedRadius,
      monitoringRadius: monitoringRadius ?? this.monitoringRadius,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Check if a position is within allowed radius (for check-in/out)
  bool isWithinRadius(double lat, double lng) {
    final distance = _calculateDistance(latitude, longitude, lat, lng);
    return distance <= allowedRadius;
  }

  /// Check if a position is within monitoring radius (for during-shift alerts)
  bool isWithinMonitoringRadius(double lat, double lng) {
    final distance = _calculateDistance(latitude, longitude, lat, lng);
    return distance <= monitoringRadius;
  }

  /// Get distance from store in meters
  double getDistanceFrom(double lat, double lng) {
    return _calculateDistance(latitude, longitude, lat, lng);
  }

  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(lat1)) * _cos(_toRadians(lat2)) *
        _sin(dLon / 2) * _sin(dLon / 2);

    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  static double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  static double _sin(double x) => _Taylor.sin(x);
  static double _cos(double x) => _Taylor.cos(x);
  static double _sqrt(double x) => _Taylor.sqrt(x);
  static double _atan2(double y, double x) => _Taylor.atan2(y, x);
}

/// Simple math implementation to avoid dart:math import issues
class _Taylor {
  static double sin(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    while (x < -3.141592653589793) x += 2 * 3.141592653589793;

    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  static double cos(double x) {
    return sin(x + 3.141592653589793 / 2);
  }

  static double sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  static double atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }

  static double _atan(double x) {
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.141592653589793 / 2 - _atan(1 / x.abs()));
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 15; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }
}
