import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../ui/football_pitch.dart';

class PlayerAttributesView extends StatelessWidget {
  final Player player;
  const PlayerAttributesView({super.key, required this.player});
  @override
  Widget build(BuildContext context) {
    final s = player.stats, values = s.toMap();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '26 atribut · 40–100',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pozitsiyaga mos vaznlar OVR’ni belgilaydi.',
                style: TextStyle(color: Color(0xFF637184), fontSize: 12),
              ),
              Center(
                child: SizedBox(
                  width: 280,
                  height: 240,
                  child: CustomPaint(
                    painter: _Radar(s, player.mainPosition.isGoalkeeper),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in <(String, int)>[
                    ('Tezlik', s.pace),
                    ('Zarba', s.shooting),
                    ('Pas', s.passing),
                    ('Texnika', s.dribblingStat),
                    ('Himoya', s.defending),
                    ('Jismoniy', s.physicality),
                  ])
                    Container(
                      width: 90,
                      padding: const EdgeInsets.all(10),
                      color: const Color(0xFFF3F5F8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.$2}',
                            style: const TextStyle(
                              fontSize: 22,
                              color: Color(0xFF1769E0),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            item.$1,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF637184),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final group in PlayerStats.groups.entries)
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.key,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                for (final key in group.value)
                  _AttributeRow(PlayerStats.labels[key]!, values[key] as int),
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: value >= 80
                    ? const Color(0xFF1769E0)
                    : const Color(0xFF526174),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 4,
            backgroundColor: const Color(0xFFEDF1F5),
            color: value >= 80
                ? const Color(0xFF1769E0)
                : const Color(0xFF94A4B9),
          ),
        ),
      ],
    ),
  );
}

class _Radar extends CustomPainter {
  final PlayerStats s;
  final bool keeper;
  _Radar(this.s, this.keeper);
  @override
  void paint(Canvas canvas, Size size) {
    final values = keeper
        ? [s.gkAwareness, s.gkCatching, s.gkParrying, s.gkReflexes, s.gkReach]
        : [
            s.pace,
            s.shooting,
            s.passing,
            s.dribblingStat,
            s.defending,
            s.physicality,
          ];
    final labels = keeper
        ? ['AWA', 'CAT', 'PAR', 'REF', 'REA']
        : ['PAC', 'SHO', 'PAS', 'DRI', 'DEF', 'PHY'];
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 73.0;
    final p = Paint()
      ..color = const Color(0xFFDCE4EF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Offset point(int i, double r) =>
        center +
        Offset(
          cos(-pi / 2 + i * 2 * pi / values.length) * r,
          sin(-pi / 2 + i * 2 * pi / values.length) * r,
        );
    for (final ring in [0.4, 0.6, 0.8, 1.0]) {
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final v = point(i, radius * ring);
        if (i == 0) {
          path.moveTo(v.dx, v.dy);
        } else {
          path.lineTo(v.dx, v.dy);
        }
      }
      path.close();
      canvas.drawPath(path, p);
    }
    final polygon = Path();
    for (var i = 0; i < values.length; i++) {
      canvas.drawLine(center, point(i, radius), p);
      final v = point(i, radius * values[i] / 100);
      if (i == 0) {
        polygon.moveTo(v.dx, v.dy);
      } else {
        polygon.lineTo(v.dx, v.dy);
      }
      final label = TextPainter(
        text: TextSpan(
          text: '${labels[i]} ${values[i]}',
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF526174),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final at = point(i, radius + 27);
      label.paint(canvas, at - Offset(label.width / 2, label.height / 2));
    }
    polygon.close();
    canvas.drawPath(
      polygon,
      Paint()..color = const Color(0xFF1769E0).withValues(alpha: 0.12),
    );
    canvas.drawPath(
      polygon,
      Paint()
        ..color = const Color(0xFF1769E0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _Radar old) =>
      s != old.s || keeper != old.keeper;
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
    PlayerPosition.st: Offset(0.5, 0.10),
    PlayerPosition.cf: Offset(0.5, 0.19),
    PlayerPosition.ss: Offset(0.5, 0.28),
    PlayerPosition.lwf: Offset(0.14, 0.19),
    PlayerPosition.rwf: Offset(0.86, 0.19),
    PlayerPosition.amf: Offset(0.5, 0.4),
    PlayerPosition.lmf: Offset(0.14, 0.48),
    PlayerPosition.rmf: Offset(0.86, 0.48),
    PlayerPosition.cmf: Offset(0.5, 0.51),
    PlayerPosition.dmf: Offset(0.5, 0.63),
    PlayerPosition.lb: Offset(0.14, 0.76),
    PlayerPosition.rb: Offset(0.86, 0.76),
    PlayerPosition.cb: Offset(0.5, 0.77),
    PlayerPosition.gk: Offset(0.5, 0.92),
  };
  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Maydondagi pozitsion reytinglar',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ko‘k: asosiy · oq: muqobil · kulrang: begona pozitsiya. Pozitsiyani bosib tafsilotni ko‘ring.',
          style: TextStyle(fontSize: 12, color: Color(0xFF637184), height: 1.5),
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AspectRatio(
              aspectRatio: 0.65,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: const Color(0xFF15563E),
                  child: LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        const Positioned.fill(
                          child: CustomPaint(painter: FootballPitchPainter()),
                        ),
                        for (final e in locations.entries)
                          Positioned(
                            left: (e.value.dx * box.maxWidth - 27).clamp(
                              3,
                              box.maxWidth - 57,
                            ),
                            top: (e.value.dy * box.maxHeight - 20).clamp(
                              3,
                              box.maxHeight - 43,
                            ),
                            child: InkWell(
                              key: ValueKey('position_${e.key.code}'),
                              onTap: () => setState(() => selected = e.key),
                              child: Container(
                                width: 54,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: e.key == p.mainPosition
                                      ? const Color(0xFF1769E0)
                                      : p.altPositions.contains(e.key)
                                      ? Colors.white
                                      : const Color(0xFFE0E8E3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    width: e.key == selected ? 2 : 1,
                                    color: e.key == selected
                                        ? const Color(0xFFFFD66E)
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      e.key.code,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: e.key == p.mainPosition
                                            ? Colors.white
                                            : const Color(0xFF526174),
                                      ),
                                    ),
                                    Text(
                                      '${p.getEffectiveOVR(e.key)}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: e.key == p.mainPosition
                                            ? Colors.white
                                            : const Color(0xFF192B42),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selected.code} · ${selected.fullName}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pozitsion OVR: ${p.getEffectiveOVR(selected)} · Match kuchi: ${p.getMatchOVR(selected)}',
              ),
              const SizedBox(height: 8),
              Text(
                selected == p.mainPosition
                    ? 'Asosiy pozitsiya'
                    : p.altPositions.contains(selected)
                    ? 'Tanish muqobil pozitsiya'
                    : 'Pozitsiyaga moslashuv jarimasi qo‘llanadi',
                style: const TextStyle(color: Color(0xFF637184), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
