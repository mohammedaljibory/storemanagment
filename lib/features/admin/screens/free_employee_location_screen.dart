import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class FreeEmployeeLocationScreen extends StatefulWidget {
  final UserModel employee;
  final String? attendanceId;

  const FreeEmployeeLocationScreen({
    Key? key,
    required this.employee,
    this.attendanceId,
  }) : super(key: key);

  @override
  State<FreeEmployeeLocationScreen> createState() => _FreeEmployeeLocationScreenState();
}

class _FreeEmployeeLocationScreenState extends State<FreeEmployeeLocationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  StreamSubscription? _locationSubscription;

  LatLng? _currentLocation;
  List<LatLng> _locationHistory = [];
  DateTime? _lastUpdate;
  bool _isLoading = true;
  String? _attendanceId;

  @override
  void initState() {
    super.initState();
    _attendanceId = widget.attendanceId;
    _loadData();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // If no attendanceId provided, find the active one
    if (_attendanceId == null) {
      final activeAttendance = await _firestore
          .collection('attendance')
          .where('userId', isEqualTo: widget.employee.id)
          .where('isCheckedOut', isEqualTo: false)
          .orderBy('checkIn', descending: true)
          .limit(1)
          .get();

      if (activeAttendance.docs.isNotEmpty) {
        _attendanceId = activeAttendance.docs.first.id;
      }
    }

    if (_attendanceId != null) {
      // Get current location from attendance record
      await _loadCurrentLocation();
      // Load location history
      await _loadLocationHistory();
      // Start real-time updates
      _startLocationStream();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCurrentLocation() async {
    if (_attendanceId == null) return;

    try {
      final doc = await _firestore.collection('attendance').doc(_attendanceId).get();
      if (doc.exists && doc.data()?['currentLocation'] != null) {
        final location = doc.data()!['currentLocation'] as Map<String, dynamic>;
        setState(() {
          _currentLocation = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );
          if (location['timestamp'] != null) {
            _lastUpdate = DateTime.parse(location['timestamp'] as String);
          }
        });
      }
    } catch (e) {
      print('Error loading current location: $e');
    }
  }

  Future<void> _loadLocationHistory() async {
    if (_attendanceId == null) return;

    try {
      final snapshot = await _firestore
          .collection('location_history')
          .where('attendanceId', isEqualTo: _attendanceId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final history = <LatLng>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (data['latitude'] != null && data['longitude'] != null) {
          history.add(LatLng(
            data['latitude'] as double,
            data['longitude'] as double,
          ));
        }
      }

      setState(() {
        _locationHistory = history;
      });
    } catch (e) {
      print('Error loading location history: $e');
    }
  }

  void _startLocationStream() {
    if (_attendanceId == null) return;

    _locationSubscription = _firestore
        .collection('attendance')
        .doc(_attendanceId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data()?['currentLocation'] != null) {
        final location = snapshot.data()!['currentLocation'] as Map<String, dynamic>;
        final newLocation = LatLng(
          location['latitude'] as double,
          location['longitude'] as double,
        );

        setState(() {
          _currentLocation = newLocation;
          if (location['timestamp'] != null) {
            _lastUpdate = DateTime.parse(location['timestamp'] as String);
          }
        });

        // Animate camera to new location
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(newLocation),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [const Color(0xFF1A1A2E), const Color(0xFF0F0F1E)]
                : [const Color(0xFFE3F2FD), const Color(0xFFF5F5F5)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _currentLocation == null
                        ? _buildNoLocationView()
                        : _buildMapView(),
              ),
              _buildInfoPanel(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.secondaryColor.withOpacity(0.2),
            child: Icon(Icons.gps_fixed, color: AppTheme.secondaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'موظف حر',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_lastUpdate != null)
                      Text(
                        'آخر تحديث: ${_formatTime(_lastUpdate!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _refreshLocation,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث الموقع',
          ),
        ],
      ),
    );
  }

  Widget _buildNoLocationView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 20),
          Text(
            'لا يوجد موقع متاح',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'الموظف غير مسجل دخول حالياً\nأو لم يتم تسجيل موقعه بعد',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    // Current location marker
    if (_currentLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('current'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: widget.employee.name,
          snippet: _lastUpdate != null ? 'آخر تحديث: ${_formatTime(_lastUpdate!)}' : null,
        ),
      ));
    }

    // Location history polyline
    if (_locationHistory.isNotEmpty) {
      polylinePoints.addAll(_locationHistory);
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _currentLocation ?? const LatLng(24.7136, 46.6753), // Default to Riyadh
          zoom: 16,
        ),
        markers: markers,
        polylines: {
          if (polylinePoints.length > 1)
            Polyline(
              polylineId: const PolylineId('history'),
              points: polylinePoints,
              color: AppTheme.secondaryColor.withOpacity(0.6),
              width: 3,
            ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        mapToolbarEnabled: false,
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildInfoItem(
                icon: Icons.location_on,
                label: 'الموقع الحالي',
                value: _currentLocation != null
                    ? '${_currentLocation!.latitude.toStringAsFixed(4)}, ${_currentLocation!.longitude.toStringAsFixed(4)}'
                    : 'غير متاح',
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 16),
              _buildInfoItem(
                icon: Icons.history,
                label: 'سجل المواقع',
                value: '${_locationHistory.length} نقطة',
                color: AppTheme.secondaryColor,
              ),
            ],
          ),
          if (_lastUpdate != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'آخر تحديث: ${_formatDateTime(_lastUpdate!)}',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoading = true;
    });
    await _loadCurrentLocation();
    await _loadLocationHistory();
    setState(() {
      _isLoading = false;
    });

    if (_currentLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentLocation!),
      );
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime time) {
    return '${time.day}/${time.month}/${time.year} ${_formatTime(time)}';
  }
}
