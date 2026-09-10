import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/task.dart';
import '../../providers/focus_timer_provider.dart';
import '../../providers/task_provider.dart';
import '../dialogs/focus_extend_dialog.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _isShowingExtendDialog = false;

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(focusTimerProvider);
    final task = timerState.targetTask;

    if (task == null || !timerState.isActive) {
      return const Scaffold(
        backgroundColor: AppColors.focusBackground,
        body: SizedBox.shrink(),
      );
    }

    // 监听倒计时归零弹出延时确认
    if (timerState.status == FocusTimerStatus.completedPrompt && !_isShowingExtendDialog) {
      _isShowingExtendDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTimeUpDialog(context, task, timerState);
      });
    }

    final isSingleSubtask = timerState.isConqueringSingleSubtask;
    final isRunning = timerState.status == FocusTimerStatus.running;
    final isPaused = timerState.status == FocusTimerStatus.paused;

    final todayKey = AppDateUtils.todayKey();
    // 实时获取任务最新的子任务列表状态
    final allTasks = ref.watch(tasksProvider);
    final currentTask = allTasks.firstWhere((t) => t.id == task.id, orElse: () => task);

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
                            _buildTaskHeader(currentTask, timerState),
                            const SizedBox(height: 32),
                            _buildTimerRing(timerState),
                            const SizedBox(height: 32),
                            _buildActionControls(isRunning, isPaused),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 右侧（若攻克整项任务）：子任务攻克清单，支持实时勾选并智能缩减倒计时
                  if (!isSingleSubtask) ...[
                    Container(
                      width: 1,
                      color: Colors.white12,
                      margin: const EdgeInsets.symmetric(vertical: 40),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildSubtasksSidebar(currentTask, todayKey),
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
              // 暂停时或运行中均可返回主界面，主界面实时展示当前攻克胶囊
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: Text(
              isPaused ? '暂停中 · 返回主界面' : '返回主界面 (后台专注)',
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
                  isRunning ? '深度攻克中...' : (isPaused ? '倒计时已暂停' : '攻克待确认'),
                  style: TextStyle(
                    color: isRunning ? AppColors.accentLight : AppColors.warning,
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

  Widget _buildTaskHeader(Task currentTask, FocusTimerState state) {
    final subtask = state.targetSubtask;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            subtask != null ? '正在攻克单个子任务' : '正在攻克整项综合任务',
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
            '所属任务: ${currentTask.title}',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildTimerRing(FocusTimerState timerState) {
    final remaining = timerState.remainingSeconds;
    final timeStr = AppDateUtils.formatSecondsToTime(remaining);
    final ratio = timerState.progressRatio;

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
              timerState.status == FocusTimerStatus.running
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
              '真实专注: ${AppDateUtils.formatSecondsToTime(timerState.actualElapsedSeconds)}',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            if (timerState.extendedSeconds > 0)
              Text(
                '已延长: +${AppDateUtils.formatMinutes(timerState.extendedSeconds ~/ 60)}',
                style: const TextStyle(color: AppColors.accentLight, fontSize: 12),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionControls(bool isRunning, bool isPaused) {
    return Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        // 暂停 / 继续按钮
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isRunning ? AppColors.warning : AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            if (isRunning) {
              ref.read(focusTimerProvider.notifier).pause();
            } else {
              ref.read(focusTimerProvider.notifier).resume();
            }
          },
          icon: Icon(isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            await ref.read(focusTimerProvider.notifier).finishEarly();
          },
          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
          label: const Text(
            '提前完成',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        // 退出或取消攻克按钮
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white60,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
            await ref.read(focusTimerProvider.notifier).cancelOrClose(saveElapsedTime: true);
          },
          icon: const Icon(Icons.stop_circle_outlined, size: 18),
          label: const Text('结束并保存时长', style: TextStyle(fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildSubtasksSidebar(Task task, String todayKey) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rtl_rounded, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 8),
              const Text(
                '子任务攻克清单',
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
                    color: isDone ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.08),
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
                        fontWeight: isDone ? FontWeight.normal : FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '预估工时: ${st.estimatedMinutes} 分钟',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    secondary: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                                  .checkSubtaskInSession(st.id);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.accent,
                                    duration: const Duration(seconds: 2),
                                    content: Text(
                                      '已完成【${st.title}】！倒计时已智能更新为更紧凑预估时间。',
                                      style: const TextStyle(color: Colors.white),
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
    Task task,
    FocusTimerState state,
  ) async {
    final todayKey = AppDateUtils.todayKey();
    final uncompleted = task.uncompletedSubtasks(todayKey);

    final nav = Navigator.of(context);
    final extensionMinutes = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => FocusExtendDialog(
        task: task,
        uncompletedSubtasks: uncompleted,
        actualElapsedSeconds: state.actualElapsedSeconds,
      ),
    );

    _isShowingExtendDialog = false;

    if (!mounted) return;

    if (extensionMinutes != null && extensionMinutes > 0) {
      ref.read(focusTimerProvider.notifier).extendTimer(extensionMinutes);
    } else {
      await ref.read(focusTimerProvider.notifier).finishAndSave();
      if (mounted && nav.canPop()) {
        nav.pop();
      }
    }
  }
}
