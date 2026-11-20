import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:remember/item_photo_picker.dart';
import 'package:remember/main.dart';
import 'package:remember/remember_database.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'REMEMBER_ITEM_PHASE',
    defaultValue: 'save',
  );
  const requestedRun = String.fromEnvironment('REMEMBER_ITEM_RUN');
  final runId = requestedRun.isEmpty
      ? DateTime.now().microsecondsSinceEpoch.toString()
      : requestedRun;
  final db = RememberDatabase(databaseName: 'remember-items-$runId.db');
  final red = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEklEQVR4nGP8z4AdMOEQH6QSAM1BAQ/oQeJvAAAAAElFTkSuQmCC',
  );
  final blue = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAFElEQVR4nGNkYPjPgA0wYRUdtBIAy0MBD1YkjLoAAAAASUVORK5CYII=',
  );
  final largePhoto = Uint8List(300 * 1024)..setAll(0, red);

  testWidgets('物品与两条入口的照片内容跨进程保存', (tester) async {
    await tester.pumpWidget(
      MainApp(
        dateEntries: db,
        timeZones: db,
        items: db,
        now: () => DateTime.utc(2026, 6, 1),
        pickPhotos: (source) async => switch (source) {
          ItemPhotoSource.camera => [largePhoto],
          ItemPhotoSource.gallery => [blue],
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(NavigationDestination, '物品'));
    await tester.pumpAndSettle();

    if (phase == 'save') {
      expect(find.text('还没有物品记录'), findsOneWidget);
      await _newItem(tester, '相机');
      await tester.tap(find.text('购入日期'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('从相册选择'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('保存物品'));
      await tester.tap(find.text('保存物品'));
      await tester.pumpAndSettle();
      await _newItem(tester, '无照片物品');
      await tester.tap(find.text('保存物品'));
      await tester.pumpAndSettle();
    } else {
      expect(phase, 'verify');
      expect(requestedRun, isNotEmpty);
    }

    expect(find.text('无照片物品'), findsOneWidget);
    expect(find.text('购入日期 2026年6月1日星期一'), findsOneWidget);
    await tester.tap(find.text('相机'));
    await tester.pumpAndSettle();
    final photos = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(photos, hasLength(2));
    expect((photos[0].image as MemoryImage).bytes, largePhoto);
    expect((photos[1].image as MemoryImage).bytes, blue);
    expect(find.text('照片无法显示'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
  });
}

Future<void> _newItem(WidgetTester tester, String name) async {
  await tester.tap(find.text('添加物品'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), name);
  // Hide the edit keyboard before using controls below it.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}
