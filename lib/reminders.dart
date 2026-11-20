import 'package:timezone/data/latest_all.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

import 'app_calendar.dart';
import 'date_entries.dart';

enum ReminderScope { date }

enum ReminderSaveResult { saved, denied, passed }

typedef ReminderKey = ({ReminderScope scope, int id});
typedef ReminderRecord = ({ReminderKey key, ReminderOptions options});

final class ReminderOptions {
  const ReminderOptions({this.leadDays = 0, this.hour = 9, this.minute = 0});

  final int leadDays;
  final int hour;
  final int minute;
}

final class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

abstract interface class ReminderStore {
  Future<List<ReminderRecord>> readReminders();
  Future<void> writeReminder(ReminderKey key, ReminderOptions? options);
}

abstract interface class ReminderDelivery {
  Future<bool> requestPermission();
  Future<void> replacePending(List<PlannedReminder> reminders);
}

class Reminders {
  Reminders({
    required this.store,
    required this.dates,
    required this.timeZones,
    required this.delivery,
    required this.deviceZoneName,
    this.now = DateTime.now,
  }) {
    zones.initializeTimeZones();
  }

  final ReminderStore store;
  final DateEntries dates;
  final AppTimeZoneStore timeZones;
  final ReminderDelivery delivery;
  final Future<String> Function() deviceZoneName;
  final DateTime Function() now;

  Future<void> _queued = Future.value();

  bool supports(DateEntry entry) => entry.id != null && !entry.type.repeats;

  Future<ReminderOptions?> read(ReminderKey key) async {
    final records = await store.readReminders();
    for (final record in records) {
      if (record.key == key) return record.options;
    }
    return null;
  }

  Future<ReminderSaveResult> save(
    ReminderKey key,
    ReminderOptions? options,
  ) async {
    if (options != null && !await delivery.requestPermission()) {
      return ReminderSaveResult.denied;
    }
    return _enqueue(() async {
      final records = [
        for (final record in await store.readReminders())
          if (record.key != key) record,
        if (options != null) (key: key, options: options),
      ];
      final plans = await _plans(records);
      if (options != null &&
          !(plans[key]?.any((plan) => plan.at.isAfter(now())) ?? false)) {
        return ReminderSaveResult.passed;
      }
      await store.writeReminder(key, options);
      await delivery.replacePending(
        plans.values.expand((entries) => entries).toList(),
      );
      return ReminderSaveResult.saved;
    });
  }

  Future<void> synchronize() => _enqueue(() async {
    final plans = await _plans(await store.readReminders());
    await delivery.replacePending(
      plans.values.expand((entries) => entries).toList(),
    );
  });

  Future<T> _enqueue<T>(Future<T> Function() work) {
    final action = _queued.then((_) => work());
    _queued = action.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return action;
  }

  Future<Map<ReminderKey, List<PlannedReminder>>> _plans(
    List<ReminderRecord> records,
  ) async {
    if (records.isEmpty) return {};
    final zone = await timeZones.readTimeZone();
    final location = tz.getLocation(
      zone == AppTimeZone.beijing ? 'Asia/Shanghai' : await deviceZoneName(),
    );
    final byId = {
      for (final entry in await dates.read())
        if (supports(entry)) entry.id!: entry,
    };
    final plans = <ReminderKey, List<PlannedReminder>>{};
    for (final record in records) {
      final entry = byId[record.key.id];
      if (entry == null) continue;
      final options = record.options;
      final date = entry.targetDate.subtract(Duration(days: options.leadDays));
      final at = tz.TZDateTime(
        location,
        date.year,
        date.month,
        date.day,
        options.hour,
        options.minute,
      );
      plans[record.key] = [
        PlannedReminder(
          id: record.key.id * 8,
          at: at,
          title: entry.title,
          body: '日期提醒',
        ),
      ];
    }
    return plans;
  }
}
