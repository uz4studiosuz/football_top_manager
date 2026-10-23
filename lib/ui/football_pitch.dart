import 'dart:math';
import 'package:flutter/material.dart';
import 'app_theme.dart';

/// A to-scale 105 × 68 m pitch with mowing stripes. [vertical] places the
/// goals at the top and bottom (line-ups); otherwise left and right (match).
class FootballPitchPainter extends CustomPainter {
  final bool vertical;
  final EdgeInsets inset;
  final Color grass, grassAlt;
  const FootballPitchPainter({
    this.vertical = true,
    this.inset = const EdgeInsets.all(8),
    this.grass = AppColors.pitch,
    this.grassAlt = AppColors.pitchDark,
  });

  static Rect field(Size size, EdgeInsets inset) => Rect.fromLTWH(
    inset.left,
    inset.top,
    size.width - inset.horizontal,
    size.height - inset.vertical,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final r = field(size, inset);
    canvas.drawRect(Offset.zero & size, Paint()..color = grass);
    const stripes = 12;
    final stripe = Paint()..color = grassAlt;
    for (var i = 0; i < stripes; i += 2) {
      final rect = vertical
          ? Rect.fromLTWH(
              0,
              r.top + r.height / stripes * i,
              size.width,
              r.height / stripes,
            )
          : Rect.fromLTWH(
              r.left + r.width / stripes * i,
              0,
              r.width / stripes,
              size.height,
            );
      canvas.drawRect(rect, stripe);
    }
    // Map pitch metres (x along length 0–105, y across width 0–68).
    Offset m(double x, double y) => vertical
        ? Offset(r.left + y / 68 * r.width, r.top + x / 105 * r.height)
        : Offset(r.left + x / 105 * r.width, r.top + y / 68 * r.height);
    final scale = vertical ? r.height / 105 : r.width / 105;
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, scale * 0.22);
    void rect(double x1, double y1, double x2, double y2) =>
        canvas.drawRect(Rect.fromPoints(m(x1, y1), m(x2, y2)), line);
    rect(0, 0, 105, 68);
    canvas.drawLine(m(52.5, 0), m(52.5, 68), line);
    final circleR = 9.15 * scale;
    canvas.drawCircle(m(52.5, 34), circleR, line);
    final spot = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(m(52.5, 34), max(1.4, scale * 0.35), spot);
    for (final end in [0.0, 105.0]) {
      final dir = end == 0 ? 1.0 : -1.0;
      rect(end, 13.84, end + dir * 16.5, 54.16);
      rect(end, 24.84, end + dir * 5.5, 43.16);
      final penalty = m(end + dir * 11, 34);
      canvas.drawCircle(penalty, max(1.2, scale * 0.3), spot);
      // Penalty arc: the part of the 9.15 m circle outside the box.
      final arcRect = Rect.fromCircle(center: penalty, radius: circleR);
      final a = acos(5.5 / 9.15);
      final double start;
      if (vertical) {
        start = end == 0 ? pi / 2 - a : -pi / 2 - a;
      } else {
        start = end == 0 ? -a : pi - a;
      }
      canvas.drawArc(arcRect, start, 2 * a, false, line);
      // Goal frame drawn just outside the line.
      final goal = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, scale * 0.35);
      canvas.drawRect(
        Rect.fromPoints(m(end, 30.34), m(end - dir * 1.6, 37.66)),
        goal,
      );
    }
    canvas.save();
    canvas.clipRect(r);
    for (final c in [m(0, 0), m(0, 68), m(105, 0), m(105, 68)]) {
      canvas.drawCircle(c, scale * 1.0, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FootballPitchPainter old) =>
      old.vertical != vertical || old.inset != inset || old.grass != grass;
}
