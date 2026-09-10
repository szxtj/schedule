import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../core/date_utils.dart';
import 'recurrence.dart';
import 'subtask.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final RecurrenceRule recurrence;
  /// 单次任务的目标日期键，例如 "2026-09-10"
  final String targetDateKey;
  final List<Subtask> subtasks;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.recurrence = const RecurrenceRule(),
    required this.targetDateKey,
    required List<Subtask> subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isArchived = false,
  })  : subtasks = _ensureAtLeastOneSubtask(id, title, subtasks),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 保证每个任务至少包含一个子任务（若为空，则默认为任务本身）
  static List<Subtask> _ensureAtLeastOneSubtask(
    String taskId,
    String taskTitle,
    List<Subtask> original,
  ) {
    if (original.isNotEmpty) {
      return original;
    }
    return [
      Subtask(
        id: const Uuid().v4(),
        taskId: taskId,
        title: taskTitle.isNotEmpty ? taskTitle : '执行任务',
        estimatedMinutes: AppConstants.defaultEstimatedMinutes,
        orderIndex: 0,
      ),
    ];
  }

  /// 检查给定日期是否应展示该任务
  bool isScheduledFor(DateTime date) {
    if (isArchived) return false;
    final dateKey = AppDateUtils.toDateKey(date);
    switch (recurrence.type) {
      case RecurrenceType.todayOnly:
        return targetDateKey == dateKey;
      case RecurrenceType.daily:
        // 创建日期之后的每日都匹配
        final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final checkDay = DateTime(date.year, date.month, date.day);
        return !checkDay.isBefore(createdDay);
      case RecurrenceType.weekly:
        final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
        final checkDay = DateTime(date.year, date.month, date.day);
        if (checkDay.isBefore(createdDay)) return false;
        return recurrence.weeklyDays.contains(date.weekday);
    }
  }

  /// 总预估时间（分钟）
  int get totalEstimatedMinutes {
    return subtasks.fold(0, (sum, st) => sum + st.estimatedMinutes);
  }

  /// 指定日期已完成的预估时间（分钟）
  int completedEstimatedMinutes(String dateKey) {
    return subtasks
        .where((st) => st.isCompletedOn(dateKey))
        .fold(0, (sum, st) => sum + st.estimatedMinutes);
  }

  /// 指定日期未完成的预估时间（分钟）
  int remainingEstimatedMinutes(String dateKey) {
    return subtasks
        .where((st) => !st.isCompletedOn(dateKey))
        .fold(0, (sum, st) => sum + st.estimatedMinutes);
  }

  /// 指定日期未完成的子任务列表
  List<Subtask> uncompletedSubtasks(String dateKey) {
    return subtasks.where((st) => !st.isCompletedOn(dateKey)).toList();
  }

  /// 指定日期已完成的子任务列表
  List<Subtask> completedSubtasks(String dateKey) {
    return subtasks.where((st) => st.isCompletedOn(dateKey)).toList();
  }

  /// 是否全部完成
  bool isAllCompleted(String dateKey) {
    if (subtasks.isEmpty) return false;
    return subtasks.every((st) => st.isCompletedOn(dateKey));
  }

  /// 任务完成度百分比（0.0 ~ 1.0）
  double completionRatio(String dateKey) {
    final total = totalEstimatedMinutes;
    if (total == 0) return isAllCompleted(dateKey) ? 1.0 : 0.0;
    return completedEstimatedMinutes(dateKey) / total;
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    RecurrenceRule? recurrence,
    String? targetDateKey,
    List<Subtask>? subtasks,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      recurrence: recurrence ?? this.recurrence,
      targetDateKey: targetDateKey ?? this.targetDateKey,
      subtasks: subtasks ?? this.subtasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isArchived: isArchived ?? this.isArchived,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'recurrence': recurrence.toJson(),
    'targetDateKey': targetDateKey,
    'subtasks': subtasks.map((st) => st.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isArchived': isArchived,
  };

  factory Task.fromJson(Map<String, dynamic> json) {
    final subtasksJson = json['subtasks'] as List<dynamic>? ?? [];
    final subtasksList = subtasksJson
        .map((e) => Subtask.fromJson(e as Map<String, dynamic>))
        .toList();

    return Task(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      recurrence: RecurrenceRule.fromJson(json['recurrence'] as Map<String, dynamic>?),
      targetDateKey: json['targetDateKey'] as String? ?? AppDateUtils.todayKey(),
      subtasks: subtasksList,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}

