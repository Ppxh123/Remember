import 'package:flutter/material.dart';

import 'reminders.dart';

typedef ReminderEdit = ({ReminderOptions? options});

Future<void> editReminder(
  BuildContext context,
  Reminders reminders,
  ReminderKey key,
) async {
  try {
    final current = await reminders.read(key);
    if (!context.mounted) return;
    final selected = await showDialog<ReminderEdit>(
      context: context,
      builder: (_) => _ReminderDialog(current: current),
    );
    if (selected == null || !context.mounted) return;
    final result = await reminders.save(key, selected.options);
    if (!context.mounted) return;
    if (result != ReminderSaveResult.saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == ReminderSaveResult.denied
                ? '通知权限未开启，提醒未启用'
                : '该提醒时间已过，请选择未来时间',
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法安排提醒，请重试')));
    }
  }
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({this.current});

  final ReminderOptions? current;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  late bool _enabled = widget.current != null;
  late TimeOfDay _at = TimeOfDay(
    hour: widget.current?.hour ?? 9,
    minute: widget.current?.minute ?? 0,
  );
  late final _lead = TextEditingController(
    text: '${widget.current?.leadDays ?? 0}',
  );
  String? _error;

  @override
  void dispose() {
    _lead.dispose();
    super.dispose();
  }

  void _save() {
    if (!_enabled) {
      Navigator.of(context).pop((options: null as ReminderOptions?));
      return;
    }
    final leadDays = int.tryParse(_lead.text.trim());
    if (leadDays == null || leadDays < 0 || leadDays > 3652058) {
      setState(() => _error = '请输入有效的提前天数');
      return;
    }
    Navigator.of(context).pop((
      options: ReminderOptions(
        leadDays: leadDays,
        hour: _at.hour,
        minute: _at.minute,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置提醒'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('启用提醒'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          if (_enabled) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('提醒时间'),
              subtitle: Text(_at.format(context)),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _at,
                );
                if (mounted && time != null) setState(() => _at = time);
              },
            ),
            TextField(
              controller: _lead,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: '提前天数', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(onPressed: _save, child: const Text('保存提醒')),
      ],
    );
  }
}
