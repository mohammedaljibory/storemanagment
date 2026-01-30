import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class AddOvertimeScreen extends StatefulWidget {
  const AddOvertimeScreen({Key? key}) : super(key: key);

  @override
  State<AddOvertimeScreen> createState() => _AddOvertimeScreenState();
}

class _AddOvertimeScreenState extends State<AddOvertimeScreen> {
  UserModel? _selectedEmployee;
  StoreModel? _selectedStore;
  ShiftModel? _selectedShift;
  List<ShiftModel> _availableShifts = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final storeProvider = context.read<StoreProvider>();
    final shiftProvider = context.read<ShiftProvider>();

    if (storeProvider.activeStores.isNotEmpty) {
      _selectedStore = storeProvider.activeStores.first;
      _availableShifts = shiftProvider.getShiftsByStore(_selectedStore!.id);

      if (_availableShifts.isEmpty) {
        await shiftProvider.fetchShifts(_selectedStore!.id);
        _availableShifts = shiftProvider.getShiftsByStore(_selectedStore!.id);
      }

      if (_availableShifts.isNotEmpty) {
        _selectedShift = _availableShifts.first;
      }

      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final employeeProvider = context.watch<EmployeeProvider>();
    final storeProvider = context.watch<StoreProvider>();

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
                        'تسجيل أوفرتايم',
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
                      // Info Card
                      GlassContainer(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.more_time,
                                  color: Colors.green,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'تسجيل أوفرتايم',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'سيتم تسجيل حضور الموظف كـ "أوفرتايم" وتُحتسب الساعات إضافية',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Employee Selection
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.person,
                              'اختر الموظف',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 15),
                            _buildEmployeeDropdown(employeeProvider.activeEmployees),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Store Selection
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.store,
                              'المتجر',
                              AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 15),
                            _buildStoreDropdown(storeProvider.activeStores),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Shift Selection
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.schedule,
                              'الشفت',
                              Colors.orange,
                            ),
                            const SizedBox(height: 15),
                            _buildShiftDropdown(),
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

  Widget _buildEmployeeDropdown(List<UserModel> employees) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('لا يوجد موظفين متاحين'),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<UserModel>(
          value: _selectedEmployee,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: Colors.grey),
              SizedBox(width: 10),
              Text('اختر الموظف'),
            ],
          ),
          items: employees.map((employee) {
            return DropdownMenuItem(
              value: employee,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                    child: Text(
                      employee.name.isNotEmpty ? employee.name[0] : '?',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          employee.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (employee.storeName != null)
                          Text(
                            employee.storeName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedEmployee = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildStoreDropdown(List<StoreModel> stores) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final shiftProvider = context.read<ShiftProvider>();

    return Container(
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
              Icon(Icons.store_outlined, size: 20, color: Colors.grey),
              SizedBox(width: 10),
              Text('اختر المتجر'),
            ],
          ),
          items: stores.map((store) {
            return DropdownMenuItem(
              value: store,
              child: Row(
                children: [
                  const Icon(Icons.store, size: 20, color: AppTheme.secondaryColor),
                  const SizedBox(width: 10),
                  Expanded(child: Text(store.name)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) async {
            setState(() {
              _selectedStore = value;
              _selectedShift = null;
              _availableShifts = [];
            });

            if (value != null) {
              var shifts = shiftProvider.getShiftsByStore(value.id);
              if (shifts.isEmpty) {
                await shiftProvider.fetchShifts(value.id);
                shifts = shiftProvider.getShiftsByStore(value.id);
              }
              setState(() {
                _availableShifts = shifts;
                if (shifts.isNotEmpty) {
                  _selectedShift = shifts.first;
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildShiftDropdown() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (_selectedStore == null) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 10),
            Text('اختر المتجر أولاً', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_availableShifts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('لا توجد شفتات لهذا المتجر'),
          ],
        ),
      );
    }

    return Container(
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
              Icon(Icons.schedule_outlined, size: 20, color: Colors.grey),
              SizedBox(width: 10),
              Text('اختر الشفت'),
            ],
          ),
          items: _availableShifts.map((shift) {
            return DropdownMenuItem(
              value: shift,
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: Colors.orange),
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
    );
  }

  Widget _buildBottomBar(bool isDarkMode) {
    final canSubmit = _selectedEmployee != null &&
        _selectedStore != null &&
        _selectedShift != null;

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
              child: ElevatedButton.icon(
                onPressed: (_isLoading || !canSubmit) ? null : _registerOvertime,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.more_time),
                label: Text(_isLoading ? 'جاري التسجيل...' : 'تسجيل أوفرتايم'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerOvertime() async {
    if (_selectedEmployee == null ||
        _selectedStore == null ||
        _selectedShift == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      final success = await attendanceProvider.checkInAsOvertime(
        userId: _selectedEmployee!.id,
        userName: _selectedEmployee!.name,
        store: _selectedStore!,
        shift: _selectedShift!,
      );

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تسجيل أوفرتايم لـ ${_selectedEmployee!.name} في ${_selectedStore!.name}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              attendanceProvider.errorMessage ?? 'حدث خطأ أثناء تسجيل الأوفرتايم',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
