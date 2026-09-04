import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class MobileBackgroundHandler {
  static void initForegroundTask() {
    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'zero_trace_p2p_channel',
          channelName: 'Zero-Trace P2P Host Service',
          channelDescription: 'Maintains active ephemeral P2P host session in memory',
          channelImportance: NotificationChannelImportance.HIGH,
          priority: NotificationPriority.HIGH,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: const ForegroundTaskOptions(
          interval: 5000,
          isOnceEvent: false,
          autoRunOnBoot: false,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (_) {}
  }

  static Future<void> startForegroundService({
    required String title,
    required String text,
  }) async {
    try {
      // Request notification permission if required on Android 13+
      final notificationPermission = await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: title,
          notificationText: text,
          callback: startCallback,
        );
      }
    } catch (_) {
      // Silently continue if foreground service is restricted by user/system
    }
  }

  static Future<void> stopForegroundService() async {
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(HostTaskHandler());
}

class HostTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}
