import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'football_pitch.dart';
import 'widgets.dart';

/// Grid size of recorded heatmaps (columns along the pitch, rows across).
const heatCols = 18, heatRows = 12;

/// Compact text form for saves: one base-36 digit per cell (0–35).
String encodeHeat(List<int> cells) {
  final top = cells.fold<int>(0, max);
  if (top == 0) return '';
  return String.fromCharCodes([
    for (final c in cells) ((c * 35 / top).round()).toRadixString(36).codeUnitAt(0),
  ]);
}

List<int>? decodeHeat(String? text) {
  if (text == null) return null;
  final values = [for (final ch in text.split('')) int.tryParse(ch, radix: 36) ?? 0];
  if (values.length == heatCols * heatRows) return values;
  // Older saves used a 12×8 grid: scale it up.
  if (values.length == 96) {
    return [
      for (var y = 0; y < heatRows; y++)
        for (var x = 0; x < heatCols; x++) values[(y * 8 ~/ heatRows) * 12 + x * 12 ~/ heatCols],
    ];
  }
  return null;
}

/// SofaScore-style heatmap: the player always attacks to the right.
class PlayerHeatmap extends StatelessWidget {
  final List<int> cells;
  final bool showHeader;
  const PlayerHeatmap({super.key, required this.cells, this.showHeader = true});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (showHeader) ...[
        Row(
          children: [
            Flexible(child: Text(tr('Issiqlik xaritasi'), style: AppText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(tr('Hujum yo‘nalishi'), style: AppText.caption),
            Icon(Icons.arrow_right_alt_rounded, size: 18, color: AppColors.ink3),
          ],
        ),
        const SizedBox(height: 8),
      ],
      AspectRatio(
        aspectRatio: 105 / 68,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(painter: _HeatPainter(_smooth(cells))),
        ),
      ),
    ],
  );

  /// Upsamples the grid ×4 and blurs it with a small gaussian so the map
  /// reads as smooth zones of activity.
  static const _scale = 4;
  static List<double> _smooth(List<int> cells) {
    const w = heatCols * _scale, h = heatRows * _scale;
    final raw = List<double>.filled(w * h, 0);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        raw[y * w + x] = cells[(y ~/ _scale) * heatCols + x ~/ _scale].toDouble();
      }
    }
    const radius = 5;
    final kernel = [for (var i = -radius; i <= radius; i++) exp(-(i * i) / (2 * 2.2 * 2.2))];
    final ksum = kernel.reduce((a, b) => a + b);
    List<double> pass(List<double> src, bool horizontal) {
      final out = List<double>.filled(w * h, 0);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          var acc = 0.0;
          for (var k = -radius; k <= radius; k++) {
            final xx = horizontal ? (x + k).clamp(0, w - 1) : x;
            final yy = horizontal ? y : (y + k).clamp(0, h - 1);
            acc += src[yy * w + xx] * kernel[k + radius];
          }
          out[y * w + x] = acc / ksum;
        }
      }
      return out;
    }

    final blurred = pass(pass(raw, true), false);
    // Scaled against what a real match produces (a full game puts roughly
    // 15+ samples in a busy cell), not against the player's own hottest
    // cell: a short spell then stays pale instead of glowing red.
    final top = max(blurred.fold<double>(0, max), 14.0);
    return [for (final v in blurred) pow(v / top, 0.75).toDouble()];
  }
}

class _HeatPainter extends CustomPainter {
  final List<double> density;
  _HeatPainter(this.density);

  static const _ramp = [
    Color(0x00000000),
    Color(0x7036C26A),
    Color(0xB0C8E03C),
    Color(0xD0FFD21F),
    Color(0xE0FF8A1F),
    Color(0xF0F0342B),
  ];

  static Color _color(double t) {
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
    const w = heatCols * PlayerHeatmap._scale, h = heatRows * PlayerHeatmap._scale;
    final cw = r.width / w, ch = r.height / h;
    // A light blur hides the pixel grid.
    canvas.saveLayer(r, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: cw * 0.8, sigmaY: ch * 0.8));
    final paint = Paint();
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final v = density[y * w + x];
        if (v < 0.16) continue;
        paint.color = _color((v - 0.16) / 0.84);
        canvas.drawRect(Rect.fromLTWH(r.left + x * cw, r.top + y * ch, cw + 0.6, ch + 0.6), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) => old.density != density;
}
