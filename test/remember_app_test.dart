import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remember/app_calendar.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/main.dart';

void main() {
  testWidgets('在全局设置中选择应用时区', (tester) async {
    await tester.pumpWidget(
      MainApp(dateEntries: _MemoryDateEntries(), timeZones: _MemoryTimeZones()),
    );
    await tester.pumpAndSettle();
    expect(find.text('北京时间'), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('应用时区'), findsOneWidget);
    expect(find.text('跟随手机时区'), findsOneWidget);
  });

  testWidgets('切换应用时区和接收手机时区变化都会重算同一条目', (tester) async {
    final entries = _MemoryDateEntries();
    await entries.add(
      DateEntry(title: '约会', targetDate: DateTime.utc(2026, 11, 20)),
    );
    final timeZones = _MemoryTimeZones();
    final changes = StreamController<void>();
    addTearDown(changes.close);
    var deviceOffset = Duration.zero;

    await tester.pumpWidget(
      MainApp(
        dateEntries: entries,
        timeZones: timeZones,
        now: () => DateTime.utc(2026, 11, 19, 16, 30),
        deviceTimeChanges: changes.stream,
        deviceDayAt: (instant) async {
          final wallTime = instant.add(deviceOffset);
          final today = DateTime.utc(
            wallTime.year,
            wallTime.month,
            wallTime.day,
          );
          return (
            date: today,
            nextStart: today
                .add(const Duration(days: 1))
                .subtract(deviceOffset),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final originalDate = find.text('2026年11月20日星期五');
    expect(originalDate, findsOneWidget);
    expect(find.text('今天'), findsOneWidget);

    await _chooseTimeZone(tester, '跟随手机时区');
    expect(find.text('还有 1 天'), findsOneWidget);
    expect(originalDate, findsOneWidget);

    deviceOffset = const Duration(hours: 9);
    changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);

    deviceOffset = Duration.zero;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('还有 1 天'), findsOneWidget);

    await _chooseTimeZone(tester, '北京时间');
    expect(find.text('今天'), findsOneWidget);
    expect(originalDate, findsOneWidget);

    changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('打开应用直接进入日期页，并可切换三个入口', (tester) async {
    await tester.pumpWidget(
      MainApp(dateEntries: _MemoryDateEntries(), timeZones: _MemoryTimeZones()),
    );
    await tester.pumpAndSettle();

    expect(find.text('莫忘'), findsOneWidget);
    expect(find.text('还没有日期条目'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
    await tester.pumpAndSettle();
    expect(find.text('物品记录将在后续版本开放'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '凭据保险箱'));
    await tester.pumpAndSettle();
    expect(find.text('凭据保险箱将在后续版本开放'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '日期'));
    await tester.pumpAndSettle();
    expect(find.text('还没有日期条目'), findsOneWidget);
  });

  testWidgets('保存一次性日期，按北京时间跨日更新且保留条目', (tester) async {
    var now = DateTime.utc(2026, 11, 19, 15, 55);
    await tester.pumpWidget(
      MainApp(
        dateEntries: _MemoryDateEntries(),
        timeZones: _MemoryTimeZones(),
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加日期'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '搬家');
    await tester.tap(find.text('目标日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('搬家'), findsOneWidget);
    expect(find.text('还有 1 天'), findsOneWidget);

    now = DateTime.utc(2026, 11, 19, 16);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('今天'), findsOneWidget);

    now = DateTime.utc(2026, 11, 20, 16);
    await tester.pump(const Duration(days: 1));
    expect(find.text('已过 1 天'), findsOneWidget);
    expect(find.text('搬家'), findsOneWidget);
  });
}

Future<void> _chooseTimeZone(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip('设置'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: find.byType(SimpleDialog), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

class _MemoryDateEntries implements DateEntries {
  final _entries = <DateEntry>[];

  @override
  Future<List<DateEntry>> read() async => List.of(_entries.reversed);

  @override
  Future<void> add(DateEntry entry) async => _entries.add(entry);
}

class _MemoryTimeZones implements AppTimeZoneStore {
  AppTimeZone _selected = AppTimeZone.beijing;

  @override
  Future<AppTimeZone> readTimeZone() async => _selected;

  @override
  Future<void> writeTimeZone(AppTimeZone timeZone) async {
    _selected = timeZone;
  }
}
