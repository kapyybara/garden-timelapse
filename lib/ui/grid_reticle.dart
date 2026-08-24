import 'package:flutter/material.dart';

/// A 3×3 rule-of-thirds grid drawn over the camera preview to help the user
/// frame identically each day.
class GridReticle extends StatelessWidget {
  const GridReticle({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    // Vertical thirds
    for (final f in const [1.0 / 3.0, 2.0 / 3.0]) {
      final x = size.width * f;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal thirds
    for (final f in const [1.0 / 3.0, 2.0 / 3.0]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}
