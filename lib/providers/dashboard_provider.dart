import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/date_utils.dart';
import '../models/task.dart';
import 'focus_session_provider.dart';
import 'task_provider.dart';

class DashboardMetrics {
  final List<Task> todayTasks;
  final int totalEstimatedMinutes;
  final int completedEstimatedMinutes;
  final double completionRatio;
  final int completionPercentage;
  final int remainingEstimatedMinutes;
  final int remainingSubtasksCount;
  final int totalSubtasksCount;
  final int completedSubtasksCount;
  final int todayTotalFocusSeconds;

  const DashboardMetrics({
    required this.todayTasks,
    required this.totalEstimatedMinutes,
    required this.completedEstimatedMinutes,
    required this.completionRatio,
    required this.completionPercentage,
    required this.remainingEstimatedMinutes,
    required this.remainingSubtasksCount,
    required this.totalSubtasksCount,
    required this.completedSubtasksCount,
    required this.todayTotalFocusSeconds,
  });

  factory DashboardMetrics.empty() {
    return const DashboardMetrics(
      todayTasks: [],
      totalEstimatedMinutes: 0,
      completedEstimatedMinutes: 0,
      completionRatio: 0.0,
      completionPercentage: 0,
      remainingEstimatedMinutes: 0,
      remainingSubtasksCount: 0,
      totalSubtasksCount: 0,
      completedSubtasksCount: 0,
      todayTotalFocusSeconds: 0,
    );
  }
}

/// 计算今日看板各项核心指标
final dashboardMetricsProvider = Provider<DashboardMetrics>((ref) {
  final allTasks = ref.watch(tasksProvider);
  final completedSessionsFocusSeconds = ref.watch(todayTotalFocusSecondsProvider);
  final now = DateTime.now();
  final todayKey = AppDateUtils.todayKey();

  // 1. 过滤今日任务
  final todayTasks = allTasks.where((t) => t.isScheduledFor(now)).toList();

  int totalEstMinutes = 0;
  int completedEstMinutes = 0;
  int totalSubtasks = 0;
  int completedSubtasks = 0;

  for (final task in todayTasks) {
    for (final st in task.subtasks) {
      totalSubtasks++;
      totalEstMinutes += st.estimatedMinutes;
      if (st.isCompletedOn(todayKey)) {
        completedSubtasks++;
        completedEstMinutes += st.estimatedMinutes;
      }
    }
  }

  final remainingSubtasks = totalSubtasks - completedSubtasks;
  final remainingEstMinutes = totalEstMinutes - completedEstMinutes;

  // 按已完成每项子任务的预计时间总和除以总预计时间来计算完成度百分比
  final double ratio = totalEstMinutes > 0
      ? (completedEstMinutes / totalEstMinutes).clamp(0.0, 1.0)
      : (totalSubtasks > 0 && remainingSubtasks == 0 ? 1.0 : 0.0);
  final int percentage = (ratio * 100).round();

  return DashboardMetrics(
    todayTasks: todayTasks,
    totalEstimatedMinutes: totalEstMinutes,
    completedEstimatedMinutes: completedEstMinutes,
    completionRatio: ratio,
    completionPercentage: percentage,
    remainingEstimatedMinutes: remainingEstMinutes > 0 ? remainingEstMinutes : 0,
    remainingSubtasksCount: remainingSubtasks > 0 ? remainingSubtasks : 0,
    totalSubtasksCount: totalSubtasks,
    completedSubtasksCount: completedSubtasks,
    todayTotalFocusSeconds: completedSessionsFocusSeconds,
  );
});

