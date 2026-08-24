import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/schedule_config.dart';
import '../state/providers.dart';
import 'app_theme.dart';

/// Configure the daily reminder schedule (on/off, shot 1 / shot 2 times)
/// and manage notification + exact-alarm permissions.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  ScheduleConfig? _config;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cfg = await ref
        .read(scheduleControllerProvider.notifier)
        .load();
    if (!mounted) return;
    setState(() => _config = cfg);
  }

  Future<void> _update(ScheduleConfig next) async {
    // If enabling, request permissions first.
    if (next.enabled && !_config!.enabled) {
      await _requestPerms();
    }
    setState(() => _config = next);
    setState(() => _busy = true);
    await ref.read(scheduleControllerProvider.notifier).update(next);
    if (!mounted) return;
    setState(() => _busy = false);
  }

  Future<void> _requestPerms() async {
    // requestPermissions() also asks for exact alarms on Android.
    final reminders = ref.read(reminderServiceProvider);
    await reminders.requestPermissions();
  }

  Future<TimeOfDay> _pickTime(BuildContext context, TimeOfDay initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Pick reminder time',
    );
    return picked ?? initial;
  }

  TimeOfDay _t(ScheduleConfig c, {required bool second}) {
    return TimeOfDay(
      hour: second ? c.shot2Hour : c.shot1Hour,
      minute: second ? c.shot2Minute : c.shot1Minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _config;
    if (c == null) {
      return const Scaffold(
          body: Center(
              child: CircularProgressIndicator(color: AppTheme.accentColor)));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Master toggle
          _Card(
            child: SwitchListTile(
              title: const Text('Daily capture reminders'),
              subtitle: Text(
                c.enabled
                    ? 'On — remind you at ${c.shot1Label}'
                        '${c.shot2Enabled ? ' and ${c.shot2Label}' : ''}'
                    : 'Off',
                style: const TextStyle(color: AppTheme.mutedColor),
              ),
              value: c.enabled,
              activeThumbColor: AppTheme.accentColor,
              onChanged: (v) => _update(c.copyWith(enabled: v)),
            ),
          ),
          const SizedBox(height: 16),

          // Shot 1 time
          _Card(
            child: _TimeRow(
              label: 'Shot 1 (morning)',
              time: _t(c, second: false),
              enabled: true,
              onPick: () async {
                final t = await _pickTime(context, _t(c, second: false));
                _update(c.copyWith(shot1Hour: t.hour, shot1Minute: t.minute));
              },
            ),
          ),
          const SizedBox(height: 12),

          // Shot 2 toggle + time
          _Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Shot 2 (evening)'),
                  value: c.shot2Enabled,
                  activeThumbColor: AppTheme.accentColor,
                  onChanged: (v) => _update(c.copyWith(shot2Enabled: v)),
                ),
                if (c.shot2Enabled)
                  _TimeRow(
                    label: 'Shot 2 time',
                    time: _t(c, second: true),
                    enabled: true,
                    onPick: () async {
                      final t = await _pickTime(context, _t(c, second: true));
                      _update(
                          c.copyWith(shot2Hour: t.hour, shot2Minute: t.minute));
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status / permissions
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: AppTheme.accentColor),
                    SizedBox(width: 8),
                    Text('How it works',
                        style: TextStyle(
                            color: AppTheme.mutedColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '• A notification fires at each time so you can open the app and capture.\n'
                  '• On Android, exact-time reminders need the "Alarms & reminders" permission.\n'
                  '• On iOS, notification permission is requested when you turn reminders on.',
                  style: TextStyle(color: AppTheme.mutedColor, fontSize: 13, height: 1.5),
                ),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.accentColor)),
                        SizedBox(width: 8),
                        Text('Saving…',
                            style: TextStyle(color: AppTheme.mutedColor)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow(
      {required this.label, required this.time, required this.enabled, this.onPick});
  final String label;
  final TimeOfDay time;
  final bool enabled;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppTheme.textColor)),
        ),
        InkWell(
          onTap: onPick,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.accentColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 18, color: AppTheme.accentColor),
                const SizedBox(width: 8),
                Text(
                  DateFormat('HH:mm').format(
                      DateTime(2020, 1, 1, time.hour, time.minute)),
                  style: const TextStyle(
                      color: AppTheme.textColor, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
