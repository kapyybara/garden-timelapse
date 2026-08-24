# garden_timelapse

A daily photo timelapse app for your garden: take 1–2 photos a day
(morning + evening) from the same spot, and the app turns the year of
shots into a timelapse video.

Local-only in v1 — no account, no cloud.

## Features

- **Guided capture** — live camera preview with a 3×3 grid reticle,
  a date chip, and slot indicators (shot 1 / shot 2)
- **Onion-skin ghost** — the previous day's photo is overlaid at
  adjustable opacity so you can match your framing
- **FOV matching** — the camera opens at the last shot's zoom level
  (persisted per shot), so consecutive days line up
- **Per-day note & weather** — a short note and a weather summary for
  each day
- **Calendar gallery** — a month grid showing which days have shots;
  tap a day to see its photos, note, and weather
- **Reminders** — local notifications at your chosen times (default
  07:00 / 20:00) via `flutter_local_notifications`
- **Timelapse export** — ffmpeg (via `ffmpeg_kit_flutter`) stitches the
  days into a vertical 1080×1920 MP4 with adjustable speed, optional
  both-shots mode, and optional burned-in title/note lines; copy to
  gallery or share

## Stack

- Flutter 3.x (Dart 3), Riverpod for state, `sqflite` for storage,
  `path_provider` for files, `camera` for capture
- Android 24+ / iOS 12+

## Build

```bash
flutter pub get
flutter run            # debug, on a connected device/emulator
flutter build apk      # or: flutter build ios
```

### Note on `ffmpeg_kit_flutter` (vendored, patched)

`ffmpeg_kit_flutter` 6.0.3 (latest on pub.dev) still references the
v1-embedding `PluginRegistry.Registrar`, which modern Flutter removed,
so it no longer compiles. We keep a patched copy under `local_plugins/`
(v1 code stripped, otherwise identical) wired in via `dependency_overrides`
in `pubspec.yaml`. Its native AAR also only resolves from the Aliyun
maven mirror (the arthenica repo is dead) — both fixes live in
`local_plugins/ffmpeg_kit_flutter/android/build.gradle`.

The Android build is the LGPL "small" ffmpeg (no `libx264`, no
libfreetype), so the exporter uses the `h264_mediacodec` hardware
encoder on Android and probes for `drawtext` support at runtime —
see `lib/services/timelapse_exporter.dart`.

TODO: drop the override when arthenica ships a Flutter-compatible
release.

## Project layout

```
lib/
  data/          sqflite database + photo file store
  domain/        records (daily record, shot, weather, schedule)
  services/      reminders, timelapse exporter
  state/         Riverpod providers + controllers
  ui/            screens (camera, gallery, day detail, note,
                 reminders, export) + theme + grid reticle
local_plugins/   vendored patched ffmpeg_kit_flutter
test/            unit tests
```
# garden-timelapse
