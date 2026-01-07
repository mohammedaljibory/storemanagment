import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({Key? key}) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  StoreModel? _selectedStore;
  ShiftModel? _selectedShift;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<StoreProvider>().fetchStores(authProvider.user!.id);
      await context.read<ShiftProvider>().fetchShifts(null);
      await context.read<EmployeeProvider>().fetchEmployees();
    }
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
              _buildFilters(context),
              const SizedBox(height: 10),
              Expanded(child: _buildEmployeeList(context)),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEmployeeDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
        backgroundColor: AppTheme.primaryColor,
      ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios),
          ),
          Expanded(
            child: Text(
              'إدارة الموظفين',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildFilters(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    final shiftProvider = context.watch<ShiftProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<StoreModel?>(
                isExpanded: true,
                value: _selectedStore,
                hint: const Text('اختر المتجر'),
                items: [
                  const DropdownMenuItem<StoreModel?>(
                    value: null,
                    child: Text('جميع المتاجر'),
                  ),
                  ...storeProvider.activeStores.map((store) {
                    return DropdownMenuItem(value: store, child: Text(store.name));
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStore = value;
                    _selectedShift = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_selectedStore != null)
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ShiftModel?>(
                  isExpanded: true,
                  value: _selectedShift,
                  hint: const Text('اختر الوردية'),
                  items: [
                    const DropdownMenuItem<ShiftModel?>(
                      value: null,
                      child: Text('جميع الشفتات'),
                    ),
                    ...shiftProvider.getShiftsByStore(_selectedStore!.id).map((shift) {
                      return DropdownMenuItem(
                        value: shift,
                        child: Text('${shift.name} (${shift.startTime} - ${shift.endTime})'),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() { _selectedShift = value; });
                  },
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
  }

  Widget _buildEmployeeList(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();

    if (employeeProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    List<UserModel> employees;
    if (_selectedStore != null && _selectedShift != null) {
      employees = employeeProvider.getEmployeesByStoreAndShift(
        _selectedStore!.id, _selectedShift!.id);
    } else if (_selectedStore != null) {
      employees = employeeProvider.getEmployeesByStore(_selectedStore!.id);
    } else {
      employees = employeeProvider.activeEmployees;
    }

    if (employees.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 20),
            Text('لا يوجد موظفين',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: employees.length,
        itemBuilder: (context, index) => _buildEmployeeCard(context, employees[index], index),
      ),
    );
  }

  Widget _buildEmployeeCard(BuildContext context, UserModel employee, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final storeProvider = context.read<StoreProvider>();

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.employeeDetail, arguments: employee.id);
        },
        onLongPress: () => _showEmployeeOptionsMenu(context, employee),
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
              backgroundImage: employee.photoUrl != null ? NetworkImage(employee.photoUrl!) : null,
              child: employee.photoUrl == null
                  ? Text(employee.name.isNotEmpty ? employee.name[0] : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(employee.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      // Free employee badge
                      if (employee.isFreeEmployee)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.gps_fixed, size: 12, color: AppTheme.secondaryColor),
                              const SizedBox(width: 4),
                              Text('حر',
                                style: TextStyle(fontSize: 10, color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // For free employees, show "no store" message
                  if (employee.isFreeEmployee)
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed, size: 14, color: AppTheme.secondaryColor),
                        const SizedBox(width: 4),
                        Text('موظف حر - تتبع GPS',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryColor)),
                      ],
                    )
                  else if (employee.storeName != null)
                    Row(
                      children: [
                        const Icon(Icons.store, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(employee.storeName!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                            overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  if (!employee.isFreeEmployee && employee.shiftName != null)
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(employee.shiftName!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryColor)),
                      ],
                    ),
                  // Show authorized stores count
                  if (employee.authorizedStoreIds.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.storefront, size: 14, color: AppTheme.secondaryColor),
                        const SizedBox(width: 4),
                        Text('${employee.authorizedStoreIds.length} متجر إضافي',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryColor)),
                      ],
                    ),
                  // Show days off
                  if (employee.daysOffPerMonth > 0)
                    Row(
                      children: [
                        const Icon(Icons.event_busy, size: 14, color: AppTheme.warningColor),
                        const SizedBox(width: 4),
                        Text('${employee.daysOffPerMonth} أيام إجازة/شهر',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor)),
                      ],
                    ),
                  // Show vacation balance
                  if (employee.allowedVacationDays > 0)
                    Row(
                      children: [
                        const Icon(Icons.beach_access, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text('رصيد الإجازات: ${employee.remainingVacationDays}/${employee.allowedVacationDays}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primaryColor)),
                      ],
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: isDarkMode ? Colors.white54 : Colors.black38),
              onSelected: (value) {
                if (value == 'authorized_stores') {
                  _showAuthorizedStoresDialog(context, employee, storeProvider);
                } else if (value == 'details') {
                  Navigator.pushNamed(context, AppRoutes.employeeDetail, arguments: employee.id);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20),
                      SizedBox(width: 8),
                      Text('التفاصيل'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'authorized_stores',
                  child: Row(
                    children: [
                      Icon(Icons.storefront, size: 20, color: AppTheme.secondaryColor),
                      SizedBox(width: 8),
                      Text('المتاجر المصرح بها'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  void _showEmployeeOptionsMenu(BuildContext context, UserModel employee) {
    final storeProvider = context.read<StoreProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              employee.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('التفاصيل'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.employeeDetail, arguments: employee.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront, color: AppTheme.secondaryColor),
              title: const Text('إدارة المتاجر المصرح بها'),
              subtitle: Text(
                employee.authorizedStoreIds.isEmpty
                    ? 'لم يتم تحديد متاجر إضافية'
                    : '${employee.authorizedStoreIds.length} متجر إضافي',
              ),
              onTap: () {
                Navigator.pop(context);
                _showAuthorizedStoresDialog(context, employee, storeProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthorizedStoresDialog(BuildContext context, UserModel employee, StoreProvider storeProvider) {
    final employeeProvider = context.read<EmployeeProvider>();
    List<String> selectedStoreIds = [...employee.authorizedStoreIds];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final allStores = storeProvider.activeStores;
          // Filter out the primary store
          final availableStores = allStores.where((s) => s.id != employee.storeId).toList();

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.storefront, color: AppTheme.secondaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('المتاجر المصرح بها'),
                      Text(
                        employee.name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Primary store info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.store, color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'المتجر الأساسي',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                employee.storeName ?? 'غير محدد',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'اختر المتاجر الإضافية المصرح بها:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (availableStores.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'لا توجد متاجر أخرى متاحة',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableStores.length,
                        itemBuilder: (context, index) {
                          final store = availableStores[index];
                          final isSelected = selectedStoreIds.contains(store.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedStoreIds.add(store.id);
                                } else {
                                  selectedStoreIds.remove(store.id);
                                }
                              });
                            },
                            title: Text(store.name),
                            subtitle: Text(store.address, style: const TextStyle(fontSize: 12)),
                            secondary: const Icon(Icons.store_outlined),
                            activeColor: AppTheme.secondaryColor,
                          );
                        },
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
                onPressed: () async {
                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const Center(child: CircularProgressIndicator()),
                  );

                  final success = await employeeProvider.updateAuthorizedStores(
                    employeeId: employee.id,
                    authorizedStoreIds: selectedStoreIds,
                  );

                  // Close loading
                  Navigator.pop(context);
                  // Close dialog
                  Navigator.pop(context);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تحديث المتاجر المصرح بها'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(employeeProvider.errorMessage ?? 'فشل في التحديث'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddEmployeeDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final daysOffController = TextEditingController(text: '0');
    final vacationDaysController = TextEditingController(text: '0');
    StoreModel? selectedStore;
    ShiftModel? selectedShift;
    bool isFreeEmployee = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final storeProvider = context.read<StoreProvider>();
          final shiftProvider = context.read<ShiftProvider>();

          return AlertDialog(
            title: const Text('إضافة موظف جديد'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'الاسم',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم الهاتف',
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Free Employee Toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFreeEmployee
                          ? AppTheme.secondaryColor.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFreeEmployee
                            ? AppTheme.secondaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          color: isFreeEmployee ? AppTheme.secondaryColor : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'موظف حر',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isFreeEmployee ? AppTheme.secondaryColor : Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                'بدون متجر أو وردية - تتبع GPS كامل',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: isFreeEmployee,
                          onChanged: (value) {
                            setDialogState(() {
                              isFreeEmployee = value;
                              if (value) {
                                selectedStore = null;
                                selectedShift = null;
                              }
                            });
                          },
                          activeColor: AppTheme.secondaryColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: daysOffController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'أيام الإجازة شهرياً',
                      prefixIcon: Icon(Icons.event_busy),
                      hintText: '0',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: vacationDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رصيد الإجازات السنوية',
                      prefixIcon: Icon(Icons.beach_access),
                      hintText: '0',
                      helperText: 'عدد أيام الإجازة المسموحة سنوياً',
                    ),
                  ),
                  // Show store/shift selection only for regular employees
                  if (!isFreeEmployee) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StoreModel>(
                      value: selectedStore,
                      decoration: const InputDecoration(
                        labelText: 'المتجر',
                        prefixIcon: Icon(Icons.store),
                      ),
                      items: storeProvider.activeStores.map((store) {
                        return DropdownMenuItem(value: store, child: Text(store.name));
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStore = value;
                          selectedShift = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedStore != null)
                      DropdownButtonFormField<ShiftModel>(
                        value: selectedShift,
                        decoration: const InputDecoration(
                          labelText: 'الوردية',
                          prefixIcon: Icon(Icons.schedule),
                        ),
                        items: shiftProvider.getShiftsByStore(selectedStore!.id).map((shift) {
                          return DropdownMenuItem(value: shift, child: Text(shift.name));
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() { selectedShift = value; });
                        },
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Validation
                  final bool isValid;
                  if (isFreeEmployee) {
                    isValid = nameController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        passwordController.text.isNotEmpty;
                  } else {
                    isValid = nameController.text.isNotEmpty &&
                        emailController.text.isNotEmpty &&
                        passwordController.text.isNotEmpty &&
                        selectedStore != null &&
                        selectedShift != null;
                  }

                  if (isValid) {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(child: CircularProgressIndicator()),
                    );

                    // Create employee in Auth + Firestore using AuthProvider
                    final authProvider = context.read<AuthProvider>();
                    final success = await authProvider.createEmployee(
                      name: nameController.text,
                      email: emailController.text,
                      phone: phoneController.text.isNotEmpty ? phoneController.text : '',
                      password: passwordController.text,
                      storeId: isFreeEmployee ? null : selectedStore!.id,
                      storeName: isFreeEmployee ? null : selectedStore!.name,
                      shiftId: isFreeEmployee ? null : selectedShift!.id,
                      shiftName: isFreeEmployee ? null : selectedShift!.name,
                      daysOffPerMonth: int.tryParse(daysOffController.text) ?? 0,
                      allowedVacationDays: int.tryParse(vacationDaysController.text) ?? 0,
                      employeeType: isFreeEmployee ? EmployeeType.free : EmployeeType.regular,
                    );

                    // Close loading
                    Navigator.pop(context);

                    if (success) {
                      // Refresh employee list
                      await context.read<EmployeeProvider>().fetchEmployees();
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFreeEmployee
                              ? 'تم إضافة الموظف الحر بنجاح'
                              : 'تم إضافة الموظف بنجاح'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(authProvider.errorMessage ?? 'فشل في إضافة الموظف'),
                          backgroundColor: AppTheme.errorColor,
                        ),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى ملء جميع الحقول المطلوبة'),
                        backgroundColor: AppTheme.warningColor,
                      ),
                    );
                  }
                },
                child: const Text('إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }
}
