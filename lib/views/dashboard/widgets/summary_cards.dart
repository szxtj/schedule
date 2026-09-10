import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/date_utils.dart';
import '../../../providers/dashboard_provider.dart';

class DashboardSummaryCards extends StatelessWidget {
  final DashboardMetrics metrics;

  const DashboardSummaryCards({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端双行或单行响应式排版
        final isWide = constraints.maxWidth > 900;
        return isWide ? _buildWideRow() : _buildWrappedGrid();
      },
    );
  }

  Widget _buildWideRow() {
    return Row(
      children: [
        // 核心卡片 1：今日计划完成度百分比
        Expanded(flex: 3, child: _buildCompletionRateCard()),
        const SizedBox(width: 14),
        // 核心卡片 2：剩余预计时间
        Expanded(flex: 2, child: _buildRemainingTimeCard()),
        const SizedBox(width: 14),
        // 核心卡片 3：剩余子任务数
        Expanded(flex: 2, child: _buildRemainingSubtasksCard()),
        const SizedBox(width: 14),
        // 核心卡片 4：今日总专注时长 (实际打卡)
        Expanded(flex: 3, child: _buildFocusDurationCard()),
      ],
    );
  }

  Widget _buildWrappedGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompletionRateCard()),
            const SizedBox(width: 14),
            Expanded(child: _buildFocusDurationCard()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildRemainingTimeCard()),
            const SizedBox(width: 14),
            Expanded(child: _buildRemainingSubtasksCard()),
          ],
        ),
      ],
    );
  }

  /// 今日总任务计划完成度百分比（按已完成每项子任务的预计时间总和除以总预计时间来计算）
  Widget _buildCompletionRateCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            height: 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: metrics.completionRatio,
                  strokeWidth: 6,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                Text(
                  '${metrics.completionPercentage}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '今日计划完成度',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '已完成 ${metrics.completedEstimatedMinutes} 分钟',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '总预估 ${metrics.totalEstimatedMinutes} 分钟 · 按预估工时加权',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 剩余预计时间显示
  Widget _buildRemainingTimeCard() {
    return _buildMetricCard(
      title: '剩余预计时间',
      value: AppDateUtils.formatMinutes(metrics.remainingEstimatedMinutes),
      subtitle: '今日未完成子任务工时总和',
      icon: Icons.hourglass_empty_rounded,
      color: AppColors.warning,
    );
  }

  /// 剩余子任务数量显示
  Widget _buildRemainingSubtasksCard() {
    return _buildMetricCard(
      title: '剩余待办子任务',
      value: '${metrics.remainingSubtasksCount} 项',
      subtitle: '共 ${metrics.totalSubtasksCount} 个子任务 (已完成 ${metrics.completedSubtasksCount} 项)',
      icon: Icons.playlist_add_check_circle_rounded,
      color: AppColors.primary,
    );
  }

  /// 今日总专注时长（任务攻克状态真实打卡时长）
  Widget _buildFocusDurationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: AppColors.accent,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      '今日总专注时长',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '真实打卡',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppDateUtils.formatSecondsDuration(metrics.todayTotalFocusSeconds),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '攻克模式实际耗时: ${AppDateUtils.formatSecondsToTime(metrics.todayTotalFocusSeconds)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

