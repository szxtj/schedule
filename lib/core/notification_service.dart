import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  bool _initialized = false;
  final FlutterLocalNotificationsPlugin _androidPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (_initialized) return;
    try {
      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        await localNotifier.setup(appName: 'ScheduleFocus');
      } else if (!kIsWeb && Platform.isAndroid) {
        const androidInit = AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        );
        const initSettings = InitializationSettings(android: androidInit);
        await _androidPlugin.initialize(settings: initSettings);

        // 请求 Android 13+ 通知权限
        await _androidPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// 触发倒计时结束提示（系统提示音 + 通知）
  Future<void> notifyTimerCompleted({
    required String title,
    required String body,
  }) async {
    // 播放系统提示音与震动
    try {
      await SystemSound.play(SystemSoundType.alert);
      if (!kIsWeb && Platform.isAndroid) {
        HapticFeedback.vibrate();
      }
    } catch (e) {
      debugPrint('SystemSound play error: $e');
    }

    // 发送系统横幅通知
    try {
      if (!kIsWeb &&
          (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        final notification = LocalNotification(
          title: title,
          body: body,
          silent: false,
        );
        await notification.show();
      } else if (!kIsWeb && Platform.isAndroid) {
        const androidDetails = AndroidNotificationDetails(
          'schedule_focus_timer_channel',
          '倒计时提醒',
          channelDescription: '任务倒计时结束与延时提醒',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        );
        const details = NotificationDetails(android: androidDetails);
        await _androidPlugin.show(
          id: 1001,
          title: title,
          body: body,
          notificationDetails: details,
        );
      }
    } catch (e) {
      debugPrint('Show notification error: $e');
    }
  }
}
