import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'app_calendar.dart';
import 'date_entries.dart';
import 'item_entries.dart';
import 'item_expiry.dart';
import 'lunar_date.dart';
import 'reminders.dart';

final class RememberDatabase
    implements DateEntries, ItemEntries, AppTimeZoneStore, ReminderStore {
  const RememberDatabase({this.databaseName = 'remember.db'});

  static const _storage = MethodChannel('io.github.ppxh123.remember/storage');
  static const _dateEntryType = "type TEXT NOT NULL DEFAULT 'oneTime'";
  static const _lunarColumns = [
    'lunar_year INTEGER',
    'lunar_month INTEGER',
    'lunar_day INTEGER',
  ];

  static const _createSettings = '''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''';

  static const _expiryColumns = [
    'expires_on INTEGER',
    'produced_on INTEGER',
    'shelf_life_amount INTEGER',
    'shelf_life_unit TEXT',
  ];

  static final _createItems =
      '''
    CREATE TABLE items (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      purchased_on INTEGER,
      ${_expiryColumns.join(', ')}
    )
  ''';

  static const _createPhotoChunks = '''
    CREATE TABLE item_photo_chunks (
      item_id INTEGER NOT NULL REFERENCES items(id),
      photo_index INTEGER NOT NULL,
      chunk_index INTEGER NOT NULL,
      bytes BLOB NOT NULL,
      PRIMARY KEY (item_id, photo_index, chunk_index)
    )
  ''';

  static const _createReminders = '''
    CREATE TABLE reminders (
      scope TEXT NOT NULL,
      entry_id INTEGER NOT NULL,
      lead_days INTEGER NOT NULL,
      hour INTEGER NOT NULL,
      minute INTEGER NOT NULL,
      PRIMARY KEY (scope, entry_id)
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
      version: 7,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE date_entries (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL,
            target_date INTEGER NOT NULL,
            $_dateEntryType,
            ${_lunarColumns.join(', ')}
          )
        ''');
        await database.execute(_createSettings);
        await database.execute(_createItems);
        await database.execute(_createPhotoChunks);
        await database.execute(_createReminders);
      },
      onUpgrade: (database, oldVersion, _) async {
        if (oldVersion < 2) await database.execute(_createSettings);
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE date_entries ADD $_dateEntryType',
          );
        }
        if (oldVersion < 4) {
          for (final column in _lunarColumns) {
            await database.execute('ALTER TABLE date_entries ADD $column');
          }
        }
        if (oldVersion < 5) {
          await database.execute(_createItems);
          await database.execute(_createPhotoChunks);
        } else if (oldVersion < 6) {
          for (final column in _expiryColumns) {
            await database.execute('ALTER TABLE items ADD $column');
          }
        }
        if (oldVersion < 7) await database.execute(_createReminders);
      },
    );
  }

  @override
  Future<List<DateEntry>> read() async {
    final database = await _open();
    final rows = await database.query('date_entries', orderBy: 'id DESC');

    return rows.map(_dateEntryFromRow).toList();
  }

  DateEntry _dateEntryFromRow(Map<String, Object?> row) {
    final title = row['title'] as String;
    final id = row['id'] as int;
    final type = DateEntryType.values.byName(row['type'] as String);
    if (row['lunar_year'] case final int year) {
      final signedMonth = row['lunar_month'] as int;
      return DateEntry.lunar(
        id: id,
        title: title,
        type: type,
        originalDate: LunarDate(
          year: year,
          month: signedMonth.abs(),
          day: row['lunar_day'] as int,
          isLeapMonth: signedMonth < 0,
        ),
      );
    }

    return DateEntry(
      id: id,
      title: title,
      type: type,
      targetDate: DateTime.fromMillisecondsSinceEpoch(
        row['target_date'] as int,
        isUtc: true,
      ),
    );
  }

  @override
  Future<void> add(DateEntry entry) async {
    final database = await _open();
    await database.insert('date_entries', {
      'title': entry.title,
      'type': entry.type.name,
      'target_date': entry.targetDate.millisecondsSinceEpoch,
      'lunar_year': entry.lunarDate?.year,
      'lunar_month': entry.lunarDate?.signedMonth,
      'lunar_day': entry.lunarDate?.day,
    });
  }

  @override
  Future<List<ItemEntry>> readItems() async {
    final database = await _open();
    final rows = await database.query('items', orderBy: 'id DESC');
    return [
      for (final row in rows)
        ItemEntry(
          id: row['id'] as int,
          name: row['name'] as String,
          expiry: _readExpiry(row),
          purchasedOn: switch (row['purchased_on']) {
            final int day => DateTime.fromMillisecondsSinceEpoch(
              day,
              isUtc: true,
            ),
            _ => null,
          },
        ),
    ];
  }

  @override
  Future<void> addItem(ItemDraft item) async {
    final database = await _open();
    await database.transaction((transaction) async {
      final itemId = await transaction.insert('items', {
        'name': item.name,
        'purchased_on': item.purchasedOn?.millisecondsSinceEpoch,
        ..._expiryValues(item.expiry),
      });
      final batch = transaction.batch();
      // Each row fits comfortably inside Android's CursorWindow.
      const chunkSize = 256 * 1024;
      for (var index = 0; index < item.photos.length; index++) {
        final photo = item.photos[index];
        if (photo.isEmpty) throw ArgumentError('Empty item photo');
        for (var offset = 0; offset < photo.length; offset += chunkSize) {
          final end = (offset + chunkSize).clamp(0, photo.length);
          batch.insert('item_photo_chunks', {
            'item_id': itemId,
            'photo_index': index,
            'chunk_index': offset ~/ chunkSize,
            'bytes': Uint8List.sublistView(photo, offset, end),
          });
        }
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> updateItemExpiry(int itemId, ItemExpiry? expiry) async {
    final database = await _open();
    await database.update(
      'items',
      _expiryValues(expiry),
      where: 'id = ?',
      whereArgs: [itemId],
    );
  }

  Map<String, Object?> _expiryValues(ItemExpiry? expiry) => {
    'expires_on': expiry?.date.millisecondsSinceEpoch,
    'produced_on': expiry?.shelfLife?.producedOn.millisecondsSinceEpoch,
    'shelf_life_amount': expiry?.shelfLife?.amount,
    'shelf_life_unit': expiry?.shelfLife?.unit.name,
  };

  ItemExpiry? _readExpiry(Map<String, Object?> row) {
    final expiresOn = row['expires_on'] as int?;
    if (expiresOn == null) return null;
    if (row['shelf_life_unit'] case final String unit) {
      return ItemExpiry.calculated(
        ShelfLife(
          producedOn: DateTime.fromMillisecondsSinceEpoch(
            row['produced_on'] as int,
            isUtc: true,
          ),
          amount: row['shelf_life_amount'] as int,
          unit: ShelfLifeUnit.values.byName(unit),
        ),
      );
    }
    return ItemExpiry.direct(
      DateTime.fromMillisecondsSinceEpoch(expiresOn, isUtc: true),
    );
  }

  @override
  Future<List<Uint8List>> readItemPhotos(int itemId) async {
    final database = await _open();
    final rows = await database.query(
      'item_photo_chunks',
      columns: ['photo_index', 'bytes'],
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'photo_index, chunk_index',
    );
    final photos = <int, BytesBuilder>{};
    for (final row in rows) {
      photos
          .putIfAbsent(
            row['photo_index'] as int,
            () => BytesBuilder(copy: false),
          )
          .add(row['bytes'] as Uint8List);
    }
    return [for (final photo in photos.values) photo.takeBytes()];
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

  @override
  Future<List<ReminderRecord>> readReminders() async {
    final database = await _open();
    final rows = await database.query('reminders');
    return [
      for (final row in rows)
        (
          key: (
            scope: ReminderScope.values.byName(row['scope'] as String),
            id: row['entry_id'] as int,
          ),
          options: ReminderOptions(
            leadDays: row['lead_days'] as int,
            hour: row['hour'] as int,
            minute: row['minute'] as int,
          ),
        ),
    ];
  }

  @override
  Future<void> writeReminder(ReminderKey key, ReminderOptions? options) async {
    final database = await _open();
    if (options == null) {
      await database.delete(
        'reminders',
        where: 'scope = ? AND entry_id = ?',
        whereArgs: [key.scope.name, key.id],
      );
      return;
    }
    await database.insert('reminders', {
      'scope': key.scope.name,
      'entry_id': key.id,
      'lead_days': options.leadDays,
      'hour': options.hour,
      'minute': options.minute,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
