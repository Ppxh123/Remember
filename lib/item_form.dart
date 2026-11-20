import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'item_entries.dart';
import 'item_expiry.dart';
import 'item_expiry_dialog.dart';
import 'item_photo_picker.dart';

class ItemForm extends StatefulWidget {
  const ItemForm({
    required this.today,
    required this.entries,
    required this.pickPhotos,
    super.key,
  });

  final DateTime today;
  final ItemEntries entries;
  final PickItemPhotos pickPhotos;

  @override
  State<ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<ItemForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _photos = <Uint8List>[];
  DateTime? _purchasedOn;
  ItemExpiry? _expiry;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_recoverPhotos());
  }

  Future<void> _recoverPhotos() async {
    try {
      final recovered = await recoverItemPhotos();
      if (mounted) setState(() => _photos.addAll(recovered));
    } catch (_) {
      if (mounted) setState(() => _error = '无法恢复上次选择的照片');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePurchaseDate() async {
    FocusScope.of(context).unfocus();
    final date = await showDatePicker(
      context: context,
      initialDate: _purchasedOn ?? widget.today,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: widget.today,
    );
    if (mounted && date != null) {
      setState(
        () => _purchasedOn = DateTime.utc(date.year, date.month, date.day),
      );
    }
  }

  Future<void> _pick(ItemPhotoSource source) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photos = await widget.pickPhotos(source);
      if (mounted) setState(() => _photos.addAll(photos));
    } catch (_) {
      if (mounted) setState(() => _error = '无法读取照片，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseExpiry() async {
    FocusScope.of(context).unfocus();
    final selected = await showDialog<ExpiryEdit>(
      context: context,
      builder: (_) =>
          ItemExpiryDialog(today: widget.today, initialExpiry: _expiry),
    );
    if (mounted && selected != null) setState(() => _expiry = selected.expiry);
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.entries.addItem(
        ItemDraft(
          name: _name.text.trim(),
          purchasedOn: _purchasedOn,
          expiry: _expiry,
          photos: List.of(_photos),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = '保存失败，请重试';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = MaterialLocalizations.of(context);
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('添加物品')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      decoration: const InputDecoration(
                        labelText: '物品名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (text) => text == null || text.trim().isEmpty
                          ? '请输入物品名称'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('购入日期'),
                      subtitle: Text(
                        _purchasedOn == null
                            ? '选填'
                            : locale.formatFullDate(_purchasedOn!),
                      ),
                      onTap: _busy ? null : _choosePurchaseDate,
                      trailing: _purchasedOn == null
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: '清除购入日期',
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _purchasedOn = null),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('设置到期日'),
                      subtitle: Text(
                        _expiry == null ? '选填' : expiryLabel(context, _expiry!),
                      ),
                      onTap: _busy ? null : _chooseExpiry,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pick(ItemPhotoSource.camera),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('拍照'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _pick(ItemPhotoSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('从相册选择'),
                        ),
                      ],
                    ),
                    if (_photos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var index = 0; index < _photos.length; index++)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    _photos[index],
                                    width: 96,
                                    height: 96,
                                    cacheWidth: 192,
                                    fit: BoxFit.cover,
                                    semanticLabel: '照片 ${index + 1}',
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 96,
                                      height: 96,
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: IconButton.filledTonal(
                                    tooltip: '移除照片 ${index + 1}',
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _photos.removeAt(index),
                                          ),
                                    icon: const Icon(Icons.close, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                    if (_error case final message?) ...[
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: const Text('保存物品'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
