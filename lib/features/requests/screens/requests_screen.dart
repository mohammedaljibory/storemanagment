import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({Key? key}) : super(key: key);

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isDisposed = false;
  bool _isEmbedded = false; // True when used as a tab

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Check if this screen is embedded in a tab (no route to pop)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isEmbedded = !Navigator.canPop(context);
        });
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isDisposed) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      await context.read<RequestProvider>().fetchEmployeeRequests(authProvider.user!.id);
    }
  }

  void _goBack() {
    if (!_isDisposed && mounted && Navigator.canPop(context)) {
      Navigator.of(context).pop();
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Only show back button when not embedded as a tab
                    if (!_isEmbedded) ...[
                      IconButton(
                        onPressed: _goBack,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      'الطلبات',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),

              // Vacation Balance Card
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final user = authProvider.user;
                  if (user == null || user.allowedVacationDays <= 0) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GlassContainer(
                      margin: const EdgeInsets.only(bottom: 15),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.beach_access,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'رصيد الإجازات',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${user.remainingVacationDays}',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                    ),
                                    Text(
                                      ' / ${user.allowedVacationDays} يوم',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Progress indicator
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: Stack(
                              children: [
                                CircularProgressIndicator(
                                  value: user.allowedVacationDays > 0
                                      ? user.remainingVacationDays / user.allowedVacationDays
                                      : 0,
                                  backgroundColor: Colors.grey.withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    user.remainingVacationDays > 0
                                        ? AppTheme.primaryColor
                                        : AppTheme.errorColor,
                                  ),
                                  strokeWidth: 6,
                                ),
                                Center(
                                  child: Text(
                                    '${((user.remainingVacationDays / user.allowedVacationDays) * 100).round()}%',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.black54,
                  tabs: const [
                    Tab(text: 'قيد الانتظار'),
                    Tab(text: 'الموافق عليها'),
                    Tab(text: 'المرفوضة'),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRequestsList(RequestStatus.pending),
                    _buildRequestsList(RequestStatus.approved),
                    _buildRequestsList(RequestStatus.rejected),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, AppRoutes.createRequest);
          if (result == true) {
            // Refresh the list after creating a new request
            _loadData();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildRequestsList(RequestStatus status) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        if (requestProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        List<RequestModel> requests;
        switch (status) {
          case RequestStatus.pending:
            requests = requestProvider.pendingRequests;
            break;
          case RequestStatus.approved:
            requests = requestProvider.approvedRequests;
            break;
          case RequestStatus.rejected:
            requests = requestProvider.rejectedRequests;
            break;
          default:
            requests = [];
        }

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                Text(
                  'لا توجد طلبات',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildRequestCard(requests[index], index);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(RequestModel request, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    IconData statusIcon;
    switch (request.status) {
      case RequestStatus.pending:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.hourglass_empty;
        break;
      case RequestStatus.approved:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle;
        break;
      case RequestStatus.rejected:
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    IconData typeIcon;
    switch (request.type) {
      case RequestType.timeOff:
        typeIcon = Icons.timer_outlined;
        break;
      case RequestType.fullDayOff:
        typeIcon = Icons.calendar_today;
        break;
      case RequestType.shiftChange:
        typeIcon = Icons.swap_horiz;
        break;
      case RequestType.vacationCancellation:
        typeIcon = Icons.event_busy;
        break;
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(typeIcon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.typeText,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      request.isMultiDay ? request.dateRangeText : request.formattedTargetDate,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 16, color: statusColor),
                    const SizedBox(width: 5),
                    Text(
                      request.statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Time range for time-off requests
          if (request.type == RequestType.timeOff && request.startTime != null) ...[
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  request.timeRangeText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 15),
                Text(
                  '(${request.durationText})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Reason
          Text(
            'السبب: ${request.reason}',
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Admin response
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const Divider(height: 20),
            Row(
              children: [
                Icon(
                  Icons.comment,
                  size: 16,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'رد المدير: ${request.adminResponse}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              ],
            ),
          ],

          // Cancel button for pending requests
          if (request.status == RequestStatus.pending) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelRequest(request),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('إلغاء الطلب'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: const BorderSide(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],

          // Request cancellation button for approved vacations (only for future vacations)
          if (request.status == RequestStatus.approved &&
              request.type == RequestType.fullDayOff &&
              request.targetDate.isAfter(DateTime.now().subtract(const Duration(days: 1)))) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showCancellationRequestDialog(request),
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('طلب إلغاء الإجازة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],

          // Delete button for all requests
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => _deleteRequest(request),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('حذف الطلب'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRequest(RequestModel request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لا'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await context.read<RequestProvider>().cancelRequest(request.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إلغاء الطلب'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }

  Future<void> _deleteRequest(RequestModel request) async {
    final confirm = await showDialog<bool>(
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
              child: const Icon(Icons.delete_forever, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 10),
            const Text('حذف الطلب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف هذا الطلب نهائياً؟',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا يمكن التراجع عن هذا الإجراء',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await context.read<RequestProvider>().deleteRequest(request.id);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الطلب'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<RequestProvider>().errorMessage ?? 'فشل في حذف الطلب'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Show dialog to request cancellation of an approved vacation
  void _showCancellationRequestDialog(RequestModel vacation) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.event_busy, color: Colors.orange),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('طلب إلغاء إجازة', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vacation info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'الإجازة المراد إلغاؤها',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      vacation.isMultiDay ? vacation.dateRangeText : vacation.formattedTargetDate,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (vacation.totalDays != null)
                      Text(
                        '${vacation.totalDays} أيام',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Info message
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'سيتم إرسال طلب الإلغاء للمدير للموافقة عليه.\nفي حال الموافقة، سيُسترد رصيد الإجازات.',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason
              const Text('سبب الإلغاء:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'اكتب سبب طلب الإلغاء...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          ElevatedButton.icon(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى كتابة سبب الإلغاء')),
                );
                return;
              }

              Navigator.pop(context);

              final success = await context.read<RequestProvider>().createCancellationRequest(
                originalVacation: vacation,
                reason: reasonController.text.trim(),
              );

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال طلب الإلغاء للمدير'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.read<RequestProvider>().errorMessage ?? 'فشل في إرسال الطلب'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            icon: const Icon(Icons.send, size: 18),
            label: const Text('إرسال الطلب'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
