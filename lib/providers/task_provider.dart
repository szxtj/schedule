import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/date_utils.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

class TaskNotifier extends StateNotifier<List<Task>> {
  final TaskRepository _repository;

  TaskNotifier(this._repository) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final tasks = await _repository.loadTasks();
    if (!mounted) return;
    state = tasks;
  }

  Future<void> reload() async => _load();

  Future<void> _save() async {
    await _repository.saveTasks(state);
  }

  Future<void> addTask(Task task) async {
    state = [task, ...state];
    await _save();
  }

  Future<void> updateTask(Task updated) async {
    state = [
      for (final t in state)
        if (t.id == updated.id) updated else t,
    ];
    await _save();
  }

  Future<void> deleteTask(String taskId) async {
    state = state.where((t) => t.id != taskId).toList();
    await _save();
  }

  /// 切换指定子任务在特定日期的完成状态（默认今日）
  Future<void> toggleSubtaskCompletion(
    String taskId,
    String subtaskId, {
    String? dateKey,
  }) async {
    final key = dateKey ?? AppDateUtils.todayKey();
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            subtasks: [
              for (final st in task.subtasks)
                if (st.id == subtaskId) st.toggleCompletion(key) else st,
            ],
          )
        else
          task,
    ];
    await _save();
  }

  /// 显式设置指定子任务在特定日期的完成状态
  Future<void> setSubtaskCompletion(
    String taskId,
    String subtaskId,
    bool completed, {
    String? dateKey,
  }) async {
    final key = dateKey ?? AppDateUtils.todayKey();
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            subtasks: [
              for (final st in task.subtasks)
                if (st.id == subtaskId)
                  st.setCompletion(key, completed)
                else
                  st,
            ],
          )
        else
          task,
    ];
    await _save();
  }

  /// 为指定任务添加子任务
  Future<void> addSubtask(String taskId, Subtask subtask) async {
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(subtasks: [...task.subtasks, subtask])
        else
          task,
    ];
    await _save();
  }

  /// 删除子任务（确保任务始终至少保留一个子任务）
  Future<void> deleteSubtask(String taskId, String subtaskId) async {
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            subtasks: task.subtasks.length > 1
                ? task.subtasks.where((st) => st.id != subtaskId).toList()
                : task.subtasks,
          )
        else
          task,
    ];
    await _save();
  }
}

final tasksProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  return TaskNotifier(repo);
});
