import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// Crest outlines. None is a copy of a real badge; the families only evoke
/// the silhouette clubs are known for (roundels, pointed shields, heaters...).
enum CrestShape {
  shield('Klassik'),
  modernShield('Modern'),
  circle('Doira'),
  oval('Oval'),
  roundel('Halqa'),
  pointed('Uchli'),
  heater('Qalqon'),
  badge('Nishon'),
  hexagon('Olti burchak'),
  diamond('Olmos'),
  pennant('Bayroqcha');

  const CrestShape(this._label);
  final String _label;
  String get label => tr(_label);
}

enum CrestPattern {
  solid('Silliq'),
  verticalStripes('Chiziqli'),
  pinstripes('Ingichka'),
  hoops('Gorizontal'),
  diagonalSash('Diagonal'),
  halves('Ikkiga'),
  quarters('To‘rtga'),
  lozenges('Romblar'),
  chevron('Burchak'),
  rings('Halqalar'),
  splitCross('Xoch va chiziq'),
  cross('Xoch'),
  checks('Katakli'),
  rays('Nurlar'),
  frame('Ramka');

  const CrestPattern(this._label);
  final String _label;
  String get label => tr(_label);
}

enum CrestEmblem {
  monogram('Harflar'),
  ball('To‘p'),
  star('Yulduz'),
  cannon('To‘p-zambarak'),
  bird('Qush'),
  ship('Kema'),
  tower('Minora'),
  lion('Sher'),
  trident('Sanchqi'),
  tree('Daraxt'),
  hammers('Bolg‘alar'),
  wolf('Bo‘ri'),
  anchor('Langar'),
  bolt('Chaqmoq'),
  sun('Quyosh'),
  crescent('Yarim oy'),
  swords('Qilichlar'),
  flame('Olov'),
  mountain('Tog‘'),
  gem('Olmos tosh');

  const CrestEmblem(this._label);
  final String _label;
  String get label => tr(_label);
}

@immutable
class ClubCrestConfig {
  final CrestShape shape;
  final CrestPattern pattern;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trimColor;
  final String monogram;
  final int stars;
  final CrestEmblem emblem;
  final bool crown;
  final String? ringText;
  final Color? ringColor;

  /// A laurel wreath around the badge.
  final bool laurel;
  const ClubCrestConfig({
    required this.shape,
    required this.pattern,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trimColor,
    required this.monogram,
    this.stars = 0,
    this.emblem = CrestEmblem.monogram,
    this.crown = false,
    this.ringText,
    this.ringColor,
    this.laurel = false,
  });

  ClubCrestConfig copyWith({
    CrestShape? shape,
    CrestPattern? pattern,
    Color? primaryColor,
    Color? secondaryColor,
    Color? trimColor,
    String? monogram,
    int? stars,
    CrestEmblem? emblem,
    bool? crown,
    String? ringText,
    Color? ringColor,
    bool? laurel,
  }) => ClubCrestConfig(
    shape: shape ?? this.shape,
    pattern: pattern ?? this.pattern,
    primaryColor: primaryColor ?? this.primaryColor,
    secondaryColor: secondaryColor ?? this.secondaryColor,
    trimColor: trimColor ?? this.trimColor,
    monogram: monogram ?? this.monogram,
    stars: stars ?? this.stars,
    emblem: emblem ?? this.emblem,
    crown: crown ?? this.crown,
    ringText: ringText ?? this.ringText,
    ringColor: ringColor ?? this.ringColor,
    laurel: laurel ?? this.laurel,
  );

  Map<String, dynamic> toMap() => {
    'shape': shape.name,
    'pattern': pattern.name,
    'primaryColor': primaryColor.toARGB32(),
    'secondaryColor': secondaryColor.toARGB32(),
    'trimColor': trimColor.toARGB32(),
    'monogram': monogram,
    'stars': stars,
    'emblem': emblem.name,
    'crown': crown,
    'ringText': ?ringText,
    'ringColor': ?ringColor?.toARGB32(),
    if (laurel) 'laurel': true,
  };

  factory ClubCrestConfig.fromMap(Map m) => ClubCrestConfig(
    shape: CrestShape.values.asNameMap()[m['shape']] ?? CrestShape.shield,
    pattern:
        CrestPattern.values.asNameMap()[m['pattern']] ?? CrestPattern.solid,
    primaryColor: Color(m['primaryColor']),
    secondaryColor: Color(m['secondaryColor']),
    trimColor: Color(m['trimColor']),
    monogram: m['monogram'] ?? 'FC',
    stars: m['stars'] ?? 0,
    emblem:
        CrestEmblem.values.asNameMap()[m['emblem']] ?? CrestEmblem.monogram,
    crown: m['crown'] == true,
    ringText: m['ringText'],
    ringColor: m['ringColor'] == null ? null : Color(m['ringColor']),
    laurel: m['laurel'] == true,
  );

  @override
  bool operator ==(Object other) =>
      other is ClubCrestConfig && _key == other._key;
  @override
  int get hashCode => _key.hashCode;
  String get _key => toMap().toString();
}

/// Vector crest painter – no bitmap assets.
class ClubCrestPainter extends CustomPainter {
  final ClubCrestConfig config;
  ClubCrestPainter({required this.config});

  bool get _ring => config.shape == CrestShape.roundel;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    // Ornaments (crown / stars) take the top band; the badge sits below.
    final hasTop = config.crown || config.stars > 0;
    final top = hasTop ? s * (config.crown ? 0.22 : 0.13) : 0.0;
    final body = Rect.fromLTWH(
      hasTop ? s * 0.08 : 0,
      top,
      hasTop ? s * 0.84 : s,
      s - top - (hasTop ? s * 0.0 : 0),
    );
    final side = min(body.width, body.height) * (config.laurel ? 0.82 : 1);
    final square = Rect.fromCenter(center: body.center, width: side, height: side);
    if (config.laurel) _drawLaurel(canvas, square);
    if (config.crown) _drawCrown(canvas, s, square);
    if (config.stars > 0 && !config.crown) _drawStars(canvas, s, square);
    final outline = _shapePath(config.shape, square);
    // Soft drop shadow for depth.
    canvas.drawPath(
      outline.shift(Offset(0, s * 0.015)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.015),
    );
    if (_ring) {
      _drawRoundel(canvas, square, s);
    } else {
      canvas.save();
      canvas.clipPath(outline);
      canvas.drawRect(square, Paint()..color = config.primaryColor);
      _drawPattern(canvas, square);
      _drawGloss(canvas, square);
      canvas.restore();
      canvas.drawPath(
        outline,
        Paint()
          ..color = config.trimColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = square.width * 0.055,
      );
      final inner = _shapePath(config.shape, square.deflate(square.width * 0.075));
      canvas.drawPath(
        inner,
        Paint()
          ..color = config.trimColor.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = square.width * 0.014,
      );
      _drawCenter(canvas, square.deflate(square.width * 0.16));
    }
    canvas.restore();
  }

  // ---------------------------------------------------------------- shapes
  Path _shapePath(CrestShape shape, Rect r) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    Offset p(double fx, double fy) => Offset(x + w * fx, y + h * fy);
    final path = Path();
    switch (shape) {
      case CrestShape.shield:
        path
          ..moveTo(p(0.08, 0.06).dx, p(0.08, 0.06).dy)
          ..lineTo(p(0.92, 0.06).dx, p(0.92, 0.06).dy)
          ..lineTo(p(0.92, 0.55).dx, p(0.92, 0.55).dy)
          ..quadraticBezierTo(p(0.9, 0.86).dx, p(0.9, 0.86).dy, p(0.5, 0.98).dx, p(0.5, 0.98).dy)
          ..quadraticBezierTo(p(0.1, 0.86).dx, p(0.1, 0.86).dy, p(0.08, 0.55).dx, p(0.08, 0.55).dy)
          ..close();
      case CrestShape.modernShield:
        path
          ..moveTo(p(0.5, 0.02).dx, p(0.5, 0.02).dy)
          ..lineTo(p(0.93, 0.13).dx, p(0.93, 0.13).dy)
          ..lineTo(p(0.9, 0.62).dx, p(0.9, 0.62).dy)
          ..quadraticBezierTo(p(0.78, 0.88).dx, p(0.78, 0.88).dy, p(0.5, 0.99).dx, p(0.5, 0.99).dy)
          ..quadraticBezierTo(p(0.22, 0.88).dx, p(0.22, 0.88).dy, p(0.1, 0.62).dx, p(0.1, 0.62).dy)
          ..lineTo(p(0.07, 0.13).dx, p(0.07, 0.13).dy)
          ..close();
      case CrestShape.circle:
      case CrestShape.roundel:
        path.addOval(r.deflate(w * 0.03));
      case CrestShape.oval:
        path.addOval(Rect.fromLTRB(x + w * 0.12, y + h * 0.02, x + w * 0.88, y + h * 0.98));
      case CrestShape.pointed:
        // Amphora-like: notched shoulders, swelling sides, sharp base.
        path
          ..moveTo(p(0.06, 0.08).dx, p(0.06, 0.08).dy)
          ..lineTo(p(0.2, 0.02).dx, p(0.2, 0.02).dy)
          ..lineTo(p(0.32, 0.08).dx, p(0.32, 0.08).dy)
          ..lineTo(p(0.5, 0.04).dx, p(0.5, 0.04).dy)
          ..lineTo(p(0.68, 0.08).dx, p(0.68, 0.08).dy)
          ..lineTo(p(0.8, 0.02).dx, p(0.8, 0.02).dy)
          ..lineTo(p(0.94, 0.08).dx, p(0.94, 0.08).dy)
          ..quadraticBezierTo(p(0.98, 0.42).dx, p(0.98, 0.42).dy, p(0.82, 0.66).dx, p(0.82, 0.66).dy)
          ..quadraticBezierTo(p(0.66, 0.86).dx, p(0.66, 0.86).dy, p(0.5, 0.99).dx, p(0.5, 0.99).dy)
          ..quadraticBezierTo(p(0.34, 0.86).dx, p(0.34, 0.86).dy, p(0.18, 0.66).dx, p(0.18, 0.66).dy)
          ..quadraticBezierTo(p(0.02, 0.42).dx, p(0.02, 0.42).dy, p(0.06, 0.08).dx, p(0.06, 0.08).dy)
          ..close();
      case CrestShape.heater:
        // Concave top edge, straight flanks, rounded point.
        path
          ..moveTo(p(0.08, 0.04).dx, p(0.08, 0.04).dy)
          ..quadraticBezierTo(p(0.5, 0.16).dx, p(0.5, 0.16).dy, p(0.92, 0.04).dx, p(0.92, 0.04).dy)
          ..lineTo(p(0.9, 0.5).dx, p(0.9, 0.5).dy)
          ..cubicTo(p(0.88, 0.76).dx, p(0.88, 0.76).dy, p(0.66, 0.9).dx, p(0.66, 0.9).dy, p(0.5, 0.99).dx, p(0.5, 0.99).dy)
          ..cubicTo(p(0.34, 0.9).dx, p(0.34, 0.9).dy, p(0.12, 0.76).dx, p(0.12, 0.76).dy, p(0.1, 0.5).dx, p(0.1, 0.5).dy)
          ..close();
      case CrestShape.badge:
        path.addRRect(
          RRect.fromRectAndRadius(r.deflate(w * 0.06), Radius.circular(w * 0.2)),
        );
      case CrestShape.hexagon:
        path.addPath(_polygon(r.center, w * 0.48, 6, -pi / 2), Offset.zero);
      case CrestShape.diamond:
        path
          ..moveTo(p(0.5, 0.01).dx, p(0.5, 0.01).dy)
          ..lineTo(p(0.97, 0.5).dx, p(0.97, 0.5).dy)
          ..lineTo(p(0.5, 0.99).dx, p(0.5, 0.99).dy)
          ..lineTo(p(0.03, 0.5).dx, p(0.03, 0.5).dy)
          ..close();
      case CrestShape.pennant:
        // A banner hanging from a bar, with a swallow-tail notch.
        path
          ..moveTo(p(0.1, 0.04).dx, p(0.1, 0.04).dy)
          ..lineTo(p(0.9, 0.04).dx, p(0.9, 0.04).dy)
          ..lineTo(p(0.9, 0.98).dx, p(0.9, 0.98).dy)
          ..lineTo(p(0.5, 0.8).dx, p(0.5, 0.8).dy)
          ..lineTo(p(0.1, 0.98).dx, p(0.1, 0.98).dy)
          ..close();
    }
    return path;
  }

  // -------------------------------------------------------------- patterns
  void _drawPattern(Canvas canvas, Rect r) {
    final paint = Paint()..color = config.secondaryColor;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    switch (config.pattern) {
      case CrestPattern.solid:
        break;
      case CrestPattern.verticalStripes:
        for (var i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(x + w / 7 * i, y, w / 7, h), paint);
        }
      case CrestPattern.pinstripes:
        for (var i = 0; i < 12; i += 2) {
          canvas.drawRect(Rect.fromLTWH(x + w / 12 * i + w / 48, y, w / 24, h), paint);
        }
      case CrestPattern.hoops:
        for (var i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(x, y + h / 7 * i, w, h / 7), paint);
        }
      case CrestPattern.diagonalSash:
        canvas.drawPath(
          Path()
            ..moveTo(x, y + h * 0.62)
            ..lineTo(x + w * 0.62, y)
            ..lineTo(x + w * 0.9, y)
            ..lineTo(x, y + h * 0.9)
            ..close(),
          paint,
        );
      case CrestPattern.halves:
        canvas.drawRect(Rect.fromLTWH(x + w / 2, y, w / 2, h), paint);
      case CrestPattern.quarters:
        canvas.drawRect(Rect.fromLTWH(x + w / 2, y, w / 2, h / 2), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + h / 2, w / 2, h / 2), paint);
      case CrestPattern.lozenges:
        const n = 6;
        final cw = w / n, ch = h / n;
        for (var i = -1; i <= n; i++) {
          for (var j = -1; j <= n; j++) {
            if ((i + j).isEven) continue;
            final cx = x + cw * i + cw / 2, cy = y + ch * j + ch / 2;
            canvas.drawPath(
              Path()
                ..moveTo(cx, cy - ch / 2)
                ..lineTo(cx + cw / 2, cy)
                ..lineTo(cx, cy + ch / 2)
                ..lineTo(cx - cw / 2, cy)
                ..close(),
              paint,
            );
          }
        }
      case CrestPattern.chevron:
        canvas.drawPath(
          Path()
            ..moveTo(x, y + h * 0.42)
            ..lineTo(x + w / 2, y + h * 0.72)
            ..lineTo(x + w, y + h * 0.42)
            ..lineTo(x + w, y + h * 0.62)
            ..lineTo(x + w / 2, y + h * 0.92)
            ..lineTo(x, y + h * 0.62)
            ..close(),
          paint,
        );
      case CrestPattern.rings:
        final ring = Paint()
          ..color = config.secondaryColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.07;
        for (final f in [0.18, 0.32]) {
          canvas.drawCircle(r.center, w * f, ring);
        }
      case CrestPattern.splitCross:
        // Upper-left: cross on white; upper-right: vertical bars on gold;
        // lower half: club stripes; a band carries the monogram.
        final mid = y + h * 0.42;
        canvas.drawRect(Rect.fromLTRB(x, y, x + w / 2, mid), Paint()..color = Colors.white);
        final cross = Paint()..color = const Color(0xFFD6252B);
        canvas.drawRect(Rect.fromLTRB(x + w * 0.21, y, x + w * 0.29, mid), cross);
        canvas.drawRect(Rect.fromLTRB(x, y + h * 0.17, x + w / 2, y + h * 0.25), cross);
        canvas.drawRect(Rect.fromLTRB(x + w / 2, y, x + w, mid), Paint()..color = const Color(0xFFF7C600));
        for (var i = 0; i < 4; i++) {
          canvas.drawRect(Rect.fromLTWH(x + w / 2 + w / 16 + i * w / 8, y, w / 16, mid - y), cross);
        }
        canvas.drawRect(Rect.fromLTRB(x, mid, x + w, y + h), Paint()..color = config.primaryColor);
        for (var i = 1; i < 7; i += 2) {
          canvas.drawRect(Rect.fromLTWH(x + w / 7 * i, mid, w / 7, h), paint);
        }
        canvas.drawRect(
          Rect.fromLTRB(x, mid - h * 0.055, x + w, mid + h * 0.075),
          Paint()..color = config.trimColor,
        );
      case CrestPattern.cross:
        canvas.drawRect(Rect.fromLTWH(x + w * 0.4, y, w * 0.2, h), paint);
        canvas.drawRect(Rect.fromLTWH(x, y + h * 0.36, w, h * 0.2), paint);
      case CrestPattern.checks:
        const n = 6;
        for (var i = 0; i < n; i++) {
          for (var j = 0; j < n; j++) {
            if ((i + j).isOdd) canvas.drawRect(Rect.fromLTWH(x + w / n * i, y + h / n * j, w / n, h / n), paint);
          }
        }
      case CrestPattern.rays:
        for (var i = 0; i < 16; i += 2) {
          final a1 = i * pi / 8, a2 = (i + 1) * pi / 8;
          canvas.drawPath(
            Path()
              ..moveTo(r.center.dx, r.center.dy)
              ..lineTo(r.center.dx + cos(a1) * w, r.center.dy + sin(a1) * w)
              ..lineTo(r.center.dx + cos(a2) * w, r.center.dy + sin(a2) * w)
              ..close(),
            paint,
          );
        }
      case CrestPattern.frame:
        canvas.drawRect(
          r.deflate(w * 0.13),
          Paint()
            ..color = config.secondaryColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.08,
        );
    }
  }

  void _drawGloss(Canvas canvas, Rect r) {
    canvas.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0),
            Colors.black.withValues(alpha: 0.12),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(r),
    );
  }

  // --------------------------------------------------------------- roundel
  void _drawRoundel(Canvas canvas, Rect r, double s) {
    final outer = r.deflate(r.width * 0.03);
    final ringColor = config.ringColor ?? config.secondaryColor;
    canvas.drawOval(outer, Paint()..color = ringColor);
    canvas.drawOval(
      outer,
      Paint()
        ..color = config.trimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.03,
    );
    final inner = outer.deflate(outer.width * 0.17);
    canvas.save();
    canvas.clipPath(Path()..addOval(inner));
    canvas.drawRect(inner, Paint()..color = config.primaryColor);
    _drawPattern(canvas, inner);
    _drawGloss(canvas, inner);
    canvas.restore();
    canvas.drawOval(
      inner,
      Paint()
        ..color = config.trimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r.width * 0.022,
    );
    final text = (config.ringText ?? '').toUpperCase();
    if (text.isNotEmpty && s >= 34) {
      _ringText(
        canvas,
        outer.center,
        outer.width / 2 - outer.width * 0.085,
        text,
        outer.width * 0.085,
        ringColor.computeLuminance() > 0.55 ? const Color(0xFF14213D) : Colors.white,
      );
    } else if (s >= 20) {
      // Dots stand in for lettering at tiny sizes.
      final dot = Paint()
        ..color = (ringColor.computeLuminance() > 0.55 ? Colors.black : Colors.white)
            .withValues(alpha: 0.55);
      for (var i = 0; i < 16; i++) {
        final a = -pi / 2 + i * 2 * pi / 16;
        canvas.drawCircle(
          outer.center + Offset(cos(a), sin(a)) * (outer.width / 2 - outer.width * 0.085),
          outer.width * 0.012,
          dot,
        );
      }
    }
    _drawCenter(canvas, inner.deflate(inner.width * 0.14));
  }

  void _ringText(Canvas canvas, Offset c, double radius, String text, double fs, Color color) {
    final chars = text.split('');
    final painters = [
      for (final ch in chars)
        TextPainter(
          text: TextSpan(
            text: ch,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: fs,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
    ];
    final spacing = fs * 0.18;
    final total = painters.fold<double>(0, (a, p) => a + p.width + spacing);
    final maxArc = radius * pi * 1.55;
    final scale = total > maxArc ? maxArc / total : 1.0;
    var angle = -pi / 2 - (total * scale) / radius / 2;
    for (final p in painters) {
      final step = (p.width + spacing) * scale / radius;
      final a = angle + step / 2;
      canvas.save();
      canvas.translate(c.dx + cos(a) * radius, c.dy + sin(a) * radius);
      canvas.rotate(a + pi / 2);
      canvas.scale(scale, scale);
      p.paint(canvas, Offset(-p.width / 2, -p.height / 2));
      canvas.restore();
      angle += step;
    }
  }

  // ------------------------------------------------------------ ornaments
  void _drawCrown(Canvas canvas, double s, Rect body) {
    final cw = body.width * 0.62;
    final left = body.center.dx - cw / 2;
    final base = body.top - s * 0.01;
    final ch = s * 0.19;
    final gold = Paint()..color = config.trimColor;
    final dark = Paint()
      ..color = Color.lerp(config.trimColor, Colors.black, 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.01;
    final path = Path()
      ..moveTo(left, base)
      ..lineTo(left - cw * 0.04, base - ch * 0.62)
      ..lineTo(left + cw * 0.22, base - ch * 0.34)
      ..lineTo(left + cw * 0.32, base - ch * 0.78)
      ..lineTo(left + cw * 0.5, base - ch * 0.48)
      ..lineTo(left + cw * 0.68, base - ch * 0.78)
      ..lineTo(left + cw * 0.78, base - ch * 0.34)
      ..lineTo(left + cw * 1.04, base - ch * 0.62)
      ..lineTo(left + cw, base)
      ..close();
    canvas.drawPath(path, gold);
    canvas.drawPath(path, dark);
    canvas.drawRect(Rect.fromLTWH(left, base - ch * 0.16, cw, ch * 0.16), Paint()..color = Color.lerp(config.trimColor, Colors.black, 0.15)!);
    for (final fx in [-0.04, 0.32, 0.68, 1.04]) {
      canvas.drawCircle(Offset(left + cw * fx, base - ch * (fx == -0.04 || fx == 1.04 ? 0.66 : 0.82)), s * 0.022, gold);
    }
    // Orb and cross.
    final top = Offset(body.center.dx, base - ch * 0.62);
    canvas.drawCircle(top, s * 0.03, gold);
    canvas.drawRect(Rect.fromCenter(center: top - Offset(0, s * 0.055), width: s * 0.014, height: s * 0.05), gold);
    canvas.drawRect(Rect.fromCenter(center: top - Offset(0, s * 0.06), width: s * 0.04, height: s * 0.012), gold);
  }

  void _drawStars(Canvas canvas, double s, Rect body) {
    final n = config.stars.clamp(1, 5);
    final r = s * 0.045;
    final gap = r * 2.5;
    final start = body.center.dx - gap * (n - 1) / 2;
    for (var i = 0; i < n; i++) {
      canvas.drawPath(
        _star(Offset(start + gap * i, body.top - s * 0.06), r, r * 0.45),
        Paint()..color = config.trimColor,
      );
    }
  }

  Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -pi / 2 + i * pi / 5;
      final p = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  // ---------------------------------------------------------------- centre
  void _drawCenter(Canvas canvas, Rect r) {
    final color = config.trimColor;
    if (config.pattern == CrestPattern.splitCross) {
      _monogram(canvas, Rect.fromCenter(center: Offset(r.center.dx, r.top + r.height * 0.36), width: r.width, height: r.height * 0.22), color: config.primaryColor);
      if (config.emblem == CrestEmblem.ball) {
        _ball(canvas, Offset(r.center.dx, r.top + r.height * 0.74), r.width * 0.2);
      }
      return;
    }
    switch (config.emblem) {
      case CrestEmblem.monogram:
        _monogram(canvas, r, color: color);
      case CrestEmblem.ball:
        _ball(canvas, r.center, r.width * 0.34);
      case CrestEmblem.star:
        canvas.drawPath(_star(r.center, r.width * 0.42, r.width * 0.18), Paint()..color = color);
      case CrestEmblem.cannon:
        _cannon(canvas, r, color);
      case CrestEmblem.bird:
        _bird(canvas, r, color);
      case CrestEmblem.ship:
        _ship(canvas, r, color);
      case CrestEmblem.tower:
        _tower(canvas, r, color);
      case CrestEmblem.lion:
        _lion(canvas, r, color);
      case CrestEmblem.trident:
        _trident(canvas, r, color);
      case CrestEmblem.tree:
        _tree(canvas, r, color);
      case CrestEmblem.hammers:
        _hammers(canvas, r, color);
      case CrestEmblem.wolf:
        _wolf(canvas, r, color);
      case CrestEmblem.anchor:
        _anchor(canvas, r, color);
      case CrestEmblem.bolt:
        _bolt(canvas, r, color);
      case CrestEmblem.sun:
        _sun(canvas, r, color);
      case CrestEmblem.crescent:
        _crescent(canvas, r, color);
      case CrestEmblem.swords:
        _swords(canvas, r, color);
      case CrestEmblem.flame:
        _flame(canvas, r, color);
      case CrestEmblem.mountain:
        _mountain(canvas, r, color);
      case CrestEmblem.gem:
        _gem(canvas, r, color);
    }
  }

  // ------------------------------------------------------- more emblems
  void _anchor(Canvas canvas, Rect r, Color color) {
    final w = r.width, c = r.center;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c - Offset(0, w * 0.32), w * 0.08, stroke);
    canvas.drawLine(c - Offset(0, w * 0.24), c + Offset(0, w * 0.36), stroke);
    canvas.drawLine(c - Offset(w * 0.18, w * 0.12), c + Offset(w * 0.18, -w * 0.12), stroke);
    canvas.drawArc(Rect.fromCenter(center: c + Offset(0, w * 0.06), width: w * 0.66, height: w * 0.62), 0.25, pi - 0.5, false, stroke);
  }

  void _bolt(Canvas canvas, Rect r, Color color) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.58, y + h * 0.04)
        ..lineTo(x + w * 0.24, y + h * 0.56)
        ..lineTo(x + w * 0.46, y + h * 0.56)
        ..lineTo(x + w * 0.38, y + h * 0.96)
        ..lineTo(x + w * 0.76, y + h * 0.42)
        ..lineTo(x + w * 0.54, y + h * 0.42)
        ..close(),
      Paint()..color = color,
    );
  }

  void _sun(Canvas canvas, Rect r, Color color) {
    final w = r.width, c = r.center;
    final paint = Paint()..color = color;
    canvas.drawCircle(c, w * 0.2, paint);
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + cos(a - 0.12) * w * 0.26, c.dy + sin(a - 0.12) * w * 0.26)
          ..lineTo(c.dx + cos(a) * w * 0.44, c.dy + sin(a) * w * 0.44)
          ..lineTo(c.dx + cos(a + 0.12) * w * 0.26, c.dy + sin(a + 0.12) * w * 0.26)
          ..close(),
        paint,
      );
    }
  }

  void _crescent(Canvas canvas, Rect r, Color color) {
    final w = r.width, c = r.center;
    final outer = Path()..addOval(Rect.fromCircle(center: c - Offset(w * 0.06, 0), radius: w * 0.36));
    final cut = Path()..addOval(Rect.fromCircle(center: c + Offset(w * 0.08, -w * 0.04), radius: w * 0.3));
    canvas.drawPath(Path.combine(PathOperation.difference, outer, cut), Paint()..color = color);
    canvas.drawPath(_star(c + Offset(w * 0.22, -w * 0.02), w * 0.11, w * 0.05), Paint()..color = color);
  }

  void _swords(Canvas canvas, Rect r, Color color) {
    final w = r.width, c = r.center;
    final blade = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round;
    for (final dir in [1.0, -1.0]) {
      final tip = c + Offset(dir * w * 0.36, -w * 0.38);
      final hilt = c + Offset(-dir * w * 0.26, w * 0.28);
      canvas.drawLine(tip, hilt, blade);
      final guard = hilt + Offset(dir * w * 0.06, -w * 0.06);
      canvas.drawLine(guard + Offset(-w * 0.1, -w * 0.1 * dir * -1), guard + Offset(w * 0.1, w * 0.1 * dir * -1), blade);
    }
  }

  void _flame(Canvas canvas, Rect r, Color color) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.5, y + h * 0.02)
        ..cubicTo(x + w * 0.62, y + h * 0.3, x + w * 0.86, y + h * 0.42, x + w * 0.8, y + h * 0.7)
        ..cubicTo(x + w * 0.76, y + h * 0.9, x + w * 0.6, y + h * 0.98, x + w * 0.5, y + h * 0.98)
        ..cubicTo(x + w * 0.3, y + h * 0.98, x + w * 0.18, y + h * 0.84, x + w * 0.2, y + h * 0.64)
        ..cubicTo(x + w * 0.22, y + h * 0.46, x + w * 0.34, y + h * 0.4, x + w * 0.36, y + h * 0.24)
        ..cubicTo(x + w * 0.44, y + h * 0.36, x + w * 0.44, y + h * 0.46, x + w * 0.42, y + h * 0.52)
        ..cubicTo(x + w * 0.56, y + h * 0.44, x + w * 0.56, y + h * 0.22, x + w * 0.5, y + h * 0.02)
        ..close(),
      Paint()..color = color,
    );
  }

  void _mountain(Canvas canvas, Rect r, Color color) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.02, y + h * 0.86)
        ..lineTo(x + w * 0.36, y + h * 0.26)
        ..lineTo(x + w * 0.52, y + h * 0.52)
        ..lineTo(x + w * 0.66, y + h * 0.36)
        ..lineTo(x + w * 0.98, y + h * 0.86)
        ..close(),
      Paint()..color = color,
    );
    // Snow caps in the badge colour.
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.27, y + h * 0.42)
        ..lineTo(x + w * 0.36, y + h * 0.26)
        ..lineTo(x + w * 0.45, y + h * 0.42)
        ..lineTo(x + w * 0.36, y + h * 0.38)
        ..close(),
      Paint()..color = config.primaryColor,
    );
  }

  void _gem(Canvas canvas, Rect r, Color color) {
    final w = r.width, h = r.height, x = r.left, y = r.top;
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.22, y + h * 0.24)
        ..lineTo(x + w * 0.78, y + h * 0.24)
        ..lineTo(x + w * 0.94, y + h * 0.42)
        ..lineTo(x + w * 0.5, y + h * 0.92)
        ..lineTo(x + w * 0.06, y + h * 0.42)
        ..close(),
      paint,
    );
    final facet = Paint()
      ..color = config.primaryColor.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025;
    canvas.drawLine(Offset(x + w * 0.06, y + h * 0.42), Offset(x + w * 0.94, y + h * 0.42), facet);
    canvas.drawLine(Offset(x + w * 0.36, y + h * 0.24), Offset(x + w * 0.5, y + h * 0.92), facet);
    canvas.drawLine(Offset(x + w * 0.64, y + h * 0.24), Offset(x + w * 0.5, y + h * 0.92), facet);
  }

  /// Two laurel branches around the badge, tied at the bottom.
  void _drawLaurel(Canvas canvas, Rect body) {
    final c = body.center, rad = body.width * 0.6;
    final leaf = Paint()..color = config.trimColor;
    for (final side in [-1.0, 1.0]) {
      for (var i = 0; i < 8; i++) {
        final a = pi / 2 + side * (0.35 + i * 0.3);
        final at = c + Offset(cos(a), sin(a)) * rad;
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.rotate(a + side * 0.9);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: body.width * 0.09, height: body.width * 0.04), leaf);
        canvas.restore();
      }
    }
    canvas.drawCircle(c + Offset(0, rad * 0.98), body.width * 0.035, leaf);
  }

  void _monogram(Canvas canvas, Rect r, {required Color color}) {
    final text = config.monogram;
    final fs = r.height * (text.length <= 2 ? 0.62 : text.length == 3 ? 0.48 : 0.38);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fs,
          fontFamily: 'Roboto',
          fontWeight: FontWeight.w900,
          letterSpacing: -fs * 0.04,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.25), offset: Offset(0, fs * 0.03), blurRadius: fs * 0.04),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: r.width * 1.2);
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  void _ball(Canvas canvas, Offset c, double radius) {
    canvas.drawCircle(c, radius, Paint()..color = Colors.white);
    final dark = Paint()..color = const Color(0xFF1B1F27);
    canvas.drawPath(_polygon(c, radius * 0.38, 5, -pi / 2), dark);
    for (var i = 0; i < 5; i++) {
      final a = -pi / 2 + i * 2 * pi / 5;
      canvas.drawPath(_polygon(c + Offset(cos(a), sin(a)) * radius * 0.86, radius * 0.24, 5, a + pi), dark);
    }
    canvas.drawCircle(c, radius, Paint()
      ..color = const Color(0xFF1B1F27)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08);
  }

  Path _polygon(Offset c, double r, int n, double start) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a = start + i * 2 * pi / n;
      final pt = c + Offset(cos(a), sin(a)) * r;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  void _cannon(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    // Barrel, tapering toward the muzzle on the right.
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.08, y + h * 0.42)
        ..lineTo(x + w * 0.86, y + h * 0.36)
        ..lineTo(x + w * 0.92, y + h * 0.33)
        ..lineTo(x + w * 0.94, y + h * 0.5)
        ..lineTo(x + w * 0.86, y + h * 0.48)
        ..lineTo(x + w * 0.1, y + h * 0.62)
        ..quadraticBezierTo(x, y + h * 0.52, x + w * 0.08, y + h * 0.42)
        ..close(),
      paint,
    );
    canvas.drawCircle(Offset(x + w * 0.04, y + h * 0.52), w * 0.06, paint);
    // Carriage and wheel.
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.2, y + h * 0.6)
        ..lineTo(x + w * 0.62, y + h * 0.54)
        ..lineTo(x + w * 0.58, y + h * 0.72)
        ..lineTo(x + w * 0.16, y + h * 0.76)
        ..close(),
      paint,
    );
    canvas.drawCircle(Offset(x + w * 0.38, y + h * 0.76), w * 0.15, paint);
    canvas.drawCircle(
      Offset(x + w * 0.38, y + h * 0.76),
      w * 0.06,
      Paint()..color = config.primaryColor,
    );
  }

  void _bird(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    Offset p(double a, double b) => Offset(x + w * a, y + h * b);
    // Stylised long-necked bird: head with beak, raised wing, sturdy legs.
    final path = Path()
      ..moveTo(p(0.62, 0.08).dx, p(0.62, 0.08).dy)
      ..quadraticBezierTo(p(0.74, 0.06).dx, p(0.74, 0.06).dy, p(0.76, 0.16).dx, p(0.76, 0.16).dy)
      ..lineTo(p(0.9, 0.2).dx, p(0.9, 0.2).dy)
      ..lineTo(p(0.74, 0.24).dx, p(0.74, 0.24).dy)
      ..quadraticBezierTo(p(0.62, 0.36).dx, p(0.62, 0.36).dy, p(0.66, 0.52).dx, p(0.66, 0.52).dy)
      ..quadraticBezierTo(p(0.72, 0.72).dx, p(0.72, 0.72).dy, p(0.52, 0.78).dx, p(0.52, 0.78).dy)
      ..lineTo(p(0.56, 0.94).dx, p(0.56, 0.94).dy)
      ..lineTo(p(0.5, 0.94).dx, p(0.5, 0.94).dy)
      ..lineTo(p(0.46, 0.8).dx, p(0.46, 0.8).dy)
      ..lineTo(p(0.4, 0.94).dx, p(0.4, 0.94).dy)
      ..lineTo(p(0.34, 0.94).dx, p(0.34, 0.94).dy)
      ..lineTo(p(0.38, 0.78).dx, p(0.38, 0.78).dy)
      ..quadraticBezierTo(p(0.22, 0.72).dx, p(0.22, 0.72).dy, p(0.26, 0.56).dx, p(0.26, 0.56).dy)
      ..lineTo(p(0.08, 0.3).dx, p(0.08, 0.3).dy)
      ..quadraticBezierTo(p(0.3, 0.34).dx, p(0.3, 0.34).dy, p(0.42, 0.48).dx, p(0.42, 0.48).dy)
      ..quadraticBezierTo(p(0.48, 0.3).dx, p(0.48, 0.3).dy, p(0.56, 0.22).dx, p(0.56, 0.22).dy)
      ..quadraticBezierTo(p(0.54, 0.12).dx, p(0.54, 0.12).dy, p(0.62, 0.08).dx, p(0.62, 0.08).dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _ship(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.04, y + h * 0.66)
        ..lineTo(x + w * 0.96, y + h * 0.66)
        ..lineTo(x + w * 0.8, y + h * 0.86)
        ..lineTo(x + w * 0.2, y + h * 0.86)
        ..close(),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(x + w * 0.48, y + h * 0.06, w * 0.04, h * 0.6), paint);
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.46, y + h * 0.12)
        ..quadraticBezierTo(x + w * 0.22, y + h * 0.36, x + w * 0.16, y + h * 0.6)
        ..lineTo(x + w * 0.46, y + h * 0.6)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.54, y + h * 0.16)
        ..quadraticBezierTo(x + w * 0.8, y + h * 0.38, x + w * 0.84, y + h * 0.6)
        ..lineTo(x + w * 0.54, y + h * 0.6)
        ..close(),
      paint,
    );
    // Waves.
    final wave = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.035
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(x + w * 0.12, y + h * 0.94);
    for (var i = 0; i < 4; i++) {
      path.relativeQuadraticBezierTo(w * 0.095, -h * 0.05, w * 0.19, 0);
    }
    canvas.drawPath(path, wave);
  }

  void _tower(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.5, y + h * 0.02)
        ..lineTo(x + w * 0.54, y + h * 0.3)
        ..quadraticBezierTo(x + w * 0.6, y + h * 0.66, x + w * 0.82, y + h * 0.96)
        ..lineTo(x + w * 0.62, y + h * 0.96)
        ..quadraticBezierTo(x + w * 0.5, y + h * 0.76, x + w * 0.38, y + h * 0.96)
        ..lineTo(x + w * 0.18, y + h * 0.96)
        ..quadraticBezierTo(x + w * 0.4, y + h * 0.66, x + w * 0.46, y + h * 0.3)
        ..close(),
      paint,
    );
    final cut = Paint()..color = config.primaryColor;
    canvas.drawRect(Rect.fromLTWH(x + w * 0.38, y + h * 0.52, w * 0.24, h * 0.04), paint);
    canvas.drawRect(Rect.fromLTWH(x + w * 0.42, y + h * 0.3, w * 0.16, h * 0.03), paint);
    canvas.drawCircle(Offset(x + w * 0.5, y + h * 0.66), w * 0.035, cut);
  }

  void _trident(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawRect(Rect.fromLTWH(x + w * 0.46, y + h * 0.28, w * 0.08, h * 0.68), paint);
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.2, y + h * 0.1)
        ..lineTo(x + w * 0.28, y + h * 0.04)
        ..lineTo(x + w * 0.3, y + h * 0.3)
        ..quadraticBezierTo(x + w * 0.5, y + h * 0.42, x + w * 0.7, y + h * 0.3)
        ..lineTo(x + w * 0.72, y + h * 0.04)
        ..lineTo(x + w * 0.8, y + h * 0.1)
        ..lineTo(x + w * 0.78, y + h * 0.36)
        ..quadraticBezierTo(x + w * 0.5, y + h * 0.52, x + w * 0.22, y + h * 0.36)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.5, y + h * 0.0)
        ..lineTo(x + w * 0.58, y + h * 0.16)
        ..lineTo(x + w * 0.42, y + h * 0.16)
        ..close(),
      paint,
    );
    canvas.drawRect(Rect.fromLTWH(x + w * 0.47, y + h * 0.14, w * 0.06, h * 0.16), paint);
  }

  void _tree(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    canvas.drawRect(Rect.fromLTWH(x + w * 0.45, y + h * 0.55, w * 0.1, h * 0.32), paint);
    for (final c in [
      Offset(0.5, 0.22), Offset(0.3, 0.38), Offset(0.7, 0.38), Offset(0.4, 0.5), Offset(0.6, 0.5),
    ]) {
      canvas.drawCircle(Offset(x + w * c.dx, y + h * c.dy), w * 0.17, paint);
    }
    // Wavy river under the tree.
    final wave = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.04;
    final path = Path()..moveTo(x + w * 0.15, y + h * 0.93);
    for (var i = 0; i < 4; i++) {
      path.relativeQuadraticBezierTo(w * 0.0875, -h * 0.05, w * 0.175, 0);
    }
    canvas.drawPath(path, wave);
  }

  void _hammers(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height;
    for (final sign in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(sign * 0.65);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, h * 0.08), width: w * 0.08, height: h * 0.78), Radius.circular(w * 0.03)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -h * 0.3), width: w * 0.36, height: h * 0.16), Radius.circular(w * 0.03)),
        paint,
      );
      canvas.restore();
    }
  }

  void _wolf(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    Offset p(double a, double b) => Offset(x + w * a, y + h * b);
    // Angular wolf head facing left, ears up – drawn as facets.
    final head = Path()
      ..moveTo(p(0.62, 0.05).dx, p(0.62, 0.05).dy)
      ..lineTo(p(0.72, 0.32).dx, p(0.72, 0.32).dy)
      ..lineTo(p(0.86, 0.12).dx, p(0.86, 0.12).dy)
      ..lineTo(p(0.88, 0.5).dx, p(0.88, 0.5).dy)
      ..lineTo(p(0.74, 0.86).dx, p(0.74, 0.86).dy)
      ..lineTo(p(0.5, 0.96).dx, p(0.5, 0.96).dy)
      ..lineTo(p(0.44, 0.74).dx, p(0.44, 0.74).dy)
      ..lineTo(p(0.12, 0.62).dx, p(0.12, 0.62).dy)
      ..lineTo(p(0.2, 0.5).dx, p(0.2, 0.5).dy)
      ..lineTo(p(0.4, 0.42).dx, p(0.4, 0.42).dy)
      ..lineTo(p(0.5, 0.26).dx, p(0.5, 0.26).dy)
      ..close();
    canvas.drawPath(head, paint);
    final cut = Paint()..color = config.primaryColor;
    canvas.drawPath(
      Path()
        ..moveTo(p(0.52, 0.44).dx, p(0.52, 0.44).dy)
        ..lineTo(p(0.64, 0.4).dx, p(0.64, 0.4).dy)
        ..lineTo(p(0.6, 0.48).dx, p(0.6, 0.48).dy)
        ..close(),
      cut,
    );
    canvas.drawPath(
      Path()
        ..moveTo(p(0.44, 0.74).dx, p(0.44, 0.74).dy)
        ..lineTo(p(0.62, 0.62).dx, p(0.62, 0.62).dy)
        ..lineTo(p(0.56, 0.8).dx, p(0.56, 0.8).dy)
        ..close(),
      cut,
    );
  }

  void _lion(Canvas canvas, Rect r, Color color) {
    final paint = Paint()..color = color;
    final w = r.width, h = r.height, x = r.left, y = r.top;
    // Rampant lion silhouette, simplified to a few curves.
    final path = Path()
      ..moveTo(x + w * 0.3, y + h * 0.96)
      ..lineTo(x + w * 0.36, y + h * 0.66)
      ..quadraticBezierTo(x + w * 0.2, y + h * 0.5, x + w * 0.3, y + h * 0.32)
      ..quadraticBezierTo(x + w * 0.26, y + h * 0.12, x + w * 0.46, y + h * 0.06)
      ..quadraticBezierTo(x + w * 0.66, y + h * 0.04, x + w * 0.7, y + h * 0.2)
      ..lineTo(x + w * 0.86, y + h * 0.22)
      ..lineTo(x + w * 0.74, y + h * 0.3)
      ..quadraticBezierTo(x + w * 0.66, y + h * 0.4, x + w * 0.72, y + h * 0.46)
      ..lineTo(x + w * 0.92, y + h * 0.36)
      ..lineTo(x + w * 0.78, y + h * 0.54)
      ..quadraticBezierTo(x + w * 0.66, y + h * 0.6, x + w * 0.62, y + h * 0.7)
      ..lineTo(x + w * 0.72, y + h * 0.96)
      ..lineTo(x + w * 0.58, y + h * 0.96)
      ..lineTo(x + w * 0.5, y + h * 0.76)
      ..lineTo(x + w * 0.44, y + h * 0.96)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.3, y + h * 0.7)
        ..quadraticBezierTo(x + w * 0.04, y + h * 0.72, x + w * 0.12, y + h * 0.42)
        ..quadraticBezierTo(x + w * 0.12, y + h * 0.62, x + w * 0.3, y + h * 0.62)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ClubCrestPainter oldDelegate) =>
      oldDelegate.config != config;
}

/// Ready-to-use crest widget.
class ClubCrestWidget extends StatelessWidget {
  final ClubCrestConfig config;
  final double size;
  const ClubCrestWidget({super.key, required this.config, this.size = 48.0});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: ClubCrestPainter(config: config)),
  );
}
