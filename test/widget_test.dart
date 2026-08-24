// Pure-logic tests for the domain layer. These avoid platform channels
// (camera, sqflite, path_provider) so they run in a plain `flutter test`.

import 'package:flutter_test/flutter_test.dart';
import 'package:garden_timelapse/domain/daily_record.dart';
import 'package:garden_timelapse/domain/shot.dart';
import 'package:garden_timelapse/domain/weather.dart';

void main() {
  group('Weather.shortLabel', () {
    test('combines the set fields with a dot separator', () {
      const w = Weather(
        condition: 'rainy',
        temperatureC: 18.4,
        humidity: 80,
        wind: 'light, from W',
      );
      expect(
        w.shortLabel,
        'rainy · 18°C · 💧80% · 💨light, from W',
      );
    });

    test('is empty when nothing is set', () {
      const w = Weather();
      expect(w.shortLabel, isEmpty);
      expect(w.isAnySet, isFalse);
    });

    test('includes only the fields that are set', () {
      const w = Weather(condition: 'sunny', temperatureC: 30);
      expect(w.shortLabel, 'sunny · 30°C');
      expect(w.isAnySet, isTrue);
    });
  });

  group('DailyRecord.status', () {
    test('missed when no shots', () {
      const r = DailyRecord(date: '2026-08-23', weather: Weather());
      expect(r.status, 'missed');
      expect(r.hasAnyShot, isFalse);
    });

    test('partial when only one shot', () {
      final r = DailyRecord(
        date: '2026-08-23',
        shot1: Shot(path: '/a.jpg', takenAt: DateTime(2026, 8, 23)),
        weather: const Weather(),
      );
      expect(r.status, 'partial');
      expect(r.hasAnyShot, isTrue);
    });

    test('completed when both shots', () {
      final r = DailyRecord(
        date: '2026-08-23',
        shot1: Shot(path: '/a.jpg', takenAt: DateTime(2026, 8, 23)),
        shot2: Shot(path: '/b.jpg', takenAt: DateTime(2026, 8, 23)),
        weather: const Weather(),
      );
      expect(r.status, 'completed');
    });
  });

  group('DailyRecord.fromRow / toRow round-trip', () {
    test('round-trips a full record', () {
      final original = DailyRecord(
        date: '2026-08-23',
        shot1: Shot(
            path: '/a.jpg',
            takenAt: DateTime(2026, 8, 23, 7),
            zoom: 2.5,
            width: 1080,
            height: 1920),
        note: 'cloudy morning',
        weather: const Weather(condition: 'cloudy', temperatureC: 21),
      );
      final parsed = DailyRecord.fromRow(original.toRow());
      expect(parsed.date, original.date);
      expect(parsed.note, 'cloudy morning');
      expect(parsed.shot1?.path, '/a.jpg');
      expect(parsed.shot1?.zoom, 2.5);
      expect(parsed.weather.condition, 'cloudy');
      expect(parsed.weather.temperatureC, 21);
      expect(parsed.shot2, isNull);
    });

    test('returns null shots when paths are absent', () {
      final r = DailyRecord.fromRow({
        'date': '2026-08-23',
        'shot1Path': null,
        'shot2Path': null,
        'note': '',
      });
      expect(r.shot1, isNull);
      expect(r.shot2, isNull);
      expect(r.note, '');
    });
  });
}
