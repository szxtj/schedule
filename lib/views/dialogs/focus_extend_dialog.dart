import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/subtask.dart';
import '../../models/task.dart';

class FocusExtendDialog extends StatefulWidget {
  final Task task;
  final List<Subtask> uncompletedSubtasks;
  final int actualElapsedSeconds;

  const FocusExtendDialog({
    super.key,
    required this.task,
    required this.uncompletedSubtasks,
    required this.actualElapsedSeconds,
  });

  @override
  State<FocusExtendDialog> createState() => _FocusExtendDialogState();
}

class _FocusExtendDialogState extends State<FocusExtendDialog> {
  final Set<String> _selectedSubtaskIds = {};
  int _manualExtensionMinutes = 0;

  @override
  void initState() {
    super.initState();
    // 默认全选所有未完成子任务
    for (final st in widget.uncompletedSubtasks) {
      _selectedSubtaskIds.add(st.id);
    }
  }

  int get _selectedSubtasksEstimatedMinutes {
    return widget.uncompletedSubtasks
        .where((st) => _selectedSubtaskIds.contains(st.id))
        .fold(0, (sum, st) => sum + st.estimatedMinutes);
  }

  int get _totalExtensionMinutes {
    return _selectedSubtasksEstimatedMinutes + _manualExtensionMinutes;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.alarm_on_rounded,
                      color: AppColors.warning,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '攻克倒计时已结束！',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '本次已专注攻克：${AppDateUtils.formatSecondsDuration(widget.actualElapsedSeconds)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                '勾选未完成的子任务，智能延长攻克时间：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.uncompletedSubtasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
                      SizedBox(width: 8),
                      Text('太棒了！所有子任务已全部勾选完成！'),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.uncompletedSubtasks.length,
                    itemBuilder: (context, index) {
                      final st = widget.uncompletedSubtasks[index];
                      final isSelected = _selectedSubtaskIds.contains(st.id);
                      return CheckboxListTile(
                        value: isSelected,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          st.title,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          '预计需用时：${st.estimatedMinutes} 分钟',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+${st.estimatedMinutes}m',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedSubtaskIds.add(st.id);
                            } else {
                              _selectedSubtaskIds.remove(st.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 14),
              // 微调延长快捷选项
              Row(
                children: [
                  const Text(
                    '快捷微调追加：',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: [5, 10, 15, 30].map((mins) {
                      final isCurrent = _manualExtensionMinutes == mins;
                      return ChoiceChip(
                        label: Text('+$mins 分钟'),
                        selected: isCurrent,
                        onSelected: (selected) {
                          setState(() {
                            _manualExtensionMinutes = selected ? mins : 0;
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // 结束攻克并保存
                      Navigator.of(context).pop(0);
                    },
                    child: const Text('结束攻克并保存记录'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: _totalExtensionMinutes > 0
                        ? () {
                            Navigator.of(context).pop(_totalExtensionMinutes);
                          }
                        : null,
                    icon: const Icon(Icons.more_time_rounded),
                    label: Text(
                      _totalExtensionMinutes > 0
                          ? '智能延长 $_totalExtensionMinutes 分钟继续'
                          : '请勾选或选择延长时间',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

