import 'package:flutter/material.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';

class TaskListPage extends StatefulWidget {
  final String token;

  const TaskListPage({
    super.key,
    required this.token,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  int currentPage = 1;
  final int pageSize = 2;

  late Future<Map<String, dynamic>> _tasksFuture;

  // Tracks tasks currently being updated or deleted.
  final Set<int> _busyTaskIds = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    _tasksFuture = ApiService.getTasksGraphQL(
      token: widget.token,
      page: currentPage,
      limit: pageSize,
    );
  }

  void _refreshTasks() {
    setState(() {
      _loadTasks();
    });
  }

  void _goToPage(int page) {
    setState(() {
      currentPage = page;
      _loadTasks();
    });
  }

  int? _getTaskId(Map<String, dynamic> task) {
    return int.tryParse(task['task_id']?.toString() ?? '');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Future<void> _updateTaskStatus(
      Map<String, dynamic> task,
      bool completed,
      ) async {
    final taskId = _getTaskId(task);

    if (taskId == null) {
      _showMessage('Could not identify this task.');
      return;
    }

    if (_busyTaskIds.contains(taskId)) return;

    setState(() {
      _busyTaskIds.add(taskId);
    });

    try {
      await ApiService.updateTaskStatus(
        token: widget.token,
        taskId: taskId,
        status: completed ? 'completed' : 'pending',
      );

      if (!mounted) return;

      _showMessage(
        completed
            ? 'Task marked as completed!'
            : 'Task marked as pending.',
      );

      setState(() {
        _busyTaskIds.remove(taskId);
        _loadTasks();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busyTaskIds.remove(taskId);
      });

      _showMessage('Could not update task: $error');
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final taskId = _getTaskId(task);

    if (taskId == null) {
      _showMessage('Could not identify this task.');
      return;
    }

    final title = task['title']?.toString() ?? 'this task';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text(
            'Are you sure you want to delete "$title"? '
                'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    if (_busyTaskIds.contains(taskId)) return;

    setState(() {
      _busyTaskIds.add(taskId);
    });

    try {
      await ApiService.deleteTask(
        token: widget.token,
        taskId: taskId,
      );

      if (!mounted) return;

      _showMessage('Task deleted successfully!');

      // Reload the current page.
      setState(() {
        _busyTaskIds.remove(taskId);
        _loadTasks();
      });

      final updatedData = await _tasksFuture;

      final updatedTasks =
      List<dynamic>.from(updatedData['tasks'] ?? []);

      // If the current page became empty, go back one page.
      if (updatedTasks.isEmpty && currentPage > 1 && mounted) {
        setState(() {
          currentPage--;
          _loadTasks();
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _busyTaskIds.remove(taskId);
      });

      _showMessage('Could not delete task: $error');
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) {
      return 'No due date';
    }

    final date = DateTime.tryParse(value.toString());

    if (date == null) {
      return 'Invalid date';
    }

    final localDate = date.toLocal();

    return '${localDate.day.toString().padLeft(2, '0')}/'
        '${localDate.month.toString().padLeft(2, '0')}/'
        '${localDate.year}';
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      case 'low':
        return AppColors.success;
      default:
        return AppColors.secondary;
    }
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final taskId = _getTaskId(task);

    final title = task['title']?.toString() ?? 'Untitled Task';
    final subject = task['subject']?.toString() ?? 'N/A';
    final priority = task['priority']?.toString() ?? 'N/A';
    final status = task['status']?.toString() ?? 'pending';
    final description = task['description']?.toString() ?? '';

    final isCompleted = status.toLowerCase() == 'completed';
    final isBusy = taskId != null && _busyTaskIds.contains(taskId);

    final priorityColor = _priorityColor(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildDetailRow(
              Icons.menu_book_outlined,
              subject,
            ),

            const SizedBox(height: 8),

            _buildDetailRow(
              Icons.calendar_today_outlined,
              'Due: ${_formatDate(task['due_date'])}',
            ),

            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],

            const Divider(height: 24),

            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (isBusy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      else
                        Checkbox(
                          value: isCompleted,
                          activeColor: AppColors.primary,
                          onChanged: taskId == null
                              ? null
                              : (value) {
                            _updateTaskStatus(
                              task,
                              value ?? false,
                            );
                          },
                        ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isCompleted ? 'Completed' : 'Mark as complete',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isBusy
                      ? null
                      : () => _deleteTask(task),
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.error,
                  tooltip: 'Delete task',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.secondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_outlined,
              size: 55,
              color: AppColors.secondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tasks yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your tasks will appear here once you create them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Could not load your tasks',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshTasks,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'My Tasks',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshTasks,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh tasks',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error!);
          }

          if (!snapshot.hasData) {
            return _buildEmptyState();
          }

          final data = snapshot.data!;

          final List<dynamic> taskData = data['tasks'] ?? [];

          final tasks = taskData
              .map(
                (task) => Map<String, dynamic>.from(task),
          )
              .toList();

          final pagination =
          Map<String, dynamic>.from(data['pagination'] ?? {});

          final totalPages =
              (pagination['totalPages'] as num?)?.toInt() ?? 0;

          final totalTasks =
              (pagination['totalTasks'] as num?)?.toInt() ?? 0;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your task collection',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$totalTasks ${totalTasks == 1 ? 'Task' : 'Tasks'}',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskCard(tasks[index]);
                  },
                ),
              ),

              if (totalPages > 0)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton.icon(
                          onPressed: currentPage > 1
                              ? () => _goToPage(currentPage - 1)
                              : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        ),

                        Text(
                          'Page $currentPage of $totalPages',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        OutlinedButton.icon(
                          onPressed: currentPage < totalPages
                              ? () => _goToPage(currentPage + 1)
                              : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}