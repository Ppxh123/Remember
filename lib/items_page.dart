import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'item_entries.dart';
import 'item_form.dart';
import 'item_photo_picker.dart';

class ItemsPage extends StatefulWidget {
  const ItemsPage({
    required this.entries,
    required this.today,
    required this.pickPhotos,
    super.key,
  });

  final ItemEntries entries;
  final DateTime today;
  final PickItemPhotos pickPhotos;

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  late Future<List<ItemEntry>> _entries = widget.entries.readItems();

  void _reload() {
    final entries = widget.entries.readItems();
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ItemForm(
          today: widget.today,
          entries: widget.entries,
          pickPhotos: widget.pickPhotos,
        ),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  void _open(ItemEntry item) {
    final photos = widget.entries.readItemPhotos(item.id);
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ItemDetails(item: item, photos: photos),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('物品记录', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder(
                  future: _entries,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: _reload,
                          child: const Text('读取失败，重试'),
                        ),
                      );
                    }
                    final entries = snapshot.data;
                    if (entries == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (entries.isEmpty) {
                      return const Center(child: Text('还没有物品记录'));
                    }
                    return ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = entries[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(item.name),
                            subtitle: item.purchasedOn == null
                                ? null
                                : Text(
                                    _purchaseLabel(context, item.purchasedOn!),
                                  ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('添加物品'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _purchaseLabel(BuildContext context, DateTime date) =>
    '购入日期 ${MaterialLocalizations.of(context).formatFullDate(date)}';

class _ItemDetails extends StatelessWidget {
  const _ItemDetails({required this.item, required this.photos});

  final ItemEntry item;
  final Future<List<Uint8List>> photos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SafeArea(
        child: FutureBuilder(
          future: photos,
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('照片读取失败，请重新打开物品');
            final values = snapshot.data;
            if (values == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final purchased = item.purchasedOn;
            final headerCount = purchased == null ? 0 : 1;
            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: headerCount + values.length,
              itemBuilder: (context, index) {
                if (index < headerCount) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_purchaseLabel(context, purchased!)),
                  );
                }
                final photoIndex = index - headerCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      values[photoIndex],
                      semanticLabel: '物品照片 ${photoIndex + 1}',
                      errorBuilder: (_, _, _) => const Text('照片无法显示'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
