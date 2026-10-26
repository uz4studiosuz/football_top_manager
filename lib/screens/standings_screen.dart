import 'package:flutter/material.dart';
import 'club_screen.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import '../ui/face_avatar.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'match_report_screen.dart';
import 'widgets/opponent_squad_sheet.dart';
import 'widgets/player_detail_view.dart';
import '../l10n/l10n.dart';
import '../services/cup.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});
  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  int round = 0;
  int seenRound = 0;
  int leaders = 0;
  String? view; // league whose table is shown (null = own)

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trf('{0} Markazi', [game.leagueName])),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            tabs: [
              Tab(text: tr('Turnir jadvali')),
              Tab(text: tr('Turlar')),
              Tab(text: tr('Futbolchilar')),
              Tab(text: tr('Kubok')),
              Tab(text: tr('Kalendar')),
            ],
          ),
        ),
        body: ListenableBuilder(
          listenable: game,
          builder: (context, _) {
            if (!game.isInitialized) return const SizedBox();
            // Follow the season: jump to the new round when it changes.
            if (seenRound != game.currentRound) {
              seenRound = game.currentRound;
              round = game.currentRound;
            }
            return TabBarView(
              children: [
                _table(context, game),
                _rounds(context, game),
                _leaders(context, game),
                _cup(context, game),
                const CalendarView(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The cup bracket, round by round; the user's ties open their report.
  Widget _cup(BuildContext context, GameState game) {
    final cup = game.cup;
    if (cup == null) return EmptyState(icon: Icons.emoji_events_outlined, text: tr('Kubok keyingi mavsumdan boshlanadi.'));
    String name(String? id) => id == null ? '—' : (game.getClubById(id)?.name ?? id);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.gold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.cupName, style: AppText.h3),
                    Text(
                      cup.winner != null
                          ? trf('G‘olib: {0}', [name(cup.winner)])
                          : tr('Bir o‘yinli pley-off; durangda penaltilar seriyasi.'),
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (var r = cup.rounds.length - 1; r >= 0; r--) ...[
          const SizedBox(height: 12),
          SectionHeader(
            trf('{0} · {1}', [Cup.stageName(r, cup.totalRounds), GameState().roundDate(cup.schedule[r])]),
            icon: Icons.account_tree_outlined,
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (i, t) in cup.rounds[r].indexed)
                  if (!t.isBye)
                    ListTile(
                      dense: true,
                      selected: t.involves(game.userClubId ?? ''),
                      selectedTileColor: AppColors.primarySoft,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name(t.home),
                              textAlign: TextAlign.right,
                              style: AppText.small.copyWith(
                                color: AppColors.ink,
                                fontWeight: t.winner == t.home ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(t.score(), style: AppText.bodyStrong),
                          ),
                          Expanded(
                            child: Text(
                              name(t.away),
                              style: AppText.small.copyWith(
                                color: AppColors.ink,
                                fontWeight: t.winner == t.away ? FontWeight.w800 : FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      onTap: () {
                        final f = game.cupFixtures.where((f) => f.id.endsWith('_${r}_$i')).firstOrNull;
                        if (f != null) {
                          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)));
                        }
                      },
                    ),
                if (cup.rounds[r].any((t) => t.isBye))
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      trf('Keyingi bosqichga to‘g‘ridan-to‘g‘ri: {0}', [
                        cup.rounds[r].where((t) => t.isBye).map((t) => game.getClubById(t.home)?.shortName ?? t.home).join(', '),
                      ]),
                      style: AppText.caption,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _table(BuildContext context, GameState game) {
    final pyramid = InitialDatabase.pyramidOf(game.leagueId);
    final shown = view != null && game.divisions.containsKey(view) ? view! : game.leagueId;
    final own = shown == game.leagueId;
    return ListView(
    padding: const EdgeInsets.all(12),
    children: [
      if (pyramid.length > 1) ...[
        PillTabs(
          labels: [for (final l in pyramid) l.id == game.leagueId ? '${l.name} ★' : l.name],
          index: pyramid.indexWhere((l) => l.id == shown),
          onChanged: (i) => setState(() => view = pyramid[i].id),
        ),
        const SizedBox(height: 12),
      ],
      AppCard(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(
                own ? trf('Mavsum {0}', [game.seasonLabel]) : '${InitialDatabase.leagueName(shown)} · ${game.seasonLabel}',
                icon: Icons.emoji_events_outlined,
              ),
            ),
            StandingsTable(
              leagueId: own ? null : shown,
              highlightClubId: game.userClubId,
              onTapClub: (c) => c.id == game.userClubId
                  ? null
                  : OpponentSquadSheet.show(context, opponentClub: c),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final (c, t) in StandingsTable.legend(own ? null : shown)) _legend(c, t),
          ],
        ),
      ),
    ],
  );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(tr(t), style: AppText.caption),
    ],
  );

  Widget _rounds(BuildContext context, GameState game) {
    final fixtures = game.fixtures.where((f) => f.round == round).toList();
    final date = game.calendar.dateOfRound(round);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: round > 1 ? () => setState(() => round--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(trf('{0}-tur', [round]), style: AppText.h3),
                    Text('${SeasonCalendar.weekday(date)}, ${SeasonCalendar.format(date, year: true)}', style: AppText.caption),
                  ],
                ),
              ),
              IconButton(
                onPressed: round < game.totalRounds ? () => setState(() => round++) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final f in fixtures)
                FixtureTile(
                  fixture: f,
                  highlightClubId: f.involves(game.userClubId!) ? game.userClubId : null,
                  onTap: f.isPlayed
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leaders(BuildContext context, GameState game) {
    final lists = [
      (game.topScorers, (PlayerLeaderboardEntry e) => '${e.player.seasonGoals}', 'gol'),
      (game.topAssists, (PlayerLeaderboardEntry e) => '${e.player.seasonAssists}', 'assist'),
      (game.topRated, (PlayerLeaderboardEntry e) => e.player.averageRating!.toStringAsFixed(2), 'reyting'),
      (game.topCleanSheets, (PlayerLeaderboardEntry e) => '${e.player.seasonCleanSheets}', 'quruq'),
    ];
    final current = lists[leaders];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        PillTabs(
          labels: [tr('To\'purarlar'), tr('Assistentlar'), 'Reyting', tr('Quruq o‘yinlar')],
          index: leaders,
          onChanged: (i) => setState(() => leaders = i),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: current.$1.isEmpty
              ? EmptyState(icon: Icons.bar_chart_rounded, text: tr('Birinchi turdan keyin statistika paydo bo‘ladi'))
              : Column(
                  children: [
                    for (var i = 0; i < current.$1.length && i < 25; i++)
                      InkWell(
                        onTap: () => PlayerDetailView.show(context, player: current.$1[i].player, club: current.$1[i].club),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 26,
                                child: Text('${i + 1}', style: AppText.number.copyWith(color: i < 3 ? AppColors.primary : AppColors.ink2)),
                              ),
                              FaceAvatar(
                                config: current.$1[i].player.face,
                                size: 36,
                                shirt: current.$1[i].club.primaryColor,
                                circle: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(current.$1[i].player.name, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                                    Row(
                                      children: [
                                        ClubCrestWidget(config: current.$1[i].club.crestConfig, size: 14),
                                        const SizedBox(width: 5),
                                        Text(
                                          trf('{0} · {1} o‘yin', [current.$1[i].club.shortName, current.$1[i].player.seasonMatches]),
                                          style: AppText.caption,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (leaders == 2)
                                RatingBadge(current.$1[i].player.averageRating, size: 13)
                              else
                                Text(current.$2(current.$1[i]), style: AppText.number.copyWith(fontSize: 18)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
