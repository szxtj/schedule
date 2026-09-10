import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../models/subtask.dart';
import '../../models/task.dart';

class FocusExtendDialog extends StatefulWidget {
  final Task task;
  final Subtask? targetSubtask;
  final List<Subtask> uncompletedSubtasks;
  final int actualElapsedSeconds;

  const FocusExtendDialog({
    super.key,
    required this.task,
    this.targetSubtask,
    required this.uncompletedSubtasks,
    required this.actualElapsedSeconds,
  });

  @override
  State<FocusExtendDialog> createState() => _FocusExtendDialogState();
}

class _FocusExtendDialogState extends State<FocusExtendDialog> {
  final Set<String> _selectedSubtaskIds = {};
  int _manualExtensionMinutes = 0;

  bool get _isSingleSubtask => widget.targetSubtask != null;

  @override
  void initState() {
    super.initState();
    if (_isSingleSubtask) {
      // 单个子任务时，默认延长时间即为该子任务同等预计时长
      _manualExtensionMinutes = widget.targetSubtask!.estimatedMinutes;
    } else {
      // 主任务时，默认全选所有未完成子任务智能计算
      for (final st in widget.uncompletedSubtasks) {
        _selectedSubtaskIds.add(st.id);
      }
    }
  }

  int get _selectedSubtasksEstimatedMinutes {
    return widget.uncompletedSubtasks
        .where((st) => _selectedSubtaskIds.contains(st.id))
        .fold(0, (sum, st) => sum + st.estimatedMinutes);
  }

  int get _totalExtensionMinutes {
    if (_isSingleSubtask) {
      return _manualExtensionMinutes;
    }
    return _selectedSubtasksEstimatedMinutes + _manualExtensionMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.targetSubtask?.title ?? widget.task.title;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部提示
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
                        Text(
                          _isSingleSubtask ? '子任务时间已到达！' : '任务倒计时已到达！',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '【$displayName】已持续进行：${AppDateUtils.formatSecondsDuration(widget.actualElapsedSeconds)}',
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

              // 内容主体：区分单个子任务与整项综合任务
              if (_isSingleSubtask) ...[
                // 单个子任务：直接延长同等时间
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '当前子任务原预计用时：${widget.targetSubtask!.estimatedMinutes} 分钟',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '您可以直接延长同等长度时间继续专注，或根据需要微调延长时间：',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // 默认同等时间按钮
                          ChoiceChip(
                            label: Text(
                              '延长同等时间 (+${widget.targetSubtask!.estimatedMinutes}m)',
                            ),
                            selected:
                                _manualExtensionMinutes ==
                                widget.targetSubtask!.estimatedMinutes,
                            selectedColor: AppColors.accent.withValues(
                              alpha: 0.2,
                            ),
                            onSelected: (sel) {
                              setState(() {
                                _manualExtensionMinutes = sel
                                    ? widget.targetSubtask!.estimatedMinutes
                                    : 0;
                              });
                            },
                          ),
                          // 快捷追加选项
                          ...[5, 10, 15, 30].map((mins) {
                            final isCur =
                                _manualExtensionMinutes == mins &&
                                mins != widget.targetSubtask!.estimatedMinutes;
                            return ChoiceChip(
                              label: Text('+$mins 分钟'),
                              selected: isCur,
                              onSelected: (selected) {
                                setState(() {
                                  _manualExtensionMinutes = selected ? mins : 0;
                                });
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 整项任务：勾选未完成子任务智能计算延长时间
                const Text(
                  '勾选未完成的子任务，智能延长任务时间：',
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
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('所有子任务已全部勾选完成！'),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight,
                            ),
                          ),
                          secondary: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      '快捷追加：',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
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
              ],

              const SizedBox(height: 24),
              // 底部操作按钮
              Row(
                children: [
                  // 取消任务按钮（作废统计与进度）
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      // 返回 -1 代表取消任务
                      Navigator.of(context).pop(-1);
                    },
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('取消任务'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {
                      // 返回 0 代表结束任务并保存打卡记录
                      Navigator.of(context).pop(0);
                    },
                    child: const Text('结束并保存记录'),
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
                          ? '延时 $_totalExtensionMinutes 分钟继续'
                          : '请选择延长时间',
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
