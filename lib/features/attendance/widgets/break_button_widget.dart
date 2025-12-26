import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/break_service.dart';
import '../../../core/models/attendance_model.dart';

/// Break button widget with admin approval flow
/// Shows during active attendance - requires admin approval for break
class BreakButtonWidget extends StatefulWidget {
  final AttendanceModel attendance;
  final String userId;
  final String userName;

  const BreakButtonWidget({
    super.key,
    required this.attendance,
    required this.userId,
    required this.userName,
  });

  @override
  State<BreakButtonWidget> createState() => _BreakButtonWidgetState();
}

class _BreakButtonWidgetState extends State<BreakButtonWidget> {
  final BreakService _breakService = BreakService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Check break status on init (handles app restart)
    _breakService.checkBreakStatus(widget.attendance.id, widget.userId);
    _breakService.addListener(_onBreakStateChanged);
  }

  @override
  void dispose() {
    _breakService.removeListener(_onBreakStateChanged);
    super.dispose();
  }

  void _onBreakStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Check if break was already taken today (from attendance record)
    if (widget.attendance.breakEndTime != null) {
      return _buildBreakCompletedCard(context);
    }

    // Listen to break service state
    if (_breakService.isOnBreak) {
      return _buildOnBreakCard(context);
    }

    if (_breakService.hasPendingRequest) {
      return _buildPendingRequestCard(context);
    }

    return _buildRequestBreakButton(context);
  }

  Widget _buildRequestBreakButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _showRequestBreakDialog(context),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.coffee, size: 24),
        label: Text(
          _isLoading ? 'جاري الإرسال...' : 'طلب استراحة',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildPendingRequestCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'بانتظار موافقة المدير',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'تم إرسال طلب الاستراحة\nسيتم إعلامك عند الموافقة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(height: 16),
          // Cancel button
          OutlinedButton.icon(
            onPressed: _isLoading ? null : _cancelBreakRequest,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('إلغاء الطلب'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
          // Listen for approval in real-time
          if (_breakService.pendingRequestId != null)
            StreamBuilder<DocumentSnapshot>(
              stream: _breakService.breakRequestStream(_breakService.pendingRequestId!),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final status = data['status'] as String?;

                  if (status == 'approved') {
                    // Auto-start break when approved
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _startApprovedBreak();
                    });
                  } else if (status == 'rejected') {
                    // Show rejection and reset
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _handleRejection(data['rejectionReason'] ?? 'لم يتم تحديد السبب');
                    });
                  }
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOnBreakCard(BuildContext context) {
    final isOvertime = _breakService.isOvertime;
    final backgroundColor = isOvertime ? Colors.red.shade100 : Colors.orange.shade100;
    final borderColor = isOvertime ? Colors.red : Colors.orange;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Icon and status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isOvertime ? Icons.warning_amber : Icons.coffee,
                color: borderColor,
                size: 32,
              ),
              const SizedBox(width: 8),
              Text(
                isOvertime ? 'تجاوزت وقت الاستراحة!' : 'في الاستراحة',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isOvertime ? Colors.red.shade800 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timer display
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isOvertime ? 'تجاوزت بـ' : 'الوقت المتبقي',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOvertime
                      ? '${_breakService.overtimeMinutes} دقيقة'
                      : _breakService.remainingTimeText,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: isOvertime ? Colors.red : Colors.black87,
                  ),
                ),
                if (!isOvertime) ...[
                  const SizedBox(height: 4),
                  Text(
                    'مضى: ${_breakService.elapsedTimeText}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // End break button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _endBreak,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.work),
              label: const Text(
                'إنهاء الاستراحة والعودة للعمل',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          if (isOvertime) ...[
            const SizedBox(height: 12),
            Text(
              'تم إبلاغ المدير بتجاوز وقت الاستراحة',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreakCompletedCard(BuildContext context) {
    final breakDuration = widget.attendance.totalBreakMinutes;
    final overtime = widget.attendance.breakOvertimeMinutes;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تم أخذ الاستراحة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'المدة: $breakDuration دقيقة${overtime > 0 ? ' (تجاوز: $overtime دقيقة)' : ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: overtime > 0 ? Colors.red.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestBreakDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.coffee, color: Colors.orange),
            SizedBox(width: 8),
            Text('طلب استراحة'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد إرسال طلب استراحة؟'),
            SizedBox(height: 12),
            Text(
              '• سيتم إرسال الطلب للمدير للموافقة',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              '• مدة الاستراحة: 60 دقيقة',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              '• لن يتم تنبيهك بالابتعاد خلال الاستراحة',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              '• سيتم تنبيهك قبل 5 دقائق من انتهائها',
              style: TextStyle(fontSize: 14),
            ),
            Text(
              '• سيتم إبلاغ المدير إذا تجاوزت الوقت',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _requestBreak();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestBreak() async {
    setState(() => _isLoading = true);

    final success = await _breakService.requestBreak(
      attendanceId: widget.attendance.id,
      userId: widget.userId,
      userName: widget.userName,
      storeId: widget.attendance.storeId,
      storeName: widget.attendance.storeName,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الاستراحة - بانتظار موافقة المدير'),
            backgroundColor: Colors.blue,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في إرسال طلب الاستراحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelBreakRequest() async {
    setState(() => _isLoading = true);
    await _breakService.cancelBreakRequest();
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إلغاء طلب الاستراحة'),
          backgroundColor: Colors.grey,
        ),
      );
    }
  }

  Future<void> _startApprovedBreak() async {
    await _breakService.startApprovedBreak(
      attendanceId: widget.attendance.id,
      userId: widget.userId,
      userName: widget.userName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تمت الموافقة! بدأت الاستراحة'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _handleRejection(String reason) {
    _breakService.reset();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم رفض طلب الاستراحة: $reason'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _endBreak() async {
    setState(() => _isLoading = true);
    final success = await _breakService.endBreak();
    setState(() => _isLoading = false);

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنهاء الاستراحة - عودة للعمل'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
