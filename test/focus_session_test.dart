import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:schedule/core/date_utils.dart';
import 'package:schedule/models/focus_session.dart';
import 'package:schedule/models/recurrence.dart';
import 'package:schedule/models/subtask.dart';
import 'package:schedule/models/task.dart';
import 'package:schedule/providers/focus_session_provider.dart';
import 'package:schedule/providers/focus_timer_provider.dart';
import 'package:schedule/providers/task_provider.dart';
import 'package:schedule/repositories/focus_repository.dart';
import 'package:schedule/repositories/task_repository.dart';

class InMemoryTaskRepository extends TaskRepository {
  List<Task> tasks;
  InMemoryTaskRepository(this.tasks);

  @override
  Future<List<Task>> loadTasks() async => tasks;

  @override
  Future<void> saveTasks(List<Task> newTasks) async {
    tasks = newTasks;
  }
}

class InMemoryFocusRepository extends FocusRepository {
  List<FocusSession> sessions = [];
  @override
  Future<List<FocusSession>> loadSessions() async => sessions;
  @override
  Future<void> addSession(FocusSession session) async {
    sessions = [session, ...sessions];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final todayKey = AppDateUtils.todayKey();

  late Task taskA;
  late Task taskB;
  late ProviderContainer container;

  setUp(() async {
    taskA = Task(
      id: 'task-A',
      title: '任务A',
      targetDateKey: todayKey,
      recurrence: const RecurrenceRule(type: RecurrenceType.todayOnly),
      subtasks: [
        Subtask(id: 'sub-A1', taskId: 'task-A', title: '子任务A1', estimatedMinutes: 20),
        Subtask(id: 'sub-A2', taskId: 'task-A', title: '子任务A2', estimatedMinutes: 30),
      ],
    );

    taskB = Task(
      id: 'task-B',
      title: '任务B',
      targetDateKey: todayKey,
      recurrence: const RecurrenceRule(type: RecurrenceType.todayOnly),
      subtasks: [
        Subtask(id: 'sub-B1', taskId: 'task-B', title: '子任务B1', estimatedMinutes: 25),
      ],
    );

    container = ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository([taskA, taskB])),
        focusRepositoryProvider.overrideWithValue(InMemoryFocusRepository()),
      ],
    );

    // 触发 tasksProvider 与 focusSessionsProvider 初始加载并等待异步完成
    container.read(tasksProvider);
    container.read(focusSessionsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });

  tearDown(() {
    container.dispose();
  });

  test('互斥运行机制：同一时间只能有一项任务处于运行状态，启动新任务时原任务自动置为暂停', () async {
    final timerNotifier = container.read(focusTimerProvider.notifier);

    // 1. 启动任务A
    timerNotifier.startTask(taskA);
    var timerState = container.read(focusTimerProvider);
    expect(timerState.sessions.length, 1);
    expect(timerState.sessions['task-A']?.status, FocusTimerStatus.running);
    expect(timerState.runningSession?.sessionKey, 'task-A');

    // 2. 启动任务B -> 任务B处于 running，任务A自动转为 paused
    timerNotifier.startTask(taskB);
    timerState = container.read(focusTimerProvider);
    expect(timerState.sessions.length, 2);
    expect(timerState.sessions['task-B']?.status, FocusTimerStatus.running);
    expect(timerState.sessions['task-A']?.status, FocusTimerStatus.paused);
    expect(timerState.runningSession?.sessionKey, 'task-B');
    expect(timerState.pausedSessions.map((s) => s.sessionKey).toList(), ['task-A']);

    // 3. 恢复继续任务A -> 任务A变为 running，任务B自动转为 paused
    timerNotifier.resumeSession('task-A');
    timerState = container.read(focusTimerProvider);
    expect(timerState.sessions['task-A']?.status, FocusTimerStatus.running);
    expect(timerState.sessions['task-B']?.status, FocusTimerStatus.paused);
    expect(timerState.runningSession?.sessionKey, 'task-A');
  });

  test('取消任务机制：勾选的子任务进度回滚撤回，且专注记录不予保存作废', () async {
    final timerNotifier = container.read(focusTimerProvider.notifier);

    // 启动任务A
    timerNotifier.startTask(taskA);

    // 在该任务进行中勾选完成子任务 A1
    await timerNotifier.checkSubtaskInSession('task-A', 'sub-A1');

    // 确认任务A的子任务A1此时已被标记为完成
    var currentTasks = container.read(tasksProvider);
    var updatedA = currentTasks.firstWhere((t) => t.id == 'task-A');
    expect(updatedA.subtasks.firstWhere((st) => st.id == 'sub-A1').isCompletedOn(todayKey), true);

    // 取消任务A
    await timerNotifier.cancelTask('task-A');

    // 验证1：会话已从 sessions 中移除
    final timerState = container.read(focusTimerProvider);
    expect(timerState.sessions.containsKey('task-A'), false);

    // 验证2：进度作废 -> 子任务 A1 已被恢复为未完成！
    currentTasks = container.read(tasksProvider);
    updatedA = currentTasks.firstWhere((t) => t.id == 'task-A');
    expect(updatedA.subtasks.firstWhere((st) => st.id == 'sub-A1').isCompletedOn(todayKey), false);

    // 验证3：专注打卡记录未增加 (0条记录)
    final sessions = container.read(focusSessionsProvider);
    expect(sessions.isEmpty, true);
  });

  test('单个子任务进行：支持直接延长同等时间', () async {
    final timerNotifier = container.read(focusTimerProvider.notifier);
    final subtask = taskB.subtasks.first; // 25 分钟

    timerNotifier.startSubtask(taskB, subtask);
    final subKey = 'task-B_${subtask.id}';

    var timerState = container.read(focusTimerProvider);
    final session = timerState.sessions[subKey];
    expect(session, isNotNull);
    expect(session!.isSingleSubtask, true);
    expect(session.initialPlannedSeconds, 25 * 60);

    // 延长同等时间 (25分钟)
    timerNotifier.extendTimer(subtask.estimatedMinutes, subKey);
    timerState = container.read(focusTimerProvider);
    final updatedSession = timerState.sessions[subKey]!;
    expect(updatedSession.extendedSeconds, 25 * 60);
    expect(updatedSession.remainingSeconds, 50 * 60);
  });
}
