import 'dart:typed_data';
import 'item_expiry.dart';

final class ItemEntry {
  const ItemEntry({
    required this.id,
    required this.name,
    this.purchasedOn,
    this.expiry,
  });

  final int id;
  final String name;
  final DateTime? purchasedOn;
  final ItemExpiry? expiry;
}

final class ItemDraft {
  const ItemDraft({
    required this.name,
    this.purchasedOn,
    this.expiry,
    this.photos = const [],
  });

  final String name;
  final DateTime? purchasedOn;
  final ItemExpiry? expiry;
  final List<Uint8List> photos;
}

abstract interface class ItemEntries {
  Future<List<ItemEntry>> readItems();
  Future<void> addItem(ItemDraft item);
  Future<void> updateItemExpiry(int itemId, ItemExpiry? expiry);
  Future<List<Uint8List>> readItemPhotos(int itemId);
}
