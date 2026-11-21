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
    this.occurrenceKey,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
  final String? occurrenceKey;
}

typedef ScheduledOccurrence = ({String key, int milliseconds});

abstract interface class ReminderHistory {
  Future<Map<int, ScheduledOccurrence>> readScheduledOccurrences();
  Future<void> recordScheduledOccurrence(
    int id,
    ScheduledOccurrence? occurrence,
  );
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
    required this.deviceDayAt,
    required this.deviceInstantAt,
    this.now = DateTime.now,
  });

  final ReminderStore store;
  final DateEntries dates;
  final AppTimeZoneStore timeZones;
  final ReminderDelivery delivery;
  final DeviceDayAt deviceDayAt;
  final DeviceInstantAt deviceInstantAt;
  final DateTime Function() now;

  Future<void> _queued = Future.value();

  bool supports(DateEntry entry) => entry.id != null;

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
    final today = zone == AppTimeZone.beijing
        ? beijingDayAt(now()).date
        : (await deviceDayAt(now())).date;
    final byId = {
      for (final entry in await dates.read())
        if (supports(entry)) entry.id!: entry,
    };
    final plans = <ReminderKey, List<PlannedReminder>>{};
    for (final record in records) {
      final entry = byId[record.key.id];
      if (entry == null) continue;
      plans[record.key] = await _plansForDate(
        entry,
        record.options,
        today,
        zone,
      );
    }
    return plans;
  }

  Future<List<PlannedReminder>> _plansForDate(
    DateEntry entry,
    ReminderOptions options,
    DateTime today,
    AppTimeZone zone,
  ) async {
    final repeats = entry.type.repeats;
    // Keep yesterday's nominal occurrence eligible for delayed system delivery.
    final from = today.add(Duration(days: options.leadDays - 1));
    var occurrence = repeats ? entry.occurrenceFor(from) : entry.targetDate;
    final plans = <PlannedReminder>[];
    final count = repeats ? 3 : 1;
    for (var index = 0; index < count; index++) {
      final date = occurrence.subtract(Duration(days: options.leadDays));
      final slot = repeats ? 1 + entry.yearOfOccurrence(occurrence) % 3 : 0;
      plans.add(
        PlannedReminder(
          id: entry.id! * 8 + slot,
          at: zone == AppTimeZone.beijing
              ? beijingInstantAt(date, options.hour, options.minute)
              : await deviceInstantAt(date, options.hour, options.minute),
          title: entry.title,
          body: repeats ? '${entry.type.label}提醒' : '日期提醒',
          occurrenceKey:
              'date:${entry.id}:${occurrence.millisecondsSinceEpoch}',
        ),
      );
      if (index + 1 < count) {
        occurrence = entry.occurrenceFor(
          occurrence.add(const Duration(days: 1)),
        );
      }
    }
    return plans;
  }
}
