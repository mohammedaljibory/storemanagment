import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<StoreProvider>().fetchStores(authProvider.user!.id);
      await context.read<EmployeeProvider>().fetchEmployees();
      await context.read<TaskProvider>().fetchTasks();
      await context.read<RequestProvider>().fetchAllRequests(); // NEW: Fetch requests
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
        // NEW: Requests notification badge
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
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
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
      // NEW: Pending requests stat
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
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return GlassContainer(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (stat['color'] as Color).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  stat['icon'] as IconData,
                  color: stat['color'] as Color,
                  size: 24,
                ),
              ),
              Text(
                stat['value'] as String,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: stat['color'] as Color,
                ),
              ),
              Text(
                stat['title'] as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ).animate()
            .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
      },
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
      // NEW: Requests management card
      {
        'title': 'إدارة الطلبات',
        'subtitle': 'طلبات الإجازات والزمنيات',
        'icon': Icons.request_page,
        'gradient': [AppTheme.accentColor, AppTheme.accentColor.withOpacity(0.7)],
        'route': AppRoutes.adminRequests,
        'badge': requestProvider.pendingCount,
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
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          
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
            ).animate()
                .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
                .slideX(begin: 0.2, end: 0),
          );
        }).toList(),
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
