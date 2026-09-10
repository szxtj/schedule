import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/notification_service.dart';
import 'core/status_bar_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化通知服务
  await NotificationService.instance.init();

  // 初始化 macOS 状态栏
  await StatusBarService.updateStatus(statusText: '空闲', isRunning: false);

  runApp(const ProviderScope(child: ScheduleApp()));
}
