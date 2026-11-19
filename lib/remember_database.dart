import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_calendar.dart';
import 'date_entries.dart';

final class RememberDatabase implements DateEntries, AppTimeZoneStore {
  const RememberDatabase({this.databaseName = 'remember.db'});

  static const _storage = MethodChannel('io.github.ppxh123.remember/storage');
  static const _dateEntryType = "type TEXT NOT NULL DEFAULT 'oneTime'";

  static const _createSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  final String databaseName;

  Future<Database> _open() async {
    var path = databaseName;
    if (Platform.isIOS) {
      final directory = await _storage.invokeMethod<String>(
        'prepareLocalDirectory',
      );
      if (directory == null) throw StateError('Local storage unavailable');
      path = '$directory/$databaseName';
    }

    return openDatabase(
      path,
      version: 3,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE date_entries (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            target_date INTEGER NOT NULL,
            $_dateEntryType
          )
        ''');
        await database.execute(_createSettings);
      },
      onUpgrade: (database, oldVersion, _) async {
        if (oldVersion < 2) await database.execute(_createSettings);
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE date_entries ADD $_dateEntryType',
          );
        }
      },
    );
  }

  @override
  Future<List<DateEntry>> read() async {
    final database = await _open();
    final rows = await database.query('date_entries', orderBy: 'id DESC');

    return [
      for (final row in rows)
        DateEntry(
          title: row['title'] as String,
          type: DateEntryType.values.byName(row['type'] as String),
          targetDate: DateTime.fromMillisecondsSinceEpoch(
            row['target_date'] as int,
            isUtc: true,
          ),
        ),
    ];
  }

  @override
  Future<void> add(DateEntry entry) async {
    final database = await _open();
    await database.insert('date_entries', {
      'title': entry.title,
      'type': entry.type.name,
      'target_date': entry.targetDate.millisecondsSinceEpoch,
    });
  }

  @override
  Future<AppTimeZone> readTimeZone() async {
    final database = await _open();
    final rows = await database.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['time_zone'],
    );
    return rows.firstOrNull?['value'] == AppTimeZone.device.name
        ? AppTimeZone.device
        : AppTimeZone.beijing;
  }

  @override
  Future<void> writeTimeZone(AppTimeZone timeZone) async {
    final database = await _open();
    await database.insert('app_settings', {
      'key': 'time_zone',
      'value': timeZone.name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final database = await _open();
    await database.close();
  }
}
