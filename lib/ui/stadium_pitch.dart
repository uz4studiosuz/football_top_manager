import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'football_pitch.dart';

/// Shared world-to-screen mapping for painting and tapping. The playing
/// surface is exactly 105×68 m; stands and the track live outside it.
class MatchCameraTransform {
  static const world = Size(125, 100);
  static const pitch = Rect.fromLTWH(10, 11, 105, 68);
  final Size viewport;
  final double focusX;
  final bool overview;
  late final double scale = overview
      ? min(viewport.width / world.width, viewport.height / world.height)
      : viewport.width / viewport.height < .95
      ? viewport.height / world.height
      : max(viewport.height / world.height, viewport.width / world.width) *
            1.08;
  late final double centreX = overview || viewport.width / scale >= world.width
      ? world.width / 2
      : (10 + focusX * 105).clamp(
          viewport.width / scale / 2,
          world.width - viewport.width / scale / 2,
        );
  late final Offset origin = Offset(
    viewport.width / 2 - centreX * scale,
    viewport.height / 2 - world.height / 2 * scale,
  );
  MatchCameraTransform(this.viewport, {this.focusX = .5, this.overview = true});
  Offset project(Offset normalized) =>
      origin +
      Offset(10 + normalized.dx * 105, 11 + normalized.dy * 68) * scale;
  Offset unproject(Offset pixel) {
    final p = (pixel - origin) / scale;
    return Offset((p.dx - 10) / 105, (p.dy - 11) / 68);
  }
}

/// A deterministic stadium picture is recorded once, then reused each frame.
/// Grass, seating and roof shadows are drawn locally; no network assets.
abstract final class StadiumPitch {
  static ui.Picture? _picture;
  static ui.Image? _texture;
  static Future<void>? _warming;
  static Future<void> warmUp() => _warming ??= _rasterize();
  static Future<void> _rasterize() async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(10);
      canvas.drawPicture(_picture ??= _record());
      final picture = recorder.endRecording();
      _texture = await picture.toImage(1250, 1000);
      picture.dispose();
    } catch (_) {
      // The retained vector picture remains available on renderers that
      // cannot rasterize offscreen.
    }
  }
  static void paint(Canvas canvas, MatchCameraTransform camera) {
    canvas.drawRect(
      Offset.zero & camera.viewport,
      Paint()..color = const Color(0xFF252A25),
    );
    canvas.save();
    canvas.translate(camera.origin.dx, camera.origin.dy);
    canvas.scale(camera.scale);
    final texture = _texture;
    if (texture == null) {
      warmUp();
      canvas.drawPicture(_picture ??= _record());
    } else {
      canvas.drawImageRect(texture, Rect.fromLTWH(0, 0, texture.width.toDouble(), texture.height.toDouble()),
        Offset.zero & MatchCameraTransform.world, Paint()..filterQuality = FilterQuality.low);
    }
    canvas.restore();
  }

  static ui.Picture _record() {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const size = MatchCameraTransform.world, field = MatchCameraTransform.pitch;
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF8B8071));
    final random = Random(481);
    // Concrete concourse and access lanes.
    c.drawRect(
      const Rect.fromLTWH(5, 6, 115, 78),
      Paint()..color = const Color(0xFFB7A68A),
    );
    for (var y = 7.0; y < 84; y += .65) {
      c.drawLine(
        Offset(5, y),
        Offset(120, y),
        Paint()
          ..color = const Color(0x22716557)
          ..strokeWidth = .04,
      );
    }
    void seats(Rect area, bool horizontal) {
      c.drawRect(area, Paint()..color = const Color(0xFF74767B));
      final rows = horizontal
          ? (area.height / .5).floor()
          : (area.width / .5).floor();
      final length = horizontal
          ? (area.width / .42).floor()
          : (area.height / .42).floor();
      for (var row = 0; row < rows; row++) {
        for (var seat = 0; seat < length; seat++) {
          if (seat % 38 < 2) continue;
          final color = const [
            Color(0xFFB3B3A9),
            Color(0xFF334B70),
            Color(0xFF8B9295),
            Color(0xFF4F5C68),
            Color(0xFFCCBBA5),
          ][random.nextInt(5)];
          final x = area.left + (horizontal ? seat * .42 : row * .5);
          final y = area.top + (horizontal ? row * .5 : seat * .42);
          c.drawRect(
            Rect.fromLTWH(x, y, horizontal ? .29 : .36, horizontal ? .36 : .29),
            Paint()..color = color,
          );
        }
      }
    }

    seats(const Rect.fromLTWH(2, 0, 121, 4.5), true);
    seats(const Rect.fromLTWH(2, 85.5, 121, 14.5), true);
    seats(const Rect.fromLTWH(0, 6, 3.5, 78), false);
    seats(const Rect.fromLTWH(121.5, 6, 3.5, 78), false);
    c.drawRect(field.inflate(3), Paint()..color = const Color(0xFF427D35));
    c.save();
    c.clipRect(field.inflate(2.5));
    c.scale(.1);
    const FootballPitchPainter(
      vertical: false,
      inset: EdgeInsets.fromLTRB(100, 110, 100, 110),
      grass: Color(0xFF61943D),
      grassAlt: Color(0xFF568A36),
    ).paint(c, const Size(1250, 900));
    c.restore();
    c.save();
    c.clipRect(field);
    // Cross-cut squares and fine grass texture, without flickering noise.
    for (var col = 0; col < 14; col++) {
      for (var row = 0; row < 9; row++) {
        c.drawRect(
          Rect.fromLTWH(
            field.left + col * 7.5,
            field.top + row * 68 / 9,
            7.5,
            68 / 9,
          ),
          Paint()
            ..color = (row + col).isEven
                ? const Color(0x087FC652)
                : const Color(0x0D153B21),
        );
      }
    }
    for (var i = 0; i < 4500; i++) {
      final x = field.left + random.nextDouble() * field.width,
          y = field.top + random.nextDouble() * field.height;
      c.drawLine(
        Offset(x, y),
        Offset(x + .03, y + .1 + random.nextDouble() * .15),
        Paint()
          ..color = random.nextBool()
              ? const Color(0x1062B94A)
              : const Color(0x0C143415)
          ..strokeWidth = .025,
      );
    }
    final roof = Path()
      ..moveTo(10, 38)
      ..lineTo(88, 39.5)
      ..lineTo(95, 79)
      ..lineTo(10, 79)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0x3C102B24));
    c.drawRect(
      field,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x08FFFFFF), Color(0x00000000), Color(0x160B2A12)],
        ).createShader(field),
    );
    c.restore();
    // Advertising and rails outside the touchlines.
    for (var i = 0; i < 12; i++) {
      final x = 10 + i * 8.75;
      final paint = Paint()
        ..color = i.isEven ? const Color(0xFF303F76) : const Color(0xFF7048AC);
      c.drawRect(Rect.fromLTWH(x, 7, 8.5, 1.1), paint);
      c.drawRect(Rect.fromLTWH(x, 82, 8.5, 1.1), paint);
    }
    final rail = Paint()
      ..color = const Color(0xFF6B6A5D)
      ..strokeWidth = .13;
    c.drawLine(const Offset(5, 84.5), const Offset(120, 84.5), rail);
    c.drawLine(const Offset(5, 5.5), const Offset(120, 5.5), rail);
    // Staff and stewards beside the track.
    for (var i = 0; i < 90; i++) {
      final horizontal = i % 2 == 0;
      final x = horizontal
          ? 7 + random.nextDouble() * 111
          : (i % 3 == 0 ? 5.5 : 119.5);
      final y = horizontal
          ? (i % 4 == 0 ? 5.8 : 84.0)
          : 8 + random.nextDouble() * 74;
      c.drawOval(
        Rect.fromCenter(center: Offset(x + .1, y + .1), width: .22, height: .4),
        Paint()..color = const Color(0x55302C24),
      );
      c.drawCircle(
        Offset(x, y),
        .13,
        Paint()
          ..color = i % 7 == 0
              ? const Color(0xFFE1B552)
              : const Color(0xFF33527B),
      );
    }
    // Goal nets beyond each goal line.
    for (final x in [8.4, 115.0]) {
      final net = Rect.fromLTWH(x, 11 + 30.34, 1.6, 7.32);
      c.drawRect(net, Paint()..color = const Color(0x227A9185));
      for (var y = net.top; y < net.bottom; y += .4) {
        c.drawLine(
          Offset(net.left, y),
          Offset(net.right, y),
          rail
            ..color = const Color(0x99DCE0C6)
            ..strokeWidth = .04,
        );
      }
      c.drawRect(
        net,
        Paint()
          ..color = const Color(0xFFDCE0C6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .12,
      );
    }
    return recorder.endRecording();
  }
}
