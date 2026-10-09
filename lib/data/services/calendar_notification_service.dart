import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as timezone;

class CalendarReminderOccurrence {
  const CalendarReminderOccurrence({
    required this.key,
    required this.title,
    required this.body,
    required this.dateTime,
  });

  final String key;
  final String title;
  final String body;
  final DateTime dateTime;

  String get payload => jsonEncode(<String, String>{
    'key': key,
    'dateTime': dateTime.toIso8601String(),
  });
}

class CalendarNotificationService {
  CalendarNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'calendar_reminders';
  static const _channelName = '日历提醒';
  static const _channelDescription = '日历备注和还款节点提醒';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  // macOS 与移动端共用提醒实例和点击载荷，仅由插件适配系统通知。
  bool get _supportsNotifications =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> initialize({
    required ValueChanged<String> onNotificationTap,
  }) async {
    if (!_supportsNotifications) return;

    // 各端都在用户启用提醒时申请权限，启动应用不主动弹出授权框。
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: darwinSettings,
      macOS: darwinSettings,
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onNotificationTap(payload);
      },
    );
    _initialized = true;
  }

  Future<String?> getLaunchPayload() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  Future<bool> requestPermission() async {
    if (!_initialized || !_supportsNotifications) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      return await ios?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final macos = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      return await macos?.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  Future<void> reschedule(List<CalendarReminderOccurrence> reminders) async {
    if (!_initialized) return;
    await _plugin.cancelAllPendingNotifications();
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      presentBadge: false,
    );
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: false,
      ),
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
    for (var index = 0; index < reminders.length; index++) {
      final reminder = reminders[index];
      await _plugin.zonedSchedule(
        id: index + 1,
        title: reminder.title,
        body: reminder.body,
        // Preserve the local DateTime's exact instant without a device timezone plugin.
        scheduledDate: timezone.TZDateTime.from(
          reminder.dateTime,
          timezone.UTC,
        ),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.payload,
      );
    }
  }
}
