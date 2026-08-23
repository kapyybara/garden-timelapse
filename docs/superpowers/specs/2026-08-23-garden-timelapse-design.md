# Garden Timelapse App — Design Spec

Date: 2026-08-23
Status: Approved by user

## Overview

A cross-platform (Android + iOS) Flutter app for tracking garden change over time.
The app reminds the user to take 1–2 photos per day at customizable times
(default 07:00 and 20:00), uses an onion-skin (ghost) overlay in the camera
viewfinder so every shot has the same field of view (FOV), and lets the user
attach a daily note (weather form + free text). All daily photos are browsable
in a calendar gallery and can be exported as a timelapse video with optional
date/note text overlays.

**v1 scope:** local-only storage, no cloud, no backend.

## Confirmed decisions

| Question | Decision |
|---|---|
| Capture model | App sends a **notification reminder** at each configured time; user opens the app and captures manually (no background auto-capture) |
| Overlay | **Onion-skin (ghost)**: previous day's photo drawn at adjustable opacity over the live camera preview + grid reticle; previous shot's **zoom level** auto-applied so FOV matches |
| Note | Per-day: optional structured form (weather condition, temperature, humidity, wind) + free text; form is fully skippable |
| Playback | Calendar grid gallery + **timelapse video export** via ffmpeg (frame duration adjustable, optional date + note text burned in) |
| Platforms | **Android + iOS**, local photos only |
| Data | SQLite (sqflite), photos in app-scoped storage |

## Architecture

- **State management:** Riverpod
- **Storage:** sqflite (metadata), app-scoped photo files (`path_provider`)
- **Camera:** `camera` plugin — live preview + still capture, zoom
- **Video export:** `ffmpeg_kit_flutter` (native ffmpeg on both platforms)
- **Notifications:** `flutter_local_notifications`
- **Permission handling:** `permission_handler` (camera, notifications, exact alarm on Android)

Layering:

```
data/          -> DB access (DAOs), photo file storage
domain/        -> DailyRecord, Note, ScheduleConfig models + pure logic
features/
  camera/      -> viewfinder, ghost overlay, capture flow
  gallery/     -> calendar grid, day detail, backfill capture
  notes/       -> note form + free text
  reminders/   -> scheduling, permission flows
  export/      -> ffmpeg timelapse generation, share/save to gallery
ui/            -> shared widgets, theme
```

## Data model

### DailyRecord
- `date` (YYYY-MM-DD, primary key)
- `shot1`: path, takenAt (DateTime), zoom, width, height (nullable until captured)
- `shot2`: same fields, nullable (optional second daily shot)
- `note`: see below
- `status`: derived — completed / partial / missed (no photos)

### Note
- `text`: free text (may be empty)
- `weather`: enum (sunny, partly-cloudy, cloudy, rainy, foggy, storm, snow, other) — nullable
- `temperatureC`: double — nullable
- `humidity`: int 0–100 — nullable
- `wind`: string (e.g. "light, from W") — nullable
- All form fields optional; saving a note requires at least text or one field.

### ScheduleConfig
- `enabled`: bool
- `shot1Time`: TimeOfDay (default 07:00)
- `shot2Enabled`: bool (default true)
- `shot2Time`: TimeOfDay (default 20:00)

## Feature details

### 1. Camera + onion-skin
- Live preview with:
  - grid reticle (3×3)
  - ghost overlay: last captured photo (from the most recent prior day that has a shot) at user-adjustable opacity (slider, default ~35%), hideable
  - on open, camera **zoom is set to the last shot's zoom** so FOV matches without muscle memory
- Capture button → saves shot1 (or shot2 if shot1 already exists today; user can also explicitly choose which shot slot)
- After capture, jumps to that day's note screen (or gallery)
- Missed-day backfill: from a gallery day with no photos, "Capture now" opens the same flow (ghost uses the nearest prior day with photos)

### 2. Reminders
- On enabling schedule: request notification permission; Android: request exact-alarm permission (`SCHEDULE_EXACT_ALARM`), with graceful fallback + in-app banner if denied.
- Schedule one notification per shot time per day, with a deep link into the camera screen.
- Reschedule on config change; cancel all on disable.

### 3. Gallery
- Month calendar grid: each day shows dots for shot1/shot2; "missed" days visually distinct.
- Tap a day → day detail: photo(s) full screen, note display, edit note.
- Horizontal timeline strip (swipe) as an alternative view.

### 4. Timelapse export
- Input: all days in a selected range (default: all captured days).
- ffmpeg: sequence stills at adjustable frame duration (1s/day, 0.5s/day, 1 day per 2 frames), 30 fps, H.264.
- Optional burn-in overlays (toggleable, previewed): date text, note text (truncated to one line).
- If a day has shot1 + shot2, alternate them (toggle: "use both shots").
- Output: save to device gallery (MediaStore / Photos library) + share sheet.

### 5. Notes
- Form: weather dropdown, temperature, humidity, wind, free text.
- All fields optional; validate "at least one field non-empty" only on explicit save.
- Editable from day detail at any time.

## Error handling
- Missed reminder / uncaptured day → day shown as "missed"; can be backfilled any time (ghost overlay uses nearest prior captured day).
- Permission denied (camera) → camera screen shows explanation + settings deep link.
- ffmpeg export failure → surface the ffmpeg log in a dialog, offer to retry; never crash.
- No data loss: deleting a day is a two-step confirm; photos + DB rows removed together.

## Out of scope (v1)
- Cloud backup / sync
- Background auto-capture (camera on)
- Multiple gardens / locations
- Weather auto-fetch (fields are manual)

## Testing
- Unit: schedule config persistence, note validation, day status derivation, export command-builder (ffmpeg args from config)
- Widget: calendar grid rendering, note form, ghost opacity slider
- Manual: camera + ghost on device; notification scheduling on Android + iOS; export output playback
