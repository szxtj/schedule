import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/recurrence.dart';
import '../../models/task.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/focus_timer_provider.dart';
import '../../providers/task_provider.dart';
import '../dialogs/add_task_dialog.dart';
import '../focus/focus_screen.dart';
import 'focus_records_view.dart';
import 'widgets/sidebar.dart';
import 'widgets/summary_cards.dart';
import 'widgets/task_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  SidebarNavSection _currentSection = SidebarNavSection.today;

  void _openAddTaskDialog() async {
    final newTask = await showDialog<Task>(
      context: context,
      builder: (context) => const AddTaskDialog(),
    );
    if (newTask != null) {
      await ref.read(tasksProvider.notifier).addTask(newTask);
    }
  }

  void _openFocusScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FocusScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final allTasks = ref.watch(tasksProvider);
    final timerState = ref.watch(focusTimerProvider);
    final todayKey = AppDateUtils.todayKey();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Row(
        children: [
          // 左侧侧边栏
          DashboardSidebar(
            currentSection: _currentSection,
            onSectionChanged: (sec) => setState(() => _currentSection = sec),
            metrics: metrics,
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.borderLight),
          // 右侧主内容区域
          Expanded(
            child: Column(
              children: [
                // 顶部状态栏
                _buildTopAppBar(context, timerState),
                // 活跃攻克悬浮提示条（当专注进行中或暂停且退回主界面时常驻提示）
                if (timerState.isActive) _buildActiveFocusBanner(timerState),
                // 主体列表与视图
                Expanded(
                  child: _currentSection == SidebarNavSection.records
                      ? const FocusRecordsView()
                      : _buildTasksView(allTasks, metrics, todayKey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar(BuildContext context, FocusTimerState timerState) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppDateUtils.formatDisplayDate(DateTime.now()),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                _sectionSubtitle(_currentSection),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          Row(
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _openAddTaskDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('新建计划任务', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 正在攻克状态条（支持直接切入专注界面）
  Widget _buildActiveFocusBanner(FocusTimerState timerState) {
    final isPaused = timerState.status == FocusTimerStatus.paused;
    final taskName = timerState.targetSubtask?.title ?? timerState.targetTask?.title ?? '当前任务';
    final timeStr = AppDateUtils.formatSecondsToTime(timerState.remainingSeconds);

    return Container(
      width: double.infinity,
      color: isPaused
          ? AppColors.warning.withValues(alpha: 0.15)
          : AppColors.accent.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          Icon(
            isPaused ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: isPaused ? AppColors.warning : AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${isPaused ? "攻克暂停中" : "攻克进行中"}：【$taskName】 · 剩余倒计时 $timeStr · 实际已专注 ${AppDateUtils.formatSecondsToTime(timerState.actualElapsedSeconds)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPaused ? Colors.amber[900] : AppColors.accent,
              ),
            ),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isPaused ? Colors.amber[900] : AppColors.accent,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            onPressed: _openFocusScreen,
            icon: const Icon(Icons.fullscreen_rounded, size: 18),
            label: const Text('切入攻克大屏', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksView(
    List<Task> allTasks,
    DashboardMetrics metrics,
    String todayKey,
  ) {
    // 过滤任务列表
    final displayedTasks = _filterTasks(allTasks);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 今日看板时，展示四大核心指标卡片
        if (_currentSection == SidebarNavSection.today) ...[
          DashboardSummaryCards(metrics: metrics),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日任务列表',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '${displayedTasks.length} 项综合任务',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (displayedTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_rounded, size: 52, color: Colors.grey[350]),
                const SizedBox(height: 12),
                const Text(
                  '暂无相关任务',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '点击右上角“新建计划任务”开始规划吧！',
                  style: TextStyle(fontSize: 12, color: AppColors.textMutedLight),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _openAddTaskDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('立即添加任务'),
                ),
              ],
            ),
          )
        else
          ...displayedTasks.map((t) => TaskCard(task: t, dateKey: todayKey)),
      ],
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final now = DateTime.now();
    switch (_currentSection) {
      case SidebarNavSection.today:
        return tasks.where((t) => t.isScheduledFor(now)).toList();
      case SidebarNavSection.daily:
        return tasks.where((t) => t.recurrence.type == RecurrenceType.daily).toList();
      case SidebarNavSection.weekly:
        return tasks.where((t) => t.recurrence.type == RecurrenceType.weekly).toList();
      case SidebarNavSection.all:
        return tasks.where((t) => !t.isArchived).toList();
      case SidebarNavSection.records:
        return [];
    }
  }

  String _sectionSubtitle(SidebarNavSection section) {
    switch (section) {
      case SidebarNavSection.today:
        return '聚焦今日目标 · 实时加权完成度看板';
      case SidebarNavSection.daily:
        return '每天例行循环任务管理';
      case SidebarNavSection.weekly:
        return '每周固定星期循环任务';
      case SidebarNavSection.all:
        return '所有计划清单总览';
      case SidebarNavSection.records:
        return '真实专注攻克打卡与历史统计';
    }
  }
}

