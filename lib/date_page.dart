import 'package:flutter/material.dart';

import 'app_calendar.dart';
import 'date_entries.dart';
import 'date_form.dart';

class DatePage extends StatefulWidget {
  const DatePage({
    required this.entries,
    required this.today,
    required this.timeZone,
    super.key,
  });

  final DateEntries entries;
  final DateTime today;
  final AppTimeZone timeZone;

  @override
  State<DatePage> createState() => _DatePageState();
}

class _DatePageState extends State<DatePage> {
  late Future<List<DateEntry>> _entries;
  @override
  void initState() {
    super.initState();
    _entries = widget.entries.read();
  }

  void _reload() {
    final entries = widget.entries.read();
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _addDate() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DateForm(today: widget.today, save: widget.entries.add),
      ),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  Text(
                    '日期条目',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.timeZone.label,
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<DateEntry>>(
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
                      return const Center(
                        child: SingleChildScrollView(child: _EmptyDates()),
                      );
                    }
                    return ListView.separated(
                      itemBuilder: (_, index) =>
                          _DateCard(entry: entries[index], today: widget.today),
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemCount: entries.length,
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _addDate,
                icon: const Icon(Icons.add),
                label: const Text('添加日期'),
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

class _EmptyDates extends StatelessWidget {
  const _EmptyDates();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: const CircleBorder(),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.event_available_outlined,
                size: 38,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('还没有日期条目', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({required this.entry, required this.today});

  final DateEntry entry;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dates = MaterialLocalizations.of(context);
    final occurrence = entry.occurrenceFor(today);
    final originalDate =
        entry.lunarDate?.label ?? dates.formatFullDate(entry.targetDate);
    final days = occurrence.difference(today).inDays;
    final countdown = switch (days) {
      > 0 => '还有 $days 天',
      0 => '今天',
      _ => '已过 ${days.abs()} 天',
    };

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerLow,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entry.title, style: theme.textTheme.titleMedium),
            if (entry.type.repeats)
              Text(
                '${entry.type.label} · ${entry.calendar.label}',
                style: theme.textTheme.labelMedium,
              ),
            const SizedBox(height: 4),
            Text(
              dates.formatFullDate(occurrence),
              style: theme.textTheme.bodyMedium,
            ),
            if (entry.type.repeats)
              Text('原始日期 $originalDate', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
              countdown,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
