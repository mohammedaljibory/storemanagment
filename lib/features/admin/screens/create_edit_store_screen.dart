import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/store_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import 'store_management_screen.dart';

class CreateEditStoreScreen extends StatefulWidget {
  final StoreModel? store;

  const CreateEditStoreScreen({
    Key? key,
    this.store,
  }) : super(key: key);

  @override
  State<CreateEditStoreScreen> createState() => _CreateEditStoreScreenState();
}

class _CreateEditStoreScreenState extends State<CreateEditStoreScreen> {
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _radiusController;
  late TextEditingController _monitoringRadiusController;

  double? _selectedLat;
  double? _selectedLng;
  bool _isLoading = false;

  bool get isEdit => widget.store != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store?.name);
    _addressController = TextEditingController(text: widget.store?.address);
    _phoneController = TextEditingController(text: widget.store?.phone);
    _radiusController = TextEditingController(
      text: widget.store?.allowedRadius.toString() ?? '100',
    );
    _monitoringRadiusController = TextEditingController(
      text: widget.store?.monitoringRadius.toString() ?? '400',
    );
    _selectedLat = widget.store?.latitude;
    _selectedLng = widget.store?.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _radiusController.dispose();
    _monitoringRadiusController.dispose();
    super.dispose();
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
                    Expanded(
                      child: Text(
                        isEdit ? 'تعديل المتجر' : 'إضافة متجر جديد',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.store,
                              'معلومات المتجر',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 20),

                            // Name
                            _buildTextField(
                              controller: _nameController,
                              label: 'اسم المتجر',
                              icon: Icons.store_mall_directory,
                              hint: 'أدخل اسم المتجر',
                            ),
                            const SizedBox(height: 15),

                            // Address
                            _buildTextField(
                              controller: _addressController,
                              label: 'العنوان',
                              icon: Icons.location_on_outlined,
                              hint: 'أدخل عنوان المتجر',
                            ),
                            const SizedBox(height: 15),

                            // Phone
                            _buildTextField(
                              controller: _phoneController,
                              label: 'رقم الهاتف',
                              icon: Icons.phone_outlined,
                              hint: '07XXXXXXXX',
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Location
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.gps_fixed,
                              'موقع المتجر',
                              AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 20),
                            _buildLocationPicker(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Radius Settings
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.radar,
                              'إعدادات النطاق',
                              Colors.orange,
                            ),
                            const SizedBox(height: 20),

                            // Attendance Radius
                            _buildRadiusField(
                              controller: _radiusController,
                              label: 'نطاق الحضور والانصراف',
                              icon: Icons.my_location,
                              color: AppTheme.successColor,
                              helperText: 'المسافة المسموحة لتسجيل الحضور والخروج (بالمتر)',
                            ),
                            const SizedBox(height: 20),

                            // Monitoring Radius
                            _buildRadiusField(
                              controller: _monitoringRadiusController,
                              label: 'نطاق المراقبة أثناء الدوام',
                              icon: Icons.radar,
                              color: Colors.orange,
                              helperText: 'المسافة التي يُسمح للموظف بالابتعاد فيها أثناء العمل (بالمتر)',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDarkMode),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRadiusField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    String? helperText,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'أدخل المسافة بالمتر',
              suffixText: 'متر',
              filled: true,
              fillColor: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 8),
            Text(
              helperText,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationPicker() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final hasLocation = _selectedLat != null && _selectedLng != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasLocation
            ? AppTheme.successColor.withOpacity(0.1)
            : (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation ? AppTheme.successColor : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: hasLocation
                      ? AppTheme.successColor.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasLocation ? Icons.check_circle : Icons.gps_fixed,
                  color: hasLocation ? AppTheme.successColor : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasLocation ? 'تم تحديد الموقع' : 'موقع المتجر (مطلوب)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: hasLocation ? AppTheme.successColor : null,
                      ),
                    ),
                    if (hasLocation) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedLat!.toStringAsFixed(4)}, ${_selectedLng!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location, size: 18),
                  label: const Text('موقعي الحالي'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('اختر من الخريطة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(
                    color: isDarkMode ? Colors.white30 : Colors.grey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveStore,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEdit ? 'تحديث المتجر' : 'إضافة المتجر',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('يرجى تفعيل خدمة الموقع');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('يرجى السماح بالوصول للموقع');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLat = position.latitude;
        _selectedLng = position.longitude;
      });
    } catch (e) {
      _showError('فشل في الحصول على الموقع');
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLat: _selectedLat,
          initialLng: _selectedLng,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedLat = result.latitude;
        _selectedLng = result.longitude;
      });
    }
  }

  void _saveStore() {
    if (_nameController.text.isEmpty) {
      _showError('يرجى إدخال اسم المتجر');
      return;
    }

    if (_selectedLat == null || _selectedLng == null) {
      _showError('يرجى تحديد موقع المتجر على الخريطة');
      return;
    }

    setState(() => _isLoading = true);

    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final newStore = StoreModel(
      id: widget.store?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      address: _addressController.text,
      adminId: authProvider.user!.id,
      phone: _phoneController.text,
      latitude: _selectedLat!,
      longitude: _selectedLng!,
      allowedRadius: double.tryParse(_radiusController.text) ?? 100,
      monitoringRadius: double.tryParse(_monitoringRadiusController.text) ?? 400,
      createdAt: widget.store?.createdAt ?? DateTime.now(),
    );

    try {
      if (isEdit) {
        storeProvider.updateStore(newStore);
      } else {
        storeProvider.createStore(newStore);
      }
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('حدث خطأ: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }
}
