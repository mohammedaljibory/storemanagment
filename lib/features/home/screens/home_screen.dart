import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/models/store_model.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/routes/app_routes.dart' show AppRoutes;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../requests/screens/requests_screen.dart';
import '../../attendance/widgets/break_button_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    
    // NEW: Added RequestsScreen to the list
    _screens = [
      const DashboardTab(),
      const TasksScreen(),
      const AttendanceScreen(),
      const RequestsScreen(),  // NEW: Requests tab
      const ProfileScreen(),
    ];
    
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.user != null) {
        context.read<AttendanceProvider>().fetchAttendanceHistory(authProvider.user!.id);
        context.read<RequestProvider>().fetchEmployeeRequests(authProvider.user!.id); // NEW

        final taskProvider = context.read<TaskProvider>();
        if (authProvider.isAdmin) {
          taskProvider.fetchTasks(isAdmin: true);
        } else {
          taskProvider.fetchTasks(userId: authProvider.user!.id, isAdmin: false);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: (isDarkMode ? AppTheme.secondaryColor : AppTheme.primaryColor)
                  .withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed, // NEW: Required for 5 items
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.task_alt),
              label: 'المهام',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_time),
              label: 'الحضور',
            ),
            // NEW: Requests tab
            BottomNavigationBarItem(
              icon: Icon(Icons.request_page),
              label: 'الطلبات',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'الملف',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardTab extends StatefulWidget {
  const DashboardTab({Key? key}) : super(key: key);

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        context.read<StoreProvider>().fetchStores(authProvider.user!.id);
        context.read<ShiftProvider>().fetchAllShifts();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final attendanceProvider = Provider.of<AttendanceProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final shiftProvider = Provider.of<ShiftProvider>(context);
    final requestProvider = Provider.of<RequestProvider>(context); // NEW
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final user = authProvider.user;

    return Container(
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرحباً،',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      Text(
                        user?.name ?? 'المستخدم',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          themeProvider.toggleTheme();
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            key: ValueKey(isDarkMode),
                            color: isDarkMode ? Colors.yellow : Colors.indigo,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: Stack(
                          children: [
                            const Icon(Icons.notifications_outlined),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .slideX(begin: -0.2, end: 0),
              
              const SizedBox(height: 20),

              // Shift Info Card
              if (user != null) ...[
                GlassContainer(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppTheme.secondaryGradient,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.store,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.storeName ?? 'لم يتم تحديد متجر',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: isDarkMode ? Colors.white54 : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  user.effectiveShiftName ?? user.shiftName ?? 'لم يتم تحديد شفت',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: isDarkMode ? Colors.white54 : Colors.black54,
                                      ),
                                ),
                                // Show if temporary shift
                                if (user.hasActiveTemporaryShift) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warningColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'مؤقت',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.warningColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ).animate()
                    .fadeIn(delay: 100.ms, duration: 600.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: 15),
              ],

              // Check In/Out Card
              _buildCheckInCard(
                context,
                attendanceProvider,
                authProvider,
                storeProvider,
                shiftProvider,
                isDarkMode,
              ).animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 25),
              
              // Today's Status
              if (attendanceProvider.isCheckedIn && attendanceProvider.currentSession != null) ...[
                _buildTodayStatus(context, attendanceProvider, isDarkMode)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 600.ms),
                const SizedBox(height: 15),

                // Break Button - shows during active attendance
                if (user != null)
                  BreakButtonWidget(
                    attendance: attendanceProvider.currentSession!,
                    userId: user.id,
                    userName: user.name,
                  ).animate()
                      .fadeIn(delay: 350.ms, duration: 600.ms),
                const SizedBox(height: 25),
              ],
              
              // Quick Stats
              Text(
                'إحصائيات سريعة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate()
                  .fadeIn(delay: 400.ms, duration: 600.ms),
              
              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'المهام النشطة',
                      '${taskProvider.pendingTasks.length + taskProvider.inProgressTasks.length}',
                      Icons.task,
                      AppTheme.primaryColor,
                      delay: 500.ms,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'المهام المكتملة',
                      '${taskProvider.completedTasks.length}',
                      Icons.check_circle,
                      AppTheme.successColor,
                      delay: 600.ms,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // Monthly attendance stats
              Consumer<AttendanceProvider>(
                builder: (context, provider, _) {
                  final now = DateTime.now();
                  final stats = provider.getMonthlyStats(now.year, now.month);
                  
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'أيام الحضور',
                          '${stats['totalDays']}',
                          Icons.calendar_today,
                          AppTheme.secondaryColor,
                          delay: 700.ms,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          'أيام التأخير',
                          '${stats['lateDays']}',
                          Icons.schedule,
                          AppTheme.warningColor,
                          delay: 800.ms,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              const SizedBox(height: 25),

              // NEW: Quick Actions Section
              Text(
                'إجراءات سريعة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate()
                  .fadeIn(delay: 850.ms, duration: 600.ms),
              
              const SizedBox(height: 15),

              // NEW: Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      'طلب إجازة',
                      Icons.event_busy,
                      AppTheme.accentColor,
                      onTap: () {
                        // Navigate to requests tab (index 3)
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        if (homeState != null) {
                          homeState.setState(() {
                            homeState._currentIndex = 3;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildQuickActionCard(
                      context,
                      'طلب زمنية',
                      Icons.timer_outlined,
                      AppTheme.primaryColor,
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        if (homeState != null) {
                          homeState.setState(() {
                            homeState._currentIndex = 3;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ).animate()
                  .fadeIn(delay: 900.ms, duration: 600.ms),

              const SizedBox(height: 25),
              
              // Today's Tasks
              Text(
                'مهام اليوم',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate()
                  .fadeIn(delay: 950.ms, duration: 600.ms),
              
              const SizedBox(height: 15),
              
              _buildTodayTasks(context, taskProvider, isDarkMode),
            ],
          ),
        ),
      ),
    );
  }

  // NEW: Quick Action Card Widget
  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    {required VoidCallback onTap}
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GlassContainer(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInCard(
    BuildContext context,
    AttendanceProvider attendanceProvider,
    AuthProvider authProvider,
    StoreProvider storeProvider,
    ShiftProvider shiftProvider,
    bool isDarkMode,
  ) {
    final user = authProvider.user;
    final isCheckedIn = attendanceProvider.isCheckedIn;

    return AnimatedGlassCard(
      onTap: attendanceProvider.isLoading
          ? null
          : () async {
              if (user == null) return;

              if (isCheckedIn) {
                // Check Out - validate location at store
                final currentSession = attendanceProvider.currentSession;
                StoreModel? checkoutStore;
                if (currentSession != null) {
                  checkoutStore = storeProvider.getStoreById(currentSession.storeId);
                  if (checkoutStore == null) {
                    checkoutStore = await storeProvider.fetchStoreById(currentSession.storeId);
                  }
                }

                final success = await attendanceProvider.checkOut(store: checkoutStore);
                if (!success && context.mounted) {
                  _showErrorDialog(context, attendanceProvider.errorMessage ?? 'حدث خطأ');
                } else if (success && context.mounted) {
                  _showSuccessSnackbar(context, 'تم تسجيل الخروج بنجاح');
                }
              } else {
                // Check In with validation
                // Use effective shift (considers temporary shift)
                final effectiveShiftId = user.effectiveShiftId ?? user.shiftId;
                
                var store = storeProvider.getStoreById(user.storeId ?? '');
                var shift = shiftProvider.getShiftById(effectiveShiftId ?? '');

                // If not loaded, fetch from Firebase
                if (store == null && user.storeId != null) {
                  store = await storeProvider.fetchStoreById(user.storeId!);
                }

                if (shift == null && effectiveShiftId != null) {
                  shift = await shiftProvider.fetchShiftById(effectiveShiftId);
                }

                if (store == null) {
                  _showErrorDialog(context, 'لم يتم تحديد متجر لك. تواصل مع المدير.');
                  return;
                }

                if (shift == null) {
                  _showErrorDialog(context, 'لم يتم تحديد شفت لك. تواصل مع المدير.');
                  return;
                }

                final success = await attendanceProvider.checkIn(
                  userId: user.id,
                  userName: user.name,
                  store: store,
                  shift: shift,
                );

                if (!success && context.mounted) {
                  _showErrorDialog(context, attendanceProvider.errorMessage ?? 'حدث خطأ');
                } else if (success && context.mounted) {
                  final checkInResult = shift.canCheckIn();
                  if (checkInResult['isLate'] == true) {
                    _showLateWarning(context, checkInResult['lateMinutes'] ?? 0);
                  } else {
                    _showSuccessSnackbar(context, 'تم تسجيل الحضور بنجاح');
                  }
                }
              }
            },
      height: 120,
      child: attendanceProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isCheckedIn
                          ? [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.7)]
                          : [AppTheme.successColor, AppTheme.successColor.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: (isCheckedIn ? AppTheme.errorColor : AppTheme.successColor)
                            .withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    isCheckedIn ? Icons.logout : Icons.login,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCheckedIn ? 'تسجيل الخروج' : 'تسجيل الدخول',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isCheckedIn ? 'اضغط لتسجيل الخروج' : 'اضغط لتسجيل الحضور',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? Colors.white60 : Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isDarkMode ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
    );
  }

  Widget _buildTodayStatus(
    BuildContext context,
    AttendanceProvider attendanceProvider,
    bool isDarkMode,
  ) {
    final session = attendanceProvider.currentSession;
    if (session == null) return const SizedBox();

    return GlassContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppTheme.successColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'أنت في الخدمة الآن',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                context,
                'وقت الدخول',
                '${session.checkIn.hour.toString().padLeft(2, '0')}:${session.checkIn.minute.toString().padLeft(2, '0')}',
                Icons.login,
              ),
              Container(
                height: 40,
                width: 1,
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
              _buildStatusItem(
                context,
                'المتجر',
                session.storeName,
                Icons.store,
              ),
              Container(
                height: 40,
                width: 1,
                color: isDarkMode ? Colors.white24 : Colors.black12,
              ),
              _buildStatusItem(
                context,
                'الحالة',
                session.isLate ? 'متأخر' : 'في الوقت',
                session.isLate ? Icons.warning : Icons.check,
                color: session.isLate ? AppTheme.warningColor : AppTheme.successColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey),
        const SizedBox(height: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  Widget _buildTodayTasks(
    BuildContext context,
    TaskProvider taskProvider,
    bool isDarkMode,
  ) {
    final pendingTasks = taskProvider.pendingTasks;
    final inProgressTasks = taskProvider.inProgressTasks;
    final todayTasks = [...pendingTasks, ...inProgressTasks].take(3).toList();

    if (todayTasks.isEmpty) {
      return GlassContainer(
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.task_alt,
                size: 50,
                color: Colors.grey.withOpacity(0.3),
              ),
              const SizedBox(height: 10),
              Text(
                'لا توجد مهام حالياً',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        ...todayTasks.asMap().entries.map((entry) {
          final index = entry.key;
          final task = entry.value;
          
          return GlassContainer(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.taskDetail, arguments: task.id);
              },
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 50,
                    decoration: BoxDecoration(
                      color: task.isOverdue ? AppTheme.errorColor : _getPriorityColor(task.priority),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 12,
                              color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.timeRemainingText,
                              style: TextStyle(
                                fontSize: 11,
                                color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getTaskStatusColor(task.status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.statusText,
                      style: TextStyle(
                        fontSize: 10,
                        color: _getTaskStatusColor(task.status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: isDarkMode ? Colors.white30 : Colors.black26,
                  ),
                ],
              ),
            ),
          ).animate()
              .fadeIn(delay: Duration(milliseconds: 1000 + (index * 100)), duration: 600.ms)
              .slideX(begin: 0.2, end: 0);
        }),
        
        if (todayTasks.length < pendingTasks.length + inProgressTasks.length)
          TextButton(
            onPressed: () {
              // Navigate to tasks tab
              final homeState = context.findAncestorStateOfType<_HomeScreenState>();
              if (homeState != null) {
                homeState.setState(() {
                  homeState._currentIndex = 1;
                });
              }
            },
            child: Text(
              'عرض كل المهام (${pendingTasks.length + inProgressTasks.length})',
              style: const TextStyle(color: AppTheme.primaryColor),
            ),
          ),
      ],
    );
  }

  Color _getPriorityColor(priority) {
    switch (priority.toString()) {
      case 'TaskPriority.urgent':
        return AppTheme.errorColor;
      case 'TaskPriority.high':
        return AppTheme.warningColor;
      case 'TaskPriority.medium':
        return AppTheme.secondaryColor;
      default:
        return AppTheme.successColor;
    }
  }

  Color _getTaskStatusColor(status) {
    switch (status.toString()) {
      case 'TaskStatus.pending':
        return AppTheme.warningColor;
      case 'TaskStatus.inProgress':
        return AppTheme.secondaryColor;
      case 'TaskStatus.completed':
        return AppTheme.successColor;
      case 'TaskStatus.failed':
        return AppTheme.errorColor;
      case 'TaskStatus.cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.primaryColor;
    }
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
    {Duration delay = Duration.zero}
  ) {
    return AnimatedGlassCard(
      height: 100,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ],
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ).animate()
        .fadeIn(delay: delay, duration: 600.ms)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
        );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 10),
            const Text('فشل التسجيل'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showLateWarning(BuildContext context, int lateMinutes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 10),
            Text('تم تسجيل الحضور - متأخر $lateMinutes دقيقة'),
          ],
        ),
        backgroundColor: AppTheme.warningColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// Animated Glass Card Widget
class AnimatedGlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const AnimatedGlassCard({
    Key? key,
    required this.child,
    this.onTap,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      height: height,
      padding: padding,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}
