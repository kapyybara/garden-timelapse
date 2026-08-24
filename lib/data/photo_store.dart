import 'dart:io';

/// Stores captured photos in the app-scoped directory, named by date + slot.
class PhotoStore {
  PhotoStore(this._dir);
  final Directory _dir;

  /// Returns the file path where a shot should be written.
  /// [slot] is '1' or '2'.
  String pathFor(String date, String slot) =>
      '${_dir.path}/$date/slot$slot.jpg';

  /// Writes [bytes] (from camera capture) to the slot path.
  Future<String> write(String date, String slot, List<int> bytes) async {
    final dir = Directory('${_dir.path}/$date');
    if (!dir.existsSync()) await dir.create(recursive: true);
    final file = File(pathFor(date, slot));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Returns the slot ('1' or '2') a user should capture next for a day,
  /// or null if both are already taken.
  String? nextSlot({required bool hasSlot1, required bool hasSlot2}) {
    if (!hasSlot1) return '1';
    if (!hasSlot2) return '2';
    return null;
  }

  bool fileExists(String path) => File(path).existsSync();
}
