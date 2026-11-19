import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/main.dart';

void main() {
  testWidgets('打开应用直接进入日期页，并可切换三个入口', (tester) async {
    await tester.pumpWidget(MainApp(dateEntries: _MemoryDateEntries()));
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
      MainApp(dateEntries: _MemoryDateEntries(), now: () => now),
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

class _MemoryDateEntries implements DateEntries {
  final _entries = <DateEntry>[];

  @override
  Future<List<DateEntry>> read() async => List.of(_entries.reversed);

  @override
  Future<void> add(DateEntry entry) async => _entries.add(entry);
}
