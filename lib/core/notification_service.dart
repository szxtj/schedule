import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        await localNotifier.setup(
          appName: 'ScheduleFocus',
        );
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// 触发倒计时结束提示（系统提示音 + 桌面通知）
  Future<void> notifyTimerCompleted({
    required String title,
    required String body,
  }) async {
    // 播放系统提示音
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (e) {
      debugPrint('SystemSound play error: $e');
    }

    // 发送系统桌面横幅通知
    try {
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        final notification = LocalNotification(
          title: title,
          body: body,
          silent: false,
        );
        await notification.show();
      }
    } catch (e) {
      debugPrint('Show desktop notification error: $e');
    }
  }
}
