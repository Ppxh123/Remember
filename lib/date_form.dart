import 'package:flutter/material.dart';

import 'date_entries.dart';
import 'lunar_date.dart';
import 'lunar_date_dialog.dart';

class DateForm extends StatefulWidget {
  const DateForm({required this.today, required this.save, super.key});

  final DateTime today;
  final Future<void> Function(DateEntry entry) save;

  @override
  State<DateForm> createState() => _DateFormState();
}

class _DateFormState extends State<DateForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late DateTime _targetDate = widget.today;
  DateEntryType _type = DateEntryType.oneTime;
  DateEntryCalendar _calendar = DateEntryCalendar.gregorian;
  LunarDate? _lunarDate;
  bool _saving = false;
  bool _saveFailed = false;

  bool get _needsLunarDate =>
      _calendar == DateEntryCalendar.lunar && _lunarDate == null;

  void _changeCalendar(DateEntryCalendar selected) {
    if (selected == _calendar) return;
    switch (selected) {
      case DateEntryCalendar.gregorian:
        _targetDate = _lunarDate?.gregorianDate ?? _targetDate;
      case DateEntryCalendar.lunar:
        _lunarDate = LunarDate.fromGregorian(_targetDate);
    }
    _calendar = selected;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    if (_calendar == DateEntryCalendar.lunar) {
      final picked = await showDialog<LunarDate>(
        context: context,
        builder: (_) => LunarDateDialog(initialDate: _lunarDate),
      );
      if (picked != null && mounted) setState(() => _lunarDate = picked);
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(1),
      lastDate: DateTime(9999, 12, 31),
      currentDate: widget.today,
    );

    if (picked != null && mounted) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (_saving || _needsLunarDate || !_form.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveFailed = false;
    });

    try {
      final title = _title.text.trim();
      final entry = _calendar == DateEntryCalendar.lunar
          ? DateEntry.lunar(
              title: title,
              type: _type,
              originalDate: _lunarDate!,
            )
          : DateEntry(title: title, targetDate: _targetDate, type: _type);
      await widget.save(entry);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
      return;
    }

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('添加日期')),
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
                      controller: _title,
                      enabled: !_saving,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: '日期名称',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          (value?.trim().isEmpty ?? true) ? '请输入日期名称' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DateEntryType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: '条目类型',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final type in DateEntryType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (type) {
                              if (type == null) return;
                              setState(() {
                                _type = type;
                                if (!type.repeats) {
                                  _changeCalendar(DateEntryCalendar.gregorian);
                                }
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    if (_type.repeats) ...[
                      DropdownButtonFormField<DateEntryCalendar>(
                        initialValue: _calendar,
                        decoration: const InputDecoration(
                          labelText: '历法',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final calendar in DateEntryCalendar.values)
                            DropdownMenuItem(
                              value: calendar,
                              child: Text(calendar.label),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (calendar) {
                                if (calendar == null) return;
                                setState(() => _changeCalendar(calendar));
                              },
                      ),
                      const SizedBox(height: 16),
                    ],
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: theme.colorScheme.outline),
                      ),
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        _calendar == DateEntryCalendar.lunar ? '农历日期' : '目标日期',
                      ),
                      subtitle: Text(
                        _calendar == DateEntryCalendar.lunar
                            ? _lunarDate?.label ?? '请选择 1901–2100 年的农历日期'
                            : MaterialLocalizations.of(
                                context,
                              ).formatFullDate(_targetDate),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _saving ? null : _pickDate,
                    ),
                    if (_saveFailed) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '保存失败，请重试',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving || _needsLunarDate ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(_saving ? '正在保存' : '保存'),
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
