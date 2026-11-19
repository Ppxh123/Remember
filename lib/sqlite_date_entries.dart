import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'date_entries.dart';

final class SqliteDateEntries implements DateEntries {
  const SqliteDateEntries({this.databaseName = 'remember.db'});

  static const _storage = MethodChannel('io.github.ppxh123.remember/storage');

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
      version: 1,
      onCreate: (database, _) => database.execute('''
        CREATE TABLE date_entries (
          id INTEGER PRIMARY KEY,
          title TEXT NOT NULL,
          target_date INTEGER NOT NULL
        )
      '''),
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
      'target_date': entry.targetDate.millisecondsSinceEpoch,
    });
  }

  Future<void> close() async {
    final database = await _open();
    await database.close();
  }
}
