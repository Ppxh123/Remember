import 'package:flutter/material.dart';

import 'item_expiry.dart';

typedef ExpiryEdit = ({ItemExpiry? expiry});

class ItemExpiryDialog extends StatefulWidget {
  const ItemExpiryDialog({required this.today, this.initialExpiry, super.key});

  final DateTime today;
  final ItemExpiry? initialExpiry;

  @override
  State<ItemExpiryDialog> createState() => _ItemExpiryDialogState();
}

class _ItemExpiryDialogState extends State<ItemExpiryDialog> {
  late final _quantity = TextEditingController(
    text: '${widget.initialExpiry?.shelfLife?.amount ?? 1}',
  );
  late DateTime _directDate = widget.initialExpiry?.date ?? widget.today;
  late DateTime _producedOn =
      widget.initialExpiry?.shelfLife?.producedOn ?? widget.today;
  late ShelfLifeUnit _unit =
      widget.initialExpiry?.shelfLife?.unit ?? ShelfLifeUnit.days;
  late bool _calculate = widget.initialExpiry?.shelfLife != null;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final selected = await showDatePicker(
      context: context,
      initialDate: _calculate ? _producedOn : _directDate,
      currentDate: widget.today,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
    );
    if (selected == null || !mounted) return;
    final date = DateTime.utc(selected.year, selected.month, selected.day);
    setState(() {
      _error = null;
      if (_calculate) {
        _producedOn = date;
      } else {
        _directDate = date;
      }
    });
  }

  void _confirm() {
    if (!_calculate) {
      Navigator.of(context).pop((expiry: ItemExpiry.direct(_directDate)));
      return;
    }
    final amount = int.tryParse(_quantity.text.trim());
    if (amount == null || amount < 1) {
      setState(() => _error = '请输入正整数保质期');
      return;
    }
    try {
      final expiry = ItemExpiry.calculated(
        ShelfLife(producedOn: _producedOn, amount: amount, unit: _unit),
      );
      Navigator.of(context).pop((expiry: expiry));
    } on ArgumentError {
      setState(() => _error = '推算日期超出可录入范围');
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context);
    return AlertDialog(
      title: const Text('设置到期日'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('按生产日期和保质期推算'),
            value: _calculate,
            onChanged: (value) => setState(() {
              _calculate = value;
              _error = null;
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_calculate ? '生产日期' : '到期日'),
            subtitle: Text(
              labels.formatFullDate(_calculate ? _producedOn : _directDate),
            ),
            trailing: const Icon(Icons.event_outlined),
            onTap: _pickDate,
          ),
          if (_calculate) ...[
            TextFormField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '保质期'),
            ),
            DropdownButtonFormField<ShelfLifeUnit>(
              initialValue: _unit,
              decoration: const InputDecoration(labelText: '单位'),
              items: [
                for (final unit in ShelfLifeUnit.values)
                  DropdownMenuItem(value: unit, child: Text(unit.label)),
              ],
              onChanged: (unit) {
                if (unit != null) setState(() => _unit = unit);
              },
            ),
          ],
          if (_error case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        if (widget.initialExpiry != null)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop((expiry: null as ItemExpiry?)),
            child: const Text('清除到期日'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.cancelButtonLabel),
        ),
        TextButton(onPressed: _confirm, child: const Text('确认到期日')),
      ],
    );
  }
}

String expiryLabel(BuildContext context, ItemExpiry expiry) =>
    '到期日 ${MaterialLocalizations.of(context).formatFullDate(expiry.date)}';
