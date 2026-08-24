import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../domain/daily_record.dart';
import '../services/timelapse_exporter.dart';
import '../state/providers.dart';
import 'app_theme.dart';

/// Build + run a timelapse video from the captured days.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _hasPhotos = false;

  // Options
  double _frameSeconds = 1.0;
  bool _useBothShots = false;
  bool _burnDate = true;
  bool _burnNote = false;
  DayRange? _range; // selected time range
  List<DailyRecord> _records = [];
  final List<DailyRecord> _allRecords = [];

  bool _exporting = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    // Load all records in a wide window (last 4 years).
    final now = DateTime.now();
    final start = DateFormat('yyyy-MM-dd').format(
        now.subtract(const Duration(days: 365 * 4)));
    final end = DateFormat('yyyy-MM-dd').format(now);
    final records = await db.getDaysInRange(start, end);
    if (!mounted) return;
    setState(() {
      _allRecords
        ..clear()
      ..addAll(records);
      _records = List.of(_allRecords);
      _hasPhotos = _allRecords.any((r) => r.hasAnyShot);
    });
  }

  void _setRange(DayRange range) {
    setState(() {
      _range = range;
      // Filter records to the selected month (or all).
      if (range == DayRange.all) {
        _records = List.of(_allRecords);
      } else {
        final now = DateTime.now();
        int monthOffset = 0;
        switch (range) {
          case DayRange.last1:
            monthOffset = 1;
            break;
          case DayRange.last3:
            monthOffset = 3;
            break;
          case DayRange.last6:
            monthOffset = 6;
            break;
          case DayRange.last12:
            monthOffset = 12;
            break;
          default:
            monthOffset = 0;
        }
        final from = now.subtract(Duration(days: 30 * monthOffset));
        _records = _allRecords
            .where((r) => DateTime.parse(r.date).isAfter(from))
            .toList();
      }
    });
  }

  Future<void> _export() async {
    final records = _records.where((r) => r.hasAnyShot).toList();
    if (records.isEmpty) {
      _snack('No photos in the selected range to export.');
      return;
    }
    setState(() {
      _exporting = true;
      _progress = 0.05;
      _error = null;
    });

    try {
      final dir = ref.read(appDirProvider);
      final stamp =
          DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outPath =
          p.join(dir.path, 'exports', 'timelapse_$stamp.mp4');
      final outDir = Directory(p.dirname(outPath));
      if (!outDir.existsSync()) await outDir.create(recursive: true);

      final exporter = TimelapseExporter(
        frameSeconds: _frameSeconds,
        useBothShots: _useBothShots,
        burnDate: _burnDate,
        burnNote: _burnNote,
      );

      // Run export on a background isolate to keep UI responsive.
      final result = await exporter.export(records, outPath);

      if (!mounted) return;
      if (result.success) {
        setState(() {
          _exporting = false;
          _progress = 1.0;
        });
        _showResult(outPath);
      } else {
        setState(() {
          _exporting = false;
          _error = result.message;
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _exporting = false;
        _error = 'Export failed: $e';
      });
    }
  }

  void _showResult(String path) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.accentColor, size: 56),
            const SizedBox(height: 12),
            const Text('Timelapse ready!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(path,
                style: const TextStyle(color: AppTheme.mutedColor, fontSize: 12)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.file_copy_outlined),
                    label: const Text('Copy to gallery'),
                    onPressed: () async {
                      await _copyToGallery(path);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                    onPressed: () async {
                      await Share.shareXFiles(
                        [XFile(path)],
                        subject: 'My garden timelapse',
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToGallery(String path) async {
    // A real build would use MediaStore (Android) / PHPicker (iOS).
    // Here we just report that the file is available in app storage and
    // offer to share it.
    _snack('Video saved to app storage. Use Share to move it out.');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.cardColor));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export timelapse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _exporting ? null : _load,
          ),
        ],
      ),
      body: !_hasPhotos
          ? _EmptyState(
              onReload: _load,
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Range
                const _SectionLabel('Time range'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in DayRange.values)
                      ChoiceChip(
                        label: Text(_label(r)),
                        selected: _range == r,
                        selectedColor: AppTheme.accentColor,
                        onSelected: (_) => _setRange(r),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Frame duration
                const _SectionLabel('Speed (seconds per day)'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _frameSeconds,
                        min: 0.2,
                        max: 3.0,
                        divisions: 28,
                        label: '${_frameSeconds.toStringAsFixed(1)}s/day',
                        onChanged: (v) => setState(() => _frameSeconds = v),
                      ),
                    ),
                    SizedBox(
                      width: 70,
                      child: Text(
                        '${_frameSeconds.toStringAsFixed(1)}s',
                        style: const TextStyle(
                            color: AppTheme.textColor,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),

                // Use both shots
                SwitchListTile(
                  title: const Text('Use both daily shots'),
                  subtitle: const Text(
                      'Alternates morning + evening photos for more motion'),
                  value: _useBothShots,
                  activeThumbColor: AppTheme.accentColor,
                  onChanged: (v) => setState(() => _useBothShots = v),
                ),
                const Divider(),

                // Overlays
                const _SectionLabel('Overlays'),
                const SizedBox(height: 4),
                SwitchListTile(
                  title: const Text('Burn in date / title'),
                  value: _burnDate,
                  activeThumbColor: AppTheme.accentColor,
                  onChanged: (v) => setState(() => _burnDate = v),
                ),
                SwitchListTile(
                  title: const Text('Burn in a note line'),
                  value: _burnNote,
                  activeThumbColor: AppTheme.accentColor,
                  onChanged: (v) => setState(() => _burnNote = v),
                ),

                const SizedBox(height: 12),

                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.video_library, color: AppTheme.accentColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_records.where((r) => r.hasAnyShot).length} day(s) '
                          '× ${_frameSeconds.toStringAsFixed(1)}s ≈ '
                          '${(_records.where((r) => r.hasAnyShot).length * _frameSeconds).toStringAsFixed(0)}s video',
                          style: const TextStyle(color: AppTheme.textColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Export button
                if (_exporting) ...[
                  LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: AppTheme.surfaceColor,
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text('Rendering video…',
                        style: TextStyle(color: AppTheme.mutedColor)),
                  ),
                ] else
                  FilledButton.icon(
                    onPressed: _export,
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: const Text('Render timelapse'),
                  ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Text('Export failed',
                                style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _error!,
                          style: const TextStyle(
                              color: AppTheme.textColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

enum DayRange { last1, last3, last6, last12, all }

String _label(DayRange r) {
  switch (r) {
    case DayRange.last1:
      return 'Last month';
    case DayRange.last3:
      return '3 months';
    case DayRange.last6:
      return '6 months';
    case DayRange.last12:
      return '1 year';
    case DayRange.all:
      return 'All';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
          color: AppTheme.mutedColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onReload});
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 56, color: AppTheme.mutedColor),
            const SizedBox(height: 16),
            const Text('No photos captured yet',
                style: TextStyle(
                    color: AppTheme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
                'Take some daily photos in the Camera tab first.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.mutedColor)),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: onReload,
            ),
          ],
        ),
      ),
    );
  }
}
