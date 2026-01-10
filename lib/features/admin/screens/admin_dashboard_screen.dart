import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/models/request_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/shift_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/services/admin_notification_listener.dart';
import '../../../core/services/fcm_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Stream<List<AttendanceModel>>? _activeAttendanceStream;
  Timer? _durationRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Start listening for admin notifications
    AdminNotificationListener.startListening();
    // Create stream once in initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _activeAttendanceStream = context.read<AttendanceProvider>().activeAttendanceStream();
      });
    });
    // Auto-refresh duration every minute
    _durationRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _durationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<StoreProvider>().fetchStores(authProvider.user!.id);
      await context.read<EmployeeProvider>().fetchEmployees();
      await context.read<TaskProvider>().fetchTasks();
      await context.read<RequestProvider>().fetchAllRequests();
      await context.read<AttendanceProvider>().fetchActiveAttendance();
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
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(context),
                  const SizedBox(height: 25),

                  // Quick Stats
                  _buildQuickStats(context),
                  const SizedBox(height: 25),

                  // Active Employees Section
                  _buildActiveEmployeesSection(context),
                  const SizedBox(height: 25),

                  // Vacation Employees Section
                  _buildVacationEmployeesSection(context),
                  const SizedBox(height: 25),

                  // Management Cards
                  _buildManagementSection(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final requestProvider = context.watch<RequestProvider>();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'لوحة التحكم',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'مرحباً ${authProvider.user?.name ?? ""}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Requests notification badge
        Stack(
          children: [
            IconButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.adminRequests);
              },
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.notifications, color: AppTheme.warningColor),
              ),
            ),
            if (requestProvider.pendingCount > 0)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${requestProvider.pendingCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        IconButton(
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.profile);
          },
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTheme.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ),
        // Debug notifications button
        IconButton(
          onPressed: () => _showFCMDebugDialog(context),
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bug_report, color: Colors.orange),
          ),
        ),
      ],
    );
  }

  void _showFCMDebugDialog(BuildContext context) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Get FCM status
    final status = await FCMService.debugFCMStatus();

    // Close loading
    Navigator.pop(context);

    // Show results
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.orange),
            SizedBox(width: 10),
            Text('حالة الإشعارات'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusRow('النظام', status['platform'] ?? 'N/A', Icons.phone_android),
              _buildStatusRow(
                'صلاحية الإشعارات',
                status['permissionGranted'] == true ? 'مفعّل' : 'غير مفعّل',
                status['permissionGranted'] == true ? Icons.check_circle : Icons.cancel,
                status['permissionGranted'] == true ? Colors.green : Colors.red,
              ),
              _buildStatusRow(
                'FCM Token',
                status['fcmTokenAvailable'] == true ? 'متوفر' : 'غير متوفر',
                status['fcmTokenAvailable'] == true ? Icons.check_circle : Icons.cancel,
                status['fcmTokenAvailable'] == true ? Colors.green : Colors.red,
              ),
              if (status['fcmToken'] != null)
                _buildStatusRow('Token', status['fcmToken'], Icons.key),
              if (status['fcmError'] != null)
                _buildStatusRow('خطأ FCM', status['fcmError'], Icons.error, Colors.red),
              if (status['platform'] == 'ios') ...[
                _buildStatusRow(
                  'APNS',
                  status['apnsConfigured'] == true ? 'مفعّل' : 'غير مفعّل',
                  status['apnsConfigured'] == true ? Icons.check_circle : Icons.cancel,
                  status['apnsConfigured'] == true ? Colors.green : Colors.red,
                ),
                if (status['apnsError'] != null)
                  _buildStatusRow('خطأ APNS', status['apnsError'], Icons.error, Colors.red),
              ],
              _buildStatusRow(
                'Tokens في Firestore',
                '${status['tokensInFirestore'] ?? 0}',
                (status['tokensInFirestore'] ?? 0) > 0 ? Icons.check_circle : Icons.cancel,
                (status['tokensInFirestore'] ?? 0) > 0 ? Colors.green : Colors.red,
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                'الحلول الممكنة:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade700),
              ),
              const SizedBox(height: 5),
              if (status['fcmTokenAvailable'] != true)
                const Text('• تأكد من تفعيل إشعارات التطبيق في إعدادات الجهاز'),
              if (status['platform'] == 'ios' && status['apnsConfigured'] != true)
                const Text('• iOS: تأكد من إعداد APNs في Firebase Console'),
              if ((status['tokensInFirestore'] ?? 0) == 0)
                const Text('• سجّل خروج وأعد تسجيل الدخول'),
              const Text('• تأكد من نشر Cloud Functions في Firebase'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Try to register token again
              final authProvider = context.read<AuthProvider>();
              if (authProvider.user != null) {
                await FCMService.registerToken(authProvider.user!.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم محاولة تسجيل Token جديد')),
                );
              }
            },
            child: const Text('إعادة تسجيل Token'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: color ?? Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    final employeeProvider = context.watch<EmployeeProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final requestProvider = context.watch<RequestProvider>();

    final stats = [
      {
        'title': 'المتاجر',
        'value': storeProvider.activeStores.length.toString(),
        'icon': Icons.store,
        'color': AppTheme.primaryColor,
      },
      {
        'title': 'الموظفين',
        'value': employeeProvider.activeEmployees.length.toString(),
        'icon': Icons.people,
        'color': AppTheme.secondaryColor,
      },
      {
        'title': 'المهام النشطة',
        'value': (taskProvider.pendingTasks.length +
                  taskProvider.inProgressTasks.length).toString(),
        'icon': Icons.task,
        'color': AppTheme.warningColor,
      },
      {
        'title': 'طلبات جديدة',
        'value': requestProvider.pendingCount.toString(),
        'icon': Icons.pending_actions,
        'color': AppTheme.accentColor,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return GlassContainer(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 20,
                ),
              ),
              Text(
                stat['value'] as String,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: stat['color'] as Color,
                ),
              ),
              Text(
                stat['title'] as String,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveEmployeesSection(BuildContext context) {
    // Use cached stream or fallback to provider's fetched data
    if (_activeAttendanceStream == null) {
      // Show data from the initial fetch while stream is being set up
      final attendanceProvider = context.watch<AttendanceProvider>();
      final activeAttendance = attendanceProvider.activeAttendance;
      return _buildActiveEmployeesContent(context, activeAttendance);
    }

    return StreamBuilder<List<AttendanceModel>>(
      stream: _activeAttendanceStream,
      builder: (context, snapshot) {
        final activeAttendance = snapshot.data ?? context.read<AttendanceProvider>().activeAttendance;
        return _buildActiveEmployeesContent(context, activeAttendance);
      },
    );
  }

  Widget _buildActiveEmployeesContent(BuildContext context, List<AttendanceModel> activeAttendance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.activeEmployeesByStore);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_pin_circle, color: AppTheme.successColor),
                ),
                const SizedBox(width: 10),
                Text(
                  'الموظفون النشطون الآن',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${activeAttendance.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        if (activeAttendance.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(30),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.person_off,
                    size: 50,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'لا يوجد موظفون نشطون حالياً',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 105,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: activeAttendance.length,
              itemBuilder: (context, index) {
                final attendance = activeAttendance[index];
                return _buildActiveEmployeeCard(context, attendance, index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildActiveEmployeeCard(BuildContext context, AttendanceModel attendance, int index) {
    final checkInTime = attendance.checkIn;
    final duration = DateTime.now().difference(checkInTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return GlassContainer(
      margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 12),
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 140,
        height: 75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.successColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    attendance.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              attendance.storeName,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time, size: 10, color: AppTheme.secondaryColor),
                    const SizedBox(width: 2),
                    Text(
                      '${hours}س ${minutes}د',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVacationEmployeesSection(BuildContext context) {
    final requestProvider = context.watch<RequestProvider>();
    final vacationEmployees = requestProvider.getEmployeesOnVacationToday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.beach_access, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 10),
              Text(
                'الموظفون في إجازة اليوم',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: vacationEmployees.isEmpty ? Colors.grey : Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${vacationEmployees.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (vacationEmployees.isEmpty)
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 40,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'لا يوجد موظفون في إجازة اليوم',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'جميع الموظفين متاحون للعمل',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: vacationEmployees.length,
              itemBuilder: (context, index) {
                final vacation = vacationEmployees[index];
                return _buildVacationEmployeeCard(context, vacation, index);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildVacationEmployeeCard(BuildContext context, RequestModel vacation, int index) {
    return GestureDetector(
      onTap: () => _showAssignSubstituteDialog(context, vacation),
      child: GlassContainer(
        margin: EdgeInsetsDirectional.only(start: index == 0 ? 0 : 12),
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 150,
          height: 75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.beach_access,
                    size: 14,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      vacation.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                vacation.storeName,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    vacation.isMultiDay
                        ? 'حتى ${vacation.endDate!.day}/${vacation.endDate!.month}'
                        : 'إجازة يوم واحد',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(
                    Icons.swap_horiz,
                    size: 14,
                    color: Colors.orange.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show dialog to assign a substitute employee for the absent employee
  void _showAssignSubstituteDialog(BuildContext context, RequestModel vacation) {
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

    // Get shifts for the store from ShiftProvider
    List<ShiftModel> availableShifts = shiftProvider.getShiftsByStore(selectedStore.id);
    if (availableShifts.isNotEmpty) {
      selectedShift = availableShifts.first;
    }

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
                  onChanged: (value) {
                    setDialogState(() {
                      selectedStore = value;
                      availableShifts = value != null ? shiftProvider.getShiftsByStore(value.id) : [];
                      selectedShift = availableShifts.isNotEmpty ? availableShifts.first : null;
                    });
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
        // Refresh data
        await _loadData();
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

  Widget _buildManagementSection(BuildContext context) {
    final requestProvider = context.watch<RequestProvider>();

    final items = [
      {
        'title': 'إدارة المتاجر',
        'subtitle': 'إضافة وتعديل المتاجر والفروع',
        'icon': Icons.store,
        'gradient': AppTheme.primaryGradient,
        'route': AppRoutes.storeManagement,
        'badge': 0,
      },
      {
        'title': 'إدارة الشفتات',
        'subtitle': 'تحديد أوقات العمل والشفتات',
        'icon': Icons.schedule,
        'gradient': AppTheme.secondaryGradient,
        'route': AppRoutes.shiftManagement,
        'badge': 0,
      },
      {
        'title': 'إدارة الموظفين',
        'subtitle': 'عرض وإدارة بيانات الموظفين',
        'icon': Icons.people,
        'gradient': [AppTheme.warningColor, AppTheme.warningColor.withOpacity(0.7)],
        'route': AppRoutes.employees,
        'badge': 0,
      },
      {
        'title': 'المهام',
        'subtitle': 'إنشاء ومتابعة المهام',
        'icon': Icons.task_alt,
        'gradient': [AppTheme.successColor, AppTheme.successColor.withOpacity(0.7)],
        'route': AppRoutes.tasks,
        'badge': 0,
      },
      {
        'title': 'المهام حسب الموظفين',
        'subtitle': 'عرض المهام مصنفة بحسب كل موظف',
        'icon': Icons.assignment_ind,
        'gradient': [Colors.teal, Colors.teal.shade300],
        'route': AppRoutes.tasksByEmployee,
        'badge': 0,
      },
      {
        'title': 'إدارة الطلبات',
        'subtitle': 'طلبات الإجازات والزمنيات',
        'icon': Icons.request_page,
        'gradient': [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.7)],
        'route': AppRoutes.adminRequests,
        'badge': requestProvider.pendingCount,
      },
      {
        'title': 'تقارير الموظفين',
        'subtitle': 'إنشاء تقارير PDF للحضور والمهام',
        'icon': Icons.picture_as_pdf,
        'gradient': [Colors.deepPurple, Colors.deepPurple.shade300],
        'route': AppRoutes.employeeReport,
        'badge': 0,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإدارة',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: _buildManagementCard(
              context,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              icon: item['icon'] as IconData,
              gradient: item['gradient'] as List<Color>,
              badge: item['badge'] as int,
              onTap: () {
                Navigator.pushNamed(context, item['route'] as String);
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManagementCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                // Badge for pending items
                if (badge > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: AppTheme.errorColor,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: isDarkMode ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
