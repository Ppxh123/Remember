import 'package:flutter/material.dart';

import 'lunar_date.dart';

class LunarDateDialog extends StatefulWidget {
  const LunarDateDialog({this.initialDate, super.key});

  final LunarDate? initialDate;

  @override
  State<LunarDateDialog> createState() => _LunarDateDialogState();
}

class _LunarDateDialogState extends State<LunarDateDialog> {
  final _form = GlobalKey<FormState>();
  late final _year = TextEditingController(
    text: widget.initialDate?.year.toString(),
  );
  late final _month = TextEditingController(
    text: widget.initialDate?.month.toString(),
  );
  late final _day = TextEditingController(
    text: widget.initialDate?.day.toString(),
  );
  late bool _isLeapMonth = widget.initialDate?.isLeapMonth ?? false;
  String? _dateError;

  @override
  void dispose() {
    _year.dispose();
    _month.dispose();
    _day.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    final year = int.parse(_year.text.trim());
    final month = int.parse(_month.text.trim());
    final day = int.parse(_day.text.trim());
    final dayCount = LunarDate.daysInMonth(
      year,
      month,
      isLeapMonth: _isLeapMonth,
    );

    if (dayCount == null || day > dayCount) {
      setState(() {
        _dateError = dayCount == null ? '该年没有这个闰月' : '这个农历月只有 $dayCount 天';
      });
      return;
    }

    Navigator.of(context).pop(
      LunarDate(year: year, month: month, day: day, isLeapMonth: _isLeapMonth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context);
    return AlertDialog(
      title: const Text('选择农历日期'),
      scrollable: true,
      content: Form(
        key: _form,
        onChanged: () {
          if (_dateError != null) setState(() => _dateError = null);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _numberField(
              _year,
              '农历年份',
              LunarDate.firstYear,
              LunarDate.lastYear,
            ),
            _numberField(_month, '农历月份', 1, 12),
            _numberField(_day, '农历日', 1, 30),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('闰月'),
              value: _isLeapMonth,
              onChanged: (selected) => setState(() {
                _isLeapMonth = selected;
                _dateError = null;
              }),
            ),
            if (_dateError case final message?)
              Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(labels.cancelButtonLabel),
        ),
        TextButton(onPressed: _confirm, child: Text(labels.okButtonLabel)),
      ],
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    int minimum,
    int maximum,
  ) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (text) {
        final value = int.tryParse(text?.trim() ?? '');
        return value == null || value < minimum || value > maximum
            ? '请输入 $minimum–$maximum'
            : null;
      },
    );
  }
}
