import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/request_provider.dart';
import '../../../core/models/request_model.dart';
import '../../../core/services/break_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({Key? key}) : super(key: key);

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BreakService _breakService = BreakService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await context.read<RequestProvider>().fetchAllRequests();
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
                    IconButton(
                      onPressed: () => Navigator.pop(context),
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
                    Text(
                      'إدارة الطلبات',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    StreamBuilder<QuerySnapshot>(
                      stream: _breakService.pendingBreakRequestsStream(),
                      builder: (context, breakSnapshot) {
                        return Consumer<RequestProvider>(
                          builder: (context, provider, _) {
                            final requestCount = provider.pendingCount;
                            final breakCount = breakSnapshot.data?.docs.length ?? 0;
                            final totalCount = requestCount + breakCount;

                            if (totalCount > 0) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$totalCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Tab Bar with Icons
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
                  tabs: [
                    Tab(
                      child: Consumer<RequestProvider>(
                        builder: (context, provider, _) {
                          final count = provider.pendingCount;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.hourglass_empty, size: 24),
                              if (count > 0)
                                Positioned(
                                  right: -8,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.warningColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Tab(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _breakService.pendingBreakRequestsStream(),
                        builder: (context, snapshot) {
                          final count = snapshot.data?.docs.length ?? 0;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              const Icon(Icons.coffee, size: 24),
                              if (count > 0)
                                Positioned(
                                  right: -8,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.accentColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(fontSize: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Tab(icon: Icon(Icons.check_circle, size: 24)),
                    const Tab(icon: Icon(Icons.cancel, size: 24)),
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
                    _buildBreakRequestsList(),
                    _buildRequestsList(RequestStatus.approved),
                    _buildRequestsList(RequestStatus.rejected),
                  ],
                ),
              ),
            ],
          ),
        ),
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
              return _buildRequestCard(requests[index], index, status == RequestStatus.pending);
            },
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(RequestModel request, int index, bool showActions) {
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
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                      request.employeeName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      '${request.typeText} • ${request.formattedTargetDate}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(statusIcon, size: 18, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Store info
          Row(
            children: [
              const Icon(Icons.store, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                request.storeName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Time range for time-off requests
          if (request.type == RequestType.timeOff && request.startTime != null) ...[
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(
                  request.timeRangeText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    request.durationText,
                    style: const TextStyle(
                      color: AppTheme.secondaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Reason
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'السبب:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  request.reason,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          // Request date
          const SizedBox(height: 8),
          Text(
            'تاريخ الطلب: ${request.formattedRequestDate}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),

          // Admin response (for processed requests)
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
            if (request.approvedByName != null) ...[
              const SizedBox(height: 4),
              Text(
                'بواسطة: ${request.approvedByName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 11,
                    ),
              ),
            ],
          ],

          // Action buttons for pending requests
          if (showActions) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(request),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(request),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============ BREAK REQUESTS ============

  Widget _buildBreakRequestsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _breakService.pendingBreakRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.coffee_outlined,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 20),
                Text(
                  'لا توجد طلبات استراحة',
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
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['id'] = docs[index].id;
            return _buildBreakRequestCard(data, index);
          },
        );
      },
    );
  }

  Widget _buildBreakRequestCard(Map<String, dynamic> request, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final requestId = request['id'] as String;
    final userName = request['userName'] as String? ?? 'موظف';
    final storeName = request['storeName'] as String? ?? '';
    final requestedDuration = request['requestedDuration'] as int? ?? 15;

    // Parse requested time
    String requestedTime = '--:--';
    if (request['requestedAt'] != null) {
      DateTime? requestedAt;
      if (request['requestedAt'] is Timestamp) {
        requestedAt = (request['requestedAt'] as Timestamp).toDate();
      } else if (request['requestedAt'] is String) {
        requestedAt = DateTime.tryParse(request['requestedAt'] as String);
      }
      if (requestedAt != null) {
        requestedTime = '${requestedAt.hour.toString().padLeft(2, '0')}:${requestedAt.minute.toString().padLeft(2, '0')}';
      }
    }

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.coffee, color: AppTheme.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      'طلب استراحة • $requestedTime',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.hourglass_empty, size: 18, color: AppTheme.warningColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Store info
          Row(
            children: [
              const Icon(Icons.store, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              Text(
                storeName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Duration
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer, size: 18, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  'المدة المطلوبة: $requestedDuration دقيقة',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),

          // Action buttons
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showRejectBreakDialog(requestId, userName),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('رفض'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveBreakRequest(requestId, userName),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('موافقة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveBreakRequest(String requestId, String userName) async {
    final success = await _breakService.approveBreakRequest(requestId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت الموافقة على استراحة $userName'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في الموافقة على الطلب'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showRejectBreakDialog(String requestId, String userName) {
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
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 10),
            const Text('رفض طلب الاستراحة'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            const Text('سبب الرفض:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الرفض...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
                return;
              }

              final success = await _breakService.rejectBreakRequest(
                requestId,
                reasonController.text.trim(),
              );

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم رفض استراحة $userName'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(RequestModel request) {
    final authProvider = context.read<AuthProvider>();
    final responseController = TextEditingController();

    // For time-off, allow admin to modify duration
    TimeOfDay? modifiedStartTime;
    TimeOfDay? modifiedEndTime;

    if (request.type == RequestType.timeOff && request.startTime != null) {
      final startParts = request.startTime!.split(':');
      final endParts = request.endTime!.split(':');
      modifiedStartTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );
      modifiedEndTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.check_circle, color: AppTheme.successColor),
                ),
                const SizedBox(width: 10),
                const Text('الموافقة على الطلب'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Request summary
                  Text(
                    '${request.employeeName} - ${request.typeText}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    request.formattedTargetDate,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 15),

                  // Modify time (for time-off)
                  if (request.type == RequestType.timeOff && modifiedStartTime != null) ...[
                    const Text('تعديل الوقت (اختياري):', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: modifiedStartTime!,
                              );
                              if (time != null) {
                                setState(() {
                                  modifiedStartTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text('من', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    '${modifiedStartTime!.hour.toString().padLeft(2, '0')}:${modifiedStartTime!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: modifiedEndTime!,
                              );
                              if (time != null) {
                                setState(() {
                                  modifiedEndTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text('إلى', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    '${modifiedEndTime!.hour.toString().padLeft(2, '0')}:${modifiedEndTime!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                  ],

                  // Response
                  const Text('ملاحظات (اختياري):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: responseController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'أضف ملاحظة...',
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
                  String? startTimeStr;
                  String? endTimeStr;
                  int? durationMinutes;

                  if (modifiedStartTime != null && modifiedEndTime != null) {
                    startTimeStr = '${modifiedStartTime!.hour.toString().padLeft(2, '0')}:${modifiedStartTime!.minute.toString().padLeft(2, '0')}';
                    endTimeStr = '${modifiedEndTime!.hour.toString().padLeft(2, '0')}:${modifiedEndTime!.minute.toString().padLeft(2, '0')}';

                    final startMinutes = modifiedStartTime!.hour * 60 + modifiedStartTime!.minute;
                    final endMinutes = modifiedEndTime!.hour * 60 + modifiedEndTime!.minute;
                    durationMinutes = endMinutes - startMinutes;
                  }

                  final success = await context.read<RequestProvider>().approveRequest(
                    requestId: request.id,
                    adminId: authProvider.user!.id,
                    adminName: authProvider.user!.name,
                    response: responseController.text.trim().isEmpty ? null : responseController.text.trim(),
                    approvedStartTime: startTimeStr,
                    approvedEndTime: endTimeStr,
                    approvedDurationMinutes: durationMinutes,
                  );

                  Navigator.pop(context);

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت الموافقة على الطلب'),
                        backgroundColor: AppTheme.successColor,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successColor,
                ),
                child: const Text('موافقة'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectDialog(RequestModel request) {
    final authProvider = context.read<AuthProvider>();
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
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cancel, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 10),
            const Text('رفض الطلب'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${request.employeeName} - ${request.typeText}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              request.formattedTargetDate,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 15),
            const Text('سبب الرفض:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب سبب الرفض...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
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
                  const SnackBar(content: Text('يرجى كتابة سبب الرفض')),
                );
                return;
              }

              final success = await context.read<RequestProvider>().rejectRequest(
                requestId: request.id,
                adminId: authProvider.user!.id,
                adminName: authProvider.user!.name,
                reason: reasonController.text.trim(),
              );

              Navigator.pop(context);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم رفض الطلب'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}
