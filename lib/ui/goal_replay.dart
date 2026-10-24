import 'dart:math';
import 'package:flutter/material.dart';
import '../services/match_field.dart';
import 'football_pitch.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

/// Replays a goal on the 2D pitch from recorded frames.
Future<void> showGoalReplay(BuildContext context, GoalReplay replay, Color homeColor, Color awayColor) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: _ReplayView(replay: replay, homeColor: homeColor, awayColor: awayColor),
    ),
  ),
);

class _ReplayView extends StatefulWidget {
  final GoalReplay replay;
  final Color homeColor, awayColor;
  const _ReplayView({required this.replay, required this.homeColor, required this.awayColor});
  @override
  State<_ReplayView> createState() => _ReplayViewState();
}

class _ReplayViewState extends State<_ReplayView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: max(1500, widget.replay.frames.length * 70)),
  )..forward();
  double _speed = 1;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.replay_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(trf('{0}′ · {1} – gol takrori', [widget.replay.minute, widget.replay.scorer]), style: AppText.h3),
            ),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 105 / 68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _ReplayPainter(widget.replay.frames, _c.value, widget.homeColor, widget.awayColor),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
            children: [
              IconButton(
                onPressed: () => _c.isAnimating ? _c.stop() : (_c.value >= 1 ? _c.forward(from: 0) : _c.forward()),
                icon: Icon(_c.isAnimating ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              Expanded(child: Slider(value: _c.value, onChanged: (v) => _c.value = v)),
              TextButton(
                onPressed: () => setState(() {
                  _speed = _speed == 1 ? 0.5 : 1;
                  final at = _c.value;
                  _c.duration = Duration(milliseconds: (max(1500, widget.replay.frames.length * 70) / _speed).round());
                  if (_c.isAnimating) _c.forward(from: at);
                }),
                child: Text(_speed == 1 ? '1x' : '0.5x'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReplayPainter extends CustomPainter {
  final List<ReplayFrame> frames;
  final double t;
  final Color home, away;
  _ReplayPainter(this.frames, this.t, this.home, this.away);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = EdgeInsets.all(6);
    const FootballPitchPainter(vertical: false, inset: inset).paint(canvas, size);
    if (frames.isEmpty) return;
    final r = FootballPitchPainter.field(size, inset);
    Offset at(Offset p) => Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);
    final pos = t * (frames.length - 1);
    final i = pos.floor().clamp(0, frames.length - 1), j = min(i + 1, frames.length - 1);
    final k = pos - i;
    final a = frames[i], b = frames[j];
    Offset mix(Offset x, Offset y) => Offset.lerp(x, y, k)!;
    final radius = max(4.5, size.height * 0.024);
    void team(List<Offset> pa, List<Offset> pb, Color color) {
      for (var n = 0; n < min(pa.length, pb.length); n++) {
        final c = at(mix(pa[n], pb[n]));
        canvas.drawCircle(c, radius, Paint()..color = n == 0 ? Color.lerp(color, Colors.black, 0.25)! : color);
        canvas.drawCircle(c, radius, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }
    }

    team(a.home, b.home, home);
    team(a.away, b.away, away);
    // Ball trail of the last frames.
    final trail = Path();
    for (var n = max(0, i - 8); n <= i; n++) {
      final p = at(frames[n].ball);
      n == max(0, i - 8) ? trail.moveTo(p.dx, p.dy) : trail.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(trail, Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final h = a.ballHeight + (b.ballHeight - a.ballHeight) * k;
    final ball = at(mix(a.ball, b.ball)) - Offset(0, h * radius * 1.6);
    canvas.drawCircle(ball, radius * 0.55, Paint()..color = Colors.white);
    canvas.drawCircle(ball, radius * 0.55, Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant _ReplayPainter old) => old.t != t;
}
