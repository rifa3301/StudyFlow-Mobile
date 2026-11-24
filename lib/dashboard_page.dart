import 'package:flutter/material.dart';

import 'api_service.dart';
import 'task_page.dart';
import 'task_list_page.dart';
import 'resources_page.dart';
import 'progress_page.dart';
import 'core/theme/app_colors.dart';

class DashboardPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const DashboardPage({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _tasks = [];

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  // --------------------------------------------------
  // Dashboard data
  // --------------------------------------------------

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.getTasks(
        token: widget.token,
        page: 1,
        limit: 50,
      );

      if (!mounted) return;

      final tasks = List<Map<String, dynamic>>.from(
        result['tasks'] ?? [],
      );

      int completed = 0;
      int pending = 0;

      for (final task in tasks) {
        final status = task['status']?.toString().toLowerCase();

        if (status == 'completed' || status == 'complete') {
          completed++;
        } else {
          pending++;
        }
      }

      final pagination = result['pagination'];

      setState(() {
        _tasks = tasks;

        _totalTasks = pagination is Map
            ? (pagination['totalTasks'] as num?)?.toInt() ??
            tasks.length
            : tasks.length;

        _completedTasks = completed;
        _pendingTasks = pending;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load your tasks. Please try again.';
      });
    }
  }

  // --------------------------------------------------
  // User information
  // --------------------------------------------------

  String get _userName {
    final fullName = widget.user['full_name']?.toString().trim();

    if (fullName == null || fullName.isEmpty) {
      return 'there';
    }

    return fullName.split(' ').first;
  }

  String get _greeting {
    final hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';

    return 'Good evening';
  }

  String get _currentDate {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final now = DateTime.now();

    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  // --------------------------------------------------
  // Date and task helpers
  // --------------------------------------------------

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());

    return parsed?.toLocal();
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date == null) return 'No due date';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool _isOverdue(Map<String, dynamic> task) {
    final status = task['status']?.toString().toLowerCase();

    if (status == 'completed' || status == 'complete') {
      return false;
    }

    final dueDate = _parseDate(task['due_date']);

    if (dueDate == null) return false;

    return dueDate.isBefore(DateTime.now());
  }

  List<Map<String, dynamic>> get _overdueTasks {
    final overdue = _tasks.where(_isOverdue).toList();

    overdue.sort((a, b) {
      final dateA = _parseDate(a['due_date']);
      final dateB = _parseDate(b['due_date']);

      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return overdue;
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

  // --------------------------------------------------
  // Navigation
  // --------------------------------------------------

  void _onNavigationSelected(int index) {
    if (index == _selectedIndex) {
      if (index == 0) {
        _loadDashboard();
      }
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      _loadDashboard();
    }
  }

  void _openCreateTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskPage(token: widget.token),
      ),
    ).then((_) {
      if (mounted) {
        _loadDashboard();
      }
    });
  }

  void _openAllTasks() {
    setState(() {
      _selectedIndex = 1;
    });
  }

  // --------------------------------------------------
  // Main layout
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: _buildSelectedPage(),
      ),
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryLight,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onNavigationSelected,
        labelBehavior:
        NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Planner',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Resources',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Selected page
  // --------------------------------------------------

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomePage();

      case 1:
        return TaskListPage(token: widget.token);

      case 2:
        return ResourcesPage(token: widget.token);

      case 3:
        return ProgressPage(token: widget.token);

      case 4:
        return _buildComingSoonPage(
          title: 'Profile',
          subtitle: 'Your account and personal settings will appear here.',
          icon: Icons.person_outline_rounded,
        );

      default:
        return _buildHomePage();
    }
  }

  // --------------------------------------------------
  // Home page
  // --------------------------------------------------

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              22,
              27,
              22,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverview(),
                const SizedBox(height: 30),
                _buildTaskSection(),
                const SizedBox(height: 30),
                _buildQuickActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Header
  // --------------------------------------------------

  Widget _buildHeader() {
    return Container(
      height: 255,
      width: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            'assets/images/dashboard_background.jpg',
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primaryDark.withValues(alpha: 0.45),
              AppColors.primaryDark.withValues(alpha: 0.90),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/studyflow_icon.png',
                  width: 35,
                  height: 35,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 11),
                const Text(
                  'StudyFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadDashboard,
                  tooltip: 'Refresh dashboard',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 23,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              _currentDate.toUpperCase(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$_greeting, $_userName.',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your study space, organized.',
              style: TextStyle(
                color: Color(0xFFD7DEED),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Overview
  // --------------------------------------------------

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your overview',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Total',
                value: _totalTasks,
                icon: Icons.assignment_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Completed',
                value: _completedTasks,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildStatCard(
                label: 'Pending',
                value: _pendingTasks,
                icon: Icons.pending_actions_rounded,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    Color color = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 17,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 21,
          ),
          const SizedBox(height: 14),
          Text(
            _isLoading ? '—' : '$value',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Task section
  // --------------------------------------------------

  Widget _buildTaskSection() {
    final overdue = _overdueTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                overdue.isNotEmpty
                    ? 'Overdue tasks'
                    : 'Your tasks',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            TextButton(
              onPressed: _openAllTasks,
              child: const Text(
                'View all',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (overdue.isNotEmpty && !_isLoading) ...[
          const SizedBox(height: 2),
          const Text(
            'These tasks have passed their due dates.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 13),
        _buildTaskContent(),
      ],
    );
  }

  Widget _buildTaskContent() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(35),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not load tasks',
        message: _errorMessage!,
        actionText: 'Try again',
        onPressed: _loadDashboard,
      );
    }

    if (_tasks.isEmpty) {
      return _buildEmptyState(
        icon: Icons.note_add_outlined,
        title: 'No tasks yet',
        message:
        'Create your first task to start organizing your study schedule.',
        actionText: 'Create your first task',
        onPressed: _openCreateTask,
      );
    }

    final displayTasks = _overdueTasks.isNotEmpty
        ? _overdueTasks.take(3).toList()
        : _tasks.take(3).toList();

    return Column(
      children: displayTasks.map((task) {
        return _buildTaskCard(task);
      }).toList(),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final title = task['title']?.toString() ?? 'Untitled task';
    final subject = task['subject']?.toString() ?? 'No subject';
    final priority = task['priority']?.toString() ?? 'Normal';
    final status = task['status']?.toString() ?? 'pending';

    final overdue = _isOverdue(task);
    final priorityColor = _priorityColor(priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: overdue
              ? AppColors.error.withValues(alpha: 0.35)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.menu_book_outlined,
                size: 15,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: overdue
                    ? AppColors.error
                    : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(task['due_date']),
                style: TextStyle(
                  color: overdue
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: overdue
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              const Spacer(),
              Text(
                overdue ? 'Overdue' : status,
                style: TextStyle(
                  color: overdue
                      ? AppColors.error
                      : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Empty states
  // --------------------------------------------------

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 27,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.secondary,
            size: 32,
          ),
          const SizedBox(height: 13),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          if (actionText != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onPressed,
              child: Text(actionText),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Quick actions
  // --------------------------------------------------

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_rounded,
                title: 'New task',
                subtitle: 'Add something to do',
                onTap: _openCreateTask,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.format_list_bulleted_rounded,
                title: 'All tasks',
                subtitle: 'View your task list',
                onTap: _openAllTasks,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 23,
              ),
              const SizedBox(height: 15),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Temporary pages
  // --------------------------------------------------

  Widget _buildComingSoonPage({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}