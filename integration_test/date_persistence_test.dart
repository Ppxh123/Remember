import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/main.dart';
import 'package:remember/sqlite_date_entries.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('REMEMBER_RESTART_PHASE');

  testWidgets('保存一次性日期后重新打开应用，记录仍可查看', (tester) async {
    final entries = phase.isEmpty
        ? SqliteDateEntries(
            databaseName:
                'remember-integration-${DateTime.now().microsecondsSinceEpoch}.db',
          )
        : const SqliteDateEntries();

    if (phase == 'verify') {
      await _verifyAfterRestart(tester, entries);
      return;
    }

    await tester.pumpWidget(
      MainApp(dateEntries: entries, now: () => DateTime.utc(2026, 11, 19)),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有日期条目'), findsOneWidget);

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
        SqliteDateEntries(databaseName: entries.databaseName),
      );
    }
  });
}

Future<void> _verifyAfterRestart(
  WidgetTester tester,
  SqliteDateEntries entries,
) async {
  await tester.pumpWidget(
    MainApp(dateEntries: entries, now: () => DateTime.utc(2026, 11, 20)),
  );
  await tester.pumpAndSettle();

  expect(find.text('搬家'), findsOneWidget);
  expect(find.text('已过 1 天'), findsOneWidget);

  await tester.pumpWidget(const SizedBox.shrink());
  await entries.close();
}
