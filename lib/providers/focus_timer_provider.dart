import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/date_utils.dart';
import '../core/notification_service.dart';
import '../core/status_bar_service.dart';
import '../models/focus_session.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import 'focus_session_provider.dart';
import 'task_provider.dart';

enum FocusTimerStatus {
  idle, // 未启动
  running, // 任务进行中
  paused, // 已暂停
  completedPrompt, // 倒计时结束，等待确认或延长
}

class TaskSession {
  final String sessionKey;
  final Task targetTask;
  final Subtask? targetSubtask;
  final FocusTimerStatus status;
  final int remainingSeconds;
  final int initialPlannedSeconds;
  final int actualElapsedSeconds;
  final int extendedSeconds;
  final List<String> completedSubtaskIdsInSession;
  final DateTime startTime;

  const TaskSession({
    required this.sessionKey,
    required this.targetTask,
    this.targetSubtask,
    this.status = FocusTimerStatus.idle,
    this.remainingSeconds = 0,
    this.initialPlannedSeconds = 0,
    this.actualElapsedSeconds = 0,
    this.extendedSeconds = 0,
    this.completedSubtaskIdsInSession = const [],
    required this.startTime,
  });

  bool get isSingleSubtask => targetSubtask != null;

  String get displayName => targetSubtask?.title ?? targetTask.title;

  double get progressRatio {
    final total = initialPlannedSeconds + extendedSeconds;
    if (total <= 0) return 1.0;
    return (1.0 - (remainingSeconds / total)).clamp(0.0, 1.0);
  }

  TaskSession copyWith({
    Task? targetTask,
    Subtask? targetSubtask,
    FocusTimerStatus? status,
    int? remainingSeconds,
    int? initialPlannedSeconds,
    int? actualElapsedSeconds,
    int? extendedSeconds,
    List<String>? completedSubtaskIdsInSession,
    DateTime? startTime,
  }) {
    return TaskSession(
      sessionKey: sessionKey,
      targetTask: targetTask ?? this.targetTask,
      targetSubtask: targetSubtask ?? this.targetSubtask,
      status: status ?? this.status,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      initialPlannedSeconds:
          initialPlannedSeconds ?? this.initialPlannedSeconds,
      actualElapsedSeconds: actualElapsedSeconds ?? this.actualElapsedSeconds,
      extendedSeconds: extendedSeconds ?? this.extendedSeconds,
      completedSubtaskIdsInSession:
          completedSubtaskIdsInSession ?? this.completedSubtaskIdsInSession,
      startTime: startTime ?? this.startTime,
    );
  }
}

class FocusTimerState {
  /// 所有正在追踪的任务会话（每个任务/子任务独立保存进度，互不干扰）
  final Map<String, TaskSession> sessions;

  /// 当前在大屏/浮窗中展示的会话 Key
  final String? currentSessionKey;

  const FocusTimerState({this.sessions = const {}, this.currentSessionKey});

  TaskSession? get currentSession =>
      currentSessionKey != null ? sessions[currentSessionKey] : null;

  /// 当前正在进行（计时中）的会话（全系统保证最多只有一个处于 running 状态）
  TaskSession? get runningSession {
    for (final s in sessions.values) {
      if (s.status == FocusTimerStatus.running) return s;
    }
    return null;
  }

  /// 所有处于暂停状态的会话
  List<TaskSession> get pausedSessions {
    return sessions.values
        .where((s) => s.status == FocusTimerStatus.paused)
        .toList();
  }

  bool get isRunning => runningSession != null;
  bool get hasActiveSessions => sessions.isNotEmpty;
  bool get isActive => sessions.isNotEmpty;

  // 便利 getter，直接代理当前 session（若存在）
  Task? get targetTask => currentSession?.targetTask;
  Subtask? get targetSubtask => currentSession?.targetSubtask;
  FocusTimerStatus get status =>
      currentSession?.status ?? FocusTimerStatus.idle;
  int get remainingSeconds => currentSession?.remainingSeconds ?? 0;
  int get actualElapsedSeconds => currentSession?.actualElapsedSeconds ?? 0;
  int get extendedSeconds => currentSession?.extendedSeconds ?? 0;
  double get progressRatio => currentSession?.progressRatio ?? 0.0;
  bool get isSingleSubtask => currentSession?.isSingleSubtask ?? false;

  FocusTimerState copyWith({
    Map<String, TaskSession>? sessions,
    String? currentSessionKey,
    bool clearCurrentKey = false,
  }) {
    return FocusTimerState(
      sessions: sessions ?? this.sessions,
      currentSessionKey: clearCurrentKey
          ? null
          : (currentSessionKey ?? this.currentSessionKey),
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

  String? _lastStatusText;
  bool? _lastIsRunning;

  void _updateStatusIfChanged({
    required String statusText,
    required bool isRunning,
  }) {
    if (_lastStatusText != statusText || _lastIsRunning != isRunning) {
      _lastStatusText = statusText;
      _lastIsRunning = isRunning;
      StatusBarService.updateStatus(
        statusText: statusText,
        isRunning: isRunning,
      );
    }
  }

  void _syncStatusBar() {
    final running = state.runningSession;
    if (running != null) {
      final name = running.displayName;
      final timeStr = AppDateUtils.formatSecondsToTime(
      final timeStr = AppDateUtils.formatRemainingMinutes(
        running.remainingSeconds,
      );
      StatusBarService.updateStatus(
      _updateStatusIfChanged(
        statusText: '$name $timeStr',
        isRunning: true,
      );
    } else if (state.pausedSessions.isNotEmpty) {
      final first = state.pausedSessions.first;
      final name = first.displayName;
      StatusBarService.updateStatus(
        statusText: '$name (已暂停)',
        isRunning: false,
      );
    } else {
      StatusBarService.updateStatus(statusText: '空闲', isRunning: false);
      final promptSession = state.sessions.values
          .where((s) => s.status == FocusTimerStatus.completedPrompt)
          .firstOrNull;
      if (promptSession != null) {
        final name = promptSession.displayName;
        _updateStatusIfChanged(
          statusText: '$name (时间已到)',
          isRunning: false,
        );
      } else if (state.pausedSessions.isNotEmpty) {
        final first = state.pausedSessions.first;
        final name = first.displayName;
        _updateStatusIfChanged(
          statusText: '$name (已暂停)',
          isRunning: false,
        );
      } else {
        _updateStatusIfChanged(statusText: '空闲', isRunning: false);
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      final running = state.runningSession;
      if (running == null) {
        _ticker?.cancel();
        _syncStatusBar();
        return;
      }

      final newElapsed = running.actualElapsedSeconds + 1;
      final newRemaining = running.remainingSeconds - 1;

      if (newRemaining <= 0) {
        _ticker?.cancel();
        final updated = running.copyWith(
          remainingSeconds: 0,
          actualElapsedSeconds: newElapsed,
          status: FocusTimerStatus.completedPrompt,
        );
        final newMap = Map<String, TaskSession>.from(state.sessions);
        newMap[running.sessionKey] = updated;
        state = state.copyWith(sessions: newMap);
        _triggerTimeUpNotification(updated);
      } else {
        final updated = running.copyWith(
          remainingSeconds: newRemaining,
          actualElapsedSeconds: newElapsed,
        );
        final newMap = Map<String, TaskSession>.from(state.sessions);
        newMap[running.sessionKey] = updated;
        state = state.copyWith(sessions: newMap);
      }
      _syncStatusBar();
    });
  }

  void _triggerTimeUpNotification(TaskSession session) {
    final title = '任务时间已到达！';
    final taskName = session.displayName;
    final body = session.isSingleSubtask
        ? '子任务【$taskName】预计用时已到达，可直接延长同等时间继续。'
        : '任务【$taskName】预计用时已到达，请确认是否延长。';
    NotificationService.instance.notifyTimerCompleted(title: title, body: body);
  }

  /// 发起整项任务进行
  void startTask(Task task) {
    final key = task.id;
    _startSessionInternal(sessionKey: key, task: task, subtask: null);
  }

  void startTaskFocus(Task task) => startTask(task);

  /// 发起单个子任务进行
  void startSubtask(Task task, Subtask subtask) {
    final key = '${task.id}_${subtask.id}';
    _startSessionInternal(sessionKey: key, task: task, subtask: subtask);
  }

  void startSubtaskFocus(Task task, Subtask subtask) =>
      startSubtask(task, subtask);

  void _startSessionInternal({
    required String sessionKey,
    required Task task,
    required Subtask? subtask,
  }) {
    final newMap = Map<String, TaskSession>.from(state.sessions);

    // 核心规则：正在进行的任务只能有一个！如果此前有正在运行的任务，自动置为暂停
    for (final k in newMap.keys) {
      if (newMap[k]!.status == FocusTimerStatus.running && k != sessionKey) {
        newMap[k] = newMap[k]!.copyWith(status: FocusTimerStatus.paused);
      }
    }

    if (newMap.containsKey(sessionKey)) {
      // 已经存在该会话（例如暂停后重新继续）
      newMap[sessionKey] = newMap[sessionKey]!.copyWith(
        status: FocusTimerStatus.running,
        targetTask: task,
      );
    } else {
      // 新建会话
      final todayKey = AppDateUtils.todayKey();
      final int targetMinutes;
      if (subtask != null) {
        targetMinutes = max(1, subtask.estimatedMinutes);
      } else {
        final uncompleted = task.uncompletedSubtasks(todayKey);
        targetMinutes = uncompleted.isNotEmpty
            ? uncompleted.fold(0, (sum, st) => sum + st.estimatedMinutes)
            : max(1, task.totalEstimatedMinutes);
      }
      final plannedSecs = max(1, targetMinutes) * 60;

      newMap[sessionKey] = TaskSession(
        sessionKey: sessionKey,
        targetTask: task,
        targetSubtask: subtask,
        status: FocusTimerStatus.running,
        remainingSeconds: plannedSecs,
        initialPlannedSeconds: plannedSecs,
        actualElapsedSeconds: 0,
        extendedSeconds: 0,
        completedSubtaskIdsInSession: [],
        startTime: DateTime.now(),
      );
    }

    state = state.copyWith(sessions: newMap, currentSessionKey: sessionKey);

    _startTicker();
    _syncStatusBar();
  }

  /// 切换当前聚焦查看的会话大屏
  void switchToSession(String sessionKey) {
    if (state.sessions.containsKey(sessionKey)) {
      state = state.copyWith(currentSessionKey: sessionKey);
    }
  }

  /// 暂停指定会话（若未传 sessionKey 则暂停当前查看或正在运行的会话）
  void pause([String? sessionKey]) => pauseSession(
    sessionKey ?? state.currentSessionKey ?? state.runningSession?.sessionKey,
  );

  void pauseSession([String? sessionKey]) {
    final key =
        sessionKey ??
        state.currentSessionKey ??
        state.runningSession?.sessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session != null && session.status == FocusTimerStatus.running) {
      final updated = session.copyWith(status: FocusTimerStatus.paused);
      final newMap = Map<String, TaskSession>.from(state.sessions);
      newMap[key] = updated;
      state = state.copyWith(sessions: newMap);
      _ticker?.cancel();
      _syncStatusBar();
    }
  }

  /// 继续指定已暂停的会话（确保全系统仅有这一个运行）
  void resume([String? sessionKey]) => resumeSession(
    sessionKey ??
        state.currentSessionKey ??
        state.pausedSessions.firstOrNull?.sessionKey,
  );

  void resumeSession([String? sessionKey]) {
    final key =
        sessionKey ??
        state.currentSessionKey ??
        state.pausedSessions.firstOrNull?.sessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session != null) {
      final newMap = Map<String, TaskSession>.from(state.sessions);
      // 暂停其他所有正在运行的任务
      for (final k in newMap.keys) {
        if (newMap[k]!.status == FocusTimerStatus.running && k != key) {
          newMap[k] = newMap[k]!.copyWith(status: FocusTimerStatus.paused);
        }
      }
      newMap[key] = session.copyWith(status: FocusTimerStatus.running);
      state = state.copyWith(sessions: newMap, currentSessionKey: key);
      _startTicker();
      _syncStatusBar();
    }
  }

  /// 在进行中勾选子任务（智能减少时间更小值算法）
  Future<void> checkSubtask(String subtaskId, [String? sessionKey]) =>
      checkSubtaskInSession(
        sessionKey ?? state.currentSessionKey ?? '',
        subtaskId,
      );

  Future<void> checkSubtaskInSession(
    String? sessionKey,
    String subtaskId,
  ) async {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session == null) return;

    final task = session.targetTask;
    final todayKey = AppDateUtils.todayKey();
    final subtask = task.subtasks.firstWhere(
      (st) => st.id == subtaskId,
      orElse: () => Subtask(id: '', taskId: '', title: ''),
    );
    if (subtask.id.isEmpty) return;

    // 1. 标记完成
    await _ref
        .read(tasksProvider.notifier)
        .setSubtaskCompletion(task.id, subtaskId, true, dateKey: todayKey);

    // 2. 重新获取任务最新数据
    final allTasks = _ref.read(tasksProvider);
    final updatedTask = allTasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    // 3. 智能减少倒计时
    final remainingUncompleted = updatedTask.uncompletedSubtasks(todayKey);
    final int remainingEstimateSeconds =
        remainingUncompleted.fold(0, (sum, st) => sum + st.estimatedMinutes) *
        60;

    final int subtaskEstimateSeconds = subtask.estimatedMinutes * 60;
    final int reducedCurrentSeconds = max(
      0,
      session.remainingSeconds - subtaskEstimateSeconds,
    );

    final int newRemaining = min(
      remainingEstimateSeconds,
      reducedCurrentSeconds,
    );
    final updatedCompletedIds = [
      ...session.completedSubtaskIdsInSession,
      subtaskId,
    ];

    final newMap = Map<String, TaskSession>.from(state.sessions);

    if (remainingUncompleted.isEmpty || newRemaining <= 0) {
      _ticker?.cancel();
      final updated = session.copyWith(
        targetTask: updatedTask,
        remainingSeconds: 0,
        status: FocusTimerStatus.completedPrompt,
        completedSubtaskIdsInSession: updatedCompletedIds,
      );
      newMap[key] = updated;
      state = state.copyWith(sessions: newMap);
      _triggerTimeUpNotification(updated);
    } else {
      final updated = session.copyWith(
        targetTask: updatedTask,
        remainingSeconds: newRemaining,
        completedSubtaskIdsInSession: updatedCompletedIds,
      );
      newMap[key] = updated;
      state = state.copyWith(sessions: newMap);
    }

    _syncStatusBar();
  }

  /// 提前点击完成（或完成所有子任务）
  Future<void> finishEarly([String? sessionKey]) async {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session == null) return;

    final todayKey = AppDateUtils.todayKey();
    final task = session.targetTask;

    if (session.targetSubtask != null) {
      await _ref
          .read(tasksProvider.notifier)
          .setSubtaskCompletion(
            task.id,
            session.targetSubtask!.id,
            true,
            dateKey: todayKey,
          );
    } else {
      for (final st in task.subtasks) {
        if (!st.isCompletedOn(todayKey)) {
          await _ref
              .read(tasksProvider.notifier)
              .setSubtaskCompletion(task.id, st.id, true, dateKey: todayKey);
        }
      }
    }

    await _saveSessionRecord(session: session, isEarlyFinished: true);
    _removeSession(key);
  }

  /// 取消任务：直接取消，该任务所有专注统计时间和勾选进度作废！
  Future<void> cancelTask([String? sessionKey]) async {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session == null) return;

    final todayKey = AppDateUtils.todayKey();

    // 进度作废：将在本次进行过程中勾选完成的所有子任务状态还原为未完成
    for (final subtaskId in session.completedSubtaskIdsInSession) {
      await _ref
          .read(tasksProvider.notifier)
          .setSubtaskCompletion(
            session.targetTask.id,
            subtaskId,
            false,
            dateKey: todayKey,
          );
    }

    // 时间作废：不向 focus_sessions 写入任何记录！
    _removeSession(key);
  }

  Future<void> cancelOrClose({
    bool saveElapsedTime = false,
    String? sessionKey,
  }) async {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    if (saveElapsedTime) {
      await finishAndSave(key);
    } else {
      await cancelTask(key);
    }
  }

  /// 延长时间
  void extendTimer(int additionalMinutes, [String? sessionKey]) {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session == null) return;

    final additionalSeconds = max(1, additionalMinutes) * 60;
    final newMap = Map<String, TaskSession>.from(state.sessions);

    // 确保当前会话是唯一的 running 会话
    for (final k in newMap.keys) {
      if (newMap[k]!.status == FocusTimerStatus.running && k != key) {
        newMap[k] = newMap[k]!.copyWith(status: FocusTimerStatus.paused);
      }
    }

    newMap[key] = session.copyWith(
      remainingSeconds: session.remainingSeconds + additionalSeconds,
      extendedSeconds: session.extendedSeconds + additionalSeconds,
      status: FocusTimerStatus.running,
    );

    state = state.copyWith(sessions: newMap, currentSessionKey: key);
    _startTicker();
    _syncStatusBar();
  }

  /// 正常结束并保存打卡记录
  Future<void> finishAndSave([String? sessionKey]) async {
    final key = sessionKey ?? state.currentSessionKey;
    if (key == null) return;
    final session = state.sessions[key];
    if (session == null) return;

    await _saveSessionRecord(session: session, isEarlyFinished: false);
    _removeSession(key);
  }

  void _removeSession(String sessionKey) {
    final newMap = Map<String, TaskSession>.from(state.sessions);
    newMap.remove(sessionKey);

    String? nextKey;
    if (newMap.isNotEmpty) {
      nextKey = newMap.keys.first;
    }

    state = state.copyWith(
      sessions: newMap,
      currentSessionKey: nextKey,
      clearCurrentKey: nextKey == null,
    );

    if (state.runningSession == null) {
      _ticker?.cancel();
    }
    _syncStatusBar();
  }

  Future<void> _saveSessionRecord({
    required TaskSession session,
    required bool isEarlyFinished,
  }) async {
    final now = DateTime.now();
    final todayKey = AppDateUtils.todayKey();

    final record = FocusSession(
      id: const Uuid().v4(),
      taskId: session.targetTask.id,
      taskTitle: session.targetTask.title,
      subtaskId: session.targetSubtask?.id,
      subtaskTitle: session.targetSubtask?.title,
      startTime: session.startTime,
      endTime: now,
      actualDurationSeconds: session.actualElapsedSeconds,
      plannedDurationSeconds: session.initialPlannedSeconds,
      extendedSeconds: session.extendedSeconds,
      isEarlyFinished: isEarlyFinished,
      dateKey: todayKey,
      completedSubtaskIds: session.completedSubtaskIdsInSession,
    );

    await _ref.read(focusSessionsProvider.notifier).logSession(record);
  }
}

final focusTimerProvider =
    StateNotifierProvider<FocusTimerNotifier, FocusTimerState>((ref) {
      return FocusTimerNotifier(ref);
    });
