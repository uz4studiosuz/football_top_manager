import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/finance.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import '../ui/face_avatar.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'club_screen.dart';
import 'manager_profile_screen.dart';
import 'match_report_screen.dart';
import 'match_screen.dart';
import 'widgets/opponent_squad_sheet.dart';
import 'widgets/player_detail_view.dart';
import '../l10n/l10n.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToTactics;
  final VoidCallback? onNavigateToSquad,
      onNavigateToFinance,
      onNavigateToTable,
      onNavigateToTransfers;
  const DashboardScreen({
    super.key,
    required this.onNavigateToTactics,
    this.onNavigateToSquad,
    this.onNavigateToFinance,
    this.onNavigateToTable,
    this.onNavigateToTransfers,
  });

  @override
  Widget build(BuildContext context) {
    final game = GameState();
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isInitialized) return const Scaffold();
        final club = game.userClub, manager = game.managerProfile;
        final next = game.nextUserFixture;
        final standing = game.standingOf(club.id);
        final rank = game.positionOf(club.id);
        final upcoming = game
            .fixturesOf(club.id)
            .where((f) => !f.isPlayed && f != next)
            .take(3)
            .toList();
        final last = game.lastUserResult;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                ClubCrestWidget(config: club.crestConfig, size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.h3.copyWith(fontSize: 16),
                      ),
                      Text(
                        '${game.leagueName} · ${game.seasonLabel}',
                        style: AppText.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: tr('Yangiliklar'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const NewsPage()),
                ),
                icon: Badge(
                  isLabelVisible: game.unreadNews > 0,
                  label: Text('${game.unreadNews}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
              IconButton(
                tooltip: tr('Menejer profili'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ManagerProfileScreen(),
                  ),
                ),
                icon: FaceAvatar(
                  config: manager.face,
                  size: 34,
                  shirt: const Color(0xFF2B3A55),
                  circle: true,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tr('Sezon markazi'), style: AppText.h1),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            SeasonCalendar.format(game.currentDate),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _summaryStrip(game, club, standing, rank),
              const SizedBox(height: 12),
              ..._inbox(context, game),
              LayoutBuilder(
                builder: (context, box) {
                  final main = Column(
                    children: [
                      if (game.seasonFinished)
                        _seasonEnd(context, game)
                      else if (next != null)
                        _matchCard(context, game, club, next)
                      else
                        _roundDone(context, game),
                      if (game.unavailableStarters.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _availabilityWarning(game),
                      ],
                      if (last != null) ...[
                        const SizedBox(height: 12),
                        _lastResult(context, game, club, last),
                      ],
                      const SizedBox(height: 12),
                      _fixturesCard(context, game, club, upcoming),
                    ],
                  );
                  final side = Column(
                    children: [
                      _boardCard(game),
                      const SizedBox(height: 12),
                      AppCard(
                        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: SectionHeader(
                                tr('Liga jadvali'),
                                icon: Icons.leaderboard_outlined,
                                action: tr('To‘liq'),
                                onAction: onNavigateToTable,
                              ),
                            ),
                            StandingsTable(compact: true, highlightClubId: club.id),
                            if (StandingsTable.zoneLabel(rank) case final zone?)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                                child: Row(
                                  children: [
                                    Icon(Icons.place_rounded, size: 15, color: StandingsTable.zoneColor(rank)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        trf('Hozir: {0} zonasida', [zone]),
                                        style: AppText.small,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _topPerformers(context, club),
                      const SizedBox(height: 12),
                      _newsCard(context, game),
                    ],
                  );
                  if (box.maxWidth > 860) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: main),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: side),
                      ],
                    );
                  }
                  return Column(children: [main, const SizedBox(height: 12), side]);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryStrip(GameState game, Club club, LeagueStanding s, int rank) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Expanded(child: StatTile('$rank/${game.clubCount}', 'Liga o‘rni', color: StandingsTable.zoneColor(rank) == Colors.transparent ? null : StandingsTable.zoneColor(rank))),
        Expanded(child: StatTile('${s.points}', 'Ochko')),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                child: s.formGuide.isEmpty
                    ? const Text('—', style: AppText.number)
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(children: [for (final r in s.formGuide) FormChip(r, size: 18)]),
                      ),
              ),
              const SizedBox(height: 2),
              Text(tr('Forma'), style: AppText.caption),
            ],
          ),
        ),
        Expanded(child: StatTile(club.formattedTransferBudget, 'Mablag‘')),
      ],
    ),
  );

  Widget _matchCard(BuildContext context, GameState game, Club club, Fixture f) {
    final h = game.getClubById(f.homeClubId)!, a = game.getClubById(f.awayClubId)!;
    final rival = h.id == club.id ? a : h;
    Widget form(Club c) {
      final g = game.standingOf(c.id).formGuide;
      return SizedBox(
        height: 18,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: g.isEmpty ? [const Text('—', style: AppText.caption)] : [for (final r in g) FormChip(r, size: 16)],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('NAVBATDAGI UCHRASHUV'), style: AppText.overline),
              ),
              Text(trf('{0}-tur', [f.round]), style: AppText.caption),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: ClubHeading(club: h, caption: trf('OVR {0} · {1}-o‘rin', [h.teamOVR, game.positionOf(h.id)]))),
              Column(
                children: [
                  Text(
                    SeasonCalendar.weekday(f.date ?? game.currentDate),
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    SeasonCalendar.short(f.date ?? game.currentDate),
                    style: AppText.h2,
                  ),
                  const SizedBox(height: 2),
                  const Text('20:00', style: AppText.caption),
                ],
              ),
              Expanded(child: ClubHeading(club: a, caption: trf('OVR {0} · {1}-o‘rin', [a.teamOVR, game.positionOf(a.id)]))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: form(h)),
              const SizedBox(width: 60),
              Expanded(child: form(a)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.stadium_outlined, size: 14, color: AppColors.ink3),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${h.stadiumName} · ${h.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => OpponentSquadSheet.show(context, opponentClub: rival),
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 17),
                  label: FittedBox(child: Text(tr('Raqib tahlili'))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (game.unavailableStarters.isNotEmpty) game.fixUnavailableStarters();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => MatchScreen(fixture: f)),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: FittedBox(child: Text(tr('Boshlash'))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () async {
              if (game.unavailableStarters.isNotEmpty) game.fixUnavailableStarters();
              await runWithLoading(context, 'Uchrashuv simulyatsiya qilinmoqda…', () => game.simulateUserFixture(f));
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
              );
            },
            icon: const Icon(Icons.fast_forward_rounded, size: 18),
            label: Text(tr('Tezkor natija')),
          ),
        ],
      ),
    );
  }

  Widget _roundDone(BuildContext context, GameState game) {
    final nextDate = game.currentRound < game.totalRounds
        ? game.calendar.dateOfRound(game.currentRound + 1)
        : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('Tur yakunlandi'), icon: Icons.check_circle_outline),
          Text(
            trf('Barcha natijalar jadvalga yozildi.{0}', [nextDate != null ? ' Keyingi o‘yin kuni: ${SeasonCalendar.format(nextDate)}.' : '']),
            style: AppText.small,
          ),
          const SizedBox(height: 14),
          if (nextDate != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: game.nextRound,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(tr('Keyingi turga o‘tish')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _seasonEnd(BuildContext context, GameState game) {
    final table = game.sortedStandings;
    final champion = game.getClubById(table.first.clubId)!;
    final pos = game.positionOf(game.userClubId!);
    final met = pos <= game.objective.targetPosition;
    return AppCard(
      child: Column(
        children: [
          const Icon(Icons.emoji_events_rounded, size: 40, color: AppColors.gold),
          const SizedBox(height: 8),
          Text(trf('Mavsum {0} yakunlandi', [game.seasonLabel]), style: AppText.h2),
          const SizedBox(height: 14),
          ClubHeading(club: champion, size: 64, caption: trf('Chempion · {0} ochko', [table.first.points])),
          const SizedBox(height: 14),
          InfoRow(tr('Sizning o‘rningiz'), '$pos-o‘rin'),
          InfoRow(
            trf('Kengash maqsadi ({0})', [game.objective.title]),
            met ? tr('Bajarildi') : tr('Bajarilmadi'),
            valueColor: met ? AppColors.win : AppColors.loss,
          ),
          if (game.pendingMoves[game.userClubId] case final next?)
            InfoRow(
              tr('Keyingi mavsum'),
              InitialDatabase.leagueName(next),
              valueColor: InitialDatabase.info(next).tier < game.leagueInfo.tier ? AppColors.win : AppColors.loss,
            ),
          if (game.pendingMoves.isNotEmpty) ...[
            const Divider(height: 22),
            for (final l in InitialDatabase.pyramidOf(game.leagueId))
              if (game.pendingMoves.entries.where((e) => e.value == l.id).toList() case final arriving when arriving.isNotEmpty)
                InfoRow(
                  '${l.name}ga',
                  arriving.map((e) => game.getClubById(e.key)?.shortName ?? '').join(', '),
                ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: game.startNextSeason,
              icon: const Icon(Icons.autorenew_rounded),
              label: Text(tr('Yangi mavsumni boshlash')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availabilityWarning(GameState game) {
    final list = game.unavailableStarters;
    return AppCard(
      color: const Color(0xFFFFF4F2),
      child: Row(
        children: [
          const Icon(Icons.local_hospital_outlined, color: AppColors.live),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trf('Asosiy tarkibda o‘ynay olmaydiganlar: {0}', [list.map((p) => p.shortName).join(', ')]),
              style: AppText.small.copyWith(color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: game.fixUnavailableStarters,
            child: Text(tr('Almashtirish')),
          ),
        ],
      ),
    );
  }

  Widget _lastResult(BuildContext context, GameState game, Club club, Fixture f) {
    final h = game.getClubById(f.homeClubId)!, a = game.getClubById(f.awayClubId)!;
    final motm = f.motmId == null ? null : (h.playerById(f.motmId!) ?? a.playerById(f.motmId!));
    final result = f.resultFor(club.id);
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(tr('OXIRGI NATIJA'), style: AppText.overline)),
              FormChip(result, size: 20),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink3),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    ClubCrestWidget(config: h.crestConfig, size: 30),
                    const SizedBox(width: 8),
                    Flexible(child: Text(h.shortName, style: AppText.bodyStrong)),
                  ],
                ),
              ),
              Text('${f.homeScore} – ${f.awayScore}', style: AppText.h1),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(child: Text(a.shortName, style: AppText.bodyStrong)),
                    const SizedBox(width: 8),
                    ClubCrestWidget(config: a.crestConfig, size: 30),
                  ],
                ),
              ),
            ],
          ),
          if (motm != null) ...[
            const Divider(height: 22),
            Row(
              children: [
                FaceAvatar(config: motm.face, size: 30, shirt: (h.playerById(motm.id) != null ? h : a).primaryColor, circle: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('O‘yin qahramoni'), style: AppText.caption),
                      Text(motm.name, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                    ],
                  ),
                ),
                RatingBadge(f.ratings[motm.id], star: true),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fixturesCard(BuildContext context, GameState game, Club club, List<Fixture> upcoming) => AppCard(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(tr('Taqvim'), icon: Icons.event_outlined, action: tr('Barchasi'), onAction: onNavigateToTable),
        ),
        if (upcoming.isEmpty)
          EmptyState(icon: Icons.event_busy_outlined, text: tr('Mavsumda boshqa o‘yin qolmadi'))
        else
          for (final f in upcoming) FixtureTile(fixture: f, highlightClubId: club.id),
      ],
    ),
  );

  Widget _boardCard(GameState game) {
    final conf = game.boardConfidence;
    final color = conf >= 65
        ? AppColors.win
        : conf >= 40
        ? AppColors.warning
        : AppColors.loss;
    final pos = game.positionOf(game.userClubId!);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(tr('Boshqaruv kengashi'), icon: Icons.account_balance_outlined),
          InfoRow(tr('Mavsum maqsadi'), game.objective.title),
          InfoRow(
            tr('Joriy holat'),
            '$pos-o‘rin',
            valueColor: pos <= game.objective.targetPosition ? AppColors.win : AppColors.loss,
          ),
          MeterRow(label: tr('Kengash ishonchi'), value: conf / 100, trailing: '$conf%', color: color),
          MeterRow(
            label: tr('Muxlislar kayfiyati'),
            value: game.userClub.fanMood / 100,
            trailing: '${game.userClub.fanMood}%',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _topPerformers(BuildContext context, Club club) {
    final rated = club.squad.where((p) => p.averageRating != null).toList()
      ..sort((a, b) => b.averageRating!.compareTo(a.averageRating!));
    final list = rated.isNotEmpty
        ? rated.take(4).toList()
        : (List.of(club.squad)..sort((a, b) => b.ovr.compareTo(a.ovr))).take(4).toList();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(
              rated.isNotEmpty ? tr('Eng yaxshi reytinglar') : tr('Yetakchi futbolchilar'),
              icon: Icons.star_outline_rounded,
              action: tr('Tarkib'),
              onAction: onNavigateToSquad,
            ),
          ),
          for (final p in list)
            PlayerTile(
              player: p,
              club: club,
              subtitle: trf('{0} o‘yin · {1} gol · {2} assist', [p.seasonMatches, p.seasonGoals, p.seasonAssists]),
              onTap: () => PlayerDetailView.show(context, player: p, club: club),
            ),
        ],
      ),
    );
  }

  /// Unread offers, injuries and growth as tappable tiles, so they are not
  /// buried in the news feed.
  List<Widget> _inbox(BuildContext context, GameState game) {
    final unread = game.news.where((n) => !n.read).toList();
    int count(NewsKind k) => unread.where((n) => n.kind == k).length;
    final tiles = <Widget>[
      if (game.offers.isNotEmpty)
        _inboxTile(NewsKind.transfer, '${game.offers.length} ta taklif', 'Sotish takliflari kutmoqda', onNavigateToTransfers),
      if (count(NewsKind.injury) > 0)
        _inboxTile(
          NewsKind.injury,
          '${count(NewsKind.injury)} jarohat',
          unread.firstWhere((n) => n.kind == NewsKind.injury).title,
          () => _openNews(context, game),
        ),
      if (count(NewsKind.award) > 0)
        _inboxTile(
          NewsKind.award,
          '${count(NewsKind.award)} yangilik',
          unread.firstWhere((n) => n.kind == NewsKind.award).title,
          () => _openNews(context, game),
        ),
      if (count(NewsKind.contract) > 0)
        _inboxTile(NewsKind.contract, 'Shartnomalar', 'Muddati tugayotganlar bor', onNavigateToSquad),
    ];
    if (tiles.isEmpty) return const [];
    return [
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => tiles[i],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  void _openNews(BuildContext context, GameState game) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const NewsPage()),
  );

  Widget _inboxTile(NewsKind kind, String title, String body, VoidCallback? onTap) => SizedBox(
    width: 220,
    child: Material(
      color: kind.color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(kind.icon, color: kind.color, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: kind.color)),
                    Text(body, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _newsCard(BuildContext context, GameState game) => AppCard(
    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            tr('Yangiliklar'),
            icon: Icons.newspaper_outlined,
            action: tr('Barchasi'),
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const NewsPage()),
            ),
          ),
        ),
        for (final n in game.news.take(3)) NewsTile(item: n, dense: true),
      ],
    ),
  );
}
