import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/date_entries.dart';
import 'package:remember/main.dart';
import 'package:remember/remember_database.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'REMEMBER_ANNUAL_PHASE',
    defaultValue: 'save',
  );
  const requestedRun = String.fromEnvironment('REMEMBER_ANNUAL_RUN');
  final runId = requestedRun.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : requestedRun;
  final store = RememberDatabase(databaseName: 'remember-annual-$runId.db');

  testWidgets('公历生日和纪念日跨进程保留类别、原始日期和倒计时', (tester) async {
    if (phase == 'save') {
      if (Platform.isAndroid) await _createOldDatabase(store.databaseName);
      await _openApp(tester, store, DateTime.utc(2026, 2, 28));
      await _addEntry(tester, type: '生日', title: '母亲生日');
      await _addEntry(tester, type: '纪念日', title: '相识纪念日');
      expect(find.text('生日 · 公历'), findsOneWidget);
      expect(find.text('纪念日 · 公历'), findsOneWidget);
      expect(find.text('今天'), findsNWidgets(2));
    } else {
      expect(phase, 'verify');
      expect(
        requestedRun,
        isNotEmpty,
        reason: 'Use the run ID from the save phase',
      );
      await _openApp(tester, store, DateTime.utc(2026, 3, 1));
      expect(find.text('母亲生日'), findsOneWidget);
      expect(find.text('相识纪念日'), findsOneWidget);
      expect(find.text('生日 · 公历'), findsOneWidget);
      expect(find.text('纪念日 · 公历'), findsOneWidget);
      expect(find.text('原始日期 2026年2月28日星期六'), findsNWidgets(2));
      expect(find.text('2027年2月28日星期日'), findsNWidgets(2));
      expect(find.text('还有 364 天'), findsNWidgets(2));
    }
    if (Platform.isAndroid) {
      expect(find.text('升级前的一次性日期'), findsOneWidget);
      expect(find.text('2026年2月27日星期五'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await store.close();
  });
}

Future<void> _openApp(
  WidgetTester tester,
  RememberDatabase store,
  DateTime now,
) async {
  await tester.pumpWidget(
    MainApp(dateEntries: store, timeZones: store, now: () => now),
  );
  await tester.pumpAndSettle();
}

Future<void> _addEntry(
  WidgetTester tester, {
  required String type,
  required String title,
}) async {
  await tester.tap(find.text('添加日期'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<DateEntryType>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(type).last);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), title);
  await tester.tap(find.text('保存'));
  await tester.pumpAndSettle();
}

Future<void> _createOldDatabase(String name) async {
  final db = await openDatabase(
    name,
    version: 2,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE date_entries (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          target_date INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
      ''');
      await db.insert('date_entries', {
        'title': '升级前的一次性日期',
        'target_date': DateTime.utc(2026, 2, 27).millisecondsSinceEpoch,
      });
    },
  );
  await db.close();
}
