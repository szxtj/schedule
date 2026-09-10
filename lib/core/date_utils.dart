import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _dateKeyFormat = DateFormat('yyyy-MM-dd');

  /// 获取指定日期的键名，如 "2026-09-10"
  static String toDateKey(DateTime date) {
    return _dateKeyFormat.format(date);
  }

  /// 获取今天的键名
  static String todayKey() {
    return toDateKey(DateTime.now());
  }

  /// 格式化为友好显示的今天日期，如 "2026年9月10日 星期四"
  static String formatDisplayDate(DateTime date) {
    final weekdays = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    final formatted = DateFormat('yyyy年M月d日').format(date);
    final weekdayStr = weekdays[date.weekday];
    return '$formatted $weekdayStr';
  }

  /// 格式化分钟为“X小时Y分钟”或“Y分钟”
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0 分钟';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) {
      return '$mins 分钟';
    } else if (mins == 0) {
      return '$hours 小时';
    } else {
      return '$hours 小时 $mins 分钟';
    }
  }

  /// 格式化秒数为“mm:ss”或“hh:mm:ss”
  static String formatSecondsToTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final mins = (totalSeconds % 3600) ~/ 60;
    final secs = totalSeconds % 60;

    final minsStr = mins.toString().padLeft(2, '0');
    final secsStr = secs.toString().padLeft(2, '0');

    if (hours > 0) {
      final hoursStr = hours.toString().padLeft(2, '0');
      return '$hoursStr:$minsStr:$secsStr';
    }
    return '$minsStr:$secsStr';
  }

  /// 格式化秒数为汉字时长，如“1小时15分钟”
  static String formatSecondsDuration(int totalSeconds) {
    final totalMinutes = (totalSeconds / 60).round();
    return formatMinutes(totalMinutes);
  }
}

