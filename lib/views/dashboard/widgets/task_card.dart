import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants.dart';
import '../../../models/recurrence.dart';
import '../../../models/subtask.dart';
import '../../../models/task.dart';
import '../../../providers/focus_timer_provider.dart';
import '../../../providers/task_provider.dart';
import '../../dialogs/add_task_dialog.dart';
import '../../focus/focus_screen.dart';

class TaskCard extends ConsumerStatefulWidget {
  final Task task;
  final String dateKey;

  const TaskCard({
    super.key,
    required this.task,
    required this.dateKey,
  });

  @override
  ConsumerState<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends ConsumerState<TaskCard> {
  bool _isExpanded = true;
  final TextEditingController _quickSubtaskController = TextEditingController();
  bool _isAddingQuickSubtask = false;

  @override
  void dispose() {
    _quickSubtaskController.dispose();
    super.dispose();
  }

  void _startTaskFocus() {
    ref.read(focusTimerProvider.notifier).startTaskFocus(widget.task);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FocusScreen()),
    );
  }

  void _startSubtaskFocus(Subtask subtask) {
    ref.read(focusTimerProvider.notifier).startSubtaskFocus(widget.task, subtask);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FocusScreen()),
    );
  }

  void _editTask() async {
    final updated = await showDialog<Task>(
      context: context,
      builder: (context) => AddTaskDialog(initialTask: widget.task),
    );
    if (updated != null) {
      await ref.read(tasksProvider.notifier).updateTask(updated);
    }
  }

  void _deleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除任务？'),
        content: Text('删除后将无法恢复【${widget.task.title}】及其所有子任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(tasksProvider.notifier).deleteTask(widget.task.id);
    }
  }

  void _submitQuickSubtask() async {
    final text = _quickSubtaskController.text.trim();
    if (text.isEmpty) return;

    final newSubtask = Subtask(
      id: const Uuid().v4(),
      taskId: widget.task.id,
      title: text,
      estimatedMinutes: AppConstants.defaultEstimatedMinutes,
      orderIndex: widget.task.subtasks.length,
    );

    await ref.read(tasksProvider.notifier).addSubtask(widget.task.id, newSubtask);
    _quickSubtaskController.clear();
    setState(() {
      _isAddingQuickSubtask = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final dateKey = widget.dateKey;
    final isAllDone = task.isAllCompleted(dateKey);
    final completionRatio = task.completionRatio(dateKey);
    final completedMins = task.completedEstimatedMinutes(dateKey);
    final totalMins = task.totalEstimatedMinutes;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAllDone ? AppColors.accent.withValues(alpha: 0.3) : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头部总任务概览
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 折叠/展开箭头
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                      color: AppColors.textSecondaryLight,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 任务主信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildRecurrenceBadge(task.recurrence),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isAllDone ? AppColors.textMutedLight : AppColors.textPrimaryLight,
                                decoration: isAllDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // 进度与预估时间指示条
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: completionRatio,
                                minHeight: 6,
                                backgroundColor: AppColors.backgroundLight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isAllDone ? AppColors.accent : AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$completedMins/$totalMins 分钟 (${(completionRatio * 100).round()}%)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // 操作按钮区
                Row(
                  children: [
                    // 攻克整项任务按钮
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isAllDone
                            ? AppColors.textMutedLight
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isAllDone ? null : _startTaskFocus,
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('攻克整项任务', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 4),
                    // 更多菜单
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondaryLight),
                      onSelected: (val) {
                        if (val == 'edit') _editTask();
                        if (val == 'delete') _deleteTask();
                        if (val == 'addSubtask') {
                          setState(() {
                            _isExpanded = true;
                            _isAddingQuickSubtask = true;
                          });
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'addSubtask',
                          child: Row(
                            children: [
                              Icon(Icons.add, size: 18),
                              SizedBox(width: 8),
                              Text('添加子任务'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('编辑任务'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              SizedBox(width: 8),
                              Text('删除任务', style: TextStyle(color: AppColors.danger)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 展开的子任务列表
          if (_isExpanded) ...[
            const Divider(height: 1, color: AppColors.borderLight),
            Container(
              color: AppColors.backgroundLight.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ...task.subtasks.map((st) => _buildSubtaskTile(st, dateKey)),
                  // 快捷添加子任务输入行
                  if (_isAddingQuickSubtask)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                      child: Row(
                        children: [
                          const SizedBox(width: 36),
                          Expanded(
                            child: TextField(
                              controller: _quickSubtaskController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: '输入新子任务名称...',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              onSubmitted: (_) => _submitQuickSubtask(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _submitQuickSubtask,
                            child: const Text('添加'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              setState(() {
                                _isAddingQuickSubtask = false;
                                _quickSubtaskController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtaskTile(Subtask subtask, String dateKey) {
    final isDone = subtask.isCompletedOn(dateKey);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDone ? Colors.transparent : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          // 复选框（勾选即实时更新今日计划完成度）
          Checkbox(
            value: isDone,
            activeColor: AppColors.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              ref.read(tasksProvider.notifier).toggleSubtaskCompletion(
                    widget.task.id,
                    subtask.id,
                    dateKey: dateKey,
                  );
            },
          ),
          const SizedBox(width: 4),
          // 子任务标题
          Expanded(
            child: Text(
              subtask.title,
              style: TextStyle(
                fontSize: 13,
                color: isDone ? AppColors.textMutedLight : AppColors.textPrimaryLight,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          // 预计时间小胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${subtask.estimatedMinutes} 分钟',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 独立攻克此子任务按钮
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: isDone ? AppColors.textMutedLight : AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            onPressed: isDone ? null : () => _startSubtaskFocus(subtask),
            icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
            label: const Text('攻克此项', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurrenceBadge(RecurrenceRule rule) {
    Color bg;
    Color fg;
    IconData icon;

    switch (rule.type) {
      case RecurrenceType.todayOnly:
        bg = AppColors.primary.withValues(alpha: 0.1);
        fg = AppColors.primaryDark;
        icon = Icons.today_rounded;
        break;
      case RecurrenceType.daily:
        bg = AppColors.accent.withValues(alpha: 0.1);
        fg = AppColors.accent;
        icon = Icons.repeat_rounded;
        break;
      case RecurrenceType.weekly:
        bg = Colors.purple.withValues(alpha: 0.1);
        fg = Colors.purple;
        icon = Icons.calendar_view_week_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            rule.summaryText,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}
