import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/device_clock.dart';
import 'package:remember/item_entries.dart';
import 'package:remember/item_expiry.dart';
import 'package:remember/main.dart';
import 'package:remember/notification_delivery.dart';
import 'package:remember/remember_database.dart';
import 'package:remember/reminders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 的直填与推算到期提醒可改期、切时区并关闭', (tester) async {
    final db = RememberDatabase(
      databaseName:
          'item-notifications-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    const tag = 'remember-item-test:';
    final delivery = NotificationDelivery(namespace: tag, history: db);
    final plugin = FlutterLocalNotificationsPlugin();
    final now = DateTime.utc(2030, 2, 1);
    final reminders = Reminders(
      store: db,
      dates: db,
      readItems: db.readItems,
      timeZones: db,
      delivery: delivery,
      deviceDayAt: deviceDayAt,
      deviceInstantAt: deviceInstantAt,
      now: () => now,
    );
    await db.addItem(
      ItemDraft(
        name: '直填到期物品',
        expiry: ItemExpiry.direct(DateTime.utc(2030, 2, 28)),
      ),
    );
    await db.addItem(
      ItemDraft(
        name: '推算到期物品',
        expiry: ItemExpiry.calculated(
          ShelfLife(
            producedOn: DateTime.utc(2030, 1, 31),
            amount: 1,
            unit: ShelfLifeUnit.months,
          ),
        ),
      ),
    );
    final items = await db.readItems();
    final ids = items.map((item) => item.id * 8 + 4).toSet();
    final existing = await plugin.pendingNotificationRequests();
    expect(
      existing.where((note) => ids.contains(note.id)),
      isEmpty,
      reason: 'Use an isolated Android test device',
    );
    final calculated = items.singleWhere((item) => item.name == '推算到期物品');
    final direct = items.singleWhere((item) => item.name == '直填到期物品');

    try {
      await tester.pumpWidget(
        MainApp(
          dateEntries: db,
          items: db,
          timeZones: db,
          reminders: reminders,
          now: () => now,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
      await tester.pumpAndSettle();

      for (final item in items) {
        await _open(tester, item.name);
        await _toggle(tester);
        await _leaveDetails(tester);
      }
      const directTitle = '直填到期物品';
      const calculatedTitle = '推算到期物品';
      expect(
        await _scheduled(plugin, tag, directTitle),
        DateTime.utc(2030, 2, 28, 1),
      );
      expect(
        await _scheduled(plugin, tag, calculatedTitle),
        DateTime.utc(2030, 2, 28, 1),
      );
      final directKey = (scope: ReminderScope.item, id: direct.id);
      expect(
        await reminders.save(
          directKey,
          const ReminderOptions(leadDays: 2, hour: 10, minute: 15),
        ),
        ReminderSaveResult.saved,
      );
      expect(
        await _scheduled(plugin, tag, directTitle),
        DateTime.utc(2030, 2, 26, 2, 15),
      );
      await reminders.save(directKey, const ReminderOptions());
      await reminders.save((
        scope: ReminderScope.item,
        id: calculated.id,
      ), const ReminderOptions(leadDays: 1, hour: 11));
      expect(
        await _scheduled(plugin, tag, calculatedTitle),
        DateTime.utc(2030, 2, 27, 3),
      );

      await _open(tester, directTitle);
      await tester.tap(find.text('设置到期日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('到期日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('27'));
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认到期日'));
      await tester.pumpAndSettle();
      expect(
        await _scheduled(plugin, tag, directTitle),
        DateTime.utc(2030, 2, 27, 1),
      );
      await _leaveDetails(tester);

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跟随手机时区'));
      await tester.pumpAndSettle();
      await reminders.synchronize();
      expect(
        await _scheduled(plugin, tag, directTitle),
        await deviceInstantAt(DateTime.utc(2030, 2, 27), 9, 0),
      );
      expect(
        await _scheduled(plugin, tag, calculatedTitle),
        await deviceInstantAt(DateTime.utc(2030, 2, 27), 11, 0),
      );

      await _open(tester, directTitle);
      await _toggle(tester);
      expect(await _scheduled(plugin, tag, directTitle), isNull);
      expect(find.text('到期日 2030年2月27日星期三'), findsOneWidget);
      await _leaveDetails(tester);

      await _open(tester, calculatedTitle);
      await tester.tap(find.text('设置到期日'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除到期日'));
      await tester.pumpAndSettle();
      expect(await _scheduled(plugin, tag, calculatedTitle), isNull);
      expect(await db.readReminders(), isEmpty);
      expect(find.text('设置到期提醒'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await reminders.synchronize();
      await delivery.replacePending([]);
      await db.close();
    }
  });
}

Future<void> _open(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _leaveDetails(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(find.text('物品记录'), findsOneWidget);
}

Future<void> _toggle(WidgetTester tester) async {
  await tester.tap(find.text('设置到期提醒'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SwitchListTile, '启用提醒'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('保存提醒'));
  await tester.pumpAndSettle();
}

Future<DateTime?> _scheduled(
  FlutterLocalNotificationsPlugin plugin,
  String tag,
  String title,
) async {
  final pending = (await plugin.pendingNotificationRequests()).where(
    (note) => note.title == title && (note.payload?.startsWith(tag) ?? false),
  );
  if (pending.isEmpty) return null;
  final data =
      jsonDecode(pending.single.payload!.substring(tag.length)) as List;
  return DateTime.fromMillisecondsSinceEpoch(data.first as int, isUtc: true);
}
