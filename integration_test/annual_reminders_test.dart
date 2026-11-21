import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/app_calendar.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/device_clock.dart';
import 'package:remember/lunar_date.dart';
import 'package:remember/notification_delivery.dart';
import 'package:remember/reminders.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android 排定年度提醒，切换时区和时间后替换计划', (tester) async {
    final store = _Fixture();
    final delivery = NotificationDelivery(namespace: 'remember-annual-test:');
    final plugin = FlutterLocalNotificationsPlugin();
    final manager = Reminders(
      store: store,
      dates: store,
      timeZones: store,
      delivery: delivery,
      deviceDayAt: deviceDayAt,
      deviceInstantAt: deviceInstantAt,
      now: () => DateTime.utc(2042, 3, 29),
    );
    const lunarKey = (scope: ReminderScope.date, id: 500002);
    const solarKey = (scope: ReminderScope.date, id: 500001);

    try {
      expect(
        await manager.save(lunarKey, const ReminderOptions()),
        ReminderSaveResult.saved,
      );
      expect(
        await manager.save(solarKey, const ReminderOptions()),
        ReminderSaveResult.saved,
      );
      expect(
        await _times(plugin, '闰月纪念日'),
        contains(DateTime.utc(2042, 3, 31, 1)),
      );
      expect(
        await _times(plugin, '公历生日'),
        contains(DateTime.utc(2043, 2, 28, 1)),
      );

      await store.writeTimeZone(AppTimeZone.device);
      await manager.synchronize();
      expect(
        await manager.save(
          lunarKey,
          const ReminderOptions(leadDays: 1, hour: 10),
        ),
        ReminderSaveResult.saved,
      );

      final slots = await _times(plugin, '闰月纪念日');
      expect(slots, hasLength(3));
      expect(
        slots,
        contains(await deviceInstantAt(DateTime.utc(2042, 3, 30), 10, 0)),
      );
      expect(slots, isNot(contains(DateTime.utc(2042, 3, 31, 1))));
    } finally {
      await delivery.replacePending([]);
    }
  });
}

Future<List<DateTime>> _times(
  FlutterLocalNotificationsPlugin plugin,
  String title,
) async {
  final notices = await plugin.pendingNotificationRequests();
  const tag = 'remember-annual-test:';
  return [
    for (final note in notices)
      if (note.title == title && (note.payload?.startsWith(tag) ?? false))
        DateTime.fromMillisecondsSinceEpoch(
          (jsonDecode(note.payload!.substring(tag.length)) as List).first
              as int,
          isUtc: true,
        ),
  ];
}

class _Fixture implements DateEntries, ReminderStore, AppTimeZoneStore {
  final _records = <ReminderKey, ReminderOptions>{};
  AppTimeZone _zone = AppTimeZone.beijing;

  @override
  Future<List<DateEntry>> read() async => [
    DateEntry(
      id: 500001,
      title: '公历生日',
      type: DateEntryType.birthday,
      targetDate: DateTime.utc(2024, 2, 29),
    ),
    DateEntry.lunar(
      id: 500002,
      title: '闰月纪念日',
      type: DateEntryType.anniversary,
      originalDate: LunarDate(year: 2023, month: 2, day: 10, isLeapMonth: true),
    ),
  ];

  @override
  Future<void> add(DateEntry entry) async => throw UnimplementedError();

  @override
  Future<AppTimeZone> readTimeZone() async => _zone;

  @override
  Future<void> writeTimeZone(AppTimeZone zone) async {
    _zone = zone;
  }

  @override
  Future<List<ReminderRecord>> readReminders() async => [
    for (final entry in _records.entries)
      (key: entry.key, options: entry.value),
  ];

  @override
  Future<void> writeReminder(ReminderKey key, ReminderOptions? options) async {
    if (options == null) {
      _records.remove(key);
    } else {
      _records[key] = options;
    }
  }
}
