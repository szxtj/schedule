import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/date_utils.dart';
import '../core/notification_service.dart';
import '../models/focus_session.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import 'focus_session_provider.dart';
import 'task_provider.dart';

enum FocusTimerStatus {
  idle,             // 未在攻克状态
  running,          // 倒计时进行中
  paused,           // 已暂停
  completedPrompt,  // 倒计时已归零，等待用户确认完成或延长
}

class FocusTimerState {
  final FocusTimerStatus status;
  final Task? targetTask;
  final Subtask? targetSubtask;
  final int remainingSeconds;
  final int initialPlannedSeconds;
  final int actualElapsedSeconds;
  final int extendedSeconds;
  final List<String> completedSubtaskIds;
  final DateTime? startTime;

  const FocusTimerState({
    this.status = FocusTimerStatus.idle,
    this.targetTask,
    this.targetSubtask,
    this.remainingSeconds = 0,
    this.initialPlannedSeconds = 0,
    this.actualElapsedSeconds = 0,
    this.extendedSeconds = 0,
    this.completedSubtaskIds = const [],
    this.startTime,
  });

  bool get isActive =>
      status == FocusTimerStatus.running ||
      status == FocusTimerStatus.paused ||
      status == FocusTimerStatus.completedPrompt;

  bool get isConqueringSingleSubtask => targetSubtask != null;

  double get progressRatio {
    final total = initialPlannedSeconds + extendedSeconds;
    if (total <= 0) return 1.0;
    return (1.0 - (remainingSeconds / total)).clamp(0.0, 1.0);
  }

  FocusTimerState copyWith({
    FocusTimerStatus? status,
    Task? targetTask,
    Subtask? targetSubtask,
    int? remainingSeconds,
    int? initialPlannedSeconds,
    int? actualElapsedSeconds,
    int? extendedSeconds,
    List<String>? completedSubtaskIds,
    DateTime? startTime,
    bool clearTargetSubtask = false,
  }) {
    return FocusTimerState(
      status: status ?? this.status,
      targetTask: targetTask ?? this.targetTask,
      targetSubtask: clearTargetSubtask ? null : (targetSubtask ?? this.targetSubtask),
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      initialPlannedSeconds: initialPlannedSeconds ?? this.initialPlannedSeconds,
      actualElapsedSeconds: actualElapsedSeconds ?? this.actualElapsedSeconds,
      extendedSeconds: extendedSeconds ?? this.extendedSeconds,
      completedSubtaskIds: completedSubtaskIds ?? this.completedSubtaskIds,
      startTime: startTime ?? this.startTime,
    );
  }
}

class FocusTimerNotifier extends StateNotifier<FocusTimerState> {
  final Ref _ref;
  Timer? _ticker;

  FocusTimerNotifier(this._ref) : super(const FocusTimerState());

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != FocusTimerStatus.running) return;

      final newElapsed = state.actualElapsedSeconds + 1;
      final newRemaining = state.remainingSeconds - 1;

      if (newRemaining <= 0) {
        _ticker?.cancel();
        state = state.copyWith(
          remainingSeconds: 0,
          actualElapsedSeconds: newElapsed,
          status: FocusTimerStatus.completedPrompt,
        );
        _triggerTimeUpNotification();
      } else {
        state = state.copyWith(
          remainingSeconds: newRemaining,
          actualElapsedSeconds: newElapsed,
        );
      }
    });
  }

  void _triggerTimeUpNotification() {
    final title = '攻克倒计时结束！';
    final taskName = state.targetSubtask?.title ?? state.targetTask?.title ?? '当前任务';
    final body = '任务【$taskName】预计时间已到达，已为您弹出延时或完成选项。';
    NotificationService.instance.notifyTimerCompleted(title: title, body: body);
  }

  /// 发起整项（总）任务攻克
  void startTaskFocus(Task task) {
    _ticker?.cancel();
    final todayKey = AppDateUtils.todayKey();
    // 初始倒计时 = 所有未完成子任务的预估时间总和
    final uncompleted = task.uncompletedSubtasks(todayKey);
    final targetMinutes = uncompleted.isNotEmpty
        ? uncompleted.fold(0, (sum, st) => sum + st.estimatedMinutes)
        : task.totalEstimatedMinutes;
    final plannedSecs = max(1, targetMinutes) * 60;

    state = FocusTimerState(
      status: FocusTimerStatus.running,
      targetTask: task,
      targetSubtask: null,
      remainingSeconds: plannedSecs,
      initialPlannedSeconds: plannedSecs,
      actualElapsedSeconds: 0,
      extendedSeconds: 0,
      completedSubtaskIds: [],
      startTime: DateTime.now(),
    );

    _startTicker();
  }

  /// 发起单个子任务攻克
  void startSubtaskFocus(Task task, Subtask subtask) {
    _ticker?.cancel();
    final plannedSecs = max(1, subtask.estimatedMinutes) * 60;

    state = FocusTimerState(
      status: FocusTimerStatus.running,
      targetTask: task,
      targetSubtask: subtask,
      remainingSeconds: plannedSecs,
      initialPlannedSeconds: plannedSecs,
      actualElapsedSeconds: 0,
      extendedSeconds: 0,
      completedSubtaskIds: [],
      startTime: DateTime.now(),
    );

    _startTicker();
  }

  /// 暂停倒计时
  void pause() {
    if (state.status == FocusTimerStatus.running) {
      _ticker?.cancel();
      state = state.copyWith(status: FocusTimerStatus.paused);
    }
  }

  /// 继续倒计时
  void resume() {
    if (state.status == FocusTimerStatus.paused) {
      state = state.copyWith(status: FocusTimerStatus.running);
      _startTicker();
    }
  }

  /// 在攻克过程中勾选完成子任务（智能减少剩余预计时间核心算法）
  /// 用户指定公式：倒计时智能更新为“当前总任务剩余未完成子任务预计时间”与“（当前倒计时剩余时间 - 该子任务预计时间）”两者的更小值
  Future<void> checkSubtaskInSession(String subtaskId) async {
    final task = state.targetTask;
    if (task == null) return;

    final todayKey = AppDateUtils.todayKey();
    final subtask = task.subtasks.firstWhere(
      (st) => st.id == subtaskId,
      orElse: () => Subtask(id: '', taskId: '', title: ''),
    );
    if (subtask.id.isEmpty) return;

    // 1. 在任务状态提供者中将该子任务标记为完成
    await _ref.read(tasksProvider.notifier).setSubtaskCompletion(
          task.id,
          subtaskId,
          true,
          dateKey: todayKey,
        );

    // 2. 重新从最新任务列表中获取更新后的 task
    final allTasks = _ref.read(tasksProvider);
    final updatedTask = allTasks.firstWhere((t) => t.id == task.id, orElse: () => task);

    // 3. 计算智能减少时间
    // Term 1: 当前总任务所有未完成子任务的预估时间之和（秒）
    final remainingUncompleted = updatedTask.uncompletedSubtasks(todayKey);
    final int remainingEstimateSeconds =
        remainingUncompleted.fold(0, (sum, st) => sum + st.estimatedMinutes) * 60;

    // Term 2: 勾选前倒计时剩余秒数 - 该已完成子任务预估秒数
    final int subtaskEstimateSeconds = subtask.estimatedMinutes * 60;
    final int reducedCurrentSeconds = max(0, state.remainingSeconds - subtaskEstimateSeconds);

    // 取两者的更小值
    int newRemaining = min(remainingEstimateSeconds, reducedCurrentSeconds);

    final updatedCompletedIds = [...state.completedSubtaskIds, subtaskId];

    // 如果所有子任务已全部完成或剩余时间归零
    if (remainingUncompleted.isEmpty || newRemaining <= 0) {
      _ticker?.cancel();
      state = state.copyWith(
        targetTask: updatedTask,
        remainingSeconds: 0,
        status: FocusTimerStatus.completedPrompt,
        completedSubtaskIds: updatedCompletedIds,
      );
      _triggerTimeUpNotification();
    } else {
      state = state.copyWith(
        targetTask: updatedTask,
        remainingSeconds: newRemaining,
        completedSubtaskIds: updatedCompletedIds,
      );
    }
  }

  /// 提前点击完成（或完成所有子任务）
  Future<void> finishEarly() async {
    _ticker?.cancel();
    final todayKey = AppDateUtils.todayKey();
    final task = state.targetTask;

    if (task != null) {
      // 若是单子任务，则标记单子任务完成；若是总任务，将所有子任务标记为完成
      if (state.targetSubtask != null) {
        await _ref.read(tasksProvider.notifier).setSubtaskCompletion(
              task.id,
              state.targetSubtask!.id,
              true,
              dateKey: todayKey,
            );
      } else {
        for (final st in task.subtasks) {
          if (!st.isCompletedOn(todayKey)) {
            await _ref.read(tasksProvider.notifier).setSubtaskCompletion(
                  task.id,
                  st.id,
                  true,
                  dateKey: todayKey,
                );
          }
        }
      }
    }

    await _saveCurrentSession(isEarlyFinished: true);
    _reset();
  }

  /// 延长时间（按勾选的未完成子任务预计时间，或自定义分钟）
  void extendTimer(int additionalMinutes) {
    final additionalSeconds = max(1, additionalMinutes) * 60;
    state = state.copyWith(
      remainingSeconds: state.remainingSeconds + additionalSeconds,
      extendedSeconds: state.extendedSeconds + additionalSeconds,
      status: FocusTimerStatus.running,
    );
    _startTicker();
  }

  /// 正常结束攻克并保存记录
  Future<void> finishAndSave() async {
    _ticker?.cancel();
    await _saveCurrentSession(isEarlyFinished: false);
    _reset();
  }

  /// 放弃或关闭攻克
  Future<void> cancelOrClose({bool saveElapsedTime = true}) async {
    _ticker?.cancel();
    if (saveElapsedTime && state.actualElapsedSeconds > 0) {
      await _saveCurrentSession(isEarlyFinished: false);
    }
    _reset();
  }

  Future<void> _saveCurrentSession({required bool isEarlyFinished}) async {
    final now = DateTime.now();
    final todayKey = AppDateUtils.todayKey();

    final session = FocusSession(
      id: const Uuid().v4(),
      taskId: state.targetTask?.id ?? '',
      taskTitle: state.targetTask?.title ?? '未知任务',
      subtaskId: state.targetSubtask?.id,
      subtaskTitle: state.targetSubtask?.title,
      startTime: state.startTime ?? now,
      endTime: now,
      actualDurationSeconds: state.actualElapsedSeconds,
      plannedDurationSeconds: state.initialPlannedSeconds,
      extendedSeconds: state.extendedSeconds,
      isEarlyFinished: isEarlyFinished,
      dateKey: todayKey,
      completedSubtaskIds: state.completedSubtaskIds,
    );

    await _ref.read(focusSessionsProvider.notifier).logSession(session);
  }

  void _reset() {
    state = const FocusTimerState();
  }
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerNotifier, FocusTimerState>((ref) {
  return FocusTimerNotifier(ref);
});
