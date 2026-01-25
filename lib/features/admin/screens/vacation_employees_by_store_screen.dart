import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class VacationEmployeesByStoreScreen extends StatefulWidget {
  const VacationEmployeesByStoreScreen({Key? key}) : super(key: key);

  @override
  State<VacationEmployeesByStoreScreen> createState() => _VacationEmployeesByStoreScreenState();
}

class _VacationEmployeesByStoreScreenState extends State<VacationEmployeesByStoreScreen> {
  String? _expandedStoreId;

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
                child: _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموظفون في إجازة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'حسب المتجر',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade700]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.beach_access, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    final requestProvider = context.watch<RequestProvider>();
    final stores = storeProvider.activeStores;

    // Get today's vacations
    final todayVacations = requestProvider.todayVacations;

    // Group vacations by store
    final Map<String, List<RequestModel>> vacationsByStore = {};
    for (var vacation in todayVacations) {
      vacationsByStore.putIfAbsent(vacation.storeId, () => []);
      vacationsByStore[vacation.storeId]!.add(vacation);
    }

    // Calculate total on vacation
    final totalOnVacation = todayVacations.length;

    return Column(
      children: [
        // Summary Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.beach_access,
                    color: Colors.orange,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي المجازين اليوم',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '$totalOnVacation موظف',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Text(
                      '${vacationsByStore.length}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    Text(
                      'متجر',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Stores List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: stores.length,
            itemBuilder: (context, index) {
              final store = stores[index];
              final storeVacations = vacationsByStore[store.id] ?? [];
              return _buildStoreCard(context, store, storeVacations, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStoreCard(BuildContext context, StoreModel store, List<RequestModel> vacations, int index) {
    final isExpanded = _expandedStoreId == store.id;
    final vacationCount = vacations.length;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Store Header
            InkWell(
              onTap: () {
                setState(() {
                  _expandedStoreId = isExpanded ? null : store.id;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: vacationCount > 0
                            ? LinearGradient(colors: [Colors.orange.shade400, Colors.orange.shade700])
                            : null,
                        color: vacationCount > 0 ? null : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.store,
                        color: vacationCount > 0 ? Colors.white : Colors.grey,
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
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  store.address,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: vacationCount > 0
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (vacationCount > 0)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 5),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            '$vacationCount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: vacationCount > 0 ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded Employee List
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildVacationList(context, vacations),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacationList(BuildContext context, List<RequestModel> vacations) {
    if (vacations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 40,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'لا يوجد موظفون في إجازة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Divider(height: 1),
          ...vacations.map((vacation) => _buildVacationItem(context, vacation)).toList(),
        ],
      ),
    );
  }

  Widget _buildVacationItem(BuildContext context, RequestModel vacation) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: Text(
                  vacation.employeeName.isNotEmpty
                      ? vacation.employeeName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.beach_access,
                    size: 6,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          // Employee Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vacation.employeeName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.event_note,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vacation.reason ?? 'إجازة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
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
          // Duration / Assign Substitute Button
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vacation.isMultiDay)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(left: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'حتى ${vacation.endDate!.day}/${vacation.endDate!.month}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () => _showAssignSubstituteDialog(context, vacation),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.swap_horiz,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                tooltip: 'تعيين بديل',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show dialog to assign a substitute employee for the absent employee
  void _showAssignSubstituteDialog(BuildContext context, RequestModel vacation) async {
    final employeeProvider = context.read<EmployeeProvider>();
    final storeProvider = context.read<StoreProvider>();
    final shiftProvider = context.read<ShiftProvider>();

    // Get available employees (exclude the one on vacation)
    final availableEmployees = employeeProvider.activeEmployees
        .where((e) => e.id != vacation.employeeId)
        .toList();

    if (availableEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد موظفين متاحين للتعيين كبديل'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    UserModel? selectedSubstitute;
    StoreModel? selectedStore;
    ShiftModel? selectedShift;

    // Get the store for this vacation
    final vacationStore = storeProvider.stores.firstWhere(
      (s) => s.id == vacation.storeId,
      orElse: () => storeProvider.stores.first,
    );
    selectedStore = vacationStore;

    // Fetch shifts for the store if not loaded yet
    List<ShiftModel> availableShifts = shiftProvider.getShiftsByStore(selectedStore.id);
    if (availableShifts.isEmpty) {
      await shiftProvider.fetchShifts(selectedStore.id);
      availableShifts = shiftProvider.getShiftsByStore(selectedStore.id);
    }
    if (availableShifts.isNotEmpty) {
      selectedShift = availableShifts.first;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تعيين موظف بديل',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Absent employee info
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_off, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الموظف الغائب',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            Text(
                              vacation.employeeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              vacation.storeName,
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
                const SizedBox(height: 20),

                // Select substitute employee
                const Text(
                  'اختر الموظف البديل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<UserModel>(
                  value: selectedSubstitute,
                  decoration: InputDecoration(
                    hintText: 'اختر موظف',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: availableEmployees.map((e) {
                    return DropdownMenuItem<UserModel>(
                      value: e,
                      child: Text(e.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedSubstitute = value);
                  },
                ),
                const SizedBox(height: 16),

                // Select store
                const Text(
                  'المتجر',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<StoreModel>(
                  value: selectedStore,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: storeProvider.activeStores.map((s) {
                    return DropdownMenuItem<StoreModel>(
                      value: s,
                      child: Text(s.name),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    setDialogState(() {
                      selectedStore = value;
                      selectedShift = null;
                    });
                    if (value != null) {
                      // Fetch shifts if not loaded
                      var shifts = shiftProvider.getShiftsByStore(value.id);
                      if (shifts.isEmpty) {
                        await shiftProvider.fetchShifts(value.id);
                        shifts = shiftProvider.getShiftsByStore(value.id);
                      }
                      setDialogState(() {
                        availableShifts = shifts;
                        selectedShift = shifts.isNotEmpty ? shifts.first : null;
                      });
                    } else {
                      setDialogState(() {
                        availableShifts = [];
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Select shift
                const Text(
                  'الشفت',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ShiftModel>(
                  value: selectedShift,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: availableShifts.map((s) {
                    return DropdownMenuItem<ShiftModel>(
                      value: s,
                      child: Text('${s.name} (${s.startTime} - ${s.endTime})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedShift = value);
                  },
                ),
                const SizedBox(height: 16),

                // Info message
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم احتساب ساعات العمل كـ "أوفر تايم" للموظف البديل',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: selectedSubstitute != null && selectedStore != null && selectedShift != null
                  ? () async {
                      Navigator.pop(ctx);
                      await _assignSubstitute(
                        context,
                        substituteEmployee: selectedSubstitute!,
                        store: selectedStore!,
                        shift: selectedShift!,
                        absentEmployeeId: vacation.employeeId,
                        absentEmployeeName: vacation.employeeName,
                      );
                    }
                  : null,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('تعيين البديل'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignSubstitute(
    BuildContext context, {
    required UserModel substituteEmployee,
    required StoreModel store,
    required ShiftModel shift,
    required String absentEmployeeId,
    required String absentEmployeeName,
  }) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final attendanceProvider = context.read<AttendanceProvider>();
      final success = await attendanceProvider.checkInAsSubstitute(
        userId: substituteEmployee.id,
        userName: substituteEmployee.name,
        store: store,
        shift: shift,
        substituteForUserId: absentEmployeeId,
        substituteForUserName: absentEmployeeName,
      );

      Navigator.pop(context); // Close loading

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تعيين ${substituteEmployee.name} كبديل عن $absentEmployeeName'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(attendanceProvider.errorMessage ?? 'حدث خطأ أثناء تعيين البديل'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}
