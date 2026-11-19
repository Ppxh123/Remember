import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_calendar.dart';
import 'date_entries.dart';
import 'date_page.dart';
import 'device_clock.dart' as device_clock;
import 'remember_database.dart';

void main() {
  const database = RememberDatabase();
  runApp(
    MainApp(
      dateEntries: database,
      timeZones: database,
      deviceTimeChanges: device_clock.deviceTimeChanges,
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({
    super.key,
    required this.dateEntries,
    required this.timeZones,
    this.now = DateTime.now,
    this.deviceDayAt = device_clock.deviceDayAt,
    this.deviceTimeChanges = const Stream<void>.empty(),
  });

  final DateEntries dateEntries;
  final AppTimeZoneStore timeZones;
  final DeviceDayAt deviceDayAt;
  final Stream<void> deviceTimeChanges;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xFFE87632))
        .copyWith(
          primary: const Color(0xFF9A3D17),
          primaryContainer: const Color(0xFFFFE1C8),
          onPrimaryContainer: const Color(0xFF47200E),
          surface: const Color(0xFFFFF8F0),
        );

    return MaterialApp(
      title: '莫忘',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: colors,
        scaffoldBackgroundColor: colors.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(
            color: Color(0xFF35241C),
            fontSize: 25,
            fontWeight: FontWeight.w700,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFFFF1E5),
          indicatorColor: colors.primaryContainer,
        ),
      ),
      home: _Home(
        entries: dateEntries,
        calendarStore: timeZones,
        now: now,
        deviceDayAt: deviceDayAt,
        deviceTimeChanges: deviceTimeChanges,
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({
    required this.entries,
    required this.calendarStore,
    required this.now,
    required this.deviceDayAt,
    required this.deviceTimeChanges,
  });

  final DateEntries entries;
  final AppTimeZoneStore calendarStore;
  final DeviceDayAt deviceDayAt;
  final Stream<void> deviceTimeChanges;
  final DateTime Function() now;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;
  bool _choosingTimeZone = false;
  late final AppCalendar _calendar;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<void> _clockChanges;

  @override
  void initState() {
    super.initState();
    _calendar = AppCalendar(
      store: widget.calendarStore,
      now: widget.now,
      deviceDayAt: widget.deviceDayAt,
    );
    _lifecycle = AppLifecycleListener(onResume: _calendar.refresh);
    _clockChanges = widget.deviceTimeChanges.listen((_) => _calendar.refresh());
    unawaited(_calendar.load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_clockChanges.cancel());
    _calendar.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final current = _calendar.timeZone;
    if (current == null || _choosingTimeZone) return;

    setState(() => _choosingTimeZone = true);
    try {
      final chosen = await showDialog<AppTimeZone>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('应用时区'),
          children: [
            for (final zone in AppTimeZone.values)
              ListTile(
                title: Text(zone.label),
                selected: zone == current,
                trailing: Icon(
                  zone == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                onTap: () => Navigator.of(context).pop(zone),
              ),
          ],
        ),
      );
      if (mounted && chosen != null && chosen != current) {
        await _calendar.choose(chosen);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存时区失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _choosingTimeZone = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _calendar,
    builder: (context, _) => _buildHome(),
  );

  Widget _buildHome() {
    final current = _calendar.current;
    final pages = [
      if (current != null)
        DatePage(
          entries: widget.entries,
          today: current.today,
          timeZone: current.timeZone,
        )
      else if (_calendar.failed)
        Center(
          child: TextButton(
            onPressed: _calendar.load,
            child: const Text('读取应用时区失败，重试'),
          ),
        )
      else
        const Center(child: CircularProgressIndicator()),
      const _ModuleEntry(icon: Icons.inventory_2_outlined, label: '物品记录'),
      const _ModuleEntry(icon: Icons.lock_outline_rounded, label: '凭据保险箱'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('莫忘'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: _calendar.timeZone == null || _choosingTimeZone
                ? null
                : _openSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: _index, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: '日期',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: '物品',
          ),
          NavigationDestination(
            icon: Icon(Icons.lock_outline_rounded),
            selectedIcon: Icon(Icons.lock_rounded),
            label: '凭据保险箱',
          ),
        ],
      ),
    );
  }
}

class _ModuleEntry extends StatelessWidget {
  const _ModuleEntry({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(label, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('$label将在后续版本开放'),
          ],
        ),
      ),
    );
  }
}
