import 'dart:io';

import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:path/path.dart' as p;

import '../domain/daily_record.dart';
import '../domain/schedule_config.dart';
import '../domain/weather.dart';

/// Owns the SQLite DB and photo files.
class Database {
  Database._(this._db);
  final sqflite.Database _db;

  static const _kConfigRowId = 1;

  static Future<Database> open(String appDir) async {
    final path = p.join(appDir, 'garden_timelapse.db');
    final db = await sqflite.openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE days (
            date TEXT PRIMARY KEY,
            shot1Path TEXT,
            shot1TakenAt TEXT,
            shot1Zoom REAL,
            shot1Width INTEGER,
            shot1Height INTEGER,
            shot2Path TEXT,
            shot2TakenAt TEXT,
            shot2Zoom REAL,
            shot2Width INTEGER,
            shot2Height INTEGER,
            note TEXT DEFAULT '',
            weatherCondition TEXT,
            weatherTemperatureC REAL,
            weatherHumidity INTEGER,
            weatherWind TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE config (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            enabled INTEGER NOT NULL DEFAULT 0,
            shot1Hour INTEGER NOT NULL DEFAULT 7,
            shot1Minute INTEGER NOT NULL DEFAULT 0,
            shot2Enabled INTEGER NOT NULL DEFAULT 1,
            shot2Hour INTEGER NOT NULL DEFAULT 20,
            shot2Minute INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.insert('config', const {
          'id': _kConfigRowId,
          'enabled': 0,
          'shot1Hour': 7,
          'shot1Minute': 0,
          'shot2Enabled': 1,
          'shot2Hour': 20,
          'shot2Minute': 0,
        });
      },
    );
    return Database._(db);
  }

  // ---- Days ----

  Future<DailyRecord> getDay(String date) async {
    final rows = await _db.query('days', where: 'date = ?', whereArgs: [date]);
    if (rows.isEmpty) {
      return DailyRecord(date: date, weather: const Weather());
    }
    return DailyRecord.fromRow(rows.first);
  }

  /// All records in [start, end] (inclusive, 'YYYY-MM-DD').
  Future<List<DailyRecord>> getDaysInRange(String start, String end) async {
    final rows = await _db.query(
      'days',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start, end],
      columns: ['date'],
    );
    final dates = rows.map((r) => r['date'] as String).toSet();
    final out = <DailyRecord>[];
    for (final d in dates) {
      out.add(await getDay(d));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// The most recent day strictly before [date] that has at least one shot.
  /// Used for the onion-skin ghost and FOV matching.
  Future<DailyRecord?> previousShotDay(String date) async {
    final rows = await _db.rawQuery(
      '''
      SELECT date FROM days
      WHERE date < ? AND (shot1Path IS NOT NULL OR shot2Path IS NOT NULL)
      ORDER BY date DESC LIMIT 1
      ''',
      [date],
    );
    if (rows.isEmpty) return null;
    return getDay(rows.first['date'] as String);
  }

  Future<void> saveDay(DailyRecord record) async {
    await _db.insert('days', record.toRow(),
        conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
  }

  Future<void> deleteDay(String date) async {
    final record = await getDay(date);
    await _db.delete('days', where: 'date = ?', whereArgs: [date]);
    for (final shot in [record.shot1, record.shot2]) {
      final path = shot?.path;
      if (path != null) {
        final f = File(path);
        if (f.existsSync()) await f.delete();
      }
    }
  }

  // ---- Config ----

  Future<ScheduleConfig> getConfig() async {
    final rows = await _db.query('config', where: 'id = ?', whereArgs: [_kConfigRowId]);
    if (rows.isEmpty) return const ScheduleConfig();
    return ScheduleConfig.fromRow(rows.first);
  }

  Future<void> saveConfig(ScheduleConfig config) async {
    await _db.insert(
      'config',
      {'id': _kConfigRowId, ...config.toRow()},
      conflictAlgorithm: sqflite.ConflictAlgorithm.replace,
    );
  }

  Future<void> close() => _db.close();
}
