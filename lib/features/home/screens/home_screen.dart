import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/attendance_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/shift_provider.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/routes/app_routes.dart' show AppRoutes;
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/services/location_monitor_service.dart';
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

              // Offline Sync Indicator
              if (attendanceProvider.hasOfflineData)
                _buildOfflineSyncIndicator(context, attendanceProvider, isDarkMode)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0),

              if (attendanceProvider.hasOfflineData)
                const SizedBox(height: 15),

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

              // Vacation Greeting Card
              if (user != null && requestProvider.isOnVacationToday(user.id)) ...[
                _buildVacationGreetingCard(context, user.id, requestProvider, isDarkMode)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 600.ms)
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

  Widget _buildVacationGreetingCard(
    BuildContext context,
    String userId,
    RequestProvider requestProvider,
    bool isDarkMode,
  ) {
    final vacation = requestProvider.getApprovedVacationForDate(userId, DateTime.now());
    if (vacation == null) return const SizedBox.shrink();

    return GlassContainer(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withOpacity(0.15),
              AppTheme.secondaryColor.withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4CAF50).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.beach_access,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استمتع بإجازتك!',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E7D32),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vacation.isMultiDay
                            ? vacation.dateRangeText
                            : vacation.formattedTargetDate,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.spa,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'نتمنى لك راحة واستجمام طيب',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
          ],
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
                // Check Out
                final currentSession = attendanceProvider.currentSession;

                // Check if this is a free employee
                if (user.isFreeEmployee == true) {
                  // Free employee checkout - no location validation needed
                  final success = await attendanceProvider.checkOutFreeEmployee();
                  if (success && context.mounted) {
                    // Stop GPS tracking
                    await LocationMonitorService.stopFreeEmployeeTracking();
                    _showSuccessSnackbar(context, 'تم تسجيل الخروج بنجاح');
                  } else if (!success && context.mounted) {
                    _showErrorDialog(context, attendanceProvider.errorMessage ?? 'حدث خطأ');
                  }
                } else {
                  // Regular employee checkout - validate location at store
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
                }
              } else {
                // Check In with validation and multi-store support
                await _handleCheckIn(
                  context,
                  user,
                  attendanceProvider,
                  storeProvider,
                  shiftProvider,
                );
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

  /// Handle check-in with multi-store support
  Future<void> _handleCheckIn(
    BuildContext context,
    dynamic user,
    AttendanceProvider attendanceProvider,
    StoreProvider storeProvider,
    ShiftProvider shiftProvider,
  ) async {
    // Check if this is a free employee
    if (user.isFreeEmployee == true) {
      await _handleFreeEmployeeCheckIn(context, user, attendanceProvider);
      return;
    }

    // Regular employee check-in flow
    // Use effective shift (considers temporary shift)
    final effectiveShiftId = user.effectiveShiftId ?? user.shiftId;

    // Get shift first
    var shift = shiftProvider.getShiftById(effectiveShiftId ?? '');
    if (shift == null && effectiveShiftId != null) {
      shift = await shiftProvider.fetchShiftById(effectiveShiftId);
    }

    if (shift == null) {
      _showErrorDialog(context, 'لم يتم تحديد شفت لك. تواصل مع المدير.');
      return;
    }

    // Get primary store
    var primaryStore = storeProvider.getStoreById(user.storeId ?? '');
    if (primaryStore == null && user.storeId != null) {
      primaryStore = await storeProvider.fetchStoreById(user.storeId!);
    }

    if (primaryStore == null) {
      _showErrorDialog(context, 'لم يتم تحديد متجر لك. تواصل مع المدير.');
      return;
    }

    // Fetch all authorized stores
    final authorizedStoreIds = user.allAuthorizedStoreIds as List<String>;
    final allStores = await storeProvider.fetchStoresByIds(authorizedStoreIds);

    // Try to get current location to determine which store to use
    try {
      final position = await _getCurrentLocation();

      // Find all stores within range
      final storesInRange = <StoreModel>[];
      for (final store in allStores) {
        if (store.isWithinRadius(position.latitude, position.longitude)) {
          storesInRange.add(store);
        }
      }

      if (storesInRange.isEmpty) {
        // No store in range
        final distances = allStores.map((s) =>
          '${s.name}: ${s.getDistanceFrom(position.latitude, position.longitude).toStringAsFixed(0)} متر'
        ).join('\n');

        _showErrorDialog(
          context,
          'يجب أن تكون داخل نطاق أحد المتاجر\n\n'
          'المسافة الحالية:\n$distances',
        );
        return;
      }

      if (storesInRange.length == 1) {
        // Only one store in range
        final store = storesInRange.first;

        // If it's the primary store, proceed directly
        if (store.id == user.storeId) {
          await _performCheckIn(context, user, store, shift, attendanceProvider);
        } else {
          // Secondary store - get shifts for this store
          final storeShifts = shiftProvider.getShiftsByStore(store.id);
          if (storeShifts.isEmpty) {
            await shiftProvider.fetchShifts(store.id);
          }
          final availableShifts = shiftProvider.getShiftsByStore(store.id);

          // Ask confirmation for secondary store and select shift
          final result = await _showSecondaryStoreCheckInDialog(context, store, availableShifts);
          if (result != null && context.mounted) {
            final selectedShift = result['shift'] as ShiftModel?;
            // Use selected shift or allow without time restriction for secondary stores
            await _performCheckIn(
              context, user, store,
              selectedShift ?? shift,
              attendanceProvider,
              isSecondaryStore: true,
            );
          }
        }
      } else {
        // Multiple stores in range - let user choose
        final result = await _showMultiStoreSelectionDialog(context, storesInRange, user.storeId, shiftProvider);
        if (result != null && context.mounted) {
          final selectedStore = result['store'] as StoreModel;
          final selectedShift = result['shift'] as ShiftModel?;
          await _performCheckIn(
            context, user, selectedStore,
            selectedShift ?? shift,
            attendanceProvider,
            isSecondaryStore: selectedStore.id != user.storeId,
          );
        }
      }
    } catch (e) {
      _showErrorDialog(context, 'فشل في الحصول على الموقع: $e');
    }
  }

  /// Handle check-in for free employees (no store/shift required)
  Future<void> _handleFreeEmployeeCheckIn(
    BuildContext context,
    dynamic user,
    AttendanceProvider attendanceProvider,
  ) async {
    try {
      // Get current location for tracking
      final position = await _getCurrentLocation();

      // Check in without store/shift validation
      final success = await attendanceProvider.checkInFreeEmployee(
        userId: user.id,
        userName: user.name,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!success && context.mounted) {
        _showErrorDialog(context, attendanceProvider.errorMessage ?? 'فشل في تسجيل الدخول');
        return;
      }

      if (success && context.mounted) {
        // Start GPS tracking for free employee
        final currentSession = attendanceProvider.currentSession;
        if (currentSession != null) {
          await LocationMonitorService.startFreeEmployeeTracking(
            userId: user.id,
            userName: user.name,
            attendanceId: currentSession.id,
          );
        }

        _showSuccessSnackbar(context, 'تم تسجيل الدخول بنجاح - تتبع GPS نشط');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'فشل في الحصول على الموقع: $e');
      }
    }
  }

  /// Perform the actual check-in
  Future<void> _performCheckIn(
    BuildContext context,
    dynamic user,
    StoreModel store,
    dynamic shift,
    AttendanceProvider attendanceProvider, {
    bool isSecondaryStore = false,
  }) async {
    final success = await attendanceProvider.checkIn(
      userId: user.id,
      userName: user.name,
      store: store,
      shift: shift,
      skipTimeValidation: isSecondaryStore, // Skip time validation for secondary stores
    );

    if (!success && context.mounted) {
      _showErrorDialog(context, attendanceProvider.errorMessage ?? 'حدث خطأ');
    } else if (success && context.mounted) {
      final checkInResult = shift.canCheckIn();
      if (!isSecondaryStore && checkInResult['isLate'] == true) {
        _showLateWarning(context, checkInResult['lateMinutes'] ?? 0);
      } else {
        final storeLabel = isSecondaryStore ? '(متجر إضافي)' : '';
        _showSuccessSnackbar(context, 'تم تسجيل الحضور بنجاح في ${store.name} $storeLabel');
      }
    }
  }

  /// Get current GPS location
  Future<dynamic> _getCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied) {
        throw Exception('تم رفض إذن الموقع');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('إذن الموقع مرفوض بشكل دائم');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('خدمة الموقع غير مفعلة');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Show confirmation dialog when checking in at authorized (non-primary) store
  Future<bool?> _showStoreConfirmationDialog(BuildContext context, StoreModel store) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront, color: AppTheme.secondaryColor),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('تسجيل في متجر آخر')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أنت على وشك تسجيل الحضور في:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.store, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          store.address,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'هل تريد المتابعة؟',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
            child: const Text('تسجيل الحضور'),
          ),
        ],
      ),
    );
  }

  /// Show dialog to select from multiple stores in range
  Future<StoreModel?> _showStoreSelectionDialog(
    BuildContext context,
    List<StoreModel> stores,
    String? primaryStoreId,
  ) {
    return showDialog<StoreModel>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('اختر المتجر')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أنت في نطاق عدة متاجر. اختر المتجر الذي تريد تسجيل الحضور فيه:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...stores.map((store) {
              final isPrimary = store.id == primaryStoreId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => Navigator.pop(context, store),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPrimary
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : AppTheme.secondaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: isPrimary
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isPrimary ? Icons.store : Icons.storefront,
                          color: isPrimary ? AppTheme.primaryColor : AppTheme.secondaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    store.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (isPrimary) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'الأساسي',
                                        style: TextStyle(fontSize: 10, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                store.address,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  /// Show dialog for check-in at secondary store with shift selection
  Future<Map<String, dynamic>?> _showSecondaryStoreCheckInDialog(
    BuildContext context,
    StoreModel store,
    List<ShiftModel> availableShifts,
  ) async {
    ShiftModel? selectedShift = availableShifts.isNotEmpty ? availableShifts.first : null;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.storefront, color: AppTheme.secondaryColor),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('تسجيل في متجر إضافي')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(store.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (availableShifts.isNotEmpty) ...[
                const Text('اختر الشفت:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...availableShifts.map((shift) => RadioListTile<ShiftModel>(
                  value: shift,
                  groupValue: selectedShift,
                  title: Text(shift.name),
                  subtitle: Text('${shift.startTime} - ${shift.endTime}'),
                  onChanged: (value) => setDialogState(() => selectedShift = value),
                  activeColor: AppTheme.secondaryColor,
                  dense: true,
                )),
              ] else
                const Text(
                  'لا توجد ورديات محددة لهذا المتجر.\nسيتم التسجيل بدون قيود وقتية.',
                  style: TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'التسجيل في متجر إضافي لا يتطلب التزام بوقت الشفت الأساسي',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, {'store': store, 'shift': selectedShift}),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
              child: const Text('تسجيل الحضور'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show dialog to select from multiple stores with shift selection
  Future<Map<String, dynamic>?> _showMultiStoreSelectionDialog(
    BuildContext context,
    List<StoreModel> stores,
    String? primaryStoreId,
    ShiftProvider shiftProvider,
  ) async {
    StoreModel? selectedStore;
    ShiftModel? selectedShift;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableShifts = selectedStore != null
              ? shiftProvider.getShiftsByStore(selectedStore!.id)
              : <ShiftModel>[];

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Text('اختر المتجر والشفت')),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المتجر:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...stores.map((store) {
                    final isPrimary = store.id == primaryStoreId;
                    final isSelected = selectedStore?.id == store.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          setDialogState(() {
                            selectedStore = store;
                            selectedShift = null;
                          });
                          // Fetch shifts for this store
                          if (shiftProvider.getShiftsByStore(store.id).isEmpty) {
                            await shiftProvider.fetchShifts(store.id);
                            setDialogState(() {
                              final shifts = shiftProvider.getShiftsByStore(store.id);
                              if (shifts.isNotEmpty) selectedShift = shifts.first;
                            });
                          } else {
                            final shifts = shiftProvider.getShiftsByStore(store.id);
                            if (shifts.isNotEmpty) {
                              setDialogState(() => selectedShift = shifts.first);
                            }
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : (isPrimary ? AppTheme.successColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.store,
                                color: isSelected ? AppTheme.primaryColor : (isPrimary ? AppTheme.successColor : Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(store.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (isPrimary) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.successColor,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text('أساسي', style: TextStyle(fontSize: 10, color: Colors.white)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(store.address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  if (selectedStore != null && availableShifts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('الشفت:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...availableShifts.map((shift) => RadioListTile<ShiftModel>(
                      value: shift,
                      groupValue: selectedShift,
                      title: Text(shift.name),
                      subtitle: Text('${shift.startTime} - ${shift.endTime}'),
                      onChanged: (value) => setDialogState(() => selectedShift = value),
                      activeColor: AppTheme.secondaryColor,
                      dense: true,
                    )),
                  ],
                  if (selectedStore != null && selectedStore!.id != primaryStoreId)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'المتجر الإضافي لا يتطلب التزام بوقت الشفت',
                              style: TextStyle(fontSize: 11, color: Colors.green),
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
                onPressed: () => Navigator.pop(context, null),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: selectedStore == null
                    ? null
                    : () => Navigator.pop(context, {'store': selectedStore, 'shift': selectedShift}),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor),
                child: const Text('تسجيل الحضور'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOfflineSyncIndicator(
    BuildContext context,
    AttendanceProvider attendanceProvider,
    bool isDarkMode,
  ) {
    final pendingCount = attendanceProvider.offlineQueue.length;

    return GlassContainer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.warningColor.withOpacity(0.15),
              AppTheme.warningColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.warningColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cloud_off,
                color: AppTheme.warningColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات في انتظار المزامنة',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warningColor,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$pendingCount عملية معلقة - ستتم المزامنة عند توفر الإنترنت',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.white60 : Colors.black54,
                        ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                await attendanceProvider.syncOfflineData();
                if (context.mounted) {
                  if (attendanceProvider.hasOfflineData) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.white),
                            SizedBox(width: 10),
                            Text('لا يوجد اتصال بالإنترنت'),
                          ],
                        ),
                        backgroundColor: AppTheme.warningColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.cloud_done, color: Colors.white),
                            SizedBox(width: 10),
                            Text('تمت المزامنة بنجاح'),
                          ],
                        ),
                        backgroundColor: AppTheme.successColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  }
                }
              },
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.sync,
                  color: AppTheme.warningColor,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
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
