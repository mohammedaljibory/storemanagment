import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/models/attendance_model.dart';
import '../../../core/models/request_model.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        context.read<AttendanceProvider>().fetchAttendanceHistory(authProvider.user!.id);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                    Text(
                      'سجل الحضور',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _showMonthPicker(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_month),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),

              // Month Indicator
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDarkMode
                        ? AppTheme.secondaryGradient
                        : AppTheme.primaryGradient,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getMonthName(_selectedMonth) + ' $_selectedYear',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 600.ms),

              const SizedBox(height: 20),

              // Stats Cards
              Consumer2<AttendanceProvider, RequestProvider>(
                builder: (context, attendanceProvider, requestProvider, _) {
                  final stats = attendanceProvider.getMonthlyStats(_selectedYear, _selectedMonth);
                  final authProvider = context.read<AuthProvider>();
                  final userId = authProvider.user?.id ?? '';
                  final dayOffs = requestProvider.getApprovedDayOffsForMonth(userId, _selectedYear, _selectedMonth);

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'أيام العمل',
                            '${stats['totalDays']}',
                            Icons.calendar_today,
                            AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'الإجازات',
                            '${dayOffs.length}',
                            Icons.event_busy,
                            AppTheme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            'الساعات',
                            '${stats['totalHours'].toStringAsFixed(1)}',
                            Icons.access_time,
                            AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms);
                },
              ),

              const SizedBox(height: 20),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.5),
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
                    Tab(text: 'السجل'),
                    Tab(text: 'الإحصائيات'),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

              const SizedBox(height: 20),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHistoryTab(),
                    _buildStatsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';

    return Consumer2<AttendanceProvider, RequestProvider>(
      builder: (context, attendanceProvider, requestProvider, _) {
        if (attendanceProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final monthAttendance = attendanceProvider.getAttendanceForMonth(_selectedYear, _selectedMonth);
        final dayOffs = requestProvider.getApprovedDayOffsForMonth(userId, _selectedYear, _selectedMonth);

        // Combine attendance and day offs into a list of records sorted by date
        final List<dynamic> combinedRecords = [
          ...monthAttendance.map((a) => {'type': 'attendance', 'data': a, 'date': a.checkIn}),
          ...dayOffs.map((d) => {'type': 'dayOff', 'data': d, 'date': d.targetDate}),
        ];

        // Sort by date descending
        combinedRecords.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        if (combinedRecords.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                Text(
                  'لا يوجد سجل حضور لهذا الشهر',
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
          itemCount: combinedRecords.length,
          itemBuilder: (context, index) {
            final record = combinedRecords[index];
            if (record['type'] == 'dayOff') {
              return _buildDayOffCard(record['data'] as RequestModel, index);
            }
            return _buildAttendanceCard(record['data'] as AttendanceModel, index);
          },
        );
      },
    );
  }

  Widget _buildDayOffCard(RequestModel dayOff, int index) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.event_busy,
              color: AppTheme.accentColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(dayOff.targetDate),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'إجازة معتمدة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.accentColor,
                      ),
                ),
                if (dayOff.reason.isNotEmpty)
                  Text(
                    dayOff.reason,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'إجازة',
              style: TextStyle(
                color: AppTheme.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildAttendanceCard(AttendanceModel attendance, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date & Status Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(attendance).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getStatusIcon(attendance),
                  color: _getStatusColor(attendance),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(attendance.checkIn),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      attendance.shiftName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(attendance),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Time Details
          Row(
            children: [
              Expanded(
                child: _buildTimeInfo(
                  'الدخول',
                  _formatTime(attendance.checkIn),
                  attendance.expectedStartTime,
                  AppTheme.successColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
              Expanded(
                child: _buildTimeInfo(
                  'الخروج',
                  attendance.checkOut != null 
                      ? _formatTime(attendance.checkOut!)
                      : '--:--',
                  attendance.expectedEndTime,
                  AppTheme.errorColor,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
              Expanded(
                child: _buildTimeInfo(
                  'المدة',
                  attendance.totalHours != null
                      ? '${attendance.totalHours!.toStringAsFixed(1)} س'
                      : '--',
                  '',
                  AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          
          // Late/Early Leave Warning
          if (attendance.isLate || attendance.isEarlyLeave) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: AppTheme.warningColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getWarningText(attendance),
                    style: const TextStyle(
                      color: AppTheme.warningColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildTimeInfo(String label, String time, String expected, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        if (expected.isNotEmpty)
          Text(
            'المتوقع: $expected',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: Colors.grey,
                ),
          ),
      ],
    );
  }

  Widget _buildStatusBadge(AttendanceModel attendance) {
    Color color;
    String text;

    if (attendance.isLate && attendance.isEarlyLeave) {
      color = AppTheme.errorColor;
      text = 'تأخير + خروج مبكر';
    } else if (attendance.isLate) {
      color = AppTheme.warningColor;
      text = 'متأخر';
    } else if (attendance.isEarlyLeave) {
      color = AppTheme.warningColor;
      text = 'خروج مبكر';
    } else {
      color = AppTheme.successColor;
      text = 'منتظم';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceModel attendance) {
    if (attendance.isLate || attendance.isEarlyLeave) {
      return AppTheme.warningColor;
    }
    return AppTheme.successColor;
  }

  IconData _getStatusIcon(AttendanceModel attendance) {
    if (attendance.isLate) {
      return Icons.schedule;
    } else if (attendance.isEarlyLeave) {
      return Icons.exit_to_app;
    }
    return Icons.check_circle;
  }

  String _getWarningText(AttendanceModel attendance) {
    List<String> warnings = [];
    if (attendance.isLate) {
      warnings.add('تأخير ${attendance.lateMinutes} دقيقة');
    }
    if (attendance.isEarlyLeave) {
      warnings.add('خروج مبكر ${attendance.earlyLeaveMinutes} دقيقة');
    }
    return warnings.join(' • ');
  }

  Widget _buildStatsTab() {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';

    return Consumer2<AttendanceProvider, RequestProvider>(
      builder: (context, attendanceProvider, requestProvider, _) {
        final stats = attendanceProvider.getMonthlyStats(_selectedYear, _selectedMonth);
        final dayOffs = requestProvider.getApprovedDayOffsForMonth(userId, _selectedYear, _selectedMonth);
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // Attendance Summary Card
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الحضور',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatRow('إجمالي أيام العمل', '${stats['totalDays']} يوم', AppTheme.primaryColor),
                    const Divider(height: 20),
                    _buildStatRow('الأيام المنتظمة', '${stats['onTimeDays']} يوم', AppTheme.successColor),
                    const Divider(height: 20),
                    _buildStatRow('أيام الإجازات المعتمدة', '${dayOffs.length} يوم', AppTheme.accentColor),
                    const Divider(height: 20),
                    _buildStatRow('أيام التأخير', '${stats['lateDays']} يوم', AppTheme.warningColor),
                    const Divider(height: 20),
                    _buildStatRow('أيام الخروج المبكر', '${stats['earlyLeaveDays']} يوم', AppTheme.errorColor),
                  ],
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 600.ms),

              const SizedBox(height: 15),

              // Hours Summary Card
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص الساعات',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _buildStatRow(
                      'إجمالي الساعات',
                      '${stats['totalHours'].toStringAsFixed(1)} ساعة',
                      AppTheme.secondaryColor,
                    ),
                    const Divider(height: 20),
                    _buildStatRow(
                      'متوسط ساعات اليوم',
                      '${stats['averageHoursPerDay'].toStringAsFixed(1)} ساعة',
                      AppTheme.primaryColor,
                    ),
                    const Divider(height: 20),
                    _buildStatRow(
                      'إجمالي دقائق التأخير',
                      '${stats['totalLateMinutes']} دقيقة',
                      AppTheme.warningColor,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

              const SizedBox(height: 15),

              // Performance Indicator
              GlassContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معدل الانضباط',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _buildPerformanceIndicator(stats),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceIndicator(Map<String, dynamic> stats) {
    final total = stats['totalDays'] as int;
    final onTime = stats['onTimeDays'] as int;
    final percentage = total > 0 ? (onTime / total * 100) : 0.0;
    
    Color indicatorColor;
    String statusText;
    
    if (percentage >= 90) {
      indicatorColor = AppTheme.successColor;
      statusText = 'ممتاز';
    } else if (percentage >= 70) {
      indicatorColor = AppTheme.secondaryColor;
      statusText = 'جيد';
    } else if (percentage >= 50) {
      indicatorColor = AppTheme.warningColor;
      statusText = 'مقبول';
    } else {
      indicatorColor = AppTheme.errorColor;
      statusText = 'يحتاج تحسين';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              statusText,
              style: TextStyle(
                color: indicatorColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                color: indicatorColor,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 12,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$onTime يوم منتظم من أصل $total يوم',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
      ],
    );
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 25,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'اختر الشهر',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = month == _selectedMonth;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMonth = month;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(colors: AppTheme.primaryGradient)
                            : null,
                        color: isSelected ? null : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          _getMonthName(month),
                          style: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return '${days[date.weekday % 7]} ${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
