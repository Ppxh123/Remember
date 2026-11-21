import 'dart:async';

import 'package:flutter/foundation.dart';

enum AppTimeZone {
  beijing('北京时间'),
  device('跟随手机时区');

  const AppTimeZone(this.label);

  final String label;
}

abstract interface class AppTimeZoneStore {
  Future<AppTimeZone> readTimeZone();
  Future<void> writeTimeZone(AppTimeZone timeZone);
}

typedef CalendarDay = ({DateTime date, DateTime nextStart});
typedef DeviceDayAt = Future<CalendarDay> Function(DateTime instant);
typedef DeviceInstantAt =
    Future<DateTime> Function(DateTime date, int hour, int minute);

const _beijingOffset = Duration(hours: 8);

DateTime beijingInstantAt(DateTime date, int hour, int minute) => DateTime.utc(
  date.year,
  date.month,
  date.day,
  hour,
  minute,
).subtract(_beijingOffset);

CalendarDay beijingDayAt(DateTime instant) {
  final local = instant.toUtc().add(_beijingOffset);
  final date = DateTime.utc(local.year, local.month, local.day);
  return (
    date: date,
    nextStart: date.add(const Duration(days: 1)).subtract(_beijingOffset),
  );
}

class AppCalendar extends ChangeNotifier {
  AppCalendar({
    required this.store,
    required this.now,
    required this.deviceDayAt,
  });

  final AppTimeZoneStore store;
  final DateTime Function() now;
  final DeviceDayAt deviceDayAt;

  AppTimeZone? _timeZone;
  ({AppTimeZone timeZone, DateTime today})? _current;
  bool _failed = false;
  bool _disposed = false;
  Timer? _midnight;
  int _refreshId = 0;

  AppTimeZone? get timeZone => _timeZone;
  ({AppTimeZone timeZone, DateTime today})? get current => _current;
  bool get failed => _failed;

  Future<void> load() async {
    try {
      final saved = await store.readTimeZone();
      if (_disposed) return;
      _timeZone = saved;
      await refresh();
    } catch (_) {
      if (_disposed) return;
      _failed = true;
      notifyListeners();
    }
  }

  Future<void> choose(AppTimeZone timeZone) async {
    await store.writeTimeZone(timeZone);
    if (_disposed) return;
    _timeZone = timeZone;
    await refresh();
  }

  Future<void> refresh() async {
    final timeZone = _timeZone;
    if (timeZone == null || _disposed) return;
    final refreshId = ++_refreshId;
    _midnight?.cancel();

    try {
      final instant = now().toUtc();
      final day = timeZone == AppTimeZone.beijing
          ? beijingDayAt(instant)
          : await deviceDayAt(instant);
      if (_disposed || refreshId != _refreshId) return;

      _current = (timeZone: timeZone, today: day.date);
      _failed = false;
      _midnight = Timer(day.nextStart.difference(now()), refresh);
    } catch (_) {
      if (_disposed || refreshId != _refreshId) return;
      _current = null;
      _failed = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    super.dispose();
  }
}
