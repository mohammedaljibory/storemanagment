import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/models/user_model.dart';
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
        onPressed: () => _showCreateRequestDialog(context),
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

  void _showCreateRequestDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user == null) return;

    RequestType selectedType = RequestType.timeOff;
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime? endDate; // For multi-day vacation
    bool isMultiDay = false;
    bool isBeforeShift = false; // Time-off before starting work
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Calculate total vacation days
          int totalDays = 1;
          if (isMultiDay && endDate != null) {
            totalDays = endDate!.difference(startDate).inDays + 1;
          }

          // Check if user has enough vacation balance
          final hasBalance = user.hasVacationBalance(totalDays);
          final remainingBalance = user.remainingVacationDays;

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
                  child: const Icon(Icons.add_circle, color: AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                const Text('طلب جديد'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request Type
                  const Text('نوع الطلب:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<RequestType>(
                    segments: const [
                      ButtonSegment(
                        value: RequestType.timeOff,
                        label: Text('زمنية'),
                        icon: Icon(Icons.timer_outlined),
                      ),
                      ButtonSegment(
                        value: RequestType.fullDayOff,
                        label: Text('إجازة'),
                        icon: Icon(Icons.calendar_today),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (Set<RequestType> newSelection) {
                      setState(() {
                        selectedType = newSelection.first;
                        if (selectedType == RequestType.timeOff) {
                          isMultiDay = false;
                          endDate = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Multi-day toggle for vacation
                  if (selectedType == RequestType.fullDayOff) ...[
                    Row(
                      children: [
                        const Text('إجازة متعددة الأيام:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Switch(
                          value: isMultiDay,
                          onChanged: (value) {
                            setState(() {
                              isMultiDay = value;
                              if (!value) {
                                endDate = null;
                              } else {
                                endDate = startDate.add(const Duration(days: 1));
                              }
                            });
                          },
                          activeColor: AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Vacation balance warning
                    if (user.allowedVacationDays > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasBalance
                              ? AppTheme.primaryColor.withOpacity(0.1)
                              : AppTheme.errorColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasBalance ? Icons.info_outline : Icons.warning_amber,
                              color: hasBalance ? AppTheme.primaryColor : AppTheme.errorColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                hasBalance
                                    ? 'رصيدك المتبقي: $remainingBalance يوم (تطلب $totalDays يوم)'
                                    : 'رصيدك غير كافٍ! المتبقي: $remainingBalance يوم',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: hasBalance ? AppTheme.primaryColor : AppTheme.errorColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                  ],

                  // Start Date Picker
                  Text(
                    isMultiDay ? 'تاريخ البداية:' : 'التاريخ:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() {
                          startDate = date;
                          // Adjust end date if needed
                          if (endDate != null && endDate!.isBefore(startDate)) {
                            endDate = startDate.add(const Duration(days: 1));
                          }
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                          const SizedBox(width: 10),
                          Text(
                            '${startDate.day}/${startDate.month}/${startDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // End Date Picker (for multi-day)
                  if (isMultiDay) ...[
                    const Text('تاريخ النهاية:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        // Calculate max end date based on remaining balance
                        final maxDays = remainingBalance > 0 ? remainingBalance - 1 : 0;
                        final maxEndDate = startDate.add(Duration(days: maxDays));

                        final date = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? startDate.add(const Duration(days: 1)),
                          firstDate: startDate.add(const Duration(days: 1)),
                          lastDate: user.allowedVacationDays > 0
                              ? maxEndDate
                              : DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            endDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, color: AppTheme.primaryColor),
                            const SizedBox(width: 10),
                            Text(
                              endDate != null
                                  ? '${endDate!.day}/${endDate!.month}/${endDate!.year}'
                                  : 'اختر تاريخ النهاية',
                              style: TextStyle(
                                fontSize: 16,
                                color: endDate != null ? null : Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            if (totalDays > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$totalDays أيام',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Time Range (only for time-off)
                  if (selectedType == RequestType.timeOff) ...[
                    const Text('الوقت:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text('من', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward, color: Colors.grey),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (time != null) {
                                setState(() {
                                  endTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text('إلى', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(
                                    '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // Before Shift Toggle
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isBeforeShift
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBeforeShift ? Colors.orange : Colors.grey.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isBeforeShift ? Icons.wb_sunny : Icons.work_history,
                                color: isBeforeShift ? Colors.orange : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'زمنية قبل بداية الدوام',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              Switch(
                                value: isBeforeShift,
                                onChanged: (value) {
                                  setState(() {
                                    isBeforeShift = value;
                                  });
                                },
                                activeColor: Colors.orange,
                              ),
                            ],
                          ),
                          if (isBeforeShift) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'يجب العودة قبل الساعة ${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}\nفترة السماح: 15 دقيقة',
                                      style: const TextStyle(fontSize: 11, color: Colors.orange),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Reason
                  const Text('السبب:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب الطلب...',
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
              ElevatedButton(
                onPressed: () async {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى كتابة سبب الطلب')),
                    );
                    return;
                  }

                  // Validate multi-day vacation
                  if (selectedType == RequestType.fullDayOff && isMultiDay && endDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى اختيار تاريخ النهاية')),
                    );
                    return;
                  }

                  // Validate vacation balance
                  if (selectedType == RequestType.fullDayOff && user.allowedVacationDays > 0 && !hasBalance) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('رصيد الإجازات غير كافٍ'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                    return;
                  }

                  int? durationMinutes;
                  String? startTimeStr;
                  String? endTimeStr;

                  if (selectedType == RequestType.timeOff) {
                    startTimeStr = '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}';
                    endTimeStr = '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}';

                    final startMinutes = startTime.hour * 60 + startTime.minute;
                    final endMinutes = endTime.hour * 60 + endTime.minute;
                    durationMinutes = endMinutes - startMinutes;

                    if (durationMinutes <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('وقت النهاية يجب أن يكون بعد وقت البداية')),
                      );
                      return;
                    }
                  }

                  final request = RequestModel(
                    id: '',
                    employeeId: user.id,
                    employeeName: user.name,
                    storeId: user.storeId ?? '',
                    storeName: user.storeName ?? '',
                    type: selectedType,
                    requestDate: DateTime.now(),
                    targetDate: startDate,
                    endDate: isMultiDay ? endDate : null,
                    totalDays: selectedType == RequestType.fullDayOff ? totalDays : null,
                    startTime: startTimeStr,
                    endTime: endTimeStr,
                    durationMinutes: durationMinutes,
                    reason: reasonController.text.trim(),
                    // Time-off monitoring fields
                    isBeforeShift: selectedType == RequestType.timeOff ? isBeforeShift : false,
                    expectedReturnTime: selectedType == RequestType.timeOff ? endTimeStr : null,
                    graceMinutes: 15,
                  );

                  final requestProvider = context.read<RequestProvider>();
                  final success = await requestProvider.createRequest(request);

                  if (success) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إرسال الطلب بنجاح'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(requestProvider.errorMessage ?? 'فشل في إرسال الطلب'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('إرسال الطلب'),
              ),
            ],
          );
        },
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
