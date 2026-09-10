class FocusSession {
  final String id;
  final String taskId;
  final String taskTitle;
  final String? subtaskId;
  final String? subtaskTitle;
  final DateTime startTime;
  final DateTime endTime;

  /// 真实专注消耗的时长（秒）
  final int actualDurationSeconds;

  /// 初始计划时长（秒）
  final int plannedDurationSeconds;

  /// 额外延长的时长（秒）
  final int extendedSeconds;

  /// 是否提前点击完成
  final bool isEarlyFinished;

  /// 归属日期 key (yyyy-MM-dd)
  final String dateKey;

  /// 本次专注中勾选完成的子任务 ID 列表
  final List<String> completedSubtaskIds;

  const FocusSession({
    required this.id,
    required this.taskId,
    required this.taskTitle,
    this.subtaskId,
    this.subtaskTitle,
    required this.startTime,
    required this.endTime,
    required this.actualDurationSeconds,
    required this.plannedDurationSeconds,
    this.extendedSeconds = 0,
    this.isEarlyFinished = false,
    required this.dateKey,
    this.completedSubtaskIds = const [],
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'taskTitle': taskTitle,
    'subtaskId': subtaskId,
    'subtaskTitle': subtaskTitle,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'actualDurationSeconds': actualDurationSeconds,
    'plannedDurationSeconds': plannedDurationSeconds,
    'extendedSeconds': extendedSeconds,
    'isEarlyFinished': isEarlyFinished,
    'dateKey': dateKey,
    'completedSubtaskIds': completedSubtaskIds,
  };

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      taskId: json['taskId'] as String? ?? '',
      taskTitle: json['taskTitle'] as String? ?? '',
      subtaskId: json['subtaskId'] as String?,
      subtaskTitle: json['subtaskTitle'] as String?,
      startTime:
          DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.now(),
      endTime:
          DateTime.tryParse(json['endTime'] as String? ?? '') ?? DateTime.now(),
      actualDurationSeconds:
          (json['actualDurationSeconds'] as num?)?.toInt() ?? 0,
      plannedDurationSeconds:
          (json['plannedDurationSeconds'] as num?)?.toInt() ?? 0,
      extendedSeconds: (json['extendedSeconds'] as num?)?.toInt() ?? 0,
      isEarlyFinished: json['isEarlyFinished'] as bool? ?? false,
      dateKey: json['dateKey'] as String? ?? '',
      completedSubtaskIds:
          (json['completedSubtaskIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}
