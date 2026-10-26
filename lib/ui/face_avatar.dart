import 'dart:math';
import 'package:flutter/material.dart';
import '../models/face.dart';
import 'app_theme.dart';
import '../l10n/l10n.dart';
import 'face_from_photo.dart';
export '../models/face.dart';

/// Vector portrait: shaded head, almond eyes, tapered brows, layered hair,
/// beard styles and a jersey in club colours.
class FaceAvatar extends StatelessWidget {
  final FaceConfig config;
  final double size;
  final Color shirt;
  final Color? trim;
  final bool circle;
  final bool background;
  const FaceAvatar({
    super.key,
    required this.config,
    this.size = 52,
    this.shirt = const Color(0xFF374DF5),
    this.trim,
    this.circle = false,
    this.background = true,
  });
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final paint = CustomPaint(
      painter: FacePainter(config, shirt, trim, background: background),
    );
    return Semantics(
      label: tr('Shaxsiy portret'),
      child: SizedBox.square(
        dimension: size,
        child: circle ? ClipOval(child: paint) : paint,
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final FaceConfig c;
  final Color shirt;
  final Color? trim;
  final bool background;
  FacePainter(this.c, this.shirt, this.trim, {this.background = true});

  static const skins = [
    Color(0xFFF6DCC8),
    Color(0xFFEFCDB1),
    Color(0xFFE5B993),
    Color(0xFFD7A57D),
    Color(0xFFC68E63),
    Color(0xFFB27A52),
    Color(0xFF9A6442),
    Color(0xFF7E4E33),
    Color(0xFF643C27),
    Color(0xFF4A2C1D),
  ];
  static const hairs = [
    Color(0xFF1C1A1A),
    Color(0xFF3B2A21),
    Color(0xFF6A4630),
    Color(0xFFC9A46A),
    Color(0xFF9C9A95),
    Color(0xFF8E4325),
    Color(0xFFE8DDC6),
    Color(0xFF2A2F3C),
    Color(0xFFDADADA),
    Color(0xFFA0522D),
    Color(0xFFF2EAD3),
    Color(0xFF2F5DA8),
    Color(0xFFB3261E),
  ];
  static const eyeColors = [
    Color(0xFF5A3A22),
    Color(0xFF4E7FA2),
    Color(0xFF5F7A45),
    Color(0xFF2A211C),
    Color(0xFF8A7A5A),
  ];

  // Head geometry per shape: cheek half-width, jaw half-width, chin, top.
  static const _geo = [
    (21.0, 13.0, 79.0, 17.0),
    (22.0, 17.0, 78.0, 17.0),
    (23.0, 15.0, 77.0, 18.0),
    (20.0, 13.0, 81.0, 15.0),
    (22.0, 10.0, 79.0, 17.0),
  ];

  Color _shade(Color base, double amount) =>
      Color.lerp(base, Colors.black, amount)!;
  Color _tint(Color base, double amount) =>
      Color.lerp(base, Colors.white, amount)!;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    // Fine detail (stubble) vanishes in small avatars: draw it bolder there.
    _small = size.width < 70 ? (70 - size.width) / 40 : 0;
    final skin = skins[c.skin.clamp(0, skins.length - 1)];
    final hair = hairs[c.hair.clamp(0, hairs.length - 1)];
    final g = _geo[c.shape.clamp(0, _geo.length - 1)];
    final cheek = g.$1, jaw = g.$2, chin = g.$3, top = g.$4;
    if (background) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 100),
          const Radius.circular(14),
        ),
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.5),
            radius: 1.1,
            colors: [Color(0xFFF7F9FC), Color(0xFFE2E8F0)],
          ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
      );
    }
    _backHair(canvas, hair, cheek, top);
    _neckAndShirt(canvas, skin, chin);
    final head = _headPath(cheek, jaw, chin, top);
    _ears(canvas, skin, cheek);
    canvas.drawPath(head, Paint()..color = skin);
    canvas.save();
    canvas.clipPath(head);
    // Light from upper-left; soft shadow on the right and under the jaw.
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 100, 100),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.16),
          ],
          stops: const [0.25, 0.55, 0.78],
        ).createShader(Rect.fromLTWH(50 - cheek, 0, cheek * 2, 100)),
    );
    canvas.drawCircle(
      const Offset(43, 36),
      22,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.16), Colors.transparent],
        ).createShader(Rect.fromCircle(center: const Offset(43, 36), radius: 22)),
    );
    for (final x in [50 - cheek * 0.62, 50 + cheek * 0.62]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 58), width: 9, height: 6),
        Paint()..color = const Color(0xFFE0605A).withValues(alpha: 0.07),
      );
    }
    _ageLines(canvas, skin, cheek);
    if (c.beardStyle == 1) _stubble(canvas, hair, cheek, jaw, chin);
    canvas.restore();
    // Beards follow the jaw and may grow past it, so they are drawn
    // outside the head clip.
    _beard(canvas, hair, cheek, jaw, chin);
    _eyes(canvas, skin);
    _brows(canvas, hair);
    _nose(canvas, skin, chin);
    _mouth(canvas, skin, chin);
    if (_moustacheStyles.contains(c.beardStyle)) _moustache(canvas, hair, chin);
    if (c.freckles) _freckles(canvas, skin);
    _frontHair(canvas, hair, skin, cheek, top);
    if (c.glasses) _glasses(canvas, cheek);
    _accessory(canvas, skin, cheek, chin, top);
    canvas.restore();
  }

  /// Headband, earring, scar, neck tattoo or chain.
  void _accessory(Canvas canvas, Color skin, double cheek, double chin, double top) {
    switch (c.accessory) {
      case 1:
        // Sweatband across the forehead, in the shirt colour.
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTRB(50 - cheek - 1, top + 9, 50 + cheek + 1, top + 14.5), const Radius.circular(2)),
          Paint()..color = shirt,
        );
        canvas.drawRect(
          Rect.fromLTRB(50 - cheek - 1, top + 11, 50 + cheek + 1, top + 12),
          Paint()..color = Colors.white.withValues(alpha: 0.7),
        );
      case 2:
        canvas.drawCircle(Offset(50 - cheek - 1.5, 57), 1.6, Paint()..color = const Color(0xFFE8C46A));
        canvas.drawCircle(Offset(50 + cheek + 1.5, 57), 1.6, Paint()..color = const Color(0xFFE8C46A));
      case 3:
        final scar = Paint()
          ..color = _shade(skin, 0.3)
          ..strokeWidth = 0.9
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(50 + cheek * 0.42, 45), Offset(50 + cheek * 0.58, 55), scar);
        for (final t in [0.3, 0.6]) {
          final p = Offset.lerp(Offset(50 + cheek * 0.42, 45), Offset(50 + cheek * 0.58, 55), t)!;
          canvas.drawLine(p + const Offset(-1.4, 0.4), p + const Offset(1.4, -0.4), scar);
        }
      case 4:
        final ink = Paint()
          ..color = const Color(0xFF2C3E50).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        final base = Offset(56, chin + 5);
        canvas.drawArc(Rect.fromCircle(center: base, radius: 2.5), 0, pi * 1.6, false, ink);
        canvas.drawLine(base + const Offset(-2, 3.5), base + const Offset(2.5, 3.5), ink);
      case 5:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(50, chin + 6), width: 22, height: 12),
          0.2,
          pi - 0.4,
          false,
          Paint()
            ..color = const Color(0xFFE8C46A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
    }
  }

  Path _headPath(double cheek, double jaw, double chin, double top) {
    final l = 50 - cheek, r = 50 + cheek;
    return Path()
      ..moveTo(l, 44)
      ..cubicTo(l - 0.5, top + 8, 50 - cheek * 0.62, top, 50, top)
      ..cubicTo(50 + cheek * 0.62, top, r + 0.5, top + 8, r, 44)
      ..lineTo(r - 0.4, 54)
      ..cubicTo(r - 1, 64, 50 + jaw + 2, chin - 6, 50 + jaw * 0.5, chin - 1.2)
      ..quadraticBezierTo(50, chin + 1.2, 50 - jaw * 0.5, chin - 1.2)
      ..cubicTo(50 - jaw - 2, chin - 6, l + 1, 64, l + 0.4, 54)
      ..close();
  }

  void _neckAndShirt(Canvas canvas, Color skin, double chin) {
    final neck = Path()
      ..moveTo(41, 64)
      ..lineTo(59, 64)
      ..lineTo(60.5, 84)
      ..quadraticBezierTo(50, 90, 39.5, 84)
      ..close();
    canvas.drawPath(neck, Paint()..color = _shade(skin, 0.06));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, chin + 1.5), width: 22, height: 7),
      Paint()..color = _shade(skin, 0.28).withValues(alpha: 0.55),
    );
    final body = Path()
      ..moveTo(0, 100)
      ..lineTo(0, 93)
      ..quadraticBezierTo(3, 83, 20, 80)
      ..lineTo(39, 77)
      ..quadraticBezierTo(50, 86, 61, 77)
      ..lineTo(80, 80)
      ..quadraticBezierTo(97, 83, 100, 93)
      ..lineTo(100, 100)
      ..close();
    canvas.drawPath(body, Paint()..color = shirt);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.black.withValues(alpha: 0.14),
          ],
        ).createShader(const Rect.fromLTWH(0, 76, 100, 24)),
    );
    final collarColor =
        trim ??
        (shirt.computeLuminance() > 0.6
            ? _shade(shirt, 0.35)
            : _tint(shirt, 0.55));
    canvas.drawPath(
      Path()
        ..moveTo(38.5, 77)
        ..quadraticBezierTo(50, 88, 61.5, 77)
        ..lineTo(64, 78.5)
        ..quadraticBezierTo(50, 93, 36, 78.5)
        ..close(),
      Paint()..color = collarColor,
    );
  }

  void _ears(Canvas canvas, Color skin, double cheek) {
    for (final s in [-1.0, 1.0]) {
      final x = 50 + s * (cheek + 0.5);
      final ear = Rect.fromCenter(center: Offset(x, 50), width: 7.5, height: 13);
      canvas.drawOval(ear, Paint()..color = s > 0 ? _shade(skin, 0.08) : skin);
      canvas.drawArc(
        ear.deflate(1.8),
        s > 0 ? -1.2 : pi + 1.2 - 2.4,
        2.4,
        false,
        Paint()
          ..color = _shade(skin, 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  void _eyes(Canvas canvas, Color skin) {
    final spacing = 9.5 + (c.eyes == 2 ? 1.0 : 0);
    final h = const [4.0, 3.1, 4.4, 5.0, 2.7][c.eyes.clamp(0, 4)];
    final almond = c.eyes == 4;
    const y = 47.5;
    for (final s in [-1.0, 1.0]) {
      final x = 50 + s * spacing;
      // Socket shadow.
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y - 1.6), width: 12, height: 5),
        Paint()..color = _shade(skin, 0.18).withValues(alpha: 0.35),
      );
      // Almond eyes rise slightly towards the outer corner.
      final tilt = almond ? -0.9 : 0.0;
      final eye = Path()
        ..moveTo(x - 5.2, y + 0.2 + (s < 0 ? tilt : 0))
        ..quadraticBezierTo(x + (almond ? 0.8 : -0.6) * s, y - h, x + 5.2, y - 0.2 * s + (s > 0 ? tilt : 0))
        ..quadraticBezierTo(x + 0.4 * s, y + h * (almond ? 0.6 : 0.72), x - 5.2, y + 0.2 + (s < 0 ? tilt : 0))
        ..close();
      canvas.drawPath(eye, Paint()..color = const Color(0xFFF6F3EE));
      canvas.save();
      canvas.clipPath(eye);
      final iris = Offset(x + 0.2 * s, y + 0.2);
      canvas.drawCircle(
        iris,
        2.55,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _tint(eyeColors[c.eyeColor.clamp(0, 4)], 0.25),
              eyeColors[c.eyeColor.clamp(0, 4)],
              _shade(eyeColors[c.eyeColor.clamp(0, 4)], 0.4),
            ],
            stops: const [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: iris, radius: 2.55)),
      );
      canvas.drawCircle(iris, 1.15, Paint()..color = const Color(0xFF120F0E));
      canvas.drawCircle(
        iris + const Offset(-0.8, -0.8),
        0.65,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      // Upper lid casts a little shade over the eyeball.
      canvas.drawRect(
        Rect.fromLTWH(x - 6, y - h - 1, 12, 1.6 + h * 0.25),
        Paint()..color = _shade(skin, 0.35).withValues(alpha: 0.18),
      );
      canvas.restore();
      canvas.drawPath(
        Path()
          ..moveTo(x - 5.4, y + 0.3)
          ..quadraticBezierTo(x - 0.6 * s, y - h - 0.2, x + 5.4, y - 0.2 * s),
        Paint()
          ..color = _shade(skin, 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..strokeCap = StrokeCap.round,
      );
      if (!almond) {
        // Lid crease (monolid almond eyes have none).
        canvas.drawPath(
          Path()
            ..moveTo(x - 3.5, y - h - 1.4)
            ..quadraticBezierTo(x, y - h - 2.4, x + 3.8, y - h - 1.0),
          Paint()
            ..color = _shade(skin, 0.2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.55,
        );
      }
    }
  }

  void _brows(Canvas canvas, Color hair) {
    final t1 = const [1.7, 2.3, 2.9, 2.0][c.brow.clamp(0, 3)];
    final arch = const [1.0, 1.6, 0.4, 2.3][c.brow.clamp(0, 3)];
    final color = c.hair == 6 || c.hair == 3 ? _shade(hair, 0.35) : hair;
    const yb = 41.2;
    for (final s in [-1.0, 1.0]) {
      final xi = 50 + s * 4.2, xo = 50 + s * 15.2, xm = 50 + s * 10;
      final path = Path()
        ..moveTo(xi, yb)
        ..lineTo(xi, yb - t1)
        ..quadraticBezierTo(xm, yb - t1 - arch, xo, yb - arch * 0.3 + 0.4)
        ..quadraticBezierTo(xm, yb - arch - t1 * 0.25, xi, yb)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.95));
    }
  }

  void _nose(Canvas canvas, Color skin, double chin) {
    final w = 3.0 + c.nose * 0.6;
    final y = chin - 20.5 + (c.nose == 3 ? 0.8 : 0);
    canvas.drawPath(
      Path()
        ..moveTo(51.2, 47)
        ..quadraticBezierTo(52.6, y - 4, 52.2, y - 0.5),
      Paint()
        ..color = _shade(skin, 0.18).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(50 - w, y)
        ..quadraticBezierTo(50, y + 2.6, 50 + w, y)
        ..quadraticBezierTo(50, y + 1.1, 50 - w, y),
      Paint()..color = _shade(skin, 0.24),
    );
    final nostril = Paint()
      ..color = _shade(skin, 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.95
      ..strokeCap = StrokeCap.round;
    for (final s in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(50 + s * (w + 0.3), y - 1.6)
          ..quadraticBezierTo(50 + s * (w + 0.8), y + 0.4, 50 + s * 1.6, y + 0.8),
        nostril,
      );
    }
    canvas.drawCircle(
      Offset(49.4, y - 2),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
  }

  void _mouth(Canvas canvas, Color skin, double chin) {
    final y = chin - 13.2;
    final mw = 9.0 + c.mouth * 1.2;
    final lip = Color.lerp(skin, const Color(0xFFA2434B), 0.42)!;
    final smile = c.mouth == 3 ? 0.9 : 0.0;
    canvas.drawPath(
      Path()
        ..moveTo(50 - mw / 2, y - smile)
        ..quadraticBezierTo(50 - mw / 4, y - 1.9, 50, y - 1.0)
        ..quadraticBezierTo(50 + mw / 4, y - 1.9, 50 + mw / 2, y - smile)
        ..quadraticBezierTo(50, y + 0.7, 50 - mw / 2, y - smile)
        ..close(),
      Paint()..color = _shade(lip, 0.12),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50 - mw / 2 + 0.8, y - smile * 0.6)
        ..quadraticBezierTo(50, y + 3.2 + c.mouth * 0.25, 50 + mw / 2 - 0.8, y - smile * 0.6)
        ..quadraticBezierTo(50, y + 0.8, 50 - mw / 2 + 0.8, y - smile * 0.6)
        ..close(),
      Paint()..color = _tint(lip, 0.08),
    );
    canvas.drawPath(
      Path()
        ..moveTo(50 - mw / 2, y - smile)
        ..quadraticBezierTo(50, y + 0.9 + smile * 0.4, 50 + mw / 2, y - smile),
      Paint()
        ..color = _shade(lip, 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, y + 5.3), width: mw * 0.55, height: 1.6),
      Paint()..color = _shade(skin, 0.14).withValues(alpha: 0.5),
    );
  }

  double _small = 0;
  static const _moustacheStyles = {2, 3, 4, 5, 7};

  Color _beardColor(Color hair) =>
      Color.lerp(hair, Colors.black, hair.computeLuminance() > 0.3 ? 0.18 : 0.04)!;

  /// Lower face outline from the left sideburn round the chin to the right
  /// one, following this face shape and pushed out by [grow] (beard volume).
  Path _jaw(double cheek, double jaw, double chin, double grow, double from) {
    final l = 50 - cheek - grow * 0.3, r = 50 + cheek + grow * 0.3;
    final ch = chin + grow;
    return Path()
      ..moveTo(l + 0.2, from)
      ..lineTo(l + 0.4, 54)
      ..cubicTo(l + 1 - grow * 0.2, 64 + grow * 0.3, 50 - jaw - 2 - grow * 0.4, ch - 6, 50 - jaw * 0.5 - grow * 0.2, ch - 1.2)
      ..quadraticBezierTo(50, ch + 1.2 + grow * 0.2, 50 + jaw * 0.5 + grow * 0.2, ch - 1.2)
      ..cubicTo(50 + jaw + 2 + grow * 0.4, ch - 6, r - 1 + grow * 0.2, 64 + grow * 0.3, r - 0.4, 54)
      ..lineTo(r - 0.2, from);
  }

  /// Beard area: the jaw outline, then back along the cheek line to the
  /// corners of the mouth, leaving the lips (and a soul-patch gap) clear.
  Path _beardArea(
    double cheek,
    double jaw,
    double chin, {
    required double grow,
    required double from,
    required double cheekLine,
    required double corner,
  }) {
    final y = chin - 13.2;
    final mw = 9.0 + c.mouth * 1.2;
    final l = 50 - cheek, r = 50 + cheek;
    return _jaw(cheek, jaw, chin, grow, from)
      ..lineTo(r - 2.6, from + 2)
      ..quadraticBezierTo(r - 3.5, cheekLine, 50 + mw / 2 + corner, y - 1.0)
      ..quadraticBezierTo(50 + mw * 0.32, y + 4.6, 50, y + 4.2)
      ..quadraticBezierTo(50 - mw * 0.32, y + 4.6, 50 - mw / 2 - corner, y - 1.0)
      ..quadraticBezierTo(l + 3.5, cheekLine, l + 2.6, from + 2)
      ..close();
  }

  void _stubble(Canvas canvas, Color hair, double cheek, double jaw, double chin) {
    final y = chin - 13.2;
    final mw = 9.0 + c.mouth * 1.2;
    final area = _beardArea(cheek, jaw, chin, grow: 0, from: 49, cheekLine: 61, corner: 2.4);
    final color = _beardColor(hair);
    canvas.drawPath(
      area,
      Paint()
        ..color = color.withValues(alpha: 0.17 + _small * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, y - 2.7), width: mw + 3.5, height: 3.2),
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
    canvas.save();
    canvas.clipPath(area);
    final dot = Paint()..color = color.withValues(alpha: (0.32 + _small * 0.4).clamp(0.0, 0.85));
    final rnd = Random(c.skin * 31 + c.shape);
    final box = area.getBounds();
    for (var i = 0; i < 150; i++) {
      canvas.drawCircle(
        Offset(box.left + rnd.nextDouble() * box.width, box.top + rnd.nextDouble() * box.height),
        0.24 + _small * 0.3,
        dot,
      );
    }
    canvas.restore();
  }

  void _beard(Canvas canvas, Color hair, double cheek, double jaw, double chin) {
    final s = c.beardStyle;
    if (s == 0 || s == 1 || s == 5) return;
    final color = _beardColor(hair);
    if (s == 6) {
      // Chinstrap: a thin band hugging the jawline.
      canvas.drawPath(
        _jaw(cheek, jaw, chin, 0.5, 46),
        Paint()
          ..color = color.withValues(alpha: 0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }
    final y = chin - 13.2;
    final mw = 9.0 + c.mouth * 1.2;
    final area = switch (s) {
      2 => _beardArea(cheek, jaw, chin, grow: 1.0, from: 49, cheekLine: 62, corner: 2.4),
      4 => Path()
        ..moveTo(50 - mw / 2 - 1.2, y - 0.6)
        ..quadraticBezierTo(50 - mw / 2 - 3.2, chin - 4, 50 - jaw * 0.6 - 1, chin)
        ..quadraticBezierTo(50, chin + 3, 50 + jaw * 0.6 + 1, chin)
        ..quadraticBezierTo(50 + mw / 2 + 3.2, chin - 4, 50 + mw / 2 + 1.2, y - 0.6)
        ..lineTo(50 + mw / 2 + 0.2, y + 0.6)
        ..quadraticBezierTo(50, y + 3.8, 50 - mw / 2 - 0.2, y + 0.6)
        ..close(),
      7 => _beardArea(cheek, jaw, chin, grow: 7, from: 47, cheekLine: 59, corner: 2.8),
      _ => _beardArea(cheek, jaw, chin, grow: 2.8, from: 47, cheekLine: 60, corner: 2.8),
    };
    final box = area.getBounds();
    canvas.drawPath(
      area,
      Paint()
        ..color = color.withValues(alpha: s == 2 ? 0.9 : 0.97)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.35),
    );
    canvas.save();
    canvas.clipPath(area);
    // Volume: lighter near the cheeks, darker toward the jaw edge.
    canvas.drawRect(
      box,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _tint(color, 0.15).withValues(alpha: 0.35),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
        ).createShader(box),
    );
    final strand = Paint()
      ..color = _tint(color, 0.28).withValues(alpha: 0.45)
      ..strokeWidth = 0.45
      ..strokeCap = StrokeCap.round;
    final rnd = Random(c.skin * 7 + c.hair * 13 + s);
    for (var i = 0; i < (s == 4 ? 40 : 110); i++) {
      final x = box.left + rnd.nextDouble() * box.width;
      final yy = box.top + rnd.nextDouble() * box.height;
      canvas.drawLine(Offset(x, yy), Offset(x + (x - 50) * 0.05, yy + 1.7), strand);
    }
    canvas.restore();
  }

  void _moustache(Canvas canvas, Color hair, double chin) {
    final y = chin - 13.2;
    final mw = 9.0 + c.mouth * 1.2;
    final full = c.beardStyle == 3 || c.beardStyle == 7;
    final drop = full ? 1.6 : 0.2; // full beards join the moustache at the corners
    final color = _beardColor(hair);
    final path = Path()
      ..moveTo(50 - mw / 2 - 1.4, y + drop)
      ..quadraticBezierTo(50 - mw / 4, y - 4.4, 50, y - 3.3)
      ..quadraticBezierTo(50 + mw / 4, y - 4.4, 50 + mw / 2 + 1.4, y + drop)
      ..quadraticBezierTo(50 + mw / 4, y - 1.2, 50, y - 1.5)
      ..quadraticBezierTo(50 - mw / 4, y - 1.2, 50 - mw / 2 - 1.4, y + drop)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: c.beardStyle == 2 ? 0.8 : 0.96)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.3),
    );
    final strand = Paint()
      ..color = _tint(color, 0.3).withValues(alpha: 0.4)
      ..strokeWidth = 0.4
      ..strokeCap = StrokeCap.round;
    for (var i = -3; i <= 3; i++) {
      final x = 50 + i * mw / 8;
      canvas.drawLine(Offset(x, y - 3.4), Offset(x + i * 0.35, y - 1.8), strand);
    }
  }

  void _ageLines(Canvas canvas, Color skin, double cheek) {
    if (c.age == 0) return;
    final p = Paint()
      ..color = _shade(skin, 0.24).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < c.age + 1; i++) {
      final y = 31.5 + i * 2.6;
      canvas.drawPath(
        Path()
          ..moveTo(42, y)
          ..quadraticBezierTo(50, y - 1, 58, y),
        p,
      );
    }
    if (c.age == 2) {
      for (final s in [-1.0, 1.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(50 + s * 5.5, 59)
            ..quadraticBezierTo(50 + s * 8.5, 63, 50 + s * 8, 67),
          p,
        );
        canvas.drawLine(
          Offset(50 + s * 16, 47),
          Offset(50 + s * 18, 48.5),
          p,
        );
      }
    }
  }

  void _freckles(Canvas canvas, Color skin) {
    final p = Paint()..color = _shade(skin, 0.3).withValues(alpha: 0.7);
    for (final pt in const [
      Offset(36, 54),
      Offset(39, 56),
      Offset(34, 57),
      Offset(41, 53.5),
      Offset(61, 54),
      Offset(64, 56),
      Offset(66, 53.5),
      Offset(59, 56.5),
    ]) {
      canvas.drawCircle(pt, 0.55, p);
    }
  }

  void _glasses(Canvas canvas, double cheek) {
    final frame = Paint()
      ..color = const Color(0xFF1F2733)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    for (final s in [-1.0, 1.0]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(50 + s * 10.2, 48), width: 15, height: 10.5),
        const Radius.circular(3.5),
      );
      canvas.drawRRect(r, Paint()..color = const Color(0xFF9DC7E8).withValues(alpha: 0.12));
      canvas.drawRRect(r, frame);
      canvas.drawLine(
        Offset(50 + s * 17.7, 46.5),
        Offset(50 + s * (cheek + 0.5), 47.5),
        frame,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(47.3, 47.3)
        ..quadraticBezierTo(50, 45.6, 52.7, 47.3),
      frame,
    );
  }

  // ------------------------------------------------------------------ hair
  void _backHair(Canvas canvas, Color hair, double cheek, double top) {
    final paint = Paint()..color = _shade(hair, 0.12);
    switch (c.cut) {
      case 7: // afro
        canvas.drawOval(
          Rect.fromCenter(center: Offset(50, top + 14), width: cheek * 2 + 22, height: 48),
          paint,
        );
      case 8: // long
        canvas.drawPath(
          Path()
            ..moveTo(50 - cheek - 4, 34)
            ..quadraticBezierTo(50 - cheek - 7, 64, 50 - cheek - 2, 84)
            ..lineTo(50 + cheek + 2, 84)
            ..quadraticBezierTo(50 + cheek + 7, 64, 50 + cheek + 4, 34)
            ..close(),
          paint,
        );
      case 9: // bun
        canvas.drawCircle(Offset(50, top - 4.5), 6.2, paint);
      case 10: // dreads
        final rnd = Random(7);
        for (var i = 0; i < 9; i++) {
          final s = i.isEven ? -1.0 : 1.0;
          final x = 50 + s * (cheek - 4 + (i ~/ 2) * 2.4);
          final len = 60 + rnd.nextDouble() * 14;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 1.6, 30, 3.2, len - 30),
              const Radius.circular(1.6),
            ),
            paint,
          );
        }
      default:
        break;
    }
  }

  void _frontHair(
    Canvas canvas,
    Color hair,
    Color skin,
    double cheek,
    double top,
  ) {
    if (c.cut == 5) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(44, top + 6), width: 12, height: 5),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
      return;
    }
    final l = 50 - cheek, r = 50 + cheek;
    final volume = const [2.2, 3.2, 7.0, 5.0, 0.6, 0.0, 1.4, 8.5, 2.6, 1.2, 3.0, 0.4, 3.2, 4.2, 5.2, 3.0][c.cut];
    final hairline = const [30.0, 29.5, 29.0, 30.0, 31.0, 0.0, 30.5, 28.0, 30.0, 29.0, 29.5, 31.5, 27.5, 34.5, 36.5, 30.0][c.cut];
    final shaved = c.cut == 4 || c.cut == 11;
    final fade = c.cut == 15;
    final path = Path()
      ..moveTo(l - 1.6, 47)
      ..lineTo(l - 1.8, 36)
      ..cubicTo(l - 2.5, top - 2 - volume, 50 - cheek * 0.45, top - 3 - volume * 1.15, 50 + (c.cut == 2 ? -3 : 0), top - 3 - volume * 1.15)
      ..cubicTo(50 + cheek * 0.45, top - 3 - volume * 1.1, r + 2.5, top - 2 - volume, r + 1.8, 36)
      ..lineTo(r + 1.6, 47)
      ..lineTo(r - 0.8, 47)
      ..lineTo(r - 1.4, hairline + 5);
    switch (c.cut) {
      case 1: // side part: sweeps right to left
        path
          ..quadraticBezierTo(50 + cheek * 0.3, hairline - 3, 44, hairline - 1.5)
          ..quadraticBezierTo(50 - cheek * 0.7, hairline + 1, l + 1.4, hairline + 6);
      case 2: // quiff
        path
          ..quadraticBezierTo(50 + cheek * 0.4, hairline - 2.5, 50, hairline - 1.5)
          ..quadraticBezierTo(50 - cheek * 0.4, hairline - 2.5, l + 1.4, hairline + 5);
      case 13: // messy fringe
        path
          ..lineTo(r - 4, hairline - 1)
          ..lineTo(r - 7, hairline + 2.5)
          ..lineTo(53, hairline - 1.5)
          ..lineTo(49, hairline + 2.8)
          ..lineTo(45, hairline - 1.2)
          ..lineTo(41, hairline + 2.2)
          ..lineTo(l + 4, hairline - 0.5)
          ..lineTo(l + 1.4, hairline + 5);
      case 14: // heavy straight fringe falling over the forehead
        path
          ..lineTo(r - 3.5, hairline - 2.2)
          ..lineTo(r - 6.5, hairline + 0.6)
          ..lineTo(57, hairline - 1.4)
          ..lineTo(53.5, hairline + 1.2)
          ..lineTo(50, hairline - 1.0)
          ..lineTo(46, hairline + 1.6)
          ..lineTo(42, hairline - 0.6)
          ..lineTo(38.5, hairline + 1.0)
          ..lineTo(l + 3, hairline - 1.6)
          ..lineTo(l + 1.4, hairline + 3);
      case 12: // slick back – high, rounded hairline
        path
          ..quadraticBezierTo(r - 6, hairline - 1, 50, hairline - 1.6)
          ..quadraticBezierTo(l + 6, hairline - 1, l + 1.4, hairline + 5);
      default:
        path
          ..quadraticBezierTo(50 + cheek * 0.5, hairline - 1.2, 50, hairline)
          ..quadraticBezierTo(50 - cheek * 0.5, hairline - 1.2, l + 1.4, hairline + 5);
    }
    path
      ..lineTo(l + 0.8, 47)
      ..close();
    final base = shaved ? hair.withValues(alpha: c.cut == 11 ? 0.32 : 0.78) : hair;
    if (fade) {
      // Skin fade: faint sides, full hair only on top.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(l + 0.4, 0, r - 0.4, 100));
      canvas.drawPath(path, Paint()..color = hair.withValues(alpha: 0.3));
      canvas.restore();
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(l + 2.2, 0, r - 2.2, 37.5));
      canvas.drawPath(path, Paint()..color = hair);
      canvas.restore();
    } else {
      canvas.drawPath(path, Paint()..color = base);
    }
    if (!shaved) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_tint(hair, 0.22).withValues(alpha: 0.6), Colors.transparent, _shade(hair, 0.3).withValues(alpha: 0.5)],
          ).createShader(Rect.fromLTWH(l - 3, top - 12, cheek * 2 + 6, 40)),
      );
    }
    final strand = Paint()
      ..color = _tint(hair, 0.18).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    switch (c.cut) {
      case 14:
        for (var i = 0; i < 7; i++) {
          final x = l + 4 + i * (cheek * 2 - 8) / 6;
          canvas.drawPath(
            Path()
              ..moveTo(x + 2.5, top - 1)
              ..quadraticBezierTo(x + 1, top + 6, x - 0.6, hairline - 0.8),
            strand,
          );
        }
      case 15:
        for (var i = 0; i < 4; i++) {
          final x = l + 7 + i * (cheek * 2 - 14) / 3;
          canvas.drawLine(Offset(x, top - 2), Offset(x + 1.5, hairline - 1.5), strand);
        }
      case 0:
      case 13:
        for (var i = 0; i < 5; i++) {
          final x = l + 6 + i * (cheek * 2 - 12) / 4;
          canvas.drawLine(Offset(x, top - 1.5), Offset(x + 2, hairline - 1.5), strand);
        }
      case 1:
        canvas.drawLine(Offset(44, top - 2.5), Offset(44, hairline - 1.8), Paint()
          ..color = _shade(hair, 0.4)
          ..strokeWidth = 0.7);
        for (var i = 0; i < 4; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(46 + i * 4, top - 2)
              ..quadraticBezierTo(50 + i * 4, top + 6, 44 + i * 2, hairline - 1),
            strand,
          );
        }
      case 2:
        for (var i = 0; i < 4; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(40 + i * 5, hairline - 1)
              ..quadraticBezierTo(42 + i * 5, top - 4, 50 + i * 3, top - 8),
            strand,
          );
        }
      case 3:
      case 7:
        final bump = Paint()..color = c.cut == 7 ? _shade(hair, 0.05) : hair;
        final n = c.cut == 7 ? 11 : 8;
        for (var i = 0; i < n; i++) {
          final t = i / (n - 1);
          final x = l - (c.cut == 7 ? 4 : 0) + t * (cheek * 2 + (c.cut == 7 ? 8 : 0));
          final y = top - volume + 2 + sin(t * pi) * -2.5 + (i.isEven ? 0 : 1.6);
          canvas.drawCircle(Offset(x, y), c.cut == 7 ? 5.2 : 4.0, bump);
        }
        final curl = Paint()
          ..color = _tint(hair, 0.2).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6;
        for (var i = 0; i < 9; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(l + 5 + i * (cheek * 2 - 10) / 8, top + 3 + (i % 3) * 2), radius: 1.6),
            0,
            pi * 1.4,
            false,
            curl,
          );
        }
      case 4:
        final dot = Paint()..color = _shade(hair, 0.2).withValues(alpha: 0.35);
        final rnd = Random(c.hair + 3);
        for (var i = 0; i < 60; i++) {
          canvas.drawCircle(
            Offset(l + 2 + rnd.nextDouble() * (cheek * 2 - 4), top + rnd.nextDouble() * (hairline - top - 1)),
            0.3,
            dot,
          );
        }
      case 6:
        for (var row = 0; row < 3; row++) {
          final y = top + 2 + row * 3.6;
          final wave = Path()..moveTo(l + 5, y);
          for (var i = 0; i < 6; i++) {
            wave.relativeQuadraticBezierTo((cheek * 2 - 10) / 12, -1.2, (cheek * 2 - 10) / 6, 0);
          }
          canvas.drawPath(wave, strand);
        }
      case 9:
      case 12:
        for (var i = 0; i < 5; i++) {
          final x = l + 6 + i * (cheek * 2 - 12) / 4;
          canvas.drawPath(
            Path()
              ..moveTo(x, hairline - 0.5)
              ..quadraticBezierTo(x + (x < 50 ? -1 : 1), top + 4, x + (x < 50 ? -2 : 2), top - 1),
            strand,
          );
        }
      case 10:
        final loc = Paint()..color = _shade(hair, 0.05);
        for (var i = 0; i < 7; i++) {
          final x = l + 3 + i * (cheek * 2 - 6) / 6;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x - 1.7, top - 3, 3.4, hairline - top + 4), const Radius.circular(1.7)),
            loc,
          );
        }
      case 11:
        canvas.drawPath(
          Path()
            ..moveTo(45, hairline)
            ..quadraticBezierTo(44, top - 6, 50, top - 11)
            ..quadraticBezierTo(56, top - 6, 55, hairline)
            ..close(),
          Paint()..color = hair,
        );
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant FacePainter old) =>
      old.c != c || old.shirt != shirt || old.trim != trim;
}

/// Portrait editor shared by the manager onboarding and player profiles.
class FaceStudio extends StatefulWidget {
  final FaceConfig value;
  final ValueChanged<FaceConfig> onChanged;
  final Color shirt;

  /// When known, "random" draws a face typical of this nationality and age.
  final String? nationality;
  final int? age;
  const FaceStudio({
    super.key,
    required this.value,
    required this.onChanged,
    this.shirt = const Color(0xFF2B3A55),
    this.nationality,
    this.age,
  });
  @override
  State<FaceStudio> createState() => _FaceStudioState();
}

class _FaceStudioState extends State<FaceStudio> {
  int tab = 0;
  final List<FaceConfig> _undo = [];
  FaceConfig get value => widget.value;

  void _set(FaceConfig next) {
    if (next == value) return;
    _undo.add(value);
    if (_undo.length > 40) _undo.removeAt(0);
    widget.onChanged(next);
  }

  void _random() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _set(widget.nationality == null
        ? FaceConfig.seed(id)
        : FaceConfig.forPlayer(id, widget.nationality!, widget.age ?? 25));
  }

  /// Thumbnail zoomed on the feature being edited (eyes, mouth, beard...).
  Widget _thumb(FaceConfig f, ({double scale, double y}) zoom) => ClipRRect(
    borderRadius: BorderRadius.circular(11),
    child: SizedBox.square(
      dimension: 56,
      child: Transform.scale(
        scale: zoom.scale,
        alignment: Alignment(0, zoom.y),
        child: FaceAvatar(config: f, size: 56, shirt: widget.shirt),
      ),
    ),
  );

  static const _full = (scale: 1.0, y: 0.0);
  static const _eyesZoom = (scale: 2.3, y: -0.08);
  static const _browZoom = (scale: 2.3, y: -0.22);
  static const _noseZoom = (scale: 2.2, y: 0.12);
  static const _mouthZoom = (scale: 2.2, y: 0.38);
  static const _beardZoom = (scale: 1.45, y: 0.5);

  Widget _choices(
    String key,
    String label,
    int count, {
    List<String>? labels,
    ({double scale, double y}) zoom = _full,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label), style: AppText.bodyStrong),
      const SizedBox(height: 10),
      SizedBox(
        height: labels == null ? 66 : 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final selected = value.toMap()[key] == i;
            return InkWell(
              onTap: () => _set(value.change(key, i)),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.line,
                        width: selected ? 2.2 : 1,
                      ),
                    ),
                    child: _thumb(value.change(key, i), zoom),
                  ),
                  if (labels != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      tr(labels[i]),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? AppColors.primary : AppColors.ink2,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _swatches(String key, String label, List<Color> colors) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(tr(label), style: AppText.bodyStrong),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < colors.length; i++)
            InkWell(
              onTap: () => _set(value.change(key, i)),
              customBorder: const CircleBorder(),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value.toMap()[key] == i ? AppColors.primary : AppColors.line,
                    width: value.toMap()[key] == i ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 18),
    ],
  );

  Widget _toggle(String key, String label) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(tr(label), style: AppText.bodyStrong),
    value: value.toMap()[key] as bool,
    onChanged: (v) => _set(value.change(key, v)),
  );

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final sections = [
      [
        _swatches('skin', 'Teri rangi', FacePainter.skins),
        _choices('shape', 'Yuz shakli', FaceConfig.shapeCount, labels: FaceConfig.shapeLabels),
        _choices('nose', 'Burun', FaceConfig.noseCount, labels: FaceConfig.noseLabels, zoom: _noseZoom),
        _choices('mouth', 'Lab', FaceConfig.mouthCount, labels: FaceConfig.mouthLabels, zoom: _mouthZoom),
      ],
      [
        _choices('eyes', tr('Ko‘z shakli'), FaceConfig.eyesCount, labels: FaceConfig.eyeLabels, zoom: _eyesZoom),
        _swatches('eyeColor', tr('Ko‘z rangi'), FacePainter.eyeColors),
        _choices('brow', 'Qosh', FaceConfig.browCount, labels: FaceConfig.browLabels, zoom: _browZoom),
      ],
      [
        _choices('cut', 'Soch turmagi', FaceConfig.cutCount, labels: FaceConfig.cutLabels),
        _swatches('hair', tr('Soch va soqol rangi'), FacePainter.hairs),
      ],
      [
        _choices('beardStyle', 'Soqol', FaceConfig.beardCount, labels: FaceConfig.beardLabels, zoom: _beardZoom),
        Text(
          tr('Soqol yuz shakli va jag‘ chizig‘iga moslashadi.'),
          style: AppText.caption,
        ),
      ],
      [
        _choices('age', 'Yosh chiziqlari', FaceConfig.ageCount, labels: FaceConfig.ageLabels, zoom: _browZoom),
        _toggle('glasses', tr('Ko‘zoynak')),
        _toggle('freckles', 'Sepkil'),
        _choices('accessory', 'Aksessuar', FaceConfig.accessoryCount, labels: FaceConfig.accessoryLabels),
      ],
    ];
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FaceAvatar(config: value, size: 136, shirt: widget.shirt),
            ),
            const SizedBox(width: 14),
            // How the portrait reads at list size.
            Column(
              children: [
                FaceAvatar(config: value, size: 44, shirt: widget.shirt, circle: true),
                const SizedBox(height: 6),
                FaceAvatar(config: value, size: 28, shirt: widget.shirt, circle: true),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () async {
                final face = await faceFromPhoto(context, value);
                if (face != null && mounted) setState(() => _set(face));
              },
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(tr('Rasmdan yuz')),
            ),
            TextButton.icon(
              onPressed: _undo.isEmpty
                  ? null
                  : () => setState(() => widget.onChanged(_undo.removeLast())),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: Text(tr('Orqaga')),
            ),
            TextButton.icon(
              onPressed: () => _set(const FaceConfig()),
              icon: const Icon(Icons.face_outlined, size: 18),
              label: Text(tr('Standart')),
            ),
            TextButton.icon(
              onPressed: _random,
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: Text(widget.nationality == null ? tr('Tasodifiy') : trf('Tasodifiy ({0})', [tr(widget.nationality!)])),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PillTabsInline(
            labels: [tr('Yuz'), tr('Ko‘z'), 'Soch', 'Soqol', 'Boshqa'],
            index: tab,
            onChanged: (i) => setState(() => tab = i),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: sections[tab],
          ),
        ),
      ],
    );
  }
}

/// Lightweight segmented control (kept here to avoid a widgets import cycle).
class PillTabsInline extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const PillTabsInline({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: i == index ? AppColors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: i == index
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  tr(labels[i]),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: i == index ? AppColors.ink : AppColors.ink2,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<FaceConfig?> editFace(
  BuildContext context,
  FaceConfig initial, {
  Color shirt = const Color(0xFF2B3A55),
  String? nationality,
  int? age,
}) => Navigator.push<FaceConfig>(
  context,
  MaterialPageRoute(builder: (_) => _FaceEditor(initial, shirt, nationality, age)),
);

class _FaceEditor extends StatefulWidget {
  final FaceConfig initial;
  final Color shirt;
  final String? nationality;
  final int? age;
  const _FaceEditor(this.initial, this.shirt, this.nationality, this.age);
  @override
  State<_FaceEditor> createState() => _FaceEditorState();
}

class _FaceEditorState extends State<_FaceEditor> {
  late FaceConfig current = widget.initial;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    appBar: AppBar(
      title: Text(tr('Portret yaratish')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, current),
          child: Text(tr('Saqlash')),
        ),
      ],
    ),
    body: FaceStudio(
      value: current,
      shirt: widget.shirt,
      nationality: widget.nationality,
      age: widget.age,
      onChanged: (v) => setState(() => current = v),
    ),
  );
}
