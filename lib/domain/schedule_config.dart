/// User-configurable reminder schedule.
class ScheduleConfig {
  final bool enabled;
  final int shot1Hour;
  final int shot1Minute;
  final bool shot2Enabled;
  final int shot2Hour;
  final int shot2Minute;

  const ScheduleConfig({
    this.enabled = false,
    this.shot1Hour = 7,
    this.shot1Minute = 0,
    this.shot2Enabled = true,
    this.shot2Hour = 20,
    this.shot2Minute = 0,
  });

  String get shot1Label =>
      '${shot1Hour.toString().padLeft(2, '0')}:${shot1Minute.toString().padLeft(2, '0')}';
  String get shot2Label =>
      '${shot2Hour.toString().padLeft(2, '0')}:${shot2Minute.toString().padLeft(2, '0')}';

  ScheduleConfig copyWith({
    bool? enabled,
    int? shot1Hour,
    int? shot1Minute,
    bool? shot2Enabled,
    int? shot2Hour,
    int? shot2Minute,
  }) =>
      ScheduleConfig(
        enabled: enabled ?? this.enabled,
        shot1Hour: shot1Hour ?? this.shot1Hour,
        shot1Minute: shot1Minute ?? this.shot1Minute,
        shot2Enabled: shot2Enabled ?? this.shot2Enabled,
        shot2Hour: shot2Hour ?? this.shot2Hour,
        shot2Minute: shot2Minute ?? this.shot2Minute,
      );

  Map<String, dynamic> toRow() => {
        'enabled': enabled ? 1 : 0,
        'shot1Hour': shot1Hour,
        'shot1Minute': shot1Minute,
        'shot2Enabled': shot2Enabled ? 1 : 0,
        'shot2Hour': shot2Hour,
        'shot2Minute': shot2Minute,
      };

  static ScheduleConfig fromRow(Map<String, dynamic> row) => ScheduleConfig(
        enabled: (row['enabled'] as int) == 1,
        shot1Hour: row['shot1Hour'] as int,
        shot1Minute: row['shot1Minute'] as int,
        shot2Enabled: (row['shot2Enabled'] as int) == 1,
        shot2Hour: row['shot2Hour'] as int,
        shot2Minute: row['shot2Minute'] as int,
      );
}
