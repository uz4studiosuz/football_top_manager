import 'dart:math';
import '../ui/flag.dart';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../ui/face_avatar.dart';
import '../ui/action_map.dart';
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
  final List<PlayerAction> Function(String id) actionsFor;
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
    this.actionsFor = _noActions,
  });

  static List<PlayerAction> _noActions(String id) => const [];

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
  late int _tab = widget.player.mainPosition.isGoalkeeper ? 6 : 0;
  int? _keeperShot;
  int _moment = 0;

  PlayerMatchData get d => widget.data;
  PlayerMatchStats? get _line => d.lines[_player.id];

  List<String> get _tabs => [
    tr('Umumiy'),
    tr('Statistika'),
    tr('Zarbalar'),
    tr('Paslar'),
    tr('Dribling'),
    tr('Himoya'),
    if (_player.mainPosition.isGoalkeeper) tr('Darvozabon'),
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
  _keeperShot = null;
    if (_tab == 6 && !p.mainPosition.isGoalkeeper) _tab = 0;
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
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
                  FlagLabel(_player.countryFlag, '${tr(_player.nationality)} · #${_player.number}', nationality: _player.nationality, style: AppText.caption),
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
        for (final i in [if (_player.mainPosition.isGoalkeeper) 6, 0, 1, 2, 3, 4, 5])
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
    return switch (_tab) {
      0 => Column(children: [_overviewLeft(), const SizedBox(height: 10), _heatCard()]),
      1 => _rowsCard(playerStatRows(_player, l)),
      2 => _shotsTab(l, colors),
      3 => _passTab(l),
      4 => _dribbleTab(l),
      5 => _defenceTab(l),
      _ => _keeperTab(l, colors),
    };
  }

  // ---- action tabs (maps and detailed statistics) ------------------------

  int _passFilter = 0, _defFilter = 0, _dribFilter = 0;

  Widget _chips(List<String> labels, int selected, void Function(int) onTap) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(label: Text(labels[i]), selected: selected == i, onSelected: (_) => onTap(i)),
          ),
      ],
    ),
  );

  Widget _mapCard(Widget chips, Widget map, bool hasData) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chips,
        const SizedBox(height: 10),
        if (hasData) map else Text(tr('Bu o‘yin uchun harakat xaritasi saqlanmagan.'), style: AppText.caption),
      ],
    ),
  );

  String _ratio(int ok, int total) => total == 0 ? '0' : '$ok/$total (${(ok * 100 / total).round()}%)';

  Widget _shotsTab(PlayerMatchStats l, (Color, Color) colors) {
    final mine = [for (final s in d.shots) if (s.playerId == _player.id) s];
    final xgot = mine.fold<double>(0, (a, s) => a + s.xgot);
    final blocked = mine.where((s) => s.outcome == 'block').length;
    return Column(
      children: [
        AppCard(
          child: ShotMapView(
            shots: mine,
            home: d.home,
            away: d.away,
            homeColor: colors.$1,
            awayColor: colors.$2,
          ),
        ),
        const SizedBox(height: 10),
        _rowsCard([
          (tr('Gollar'), '${l.goals}'),
          (tr('Kutilgan gollar (xG)'), l.xg.toStringAsFixed(2)),
          ('xGOT', xgot.toStringAsFixed(2)),
          (tr('Umumiy zarbalar'), '${l.shots}'),
          (tr('Darvozaga aniq yo‘llangan zarbalar'), '${l.shotsOnTarget}'),
          (tr('To‘silgan zarbalar'), '$blocked'),
          (tr('Nishondan tashqari'), '${max(0, l.shots - l.shotsOnTarget - blocked)}'),
          (tr('Boy berilgan xavfli vaziyatlar'), '${l.bigChancesMissed}'),
          (tr('Ofsaydlar'), '${l.offsides}'),
        ]),
      ],
    );
  }

  Widget _passTab(PlayerMatchStats l) {
    final all = d.actionsFor(_player.id).where((a) => a.kind == ActionKind.pass || a.kind == ActionKind.cross).toList();
    bool long(PlayerAction a) => a.meters >= 30;
    final shown = switch (_passFilter) {
      1 => [for (final a in all) if (a.ok) a],
      2 => [for (final a in all) if (!a.ok) a],
      3 => [for (final a in all) if (long(a)) a],
      4 => [for (final a in all) if (a.kind == ActionKind.cross) a],
      _ => all,
    };
    final passes = all.where((a) => a.kind == ActionKind.pass);
    final oppHalf = passes.where((a) => a.from.dx > 0.5), ownHalf = passes.where((a) => a.from.dx <= 0.5);
    final longs = passes.where(long), crosses = all.where((a) => a.kind == ActionKind.cross);
    final forward = passes.where((a) => a.to.dx - a.from.dx > 0.04);
    int okOf(Iterable<PlayerAction> it) => it.where((a) => a.ok).length;
    return Column(
      children: [
        _mapCard(
          _chips([tr('Barcha paslar'), tr('Aniq'), tr('Aniq emas'), tr('Uzun to‘plar'), tr('Krosslar')], _passFilter, (i) => setState(() => _passFilter = i)),
          ActionMap(actions: shown),
          all.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _rowsCard([
          (tr('Gol paslar'), '${l.assists}'),
          (tr('Kutilgan yordamlar (xA)'), l.xa.toStringAsFixed(2)),
          (tr('Kalit paslar'), '${l.keyPasses}'),
          (tr('Yaratilgan katta imkoniyat'), '${l.bigChancesCreated}'),
          (tr('Aniq paslar'), _ratio(l.passesCompleted, l.passes)),
          if (all.isNotEmpty) ...[
            (tr('Raqib yarim maydonida paslar (aniq)'), _ratio(okOf(oppHalf), oppHalf.length)),
            (tr('O‘z maydonida paslar (aniq)'), _ratio(okOf(ownHalf), ownHalf.length)),
            (tr('Oldinga paslar (aniq)'), _ratio(okOf(forward), forward.length)),
            (tr('Uzun to‘p uzatmalar (aniq)'), _ratio(okOf(longs), longs.length)),
          ],
          (tr('Krosslar'), all.isNotEmpty ? _ratio(okOf(crosses), crosses.length) : '${l.crosses}'),
        ]),
      ],
    );
  }

  Widget _dribbleTab(PlayerMatchStats l) {
    final all = d.actionsFor(_player.id).where((a) => a.kind == ActionKind.dribble).toList();
    final shown = switch (_dribFilter) {
      1 => [for (final a in all) if (a.ok) a],
      2 => [for (final a in all) if (!a.ok) a],
      _ => all,
    };
    return Column(
      children: [
        _mapCard(
          _chips([tr('Barcha driblinglar'), tr('Muvaffaqiyatli'), tr('Muvaffaqiyatsiz')], _dribFilter, (i) => setState(() => _dribFilter = i)),
          ActionMap(actions: shown),
          all.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _rowsCard([
          (tr('Driblinglar (muvaffaqiyatli)'), _ratio(l.dribblesWon, l.dribbles)),
          (tr('To‘pga tegishlar'), '${l.touches}'),
          (tr('To‘p yo‘qotildi'), '${l.possessionLost}'),
          (tr('Fol qilindi'), '${l.fouled}'),
          (tr('Ishlab olingan penalti'), '${l.penaltiesWon}'),
          if (l.distanceM > 0) (tr('Yugurgan masofa'), '${(l.distanceM / 1000).toStringAsFixed(1)} km'),
          if (l.minutes > 0 && l.distanceM > 0) (tr('Daqiqasiga masofa'), '${(l.distanceM / l.minutes).round()} m'),
        ]),
      ],
    );
  }

  Widget _keeperTab(PlayerMatchStats l, (Color, Color) colors) {
    final keeperHome = _club.id == d.home.id;
    // Shots he faced on target: saved or scored.
    final faced = [
      for (final s in d.shots)
        if (s.home != keeperHome &&
            s.onTarget &&
            s.minute >= (l.subOnMinute ?? 0) &&
            s.minute <= (l.subOffMinute ?? 130))
          s,
    ];
    final selected = _keeperShot != null && _keeperShot! < faced.length ? faced[_keeperShot!] : null;
    final xgot = faced.fold<double>(0, (a, s) => a + s.xgot);
    final insideBox = faced
        .where(
          (s) =>
              s.outcome == 'save' &&
              (s.home ? 1 - s.origin.dx : s.origin.dx) * 105 <= 16.5 &&
              (s.origin.dy - 0.5).abs() * 68 <= 20.16,
        )
        .length;
    final acts = d.actionsFor(_player.id);
    final claims = acts.where((a) => a.kind == ActionKind.claim).length;
    final punches = acts.where((a) => a.kind == ActionKind.punch).length;
    final sweeps = acts.where((a) => a.kind == ActionKind.sweep).toList();
    final successfulSweeps = sweeps.where((a) => a.ok).length;
    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Darvozaga yo‘llangan zarbalar'), style: AppText.h3),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(tr('Barcha')),
                      selected: selected == null,
                      onSelected: (_) => setState(() => _keeperShot = null),
                    ),
                    for (var i = 0; i < faced.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          avatar: Icon(faced[i].goal ? Icons.sports_soccer : Icons.back_hand_outlined, size: 16),
                          label: Text("${faced[i].minute}'"),
                          selected: _keeperShot == i,
                          onSelected: (_) => setState(() => _keeperShot = i),
                        ),
                      ),
                  ],
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 125,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: GoalMouthPainter(selected, selected.goal ? AppColors.live : AppColors.win),
                  ),
                ),
                Text(
                  'xGOT ${selected.xgot.toStringAsFixed(2)} · ${selected.goal ? tr('Gol') : tr('Seyv')} · '
                  '${(selected.home ? d.home : d.away).playerById(selected.playerId)?.shortName ?? "—"}',
                  style: AppText.small,
                ),
              ],
              const SizedBox(height: 10),
              ShotMapView(
                shots: selected == null ? faced : [selected],
                home: d.home,
                away: d.away,
                homeColor: colors.$1,
                awayColor: colors.$2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _rowsCard([
          (tr('Jami saqlanganlar'), '${l.saves}'),
          (tr('O‘tkazilgan gollar'), '${l.goalsConceded}'),
          (tr('To‘siq qilingan gollar'), (xgot - l.goalsConceded).toStringAsFixed(2)),
          ('xGOT', xgot.toStringAsFixed(2)),
          (tr('Jarima maydonchasi ichidan seyvlar'), '$insideBox'),
          if (l.penaltiesSaved > 0) (tr('Qaytarilgan penalti'), '${l.penaltiesSaved}'),
          ...[
            (tr('Urinishlar'), '$punches'),
            (tr('Chiqishlar (muvaffaqiyatli)'), '${sweeps.length} ($successfulSweeps)'),
            (tr('Havodagi egallash'), '$claims'),
          ],
          (tr('Aniq paslar'), _ratio(l.passesCompleted, l.passes)),
        ]),
      ],
    );
  }

  Widget _defenceTab(PlayerMatchStats l) {
    const kinds = [null, ActionKind.tackle, ActionKind.interception, ActionKind.clearance, ActionKind.block, ActionKind.aerial];
    final defensive = {ActionKind.tackle, ActionKind.interception, ActionKind.clearance, ActionKind.block, ActionKind.aerial};
    final all = d.actionsFor(_player.id).where((a) => defensive.contains(a.kind)).toList();
    final shown = [for (final a in all) if (kinds[_defFilter] == null || a.kind == kinds[_defFilter]) a];
    final aerial = all.where((a) => a.kind == ActionKind.aerial);
    final aerialWon = aerial.where((a) => a.ok).length;
    final groundTotal = max(0, l.duelsWon + l.duelsLost - aerial.length);
    final groundWon = max(0, l.duelsWon - aerialWon);
    return Column(
      children: [
        _mapCard(
          _chips(
            [tr('Hammasi'), tr('Olib qo‘yishlar'), tr('To‘xtatib qolishlar'), tr('Tozalashlar'), tr('Bloklar'), tr('Havodagi duellar')],
            _defFilter,
            (i) => setState(() => _defFilter = i),
          ),
          ActionMap(actions: shown, arrows: false),
          all.isNotEmpty,
        ),
        const SizedBox(height: 10),
        _rowsCard([
          (tr('Himoyaviy harakatlar'), '${l.tackles + l.interceptions + l.clearances + l.blocks}'),
          (tr('Olib qo‘yishlar (yutilgan)'), '${l.tackles} (${l.tackles})'),
          (tr('To‘xtatib qolishlar'), '${l.interceptions}'),
          (tr('Tozalashlar'), '${l.clearances}'),
          (tr('Bloklangan zarbalar'), '${l.blocks}'),
          (tr('Tiklanishlar'), '${l.tackles + l.interceptions}'),
          (tr('Yer duellari (yutilgan)'), all.isEmpty ? '${l.duelsWon + l.duelsLost} (${l.duelsWon})' : '$groundTotal ($groundWon)'),
          if (all.isNotEmpty) (tr('Havodagi duellar (yutilgan)'), '${aerial.length} ($aerialWon)'),
          (tr('Qo‘pol ishlashlar'), '${l.fouls}'),
          (tr('Driblingdan o‘tishgan'), '${l.dribbledPast}'),
          if (l.errorsLeadingToShot > 0) (tr('Zarbaga olib kelgan xatolar'), '${l.errorsLeadingToShot}'),
          if (_player.mainPosition.isGoalkeeper) (tr('Seyvlar'), '${l.saves}'),
        ]),
      ],
    );
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
      decoration: BoxDecoration(
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
