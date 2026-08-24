import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database.dart';
import '../data/photo_store.dart';
import '../domain/daily_record.dart';
import '../domain/schedule_config.dart';
import '../domain/weather.dart';
import '../services/reminder_service.dart';
import '../services/timelapse_exporter.dart';

/// Application-scoped singletons, resolved once in [bootstrap].
late Directory appDir;
late Database database;
late PhotoStore photoStore;

/// Resolves the app-scoped directory and opens the DB + photo store.
/// Must be awaited before the widget tree is built.
Future<void> bootstrap() async {
  final docs = await getApplicationDocumentsDirectory();
  appDir = Directory(p.join(docs.path, 'garden_timelapse'));
  if (!appDir.existsSync()) await appDir.create(recursive: true);
  database = await Database.open(appDir.path);
  photoStore = PhotoStore(appDir);
}

final databaseProvider = Provider<Database>((ref) => database);
final photoStoreProvider = Provider<PhotoStore>((ref) => photoStore);
final appDirProvider = Provider<Directory>((ref) => appDir);

final reminderServiceProvider = Provider<ReminderService>(
    (ref) => ReminderService());

final timelapseExporterProvider = Provider<TimelapseExporter>(
    (ref) => const TimelapseExporter());

/// Holds the live [ScheduleConfig]; persists and reschedules on change.
final scheduleControllerProvider =
    StateNotifierProvider<ScheduleController, ScheduleConfig>((ref) {
  final db = ref.watch(databaseProvider);
  final reminders = ref.watch(reminderServiceProvider);
  return ScheduleController(db, reminders);
});

class ScheduleController extends StateNotifier<ScheduleConfig> {
  ScheduleController(this._db, this._reminders) : super(const ScheduleConfig());
  final Database _db;
  final ReminderService _reminders;

  Future<ScheduleConfig> load() async {
    state = await _db.getConfig();
    return state;
  }

  /// Persist the new config and reschedule notifications.
  Future<void> update(ScheduleConfig config) async {
    state = config;
    await _db.saveConfig(config);
    try {
      await _reminders.apply(config);
    } on Object catch (e) {
      debugPrint('reminder reschedule failed: $e');
    }
  }
}

/// Bumped on every record change (save/delete from any screen). Gallery and
/// Export listen and reload: [HomeShell] keeps all tabs alive in an
/// IndexedStack, so their one-time `initState` load would otherwise stay
/// frozen at the snapshot from app launch (e.g. "No photos captured yet"
/// right after a capture).
final recordsVersionProvider = StateProvider<int>((ref) => 0);

/// Loads and mutates a single day's record, one controller per date.
///
/// Deliberately NOT autoDispose: every consumer uses `ref.read(...notifier)`
/// (none watch it), so an autoDispose controller would have zero listeners and
/// be disposed mid-`await` inside `save`/`load`/`delete` — the `state = ...`
/// after the `await` then throws `Bad state: ... after dispose was called`.
/// A per-date family is fine to keep for the session (tiny, and never observed).
final dayControllerProvider =
    StateNotifierProvider.family<DayController, DailyRecord, String>((ref, date) {
  final db = ref.watch(databaseProvider);
  return DayController(db, date);
});

class DayController extends StateNotifier<DailyRecord> {
  DayController(this._db, this._date)
      : super(DailyRecord(date: _date, weather: const Weather()));
  final Database _db;
  final String _date;

  Future<DailyRecord> load() async {
    state = await _db.getDay(_date);
    return state;
  }

  Future<void> save(DailyRecord record) async {
    await _db.saveDay(record);
    state = record;
  }

  Future<void> delete() async {
    await _db.deleteDay(_date);
    state = DailyRecord(date: _date, weather: const Weather());
  }
}
