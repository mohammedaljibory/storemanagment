import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/models/request_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../widgets/attendance_calendar_widget.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeDetailScreen({Key? key, required this.employeeId})
      : super(key: key);

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await context
        .read<EmployeeProvider>()
        .fetchEmployeeDashboard(widget.employeeId);
    // Also fetch requests for vacation data
    await context
        .read<RequestProvider>()
        .fetchEmployeeRequests(widget.employeeId);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final employeeProvider = context.watch<EmployeeProvider>();
    final employee = employeeProvider.getEmployeeById(widget.employeeId);

    if (employee == null) {
      return Scaffold(
        body: Center(child: Text('الموظف غير موجود')),
      );
    }

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
              // Header with employee info
              _buildHeader(context, employee),

              // Stats Cards
              _buildStatsCards(context, employeeProvider.employeeStats),

              // Tab Bar
              _buildTabBar(context),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTasksTab(context, employeeProvider.employeeTasks),
                    _buildAttendanceTab(
                        context, employeeProvider.employeeAttendance),
                    _buildStatsTab(context, employeeProvider.employeeStats),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserModel employee) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    // Edit employee
                  } else if (value == 'deactivate') {
                    _showDeactivateConfirmation(context, employee);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text('تعطيل', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 45,
            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
            backgroundImage:
                employee.photoUrl != null ? NetworkImage(employee.photoUrl!) : null,
            child: employee.photoUrl == null
                ? Text(
                    employee.name.isNotEmpty ? employee.name[0] : '?',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 15),
          Text(
            employee.name,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (employee.storeName != null) ...[
                Icon(Icons.store, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  employee.storeName!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(width: 16),
              ],
              if (employee.shiftName != null) ...[
                Icon(Icons.schedule, size: 16, color: AppTheme.secondaryColor),
                const SizedBox(width: 4),
                Text(
                  employee.shiftName!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.secondaryColor,
                      ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
      BuildContext context, Map<String, dynamic> stats) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildStatCard(
            context,
            title: 'المهام المكتملة',
            value: '${stats['completedTasks'] ?? 0}/${stats['totalTasks'] ?? 0}',
            icon: Icons.task_alt,
            color: AppTheme.successColor,
          ),
          _buildStatCard(
            context,
            title: 'نسبة الإنجاز',
            value: '${(stats['completionRate'] ?? 0).toStringAsFixed(0)}%',
            icon: Icons.trending_up,
            color: AppTheme.primaryColor,
          ),
          _buildStatCard(
            context,
            title: 'نسبة الالتزام',
            value: '${(stats['complianceRate'] ?? 0).toStringAsFixed(0)}%',
            icon: Icons.access_time,
            color: AppTheme.secondaryColor,
          ),
          _buildStatCard(
            context,
            title: 'أيام التأخير',
            value: '${stats['lateDays'] ?? 0}',
            icon: Icons.warning,
            color: AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? AppTheme.secondaryGradient
                : AppTheme.primaryGradient,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.black54,
        tabs: const [
          Tab(text: 'المهام'),
          Tab(text: 'الحضور'),
          Tab(text: 'الإحصائيات'),
        ],
      ),
    );
  }

  Widget _buildTasksTab(BuildContext context, List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task_outlined, size: 60, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('لا توجد مهام', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(context, task, index);
      },
    );
  }

  Widget _buildTaskCard(BuildContext context, TaskModel task, int index) {
    Color statusColor;
    switch (task.status) {
      case TaskStatus.completed:
        statusColor = AppTheme.successColor;
        break;
      case TaskStatus.inProgress:
        statusColor = AppTheme.secondaryColor;
        break;
      case TaskStatus.failed:
        statusColor = AppTheme.errorColor;
        break;
      default:
        statusColor = AppTheme.warningColor;
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 60,
            decoration: BoxDecoration(
              color: task.isOverdue ? AppTheme.errorColor : statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        task.statusText,
                        style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.timeRemainingText,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.timer, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      task.maxDurationText,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab(
      BuildContext context, List<AttendanceModel> attendance) {
    final requestProvider = context.watch<RequestProvider>();
    final vacationRequests = requestProvider.getApprovedVacations(widget.employeeId);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attendance Calendar
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'تقويم الحضور',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AttendanceCalendarWidget(
                  attendanceRecords: attendance,
                  vacationRequests: vacationRequests,
                  onDaySelected: (date) {
                    // Find record for selected day and show details
                    final record = attendance.where((r) =>
                      r.checkIn.year == date.year &&
                      r.checkIn.month == date.month &&
                      r.checkIn.day == date.day
                    ).firstOrNull;

                    if (record != null) {
                      _showAttendanceDetails(context, record);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Recent Attendance Records
          if (attendance.isNotEmpty) ...[
            Text(
              'سجلات الحضور',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...attendance.take(10).toList().asMap().entries.map((entry) {
              return _buildAttendanceCard(context, entry.value, entry.key);
            }),
          ] else
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Icon(Icons.calendar_today_outlined,
                      size: 60, color: Colors.grey.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Text('لا توجد سجلات حضور', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showAttendanceDetails(BuildContext context, AttendanceModel record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              record.dateString,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('الدخول', record.formattedCheckIn, record.expectedStartTime, record.isLate),
            _buildDetailRow('الخروج', record.formattedCheckOut ?? '--:--', record.expectedEndTime, record.isEarlyLeave),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إجمالي الساعات', style: TextStyle(color: Colors.grey)),
                Text(
                  record.formattedTotalHours,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الحالة', style: TextStyle(color: Colors.grey)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: record.isCompliant
                        ? AppTheme.successColor.withOpacity(0.2)
                        : AppTheme.errorColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.complianceStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: record.isCompliant ? AppTheme.successColor : AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String actual, String expected, bool isIssue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                actual,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isIssue ? AppTheme.errorColor : null,
                ),
              ),
              Text(
                'المتوقع: $expected',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(
      BuildContext context, AttendanceModel record, int index) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                record.dateString,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: record.isCompliant
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.errorColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  record.complianceStatus,
                  style: TextStyle(
                    fontSize: 10,
                    color: record.isCompliant
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  context,
                  label: 'الدخول',
                  time: record.formattedCheckIn,
                  expected: record.expectedStartTime,
                  isLate: record.isLate,
                ),
              ),
              Expanded(
                child: _buildTimeInfo(
                  context,
                  label: 'الخروج',
                  time: record.formattedCheckOut ?? '--:--',
                  expected: record.expectedEndTime,
                  isLate: record.isEarlyLeave,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('الإجمالي',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      record.formattedTotalHours,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(
    BuildContext context, {
    required String label,
    required String time,
    required String expected,
    required bool isLate,
  }) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isLate ? AppTheme.errorColor : null,
          ),
        ),
        Text(
          'المتوقع: $expected',
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildStatsTab(BuildContext context, Map<String, dynamic> stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatsSection(
            context,
            title: 'إحصائيات المهام',
            icon: Icons.task_alt,
            items: [
              {'label': 'إجمالي المهام', 'value': '${stats['totalTasks'] ?? 0}'},
              {'label': 'المكتملة', 'value': '${stats['completedTasks'] ?? 0}'},
              {'label': 'الفاشلة', 'value': '${stats['failedTasks'] ?? 0}'},
              {'label': 'المعلقة', 'value': '${stats['pendingTasks'] ?? 0}'},
              {
                'label': 'نسبة الإنجاز',
                'value': '${(stats['completionRate'] ?? 0).toStringAsFixed(1)}%'
              },
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsSection(
            context,
            title: 'إحصائيات الحضور',
            icon: Icons.access_time,
            items: [
              {'label': 'إجمالي أيام العمل', 'value': '${stats['totalWorkDays'] ?? stats['totalDays'] ?? 0}'},
              {'label': 'أيام الحضور في الوقت', 'value': '${stats['onTimeDays'] ?? 0}'},
              {'label': 'أيام التأخير', 'value': '${stats['lateDays'] ?? 0}'},
              {'label': 'أيام الخروج المبكر', 'value': '${stats['earlyLeaveDays'] ?? 0}'},
              {
                'label': 'نسبة الالتزام',
                'value': '${(stats['complianceRate'] ?? 0).toStringAsFixed(1)}%'
              },
              {
                'label': 'ساعات العمل هذا الشهر',
                'value': '${(stats['totalHours'] ?? stats['totalHoursThisMonth'] ?? 0).toStringAsFixed(1)}'
              },
              {
                'label': 'متوسط الساعات اليومي',
                'value': '${(stats['averageHours'] ?? 0).toStringAsFixed(1)}'
              },
            ],
          ),
          const SizedBox(height: 20),
          _buildStatsSection(
            context,
            title: 'الإجازات والخصومات',
            icon: Icons.event_busy,
            items: [
              {'label': 'أيام الإجازات هذا الشهر', 'value': '${stats['vacationDays'] ?? 0}'},
              {'label': 'إجمالي دقائق التأخير', 'value': '${stats['totalLateMinutes'] ?? 0}'},
              {'label': 'إجمالي دقائق الخروج المبكر', 'value': '${stats['totalEarlyLeaveMinutes'] ?? 0}'},
              {'label': 'إجمالي دقائق الخصم', 'value': '${stats['totalPenaltyMinutes'] ?? 0}'},
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Map<String, String>> items,
  }) {
    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label']!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  Text(
                    item['value']!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  void _showDeactivateConfirmation(BuildContext context, UserModel employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل الموظف'),
        content: Text('هل أنت متأكد من تعطيل "${employee.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<EmployeeProvider>()
                  .deactivateEmployee(employee.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );
  }
}
