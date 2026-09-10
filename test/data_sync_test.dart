import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/models/focus_session.dart';
import 'package:schedule/models/recurrence.dart';
import 'package:schedule/models/subtask.dart';
import 'package:schedule/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('跨端数据同步与备份验证 (Data Sync & Serialization)', () {
    test('Task与FocusSession JSON序列化完全一致性验证', () {
      final task = Task(
        id: 'task-test-sync',
        title: '跨端同步测试任务',
        description: '测试 Mac 与 Android 数据层一致性',
        targetDateKey: '2026-09-10',
        recurrence: const RecurrenceRule(
          type: RecurrenceType.weekly,
          weeklyDays: [1, 3, 5],
        ),
        subtasks: [
          Subtask(
            id: 'sub-1',
            taskId: 'task-test-sync',
            title: '测试子任务1',
            estimatedMinutes: 30,
            dailyCompletions: {'2026-09-10': true},
          ),
          Subtask(
            id: 'sub-2',
            taskId: 'task-test-sync',
            title: '测试子任务2',
            estimatedMinutes: 45,
          ),
        ],
      );

      final taskJson = task.toJson();
      final restoredTask = Task.fromJson(taskJson);

      expect(restoredTask.id, task.id);
      expect(restoredTask.title, task.title);
      expect(restoredTask.targetDateKey, task.targetDateKey);
      expect(restoredTask.recurrence.type, RecurrenceType.weekly);
      expect(restoredTask.recurrence.weeklyDays, [1, 3, 5]);
      expect(restoredTask.subtasks.length, 2);
      expect(restoredTask.subtasks[0].isCompletedOn('2026-09-10'), isTrue);
      expect(restoredTask.subtasks[1].estimatedMinutes, 45);

      final session = FocusSession(
        id: 'session-test-1',
        taskId: 'task-test-sync',
        subtaskId: 'sub-1',
        taskTitle: '跨端同步测试任务',
        subtaskTitle: '测试子任务1',
        startTime: DateTime(2026, 9, 10, 14, 0, 0),
        endTime: DateTime(2026, 9, 10, 14, 30, 0),
        plannedDurationSeconds: 1800,
        actualDurationSeconds: 1800,
        dateKey: '2026-09-10',
      );

      final sessionJson = session.toJson();
      final restoredSession = FocusSession.fromJson(sessionJson);

      expect(restoredSession.id, session.id);
      expect(restoredSession.taskTitle, '跨端同步测试任务');
      expect(restoredSession.actualDurationSeconds, 1800);
      expect(restoredSession.plannedDurationSeconds, 1800);
      expect(restoredSession.dateKey, '2026-09-10');
      expect(restoredSession.isEarlyFinished, isFalse);
    });

    test('全量备份 JSON 结构打包与解包验证', () {
      final sampleBackup = {
        'version': 1,
        'exportedAt': '2026-09-10T14:30:00.000Z',
        'tasks': [
          {
            'id': 'task-1',
            'title': '示例任务',
            'targetDateKey': '2026-09-10',
            'recurrence': {'type': 'todayOnly', 'weeklyDays': []},
            'subtasks': [
              {
                'id': 'sub-1',
                'taskId': 'task-1',
                'title': '示例子任务',
                'estimatedMinutes': 25,
                'orderIndex': 0,
                'dailyCompletions': {},
              }
            ],
            'createdAt': '2026-09-10T10:00:00.000Z',
          }
        ],
        'focus_sessions': [
          {
            'id': 'sess-1',
            'taskId': 'task-1',
            'subtaskId': 'sub-1',
            'taskTitle': '示例任务',
            'subtaskTitle': '示例子任务',
            'startTime': '2026-09-10T10:00:00.000Z',
            'endTime': '2026-09-10T10:25:00.000Z',
            'plannedDurationSeconds': 1500,
            'actualDurationSeconds': 1500,
            'extendedSeconds': 0,
            'isEarlyFinished': false,
            'dateKey': '2026-09-10',
            'completedSubtaskIds': ['sub-1'],
          }
        ],
      };

      final jsonString = jsonEncode(sampleBackup);
      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<Map<String, dynamic>>());
      expect(decoded['version'], 1);
      expect(decoded['tasks'], isA<List>());
      expect(decoded['focus_sessions'], isA<List>());

      final tasksList = (decoded['tasks'] as List)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(tasksList.length, 1);
      expect(tasksList[0].title, '示例任务');

      final sessionsList = (decoded['focus_sessions'] as List)
          .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
          .toList();
      expect(sessionsList.length, 1);
      expect(sessionsList[0].taskTitle, '示例任务');
    });

    test('非法或损坏的 JSON 能够被安全识别', () {
      expect(
        () => jsonDecode('not a valid json'),
        throwsFormatException,
      );

      final invalidStructure = jsonDecode('{"some_key": "some_value"}');
      expect(invalidStructure['tasks'], isNull);
    });
  });
}
