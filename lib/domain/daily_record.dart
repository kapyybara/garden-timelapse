import 'shot.dart';
import 'weather.dart';

/// One entry per calendar day in the timelapse.
class DailyRecord {
  /// 'YYYY-MM-DD'
  final String date;
  final Shot? shot1;
  final Shot? shot2;
  final String note;
  final Weather weather;

  const DailyRecord({
    required this.date,
    this.shot1,
    this.shot2,
    this.note = '',
    required this.weather,
  });

  /// Derives display status from captured shots.
  String get status {
    if (shot1 != null && shot2 != null) return 'completed';
    if (shot1 != null || shot2 != null) return 'partial';
    return 'missed';
  }

  bool get hasAnyShot => shot1 != null || shot2 != null;

  Map<String, dynamic> toRow() => {
        'date': date,
        'shot1Path': shot1?.path,
        'shot1TakenAt': shot1?.takenAt.toIso8601String(),
        'shot1Zoom': shot1?.zoom,
        'shot1Width': shot1?.width,
        'shot1Height': shot1?.height,
        'shot2Path': shot2?.path,
        'shot2TakenAt': shot2?.takenAt.toIso8601String(),
        'shot2Zoom': shot2?.zoom,
        'shot2Width': shot2?.width,
        'shot2Height': shot2?.height,
        'note': note,
        'weatherCondition': weather.condition,
        'weatherTemperatureC': weather.temperatureC,
        'weatherHumidity': weather.humidity,
        'weatherWind': weather.wind,
      };

  static DailyRecord fromRow(Map<String, dynamic> row) {
    Shot? shotFrom(String p, String t, String z, String w, String h) {
      final path = row[p] as String?;
      if (path == null) return null;
      return Shot(
        path: path,
        takenAt: DateTime.parse(row[t] as String),
        zoom: (row[z] as num?)?.toDouble() ?? 1.0,
        width: row[w] as int?,
        height: row[h] as int?,
      );
    }

    return DailyRecord(
      date: row['date'] as String,
      shot1: shotFrom('shot1Path', 'shot1TakenAt', 'shot1Zoom', 'shot1Width', 'shot1Height'),
      shot2: shotFrom('shot2Path', 'shot2TakenAt', 'shot2Zoom', 'shot2Width', 'shot2Height'),
      note: row['note'] as String? ?? '',
      weather: Weather(
        condition: row['weatherCondition'] as String?,
        temperatureC: (row['weatherTemperatureC'] as num?)?.toDouble(),
        humidity: row['weatherHumidity'] as int?,
        wind: row['weatherWind'] as String?,
      ),
    );
  }
}
