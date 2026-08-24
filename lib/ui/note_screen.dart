import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/daily_record.dart';
import '../domain/weather.dart';
import '../state/providers.dart';
import 'app_theme.dart';

const _conditions = [
  'Sunny',
  'Partly cloudy',
  'Cloudy',
  'Rainy',
  'Foggy',
  'Storm',
  'Snow',
  'Other',
];

/// The per-day note editor: optional weather form + free text.
/// All fields optional; saving requires at least one non-empty field.
class NoteScreen extends ConsumerStatefulWidget {
  const NoteScreen({super.key, required this.date});
  final String date;

  @override
  ConsumerState<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends ConsumerState<NoteScreen> {
  late final _noteCtrl = TextEditingController();
  late final _tempCtrl = TextEditingController();
  late final _humCtrl = TextEditingController();
  late final _windCtrl = TextEditingController();
  String _condition = _conditions.first;
  bool _hasCondition = false;

  bool get _dirty =>
      _noteCtrl.text.trim().isNotEmpty ||
      _tempCtrl.text.trim().isNotEmpty ||
      _humCtrl.text.trim().isNotEmpty ||
      _windCtrl.text.trim().isNotEmpty ||
      _hasCondition;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final record = await ref.read(dayControllerProvider(widget.date).notifier).load();
    if (!mounted) return;
    setState(() {
      _noteCtrl.text = record.note;
      final w = record.weather;
      _tempCtrl.text = w.temperatureC?.toStringAsFixed(1) ?? '';
      _humCtrl.text = (w.humidity ?? 0).toString();
      _windCtrl.text = w.wind ?? '';
      _condition = w.condition ?? _conditions.first;
      _hasCondition = (w.condition != null && w.condition!.isNotEmpty);
    });
  }

  Future<void> _save() async {
    final condition = _hasCondition ? _condition : null;
    double? temp;
    final t = double.tryParse(_tempCtrl.text.trim());
    if (t != null) temp = t;

    final weather = Weather(
      condition: condition,
      temperatureC: temp,
      humidity: int.tryParse(_humCtrl.text.trim())?.clamp(0, 100),
      wind: _windCtrl.text.trim().isEmpty ? null : _windCtrl.text.trim(),
    );

    final note = _noteCtrl.text.trim();

    // Require at least one field.
    if (!weather.isAnySet && note.isEmpty) {
      _snack('Add at least a note or one weather field.');
      return;
    }

    final db = ref.read(databaseProvider);
    var record = await db.getDay(widget.date);
    record = DailyRecord(
      date: widget.date,
      shot1: record.shot1,
      shot2: record.shot2,
      note: note,
      weather: weather,
    );
    await ref.read(dayControllerProvider(widget.date).notifier).save(record);
    // Tell Gallery/Export to reload (their one-time initState load is
    // stale while the shell keeps the tabs alive).
    ref.read(recordsVersionProvider.notifier).state += 1;
    if (!mounted) return;
    _snack('Note saved');
    Navigator.pop(context);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.cardColor));
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _tempCtrl.dispose();
    _humCtrl.dispose();
    _windCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily note'),
        actions: [
          FilledButton.tonal(
            onPressed: _dirty ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('Weather (optional)'),
          const SizedBox(height: 12),
          // Condition dropdown
          DropdownButtonFormField<String>(
            // Re-key on value change: the form field only reads initialValue
            // at first build, and the record is loaded asynchronously.
            key: ValueKey<String>(_condition),
            initialValue: _condition,
            items: [
              for (final c in _conditions)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            decoration: const InputDecoration(
              labelText: 'Condition',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() {
              _condition = v ?? _conditions.first;
              _hasCondition = true;
            }),
          ),
          const SizedBox(height: 16),
          // Temperature + humidity row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _tempCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true, decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Temp (°C)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _humCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Humidity %',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wind
          TextFormField(
            controller: _windCtrl,
            decoration: const InputDecoration(
              labelText: 'Wind (e.g. light, from W)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 28),
          const _SectionLabel('Notes'),
          const SizedBox(height: 12),
          // Free text
          TextField(
            controller: _noteCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'What happened in the garden today?',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.mutedColor,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: .8,
      ),
    );
  }
}
