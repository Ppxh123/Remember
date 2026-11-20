import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/device_clock.dart';
import 'package:remember/main.dart';
import 'package:remember/remember_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('REMEMBER_RESTART_PHASE');

  testWidgets('保存一次性日期后重新打开应用，记录仍可查看', (tester) async {
    final entries = phase.isEmpty
        ? RememberDatabase(
            databaseName:
                'remember-integration-${DateTime.now().microsecondsSinceEpoch}.db',
          )
        : const RememberDatabase();

    if (phase == 'verify') {
      await _verifyAfterRestart(tester, entries);
      return;
    }

    await tester.pumpWidget(
      MainApp(
        dateEntries: entries,
        items: entries,
        timeZones: entries,
        deviceTimeChanges: deviceTimeChanges,
        now: () => DateTime.utc(2026, 11, 19),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有日期条目'), findsOneWidget);
    expect(find.text('北京时间'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随手机时区'));
    await tester.pumpAndSettle();
    expect(find.text('跟随手机时区'), findsOneWidget);

    await tester.tap(find.text('添加日期'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '搬家');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('搬家'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await entries.close();

    if (phase.isEmpty) {
      await _verifyAfterRestart(
        tester,
        RememberDatabase(databaseName: entries.databaseName),
      );
    }
  });
}

Future<void> _verifyAfterRestart(
  WidgetTester tester,
  RememberDatabase entries,
) async {
  await tester.pumpWidget(
    MainApp(
      dateEntries: entries,
      items: entries,
      timeZones: entries,
      deviceTimeChanges: deviceTimeChanges,
      now: () => DateTime.utc(2026, 11, 20),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('搬家'), findsOneWidget);
  expect(find.text('已过 1 天'), findsOneWidget);
  expect(find.text('跟随手机时区'), findsOneWidget);

  await tester.pumpWidget(const SizedBox.shrink());
  await entries.close();
}
