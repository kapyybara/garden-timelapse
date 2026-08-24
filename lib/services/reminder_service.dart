import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule_config.dart';

/// Schedules the daily reminder notifications for the configured shot times.
class ReminderService {
  static const _channelId = 'daily-reminders';
  static const _channelName = 'Daily capture reminders';
  static const _channelDesc =
      'Reminds you to take the day\'s timelapse photo(s).';

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: _onTap,
    );
    if (Platform.isAndroid) {
      await _createChannel();
    }
  }

  Future<void> _createChannel() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    );
    await android?.createNotificationChannel(channel);
  }

  /// Request notification (and, on Android, exact-alarm) permission.
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final notified = await android?.areNotificationsEnabled() ?? false;
      if (!notified) {
        await android?.requestNotificationsPermission();
      }
      // Exact alarms: best-effort; failure only degrades precision.
      try {
        await android?.requestExactAlarmsPermission();
      } on Object {
        // ignore — reminders still work inexact.
      }
      return true;
    }
    // iOS: alert/badge/sound permission is requested at initialize time via
    // DarwinInitializationSettings; nothing further to ask here.
    return true;
  }

  /// Reschedule all reminders to match [config]. Cancels existing first.
  Future<void> apply(ScheduleConfig config) async {
    await _init();
    await _plugin.cancelAll();

    if (!config.enabled) return;

    final zone = tz.local;
    var now = tz.TZDateTime.now(zone);

    void schedule(int id, int hour, int minute, String title, String body) {
      var scheduled = tz.TZDateTime(zone, now.year, now.month, now.day, hour, minute);
      if (!scheduled.isAfter(tz.TZDateTime.now(zone))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }

    schedule(1, config.shot1Hour, config.shot1Minute,
        'Time to capture shot 1', 'Open Garden Timelapse and take today\'s first photo.');
    if (config.shot2Enabled) {
      schedule(2, config.shot2Hour, config.shot2Minute,
          'Time to capture shot 2', 'Open Garden Timelapse and take today\'s evening photo.');
    }
  }

  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  void _onTap(NotificationResponse response) {
    // Deep link: the app's home listens to this stream to open the camera.
    if (!_taps.isClosed) _taps.add(response);
  }

  final _taps = StreamController<NotificationResponse>.broadcast();
  Stream<NotificationResponse> get taps => _taps.stream;
}
