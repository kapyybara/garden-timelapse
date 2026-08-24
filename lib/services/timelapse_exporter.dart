import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';

import '../domain/daily_record.dart';

class ExportResult {
  final bool success;
  final String? output;
  final String? message;
  const ExportResult({required this.success, this.output, this.message});
}

/// Builds an ffmpeg command and runs it to produce a timelapse video from a
/// set of daily records.
class TimelapseExporter {
  /// Seconds each day (or each frame) lasts in the final video.
  /// 1.0 = one second per frame, 0.5 = two frames per second.
  final double frameSeconds;
  final bool burnDate;
  final bool burnNote;
  final bool useBothShots;
  final int fps;
  final int width;
  final int height;

  const TimelapseExporter({
    this.frameSeconds = 1.0,
    this.burnDate = true,
    this.burnNote = false,
    this.useBothShots = false,
    this.fps = 30,
    this.width = 1080,
    this.height = 1920,
  });

  /// In-order image files to feed to ffmpeg, expanding each day into one
  /// (or two, if [useBothShots]) existing shot(s).
  List<String> resolveInputs(List<DailyRecord> records) {
    final inputs = <String>[];
    for (final r in records) {
      if (r.shot1 != null && File(r.shot1!.path).existsSync()) {
        inputs.add(r.shot1!.path);
      }
      if (useBothShots &&
          r.shot2 != null &&
          File(r.shot2!.path).existsSync()) {
        inputs.add(r.shot2!.path);
      }
    }
    return inputs;
  }

  /// Writes the ffmpeg `concat` demuxer list file and returns its path.
  Future<String> writeConcatList(List<String> inputs, String outPath) async {
    final path = '$outPath.list.txt';
    final sb = StringBuffer();
    for (final p in inputs) {
      sb.writeln("file '$p'");
      sb.writeln('duration $frameSeconds');
    }
    if (inputs.isNotEmpty) sb.writeln("file '${inputs.last}'");
    await File(path).writeAsString(sb.toString());
    return path;
  }

  /// Builds the full ffmpeg argument list for a timelapse video.
  ///
  /// The video codec is chosen per platform. The bundled `ffmpeg-kit-https`
  /// Android AAR is the LGPL build: it ships **without** `libx264` (so the
  /// x264-only `-crf`/`-preset` are unrecognised) and **without**
  /// libfreetype (so the `drawtext` filter is unavailable). Android therefore
  /// uses the hardware `h264_mediacodec` encoder instead; the iOS build does
  /// bundle libx264, so it keeps the x264 settings.
  List<String> buildArgs(
    String concatListPath,
    String outPath, {
    String? noteLine,
    bool drawtext = false,
  }) {
    final filters = <String>[
      'scale=$width:$height:force_original_aspect_ratio=decrease',
      'pad=$width:$height:(ow-iw)/2:(oh-ih)/2',
    ];
    if (drawtext) {
      if (burnDate) {
        filters.add(
            "drawtext=text='Garden Timelapse':fontcolor=white:fontsize=36:x=(w-tw)/2:y=h-90:box=1:boxcolor=black@0.5");
      }
      if (burnNote && noteLine != null && noteLine.trim().isNotEmpty) {
        final safe = noteLine
            .replaceAll("'", '')
            .replaceAll(':', ' ')
            .substring(0, noteLine.length > 40 ? 40 : noteLine.length);
        filters.add(
            "drawtext=text='$safe':fontcolor=white:fontsize=28:x=(w-tw)/2:y=44:box=1:boxcolor=black@0.4");
      }
    }

    final videoArgs = Platform.isAndroid
        // Hardware h264 encoder present in the Android LGPL build. The
        // x264-specific -crf / -preset options are not available here.
        ? ['-c:v', 'h264_mediacodec', '-b:v', '5M', '-pix_fmt', 'yuv420p']
        // libx264 is bundled in the iOS build.
        : [
            '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '23',
            '-preset', 'medium'
          ];

    return <String>[
      '-f', 'concat',
      '-safe', '0',
      '-i', concatListPath,
      '-vf', filters.join(','),
      '-r', '$fps',
      ...videoArgs,
      '-movflags', 'faststart',
      '-y',
      outPath,
    ];
  }

  /// Whether this ffmpeg build supports the `drawtext` filter (needs
  /// libfreetype, which the Android LGPL build omits). Cached per process.
  static bool? _drawtextCache;

  Future<bool> _drawtextAvailable() async {
    _drawtextCache ??= await _probeDrawtext();
    return _drawtextCache!;
  }

  Future<bool> _probeDrawtext() async {
    final session = await FFmpegKit.executeWithArguments(['-filters']);
    final out = (await session.getOutput()) ?? '';
    return out.contains('drawtext');
  }

  /// Runs the export end-to-end. Returns [ExportResult].
  Future<ExportResult> export(List<DailyRecord> records, String outPath) async {
    final inputs = resolveInputs(records);
    if (inputs.isEmpty) {
      return const ExportResult(
          success: false, message: 'No photos found to export.');
    }
    final listPath = await writeConcatList(inputs, outPath);
    final noteLine = records
        .where((r) => r.note.trim().isNotEmpty)
        .firstOrNull
        ?.note;
    // drawtext needs libfreetype, which the Android LGPL build omits. Probe
    // once per process and only request the filter when this build has it —
    // otherwise ffmpeg aborts with "Unknown filter" before writing a frame.
    final canDrawtext =
        (burnDate || burnNote) && await _drawtextAvailable();
    final args = buildArgs(listPath, outPath,
        noteLine: noteLine, drawtext: canDrawtext);

    final session = await FFmpegKit.executeWithArguments(args);
    final returnCode = await session.getReturnCode();
    final ok = ReturnCode.isSuccess(returnCode);
    if (ok) {
      return ExportResult(success: true, output: outPath);
    }
    final msg = (await session.getOutput()) ?? '';
    return ExportResult(success: false, message: 'ffmpeg failed:\n$msg');
  }
}
