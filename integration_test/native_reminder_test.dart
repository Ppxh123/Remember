import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/notification_delivery.dart';
import 'package:remember/remember_database.dart';
import 'package:remember/reminders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 系统接收、替换和显示本地提醒', (tester) async {
    final history = RememberDatabase(
      databaseName:
          'notification-history-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final delivery = NotificationDelivery(
      namespace: 'remember-reminder-test:',
      history: history,
    );
    final notifications = FlutterLocalNotificationsPlugin();
    const background = bool.fromEnvironment('REMEMBER_VERIFY_BACKGROUND');
    const id = 2147483200;
    final now = DateTime.now();
    final first = PlannedReminder(
      id: id,
      title: '待替换提醒',
      occurrenceKey: 'test:2042-03-31',
      body: '日期提醒',
      at: now.add(const Duration(minutes: 2)),
    );
    final replacement = PlannedReminder(
      id: id,
      title: 'Android 验收提醒',
      occurrenceKey: 'test:2042-03-31',
      body: '日期提醒',
      at: now.add(Duration(seconds: background ? 25 : 6)),
    );

    try {
      expect(await delivery.requestPermission(), isTrue);
      await delivery.replacePending([first]);
      expect(
        (await notifications.pendingNotificationRequests())
            .singleWhere((notice) => notice.id == id)
            .title,
        '待替换提醒',
      );

      await delivery.replacePending([replacement]);
      final pending = (await notifications.pendingNotificationRequests()).where(
        (notice) => notice.id == id,
      );
      expect(pending.single.title, 'Android 验收提醒');
      if (background) debugPrint('REMEMBER_TEST_BACKGROUND_READY');

      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (true) {
        final active = await notifications.getActiveNotifications();
        if (active.any(
          (notice) => notice.id == id && notice.title == 'Android 验收提醒',
        )) {
          break;
        }
        if (DateTime.now().isAfter(deadline)) {
          fail(
            'The Android system did not deliver the alarm in the test window.',
          );
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      await notifications.cancel(id: id);
      await delivery.replacePending([first]);
      expect(
        (await notifications.pendingNotificationRequests()).where(
          (notice) => notice.id == id,
        ),
        isEmpty,
      );
    } finally {
      await delivery.replacePending([]);
      await notifications.cancel(id: id);
      await history.close();
    }
  });
}
