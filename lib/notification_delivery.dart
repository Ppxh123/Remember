import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'reminders.dart';

final class NotificationDelivery implements ReminderDelivery {
  NotificationDelivery({String namespace = 'remember-reminder:'})
    : _tag = namespace;

  final _plugin = FlutterLocalNotificationsPlugin();
  late final _ready = _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('reminder_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  final String _tag;

  @override
  Future<bool> requestPermission() async {
    await _ready;
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> replacePending(List<PlannedReminder> reminders) async {
    await _ready;
    final enabled =
        !Platform.isAndroid ||
        (await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.areNotificationsEnabled() ??
            false);
    final expected = {for (final reminder in reminders) reminder.id: reminder};
    if (!enabled) expected.clear();
    final pending = await _plugin.pendingNotificationRequests();
    for (final current in pending) {
      if (!(current.payload?.startsWith(_tag) ?? false)) continue;
      final reminder = expected[current.id];
      if (reminder != null && current.payload == _payload(reminder)) {
        expected.remove(current.id);
      } else {
        await _plugin.cancel(id: current.id);
      }
    }

    for (final reminder in expected.values) {
      if (!reminder.at.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        payload: _payload(reminder),
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'remember_reminders',
            '莫忘提醒',
            channelDescription: '日期和物品提醒',
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  String _payload(PlannedReminder reminder) =>
      _tag +
      jsonEncode([
        reminder.at.millisecondsSinceEpoch,
        reminder.title,
        reminder.body,
      ]);
}
