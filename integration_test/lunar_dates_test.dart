import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/main.dart';
import 'package:remember/remember_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'REMEMBER_LUNAR_PHASE',
    defaultValue: 'save',
  );
  const requestedRun = String.fromEnvironment('REMEMBER_LUNAR_RUN');
  final runId = requestedRun.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : requestedRun;
  final db = RememberDatabase(databaseName: 'remember-lunar-$runId.db');

  testWidgets('农历生日和纪念日跨进程保留原日期并按年换算', (tester) async {
    final today = switch (phase) {
      'save' => DateTime.utc(2023, 3, 31),
      'verify' => DateTime.utc(2024, 3, 19),
      _ => throw ArgumentError.value(phase),
    };

    await tester.pumpWidget(
      MainApp(dateEntries: db, items: db, timeZones: db, now: () => today),
    );
    await tester.pumpAndSettle();

    if (phase == 'save') {
      await _beginEntry(tester, '生日');
      await tester.enterText(find.byType(TextFormField), '闰月生日');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      await _beginEntry(tester, '纪念日');
      await tester.tap(find.text('农历日期'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final fields = find.descendant(
        of: dialog,
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(1), '4');
      await tester.enterText(fields.at(2), '30');
      final leapToggle = find.widgetWithText(SwitchListTile, '闰月');
      await tester.ensureVisible(leapToggle);
      await tester.tap(leapToggle);
      await tester.tap(find.descendant(of: dialog, matching: find.text('确定')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '农历纪念日');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('2023年3月31日星期五'), findsOneWidget);
      expect(find.text('2023年6月17日星期六'), findsOneWidget);
    } else {
      expect(
        requestedRun,
        isNotEmpty,
        reason: 'Use the run ID from the save phase',
      );
      expect(find.text('2024年3月19日星期二'), findsOneWidget);
      expect(find.text('2024年6月5日星期三'), findsOneWidget);
    }

    expect(find.text('闰月生日'), findsOneWidget);
    expect(find.text('生日 · 农历'), findsOneWidget);
    expect(find.text('原始日期 2023年闰二月初十'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('农历纪念日'), findsOneWidget);
    expect(find.text('纪念日 · 农历'), findsOneWidget);
    expect(find.text('原始日期 2023年四月三十'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}

Future<void> _beginEntry(WidgetTester tester, String type) async {
  await tester.tap(find.text('添加日期'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<DateEntryType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type).last);
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<DateEntryCalendar>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('农历').last);
  await tester.pumpAndSettle();
}
