import 'dart:typed_data';

final class ItemEntry {
  const ItemEntry({required this.id, required this.name, this.purchasedOn});

  final int id;
  final String name;
  final DateTime? purchasedOn;
}

final class ItemDraft {
  const ItemDraft({
    required this.name,
    this.purchasedOn,
    this.photos = const [],
  });

  final String name;
  final DateTime? purchasedOn;
  final List<Uint8List> photos;
}

abstract interface class ItemEntries {
  Future<List<ItemEntry>> readItems();
  Future<void> addItem(ItemDraft item);
  Future<List<Uint8List>> readItemPhotos(int itemId);
}
