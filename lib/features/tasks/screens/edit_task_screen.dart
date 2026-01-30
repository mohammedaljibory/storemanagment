import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/models/task_model.dart';

class EditTaskScreen extends StatefulWidget {
  final TaskModel task;

  const EditTaskScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<EditTaskScreen> createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDeadline;
  late int _maxDurationMinutes;
  late TaskPriority _selectedPriority;
  late TaskRepeatType _selectedRepeatType;
  TimeOfDay? _repeatNotificationTime;
  late bool _repeatNotificationEnabled;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _selectedDeadline = widget.task.deadline;
    _maxDurationMinutes = widget.task.maxDurationMinutes;
    _selectedPriority = widget.task.priority;
    _selectedRepeatType = widget.task.repeatType;
    _repeatNotificationEnabled = widget.task.repeatNotificationEnabled;

    if (widget.task.repeatTime != null) {
      final parts = widget.task.repeatTime!.split(':');
      _repeatNotificationTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
                    Expanded(
                      child: Text(
                        'تعديل المهمة',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.task_alt,
                              'معلومات المهمة',
                              AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 20),
                            _buildTextField(
                              controller: _titleController,
                              label: 'عنوان المهمة',
                              icon: Icons.title,
                            ),
                            const SizedBox(height: 15),
                            _buildTextField(
                              controller: _descriptionController,
                              label: 'وصف المهمة',
                              icon: Icons.description,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Priority
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.flag,
                              'الأولوية',
                              AppTheme.warningColor,
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: TaskPriority.values.map((priority) {
                                return ChoiceChip(
                                  label: Text(_getPriorityText(priority)),
                                  selected: _selectedPriority == priority,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedPriority = priority);
                                    }
                                  },
                                  selectedColor: _getPriorityColor(priority).withOpacity(0.3),
                                  avatar: Icon(
                                    Icons.circle,
                                    size: 12,
                                    color: _getPriorityColor(priority),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Duration
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.timer,
                              'المدة القصوى',
                              AppTheme.secondaryColor,
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDurationChip(30, '30 دقيقة'),
                                _buildDurationChip(60, 'ساعة'),
                                _buildDurationChip(120, 'ساعتين'),
                                _buildDurationChip(180, '3 ساعات'),
                                _buildDurationChip(240, '4 ساعات'),
                                _buildDurationChip(480, '8 ساعات'),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Deadline
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.event,
                              'الموعد النهائي',
                              Colors.orange,
                            ),
                            const SizedBox(height: 15),
                            InkWell(
                              onTap: _selectDeadline,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, color: Colors.orange),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _formatDeadline(_selectedDeadline),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Repeat
                      GlassContainer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              Icons.repeat,
                              'تكرار المهمة',
                              AppTheme.accentColor,
                            ),
                            const SizedBox(height: 15),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: TaskRepeatType.values.map((repeatType) {
                                return ChoiceChip(
                                  label: Text(_getRepeatText(repeatType)),
                                  selected: _selectedRepeatType == repeatType,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedRepeatType = repeatType);
                                    }
                                  },
                                  selectedColor: AppTheme.accentColor.withOpacity(0.3),
                                );
                              }).toList(),
                            ),

                            // Notification time for repeating tasks
                            if (_selectedRepeatType != TaskRepeatType.none) ...[
                              const SizedBox(height: 20),
                              const Text(
                                'وقت الإشعار',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: _selectNotificationTime,
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: AppTheme.accentColor.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.access_time,
                                              size: 18,
                                              color: AppTheme.accentColor,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _repeatNotificationTime != null
                                                  ? '${_repeatNotificationTime!.hour.toString().padLeft(2, '0')}:${_repeatNotificationTime!.minute.toString().padLeft(2, '0')}'
                                                  : 'اختر الوقت',
                                              style: TextStyle(
                                                color: _repeatNotificationTime != null
                                                    ? AppTheme.accentColor
                                                    : Colors.grey,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                value: _repeatNotificationEnabled,
                                onChanged: (value) {
                                  setState(() => _repeatNotificationEnabled = value);
                                },
                                title: const Text('تفعيل الإشعارات عند التكرار'),
                                activeColor: AppTheme.primaryColor,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(isDarkMode),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _maxDurationMinutes == minutes;
    return GestureDetector(
      onTap: () => setState(() => _maxDurationMinutes = minutes),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade400,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.secondaryColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: BorderSide(
                    color: isDarkMode ? Colors.white30 : Colors.grey,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'حفظ التعديلات',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
      );
      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectNotificationTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _repeatNotificationTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (time != null) {
      setState(() => _repeatNotificationTime = time);
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.isEmpty || _descriptionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى ملء جميع الحقول'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? repeatTimeStr;
    if (_repeatNotificationTime != null && _selectedRepeatType != TaskRepeatType.none) {
      repeatTimeStr =
          '${_repeatNotificationTime!.hour.toString().padLeft(2, '0')}:${_repeatNotificationTime!.minute.toString().padLeft(2, '0')}';
    }

    final updatedTask = widget.task.copyWith(
      title: _titleController.text,
      description: _descriptionController.text,
      deadline: _selectedDeadline,
      maxDurationMinutes: _maxDurationMinutes,
      priority: _selectedPriority,
      repeatType: _selectedRepeatType,
      isRepeating: _selectedRepeatType != TaskRepeatType.none,
      nextRepeatDate: _selectedRepeatType != TaskRepeatType.none
          ? _calculateNextRepeatDate(_selectedDeadline, _selectedRepeatType)
          : null,
      repeatTime: repeatTimeStr,
      repeatNotificationEnabled: _repeatNotificationEnabled,
    );

    final taskProvider = context.read<TaskProvider>();
    final success = await taskProvider.updateTask(updatedTask);

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديث المهمة بنجاح'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taskProvider.errorMessage ?? 'فشل في تحديث المهمة'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  DateTime? _calculateNextRepeatDate(DateTime deadline, TaskRepeatType repeatType) {
    switch (repeatType) {
      case TaskRepeatType.daily:
        return deadline.add(const Duration(days: 1));
      case TaskRepeatType.weekly:
        return deadline.add(const Duration(days: 7));
      case TaskRepeatType.monthly:
        return DateTime(deadline.year, deadline.month + 1, deadline.day,
            deadline.hour, deadline.minute);
      case TaskRepeatType.yearly:
        return DateTime(deadline.year + 1, deadline.month, deadline.day,
            deadline.hour, deadline.minute);
      case TaskRepeatType.none:
        return null;
    }
  }

  String _formatDeadline(DateTime deadline) {
    return '${deadline.day}/${deadline.month}/${deadline.year} - '
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'منخفضة';
      case TaskPriority.medium:
        return 'متوسطة';
      case TaskPriority.high:
        return 'عالية';
      case TaskPriority.urgent:
        return 'عاجلة';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return AppTheme.successColor;
      case TaskPriority.medium:
        return AppTheme.secondaryColor;
      case TaskPriority.high:
        return AppTheme.warningColor;
      case TaskPriority.urgent:
        return AppTheme.errorColor;
    }
  }

  String _getRepeatText(TaskRepeatType repeatType) {
    switch (repeatType) {
      case TaskRepeatType.none:
        return 'لا يتكرر';
      case TaskRepeatType.daily:
        return 'يومياً';
      case TaskRepeatType.weekly:
        return 'أسبوعياً';
      case TaskRepeatType.monthly:
        return 'شهرياً';
      case TaskRepeatType.yearly:
        return 'سنوياً';
    }
  }
}
