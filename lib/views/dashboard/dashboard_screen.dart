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
import '../dialogs/data_sync_dialog.dart';
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

  void _openFocusScreen([String? sessionKey]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FocusScreen(sessionKey: sessionKey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metrics = ref.watch(dashboardMetricsProvider);
    final allTasks = ref.watch(tasksProvider);
    final timerState = ref.watch(focusTimerProvider);
    final todayKey = AppDateUtils.todayKey();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        if (isMobile) {
          return _buildMobileLayout(
            context,
            metrics,
            allTasks,
            timerState,
            todayKey,
          );
        }
        return _buildDesktopLayout(
          context,
          metrics,
          allTasks,
          timerState,
          todayKey,
        );
      },
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    DashboardMetrics metrics,
    List<Task> allTasks,
    FocusTimerState timerState,
    String todayKey,
  ) {
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
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: AppColors.borderLight,
          ),
          // 右侧主内容区域
          Expanded(
            child: Column(
              children: [
                // 顶部状态栏
                _buildTopAppBar(context, timerState),
                // 活跃任务悬浮提示条（当专注进行中或暂停且退回主界面时常驻提示）
                if (timerState.hasActiveSessions)
                  _buildActiveFocusBanner(timerState),
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

  Widget _buildMobileLayout(
    BuildContext context,
    DashboardMetrics metrics,
    List<Task> allTasks,
    FocusTimerState timerState,
    String todayKey,
  ) {
    int navIndex = 0;
    if (_currentSection == SidebarNavSection.today) {
      navIndex = 0;
    } else if (_currentSection == SidebarNavSection.records) {
      navIndex = 2;
    } else {
      navIndex = 1;
    }

    final primarySession =
        timerState.runningSession ?? timerState.pausedSessions.firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppConstants.appName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryLight,
              ),
            ),
            Text(
              AppDateUtils.formatDisplayDate(DateTime.now()),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
        actions: [
          // 活跃任务快速胶囊
          if (primarySession != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  primarySession.status == FocusTimerStatus.running
                      ? Icons.timer_outlined
                      : Icons.pause_circle_outline_rounded,
                  size: 16,
                  color: primarySession.status == FocusTimerStatus.running
                      ? AppColors.accent
                      : AppColors.warning,
                ),
                label: Text(
                  AppDateUtils.formatSecondsToTime(
                    primarySession.remainingSeconds,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primarySession.status == FocusTimerStatus.running
                        ? AppColors.accent
                        : AppColors.warning,
                  ),
                ),
                backgroundColor:
                    (primarySession.status == FocusTimerStatus.running
                            ? AppColors.accent
                            : AppColors.warning)
                        .withValues(alpha: 0.1),
                side: BorderSide(
                  color:
                      (primarySession.status == FocusTimerStatus.running
                              ? AppColors.accent
                              : AppColors.warning)
                          .withValues(alpha: 0.3),
                ),
                onPressed: () => _openFocusScreen(primarySession.sessionKey),
              ),
            ),
          // 数据互通与备份
          IconButton(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.textSecondaryLight,
              size: 22,
            ),
            tooltip: '跨端数据备份与互通',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const DataSyncDialog(),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (timerState.hasActiveSessions)
            _buildActiveFocusBanner(timerState, isMobile: true),
          Expanded(
            child: _currentSection == SidebarNavSection.records
                ? const FocusRecordsView()
                : _buildTasksView(allTasks, metrics, todayKey, isMobile: true),
          ),
        ],
      ),
      floatingActionButton: _currentSection != SidebarNavSection.records
          ? FloatingActionButton(
              onPressed: _openAddTaskDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          setState(() {
            if (index == 0) _currentSection = SidebarNavSection.today;
            if (index == 1) _currentSection = SidebarNavSection.all;
            if (index == 2) _currentSection = SidebarNavSection.records;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today_rounded),
            label: '今日计划',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: '全部任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: '专注记录',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _openAddTaskDialog,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  '新建计划任务',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 正在进行/暂停状态条（支持直接切入任务界面）
  Widget _buildActiveFocusBanner(
    FocusTimerState timerState, {
    bool isMobile = false,
  }) {
    final running = timerState.runningSession;
    final pausedList = timerState.pausedSessions;

    final primarySession = running ?? pausedList.firstOrNull;
    if (primarySession == null) return const SizedBox.shrink();

    final isRunning = primarySession.status == FocusTimerStatus.running;
    final taskName = primarySession.displayName;
    final timeStr = AppDateUtils.formatSecondsToTime(
      primarySession.remainingSeconds,
    );

    return Container(
      width: double.infinity,
      color: isRunning
          ? AppColors.accent.withValues(alpha: 0.15)
          : AppColors.warning.withValues(alpha: 0.15),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 8 : 10,
      ),
      child: Row(
        children: [
          Icon(
            isRunning
                ? Icons.play_circle_fill_rounded
                : Icons.pause_circle_filled_rounded,
            color: isRunning ? AppColors.accent : AppColors.warning,
            size: isMobile ? 18 : 22,
          ),
          SizedBox(width: isMobile ? 8 : 10),
          Expanded(
            child: Text(
              isMobile
                  ? '${isRunning ? "进行中" : "已暂停"}：$taskName · $timeStr'
                  : '${isRunning ? "任务进行中" : "任务已暂停"}：【$taskName】 · 倒计时 $timeStr · 实际已专注 ${AppDateUtils.formatSecondsToTime(primarySession.actualElapsedSeconds)}'
                        '${pausedList.isNotEmpty && isRunning ? " (另有 ${pausedList.length} 项已暂停)" : ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: isRunning ? AppColors.accent : Colors.amber[900],
              ),
            ),
          ),
          if (!isRunning)
            Padding(
              padding: const EdgeInsets.only(right: 6.0),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 10,
                    vertical: isMobile ? 4 : 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref
                      .read(focusTimerProvider.notifier)
                      .resumeSession(primarySession.sessionKey);
                },
                child: Text(
                  '继续',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isRunning ? AppColors.accent : Colors.amber[900],
              backgroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 8 : 12,
                vertical: isMobile ? 4 : 6,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openFocusScreen(primarySession.sessionKey),
            icon: Icon(Icons.fullscreen_rounded, size: isMobile ? 16 : 18),
            label: Text(
              isMobile ? '切入' : '切入任务大屏',
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksView(
    List<Task> allTasks,
    DashboardMetrics metrics,
    String todayKey, {
    bool isMobile = false,
  }) {
    // 过滤任务列表
    final displayedTasks = _filterTasks(allTasks);

    return ListView(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      children: [
        // 今日看板时，展示四大核心指标卡片
        if (_currentSection == SidebarNavSection.today) ...[
          DashboardSummaryCards(metrics: metrics, isCompact: isMobile),
          SizedBox(height: isMobile ? 14 : 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '今日任务列表',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              Text(
                '${displayedTasks.length} 项综合任务',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
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
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMutedLight,
                  ),
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
        return tasks
            .where((t) => t.recurrence.type == RecurrenceType.daily)
            .toList();
      case SidebarNavSection.weekly:
        return tasks
            .where((t) => t.recurrence.type == RecurrenceType.weekly)
            .toList();
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
        return '真实专注打卡与历史统计';
    }
  }
}
