import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class CreateEditEmployeeScreen extends StatefulWidget {
  final UserModel? employee;

  const CreateEditEmployeeScreen({
    Key? key,
    this.employee,
  }) : super(key: key);

  @override
  State<CreateEditEmployeeScreen> createState() => _CreateEditEmployeeScreenState();
}

class _CreateEditEmployeeScreenState extends State<CreateEditEmployeeScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _passwordController;
  late TextEditingController _daysOffController;
  late TextEditingController _vacationDaysController;

  StoreModel? _selectedStore;
  ShiftModel? _selectedShift;
  bool _isFreeEmployee = false;
  bool _isLoading = false;

  bool get isEdit => widget.employee != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.employee?.name);
    _emailController = TextEditingController(text: widget.employee?.email);
    _phoneController = TextEditingController(text: widget.employee?.phone ?? '');
    _passwordController = TextEditingController();
    _daysOffController = TextEditingController(
      text: widget.employee?.daysOffPerMonth.toString() ?? '0',
    );
    _vacationDaysController = TextEditingController(
      text: widget.employee?.allowedVacationDays.toString() ?? '0',
    );
    _isFreeEmployee = widget.employee?.isFreeEmployee ?? false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeStoreAndShift();
    });
  }

  void _initializeStoreAndShift() {
    if (widget.employee != null && !widget.employee!.isFreeEmployee) {
      final storeProvider = context.read<StoreProvider>();
      final shiftProvider = context.read<ShiftProvider>();

      if (widget.employee!.storeId != null) {
        _selectedStore = storeProvider.activeStores
            .where((s) => s.id == widget.employee!.storeId)
            .firstOrNull;

        if (_selectedStore != null && widget.employee!.shiftId != null) {
          _selectedShift = shiftProvider
              .getShiftsByStore(_selectedStore!.id)
              .where((s) => s.id == widget.employee!.shiftId)
              .firstOrNull;
        }
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _daysOffController.dispose();
    _vacationDaysController.dispose();
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
                        isEdit ? 'تعديل بيانات الموظف' : 'إضافة موظف جديد',
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
                              Icons.person,
                              'المعلومات الأساسية',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 20),

                            // Name
                            _buildTextField(
                              controller: _nameController,
                              label: 'الاسم',
                              icon: Icons.person_outline,
                              hint: 'أدخل اسم الموظف',
                            ),
                            const SizedBox(height: 15),

                            // Email
                            _buildTextField(
                              controller: _emailController,
                              label: 'البريد الإلكتروني',
                              icon: Icons.email_outlined,
                              hint: 'example@email.com',
                              keyboardType: TextInputType.emailAddress,
                              enabled: !isEdit, // Can't change email for existing users
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

                            // Password (only for new employees)
                            if (!isEdit) ...[
                              const SizedBox(height: 15),
                              _buildTextField(
                                controller: _passwordController,
                                label: 'كلمة المرور',
                                icon: Icons.lock_outline,
                                hint: 'أدخل كلمة مرور قوية',
                                obscureText: true,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Employee Type
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.badge,
                              'نوع الموظف',
                              AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 15),
                            _buildFreeEmployeeToggle(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Store and Shift (only for regular employees)
                      if (!_isFreeEmployee)
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                Icons.store,
                                'المتجر والوردية',
                                Colors.purple,
                              ),
                              const SizedBox(height: 20),
                              _buildStoreDropdown(),
                              const SizedBox(height: 15),
                              if (_selectedStore != null) _buildShiftDropdown(),
                            ],
                          ),
                        ),

                      const SizedBox(height: 15),

                      // Vacation Settings
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.beach_access,
                              'إعدادات الإجازات',
                              AppTheme.warningColor,
                            ),
                            const SizedBox(height: 20),

                            // Days off per month
                            _buildTextField(
                              controller: _daysOffController,
                              label: 'أيام الإجازة الشهرية',
                              icon: Icons.event_busy,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              helperText: 'عدد أيام الراحة المسموحة شهرياً',
                            ),
                            const SizedBox(height: 15),

                            // Allowed vacation days
                            _buildTextField(
                              controller: _vacationDaysController,
                              label: 'رصيد الإجازات السنوية',
                              icon: Icons.calendar_month,
                              hint: '0',
                              keyboardType: TextInputType.number,
                              helperText: 'إجمالي أيام الإجازة المسموحة سنوياً',
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
    String? helperText,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool enabled = true,
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
          obscureText: obscureText,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: enabled
                ? (isDarkMode
                    ? Colors.white.withOpacity(0.05)
                    : Colors.grey.withOpacity(0.1))
                : (isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : Colors.grey.withOpacity(0.05)),
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

  Widget _buildFreeEmployeeToggle() {
    return InkWell(
      onTap: () {
        setState(() {
          _isFreeEmployee = !_isFreeEmployee;
          if (_isFreeEmployee) {
            _selectedStore = null;
            _selectedShift = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isFreeEmployee
              ? AppTheme.secondaryColor.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFreeEmployee
                ? AppTheme.secondaryColor
                : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isFreeEmployee
                    ? AppTheme.secondaryColor.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.gps_fixed,
                color: _isFreeEmployee ? AppTheme.secondaryColor : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'موظف حر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _isFreeEmployee
                          ? AppTheme.secondaryColor
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بدون متجر أو وردية محددة - تتبع GPS كامل',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _isFreeEmployee,
              onChanged: (value) {
                setState(() {
                  _isFreeEmployee = value;
                  if (value) {
                    _selectedStore = null;
                    _selectedShift = null;
                  }
                });
              },
              activeColor: AppTheme.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDropdown() {
    final storeProvider = context.watch<StoreProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المتجر',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<StoreModel>(
              value: _selectedStore,
              isExpanded: true,
              hint: const Row(
                children: [
                  Icon(Icons.store, size: 20, color: Colors.grey),
                  SizedBox(width: 10),
                  Text('اختر المتجر'),
                ],
              ),
              items: storeProvider.activeStores.map((store) {
                return DropdownMenuItem(
                  value: store,
                  child: Row(
                    children: [
                      const Icon(Icons.store, size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(child: Text(store.name)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStore = value;
                  _selectedShift = null;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShiftDropdown() {
    final shiftProvider = context.watch<ShiftProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shifts = shiftProvider.getShiftsByStore(_selectedStore!.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الوردية',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ShiftModel>(
              value: _selectedShift,
              isExpanded: true,
              hint: const Row(
                children: [
                  Icon(Icons.schedule, size: 20, color: Colors.grey),
                  SizedBox(width: 10),
                  Text('اختر الوردية'),
                ],
              ),
              items: shifts.map((shift) {
                return DropdownMenuItem(
                  value: shift,
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, size: 20, color: AppTheme.secondaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('${shift.name} (${shift.startTime} - ${shift.endTime})'),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedShift = value;
                });
              },
            ),
          ),
        ),
      ],
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
                onPressed: _isLoading ? null : _saveEmployee,
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
                        isEdit ? 'حفظ التغييرات' : 'إضافة الموظف',
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

  void _saveEmployee() async {
    // Validation
    if (_nameController.text.isEmpty) {
      _showError('يرجى إدخال اسم الموظف');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showError('يرجى إدخال البريد الإلكتروني');
      return;
    }

    if (!isEdit && _passwordController.text.isEmpty) {
      _showError('يرجى إدخال كلمة المرور');
      return;
    }

    if (!_isFreeEmployee && _selectedStore == null) {
      _showError('يرجى اختيار المتجر');
      return;
    }

    if (!_isFreeEmployee && _selectedShift == null) {
      _showError('يرجى اختيار الوردية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (isEdit) {
        // Update existing employee
        final employeeProvider = context.read<EmployeeProvider>();
        final success = await employeeProvider.updateEmployee(
          employeeId: widget.employee!.id,
          name: _nameController.text,
          phone: _phoneController.text,
          storeId: _isFreeEmployee ? null : _selectedStore?.id,
          storeName: _isFreeEmployee ? null : _selectedStore?.name,
          shiftId: _isFreeEmployee ? null : _selectedShift?.id,
          shiftName: _isFreeEmployee ? null : _selectedShift?.name,
          daysOffPerMonth: int.tryParse(_daysOffController.text) ?? 0,
          allowedVacationDays: int.tryParse(_vacationDaysController.text) ?? 0,
          employeeType: _isFreeEmployee ? EmployeeType.free : EmployeeType.regular,
        );

        if (success) {
          Navigator.pop(context, true);
          _showSuccess('تم تحديث بيانات الموظف بنجاح');
        } else {
          setState(() => _isLoading = false);
          _showError(employeeProvider.errorMessage ?? 'فشل في تحديث البيانات');
        }
      } else {
        // Create new employee
        final authProvider = context.read<AuthProvider>();
        final success = await authProvider.createEmployee(
          name: _nameController.text,
          email: _emailController.text,
          phone: _phoneController.text.isNotEmpty ? _phoneController.text : '',
          password: _passwordController.text,
          storeId: _isFreeEmployee ? null : _selectedStore!.id,
          storeName: _isFreeEmployee ? null : _selectedStore!.name,
          shiftId: _isFreeEmployee ? null : _selectedShift!.id,
          shiftName: _isFreeEmployee ? null : _selectedShift!.name,
          daysOffPerMonth: int.tryParse(_daysOffController.text) ?? 0,
          allowedVacationDays: int.tryParse(_vacationDaysController.text) ?? 0,
          employeeType: _isFreeEmployee ? EmployeeType.free : EmployeeType.regular,
        );

        if (success) {
          // Refresh employee list
          await context.read<EmployeeProvider>().fetchEmployees();
          Navigator.pop(context, true);
          _showSuccess(_isFreeEmployee
              ? 'تم إضافة الموظف الحر بنجاح'
              : 'تم إضافة الموظف بنجاح');
        } else {
          setState(() => _isLoading = false);
          _showError(authProvider.errorMessage ?? 'فشل في إضافة الموظف');
        }
      }
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

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}
