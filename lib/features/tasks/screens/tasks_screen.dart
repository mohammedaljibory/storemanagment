import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/task_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/models/task_model.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Stream<List<TaskModel>>? _tasksStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);  // 5 tabs including rejected

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final taskProvider = context.read<TaskProvider>();

      // Set up real-time stream
      if (authProvider.isAdmin) {
        _tasksStream = taskProvider.tasksStream(isAdmin: true);
      } else {
        _tasksStream = taskProvider.tasksStream(
          userId: authProvider.user!.id,
          isAdmin: false,
        );
      }
      setState(() {});

      // Also do initial fetch
      if (authProvider.isAdmin) {
        taskProvider.fetchTasks(isAdmin: true);
      } else {
        taskProvider.fetchTasks(
          userId: authProvider.user!.id,
          isAdmin: false,
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المهام',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (authProvider.isAdmin)
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, AppRoutes.createTask);
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppTheme.primaryGradient,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ).animate()
                  .fadeIn(duration: 600.ms)
                  .slideY(begin: -0.2, end: 0),

              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  isScrollable: true,  // Make tabs scrollable
                  indicator: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? AppTheme.secondaryGradient
                          : AppTheme.primaryGradient,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDarkMode ? Colors.white60 : Colors.black54,
                  tabs: const [
                    Tab(text: 'في الانتظار'),
                    Tab(text: 'قيد التنفيذ'),
                    Tab(text: 'بانتظار الموافقة'),
                    Tab(text: 'مرفوضة'),
                    Tab(text: 'مكتملة'),
                  ],
                ),
              ).animate()
                  .fadeIn(delay: 200.ms, duration: 600.ms)
                  .slideX(begin: -0.2, end: 0),

              const SizedBox(height: 20),

              Expanded(
                child: _tasksStream == null
                    ? const Center(child: CircularProgressIndicator())
                    : StreamBuilder<List<TaskModel>>(
                        stream: _tasksStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting &&
                              !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final tasks = snapshot.data ?? [];
                          final pendingTasks = tasks
                              .where((t) => t.status == TaskStatus.pending)
                              .toList();
                          final inProgressTasks = tasks
                              .where((t) => t.status == TaskStatus.inProgress)
                              .toList();
                          final waitingApprovalTasks = tasks
                              .where((t) => t.status == TaskStatus.waitingApproval)
                              .toList();
                          final rejectedTasks = tasks
                              .where((t) => t.status == TaskStatus.rejected)
                              .toList();
                          final completedTasks = tasks
                              .where((t) => t.status == TaskStatus.completed)
                              .toList();

                          return TabBarView(
                            controller: _tabController,
                            children: [
                              _buildTaskList(pendingTasks, TaskStatus.pending),
                              _buildTaskList(inProgressTasks, TaskStatus.inProgress),
                              _buildTaskList(waitingApprovalTasks, TaskStatus.waitingApproval),
                              _buildTaskList(rejectedTasks, TaskStatus.rejected),
                              _buildTaskList(completedTasks, TaskStatus.completed),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: authProvider.isAdmin
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, AppRoutes.createTask);
        },
        icon: const Icon(Icons.add),
        label: const Text('مهمة جديدة'),
        backgroundColor: AppTheme.primaryColor,
      ).animate()
          .fadeIn(delay: 600.ms)
          .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1, 1),
        curve: Curves.elasticOut,
      )
          : null,
    );
  }

  Widget _buildTaskList(List<TaskModel> tasks, TaskStatus status) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getStatusIcon(status),
              size: 80,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد مهام ${_getStatusText(status)}',
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
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return _buildTaskCard(tasks[index], index);
      },
    );
  }

  Widget _buildTaskCard(TaskModel task, int index) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            AppRoutes.taskDetail,
            arguments: task.id,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            _buildStatusBadge(task.status),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    task.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatDeadline(task.deadline),
                        style: TextStyle(
                          fontSize: 12,
                          color: task.isOverdue ? AppTheme.errorColor : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColors(task.priority)[0].withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.priorityText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _getPriorityColors(task.priority)[0],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Show multi-employee indicator
                  if (task.isMultiEmployee) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 14, color: AppTheme.secondaryColor),
                        const SizedBox(width: 4),
                        Text(
                          '${task.assignedToList.length} موظفين',
                          style: const TextStyle(fontSize: 11, color: AppTheme.secondaryColor),
                        ),
                      ],
                    ),
                  ],
                  // Show repeat indicator
                  if (task.isRepeating) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.repeat, size: 14, color: AppTheme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          task.repeatTypeText,
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: isDarkMode ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: index * 100), duration: 600.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case TaskStatus.pending:
        color = AppTheme.warningColor;
        icon = Icons.pending;
        break;
      case TaskStatus.inProgress:
        color = AppTheme.secondaryColor;
        icon = Icons.work_history;
        break;
      case TaskStatus.completed:
        color = AppTheme.successColor;
        icon = Icons.check_circle;
        break;
      case TaskStatus.failed:
        color = AppTheme.errorColor;
        icon = Icons.error;
        break;
      case TaskStatus.cancelled:
        color = AppTheme.errorColor;
        icon = Icons.cancel;
        break;
      case TaskStatus.waitingApproval:
        color = Colors.orange;
        icon = Icons.hourglass_top;
        break;
      case TaskStatus.rejected:
        color = Colors.red.shade900;
        icon = Icons.thumb_down;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.pending_actions;
      case TaskStatus.inProgress:
        return Icons.work_history;
      case TaskStatus.completed:
        return Icons.task_alt;
      case TaskStatus.failed:
        return Icons.error_outline;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
      case TaskStatus.waitingApproval:
        return Icons.hourglass_empty;
      case TaskStatus.rejected:
        return Icons.thumb_down_outlined;
    }
  }

  List<Color> _getPriorityColors(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.urgent:
        return [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.6)];
      case TaskPriority.high:
        return [AppTheme.warningColor, AppTheme.warningColor.withOpacity(0.6)];
      case TaskPriority.medium:
        return [AppTheme.secondaryColor, AppTheme.secondaryColor.withOpacity(0.6)];
      case TaskPriority.low:
        return [AppTheme.successColor, AppTheme.successColor.withOpacity(0.6)];
    }
  }

  String _getStatusText(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return 'في الانتظار';
      case TaskStatus.inProgress:
        return 'قيد التنفيذ';
      case TaskStatus.completed:
        return 'مكتملة';
      case TaskStatus.failed:
        return 'فاشلة';
      case TaskStatus.cancelled:
        return 'ملغية';
      case TaskStatus.waitingApproval:
        return 'بانتظار الموافقة';
      case TaskStatus.rejected:
        return 'مرفوضة';
    }
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);

    if (difference.isNegative) {
      return 'متأخر';
    } else if (difference.inHours < 1) {
      return 'خلال ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'خلال ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'غداً';
    } else if (difference.inDays < 7) {
      return 'خلال ${difference.inDays} أيام';
    } else {
      return '${deadline.day}/${deadline.month}/${deadline.year}';
    }
  }
}