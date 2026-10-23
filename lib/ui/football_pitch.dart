import 'package:flutter/material.dart';

class FootballPitchPainter extends CustomPainter {
  const FootballPitchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(10, 10, w - 20, h - 20), p);
    canvas.drawLine(Offset(10, h / 2), Offset(w - 10, h / 2), p);
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.17, p);
    canvas.drawCircle(Offset(w / 2, h / 2), 2, p..style = PaintingStyle.fill);
    p.style = PaintingStyle.stroke;
    for (final top in [true, false]) {
      canvas.drawRect(
        Rect.fromLTWH(
          w * 0.22,
          top ? 10 : h - 10 - h * 0.17,
          w * 0.56,
          h * 0.17,
        ),
        p,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          w * 0.37,
          top ? 10 : h - 10 - h * 0.065,
          w * 0.26,
          h * 0.065,
        ),
        p,
      );
      canvas.drawLine(
        Offset(w * 0.44, top ? 10 : h - 10),
        Offset(w * 0.56, top ? 10 : h - 10),
        p..strokeWidth = 3,
      );
      p.strokeWidth = 1;
    }
  }

  @override
  bool shouldRepaint(covariant FootballPitchPainter old) => false;
}
