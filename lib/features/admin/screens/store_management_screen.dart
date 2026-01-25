import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/store_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class StoreManagementScreen extends StatefulWidget {
  const StoreManagementScreen({Key? key}) : super(key: key);

  @override
  State<StoreManagementScreen> createState() => _StoreManagementScreenState();
}

class _StoreManagementScreenState extends State<StoreManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        context.read<StoreProvider>().fetchStores(authProvider.user!.id);
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'إدارة المتاجر',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),

              // Store List
              Expanded(
                child: Consumer<StoreProvider>(
                  builder: (context, storeProvider, _) {
                    if (storeProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final stores = storeProvider.stores;

                    if (stores.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.store_outlined,
                              size: 80,
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'لا توجد متاجر',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: stores.length,
                      itemBuilder: (context, index) {
                        return _buildStoreCard(stores[index], index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditStoreDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة متجر'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildStoreCard(StoreModel store, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            store.address,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isDarkMode ? Colors.white54 : Colors.black54,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showAddEditStoreDialog(context, store: store);
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, store);
                  } else if (value == 'viewMap') {
                    _showMapPreview(context, store);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'viewMap',
                    child: Row(
                      children: [
                        Icon(Icons.map, size: 20),
                        SizedBox(width: 10),
                        Text('عرض الخريطة'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 10),
                        Text('تعديل'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: AppTheme.errorColor),
                        SizedBox(width: 10),
                        Text('حذف', style: TextStyle(color: AppTheme.errorColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Info chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (store.phone != null && store.phone!.isNotEmpty)
                _buildInfoChip(Icons.phone, store.phone!, AppTheme.secondaryColor),
              _buildInfoChip(
                Icons.my_location,
                'حضور: ${store.allowedRadius.toInt()}م',
                AppTheme.successColor,
              ),
              _buildInfoChip(
                Icons.radar,
                'مراقبة: ${store.monitoringRadius.toInt()}م',
                Colors.orange,
              ),
              _buildInfoChip(
                Icons.gps_fixed,
                'GPS محدد',
                AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditStoreDialog(BuildContext context, {StoreModel? store}) {
    final isEdit = store != null;
    final nameController = TextEditingController(text: store?.name);
    final addressController = TextEditingController(text: store?.address);
    final phoneController = TextEditingController(text: store?.phone);
    final radiusController = TextEditingController(
      text: store?.allowedRadius.toString() ?? '100',
    );
    final monitoringRadiusController = TextEditingController(
      text: store?.monitoringRadius.toString() ?? '400',
    );

    double? selectedLat = store?.latitude;
    double? selectedLng = store?.longitude;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.add_business,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(isEdit ? 'تعديل المتجر' : 'إضافة متجر جديد'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المتجر',
                      prefixIcon: Icon(Icons.store),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'العنوان',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نطاق الحضور والانصراف (متر)',
                      prefixIcon: Icon(Icons.my_location),
                      helperText: 'المسافة المسموحة لتسجيل الحضور والخروج',
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: monitoringRadiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'نطاق المراقبة أثناء الدوام (متر)',
                      prefixIcon: Icon(Icons.radar),
                      helperText: 'المسافة التي يُسمح للموظف بالابتعاد فيها أثناء العمل',
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Location Picker Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedLat != null 
                            ? AppTheme.successColor 
                            : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              selectedLat != null ? Icons.check_circle : Icons.gps_fixed,
                              color: selectedLat != null 
                                  ? AppTheme.successColor 
                                  : AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedLat != null
                                    ? 'تم تحديد الموقع'
                                    : 'موقع المتجر (مطلوب)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: selectedLat != null 
                                      ? AppTheme.successColor 
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (selectedLat != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'الإحداثيات: ${selectedLat!.toStringAsFixed(4)}, ${selectedLng!.toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  // Get current location
                                  final position = await _getCurrentLocation();
                                  if (position != null) {
                                    setState(() {
                                      selectedLat = position.latitude;
                                      selectedLng = position.longitude;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.my_location, size: 18),
                                label: const Text('موقعي الحالي'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapPickerScreen(
                                        initialLat: selectedLat,
                                        initialLng: selectedLng,
                                      ),
                                    ),
                                  );
                                  if (result != null) {
                                    setState(() {
                                      selectedLat = result.latitude;
                                      selectedLng = result.longitude;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.map, size: 18),
                                label: const Text('اختر من الخريطة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى إدخال اسم المتجر')),
                    );
                    return;
                  }
                  if (selectedLat == null || selectedLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى تحديد موقع المتجر على الخريطة')),
                    );
                    return;
                  }

                  final storeProvider = Provider.of<StoreProvider>(context, listen: false);
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);

                  final newStore = StoreModel(
                    id: store?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text,
                    address: addressController.text,
                    adminId: authProvider.user!.id,
                    phone: phoneController.text,
                    latitude: selectedLat!,
                    longitude: selectedLng!,
                    allowedRadius: double.tryParse(radiusController.text) ?? 100,
                    monitoringRadius: double.tryParse(monitoringRadiusController.text) ?? 400,
                    createdAt: store?.createdAt ?? DateTime.now(),
                  );

                  if (isEdit) {
                    storeProvider.updateStore(newStore);
                  } else {
                    storeProvider.createStore(newStore);
                  }

                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: Text(isEdit ? 'تحديث' : 'إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Position?> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يرجى تفعيل خدمة الموقع')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('يرجى السماح بالوصول للموقع')),
          );
          return null;
        }
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل في الحصول على الموقع')),
      );
      return null;
    }
  }

  void _showMapPreview(BuildContext context, StoreModel store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.map, color: AppTheme.primaryColor),
            const SizedBox(width: 10),
            Text(store.name),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(store.latitude, store.longitude),
                zoom: 17,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(store.id),
                  position: LatLng(store.latitude, store.longitude),
                  infoWindow: InfoWindow(title: store.name),
                ),
              },
              circles: {
                Circle(
                  circleId: CircleId(store.id),
                  center: LatLng(store.latitude, store.longitude),
                  radius: store.allowedRadius,
                  fillColor: AppTheme.primaryColor.withOpacity(0.2),
                  strokeColor: AppTheme.primaryColor,
                  strokeWidth: 2,
                ),
              },
              zoomControlsEnabled: true,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, StoreModel store) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: AppTheme.errorColor),
            SizedBox(width: 10),
            Text('حذف المتجر'),
          ],
        ),
        content: Text('هل أنت متأكد من حذف "${store.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<StoreProvider>().deleteStore(store.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MAP PICKER SCREEN
// ============================================================
class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    Key? key,
    this.initialLat,
    this.initialLng,
  }) : super(key: key);

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  bool _isLoading = true;

  // Default to Najaf if no initial location
  static const LatLng _defaultLocation = LatLng(31.9946, 44.3148);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (widget.initialLat != null && widget.initialLng != null) {
      setState(() {
        _selectedLocation = LatLng(widget.initialLat!, widget.initialLng!);
        _isLoading = false;
      });
    } else {
      // Try to get current location
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _selectedLocation = _defaultLocation;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('اختر موقع المتجر'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context, _selectedLocation);
              },
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text(
                'تأكيد',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? _defaultLocation,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: (latLng) {
                    setState(() {
                      _selectedLocation = latLng;
                    });
                  },
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _selectedLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueViolet,
                            ),
                          ),
                        }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: true,
                ),
                
                // Instructions
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.touch_app, color: AppTheme.primaryColor),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'اضغط على الخريطة لتحديد موقع المتجر',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected Location Info
                if (_selectedLocation != null)
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: AppTheme.primaryColor),
                              const SizedBox(width: 10),
                              const Text(
                                'الموقع المحدد',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 16,
                                      color: AppTheme.successColor,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'جاهز',
                                      style: TextStyle(
                                        color: AppTheme.successColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'خط العرض: ${_selectedLocation!.latitude.toStringAsFixed(6)}\n'
                            'خط الطول: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
