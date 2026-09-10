class Subtask {
  final String id;
  final String taskId;
  final String title;
  final int estimatedMinutes;
  final int orderIndex;
  /// 按日期记录完成状态，例如 {"2026-09-10": true}
  final Map<String, bool> dailyCompletions;

  const Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.estimatedMinutes = 25,
    this.orderIndex = 0,
    this.dailyCompletions = const {},
  });

  /// 指定日期是否已完成
  bool isCompletedOn(String dateKey) {
    return dailyCompletions[dateKey] == true;
  }

  Subtask toggleCompletion(String dateKey) {
    final current = isCompletedOn(dateKey);
    final updated = Map<String, bool>.from(dailyCompletions);
    updated[dateKey] = !current;
    return copyWith(dailyCompletions: updated);
  }

  Subtask setCompletion(String dateKey, bool completed) {
    final updated = Map<String, bool>.from(dailyCompletions);
    updated[dateKey] = completed;
    return copyWith(dailyCompletions: updated);
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    int? estimatedMinutes,
    int? orderIndex,
    Map<String, bool>? dailyCompletions,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
      dailyCompletions: dailyCompletions ?? this.dailyCompletions,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'estimatedMinutes': estimatedMinutes,
    'orderIndex': orderIndex,
    'dailyCompletions': dailyCompletions,
  };

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'] as String,
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 25,
      orderIndex: (json['orderIndex'] as num?)?.toInt() ?? 0,
      dailyCompletions: (json['dailyCompletions'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as bool),
          ) ??
          {},
    );
  }
}

