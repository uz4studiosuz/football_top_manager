import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../ui/face_avatar.dart';
import '../ui/heatmap.dart';
import '../ui/match_widgets.dart';
import '../ui/shot_widgets.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';
import 'widgets/player_detail_view.dart';

/// Everything recorded about one match, for the per-player breakdown.
class PlayerMatchData {
  final Club home, away;
  final int homeScore, awayScore;
  final List<MatchEvent> events;
  final List<ShotRecord> shots;
  final List<double> momentum;
  final Map<String, PlayerMatchStats> lines;
  final Map<String, double> ratings;
  final List<int>? Function(String id) heatFor;
  const PlayerMatchData({
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.events,
    required this.shots,
    required this.momentum,
    required this.lines,
    required this.ratings,
    required this.heatFor,
  });

  /// Players who took part, home side first.
  List<(Player, Club)> get participants => [
    for (final c in [home, away])
      for (final p in c.squad)
        if ((lines[p.id]?.minutes ?? 0) > 0) (p, c),
  ];
}

/// SofaScore-style player page for one match: momentum with the player's
/// moments, rating breakdown, heatmap, shot map and grouped statistics.
class PlayerMatchScreen extends StatefulWidget {
  final PlayerMatchData data;
  final Player player;
  final Club club;
  const PlayerMatchScreen({super.key, required this.data, required this.player, required this.club});

  static Future<void> show(BuildContext context, PlayerMatchData data, Player player, Club club) =>
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => PlayerMatchScreen(data: data, player: player, club: club)),
      );

  @override
  State<PlayerMatchScreen> createState() => _PlayerMatchScreenState();
}

class _PlayerMatchScreenState extends State<PlayerMatchScreen> {
  late Player _player = widget.player;
  late Club _club = widget.club;
  int _tab = 0;
  int _moment = 0;

  PlayerMatchData get d => widget.data;
  PlayerMatchStats? get _line => d.lines[_player.id];

  static List<String> get _tabs => [
    tr('Umumiy'),
    tr('Statistika'),
    tr('Zarbalar'),
    tr('Paslar'),
    tr('Dribling'),
    tr('Himoya'),
  ];

  /// The player's key moments in time order.
  List<({int minute, String title, String text, IconData icon})> get _moments {
    final out = <({int minute, String title, String text, IconData icon})>[];
    for (final s in d.shots.where((s) => s.playerId == _player.id)) {
      final (title, icon) = switch (s.outcome) {
        'goal' => (tr('GOL'), Icons.sports_soccer),
        'save' => (tr('ZARBA QAYTARILDI'), Icons.back_hand_outlined),
        'block' => (tr('ZARBA TO‘SILDI'), Icons.block),
        'woodwork' => (tr('USTUNGA TEGDI'), Icons.crop_portrait),
        _ => (tr('ZARBA YONIDAN'), Icons.trending_flat),
      };
      out.add((
        minute: s.minute,
        title: title,
        text: trf('{0} · xG {1}', [_player.shortName, s.xg.toStringAsFixed(2)]),
        icon: icon,
      ));
    }
    for (final e in d.events) {
      if (e.assistPlayerId == _player.id) {
        out.add((minute: e.minute, title: tr('ASSIST'), text: e.description, icon: Icons.assistant_outlined));
      } else if (e.playerId == _player.id &&
          (e.type == MatchEventType.yellowCard ||
              e.type == MatchEventType.redCard ||
              e.type == MatchEventType.substitution ||
              e.type == MatchEventType.injury)) {
        out.add((
          minute: e.minute,
          title: e.type.label.toUpperCase(),
          text: e.description,
          icon: switch (e.type) {
            MatchEventType.yellowCard || MatchEventType.redCard => Icons.style,
            MatchEventType.injury => Icons.healing,
            _ => Icons.swap_vert,
          },
        ));
      }
    }
    out.sort((a, b) => a.minute.compareTo(b.minute));
    return out;
  }

  void _switch(Player p, Club c) => setState(() {
    _player = p;
    _club = c;
    _moment = 0;
  });

  @override
  Widget build(BuildContext context) {
    final colors = teamColors(d.home, d.away);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final moments = _moments;
    final header = _header();
    final momentum = _momentumCard(colors, moments);
    final tabs = _tabBar();
    final content = _content(colors);
    return Scaffold(
      appBar: AppBar(
        title: Text('${d.home.shortName} ${d.homeScore} – ${d.awayScore} ${d.away.shortName}'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              header,
              const SizedBox(height: 10),
              momentum,
              const SizedBox(height: 10),
              tabs,
              const SizedBox(height: 10),
              if (wide && _tab == 0)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _overviewLeft()),
                    const SizedBox(width: 12),
                    Expanded(child: _heatCard()),
                  ],
                )
              else
                content,
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(child: _switcher()),
    );
  }

  Widget _header() => AppCard(
    child: Row(
      children: [
        FaceAvatar(config: _player.face, size: 64, shirt: _club.primaryColor, trim: _club.secondaryColor, circle: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_player.name, style: AppText.h2, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PositionChip(_player.mainPosition.code),
                  Text('${_player.countryFlag} ${tr(_player.nationality)} · #${_player.number}', style: AppText.caption),
                  Text(_player.playingStyle.title, style: AppText.caption.copyWith(color: AppColors.primary)),
                ],
              ),
            ],
          ),
        ),
        RatingBadge(d.ratings[_player.id], size: 18),
        IconButton(
          tooltip: tr('Profilni ko‘rish'),
          onPressed: () => PlayerDetailView.show(context, player: _player, club: _club).then((_) {
            if (mounted) setState(() {}); // a portrait may have been edited
          }),
          icon: const Icon(Icons.person_outline),
        ),
      ],
    ),
  );

  Widget _momentumCard((Color, Color) colors, List<({int minute, String title, String text, IconData icon})> moments) {
    final m = moments.isEmpty ? null : moments[_moment.clamp(0, moments.length - 1)];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              MomentumChart(values: d.momentum, events: d.events, homeColor: colors.$1, awayColor: colors.$2, height: 90),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MomentMarks([for (final x in moments) x.minute], m?.minute, max(96, d.momentum.length)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (m == null)
            Text(tr('Bu o‘yinda alohida lahzalar yo‘q.'), style: AppText.caption)
          else
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(m.icon, size: 18, color: AppColors.ink2),
                      Text('${m.minute}′', style: AppText.caption.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title, style: AppText.bodyStrong),
                      Text(m.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.small),
                    ],
                  ),
                ),
                Text('${_moment + 1} / ${moments.length}', style: AppText.caption),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _moment > 0 ? () => setState(() => _moment--) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _moment < moments.length - 1 ? () => setState(() => _moment++) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tabBar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(_tabs[i]),
              selected: _tab == i,
              onSelected: (_) => setState(() => _tab = i),
            ),
          ),
      ],
    ),
  );

  Widget _content((Color, Color) colors) {
    final l = _line;
    if (l == null) return EmptyState(icon: Icons.bar_chart_rounded, text: tr('Bu o‘yinda maydonga tushmadi'));
    String pct(int a, int b) => b == 0 ? '0%' : '${(a * 100 / b).round()}%';
    return switch (_tab) {
      0 => Column(children: [_overviewLeft(), const SizedBox(height: 10), _heatCard()]),
      1 => _rowsCard(playerStatRows(_player, l)),
      2 => Column(
        children: [
          _rowsCard([
            (tr('Gollar'), '${l.goals}'),
            ('xG', l.xg.toStringAsFixed(2)),
            (tr('Zarbalar (nishonga)'), '${l.shots} (${l.shotsOnTarget})'),
            (tr('Boy berilgan katta imkoniyat'), '${l.bigChancesMissed}'),
            (tr('Ofsaydlar'), '${l.offsides}'),
          ]),
          const SizedBox(height: 10),
          AppCard(
            child: ShotMapView(
              shots: [for (final s in d.shots) if (s.playerId == _player.id) s],
              home: d.home,
              away: d.away,
              homeColor: colors.$1,
              awayColor: colors.$2,
            ),
          ),
        ],
      ),
      3 => _rowsCard([
        (tr('Aniq paslar'), '${l.passesCompleted}/${l.passes} (${pct(l.passesCompleted, l.passes)})'),
        (tr('Kalit paslar'), '${l.keyPasses}'),
        (tr('Assistlar'), '${l.assists}'),
        ('xA', l.xa.toStringAsFixed(2)),
        (tr('Yaratilgan katta imkoniyat'), '${l.bigChancesCreated}'),
        (tr('Krosslar'), '${l.crosses}'),
      ]),
      4 => _rowsCard([
        (tr('Driblinglar'), '${l.dribblesWon}/${l.dribbles} (${pct(l.dribblesWon, l.dribbles)})'),
        (tr('To‘pga tegishlar'), '${l.touches}'),
        (tr('To‘p yo‘qotish'), '${l.possessionLost}'),
        (tr('Qoidabuzarlikka uchragan'), '${l.fouled}'),
        (tr('Ishlab olingan penalti'), '${l.penaltiesWon}'),
      ]),
      _ => _rowsCard([
        (tr('Olib qo‘yishlar'), '${l.tackles}'),
        (tr('Pas kesishlar'), '${l.interceptions}'),
        (tr('Tozalashlar'), '${l.clearances}'),
        (tr('Bloklangan zarbalar'), '${l.blocks}'),
        (tr('Aldab o‘tilgan'), '${l.dribbledPast}'),
        (tr('Yakkakurash (yutgan/yutqazgan)'), '${l.duelsWon}/${l.duelsLost}'),
        (tr('Qoidabuzarlik'), '${l.fouls}'),
        if (_player.mainPosition.isGoalkeeper) (tr('Seyvlar'), '${l.saves}'),
      ]),
    };
  }

  Widget _overviewLeft() {
    final l = _line;
    if (l == null) return const SizedBox.shrink();
    final accuracy = l.passes == 0 ? 0 : (l.passesCompleted * 100 / l.passes).round();
    Widget tile(String label, String value, IconData? icon) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label.toUpperCase(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(fontSize: 9)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 16, color: AppColors.ink2), const SizedBox(width: 4)],
                Text(value, style: AppText.h3),
              ],
            ),
          ],
        ),
      ),
    );
    final breakdown = _breakdown(l);
    final scale = max(1.0, breakdown.map((e) => e.$2.abs()).fold(0.0, max));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              tile(tr('Daqiqalar'), '${min(90, l.minutes.round())}′', Icons.timer_outlined),
              tile(tr('Kalit paslar'), '${l.keyPasses}', null),
              tile(tr('Pas aniqligi'), '$accuracy%', null),
              tile(tr('To‘pga tegishlar'), '${l.touches}', null),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              RatingBadge(d.ratings[_player.id], size: 14),
              const SizedBox(width: 8),
              Text(tr('Reyting tahlili'), style: AppText.bodyStrong),
            ],
          ),
          const SizedBox(height: 10),
          for (final (label, value, color) in breakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 96, child: Text(label, style: AppText.small.copyWith(color: AppColors.ink))),
                  Expanded(child: _ImpactBar(value / scale, color)),
                  SizedBox(
                    width: 44,
                    child: Text(
                      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: AppText.caption.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// How each part of the game moved the rating (mirrors the rating model).
  List<(String, double, Color)> _breakdown(PlayerMatchStats l) {
    final gk = _player.mainPosition.isGoalkeeper;
    final shooting = l.goals * 1.0 + (l.shotsOnTarget - l.goals).clamp(0, 99) * 0.11 -
        (l.shots - l.shotsOnTarget).clamp(0, 99) * 0.03 - l.bigChancesMissed * 0.22;
    final passing = l.assists * 0.7 + l.keyPasses * 0.16 + l.bigChancesCreated * 0.22 +
        l.passesCompleted * 0.01 - (l.passes - l.passesCompleted) * 0.03;
    final dribbling = l.dribblesWon * 0.09 - (l.dribbles - l.dribblesWon) * 0.04 + l.fouled * 0.03 -
        l.possessionLost * 0.02;
    final defending = l.tackles * 0.12 + l.interceptions * 0.1 + l.clearances * 0.05 + l.blocks * 0.1 -
        l.dribbledPast * 0.07 + (l.duelsWon - l.duelsLost) * 0.02 - l.fouls * 0.06 - l.errorsLeadingToShot * 0.35;
    return [
      if (gk) (tr('Darvozabonlik'), l.saves * 0.3 + l.penaltiesSaved * 0.9 - l.goalsConceded * 0.22, const Color(0xFF00ADC4)),
      (tr('Zarbalar'), shooting, AppColors.live),
      (tr('Paslar'), passing, AppColors.win),
      (tr('Dribling'), dribbling, AppColors.primary),
      (tr('Himoya'), defending, AppColors.warning),
    ];
  }

  Widget _heatCard() {
    final heat = d.heatFor(_player.id);
    return AppCard(
      child: heat == null || !heat.any((v) => v > 0)
          ? Text(tr('Bu o‘yin uchun issiqlik xaritasi yo‘q.'), style: AppText.caption)
          : PlayerHeatmap(cells: heat),
    );
  }

  Widget _rowsCard(List<(String, String)> rows) => AppCard(
    child: Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                Expanded(child: Text(tr(r.$1), style: AppText.small.copyWith(color: AppColors.ink))),
                Text(r.$2, style: AppText.number.copyWith(fontSize: 13)),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _switcher() {
    final people = d.participants;
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        itemCount: people.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final (p, c) = people[i];
          final selected = p.id == _player.id;
          return InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _switch(p, c),
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: selected ? AppColors.primary : Colors.transparent),
              ),
              child: Row(
                children: [
                  FaceAvatar(config: p.face, size: 34, shirt: c.primaryColor, circle: true),
                  const SizedBox(width: 6),
                  Text(p.shortName, style: AppText.small.copyWith(color: AppColors.ink, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small dots on the momentum chart where the player's moments happened.
class _MomentMarks extends CustomPainter {
  final List<int> minutes;
  final int? selected;
  final int total;
  _MomentMarks(this.minutes, this.selected, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final bw = size.width / total;
    for (final m in minutes) {
      final x = ((m <= 45 ? m : m + 2) - 0.5).clamp(0, total - 1) * bw;
      final on = m == selected;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = AppColors.ink.withValues(alpha: on ? 0.5 : 0.15)
          ..strokeWidth = on ? 1.4 : 1,
      );
      canvas.drawCircle(Offset(x, size.height / 2), on ? 5 : 3.5, Paint()..color = on ? AppColors.ink : AppColors.ink2);
      canvas.drawCircle(Offset(x, size.height / 2), on ? 2.4 : 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _MomentMarks old) => old.selected != selected || old.minutes.length != minutes.length;
}

/// Centred impact bar: negative to the left, positive to the right.
class _ImpactBar extends StatelessWidget {
  final double value; // -1..1
  final Color color;
  const _ImpactBar(this.value, this.color);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final half = box.maxWidth / 2;
      final w = half * value.abs().clamp(0.0, 1.0);
      return SizedBox(
        height: 10,
        child: Stack(
          children: [
            Container(decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(5))),
            Positioned(
              left: value >= 0 ? half : half - w,
              width: max(2, w),
              top: 0,
              bottom: 0,
              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
            ),
            Positioned(left: half - 1, width: 2, top: -2, bottom: -2, child: Container(color: AppColors.ink3)),
          ],
        ),
      );
    },
  );
}
