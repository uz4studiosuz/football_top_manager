import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import 'football_pitch.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

String _shooterName(ShotRecord s, Club home, Club away) =>
    (s.home ? home : away).playerById(s.playerId)?.name ?? tr('Futbolchi');

/// The recorded shot behind a goal incident (same scorer, closest minute).
ShotRecord? shotForGoal(List<ShotRecord> shots, MatchEvent e) {
  ShotRecord? best;
  for (final s in shots) {
    if (!s.goal || s.playerId != e.playerId) continue;
    if (best == null || (s.minute - e.minute).abs() < (best.minute - e.minute).abs()) best = s;
  }
  return best;
}

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint, {double dash = 5, double gap = 4}) {
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  for (var d = 0.0; d < total; d += dash + gap) {
    canvas.drawLine(a + dir * d, a + dir * min(total, d + dash), paint);
  }
}

// ------------------------------------------------------------------ map

/// Full-pitch shot map: tap a dot to see who shot, from where and how.
class ShotMapView extends StatefulWidget {
  final List<ShotRecord> shots;
  final Club home, away;
  final Color homeColor, awayColor;
  const ShotMapView({
    super.key,
    required this.shots,
    required this.home,
    required this.away,
    required this.homeColor,
    required this.awayColor,
  });
  @override
  State<ShotMapView> createState() => _ShotMapViewState();
}

class _ShotMapViewState extends State<ShotMapView> {
  int _filter = 0; // 0 all, 1 home, 2 away
  ShotRecord? _selected;

  List<ShotRecord> get _visible => [
    for (final s in widget.shots)
      if (_filter == 0 || (_filter == 1) == s.home) s,
  ];

  void _tap(Offset local, Size size) {
    final r = FootballPitchPainter.field(size, _ShotMapPainter.inset);
    ShotRecord? best;
    var bestD = 22.0;
    for (final s in _visible) {
      final o = Offset(r.left + s.origin.dx * r.width, r.top + s.origin.dy * r.height);
      final d = (o - local).distance;
      if (d < bestD) {
        bestD = d;
        best = s;
      }
    }
    setState(() => _selected = best);
  }

  void _step(int delta) {
    final list = _visible;
    if (list.isEmpty) return;
    final i = _selected == null ? -1 : list.indexOf(_selected!);
    setState(() => _selected = list[(i + delta) % list.length]);
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final visible = _visible;
    final selected = visible.contains(_selected) ? _selected : null;
    Widget chip(int i, String label) => Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(tr(label)),
        selected: _filter == i,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => setState(() => _filter = i),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            chip(0, 'Hammasi'),
            chip(1, widget.home.shortName),
            chip(2, widget.away.shortName),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 105 / 68,
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (d) => _tap(d.localPosition, box.biggest),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CustomPaint(
                  size: box.biggest,
                  painter: _ShotMapPainter(visible, selected, widget.homeColor, widget.awayColor),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (selected == null)
          Text(
            visible.isEmpty
                ? tr('Hali zarbalar yo‘q.')
                : tr('Doira kattaligi – xG, to‘ldirilgan – gol. Nuqtani bosing: kim va qanday tepgan.'),
            style: AppText.caption,
          )
        else ...[
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _step(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${visible.indexOf(selected) + 1} / ${visible.length}',
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _step(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          ShotDetails(
            shot: selected,
            home: widget.home,
            away: widget.away,
            color: selected.home ? widget.homeColor : widget.awayColor,
          ),
        ],
      ],
    );
  }
}

class _ShotMapPainter extends CustomPainter {
  static const inset = EdgeInsets.all(4);
  final List<ShotRecord> shots;
  final ShotRecord? selected;
  final Color home, away;
  _ShotMapPainter(this.shots, this.selected, this.home, this.away);

  @override
  void paint(Canvas canvas, Size size) {
    const FootballPitchPainter(
      vertical: false,
      inset: inset,
      grass: Color(0xFF3C8D5C),
      grassAlt: Color(0xFF368453),
    ).paint(canvas, size);
    final r = FootballPitchPainter.field(size, inset);
    Offset at(Offset p) => Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);
    for (final s in shots) {
      if (s == selected) continue;
      _dot(canvas, at(s.origin), s, s.home ? home : away, dim: selected != null);
    }
    final s = selected;
    if (s == null) return;
    final c = s.home ? home : away;
    if (s.assistFrom != null) {
      _dashed(canvas, at(s.assistFrom!), at(s.origin), Paint()
        ..color = Colors.white
        ..strokeWidth = 1.6);
    }
    canvas.drawLine(at(s.origin), at(s.end), Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2);
    _dot(canvas, at(s.origin), s, c, ring: true);
  }

  static void _dot(Canvas canvas, Offset o, ShotRecord s, Color c, {bool dim = false, bool ring = false}) {
    final radius = 3 + s.xg * 12;
    final a = dim ? 0.45 : 1.0;
    if (s.goal) {
      canvas.drawCircle(o, radius, Paint()..color = c.withValues(alpha: a));
      canvas.drawCircle(o, radius, Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
    } else {
      canvas.drawCircle(o, radius, Paint()..color = c.withValues(alpha: 0.25 * a));
      canvas.drawCircle(o, radius, Paint()
        ..color = c.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
    }
    if (ring) {
      canvas.drawCircle(o, radius + 3, Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _ShotMapPainter old) => true;
}

// --------------------------------------------------------------- details

/// Goalmouth view plus the SofaScore-style facts of one shot.
class ShotDetails extends StatelessWidget {
  final ShotRecord shot;
  final Club home, away;
  final Color color;
  final bool showHeader;
  const ShotDetails({
    super.key,
    required this.shot,
    required this.home,
    required this.away,
    required this.color,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final s = shot;
    final club = s.home ? home : away;
    final assist = s.assistId == null ? null : club.playerById(s.assistId!);
    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(tr(label), style: AppText.small)),
          Text(value, style: AppText.bodyStrong.copyWith(fontSize: 13)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Row(
            children: [
              Container(width: 4, height: 34, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_shooterName(s, home, away), style: AppText.bodyStrong),
                    Text('${club.shortName} · ${s.minute}′', style: AppText.caption),
                  ],
                ),
              ),
              _OutcomeChip(s),
            ],
          ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 3.4,
          child: CustomPaint(painter: GoalMouthPainter(s, color)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _BigNumber('xG', s.xg.toStringAsFixed(2))),
            Expanded(child: _BigNumber('xGOT', s.onTarget ? s.xgot.toStringAsFixed(2) : '–')),
          ],
        ),
        const Divider(height: 18),
        fact(tr('Vaziyat'), s.situationLabel),
        fact(tr('Zarba turi'), s.bodyLabel),
        fact(tr('Natija'), s.outcomeLabel),
        if (s.goal) fact(tr('Gol zonasi'), s.zoneLabel),
        fact(tr('Masofa'), '${_meters(s).round()} m'),
        if (assist != null) ...[
          const Divider(height: 18),
          Row(
            children: [
              const BootIcon(size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.goal ? trf('Assist: {0}', [assist.name]) : trf('Pas bergan: {0}', [assist.name]),
                  style: AppText.bodyStrong.copyWith(fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static double _meters(ShotRecord s) {
    final gx = s.home ? 1.0 : 0.0;
    final dx = (gx - s.origin.dx) * 105, dy = (s.origin.dy - 0.5) * 68;
    return sqrt(dx * dx + dy * dy);
  }
}

class _OutcomeChip extends StatelessWidget {
  final ShotRecord s;
  const _OutcomeChip(this.s);
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final c = switch (s.outcome) {
      'goal' => AppColors.win,
      'save' => AppColors.primary,
      'woodwork' => AppColors.warning,
      _ => AppColors.ink3,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(s.outcomeLabel, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _BigNumber extends StatelessWidget {
  final String label, value;
  const _BigNumber(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: AppText.h2),
      Text(tr(label), style: AppText.caption),
    ],
  );
}

/// Goal frame from the shooter's view with the ball where it crossed.
class GoalMouthPainter extends CustomPainter {
  final ShotRecord shot;
  final Color color;
  GoalMouthPainter(this.shot, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // x spans -0.5..1.5 goal widths, y spans 0..1.5 goal heights.
    final ground = size.height * 0.94;
    Offset at(double x, double y) => Offset((x + 0.5) / 2 * size.width, ground - y / 1.5 * ground);
    canvas.drawLine(Offset(0, ground), Offset(size.width, ground), Paint()
      ..color = AppColors.line
      ..strokeWidth = 2);
    final net = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    for (var i = 1; i < 12; i++) {
      final x = i / 12;
      canvas.drawLine(at(x, 0), at(x, 1), net);
    }
    for (var j = 1; j < 5; j++) {
      final y = j / 5;
      canvas.drawLine(at(0, y), at(1, y), net);
    }
    final frame = Paint()
      ..color = AppColors.ink2
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(at(0, 0).dx, at(0, 0).dy)
        ..lineTo(at(0, 1).dx, at(0, 1).dy)
        ..lineTo(at(1, 1).dx, at(1, 1).dy)
        ..lineTo(at(1, 0).dx, at(1, 0).dy),
      frame,
    );
    if (!shot.hasMouth) {
      final tp = TextPainter(
        text: TextSpan(text: tr('Zarba to‘sildi'), style: AppText.caption),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at(0.5, 0.5) - Offset(tp.width / 2, tp.height / 2));
      return;
    }
    final p = at(shot.mouthX.clamp(-0.48, 1.48), shot.mouthY.clamp(0.04, 1.44));
    final r = size.height * 0.075;
    if (shot.goal || shot.outcome == 'save') {
      canvas.drawCircle(p, r, Paint()..color = shot.goal ? color : Colors.white);
      canvas.drawCircle(p, r, Paint()
        ..color = shot.goal ? Colors.white : color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      if (shot.goal) {
        canvas.drawCircle(p, r + 2.5, Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }
    } else {
      final pen = Paint()
        ..color = AppColors.live
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(p - Offset(r * 0.7, r * 0.7), p + Offset(r * 0.7, r * 0.7), pen);
      canvas.drawLine(p - Offset(r * 0.7, -r * 0.7), p + Offset(r * 0.7, -r * 0.7), pen);
    }
  }

  @override
  bool shouldRepaint(covariant GoalMouthPainter old) => old.shot != shot;
}

/// Attacking half (goal on top) with the assist pass and the shot path.
class ShotPathPainter extends CustomPainter {
  final ShotRecord shot;
  final Color color;
  ShotPathPainter(this.shot, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final full = Size(size.width, size.height * 2);
    const inset = EdgeInsets.all(6);
    const FootballPitchPainter(vertical: true, inset: inset).paint(canvas, full);
    final r = FootballPitchPainter.field(full, inset);
    // Normalise so the shooter always attacks the top goal.
    Offset at(Offset p) {
      final q = shot.home ? p : Offset(1 - p.dx, 1 - p.dy);
      return Offset(r.left + q.dy * r.width, r.top + (1 - q.dx) * r.height);
    }

    if (shot.assistFrom != null) {
      _dashed(canvas, at(shot.assistFrom!), at(shot.origin), Paint()
        ..color = Colors.white
        ..strokeWidth = 2);
      canvas.drawCircle(at(shot.assistFrom!), 4, Paint()..color = Colors.white);
    }
    canvas.drawLine(at(shot.origin), at(shot.end), Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6);
    canvas.drawCircle(at(shot.origin), 7, Paint()..color = color);
    canvas.drawCircle(at(shot.origin), 7, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ShotPathPainter old) => old.shot != shot;
}

/// Bottom sheet opened from a goal incident.
Future<void> showShotDetailSheet(
  BuildContext context, {
  required ShotRecord shot,
  required Club home,
  required Club away,
  required Color color,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.9),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(shot.goal ? Icons.sports_soccer : Icons.adjust_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${shot.goal ? 'Gol' : 'Zarba'} · ${_shooterName(shot, home, away)}',
                    style: AppText.h3,
                  ),
                ),
                Text('${shot.minute}′', style: AppText.number),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 68 / 52.5,
                child: CustomPaint(painter: ShotPathPainter(shot, color)),
              ),
            ),
            const SizedBox(height: 12),
            ShotDetails(shot: shot, home: home, away: away, color: color, showHeader: false),
          ],
        ),
      ),
    ),
  ),
);

// ------------------------------------------------------------------ boot

/// Football boot glyph used for assists (like SofaScore's line-up marks).
class BootIcon extends StatelessWidget {
  final double size;
  final Color ? _color;
  Color get color=> _color ?? AppColors.ink;
  const BootIcon({super.key, this.size = 14, this._color});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size, size), painter: _BootPainter(color));
}

class _BootPainter extends CustomPainter {
  final Color color;
  _BootPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Side view, toe to the right: ankle collar, upper, sole and studs.
    final upper = Path()
      ..moveTo(w * 0.08, h * 0.12)
      ..lineTo(w * 0.40, h * 0.12)
      ..lineTo(w * 0.44, h * 0.40)
      ..quadraticBezierTo(w * 0.70, h * 0.42, w * 0.88, h * 0.55)
      ..quadraticBezierTo(w * 0.99, h * 0.62, w * 0.96, h * 0.74)
      ..lineTo(w * 0.06, h * 0.74)
      ..quadraticBezierTo(w * 0.02, h * 0.45, w * 0.08, h * 0.12)
      ..close();
    canvas.drawPath(upper, Paint()..color = color);
    // Laces / stripe.
    final stripe = Paint()
      ..color = Colors.white
      ..strokeWidth = max(1, w * 0.06)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.50, h * 0.47), Offset(w * 0.58, h * 0.62), stripe);
    canvas.drawLine(Offset(w * 0.62, h * 0.47), Offset(w * 0.70, h * 0.62), stripe);
    // Sole and studs.
    final sole = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromLTRBR(w * 0.04, h * 0.76, w * 0.97, h * 0.84, Radius.circular(h * 0.04)),
      sole,
    );
    for (final x in [0.14, 0.34, 0.62, 0.84]) {
      canvas.drawRect(Rect.fromLTWH(w * x, h * 0.84, w * 0.08, h * 0.1), sole);
    }
  }

  @override
  bool shouldRepaint(covariant _BootPainter old) => old.color != color;
}
