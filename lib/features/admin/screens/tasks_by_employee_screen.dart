import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/employee_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/models/task_model.dart';
import '../../../core/models/user_model.dart';

class TasksByEmployeeScreen extends StatefulWidget {
  const TasksByEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<TasksByEmployeeScreen> createState() => _TasksByEmployeeScreenState();
}

class _TasksByEmployeeScreenState extends State<TasksByEmployeeScreen> {
  String? _expandedEmployeeId;
  Stream<List<TaskModel>>? _tasksStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchEmployees();
      final taskProvider = context.read<TaskProvider>();
      taskProvider.fetchTasks(isAdmin: true);
      _tasksStream = taskProvider.tasksStream(isAdmin: true);
      setState(() {});
    });
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
              _buildHeader(context),
              Expanded(
                child: _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'المهام حسب الموظفين',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'تصنيف المهام بحسب كل موظف',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppTheme.primaryGradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.people, color: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildContent(BuildContext context) {
    final employeeProvider = context.watch<EmployeeProvider>();
    final employees = employeeProvider.activeEmployees;

    if (_tasksStream == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<TaskModel>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];

        // Group tasks by employee
        final Map<String, List<TaskModel>> tasksByEmployee = {};
        for (var task in tasks) {
          for (var employeeId in task.assignedToList) {
            tasksByEmployee.putIfAbsent(employeeId, () => []);
            tasksByEmployee[employeeId]!.add(task);
          }
        }

        // Calculate summary
        final totalPending = tasks.where((t) => t.status == TaskStatus.pending).length;
        final totalInProgress = tasks.where((t) => t.status == TaskStatus.inProgress).length;
        final totalCompleted = tasks.where((t) => t.status == TaskStatus.completed).length;

        return Column(
          children: [
            // Summary Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GlassContainer(
                padding: const EdgeInsets.all(15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('في الانتظار', totalPending, AppTheme.warningColor),
                    Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                    _buildSummaryItem('قيد التنفيذ', totalInProgress, AppTheme.secondaryColor),
                    Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
                    _buildSummaryItem('مكتملة', totalCompleted, AppTheme.successColor),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 600.ms).slideY(begin: 0.2, end: 0),
            ),
            const SizedBox(height: 20),
            // Employees List
            Expanded(
              child: employees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 80,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'لا يوجد موظفون',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee = employees[index];
                        final employeeTasks = tasksByEmployee[employee.id] ?? [];
                        return _buildEmployeeCard(context, employee, employeeTasks, index);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildEmployeeCard(BuildContext context, UserModel employee, List<TaskModel> tasks, int index) {
    final isExpanded = _expandedEmployeeId == employee.id;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Task counts by status
    final pending = tasks.where((t) => t.status == TaskStatus.pending).length;
    final inProgress = tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final waitingApproval = tasks.where((t) => t.status == TaskStatus.waitingApproval).length;
    final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
    final overdue = tasks.where((t) => t.isOverdue).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Employee Header
            InkWell(
              onTap: () {
                setState(() {
                  _expandedEmployeeId = isExpanded ? null : employee.id;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: Text(
                        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employee.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  employee.storeName ?? 'غير محدد',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Task count badges
                    Row(
                      children: [
                        if (overdue > 0)
                          _buildCountBadge(overdue, AppTheme.errorColor),
                        if (pending > 0 || inProgress > 0)
                          _buildCountBadge(pending + inProgress, AppTheme.warningColor),
                        if (waitingApproval > 0)
                          _buildCountBadge(waitingApproval, Colors.orange),
                      ],
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Expanded Task List
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildTasksList(context, tasks),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildCountBadge(int count, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTasksList(BuildContext context, List<TaskModel> tasks) {
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.task_outlined,
                size: 40,
                color: Colors.grey.withOpacity(0.5),
              ),
              const SizedBox(height: 10),
              Text(
                'لا توجد مهام مسندة',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort tasks: overdue first, then by deadline
    tasks.sort((a, b) {
      if (a.isOverdue && !b.isOverdue) return -1;
      if (!a.isOverdue && b.isOverdue) return 1;
      return a.deadline.compareTo(b.deadline);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Divider(height: 1),
          ...tasks.take(5).map((task) => _buildTaskItem(context, task)).toList(),
          if (tasks.length > 5)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'و ${tasks.length - 5} مهام أخرى',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TaskModel task) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.taskDetail, arguments: task.id);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 8,
              height: 40,
              decoration: BoxDecoration(
                color: _getStatusColor(task.status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        task.timeRemainingText,
                        style: TextStyle(
                          fontSize: 11,
                          color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Priority badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getPriorityColor(task.priority).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.priorityText,
                style: TextStyle(
                  fontSize: 10,
                  color: _getPriorityColor(task.priority),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return AppTheme.warningColor;
      case TaskStatus.inProgress:
        return AppTheme.secondaryColor;
      case TaskStatus.completed:
        return AppTheme.successColor;
      case TaskStatus.failed:
      case TaskStatus.cancelled:
        return AppTheme.errorColor;
      case TaskStatus.waitingApproval:
        return Colors.orange;
      case TaskStatus.rejected:
        return Colors.red.shade900;
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return AppTheme.errorColor;
      case TaskPriority.high:
        return AppTheme.warningColor;
      case TaskPriority.medium:
        return AppTheme.secondaryColor;
      case TaskPriority.low:
        return AppTheme.successColor;
    }
  }
}
