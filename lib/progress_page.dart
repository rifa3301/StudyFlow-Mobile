import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'api_service.dart';
import 'core/theme/app_colors.dart';

class ProgressPage extends StatefulWidget {
  final String token;

  const ProgressPage({
    super.key,
    required this.token,
  });

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  bool _isLoading = true;
  String? _errorMessage;

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _pendingTasks = 0;

  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);

    _loadProgress();
  }

  Future<void> _loadProgress() async {
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

      final tasks = List<Map<String, dynamic>>.from(
        result['tasks'] ?? [],
      );

      int completed = 0;
      int pending = 0;

      for (final task in tasks) {
        final status = task['status']
            ?.toString()
            .toLowerCase();

        if (status == 'completed' || status == 'complete') {
          completed++;
        } else {
          pending++;
        }
      }

      if (!mounted) return;

      setState(() {
        _totalTasks = completed + pending;
        _completedTasks = completed;
        _pendingTasks = pending;
        _isLoading = false;
      });

      await _loadAnimatedChart();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
        'Unable to load your progress. Please try again.';
      });
    }
  }

  Future<void> _loadAnimatedChart() async {
    final percentage = _totalTasks == 0
        ? 0.0
        : (_completedTasks / _totalTasks) * 100;

    final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * {
    box-sizing: border-box;
  }

  body {
    margin: 0;
    padding: 12px;
    background: #FFFFFF;
    font-family: Arial, sans-serif;
    overflow: hidden;
  }

  .container {
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 30px;
    min-height: 190px;
  }

  .chart {
    position: relative;
    width: 165px;
    height: 165px;
    flex-shrink: 0;
  }

  svg {
    transform: rotate(-90deg);
    width: 165px;
    height: 165px;
  }

  circle {
    fill: none;
    stroke-width: 12;
  }

  .background {
    stroke: #E8ECF4;
  }

  .progress {
    stroke: #172554;
    stroke-linecap: round;
    stroke-dasharray: 440;
    stroke-dashoffset: 440;
  }

  .percentage {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    color: #172033;
  }

  .number {
    font-size: 30px;
    font-weight: 700;
  }

  .label {
    margin-top: 4px;
    font-size: 11px;
    color: #64748B;
  }

  .details {
    display: flex;
    flex-direction: column;
    gap: 17px;
  }

  .detail {
    display: flex;
    flex-direction: column;
    gap: 5px;
  }

  .detail-number {
    color: #172033;
    font-size: 22px;
    font-weight: 700;
  }

  .detail-label {
    color: #64748B;
    font-size: 12px;
  }

  .dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    margin-right: 5px;
  }

  .completed-dot {
    background: #172554;
  }

  .pending-dot {
    background: #A5B4CC;
  }

  @media (max-width: 350px) {
    .container {
      gap: 12px;
    }

    .chart, svg {
      width: 140px;
      height: 140px;
    }
  }
</style>
</head>

<body>

<div class="container">

  <div class="chart">
    <svg viewBox="0 0 160 160">
      <circle
        class="background"
        cx="80"
        cy="80"
        r="70"
      />

      <circle
        class="progress"
        id="progressCircle"
        cx="80"
        cy="80"
        r="70"
      />
    </svg>

    <div class="percentage">
      <div class="number" id="percentage">0%</div>
      <div class="label">Completed</div>
    </div>
  </div>

  <div class="details">

    <div class="detail">
      <div class="detail-number" id="completed">0</div>
      <div class="detail-label">
        <span class="dot completed-dot"></span>
        Completed tasks
      </div>
    </div>

    <div class="detail">
      <div class="detail-number" id="pending">0</div>
      <div class="detail-label">
        <span class="dot pending-dot"></span>
        Pending tasks
      </div>
    </div>

  </div>

</div>

<script src="https://cdn.jsdelivr.net/npm/gsap@3.14.2/dist/gsap.min.js"></script>

<script>
  const completion = $percentage;
  const completedTasks = $_completedTasks;
  const pendingTasks = $_pendingTasks;

  function startAnimation() {
    const circle = document.getElementById('progressCircle');

    const circumference = 2 * Math.PI * 70;

    circle.style.strokeDasharray = circumference;
    circle.style.strokeDashoffset = circumference;

    const progress = {
      value: 0,
      completed: 0,
      pending: 0
    };

    gsap.to(progress, {
      value: completion,
      duration: 1.8,
      ease: "power2.out",
      onUpdate: function() {
        circle.style.strokeDashoffset =
          circumference - (progress.value / 100) * circumference;

        document.getElementById('percentage').textContent =
          Math.round(progress.value) + '%';
      }
    });

    gsap.to(progress, {
      completed: completedTasks,
      pending: pendingTasks,
      duration: 1.5,
      ease: "power2.out",
      onUpdate: function() {
        document.getElementById('completed').textContent =
          Math.round(progress.completed);

        document.getElementById('pending').textContent =
          Math.round(progress.pending);
      }
    });
  }

  if (typeof gsap !== 'undefined') {
    startAnimation();
  } else {
    document.getElementById('percentage').textContent =
      Math.round(completion) + '%';

    document.getElementById('completed').textContent =
      completedTasks;

    document.getElementById('pending').textContent =
      pendingTasks;
  }
</script>

</body>
</html>
''';

    await _webViewController.loadHtmlString(html);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadProgress,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
            children: [
              const Text(
                'Your progress',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'A look at your completed and pending tasks.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 25),

              _buildProgressCard(),

              const SizedBox(height: 20),

              _buildInformationCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task completion',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 15),

          if (_isLoading)
            const SizedBox(
              height: 200,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
            )
          else if (_errorMessage != null)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: AppColors.secondary,
                      size: 30,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadProgress,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 205,
              child: WebViewWidget(
                controller: _webViewController,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInformationCard() {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your task summary',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 18),

          _buildSummaryRow(
            'Total tasks',
            _totalTasks,
            Icons.assignment_outlined,
            AppColors.primary,
          ),

          const SizedBox(height: 15),

          _buildSummaryRow(
            'Completed',
            _completedTasks,
            Icons.check_circle_outline_rounded,
            AppColors.success,
          ),

          const SizedBox(height: 15),

          _buildSummaryRow(
            'Pending',
            _pendingTasks,
            Icons.pending_actions_rounded,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
      String label,
      int value,
      IconData icon,
      Color color,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 20,
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),

        Text(
          '$value',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}