import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/core/date_utils.dart';
import 'package:schedule/models/recurrence.dart';
import 'package:schedule/models/subtask.dart';
import 'package:schedule/models/task.dart';

void main() {
  group('计划清单与核心算法验证', () {
    final todayKey = AppDateUtils.todayKey();

    test('任务至少包含一个子任务（若未填，默认以任务本身作为子任务）', () {
      final task = Task(
        id: 't-1',
        title: '测试独立任务',
        targetDateKey: todayKey,
        subtasks: [],
      );

      expect(task.subtasks.length, 1);
      expect(task.subtasks.first.title, '测试独立任务');
      expect(task.subtasks.first.estimatedMinutes, 25);
    });

    test('总任务计划完成度百分比（已完成子任务预估时间总和 / 总预估时间）', () {
      final task = Task(
        id: 't-2',
        title: '复合任务',
        targetDateKey: todayKey,
        subtasks: [
          Subtask(id: 's-1', taskId: 't-2', title: '子任务1', estimatedMinutes: 20),
          Subtask(id: 's-2', taskId: 't-2', title: '子任务2', estimatedMinutes: 30),
          Subtask(id: 's-3', taskId: 't-2', title: '子任务3', estimatedMinutes: 50),
        ],
      );

      expect(task.totalEstimatedMinutes, 100);

      // 未完成时
      expect(task.completionRatio(todayKey), 0.0);

      // 完成子任务 1 (20m)
      final task1 = task.copyWith(
        subtasks: [
          task.subtasks[0].setCompletion(todayKey, true),
          task.subtasks[1],
          task.subtasks[2],
        ],
      );
      expect(task1.completedEstimatedMinutes(todayKey), 20);
      expect(task1.completionRatio(todayKey), 0.20);

      // 再完成子任务 3 (50m) -> 70 / 100 = 70%
      final task2 = task1.copyWith(
        subtasks: [
          task1.subtasks[0],
          task1.subtasks[1],
          task1.subtasks[2].setCompletion(todayKey, true),
        ],
      );
      expect(task2.completedEstimatedMinutes(todayKey), 70);
      expect(task2.completionRatio(todayKey), 0.70);
    });

    test('智能减少剩余倒计时算法验证（取当前未完成预估总时间 与 倒计时扣除该任务预估时间 的更小值）', () {
      // 场景 1：总任务包含子任务 A(20m) 和 B(30m)，总计 50m (3000s)
      // 用户倒计时进行到剩余 2500s (即花了 500s 完成了 A)
      int currentRemainingSeconds = 2500;
      int subtaskAEstimateSeconds = 20 * 60; // 1200s
      int remainingUncompletedEstimateSeconds = 30 * 60; // 1800s (只剩 B)

      int reducedCurrentSeconds = max(0, currentRemainingSeconds - subtaskAEstimateSeconds); // 2500 - 1200 = 1300s
      int newRemaining = min(remainingUncompletedEstimateSeconds, reducedCurrentSeconds);

      // 1300s < 1800s，因此采纳更小值 1300s（节省的时间被保留）
      expect(newRemaining, 1300);

      // 场景 2：用户耗时较多，倒计时剩余 1000s 时才勾选 A(20m=1200s)
      currentRemainingSeconds = 1000;
      reducedCurrentSeconds = max(0, currentRemainingSeconds - subtaskAEstimateSeconds); // 0s
      newRemaining = min(remainingUncompletedEstimateSeconds, reducedCurrentSeconds);

      // 此时 0s < 1800s，更小值为 0s，将立即触发倒计时结束提示
      expect(newRemaining, 0);

      // 场景 3：用户刚开始 10 秒即勾选完成 B(30m=1800s)
      currentRemainingSeconds = 2990;
      int subtaskBEstimateSeconds = 30 * 60; // 1800s
      remainingUncompletedEstimateSeconds = 20 * 60; // 1200s (只剩 A)
      reducedCurrentSeconds = max(0, currentRemainingSeconds - subtaskBEstimateSeconds); // 2990 - 1800 = 1190s
      newRemaining = min(remainingUncompletedEstimateSeconds, reducedCurrentSeconds);
      expect(newRemaining, 1190);
    });

    test('循环任务匹配逻辑', () {
      final now = DateTime.now(); // 星期几: now.weekday
      final dailyRule = const RecurrenceRule(type: RecurrenceType.daily);
      expect(dailyRule.matches(now), true);

      final weeklyRule = RecurrenceRule(
        type: RecurrenceType.weekly,
        weeklyDays: [now.weekday],
      );
      expect(weeklyRule.matches(now), true);

      final otherWeekday = now.weekday == 7 ? 1 : now.weekday + 1;
      final nonMatchingWeeklyRule = RecurrenceRule(
        type: RecurrenceType.weekly,
        weeklyDays: [otherWeekday],
      );
      expect(nonMatchingWeeklyRule.matches(now), false);
    });

    test('状态栏剩余时间显示到分钟格式化算法 (formatRemainingMinutes)', () {
      expect(AppDateUtils.formatRemainingMinutes(1500), '25分钟');
      expect(AppDateUtils.formatRemainingMinutes(1499), '25分钟');
      expect(AppDateUtils.formatRemainingMinutes(1441), '25分钟');
      expect(AppDateUtils.formatRemainingMinutes(1440), '24分钟');
      expect(AppDateUtils.formatRemainingMinutes(61), '2分钟');
      expect(AppDateUtils.formatRemainingMinutes(60), '1分钟');
      expect(AppDateUtils.formatRemainingMinutes(30), '1分钟');
      expect(AppDateUtils.formatRemainingMinutes(0), '0分钟');
      expect(AppDateUtils.formatRemainingMinutes(-10), '0分钟');
      expect(AppDateUtils.formatRemainingMinutes(3600), '1小时');
      expect(AppDateUtils.formatRemainingMinutes(5400), '1小时30分钟');
    });
  });
}

