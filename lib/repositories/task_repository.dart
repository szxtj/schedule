import 'package:uuid/uuid.dart';
import '../core/date_utils.dart';
import '../models/recurrence.dart';
import '../models/subtask.dart';
import '../models/task.dart';
import 'storage_service.dart';

class TaskRepository {
  static const String _fileName = 'tasks.json';
  final StorageService _storage;

  TaskRepository({StorageService? storage})
      : _storage = storage ?? StorageService.instance;

  Future<List<Task>> loadTasks() async {
    final data = await _storage.readJson(_fileName);
    if (data == null || data is! List) {
      // 首次初始化，生成初始引导样例任务
      final initialTasks = _createInitialSampleTasks();
      await saveTasks(initialTasks);
      return initialTasks;
    }
    return data.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<void> saveTasks(List<Task> tasks) async {
    final list = tasks.map((t) => t.toJson()).toList();
    await _storage.writeJson(_fileName, list);
  }

  List<Task> _createInitialSampleTasks() {
    final today = DateTime.now();
    final todayKey = AppDateUtils.toDateKey(today);
    const uuid = Uuid();

    final task1Id = uuid.v4();
    final task2Id = uuid.v4();

    return [
      Task(
        id: task1Id,
        title: '早晨高效专注计划',
        description: '梳理今日目标与核心工作',
        recurrence: const RecurrenceRule(type: RecurrenceType.daily),
        targetDateKey: todayKey,
        subtasks: [
          Subtask(
            id: uuid.v4(),
            taskId: task1Id,
            title: '收件箱清零与日程检视',
            estimatedMinutes: 15,
            orderIndex: 0,
          ),
          Subtask(
            id: uuid.v4(),
            taskId: task1Id,
            title: '设定今日最关键三件事 (Top 3)',
            estimatedMinutes: 10,
            orderIndex: 1,
          ),
        ],
      ),
      Task(
        id: task2Id,
        title: '项目架构设计与核心功能编码',
        description: '攻克关键业务逻辑与界面开发',
        recurrence: const RecurrenceRule(
          type: RecurrenceType.weekly,
          weeklyDays: [1, 2, 3, 4, 5], // 工作日
        ),
        targetDateKey: todayKey,
        subtasks: [
          Subtask(
            id: uuid.v4(),
            taskId: task2Id,
            title: '核心数据模型与倒计时算法实现',
            estimatedMinutes: 25,
            orderIndex: 0,
          ),
          Subtask(
            id: uuid.v4(),
            taskId: task2Id,
            title: '沉浸式任务攻克视图与提醒机制对接',
            estimatedMinutes: 30,
            orderIndex: 1,
          ),
          Subtask(
            id: uuid.v4(),
            taskId: task2Id,
            title: '多端自适应布局与完整功能验收',
            estimatedMinutes: 20,
            orderIndex: 2,
          ),
        ],
      ),
    ];
  }
}
