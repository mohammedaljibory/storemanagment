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

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, AppRoutes.employeeDetail, arguments: employee.id);
        },
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
                  Text(employee.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  if (employee.storeName != null)
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
                  if (employee.shiftName != null)
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(employee.shiftName!,
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
            Icon(Icons.arrow_forward_ios, size: 18, color: isDarkMode ? Colors.white30 : Colors.black26),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
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
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty &&
                      emailController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty &&
                      selectedStore != null &&
                      selectedShift != null) {
                    
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
                      storeId: selectedStore!.id,
                      storeName: selectedStore!.name,
                      shiftId: selectedShift!.id,
                      shiftName: selectedShift!.name,
                      daysOffPerMonth: int.tryParse(daysOffController.text) ?? 0,
                      allowedVacationDays: int.tryParse(vacationDaysController.text) ?? 0,
                    );

                    // Close loading
                    Navigator.pop(context);

                    if (success) {
                      // Refresh employee list
                      await context.read<EmployeeProvider>().fetchEmployees();
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم إضافة الموظف بنجاح'),
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
