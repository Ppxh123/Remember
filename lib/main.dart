import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'date_entries.dart';
import 'date_page.dart';
import 'sqlite_date_entries.dart';

void main() {
  runApp(const MainApp(dateEntries: SqliteDateEntries()));
}

class MainApp extends StatelessWidget {
  const MainApp({
    super.key,
    required this.dateEntries,
    this.now = DateTime.now,
  });

  final DateEntries dateEntries;
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
      home: _Home(entries: dateEntries, now: now),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({required this.entries, required this.now});

  final DateEntries entries;
  final DateTime Function() now;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      DatePage(entries: widget.entries, now: widget.now),
      const _ModuleEntry(icon: Icons.inventory_2_outlined, label: '物品记录'),
      const _ModuleEntry(icon: Icons.lock_outline_rounded, label: '凭据保险箱'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('莫忘')),
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
