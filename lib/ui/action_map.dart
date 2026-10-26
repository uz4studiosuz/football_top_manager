import 'dart:math';
import 'package:flutter/material.dart';
import '../models/league.dart';
import '../l10n/l10n.dart';
import 'football_pitch.dart';
import 'widgets.dart';

/// SofaScore-style action map: the pitch with one player's passes or
/// dribbles as arrows (green worked, red failed) or his defensive actions
/// as dots. The player always attacks to the right.
class ActionMap extends StatelessWidget {
  final List<PlayerAction> actions;
  final bool arrows;
  const ActionMap({super.key, required this.actions, this.arrows = true});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AspectRatio(
        aspectRatio: 105 / 68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: _ActionPainter(actions, arrows)),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Icon(Icons.keyboard_double_arrow_right_rounded, size: 16, color: AppColors.ink3),
          const SizedBox(width: 4),
          Text(tr('Hujum yo‘nalishi'), style: AppText.caption),
          const Spacer(),
          if (arrows) ...[
            _dot(const Color(0xFF5FD38A)),
            Text(' ${tr('Aniq')}   ', style: AppText.caption),
            _dot(const Color(0xFFFF7A6E)),
            Text(' ${tr('Aniq emas')}', style: AppText.caption),
          ],
        ],
      ),
    ],
  );

  Widget _dot(Color c) => Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  static Color kindColor(ActionKind k) => switch (k) {
    ActionKind.tackle => const Color(0xFF2E86DE),
    ActionKind.interception => const Color(0xFF8E44AD),
    ActionKind.clearance => const Color(0xFFF39C12),
    ActionKind.block => const Color(0xFF16A085),
    ActionKind.aerial => const Color(0xFFE67E22),
    ActionKind.foul => const Color(0xFFC0392B),
    _ => Colors.white,
  };
}

class _ActionPainter extends CustomPainter {
  final List<PlayerAction> actions;
  final bool arrows;
  _ActionPainter(this.actions, this.arrows);

  @override
  void paint(Canvas canvas, Size size) {
    const inset = EdgeInsets.all(4);
    const FootballPitchPainter(
      vertical: false,
      inset: inset,
      grass: Color(0xFF3C8D5C),
      grassAlt: Color(0xFF368453),
    ).paint(canvas, size);
    final r = FootballPitchPainter.field(size, inset);
    Offset at(Offset o) => Offset(r.left + o.dx * r.width, r.top + o.dy * r.height);
    for (final a in actions) {
      final color = arrows ? (a.ok ? const Color(0xFF9CF5B5) : const Color(0xFFFF7A6E)) : ActionMap.kindColor(a.kind);
      if (arrows) {
        final from = at(a.from), to = at(a.to);
        final line = Paint()
          ..color = color.withValues(alpha: 0.9)
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, line);
        final d = to - from;
        if (d.distance > 6) {
          final ang = atan2(d.dy, d.dx);
          for (final s in [-0.45, 0.45]) {
            canvas.drawLine(to, to - Offset(cos(ang + s), sin(ang + s)) * 6, line);
          }
        }
        canvas.drawCircle(from, 2, Paint()..color = color);
      } else {
        final c = at(a.from);
        canvas.drawCircle(c, 5.2, Paint()..color = color.withValues(alpha: a.ok ? 1 : 0.45));
        canvas.drawCircle(
          c,
          5.2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActionPainter old) => old.actions != actions || old.arrows != arrows;
}
