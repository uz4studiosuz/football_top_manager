import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../ui/football_pitch.dart';
import '../../ui/widgets.dart';

class PlayerAttributesView extends StatelessWidget {
  final Player player;
  const PlayerAttributesView({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final s = player.stats, values = s.toMap();
    final keeper = player.mainPosition.isGoalkeeper;
    final summary = <(String, int)>[
      ('TEZ', s.pace),
      ('ZRB', s.shooting),
      ('PAS', s.passing),
      ('DRI', s.dribblingStat),
      ('HIM', s.defending),
      ('JIS', s.physicality),
    ];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Atributlar xaritasi', icon: Icons.radar_rounded),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 240,
                  child: CustomPaint(painter: _Radar(s, keeper)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final item in summary)
                    Expanded(
                      child: Column(
                        children: [
                          ValueBadge(item.$2, size: 36),
                          const SizedBox(height: 4),
                          Text(item.$1, style: AppText.overline.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final group in PlayerStats.groups.entries)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(group.key, style: AppText.h3)),
                    ValueBadge(
                      (group.value.fold<int>(0, (a, k) => a + (values[k] as int)) / group.value.length).round(),
                      size: 30,
                      filled: false,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final key in group.value) _AttributeRow(PlayerStats.labels[key]!, values[key] as int),
              ],
            ),
          ),
      ],
    );
  }
}

class _AttributeRow extends StatelessWidget {
  final String label;
  final int value;
  const _AttributeRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final c = AppColors.attribute(value);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(label, style: AppText.small.copyWith(color: AppColors.ink))),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 6,
                backgroundColor: AppColors.surfaceAlt,
                color: c,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: AppText.number.copyWith(fontSize: 14, color: c),
            ),
          ),
        ],
      ),
    );
  }
}

class _Radar extends CustomPainter {
  final PlayerStats s;
  final bool keeper;
  _Radar(this.s, this.keeper);
  @override
  void paint(Canvas canvas, Size size) {
    final values = keeper
        ? [s.gkAwareness, s.gkCatching, s.gkParrying, s.gkReflexes, s.gkReach]
        : [s.pace, s.shooting, s.passing, s.dribblingStat, s.defending, s.physicality];
    final labels = keeper ? ['JOY', 'USH', 'QAY', 'REF', 'ETI'] : ['TEZ', 'ZRB', 'PAS', 'DRI', 'HIM', 'JIS'];
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 78.0;
    final grid = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Offset point(int i, double r) =>
        center + Offset(cos(-pi / 2 + i * 2 * pi / values.length) * r, sin(-pi / 2 + i * 2 * pi / values.length) * r);
    for (final ring in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final v = point(i, radius * ring);
        i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
      }
      canvas.drawPath(path..close(), grid);
    }
    final polygon = Path();
    for (var i = 0; i < values.length; i++) {
      canvas.drawLine(center, point(i, radius), grid);
      final v = point(i, radius * (values[i] - 30).clamp(0, 70) / 70);
      i == 0 ? polygon.moveTo(v.dx, v.dy) : polygon.lineTo(v.dx, v.dy);
      final label = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${labels[i]}\n',
              style: const TextStyle(fontFamily: 'Roboto', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink3),
            ),
            TextSpan(
              text: '${values[i]}',
              style: TextStyle(fontFamily: 'Roboto', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.attribute(values[i])),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final at = point(i, radius + 24);
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
    polygon.close();
    canvas.drawPath(polygon, Paint()..color = AppColors.primary.withValues(alpha: 0.16));
    canvas.drawPath(
      polygon,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _Radar old) => s != old.s || keeper != old.keeper;
}

class PositionRatingsView extends StatefulWidget {
  final Player player;
  const PositionRatingsView({super.key, required this.player});
  @override
  State<PositionRatingsView> createState() => _PositionRatingsViewState();
}

class _PositionRatingsViewState extends State<PositionRatingsView> {
  late PlayerPosition selected = widget.player.mainPosition;
  static const locations = <PlayerPosition, Offset>{
    PlayerPosition.cf: Offset(0.5, 0.13),
    PlayerPosition.ss: Offset(0.5, 0.28),
    PlayerPosition.lwf: Offset(0.15, 0.19),
    PlayerPosition.rwf: Offset(0.85, 0.19),
    PlayerPosition.amf: Offset(0.5, 0.40),
    PlayerPosition.lmf: Offset(0.15, 0.48),
    PlayerPosition.rmf: Offset(0.85, 0.48),
    PlayerPosition.cmf: Offset(0.5, 0.51),
    PlayerPosition.dmf: Offset(0.5, 0.63),
    PlayerPosition.lb: Offset(0.15, 0.76),
    PlayerPosition.rb: Offset(0.85, 0.76),
    PlayerPosition.cb: Offset(0.5, 0.77),
    PlayerPosition.gk: Offset(0.5, 0.92),
  };
  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader('Pozitsion reytinglar', icon: Icons.grid_view_rounded),
              const Text(
                'Asosiy pozitsiya ramkada, muqobillar oq nuqta bilan. Rang – reyting darajasi.',
                style: AppText.caption,
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: AspectRatio(
                    aspectRatio: 0.68,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LayoutBuilder(
                        builder: (context, box) => Stack(
                          children: [
                            const Positioned.fill(child: CustomPaint(painter: FootballPitchPainter(vertical: true))),
                            for (final e in locations.entries)
                              Positioned(
                                left: (e.value.dx * box.maxWidth - 27).clamp(3, box.maxWidth - 57),
                                top: (e.value.dy * box.maxHeight - 21).clamp(3, box.maxHeight - 45),
                                child: _tile(p, e.key),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Row(
            children: [
              ValueBadge(p.getEffectiveOVR(selected), size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${selected.code} · ${selected.fullName}', style: AppText.h3),
                    const SizedBox(height: 4),
                    Text('Match kuchi (charchoq bilan): ${p.getMatchOVR(selected)}', style: AppText.small),
                    const SizedBox(height: 2),
                    Text(
                      selected == p.mainPosition
                          ? 'Asosiy pozitsiya'
                          : p.altPositions.contains(selected)
                          ? 'Tanish muqobil pozitsiya'
                          : 'Pozitsiyaga moslashuv jarimasi qo‘llanadi',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(Player p, PlayerPosition pos) {
    final value = p.getEffectiveOVR(pos);
    final main = pos == p.mainPosition;
    final alt = p.altPositions.contains(pos);
    final c = AppColors.attribute(value);
    return InkWell(
      key: ValueKey('position_${pos.code}'),
      onTap: () => setState(() => selected = pos),
      child: Container(
        width: 54,
        height: 42,
        decoration: BoxDecoration(
          color: main || alt ? c : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            width: pos == selected ? 2.5 : (main ? 2 : 1),
            color: pos == selected ? const Color(0xFFFFE066) : (main ? Colors.white : Colors.white54),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              pos.code,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: main || alt ? Colors.white : AppColors.ink2),
            ),
            Text(
              '$value',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: main || alt ? Colors.white : c),
            ),
          ],
        ),
      ),
    );
  }
}
