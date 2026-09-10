import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/task.dart';
import '../../providers/focus_timer_provider.dart';
import '../../providers/task_provider.dart';
import '../dialogs/focus_extend_dialog.dart';

class FocusScreen extends ConsumerStatefulWidget {
  final String? sessionKey;

  const FocusScreen({super.key, this.sessionKey});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _isShowingExtendDialog = false;

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    final key = widget.sessionKey ?? timerState.currentSessionKey;
    final session = key != null
        ? timerState.sessions[key]
        : timerState.currentSession;

    if (session == null) {
      return const Scaffold(
        backgroundColor: AppColors.focusBackground,
        body: SizedBox.shrink(),
      );
    }

    // 监听倒计时归零弹出延时确认
    if (session.status == FocusTimerStatus.completedPrompt &&
        !_isShowingExtendDialog) {
      _isShowingExtendDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTimeUpDialog(context, session);
      });
    }

    final isSingleSubtask = session.isSingleSubtask;
    final isRunning = session.status == FocusTimerStatus.running;
    final isPaused = session.status == FocusTimerStatus.paused;

    final todayKey = AppDateUtils.todayKey();
    // 实时获取任务最新的子任务列表状态
    final allTasks = ref.watch(tasksProvider);
    final currentTask = allTasks.firstWhere(
      (t) => t.id == session.targetTask.id,
      orElse: () => session.targetTask,
    );

    return Scaffold(
      backgroundColor: AppColors.focusBackground,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部导航栏（包含返回主页按钮）
            _buildTopBar(context, isPaused, isRunning),
            // 主体内容
            Expanded(
              child: Row(
                children: [
                  // 左侧或中央：大倒计时表盘与控制
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTaskHeader(currentTask, session),
                            const SizedBox(height: 32),
                            _buildTimerRing(session),
                            const SizedBox(height: 32),
                            _buildActionControls(session, isRunning, isPaused),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 右侧（若进行整项任务）：子任务清单，支持实时勾选并智能缩减倒计时
                  if (!isSingleSubtask) ...[
                    Container(
                      width: 1,
                      color: Colors.white12,
                      margin: const EdgeInsets.symmetric(vertical: 40),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildSubtasksSidebar(
                        session,
                        currentTask,
                        todayKey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isPaused, bool isRunning) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              // 暂停时或运行中均可返回主界面，后台保持进行
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              isPaused ? '任务暂停中 · 返回主界面' : '返回主界面 (后台运行)',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isRunning
                  ? AppColors.accent.withValues(alpha: 0.2)
                  : AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRunning ? AppColors.accent : AppColors.warning,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRunning ? AppColors.accent : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isRunning ? '任务进行中...' : (isPaused ? '任务已暂停' : '时间到达待确认'),
                  style: TextStyle(
                    color: isRunning
                        ? AppColors.accentLight
                        : AppColors.warning,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader(Task currentTask, TaskSession session) {
    final subtask = session.targetSubtask;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            subtask != null ? '正在进行单个子任务' : '正在进行整项综合任务',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtask != null ? subtask.title : currentTask.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtask != null) ...[
          const SizedBox(height: 4),
          Text(
            '所属总任务: ${currentTask.title}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildTimerRing(TaskSession session) {
    final remaining = session.remainingSeconds;
    final timeStr = AppDateUtils.formatSecondsToTime(remaining);
    final ratio = session.progressRatio;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 280,
          height: 280,
          child: CircularProgressIndicator(
            value: 1.0 - ratio, // 倒计时递减
            strokeWidth: 12,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              session.status == FocusTimerStatus.running
                  ? AppColors.accent
                  : AppColors.warning,
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '实际专注: ${AppDateUtils.formatSecondsToTime(session.actualElapsedSeconds)}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            if (session.extendedSeconds > 0)
              Text(
                '已延长: +${AppDateUtils.formatMinutes(session.extendedSeconds ~/ 60)}',
                style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionControls(
    TaskSession session,
    bool isRunning,
    bool isPaused,
  ) {
    final sessionKey = session.sessionKey;

    return Wrap(
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        // 暂停 / 继续按钮
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isRunning ? AppColors.warning : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            if (isRunning) {
              ref.read(focusTimerProvider.notifier).pauseSession(sessionKey);
            } else {
              ref.read(focusTimerProvider.notifier).resumeSession(sessionKey);
            }
          },
          icon: Icon(
            isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 20,
          ),
          label: Text(
            isRunning ? '暂停' : '继续',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        // 提前完成按钮
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            await ref.read(focusTimerProvider.notifier).finishEarly(sessionKey);
          },
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: const Text(
            '提前完成',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        // 取消任务按钮（作废统计与勾选进度）
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _confirmCancelTask(session),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('取消任务', style: TextStyle(fontSize: 14)),
        ),
        // 结束并保存时长
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white60,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            await ref
                .read(focusTimerProvider.notifier)
                .finishAndSave(sessionKey);
          },
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('结束并保存时长', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  void _confirmCancelTask(TaskSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('确认取消当前任务？'),
          ],
        ),
        content: Text(
          '取消后，本次进行过程中的所有专注计时（${AppDateUtils.formatSecondsDuration(session.actualElapsedSeconds)}）将全部作废且不计入统计；\n\n'
          '同时在本次任务进行中勾选完成的 ${session.completedSubtaskIdsInSession.length} 项子任务进度也将全部撤销恢复为未完成状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续任务'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认取消并作废'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
      await ref
          .read(focusTimerProvider.notifier)
          .cancelTask(session.sessionKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.textPrimaryLight,
            content: Text('已取消任务，本次专注时间与勾选进度已作废。'),
          ),
        );
      }
    }
  }

  Widget _buildSubtasksSidebar(
    TaskSession session,
    Task task,
    String todayKey,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rtl_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '子任务清单',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '勾选即智能减少倒计时',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: task.subtasks.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final st = task.subtasks[index];
                final isDone = st.isCompletedOn(todayKey);

                return Container(
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone ? Colors.white10 : Colors.white24,
                    ),
                  ),
                  child: CheckboxListTile(
                    value: isDone,
                    activeColor: AppColors.accent,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      st.title,
                      style: TextStyle(
                        color: isDone ? Colors.white38 : Colors.white,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        fontSize: 14,
                        fontWeight: isDone
                            ? FontWeight.normal
                            : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '预计需用时: ${st.estimatedMinutes} 分钟',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${st.estimatedMinutes}m',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onChanged: isDone
                        ? null // 已完成无需再次勾选，避免重复触发
                        : (val) async {
                            if (val == true) {
                              await ref
                                  .read(focusTimerProvider.notifier)
                                  .checkSubtaskInSession(
                                    session.sessionKey,
                                    st.id,
                                  );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.accent,
                                    duration: const Duration(seconds: 2),
                                    content: Text(
                                      '已完成【${st.title}】！倒计时已智能更新为紧凑预估时间。',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimeUpDialog(
    BuildContext context,
    TaskSession session,
  ) async {
    final todayKey = AppDateUtils.todayKey();
    final uncompleted = session.targetTask.uncompletedSubtasks(todayKey);

    final nav = Navigator.of(context);
    final result = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FocusExtendDialog(
        task: session.targetTask,
        targetSubtask: session.targetSubtask,
        uncompletedSubtasks: uncompleted,
        actualElapsedSeconds: session.actualElapsedSeconds,
      ),
    );

    _isShowingExtendDialog = false;

    if (!mounted) return;

    if (result == -1) {
      // 取消任务：作废统计与勾选进度
      if (mounted && nav.canPop()) nav.pop();
      await ref
          .read(focusTimerProvider.notifier)
          .cancelTask(session.sessionKey);
    } else if (result != null && result > 0) {
      // 延长时间
      ref
          .read(focusTimerProvider.notifier)
          .extendTimer(result, session.sessionKey);
    } else if (result == 0) {
      // 结束任务并保存
      if (mounted && nav.canPop()) nav.pop();
      await ref
          .read(focusTimerProvider.notifier)
          .finishAndSave(session.sessionKey);
    }
  }
}
