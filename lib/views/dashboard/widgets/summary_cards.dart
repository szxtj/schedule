import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../core/date_utils.dart';
import '../../../providers/dashboard_provider.dart';

class DashboardSummaryCards extends StatelessWidget {
  final DashboardMetrics metrics;
  final bool? isCompact;

  const DashboardSummaryCards({
    super.key,
    required this.metrics,
    this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 桌面端宽屏（>900）为单行4张卡片；普通屏幕与移动端（<=900）为 2x2 网格
        final isWide = constraints.maxWidth > 900;
        final compact = isCompact ?? (constraints.maxWidth < 500);
        return isWide ? _buildWideRow() : _buildWrappedGrid(compact);
      },
    );
  }

  Widget _buildWideRow() {
    return Row(
      children: [
        // 核心卡片 1：今日计划完成度百分比
        Expanded(flex: 3, child: _buildCompletionRateCard(false)),
        const SizedBox(width: 14),
        // 核心卡片 2：剩余预计时间
        Expanded(flex: 2, child: _buildRemainingTimeCard(false)),
        const SizedBox(width: 14),
        // 核心卡片 3：剩余子任务数
        Expanded(flex: 2, child: _buildRemainingSubtasksCard(false)),
        const SizedBox(width: 14),
        // 核心卡片 4：今日总专注时长 (实际打卡)
        Expanded(flex: 3, child: _buildFocusDurationCard(false)),
      ],
    );
  }

  Widget _buildWrappedGrid(bool isCompact) {
    final gap = isCompact ? 10.0 : 14.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildCompletionRateCard(isCompact)),
            SizedBox(width: gap),
            Expanded(child: _buildFocusDurationCard(isCompact)),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(child: _buildRemainingTimeCard(isCompact)),
            SizedBox(width: gap),
            Expanded(child: _buildRemainingSubtasksCard(isCompact)),
          ],
        ),
      ],
    );
  }

  /// 今日总任务计划完成度百分比（按已完成每项子任务的预计时间总和除以总预计时间来计算）
  Widget _buildCompletionRateCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 18),
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
            width: isCompact ? 46 : 58,
            height: isCompact ? 46 : 58,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: metrics.completionRatio,
                  strokeWidth: isCompact ? 5 : 6,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
                Text(
                  '${metrics.completionPercentage}%',
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isCompact ? 10 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '今日计划完成度',
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '已完成 ${metrics.completedEstimatedMinutes} 分钟',
                  style: TextStyle(
                    fontSize: isCompact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '总预估 ${metrics.totalEstimatedMinutes} 分钟 · 工时加权',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
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
  Widget _buildRemainingTimeCard(bool isCompact) {
    return _buildMetricCard(
      title: '剩余预计时间',
      value: AppDateUtils.formatMinutes(metrics.remainingEstimatedMinutes),
      subtitle: '今日未完成子任务工时总和',
      icon: Icons.hourglass_empty_rounded,
      color: AppColors.warning,
      isCompact: isCompact,
    );
  }

  /// 剩余子任务数量显示
  Widget _buildRemainingSubtasksCard(bool isCompact) {
    return _buildMetricCard(
      title: '剩余待办子任务',
      value: '${metrics.remainingSubtasksCount} 项',
      subtitle:
          '共 ${metrics.totalSubtasksCount} 项 (完成 ${metrics.completedSubtasksCount} 项)',
      icon: Icons.playlist_add_check_circle_rounded,
      color: AppColors.primary,
      isCompact: isCompact,
    );
  }

  /// 今日总专注时长（真实打卡时长）
  Widget _buildFocusDurationCard(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 18),
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
            width: isCompact ? 40 : 48,
            height: isCompact ? 40 : 48,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: AppColors.accent,
              size: isCompact ? 22 : 26,
            ),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '今日专注时长',
                      style: TextStyle(
                        fontSize: isCompact ? 11 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '打卡',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  AppDateUtils.formatSecondsDuration(
                    metrics.todayTotalFocusSeconds,
                  ),
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '实际: ${AppDateUtils.formatSecondsToTime(metrics.todayTotalFocusSeconds)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
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
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 18),
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
            width: isCompact ? 36 : 44,
            height: isCompact ? 36 : 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isCompact ? 20 : 24),
          ),
          SizedBox(width: isCompact ? 10 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isCompact ? 15 : 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10 : 11,
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
