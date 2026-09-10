import 'package:flutter/material.dart';
import '../../../core/constants.dart';
import '../../../providers/dashboard_provider.dart';

enum SidebarNavSection {
  today,
  daily,
  weekly,
  all,
  records,
}

class DashboardSidebar extends StatelessWidget {
  final SidebarNavSection currentSection;
  final ValueChanged<SidebarNavSection> onSectionChanged;
  final DashboardMetrics metrics;

  const DashboardSidebar({
    super.key,
    required this.currentSection,
    required this.onSectionChanged,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: const Color(0xFFF1F5F9), // Slate 100
      child: Column(
        children: [
          // 顶部应用 Logo 与名称
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      '专注与计划管理',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderLight),
          const SizedBox(height: 12),
          // 导航项
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildNavItem(
                  section: SidebarNavSection.today,
                  title: '今日计划清单',
                  icon: Icons.today_rounded,
                  badge: metrics.remainingSubtasksCount > 0
                      ? '${metrics.remainingSubtasksCount}'
                      : null,
                  badgeColor: AppColors.primary,
                ),
                _buildNavItem(
                  section: SidebarNavSection.daily,
                  title: '每日循环任务',
                  icon: Icons.repeat_rounded,
                ),
                _buildNavItem(
                  section: SidebarNavSection.weekly,
                  title: '每周固定循环',
                  icon: Icons.calendar_view_week_rounded,
                ),
                _buildNavItem(
                  section: SidebarNavSection.all,
                  title: '全部所有任务',
                  icon: Icons.folder_open_rounded,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: AppColors.borderLight),
                ),
                _buildNavItem(
                  section: SidebarNavSection.records,
                  title: '专注攻克明细',
                  icon: Icons.insights_rounded,
                ),
              ],
            ),
          ),
          // 底部今日专注小提醒
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '今日已专注 ${(metrics.todayTotalFocusSeconds / 60).round()} 分钟',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required SidebarNavSection section,
    required String title,
    required IconData icon,
    String? badge,
    Color? badgeColor,
  }) {
    final isSelected = currentSection == section;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(
          icon,
          size: 20,
          color: isSelected ? AppColors.primary : AppColors.textSecondaryLight,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? AppColors.primary : AppColors.textPrimaryLight,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => onSectionChanged(section),
      ),
    );
  }
}

