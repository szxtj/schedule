import 'package:flutter/services.dart';

class StatusBarService {
  static const MethodChannel _channel = MethodChannel(
    'com.antigravity.schedule/status_bar',
  );

  /// 更新 macOS 状态栏常驻图标文字与模式
  static Future<void> updateStatus({
    required String statusText,
    required bool isRunning,
  }) async {
    try {
      await _channel.invokeMethod('updateStatus', {
        'statusText': statusText,
        'isRunning': isRunning,
      });
    } catch (_) {
      // 非 macOS 平台或通道不可用时静默忽略
    }
  }

  /// 请求主窗口前置显示
  static Future<void> showMainWindow() async {
    try {
      await _channel.invokeMethod('showMainWindow');
    } catch (_) {}
  }
}
