import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../ui/football_pitch.dart';
import '../../ui/widgets.dart';
import '../../l10n/l10n.dart';

class PlayerAttributesView extends StatefulWidget {
  final Player player;
  const PlayerAttributesView({super.key, required this.player});
  @override
  State<PlayerAttributesView> createState() => _PlayerAttributesViewState();
}

class _PlayerAttributesViewState extends State<PlayerAttributesView> {
  bool twenty = true;
  static const technical = ['ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass', 'finishing', 'heading', 'setPieceTaking', 'curl', 'kickingPower'];
  static const tactical = ['attackingAwareness', 'defensiveAwareness', 'defensiveEngagement', 'tackling', 'aggression'];
  static const physical = ['speed', 'acceleration', 'jumping', 'physicalContact', 'balance', 'stamina'];
  static const goalkeeping = ['gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach'];

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final values = p.stats.toMap();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 10, spacing: 12, children: [
        Text(tr('Asosiy atributlar'), style: AppText.h2),
        SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('1–20')), ButtonSegment(value: false, label: Text('1–100'))],
          selected: {twenty}, onSelectionChanged: (v) => setState(() => twenty = v.first)),
      ]),
      const SizedBox(height: 12),
      AppCard(child: LayoutBuilder(builder: (context, box) => Wrap(spacing: 28, runSpacing: 14, children: [
        _summary(tr('Hozirgi salohiyat'), '${p.ovr}', AppColors.primary),
        _summary(tr('Potensial'), '${p.potential}', AppColors.teal),
        _summary(tr('Holat'), '${p.currentStamina}%', p.currentStamina < 60 ? AppColors.warning : AppColors.win),
        _summary(tr('Yosh'), '${p.age}', AppColors.ink),
      ]))),
      const SizedBox(height: 12),
      Text(twenty ? tr('1–20 ko‘rinishi: asl 1–100 atributlar beshga bo‘linib yaxlitlanadi. O‘yin hisobi o‘zgarmaydi.') : tr('Asl atributlar 1–100 shkalada ko‘rsatilgan.'), style: AppText.caption),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 780 ? 3 : box.maxWidth >= 510 ? 2 : 1;
        final width = (box.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(spacing: 14, runSpacing: 14, crossAxisAlignment: WrapCrossAlignment.start, children: [
          SizedBox(width: width, child: _table(tr('Texnik'), technical, values)),
          SizedBox(width: width, child: _table(tr('Taktik va himoyaviy'), tactical, values)),
          SizedBox(width: width, child: Column(children: [
            _table(tr('Jismoniy'), physical, values),
            const SizedBox(height: 14),
            _table(tr('Darvozabon'), goalkeeping, values),
          ])),
        ]);
      }),
      const SizedBox(height: 18),
      AppCard(padding: EdgeInsets.zero, child: ExpansionTile(
        title: Text(tr('Atributlar xaritasi'), style: AppText.bodyStrong),
        children: [SizedBox(width: 280, height: 240, child: CustomPaint(painter: _Radar(p.stats, p.mainPosition.isGoalkeeper)))],
      )),
      const SizedBox(height: 24),
    ]);
  }

  Widget _summary(String title, String value, Color color) => SizedBox(width: 125, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: AppText.caption), const SizedBox(height: 8), Text(value, style: AppText.h1.copyWith(color: color, fontFeatures: AppText.tabular)),
  ]));

  Widget _table(String title, List<String> keys, Map<String, dynamic> values) => AppCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Padding(padding: const EdgeInsets.all(12), child: Text(title, style: AppText.h3)),
    const Divider(),
    for (final (index, key) in keys.indexed) Container(
      color: index.isEven ? AppColors.surfaceAlt : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        Expanded(child: Text(tr(PlayerStats.labels[key]!), style: AppText.small.copyWith(color: AppColors.ink))),
        const SizedBox(width: 12),
        Text('${twenty ? ((values[key] as int) / 5).round().clamp(1, 20) : values[key]}', style: AppText.number.copyWith(
          color: (values[key] as int) >= 80 ? AppColors.win : (values[key] as int) >= 60 ? AppColors.warning : AppColors.ink3)),
      ]),
    ),
  ]));
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
              style: TextStyle(fontFamily: 'Roboto', fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink3),
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
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final p = widget.player;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('Pozitsion reytinglar'), icon: Icons.grid_view_rounded),
              Text(
                tr('Asosiy pozitsiya ramkada, muqobillar oq nuqta bilan. Rang – reyting darajasi.'),
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
                    Text(trf('Match kuchi (charchoq bilan): {0}', [p.getMatchOVR(selected)]), style: AppText.small),
                    const SizedBox(height: 2),
                    Text(
                      selected == p.mainPosition
                          ? tr('Asosiy pozitsiya')
                          : p.altPositions.contains(selected)
                          ? tr('Tanish muqobil pozitsiya')
                          : tr('Pozitsiyaga moslashuv jarimasi qo‘llanadi'),
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
          color: main || alt ? c : AppColors.surface,
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
