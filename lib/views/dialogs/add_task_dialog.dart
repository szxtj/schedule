import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/recurrence.dart';
import '../../models/subtask.dart';
import '../../models/task.dart';

class AddTaskDialog extends StatefulWidget {
  final Task? initialTask;

  const AddTaskDialog({super.key, this.initialTask});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _SubtaskDraft {
  String id;
  TextEditingController titleController;
  int estimatedMinutes;

  _SubtaskDraft({
    required this.id,
    required String title,
    required this.estimatedMinutes,
  }) : titleController = TextEditingController(text: title);

  void dispose() {
    titleController.dispose();
  }
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  RecurrenceType _recurrenceType = RecurrenceType.todayOnly;
  final Set<int> _selectedWeeklyDays = {1, 2, 3, 4, 5}; // 默认工作日
  final List<_SubtaskDraft> _subtaskDrafts = [];

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descController = TextEditingController(text: task?.description ?? '');

    if (task != null) {
      _recurrenceType = task.recurrence.type;
      _selectedWeeklyDays.clear();
      _selectedWeeklyDays.addAll(task.recurrence.weeklyDays);
      for (final st in task.subtasks) {
        _subtaskDrafts.add(
          _SubtaskDraft(
            id: st.id,
            title: st.title,
            estimatedMinutes: st.estimatedMinutes,
          ),
        );
      }
    } else {
      // 默认至少包含一个子任务（初始与任务本身同名或默认名称）
      _subtaskDrafts.add(
        _SubtaskDraft(
          id: const Uuid().v4(),
          title: '',
          estimatedMinutes: AppConstants.defaultEstimatedMinutes,
        ),
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    for (final d in _subtaskDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  void _addSubtask() {
    setState(() {
      _subtaskDrafts.add(
        _SubtaskDraft(
          id: const Uuid().v4(),
          title: '',
          estimatedMinutes: AppConstants.defaultEstimatedMinutes,
        ),
      );
    });
  }

  void _removeSubtask(int index) {
    if (_subtaskDrafts.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('每项任务必须至少包含一个子任务')));
      return;
    }
    setState(() {
      final removed = _subtaskDrafts.removeAt(index);
      removed.dispose();
    });
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    final taskTitle = _titleController.text.trim();
    final taskId = widget.initialTask?.id ?? const Uuid().v4();
    final todayKey = AppDateUtils.todayKey();

    // 构建子任务列表
    final subtasks = <Subtask>[];
    for (var i = 0; i < _subtaskDrafts.length; i++) {
      final draft = _subtaskDrafts[i];
      var subTitle = draft.titleController.text.trim();
      if (subTitle.isEmpty) {
        // 如果未填子任务名，则默认为任务本身标题或“执行第 N 项”
        subTitle = _subtaskDrafts.length == 1
            ? taskTitle
            : '$taskTitle (步骤 ${i + 1})';
      }

      // 保留原有完成记录（如果是编辑现有子任务）
      Map<String, bool> completions = {};
      if (widget.initialTask != null) {
        final existing = widget.initialTask!.subtasks
            .where((st) => st.id == draft.id)
            .toList();
        if (existing.isNotEmpty) {
          completions = existing.first.dailyCompletions;
        }
      }

      subtasks.add(
        Subtask(
          id: draft.id,
          taskId: taskId,
          title: subTitle,
          estimatedMinutes: draft.estimatedMinutes,
          orderIndex: i,
          dailyCompletions: completions,
        ),
      );
    }

    final task = Task(
      id: taskId,
      title: taskTitle,
      description: _descController.text.trim(),
      recurrence: RecurrenceRule(
        type: _recurrenceType,
        weeklyDays: _recurrenceType == RecurrenceType.weekly
            ? _selectedWeeklyDays.toList()
            : const [],
      ),
      targetDateKey: widget.initialTask?.targetDateKey ?? todayKey,
      subtasks: subtasks,
      createdAt: widget.initialTask?.createdAt,
      isArchived: widget.initialTask?.isArchived ?? false,
    );

    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTask != null;
    final totalMinutes = _subtaskDrafts.fold(
      0,
      (sum, d) => sum + d.estimatedMinutes,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部标题与总时间
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? '编辑计划任务' : '创建新计划任务',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '总预估工时: ${AppDateUtils.formatMinutes(totalMinutes)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      // 任务标题
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '任务名称 *',
                          hintText: '例如：完成方案设计、阅读专业书籍',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          prefixIcon: Icon(Icons.task_alt_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '请输入任务名称';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // 任务描述
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: '任务备注（可选）',
                          hintText: '添加备忘、执行重点或相关链接...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // 循环模式选择
                      const Text(
                        '计划周期与循环模式',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<RecurrenceType>(
                        segments: const [
                          ButtonSegment(
                            value: RecurrenceType.todayOnly,
                            label: Text('今日单次'),
                            icon: Icon(Icons.today_rounded),
                          ),
                          ButtonSegment(
                            value: RecurrenceType.daily,
                            label: Text('每日循环'),
                            icon: Icon(Icons.repeat_rounded),
                          ),
                          ButtonSegment(
                            value: RecurrenceType.weekly,
                            label: Text('每周固定几天'),
                            icon: Icon(Icons.calendar_view_week_rounded),
                          ),
                        ],
                        selected: {_recurrenceType},
                        onSelectionChanged: (set) {
                          setState(() {
                            _recurrenceType = set.first;
                          });
                        },
                      ),
                      if (_recurrenceType == RecurrenceType.weekly) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (var d = 1; d <= 7; d++) ...[
                              FilterChip(
                                label: Text(_weekdayName(d)),
                                selected: _selectedWeeklyDays.contains(d),
                                onSelected: (sel) {
                                  setState(() {
                                    if (sel) {
                                      _selectedWeeklyDays.add(d);
                                    } else if (_selectedWeeklyDays.length > 1) {
                                      _selectedWeeklyDays.remove(d);
                                    }
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      // 子任务配置区
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '子任务清单 (用于加权计算完成度与任务倒计时)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addSubtask,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('添加子任务'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._subtaskDrafts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final draft = entry.value;
                        return _buildSubtaskDraftItem(index, draft);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 底部按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _onSave,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(isEditing ? '保存修改' : '创建计划'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtaskDraftItem(int index, _SubtaskDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: draft.titleController,
              decoration: InputDecoration(
                hintText: _subtaskDrafts.length == 1
                    ? '默认与总任务一致（或输入子步骤名）'
                    : '子任务 ${index + 1} 名称',
                isDense: true,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 预计用时选择
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: draft.estimatedMinutes,
                isDense: true,
                items: AppConstants.quickMinutesPresets.map((mins) {
                  return DropdownMenuItem<int>(
                    value: mins,
                    child: Text(
                      '$mins 分钟',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() {
                      draft.estimatedMinutes = newVal;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: _subtaskDrafts.length > 1
                ? AppColors.danger
                : Colors.grey[350],
            tooltip: _subtaskDrafts.length > 1 ? '删除此子任务' : '至少保留一个子任务',
            onPressed: () => _removeSubtask(index),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int day) {
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return names[day];
  }
}
