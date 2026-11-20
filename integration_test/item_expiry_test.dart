import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/item_expiry.dart';
import 'package:remember/main.dart';
import 'package:remember/remember_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'REMEMBER_EXPIRY_PHASE',
    defaultValue: 'save',
  );
  const requestedRun = String.fromEnvironment('REMEMBER_EXPIRY_RUN');
  final run = requestedRun.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : requestedRun;
  final db = RememberDatabase(databaseName: 'remember-expiry-$run.db');

  testWidgets('直接和推算到期日可保存，时区变化只重算状态', (tester) async {
    final now = phase == 'save'
        ? DateTime.utc(2026, 1, 31)
        : DateTime.utc(2026, 2, 28, 16, 30);
    await tester.pumpWidget(
      MainApp(
        dateEntries: db,
        timeZones: db,
        items: db,
        now: () => now,
        deviceDayAt: (_) async => (
          date: DateTime.utc(2026, 2, 28),
          nextStart: DateTime.utc(2026, 3, 1),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
    await tester.pumpAndSettle();

    if (phase == 'save') {
      await _addItem(tester, '直填物品', calculate: false);
      await _addItem(tester, '一个月的物品', calculate: true);
      expect(find.text('今日到期'), findsOneWidget);
      expect(find.text('还有 28 天到期'), findsOneWidget);
    } else {
      expect(requestedRun, isNotEmpty);
      expect(find.text('已过期 1 天'), findsOneWidget);
      expect(find.text('直填物品'), findsOneWidget);

      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('跟随手机时区'));
      await tester.pumpAndSettle();
      expect(find.text('今日到期'), findsOneWidget);

      await tester.tap(find.text('一个月的物品'));
      await tester.pumpAndSettle();
      expect(find.text('到期日 2026年2月28日星期六'), findsOneWidget);
      expect(find.text('生产日期 2026年1月31日星期六'), findsOneWidget);
      expect(find.text('保质期 1 月'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}

Future<void> _addItem(
  WidgetTester tester,
  String name, {
  required bool calculate,
}) async {
  await tester.tap(find.text('添加物品'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.text('设置到期日'));
  await tester.pumpAndSettle();
  if (calculate) {
    await tester.tap(find.widgetWithText(SwitchListTile, '按生产日期和保质期推算'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<ShelfLifeUnit>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('月').last);
    await tester.pumpAndSettle();
  }

  await tester.tap(find.text('确认到期日'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('保存物品'));
  await tester.tap(find.text('保存物品'));
  await tester.pumpAndSettle();
}
