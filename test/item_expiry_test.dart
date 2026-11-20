import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remember/item_entries.dart';
import 'package:remember/item_expiry.dart';
import 'package:remember/items_page.dart';

void main() {
  test('保质期跨月、闰年和跨年按自然日推算', () {
    for (final (start, units, unit, expected) in [
      (
        DateTime.utc(2026, 1, 31),
        1,
        ShelfLifeUnit.months,
        DateTime.utc(2026, 2, 28),
      ),
      (
        DateTime.utc(2028, 1, 31),
        1,
        ShelfLifeUnit.months,
        DateTime.utc(2028, 2, 29),
      ),
      (
        DateTime.utc(2024, 2, 29),
        1,
        ShelfLifeUnit.years,
        DateTime.utc(2025, 2, 28),
      ),
      (
        DateTime.utc(2026, 12, 31),
        2,
        ShelfLifeUnit.days,
        DateTime.utc(2027, 1, 2),
      ),
      (
        DateTime.utc(2026, 12, 31),
        2,
        ShelfLifeUnit.months,
        DateTime.utc(2027, 2, 28),
      ),
    ]) {
      final shelfLife = ShelfLife(producedOn: start, amount: units, unit: unit);
      expect(shelfLife.expiryDate, expected);
      expect(shelfLife.producedOn, start);
    }
  });

  test('到期日当天和次日的状态依据应用当前日期', () {
    final expiry = ItemExpiry.direct(DateTime.utc(2026, 2, 28));
    expect(expiry.statusOn(DateTime.utc(2026, 2, 27)), '还有 1 天到期');
    expect(expiry.statusOn(DateTime.utc(2026, 2, 28)), '今日到期');
    expect(expiry.statusOn(DateTime.utc(2026, 3, 1)), '已过期 1 天');
    expect(expiry.date, DateTime.utc(2026, 2, 28));
  });

  testWidgets('物品可在新建时设置到期日', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ItemsPage(
            entries: _EmptyItems(),
            today: DateTime.utc(2026, 1, 31),
            pickPhotos: (_) async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加物品'));
    await tester.pumpAndSettle();
    expect(find.text('设置到期日'), findsOneWidget);
  });
}

class _EmptyItems implements ItemEntries {
  @override
  Future<List<ItemEntry>> readItems() async => [];
  @override
  Future<void> addItem(ItemDraft item) async {}
  @override
  Future<void> updateItemExpiry(int itemId, ItemExpiry? expiry) async {}

  @override
  Future<List<Uint8List>> readItemPhotos(int itemId) async => [];
}
