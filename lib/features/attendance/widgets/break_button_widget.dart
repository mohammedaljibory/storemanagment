import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/break_service.dart';
import '../../../core/models/attendance_model.dart';

/// Break button widget with countdown timer
/// Shows during active attendance - allows 1 hour break
class BreakButtonWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: BreakService(),
      child: Consumer<BreakService>(
        builder: (context, breakService, _) {
          if (breakService.isOnBreak) {
            return _buildOnBreakCard(context, breakService);
          } else {
            return _buildStartBreakButton(context, breakService);
          }
        },
      ),
    );
  }

  Widget _buildStartBreakButton(BuildContext context, BreakService breakService) {
    // Check if already took break today
    if (attendance.breakEndTime != null) {
      return _buildBreakCompletedCard(context);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _showStartBreakDialog(context, breakService),
        icon: const Icon(Icons.coffee, size: 24),
        label: const Text(
          'بدء الاستراحة',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  Widget _buildOnBreakCard(BuildContext context, BreakService breakService) {
    final isOvertime = breakService.isOvertime;
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
                      ? '${breakService.overtimeMinutes} دقيقة'
                      : breakService.remainingTimeText,
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
                    'مضى: ${breakService.elapsedTimeText}',
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
              onPressed: () => _endBreak(context, breakService),
              icon: const Icon(Icons.work),
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
    final breakDuration = attendance.totalBreakMinutes;
    final overtime = attendance.breakOvertimeMinutes;

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

  void _showStartBreakDialog(BuildContext context, BreakService breakService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.coffee, color: Colors.orange),
            SizedBox(width: 8),
            Text('بدء الاستراحة'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد بدء الاستراحة؟'),
            SizedBox(height: 12),
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
              _startBreak(context, breakService);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('بدء الاستراحة'),
          ),
        ],
      ),
    );
  }

  Future<void> _startBreak(BuildContext context, BreakService breakService) async {
    final success = await breakService.startBreak(
      attendanceId: attendance.id,
      userId: userId,
      userName: userName,
    );

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بدأت الاستراحة - لديك 60 دقيقة'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل في بدء الاستراحة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _endBreak(BuildContext context, BreakService breakService) async {
    final success = await breakService.endBreak();

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء الاستراحة - عودة للعمل'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
