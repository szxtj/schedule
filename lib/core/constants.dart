import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = '计划清单';

  // 默认子任务预估时间（分钟）
  static const int defaultEstimatedMinutes = 25;

  // 预估时间快捷推荐（分钟）
  static const List<int> quickMinutesPresets = [
    5,
    10,
    15,
    25,
    30,
    45,
    60,
    90,
    120,
  ];

  // 延长时间快捷推荐（分钟）
  static const List<int> extensionMinutesPresets = [5, 10, 15, 20, 30];
}

class AppColors {
  static const Color primary = Color(0xFF3B82F6); // macOS Royal Blue
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color accent = Color(
    0xFF10B981,
  ); // Emerald Green (Focus/Success)
  static const Color accentLight = Color(0xFF34D399);

  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color danger = Color(0xFFEF4444); // Rose/Red

  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0); // Slate 200

  static const Color textPrimaryLight = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryLight = Color(0xFF64748B); // Slate 500
  static const Color textMutedLight = Color(0xFF94A3B8); // Slate 400

  // Focus mode deep dark background
  static const Color focusBackground = Color(0xFF0B0F19);
  static const Color focusSurface = Color(0xFF161F30);
  static const Color focusCard = Color(0xFF1E293B);
}
