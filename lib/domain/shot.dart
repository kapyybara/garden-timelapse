/// A single captured photo for a day (shot 1 or shot 2).
class Shot {
  final String path;
  final DateTime takenAt;

  /// Camera zoom level used at capture (for FOV matching via the ghost).
  final double zoom;

  final int? width;
  final int? height;

  const Shot({
    required this.path,
    required this.takenAt,
    this.zoom = 1.0,
    this.width,
    this.height,
  });

  Map<String, dynamic> toRow() => {
        'path': path,
        'takenAt': takenAt.toIso8601String(),
        'zoom': zoom,
        'width': width,
        'height': height,
      };

  static Shot fromRow(Map<String, dynamic> row) => Shot(
        path: row['path'] as String,
        takenAt: DateTime.parse(row['takenAt'] as String),
        zoom: (row['zoom'] as num?)?.toDouble() ?? 1.0,
        width: row['width'] as int?,
        height: row['height'] as int?,
      );
}
