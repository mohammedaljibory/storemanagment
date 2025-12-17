import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/models/task_model.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _noteController = TextEditingController();
  final _rejectReasonController = TextEditingController();
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _noteController.dispose();
    _rejectReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل في اختيار الصورة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassContainer(
        borderRadius: 25,
        margin: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Text(
              'اختر مصدر الصورة',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('الكاميرا'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.secondaryColor),
              title: const Text('المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForApproval(TaskModel task) async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب إرفاق صورة لإكمال المهمة'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await taskProvider.submitForApproval(
      task.id,
      completionNote: _noteController.text.trim(),
      completionImage: _selectedImage!.path,
      completedById: authProvider.user!.id,
      completedByName: authProvider.user!.name,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال المهمة للموافقة'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskProvider.errorMessage ?? 'فشل في إرسال المهمة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _approveTask(TaskModel task) async {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final success = await taskProvider.approveTask(task.id, authProvider.user!.id);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم قبول المهمة بنجاح'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskProvider.errorMessage ?? 'فشل في قبول المهمة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _showRejectDialog(TaskModel task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سبب الرفض'),
        content: TextField(
          controller: _rejectReasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'اكتب سبب رفض المهمة...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_rejectReasonController.text.isNotEmpty) {
                final taskProvider = context.read<TaskProvider>();
                final success = await taskProvider.rejectTask(
                  task.id,
                  _rejectReasonController.text,
                );
                Navigator.pop(context);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم رفض المهمة'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final authProvider = Provider.of<AuthProvider>(context);

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
          child: Consumer<TaskProvider>(
            builder: (context, taskProvider, _) {
              final task = taskProvider.getTaskById(widget.taskId);

              if (task == null) {
                return const Center(child: Text('المهمة غير موجودة'));
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
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
                        const Spacer(),
                        _buildPriorityBadge(task.priority),
                      ],
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),

                    const SizedBox(height: 20),

                    // Task Title & Status
                    GlassContainer(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _buildStatusChip(task.status),
                            ],
                          ),
                          const SizedBox(height: 15),
                          Text(task.description, style: Theme.of(context).textTheme.bodyLarge),
                          if (task.isRepeating) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.repeat, size: 16, color: AppTheme.secondaryColor),
                                  const SizedBox(width: 5),
                                  Text(task.repeatTypeText,
                                    style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                    const SizedBox(height: 20),

                    // Task Details
                    GlassContainer(
                      child: Column(
                        children: [
                          _buildDetailRow(Icons.calendar_today, 'تاريخ الإنشاء', 
                              _formatDateTime(task.createdAt), AppTheme.primaryColor),
                          const Divider(height: 30),
                          _buildDetailRow(Icons.alarm, 'الموعد النهائي',
                              _formatDateTime(task.deadline), 
                              task.isOverdue ? AppTheme.errorColor : AppTheme.warningColor),
                          const Divider(height: 30),
                          _buildDetailRow(Icons.timer, 'المدة القصوى',
                              task.maxDurationText, AppTheme.secondaryColor),
                          const Divider(height: 30),
                          _buildDetailRow(Icons.person, 
                              task.isMultiEmployee ? 'الموظفون المسؤولون' : 'الموظف المسؤول',
                              task.allAssignedNames, AppTheme.primaryColor),
                          if (task.completedByName != null) ...[
                            const Divider(height: 30),
                            _buildDetailRow(Icons.person_pin, 'أكمل بواسطة',
                                task.completedByName!, AppTheme.successColor),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                    // Admin Approval Section
                    if (authProvider.isAdmin && task.status == TaskStatus.waitingApproval) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.pending_actions, color: AppTheme.warningColor),
                                ),
                                const SizedBox(width: 12),
                                Text('بانتظار الموافقة',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 15),
                            if (task.completionImage != null && task.completionImage!.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Image.network(
                                  task.completionImage!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(height: 200, color: Colors.grey.shade300,
                                      child: const Center(child: CircularProgressIndicator()));
                                  },
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 200, color: Colors.grey.shade300,
                                    child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
                                ),
                              ),
                            if (task.completionNote != null && task.completionNote!.isNotEmpty) ...[
                              const SizedBox(height: 15),
                              Text('ملاحظات الموظف:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(task.completionNote!),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _approveTask(task),
                                    icon: const Icon(Icons.check),
                                    label: const Text('قبول'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.successColor,
                                      padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showRejectDialog(task),
                                    icon: const Icon(Icons.close),
                                    label: const Text('رفض'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.errorColor,
                                      padding: const EdgeInsets.symmetric(vertical: 12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    ],

                    // Employee Submit Section
                    if (!authProvider.isAdmin && 
                        task.status != TaskStatus.completed &&
                        task.status != TaskStatus.cancelled &&
                        task.status != TaskStatus.failed &&
                        task.status != TaskStatus.waitingApproval &&
                        task.status != TaskStatus.rejected) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إكمال المهمة',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            GestureDetector(
                              onTap: _showImageSourceDialog,
                              child: Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  border: Border.all(color: isDarkMode ? Colors.white30 : Colors.black26, width: 2),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: _selectedImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: Image.file(_selectedImage!, fit: BoxFit.cover, width: double.infinity))
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.cloud_upload_outlined, size: 50,
                                            color: isDarkMode ? Colors.white30 : Colors.black26),
                                          const SizedBox(height: 10),
                                          Text('اضغط لإرفاق صورة',
                                            style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'ملاحظات (اختياري)',
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                if (task.status == TaskStatus.pending)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await context.read<TaskProvider>().startTask(task.id);
                                      },
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('بدء التنفيذ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.secondaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                                if (task.status == TaskStatus.inProgress)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: taskProvider.isLoading ? null : () => _submitForApproval(task),
                                      icon: taskProvider.isLoading
                                          ? const SizedBox(width: 20, height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.send),
                                      label: const Text('إرسال للموافقة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.successColor,
                                        padding: const EdgeInsets.symmetric(vertical: 12)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms, duration: 600.ms),
                    ],

                    // Waiting Approval (Employee View)
                    if (!authProvider.isAdmin && task.status == TaskStatus.waitingApproval) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.warningColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.hourglass_top, color: AppTheme.warningColor, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('بانتظار موافقة المدير',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text('تم إرسال المهمة وبانتظار مراجعة المدير',
                                    style: Theme.of(context).textTheme.bodySmall),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Rejected Status
                    if (task.status == TaskStatus.rejected) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.cancel, color: AppTheme.errorColor),
                                const SizedBox(width: 10),
                                Text('تم رفض المهمة',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                              ],
                            ),
                            if (task.rejectionReason != null) ...[
                              const SizedBox(height: 10),
                              Text('السبب: ${task.rejectionReason}', style: Theme.of(context).textTheme.bodyLarge),
                            ],
                            if (!authProvider.isAdmin) ...[
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await context.read<TaskProvider>().updateTaskStatus(task.id, TaskStatus.inProgress);
                                    setState(() { _selectedImage = null; });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('إعادة المحاولة'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Completed Task Details
                    if (task.status == TaskStatus.completed && task.completionImage != null) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تفاصيل الإكمال',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: Image.network(
                                task.completionImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(height: 200, color: Colors.grey.shade300,
                                    child: const Center(child: CircularProgressIndicator()));
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 200, color: Colors.grey.shade300,
                                  child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey))),
                              ),
                            ),
                            if (task.completionNote != null && task.completionNote!.isNotEmpty) ...[
                              const SizedBox(height: 15),
                              Text('الملاحظات:', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 5),
                              Text(task.completionNote!, style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ],
                        ),
                      ).animate().fadeIn(delay: 800.ms, duration: 600.ms),
                    ],

                    // Failed Task
                    if (task.status == TaskStatus.failed) ...[
                      const SizedBox(height: 20),
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.error, color: AppTheme.errorColor),
                                const SizedBox(width: 10),
                                Text('المهمة فشلت',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold, color: AppTheme.errorColor)),
                              ],
                            ),
                            if (task.failureReason != null) ...[
                              const SizedBox(height: 10),
                              Text('السبب: ${task.failureReason}', style: Theme.of(context).textTheme.bodyLarge),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(TaskStatus status) {
    Color bgColor; Color textColor; String text;
    switch (status) {
      case TaskStatus.pending:
        bgColor = AppTheme.warningColor.withOpacity(0.2); textColor = AppTheme.warningColor; text = 'في الانتظار'; break;
      case TaskStatus.inProgress:
        bgColor = AppTheme.secondaryColor.withOpacity(0.2); textColor = AppTheme.secondaryColor; text = 'قيد التنفيذ'; break;
      case TaskStatus.waitingApproval:
        bgColor = Colors.orange.withOpacity(0.2); textColor = Colors.orange; text = 'بانتظار الموافقة'; break;
      case TaskStatus.completed:
        bgColor = AppTheme.successColor.withOpacity(0.2); textColor = AppTheme.successColor; text = 'مكتملة'; break;
      case TaskStatus.failed:
        bgColor = AppTheme.errorColor.withOpacity(0.2); textColor = AppTheme.errorColor; text = 'فاشلة'; break;
      case TaskStatus.cancelled:
        bgColor = AppTheme.errorColor.withOpacity(0.2); textColor = AppTheme.errorColor; text = 'ملغية'; break;
      case TaskStatus.rejected:
        bgColor = Colors.red.shade900.withOpacity(0.2); textColor = Colors.red.shade900; text = 'مرفوضة'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color; String text;
    switch (priority) {
      case TaskPriority.urgent: color = AppTheme.errorColor; text = 'عاجل'; break;
      case TaskPriority.high: color = AppTheme.warningColor; text = 'عالية'; break;
      case TaskPriority.medium: color = AppTheme.secondaryColor; text = 'متوسطة'; break;
      case TaskPriority.low: color = AppTheme.successColor; text = 'منخفضة'; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(20)),
      child: Text('الأولوية: $text', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year} - '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
