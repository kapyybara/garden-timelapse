/// Structured weather form fields for a daily note. All optional.
class Weather {
  final String? condition; // sunny, partly-cloudy, cloudy, rainy, foggy, storm, snow, other
  final double? temperatureC;
  final int? humidity; // 0-100
  final String? wind;

  const Weather({this.condition, this.temperatureC, this.humidity, this.wind});

  bool get isAnySet =>
      (condition != null && condition!.isNotEmpty) ||
      temperatureC != null ||
      (humidity != null && humidity! > 0) ||
      (wind != null && wind!.isNotEmpty);

  Map<String, dynamic> toRow() => {
        'condition': condition,
        'temperatureC': temperatureC,
        'humidity': humidity,
        'wind': wind,
      };

  static Weather fromRow(Map<String, dynamic> row) => Weather(
        condition: row['condition'] as String?,
        temperatureC: (row['temperatureC'] as num?)?.toDouble(),
        humidity: row['humidity'] as int?,
        wind: row['wind'] as String?,
      );

  /// A single-line summary used for video overlays.
  String get shortLabel {
    final parts = <String>[];
    if (condition != null && condition!.isNotEmpty) parts.add(condition!);
    if (temperatureC != null) parts.add('${temperatureC!.toStringAsFixed(0)}°C');
    if (humidity != null && humidity! > 0) parts.add('💧$humidity%');
    if (wind != null && wind!.isNotEmpty) parts.add('💨$wind');
    return parts.join(' · ');
  }
}
