import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/services/admin_notification_listener.dart';
import '../../../scripts/migrate_attendance_records.dart';

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

  Future<void> _showMigrationDialog(BuildContext context) async {
    // First show preview
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sync, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('تحديث سجلات الحضور'),
          ],
        ),
        content: FutureBuilder<MigrationPreview>(
          future: MigrationService.previewMigration(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasData) {
              return Text(
                snapshot.data!.summary,
                style: const TextStyle(fontFamily: 'Cairo'),
              );
            }
            return const Text('خطأ في تحميل البيانات');
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runMigration(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('بدء التحديث', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _runMigration(BuildContext context) async {
    int current = 0;
    int total = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // Start migration
          if (current == 0 && total == 0) {
            MigrationService.migrateAttendanceRecords(
              onProgress: (c, t) {
                setState(() {
                  current = c;
                  total = t;
                });
              },
            ).then((result) {
              Navigator.pop(ctx);
              // Show result
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(
                        result.isSuccess ? Icons.check_circle : Icons.error,
                        color: result.isSuccess ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(result.isSuccess ? 'تم بنجاح' : 'حدث خطأ'),
                    ],
                  ),
                  content: Text(
                    result.summary,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _loadData(); // Refresh data
                      },
                      child: const Text('موافق'),
                    ),
                  ],
                ),
              );
            });
          }

          return AlertDialog(
            title: const Text('جاري التحديث...'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('$current / ${total > 0 ? total : "..."}'),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: current / total,
                      backgroundColor: Colors.grey[300],
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
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
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.settings, color: Colors.white),
          ),
          onSelected: (value) {
            if (value == 'migrate') {
              _showMigrationDialog(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'migrate',
              child: Row(
                children: [
                  Icon(Icons.sync, color: AppTheme.primaryColor),
                  SizedBox(width: 8),
                  Text('تحديث سجلات الحضور'),
                ],
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
      ],
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
