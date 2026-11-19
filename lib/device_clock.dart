import 'package:flutter/services.dart';

import 'app_calendar.dart';

const _calendar = MethodChannel('io.github.ppxh123.remember/device_calendar');
const _clockEvents = EventChannel('io.github.ppxh123.remember/clock_changes');

final deviceTimeChanges = _clockEvents.receiveBroadcastStream().map<void>(
  (_) {},
);

Future<CalendarDay> deviceDayAt(DateTime instant) async {
  // Native order: Gregorian year, month, day, then next day start in epoch milliseconds.
  final parts = await _calendar.invokeListMethod<int>(
    'dayAt',
    instant.millisecondsSinceEpoch,
  );
  if (parts == null || parts.length != 4) {
    throw StateError('Device calendar unavailable');
  }
  return (
    date: DateTime.utc(parts[0], parts[1], parts[2]),
    nextStart: DateTime.fromMillisecondsSinceEpoch(parts[3], isUtc: true),
  );
}
