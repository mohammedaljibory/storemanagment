import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/store_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/store_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDeadline = DateTime.now().add(const Duration(hours: 4));
  int _maxDurationMinutes = 60;
  TaskPriority _selectedPriority = TaskPriority.medium;
  StoreModel? _selectedStore;
  
  // NEW: Multi-employee selection
  List<UserModel> _selectedEmployees = [];
  
  // NEW: Repeat options
  TaskRepeatType _selectedRepeatType = TaskRepeatType.none;

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
                      icon: const Icon(Icons.arrow_back_ios),
                    ),
                    Expanded(
                      child: Text(
                        'إنشاء مهمة جديدة',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        GlassContainer(
                          child: TextFormField(
                            controller: _titleController,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المهمة',
                              prefixIcon: Icon(Icons.title),
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال عنوان المهمة';
                              }
                              return null;
                            },
                          ),
                        ).animate().fadeIn(delay: 100.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // Description
                        GlassContainer(
                          child: TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'وصف المهمة',
                              prefixIcon: Icon(Icons.description),
                              alignLabelWithHint: true,
                              border: InputBorder.none,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'يرجى إدخال وصف المهمة';
                              }
                              return null;
                            },
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // Store Selection
                        Consumer<StoreProvider>(
                          builder: (context, storeProvider, _) {
                            return GlassContainer(
                              child: DropdownButtonFormField<StoreModel>(
                                value: _selectedStore,
                                decoration: const InputDecoration(
                                  labelText: 'المتجر',
                                  prefixIcon: Icon(Icons.store),
                                  border: InputBorder.none,
                                ),
                                items: storeProvider.activeStores.map((store) {
                                  return DropdownMenuItem(
                                    value: store,
                                    child: Text(store.name),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedStore = value;
                                    _selectedEmployees = [];
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'يرجى اختيار المتجر';
                                  }
                                  return null;
                                },
                              ),
                            );
                          },
                        ).animate().fadeIn(delay: 300.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // NEW: Multi-Employee Selection
                        if (_selectedStore != null)
                          Consumer<EmployeeProvider>(
                            builder: (context, employeeProvider, _) {
                              final employees = employeeProvider
                                  .getEmployeesByStore(_selectedStore!.id);
                              return GlassContainer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.people, color: Colors.grey),
                                        const SizedBox(width: 12),
                                        Text(
                                          'الموظفين المسؤولين',
                                          style: Theme.of(context).textTheme.titleMedium,
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              if (_selectedEmployees.length == employees.length) {
                                                _selectedEmployees = [];
                                              } else {
                                                _selectedEmployees = List.from(employees);
                                              }
                                            });
                                          },
                                          child: Text(
                                            _selectedEmployees.length == employees.length
                                                ? 'إلغاء الكل'
                                                : 'تحديد الكل',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: employees.map((emp) {
                                        final isSelected = _selectedEmployees.contains(emp);
                                        return FilterChip(
                                          label: Text(emp.name),
                                          selected: isSelected,
                                          onSelected: (selected) {
                                            setState(() {
                                              if (selected) {
                                                _selectedEmployees.add(emp);
                                              } else {
                                                _selectedEmployees.remove(emp);
                                              }
                                            });
                                          },
                                          selectedColor: AppTheme.primaryColor.withOpacity(0.3),
                                          checkmarkColor: AppTheme.primaryColor,
                                        );
                                      }).toList(),
                                    ),
                                    if (_selectedEmployees.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'يرجى اختيار موظف واحد على الأقل',
                                          style: TextStyle(
                                            color: Colors.red.shade300,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ).animate().fadeIn(delay: 400.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // Priority Selection
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.flag, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    'الأولوية',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: TaskPriority.values.map((priority) {
                                  return ChoiceChip(
                                    label: Text(_getPriorityText(priority)),
                                    selected: _selectedPriority == priority,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedPriority = priority;
                                        });
                                      }
                                    },
                                    selectedColor: _getPriorityColor(priority).withOpacity(0.3),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // Duration Selection
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timer, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    'المدة القصوى',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
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
                        ).animate().fadeIn(delay: 600.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // Deadline
                        GlassContainer(
                          child: InkWell(
                            onTap: () => _selectDeadline(context),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'الموعد النهائي',
                                prefixIcon: Icon(Icons.event),
                                border: InputBorder.none,
                              ),
                              child: Text(
                                _formatDeadline(_selectedDeadline),
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
                        ).animate().fadeIn(delay: 700.ms, duration: 600.ms),

                        const SizedBox(height: 16),

                        // NEW: Repeat Selection
                        GlassContainer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.repeat, color: Colors.grey),
                                  const SizedBox(width: 12),
                                  Text(
                                    'تكرار المهمة',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: TaskRepeatType.values.map((repeatType) {
                                  return ChoiceChip(
                                    label: Text(_getRepeatText(repeatType)),
                                    selected: _selectedRepeatType == repeatType,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedRepeatType = repeatType;
                                        });
                                      }
                                    },
                                    selectedColor: AppTheme.secondaryColor.withOpacity(0.3),
                                  );
                                }).toList(),
                              ),
                              if (_selectedRepeatType != TaskRepeatType.none)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline, 
                                            size: 18, color: AppTheme.secondaryColor),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'ستتكرر هذه المهمة ${_getRepeatText(_selectedRepeatType)} بعد الموافقة عليها',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.secondaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

                        const SizedBox(height: 32),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: Consumer<TaskProvider>(
                            builder: (context, taskProvider, _) {
                              return ElevatedButton(
                                onPressed: taskProvider.isLoading || _selectedEmployees.isEmpty
                                    ? null
                                    : _submitTask,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: taskProvider.isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'إنشاء المهمة',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              );
                            },
                          ),
                        ).animate().fadeIn(delay: 900.ms, duration: 600.ms),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _maxDurationMinutes == minutes;
    return GestureDetector(
      onTap: () {
        setState(() {
          _maxDurationMinutes = minutes;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.2)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDeadline(BuildContext context) async {
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

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    String dateStr = '${deadline.day}/${deadline.month}/${deadline.year}';
    String timeStr =
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';

    if (diff.inDays == 0) {
      return 'اليوم $timeStr';
    } else if (diff.inDays == 1) {
      return 'غداً $timeStr';
    } else {
      return '$dateStr - $timeStr';
    }
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

  // NEW: Get repeat text
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

  Future<void> _submitTask() async {
    if (_formKey.currentState!.validate() && _selectedEmployees.isNotEmpty) {
      final authProvider = context.read<AuthProvider>();

      // Get first employee as primary (for backward compatibility)
      final primaryEmployee = _selectedEmployees.first;

      final task = TaskModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descriptionController.text,
        storeId: _selectedStore!.id,
        storeName: _selectedStore!.name,
        assignedTo: primaryEmployee.id,
        assignedToName: primaryEmployee.name,
        assignedToList: _selectedEmployees.map((e) => e.id).toList(),
        assignedToNamesList: _selectedEmployees.map((e) => e.name).toList(),
        assignedBy: authProvider.user!.id,
        assignedByName: authProvider.user!.name,
        createdAt: DateTime.now(),
        deadline: _selectedDeadline,
        maxDurationMinutes: _maxDurationMinutes,
        status: TaskStatus.pending,
        priority: _selectedPriority,
        repeatType: _selectedRepeatType,
        isRepeating: _selectedRepeatType != TaskRepeatType.none,
        nextRepeatDate: _selectedRepeatType != TaskRepeatType.none
            ? _calculateNextRepeatDate(_selectedDeadline, _selectedRepeatType)
            : null,
      );

      final success = await context.read<TaskProvider>().createTask(task);

      if (context.mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _selectedEmployees.length > 1
                    ? 'تم إنشاء المهمة لـ ${_selectedEmployees.length} موظفين'
                    : 'تم إنشاء المهمة بنجاح',
              ),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.read<TaskProvider>().errorMessage ?? 'فشل في إنشاء المهمة'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
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
}
