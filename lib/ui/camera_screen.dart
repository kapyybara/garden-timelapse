import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../domain/daily_record.dart';
import '../domain/shot.dart';
import '../state/providers.dart';
import 'app_theme.dart';
import 'grid_reticle.dart';
import 'note_screen.dart';

/// Today's date string in local time, 'YYYY-MM-DD'.
String todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// The camera capture screen.
///
/// - Live preview with a 3×3 grid reticle
/// - Onion-skin (ghost) of the most recent prior day's photo at adjustable
///   opacity so the user can match the same field of view
/// - On open, the zoom is set to the last shot's zoom (FOV matching)
/// - Capture button saves into the next free slot (shot1 / shot2) for today
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> {
  CameraController? _controller;
  bool _ready = false;
  bool _initializing = false;
  String? _error;

  // Ghost state
  DailyRecord? _ghost;
  double _ghostOpacity = 0.35;
  bool _ghostVisible = true;

  final String _date = todayKey();
  String? _activeSlot; // '1' | '2' | null

  CameraDescription? _cam;
  List<CameraDescription> _lenses = [];

  /// Active camera zoom; camera 0.10.6 exposes no zoomLevel getter, so we
  /// track it here to persist it on the shot for future FOV matching.
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final lenses = await availableCameras();
      _lenses = lenses;
      // With camera permission denied (or on a camera-less device) this list
      // is empty — `lenses.first` would throw a StateError, which the
      // Exception-only handlers below can't catch, leaving the UI stuck on
      // "Loading camera…" forever with no way to retry.
      if (lenses.isEmpty) {
        if (!mounted) return;
        setState(() => _error = 'No camera available. Check that camera '
            'permission is granted, then tap Retry.');
        return;
      }
      _cam = lenses.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => lenses.first,
      );
      await _startCamera();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera not available: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _startCamera() async {
    setState(() {
      _error = null;
      _ready = false;
      _initializing = true;
    });
    final db = ref.read(databaseProvider);
    final photoStore = ref.read(photoStoreProvider);

    final today = await db.getDay(_date);
    final slot = photoStore.nextSlot(
      hasSlot1: today.shot1 != null,
      hasSlot2: today.shot2 != null,
    );
    _activeSlot = slot;

    // Ghost = most recent prior day with a shot.
    final prev = await db.previousShotDay(_date);
    _ghost = (prev?.shot1 != null) ? prev : null;

    final c = CameraController(
      _cam!,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = c;
    try {
      await c.initialize();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Camera init failed: $e';
        _initializing = false;
      });
      return;
    }
    if (!mounted) return;
    // FOV matching: reuse the last shot's zoom (clamped to a safe range;
    // camera 0.10.6 exposes no min/max zoom getters).
    _currentZoom = 1.0;
    final lastShot = _ghost?.shot1;
    if (lastShot != null && lastShot.zoom != 1.0) {
      final zoom = lastShot.zoom.clamp(1.0, 8.0);
      try {
        await c.setZoomLevel(zoom);
        _currentZoom = zoom;
      } on Exception {
        _currentZoom = 1.0;
      }
    }
    // These fields are plain state (not a ChangeNotifier), so without
    // setState the UI stays frozen on "Loading camera…" and the preview is
    // never shown — even once the controller is ready.
    setState(() {
      _ready = true;
      _initializing = false;
    });
  }

  Future<void> _capture() async {
    final c = _controller;
    final slot = _activeSlot;
    if (c == null || !c.value.isInitialized || slot == null) return;
    setState(() => _initializing = true);
    try {
      final photo = await c.takePicture();
      final bytes = await File(photo.path).readAsBytes();
      final path = await ref
          .read(photoStoreProvider)
          .write(_date, slot, bytes);

      // Build the updated record.
      final db = ref.read(databaseProvider);
      var record = await db.getDay(_date);
      final shot = Shot(
        path: path,
        takenAt: DateTime.now(),
        zoom: _currentZoom,
      );
      if (slot == '1') {
        record = DailyRecord(
          date: _date,
          shot1: shot,
          shot2: record.shot2,
          note: record.note,
          weather: record.weather,
        );
      } else {
        record = DailyRecord(
          date: _date,
          shot1: record.shot1,
          shot2: shot,
          note: record.note,
          weather: record.weather,
        );
      }
      await ref.read(dayControllerProvider(_date).notifier).save(record);

      if (!mounted) return;
      _showCaptureSheet(record);
    } on Exception catch (e) {
      if (!mounted) return;
      _toast('Capture failed: $e');
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  void _showCaptureSheet(DailyRecord record) {
    final nextSlot = ref
        .read(photoStoreProvider)
        .nextSlot(hasSlot1: record.shot1 != null, hasSlot2: record.shot2 != null);
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
            Text(
              'Photo captured!',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              nextSlot == null
                  ? 'Both shots done for today.'
                  : 'Shot ${nextSlot == '1' ? 1 : 2} saved — next: shot ${nextSlot == '1' ? 1 : 2}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.mutedColor),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: const Text('Add today\'s note'),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => NoteScreen(date: _date)));
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.cardColor));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview
          if (_ready && c != null)
            CameraPreview(c)
          else
            Container(
              color: AppTheme.bg,
              child: Center(
                child: _initializing
                    ? const CircularProgressIndicator(color: AppTheme.accentColor)
                    : Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                size: 48, color: AppTheme.mutedColor),
                            const SizedBox(height: 12),
                            Text(
                              _error ?? 'Loading camera…',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.mutedColor),
                            ),
                            // A retry is only useful once init has actually failed;
                            // while _initializing the spinner above is showing instead.
                            if (_error != null) ...[
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Retry'),
                                // Re-run full init (re-reads the lens list),
                                // not just _startCamera, which assumes _cam is set.
                                onPressed: _init,
                              ),
                            ],
                          ],
                        ),
                      ),
              ),
            ),

          // Grid reticle
          if (_ready) const Positioned.fill(child: GridReticle()),

          // Ghost overlay
          if (_ready && _ghostVisible && _ghost != null)
            Positioned.fill(
              child: _GhostImage(path: _ghost!.shot1!.path, opacity: _ghostOpacity),
            ),

          // Top bar: lens + date
          if (_ready)
            SafeArea(
              child: Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _ChipPill(
                      label: 'Day ${DateFormat('d MMM').format(DateTime.parse(_date))}',
                      icon: Icons.today,
                    ),
                    const Spacer(),
                    if (_ghost != null)
                      _ChipPill(
                        label: 'Ghost ${(_ghostOpacity * 100).round()}%',
                        icon: Icons.visibility,
                        onTap: () =>
                            setState(() => _ghostVisible = !_ghostVisible),
                      ),
                    if (_lenses.length > 1)
                      IconButton(
                        icon: const Icon(Icons.switch_camera),
                        color: AppTheme.textColor,
                        onPressed: () => _switchLens(),
                      ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          if (_ready)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ghost opacity slider
                      if (_ghost != null && _ghostVisible)
                        Row(
                          children: [
                            const Icon(Icons.opacity,
                                size: 20, color: AppTheme.mutedColor),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Slider(
                                value: _ghostOpacity,
                                min: 0.05,
                                max: 0.9,
                                label: '${(_ghostOpacity * 100).round()}%',
                                onChanged: (v) =>
                                    setState(() => _ghostOpacity = v),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // Slot indicator
                          Expanded(
                            child: _SlotIndicator(
                              has1: _activeSlot != '1',
                              has2: _activeSlot == null,
                              active: _activeSlot,
                            ),
                          ),
                          // Capture button
                          GestureDetector(
                            onTap: _initializing ? null : _capture,
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.accentColor,
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: .8),
                                    width: 4),
                              ),
                              child: _initializing
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: Colors.white))
                                  : const Icon(Icons.camera,
                                      color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Retake / backfill helper
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.refresh,
                                    color: AppTheme.textColor),
                                onPressed: _startCamera,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switchLens() async {
    if (_lenses.length < 2) return;
    final c = _controller;
    if (c == null) return;
    await c.dispose();
    _cam = _lenses.firstWhere(
      (l) => l.lensDirection != _cam!.lensDirection,
      orElse: () => _lenses.first,
    );
    await _startCamera();
  }
}

/// The onion-skin ghost: previous day's photo drawn at low opacity over preview.
class _GhostImage extends StatelessWidget {
  const _GhostImage({required this.path, required this.opacity});
  final String path;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (!File(path).existsSync()) return const SizedBox.shrink();
    return Opacity(
      opacity: opacity,
      child: Container(
        alignment: Alignment.center,
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppTheme.textColor),
            const SizedBox(width: 6),
            Text(label,
                style:
                    const TextStyle(color: AppTheme.textColor, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _SlotIndicator extends StatelessWidget {
  const _SlotIndicator({required this.has1, required this.has2, this.active});
  final bool has1;
  final bool has2;
  final String? active;

  @override
  Widget build(BuildContext context) {
    Color dot(bool done, bool isActive) =>
        done ? AppTheme.accentColor : (isActive ? AppTheme.warnColor : AppTheme.mutedColor);
    return Row(
      children: [
        _Dot(label: '1', color: dot(has1, active == '1')),
        const SizedBox(width: 10),
        _Dot(label: '2', color: dot(has2, active == '2')),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text('shot $label',
            style: const TextStyle(color: AppTheme.mutedColor, fontSize: 12)),
      ],
    );
  }
}
