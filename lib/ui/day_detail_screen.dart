import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/daily_record.dart';
import '../domain/shot.dart';
import '../state/providers.dart';
import 'app_theme.dart';
import 'note_screen.dart';

/// Shows one day: its photo(s), note, and actions (edit note, capture a
/// missing shot = backfill, delete day).
class DayDetailScreen extends ConsumerStatefulWidget {
  const DayDetailScreen({super.key, required this.date});
  final String date;

  @override
  ConsumerState<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends ConsumerState<DayDetailScreen> {
  DailyRecord? _record;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final record = await db.getDay(widget.date);
    if (!mounted) return;
    setState(() {
      _record = record;
      _loading = false;
    });
  }

  /// Capture the next missing slot for this day (backfill).
  Future<void> _backfill() async {
    final record = _record;
    if (record == null) return;
    final slot = ref
        .read(photoStoreProvider)
        .nextSlot(hasSlot1: record.shot1 != null, hasSlot2: record.shot2 != null);
    if (slot == null) {
      _snack('Both shots already captured for this day.');
      return;
    }
    try {
      final lenses = await availableCameras();
      final cam = lenses.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => lenses.first,
      );
      final controller =
          CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await controller.initialize();
      final photo = await controller.takePicture();
      await controller.dispose();

      final bytes = await File(photo.path).readAsBytes();
      final path = await ref.read(photoStoreProvider).write(widget.date, slot, bytes);
      final shot = Shot(path: path, takenAt: DateTime.now(), zoom: 1.0);

      var updated = record;
      if (slot == '1') {
        updated = DailyRecord(
          date: widget.date,
          shot1: shot,
          shot2: record.shot2,
          note: record.note,
          weather: record.weather,
        );
      } else {
        updated = DailyRecord(
          date: widget.date,
          shot1: record.shot1,
          shot2: shot,
          note: record.note,
          weather: record.weather,
        );
      }
      await ref.read(dayControllerProvider(widget.date).notifier).save(updated);
      if (!mounted) return;
      setState(() => _record = updated);
      _snack('Shot ${slot == '1' ? 1 : 2} captured.');
    } on Exception catch (e) {
      _snack('Capture failed: $e');
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this day?'),
        content: const Text('This removes the photos and note for this day. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(dayControllerProvider(widget.date).notifier).delete();
    if (!mounted) return;
    setState(() {
      _record = null;
    });
    _snack('Day deleted');
    // Pop if there is nothing left to show.
    final r = await ref.read(databaseProvider).getDay(widget.date);
    if (r.shot1 == null && r.shot2 == null && r.note.isEmpty) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.cardColor));
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final title =
        DateFormat('EEEE, d MMMM yyyy').format(DateTime.parse(widget.date));
    final canBackfill =
        r != null && (r.shot1 == null || r.shot2 == null);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (canBackfill)
            IconButton(
              icon: const Icon(Icons.add_a_photo_outlined),
              tooltip: 'Capture a missing shot',
              onPressed: _backfill,
            ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit note',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => NoteScreen(date: widget.date)),
              ).then((_) => _load());
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete day',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentColor))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Photos
                if (r == null || (!r.hasAnyShot))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            size: 44, color: AppTheme.mutedColor),
                        const SizedBox(height: 12),
                        const Text('No photos yet for this day',
                            style: TextStyle(color: AppTheme.mutedColor)),
                        if (canBackfill) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Capture now'),
                            onPressed: _backfill,
                          ),
                        ],
                      ],
                    ),
                  ),
                if (r?.shot1 != null && File(r!.shot1!.path).existsSync()) ...[
                  _ShotCard(label: 'Shot 1', shot: r.shot1!),
                  const SizedBox(height: 12),
                ],
                if (r?.shot2 != null && File(r!.shot2!.path).existsSync()) ...[
                  _ShotCard(label: 'Shot 2', shot: r.shot2!),
                  const SizedBox(height: 12),
                ],

                // Weather
                const SizedBox(height: 8),
                if (r != null && r.weather.isAnySet) ...[
                  _Card(
                    icon: Icons.wb_sunny_outlined,
                    title: 'Weather',
                    child: Text(
                      r.weather.shortLabel.isEmpty
                          ? '—'
                          : r.weather.shortLabel,
                      style: const TextStyle(color: AppTheme.textColor),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Note
                _Card(
                  icon: Icons.edit_note,
                  title: 'Note',
                  child: Text(
                    (r?.note.trim().isEmpty ?? true)
                        ? 'No note yet'
                        : r!.note,
                    style: TextStyle(
                      color: (r?.note.trim().isEmpty ?? true)
                          ? AppTheme.mutedColor
                          : AppTheme.textColor,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card(
      {required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.accentColor),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.mutedColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ShotCard extends StatelessWidget {
  const _ShotCard({required this.label, required this.shot});
  final String label;
  final Shot shot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.mutedColor, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                DateFormat('d MMM · HH:mm').format(shot.takenAt),
                style: const TextStyle(color: AppTheme.mutedColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(File(shot.path), fit: BoxFit.fitWidth),
          ),
        ],
      ),
    );
  }
}
