import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import '../ui/face_avatar.dart';
import '../ui/match_widgets.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';

/// Post-match page for any played fixture (SofaScore event page layout).
class MatchReportScreen extends StatefulWidget {
  final Fixture fixture;
  const MatchReportScreen({super.key, required this.fixture});
  @override
  State<MatchReportScreen> createState() => _MatchReportScreenState();
}

class _MatchReportScreenState extends State<MatchReportScreen> {
  int team = 0;
  @override
  Widget build(BuildContext context) {
    final game = GameState();
    final f = widget.fixture;
    final h = game.getClubById(f.homeClubId)!, a = game.getClubById(f.awayClubId)!;
    final colors = teamColors(h, a);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${GameState().leagueName} · ${f.round}-tur', style: AppText.h3),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(178),
            child: Column(
              children: [
                MatchHeader(
                  home: h,
                  away: a,
                  homeScore: f.homeScore ?? 0,
                  awayScore: f.awayScore ?? 0,
                  status: 'Yakunlandi',
                  events: f.events,
                  caption: f.date == null
                      ? null
                      : '${SeasonCalendar.format(f.date!, year: true)}${f.attendance > 0 ? ' · ${f.attendance} muxlis' : ''}',
                ),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: [
                    Tab(text: 'Ko‘rinish'),
                    Tab(text: 'Statistika'),
                    Tab(text: 'Tarkiblar'),
                    Tab(text: 'Izohlar'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (f.motmId != null) _motm(h, a, f),
                if (f.momentum.isNotEmpty)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeader('Hujum momenti', icon: Icons.insights_outlined),
                        MomentumChart(
                          values: f.momentum,
                          events: f.events,
                          homeColor: colors.$1,
                          awayColor: colors.$2,
                        ),
                      ],
                    ),
                  ),
                AppCard(
                  child: Column(
                    children: [
                      const SectionHeader('Muhim voqealar', icon: Icons.timeline_rounded),
                      IncidentTimeline(events: f.events, newestFirst: false),
                    ],
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                StatGroupsView(
                  groups: statGroupsFromFixture(f),
                  homeColor: colors.$1,
                  awayColor: colors.$2,
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Center(
                  child: PillTabs(
                    labels: [h.shortName, a.shortName],
                    index: team,
                    onChanged: (i) => setState(() => team = i),
                  ),
                ),
                const SizedBox(height: 12),
                _lineup(team == 0 ? h : a, team == 0 ? f.homeLineup : f.awayLineup, f, team == 0 ? colors.$1 : colors.$2),
              ],
            ),
            ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final e in f.events.reversed)
                  CommentaryTile(event: e, homeColor: colors.$1, awayColor: colors.$2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _motm(Club h, Club a, Fixture f) {
    final p = h.playerById(f.motmId!) ?? a.playerById(f.motmId!);
    if (p == null) return const SizedBox();
    final club = h.playerById(p.id) != null ? h : a;
    final line = f.playerStats[p.id];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          FaceAvatar(config: p.face, size: 52, shirt: club.primaryColor, circle: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('O‘YIN QAHRAMONI', style: AppText.overline),
                const SizedBox(height: 2),
                Text(p.name, style: AppText.h3),
                if (line != null)
                  Text(
                    '${line.goals} gol · ${line.assists} assist · ${line.passesCompleted}/${line.passes} pas',
                    style: AppText.caption,
                  ),
              ],
            ),
          ),
          RatingBadge(f.ratings[p.id], size: 15, star: true),
        ],
      ),
    );
  }

  Widget _lineup(Club club, List<String> starters, Fixture f, Color color) {
    final ratings = <String, double?>{...f.ratings};
    final ids = f.playerStats.keys.where((id) => club.playerById(id) != null && (f.playerStats[id]!.minutes > 0)).toList();
    final xi = starters.map(club.playerById).whereType<Player>().toList();
    final goals = <String, int>{
      for (final id in ids)
        if ((f.playerStats[id]?.goals ?? 0) > 0) id: f.playerStats[id]!.goals,
    };
    return Column(
      children: [
        if (xi.length == 11)
          LineupPitch(
            club: club,
            players: xi,
            ratings: ratings,
            goals: goals,
            lines: f.playerStats,
            shirt: color,
            onTap: (p) => _sheet(p, club, f),
          ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.only(bottom: 6),
          child: LineupList(
            club: club,
            starters: starters,
            bench: club.id == f.homeClubId ? f.homeBench : f.awayBench,
            lines: f.playerStats,
            ratings: ratings,
            events: f.events,
            motmId: f.motmId,
            onTap: (p) => _sheet(p, club, f),
          ),
        ),
      ],
    );
  }

  void _sheet(Player p, Club club, Fixture f) => showPlayerMatchSheet(
    context,
    player: p,
    club: club,
    line: f.playerStats[p.id],
    rating: f.ratings[p.id],
    onOpenProfile: () => PlayerDetailView.show(context, player: p, club: club),
  );
}

/// Score header used by the live match and the report.
class MatchHeader extends StatelessWidget {
  final Club home, away;
  final int homeScore, awayScore;
  final String status;
  final bool live;
  final List<MatchEvent> events;
  final String? caption;
  const MatchHeader({
    super.key,
    required this.home,
    required this.away,
    required this.homeScore,
    required this.awayScore,
    required this.status,
    required this.events,
    this.live = false,
    this.caption,
  });
  @override
  Widget build(BuildContext context) {
    List<String> scorers(bool isHome) => [
      for (final e in events.where((e) => e.type == MatchEventType.goal && e.isHomeTeam == isHome))
        '${e.playerName?.split(' ').last ?? ''} ${e.minuteLabel}',
    ];
    Widget team(Club c, bool isHome) => Expanded(
      child: Column(
        children: [
          ClubCrestWidget(config: c.crestConfig, size: 50),
          const SizedBox(height: 6),
          Text(
            c.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            scorers(isHome).join(', '),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          team(home, true),
          SizedBox(
            width: 112,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Text(
                  '$homeScore - $awayScore',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontFeatures: AppText.tabular,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (live) ...[const LiveDot(), const SizedBox(width: 5)],
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: live ? AppColors.live : AppColors.ink2,
                      ),
                    ),
                  ],
                ),
                if (caption != null) ...[
                  const SizedBox(height: 4),
                  Text(caption!, textAlign: TextAlign.center, style: AppText.caption.copyWith(fontSize: 10)),
                ],
              ],
            ),
          ),
          team(away, false),
        ],
      ),
    );
  }
}
