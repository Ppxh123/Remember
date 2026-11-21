import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remember/app_calendar.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/item_entries.dart';
import 'package:remember/item_expiry.dart';
import 'package:remember/main.dart';
import 'package:remember/lunar_date.dart';
import 'package:remember/reminders.dart';

void main() {
  test('清除到期日与已开始的提醒保存串行，清除后没有残留计划', () async {
    final items = _ReminderItems();
    final records = _MemoryReminders();
    final delivery = _TestDelivery()..granted = true;
    final snapshotRead = Completer<void>();
    final continueRead = Completer<void>();
    const key = (scope: ReminderScope.item, id: 1);
    final reminders = Reminders(
      store: records,
      dates: _MemoryDateEntries(),
      readItems: () async {
        final snapshot = await items.readItems();
        if (!snapshotRead.isCompleted) {
          snapshotRead.complete();
          await continueRead.future;
        }
        return snapshot;
      },
      timeZones: _MemoryTimeZones(),
      delivery: delivery,
      deviceDayAt: _dayInFixtureZone,
      deviceInstantAt: _instantInFixtureZone,
      now: () => DateTime.utc(2026, 6, 1),
    );
    final save = reminders.save(key, const ReminderOptions());
    await snapshotRead.future;
    final clear = reminders.synchronize(
      update: () async {
        await items.updateItemExpiry(1, null);
        await records.writeReminder(key, null);
      },
    );
    continueRead.complete();
    expect(await save, ReminderSaveResult.saved);
    await clear;
    expect(records.records, isEmpty);
    expect(delivery.pending, isEmpty);
  });

  testWidgets('有到期日的物品提供提醒入口', (tester) async {
    final items = _ReminderItems();
    final dates = _MemoryDateEntries();
    final timeZones = _MemoryTimeZones();
    final delivery = _TestDelivery();
    final reminders = Reminders(
      store: _MemoryReminders(),
      dates: dates,
      readItems: items.readItems,
      timeZones: timeZones,
      delivery: delivery,
      deviceDayAt: _dayInFixtureZone,
      deviceInstantAt: _instantInFixtureZone,
      now: () => DateTime.utc(2026, 6, 1),
    );
    await tester.pumpWidget(
      MainApp(
        dateEntries: dates,
        items: items,
        timeZones: timeZones,
        reminders: reminders,
        now: () => DateTime.utc(2026, 6, 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提醒用物品'));
    await tester.pumpAndSettle();
    expect(find.text('设置到期提醒'), findsOneWidget);

    await tester.tap(find.text('设置到期提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '启用提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存提醒'));
    await tester.pumpAndSettle();
    expect(find.text('通知权限未开启，提醒未启用'), findsOneWidget);
    expect(find.text('提醒用物品'), findsOneWidget);
    expect(find.text('到期日 2026年6月2日星期二'), findsOneWidget);

    delivery.granted = true;
    const key = (scope: ReminderScope.item, id: 1);
    expect(
      await reminders.save(key, const ReminderOptions()),
      ReminderSaveResult.saved,
    );
    expect(delivery.pending.single.at, DateTime.utc(2026, 6, 2, 1));
    final id = delivery.pending.single.id;

    await items.updateItemExpiry(
      1,
      ItemExpiry.calculated(
        ShelfLife(
          producedOn: DateTime.utc(2026, 6, 1),
          amount: 4,
          unit: ShelfLifeUnit.days,
        ),
      ),
    );
    await reminders.synchronize();
    expect(delivery.pending.single.at, DateTime.utc(2026, 6, 5, 1));
    await reminders.save(key, const ReminderOptions(leadDays: 1, hour: 10));
    expect(delivery.pending.single.at, DateTime.utc(2026, 6, 4, 2));
    await timeZones.writeTimeZone(AppTimeZone.device);
    await reminders.synchronize();
    expect(delivery.pending.single.at, DateTime.utc(2026, 6, 4, 17));
    expect(delivery.pending.single.id, id);
    await reminders.save(key, null);
    expect(delivery.pending, isEmpty);
  });

  test('年度提醒按公历闰日和农历闰月分别预排并滚动', () async {
    final dates = _MemoryDateEntries();
    await dates.add(
      DateEntry(
        id: 11,
        title: '公历生日',
        targetDate: DateTime.utc(2020, 2, 29),
        type: DateEntryType.birthday,
      ),
    );
    await dates.add(
      DateEntry.lunar(
        id: 12,
        title: '闰月纪念日',
        type: DateEntryType.anniversary,
        originalDate: LunarDate(
          year: 2023,
          month: 2,
          day: 10,
          isLeapMonth: true,
        ),
      ),
    );
    await dates.add(
      DateEntry.lunar(
        id: 13,
        title: '普通月纪念日',
        type: DateEntryType.anniversary,
        originalDate: LunarDate(year: 2023, month: 2, day: 10),
      ),
    );
    await dates.add(
      DateEntry.lunar(
        id: 14,
        title: '月底纪念日',
        type: DateEntryType.anniversary,
        originalDate: LunarDate(year: 2023, month: 4, day: 30),
      ),
    );
    final store = _MemoryReminders();
    final timeZones = _MemoryTimeZones();
    final delivery = _TestDelivery()..granted = true;
    var now = DateTime.utc(2024, 2, 28);
    final reminders = Reminders(
      store: store,
      dates: dates,
      readItems: () async => [],
      timeZones: timeZones,
      delivery: delivery,
      deviceDayAt: _dayInFixtureZone,
      deviceInstantAt: _instantInFixtureZone,
      now: () => now,
    );
    const leapMonth = (scope: ReminderScope.date, id: 12);
    for (final id in [11, 12, 13, 14]) {
      expect(
        await reminders.save((
          scope: ReminderScope.date,
          id: id,
        ), const ReminderOptions()),
        ReminderSaveResult.saved,
      );
    }
    List<DateTime> future(String title) => [
      for (final plan in delivery.pending)
        if (plan.title == title && plan.at.isAfter(now)) plan.at.toUtc(),
    ];
    expect(future('公历生日').first, DateTime.utc(2024, 2, 29, 1));
    expect(future('公历生日')[1], DateTime.utc(2025, 2, 28, 1));
    expect(future('闰月纪念日').first, DateTime.utc(2024, 3, 19, 1));
    expect(future('普通月纪念日').first, DateTime.utc(2024, 3, 19, 1));
    expect(future('月底纪念日').first, DateTime.utc(2024, 6, 5, 1));
    now = DateTime.utc(2042, 3, 2);
    await reminders.synchronize();
    expect(future('闰月纪念日').first, DateTime.utc(2042, 3, 31, 1));
    expect(future('普通月纪念日').first.year, 2043);
    expect(
      await reminders.save(
        leapMonth,
        const ReminderOptions(leadDays: 1, hour: 10),
      ),
      ReminderSaveResult.saved,
    );
    expect(future('闰月纪念日').first, DateTime.utc(2042, 3, 30, 2));
    await timeZones.writeTimeZone(AppTimeZone.device);
    await reminders.synchronize();
    expect(future('闰月纪念日').first, DateTime.utc(2042, 3, 30, 17));
    expect(
      delivery.pending.map((plan) => plan.id).toSet(),
      hasLength(delivery.pending.length),
    );
  });

  testWidgets('一次性日期有可编辑的提醒入口', (tester) async {
    final entries = _MemoryDateEntries();
    await entries.add(
      DateEntry(id: 1, title: '取件', targetDate: DateTime.utc(2030, 7, 1)),
    );
    final storage = _MemoryReminders();
    final delivery = _TestDelivery();
    final timeZones = _MemoryTimeZones();
    var now = DateTime.utc(2030, 6, 1);
    final reminders = Reminders(
      store: storage,
      dates: entries,
      readItems: () async => [],
      timeZones: timeZones,
      delivery: delivery,
      now: () => now,
      deviceDayAt: _dayInFixtureZone,
      deviceInstantAt: _instantInFixtureZone,
    );

    await tester.pumpWidget(
      MainApp(
        dateEntries: entries,
        items: const _EmptyItems(),
        timeZones: timeZones,
        reminders: reminders,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('设置提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, '启用提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存提醒'));
    await tester.pumpAndSettle();
    expect(find.text('通知权限未开启，提醒未启用'), findsOneWidget);
    expect(storage.records, isEmpty);
    expect(find.text('取件'), findsOneWidget);

    delivery.granted = true;
    final key = (scope: ReminderScope.date, id: 1);
    expect(
      await reminders.save(key, const ReminderOptions()),
      ReminderSaveResult.saved,
    );
    expect(delivery.pending.single.at.toUtc(), DateTime.utc(2030, 7, 1, 1));

    await reminders.save(
      key,
      const ReminderOptions(leadDays: 1, hour: 10, minute: 30),
    );
    expect(
      delivery.pending.single.at.toUtc(),
      DateTime.utc(2030, 6, 30, 2, 30),
    );

    await timeZones.writeTimeZone(AppTimeZone.device);
    await reminders.synchronize();
    expect(
      delivery.pending.single.at.toUtc(),
      DateTime.utc(2030, 6, 30, 17, 30),
    );
    now = DateTime.utc(2030, 6, 30, 18);
    expect(
      await reminders.save(key, const ReminderOptions(leadDays: 2)),
      ReminderSaveResult.passed,
    );
    expect(storage.records[key]?.leadDays, 1);
    expect(
      delivery.pending.single.at.toUtc(),
      DateTime.utc(2030, 6, 30, 17, 30),
    );
    await reminders.save(key, null);
    expect(delivery.pending, isEmpty);
  });

  testWidgets('农历生日保存闰月，并显示换算后的公历日期', (tester) async {
    await tester.pumpWidget(
      MainApp(
        dateEntries: _MemoryDateEntries(),
        items: const _EmptyItems(),
        timeZones: _MemoryTimeZones(),
        now: () => DateTime.utc(2023, 3, 31),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('添加日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DateEntryType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生日').last);
    await tester.pumpAndSettle();

    expect(find.text('历法'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<DateEntryCalendar>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('农历').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '闰月生日');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('生日 · 农历'), findsOneWidget);
    expect(find.text('原始日期 2023年闰二月初十'), findsOneWidget);
    expect(find.text('2023年3月31日星期五'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });

  testWidgets('超出农历录入范围时要求重新选择日期', (tester) async {
    await tester.pumpWidget(
      MainApp(
        dateEntries: _MemoryDateEntries(),
        items: const _EmptyItems(),
        timeZones: _MemoryTimeZones(),
        now: () => DateTime.utc(1899, 6, 1),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加日期'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DateEntryType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('生日').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DateEntryCalendar>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('农历').last);
    await tester.pumpAndSettle();

    expect(find.text('请选择 1901–2100 年的农历日期'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '保存'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('新建公历生日和纪念日，目标当天显示今天', (tester) async {
    await tester.pumpWidget(
      MainApp(
        dateEntries: _MemoryDateEntries(),
        items: const _EmptyItems(),
        timeZones: _MemoryTimeZones(),
        now: () => DateTime.utc(2026, 2, 28),
      ),
    );
    await tester.pumpAndSettle();

    for (final (type, title) in [('生日', '妈妈生日'), ('纪念日', '结婚纪念日')]) {
      await tester.tap(find.text('添加日期'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<DateEntryType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(type).last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), title);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('$type · 公历'), findsOneWidget);
    }

    expect(find.text('今天'), findsNWidgets(2));
  });

  testWidgets('公历二月二十九日平年取月末并在闰年还原', (tester) async {
    final entries = _MemoryDateEntries();
    await entries.add(
      DateEntry(
        title: '闰年生日',
        targetDate: DateTime.utc(2024, 2, 29),
        type: DateEntryType.birthday,
      ),
    );

    for (final (today, expectedDate, countdown) in [
      (DateTime.utc(2026, 2, 28), '2026年2月28日星期六', '今天'),
      (DateTime.utc(2026, 3, 1), '2027年2月28日星期日', '还有 364 天'),
      (DateTime.utc(2028, 2, 28), '2028年2月29日星期二', '还有 1 天'),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MainApp(
          dateEntries: entries,
          items: const _EmptyItems(),
          timeZones: _MemoryTimeZones(),
          now: () => today,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('原始日期 2024年2月29日星期四'), findsOneWidget);
      expect(find.text(expectedDate), findsOneWidget);
      expect(find.text(countdown), findsOneWidget);
    }
  });

  testWidgets('在全局设置中选择应用时区', (tester) async {
    await tester.pumpWidget(
      MainApp(
        dateEntries: _MemoryDateEntries(),
        items: const _EmptyItems(),
        timeZones: _MemoryTimeZones(),
      ),
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
        items: const _EmptyItems(),
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
      MainApp(
        dateEntries: _MemoryDateEntries(),
        items: const _EmptyItems(),
        timeZones: _MemoryTimeZones(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('莫忘'), findsOneWidget);
    expect(find.text('还没有日期条目'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
    await tester.pumpAndSettle();
    expect(find.text('还没有物品记录'), findsOneWidget);

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
        items: const _EmptyItems(),
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

class _EmptyItems implements ItemEntries {
  const _EmptyItems();

  @override
  Future<List<ItemEntry>> readItems() async => [];

  @override
  Future<void> addItem(ItemDraft item) async => throw UnimplementedError();

  @override
  Future<void> updateItemExpiry(int itemId, ItemExpiry? expiry) async {}

  @override
  Future<List<Uint8List>> readItemPhotos(int itemId) async => [];
}

class _MemoryReminders implements ReminderStore {
  final records = <ReminderKey, ReminderOptions>{};

  @override
  Future<List<ReminderRecord>> readReminders() async => [
    for (final entry in records.entries) (key: entry.key, options: entry.value),
  ];

  @override
  Future<void> writeReminder(ReminderKey key, ReminderOptions? options) async {
    if (options == null) {
      records.remove(key);
    } else {
      records[key] = options;
    }
  }
}

class _TestDelivery implements ReminderDelivery {
  bool granted = false;
  List<PlannedReminder> pending = [];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> replacePending(List<PlannedReminder> reminders) async {
    pending = reminders;
  }
}

Future<CalendarDay> _dayInFixtureZone(DateTime instant) async {
  final wallTime = instant.toUtc().subtract(const Duration(hours: 7));
  return (
    date: DateTime.utc(wallTime.year, wallTime.month, wallTime.day),
    nextStart: DateTime.utc(wallTime.year, wallTime.month, wallTime.day + 1, 7),
  );
}

Future<DateTime> _instantInFixtureZone(
  DateTime date,
  int hour,
  int minute,
) async => DateTime.utc(date.year, date.month, date.day, hour + 7, minute);

class _ReminderItems implements ItemEntries {
  ItemExpiry? expiry = ItemExpiry.direct(DateTime.utc(2026, 6, 2));
  @override
  Future<List<ItemEntry>> readItems() async => [
    ItemEntry(id: 1, name: '提醒用物品', expiry: expiry),
  ];
  @override
  Future<void> addItem(ItemDraft item) async => throw UnimplementedError();
  @override
  Future<void> updateItemExpiry(int itemId, ItemExpiry? expiry) async {
    this.expiry = expiry;
  }

  @override
  Future<List<Uint8List>> readItemPhotos(int itemId) async => [];
}
