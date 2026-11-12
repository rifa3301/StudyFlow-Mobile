
import 'package:flutter/material.dart';
import 'api_service.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  int currentPage = 1;
  final int pageSize = 2;

  late Future<Map<String, dynamic>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    _tasksFuture = ApiService.getTasks(
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

  String _formatDate(String? date) {
    if (date == null) {
      return 'No due date';
    }

    final parsedDate = DateTime.parse(date).toLocal();

    return '${parsedDate.day.toString().padLeft(2, '0')}/'
        '${parsedDate.month.toString().padLeft(2, '0')}/'
        '${parsedDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
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
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load tasks.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refreshTasks,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final List<Map<String, dynamic>> tasks =
          data['tasks'];

          final pagination =
          data['pagination'];

          final int totalPages =
          pagination['totalPages'];

          final int totalTasks =
          pagination['totalTasks'];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Total Tasks: $totalTasks',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              Expanded(
                child: tasks.isEmpty
                    ? const Center(
                  child: Text(
                    'No tasks found. Create your first task!',
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    return Card(
                      margin: const EdgeInsets.only(
                        bottom: 12,
                      ),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.all(16),

                        title: Text(
                          task['title'] ?? 'Untitled Task',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        subtitle: Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject: ${task['subject'] ?? 'N/A'}',
                              ),
                              Text(
                                'Priority: ${task['priority'] ?? 'N/A'}',
                              ),
                              Text(
                                'Status: ${task['status'] ?? 'pending'}',
                              ),
                              Text(
                                'Due: ${_formatDate(task['due_date'])}',
                              ),
                              if ((task['description'] ?? '')
                                  .isNotEmpty)
                                Text(
                                  'Description: ${task['description']}',
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Pagination controls
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: currentPage > 1
                          ? () => _goToPage(currentPage - 1)
                          : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    ),

                    Text(
                      'Page $currentPage of $totalPages',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: currentPage < totalPages
                          ? () => _goToPage(currentPage + 1)
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
