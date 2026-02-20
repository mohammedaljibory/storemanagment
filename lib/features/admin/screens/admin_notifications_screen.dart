import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/admin_notification_listener.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _markAllAsRead,
            icon: const Icon(Icons.done_all),
            tooltip: 'تحديد الكل كمقروء',
          ),
        ],
      ),
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('notifications')
              .where('forAdmin', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 60, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ في تحميل الإشعارات',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_off,
                        size: 60, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _buildNotificationCard(context, doc.id, data, isDarkMode);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, String docId,
      Map<String, dynamic> data, bool isDarkMode) {
    final type = data['type'] as String? ?? '';
    final title = data['title'] as String? ?? 'إشعار';
    final body = data['body'] as String? ?? '';
    final isRead = data['read'] as bool? ?? false;
    final createdAt = _parseTimestamp(data['createdAt']);
    final info = _getNotificationTypeInfo(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? (isRead ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.1))
            : (isRead ? Colors.white.withOpacity(0.7) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isRead
            ? null
            : Border.all(
                color: info.color.withOpacity(0.3),
                width: 1.5,
              ),
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: info.color.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            AdminNotificationListener.markAsRead(docId);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: info.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color, size: 24),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.normal : FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: info.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: info.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            info.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: info.color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotificationTypeInfo _getNotificationTypeInfo(String type) {
    switch (type) {
      case 'employee_checkin':
        return _NotificationTypeInfo(
          icon: Icons.login,
          color: AppTheme.successColor,
          label: 'تسجيل حضور',
        );
      case 'employee_checkout':
        return _NotificationTypeInfo(
          icon: Icons.logout,
          color: Colors.blue,
          label: 'تسجيل انصراف',
        );
      case 'location_alert':
        return _NotificationTypeInfo(
          icon: Icons.location_off,
          color: AppTheme.errorColor,
          label: 'تنبيه موقع',
        );
      case 'location_warning':
        return _NotificationTypeInfo(
          icon: Icons.warning_amber,
          color: AppTheme.warningColor,
          label: 'تحذير موقع',
        );
      case 'location_return':
        return _NotificationTypeInfo(
          icon: Icons.location_on,
          color: AppTheme.successColor,
          label: 'عودة للموقع',
        );
      case 'auto_checkout':
      case 'auto_checkout_shift_end':
        return _NotificationTypeInfo(
          icon: Icons.timer_off,
          color: Colors.deepOrange,
          label: 'خروج تلقائي',
        );
      case 'break_overtime_server':
        return _NotificationTypeInfo(
          icon: Icons.free_breakfast,
          color: Colors.orange,
          label: 'تجاوز استراحة',
        );
      case 'time_off_blocked':
        return _NotificationTypeInfo(
          icon: Icons.block,
          color: Colors.red.shade700,
          label: 'حظر زمنية',
        );
      case 'late_checkout_admin':
        return _NotificationTypeInfo(
          icon: Icons.schedule,
          color: Colors.purple,
          label: 'تأخر خروج',
        );
      case 'new_request':
        return _NotificationTypeInfo(
          icon: Icons.request_page,
          color: AppTheme.accentColor,
          label: 'طلب جديد',
        );
      default:
        return _NotificationTypeInfo(
          icon: Icons.notifications,
          color: AppTheme.primaryColor,
          label: 'إشعار',
        );
    }
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';

    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  Future<void> _markAllAsRead() async {
    await AdminNotificationListener.markAllAsRead();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد جميع الإشعارات كمقروءة'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
}

class _NotificationTypeInfo {
  final IconData icon;
  final Color color;
  final String label;

  const _NotificationTypeInfo({
    required this.icon,
    required this.color,
    required this.label,
  });
}
