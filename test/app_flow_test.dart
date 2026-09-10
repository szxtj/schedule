import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/app.dart';
import 'package:schedule/core/date_utils.dart';
import 'package:schedule/models/recurrence.dart';
import 'package:schedule/models/subtask.dart';
import 'package:schedule/models/task.dart';
import 'package:schedule/providers/task_provider.dart';
import 'package:schedule/repositories/task_repository.dart';

class FakeTaskRepository extends TaskRepository {
  List<Task> fakeTasks = [];

  FakeTaskRepository(this.fakeTasks);

  @override
  Future<List<Task>> loadTasks() async {
    return fakeTasks;
  }

  @override
  Future<void> saveTasks(List<Task> tasks) async {
    fakeTasks = tasks;
  }
}

void main() {
  testWidgets('完整业务流程：创建任务、加权百分比计算、攻克倒计时与智能减少时间、打卡记录验证',
      (WidgetTester tester) async {
    final todayKey = AppDateUtils.todayKey();

    final sampleTask = Task(
      id: 'task-test-1',
      title: '系统核心模块研发',
      description: '完整端到端测试任务',
      recurrence: const RecurrenceRule(type: RecurrenceType.todayOnly),
      targetDateKey: todayKey,
      subtasks: [
        Subtask(
          id: 'sub-1',
          taskId: 'task-test-1',
          title: '设计数据模型与接口',
          estimatedMinutes: 20,
          orderIndex: 0,
        ),
        Subtask(
          id: 'sub-2',
          taskId: 'task-test-1',
          title: '实现倒计时与智能缩减算法',
          estimatedMinutes: 30,
          orderIndex: 1,
        ),
      ],
    );

    final fakeRepo = FakeTaskRepository([sampleTask]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const ScheduleApp(),
      ),
    );

    await tester.pumpAndSettle();

    // 1. 验证主界面是否加载了任务与初始看板指标
    expect(find.text('系统核心模块研发'), findsWidgets);
    expect(find.text('今日计划完成度'), findsOneWidget);
    // 初始完成度 0% (已完成 0 分钟 / 总预计 50 分钟)
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('已完成 0 分钟'), findsOneWidget);
    expect(find.text('50 分钟'), findsOneWidget); // 剩余预计时间

    // 2. 勾选子任务 1 (20m) -> 实时验证今日计划完成度更新为 40% (20 / 50 = 40%)
    final subtask1Checkbox = find.byType(Checkbox).first;
    await tester.tap(subtask1Checkbox);
    await tester.pumpAndSettle();

    expect(find.text('40%'), findsOneWidget);
    expect(find.text('已完成 20 分钟'), findsOneWidget);
    expect(find.text('30 分钟'), findsNWidgets(2)); // 看板剩余 30 分钟 + 子任务2预估 30 分钟

    // 3. 点击“攻克整项任务”进入攻克全屏视图
    final conquerButton = find.text('攻克整项任务');
    expect(conquerButton, findsOneWidget);
    await tester.tap(conquerButton);
    await tester.pumpAndSettle();

    // 验证进入专注界面
    expect(find.text('正在攻克整项综合任务'), findsOneWidget);
    expect(find.text('提前完成'), findsOneWidget);
    // 初始倒计时应为剩余未完成子任务（sub-2: 30分钟 = 1800秒 = 30:00）
    expect(find.text('30:00'), findsOneWidget);

    // 4. 点击“提前完成”
    await tester.tap(find.text('提前完成'));
    await tester.pumpAndSettle();

    // 返回主界面后，所有子任务已完成，完成度应达 100%
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('已完成 50 分钟'), findsOneWidget);
    expect(find.text('0 分钟'), findsNWidgets(2)); // 剩余预计时间 0 分钟 + 今日专注时长 0 分钟
  });
}
