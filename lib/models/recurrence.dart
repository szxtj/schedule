enum RecurrenceType {
  todayOnly, // 今日单次任务
  daily,     // 每日循环任务
  weekly,    // 每周循环任务 (如周一、周三)
}

extension RecurrenceTypeExtension on RecurrenceType {
  String get displayName {
    switch (this) {
      case RecurrenceType.todayOnly:
        return '今日单次';
      case RecurrenceType.daily:
        return '每日循环';
      case RecurrenceType.weekly:
        return '每周循环';
    }
  }

  static RecurrenceType fromString(String? value) {
    switch (value) {
      case 'daily':
        return RecurrenceType.daily;
      case 'weekly':
        return RecurrenceType.weekly;
      case 'todayOnly':
      default:
        return RecurrenceType.todayOnly;
    }
  }

  String toValueString() {
    switch (this) {
      case RecurrenceType.daily:
        return 'daily';
      case RecurrenceType.weekly:
        return 'weekly';
      case RecurrenceType.todayOnly:
        return 'todayOnly';
    }
  }
}

class RecurrenceRule {
  final RecurrenceType type;
  /// 仅当 type == RecurrenceType.weekly 时生效，值为 1(周一) 到 7(周日)
  final List<int> weeklyDays;

  const RecurrenceRule({
    this.type = RecurrenceType.todayOnly,
    this.weeklyDays = const [],
  });

  /// 检查给定日期是否匹配此规则
  bool matches(DateTime date, {String? targetDateKey}) {
    switch (type) {
      case RecurrenceType.todayOnly:
        // 如果指定了具体目标日期，则匹配该日期；若无，默认当天
        return true;
      case RecurrenceType.daily:
        return true;
      case RecurrenceType.weekly:
        return weeklyDays.contains(date.weekday);
    }
  }

  String get summaryText {
    switch (type) {
      case RecurrenceType.todayOnly:
        return '今日单次';
      case RecurrenceType.daily:
        return '每日循环';
      case RecurrenceType.weekly:
        if (weeklyDays.isEmpty) return '每周循环 (未选星期)';
        final names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
        final days = (List<int>.from(weeklyDays)..sort()).map((d) => names[d]).join('、');
        return '每周 $days';
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.toValueString(),
    'weeklyDays': weeklyDays,
  };

  factory RecurrenceRule.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RecurrenceRule();
    return RecurrenceRule(
      type: RecurrenceTypeExtension.fromString(json['type'] as String?),
      weeklyDays: (json['weeklyDays'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

