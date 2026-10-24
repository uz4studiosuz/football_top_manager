import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'football_pitch.dart';
import 'widgets.dart';

/// Grid size of recorded heatmaps (columns along the pitch, rows across).
const heatCols = 12, heatRows = 8;

/// Compact text form for saves: one base-36 digit per cell (0–35).
String encodeHeat(List<int> cells) {
  final top = cells.fold<int>(0, max);
  if (top == 0) return '';
  return String.fromCharCodes([
    for (final c in cells) ((c * 35 / top).round()).toRadixString(36).codeUnitAt(0),
  ]);
}

List<int>? decodeHeat(String? text) {
  if (text == null || text.length != heatCols * heatRows) return null;
  return [for (final ch in text.split('')) int.parse(ch, radix: 36)];
}

/// SofaScore-style heatmap: the player always attacks to the right.
class PlayerHeatmap extends StatelessWidget {
  final List<int> cells;
  const PlayerHeatmap({super.key, required this.cells});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(tr('Issiqlik xaritasi'), style: AppText.bodyStrong),
          const Spacer(),
          Text(tr('Hujum yo‘nalishi'), style: AppText.caption),
          const Icon(Icons.arrow_right_alt_rounded, size: 18, color: AppColors.ink3),
        ],
      ),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 105 / 68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: _HeatPainter(cells)),
        ),
      ),
    ],
  );
}

class _HeatPainter extends CustomPainter {
  final List<int> cells;
  _HeatPainter(this.cells);

  static const _ramp = [Color(0x0012A150), Color(0xAA12A150), Color(0xCCF5D90A), Color(0xDDF5A524), Color(0xEEE5352B)];

  Color _color(double t) {
    final x = t.clamp(0.0, 1.0) * (_ramp.length - 1);
    final i = x.floor().clamp(0, _ramp.length - 2);
    return Color.lerp(_ramp[i], _ramp[i + 1], x - i)!;
  }

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
    final top = cells.fold<int>(0, max);
    if (top == 0) return;
    final cw = r.width / heatCols, ch = r.height / heatRows;
    canvas.saveLayer(r, Paint());
    for (var y = 0; y < heatRows; y++) {
      for (var x = 0; x < heatCols; x++) {
        final v = cells[y * heatCols + x] / top;
        if (v < 0.04) continue;
        final c = Offset(r.left + (x + 0.5) * cw, r.top + (y + 0.5) * ch);
        final radius = max(cw, ch) * (0.9 + v * 0.6);
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..shader = RadialGradient(colors: [_color(v), _color(v).withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: radius)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) => old.cells != cells;
}
