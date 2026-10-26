import '../data/initial_database.dart';
import 'flag.dart';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import 'face_avatar.dart';
import 'widgets.dart';
import '../l10n/l10n.dart';

/// SofaScore-like event row: date column, two team lines, scores on the right.
class FixtureTile extends StatelessWidget {
  final Fixture fixture;
  final String? highlightClubId;
  final VoidCallback? onTap;
  const FixtureTile({
    super.key,
    required this.fixture,
    this.highlightClubId,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    final h = game.getClubById(fixture.homeClubId)!;
    final a = game.getClubById(fixture.awayClubId)!;
    final played = fixture.hasResult;
    final result = highlightClubId == null ? '' : fixture.resultFor(highlightClubId!);
    Widget team(Club c, int? score, bool winner) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          ClubCrestWidget(config: c.crestConfig, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: c.id == highlightClubId || winner
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: played && !winner ? AppColors.ink2 : AppColors.ink,
              ),
            ),
          ),
          if (played)
            Text(
              '$score',
              style: AppText.number.copyWith(
                fontSize: 15,
                color: winner ? AppColors.ink : AppColors.ink2,
              ),
            ),
        ],
      ),
    );
    final d = fixture.date;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(
                    d == null ? trf('{0}-tur', [fixture.round]) : SeasonCalendar.short(d),
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    played ? 'FT' : trf('{0}-tur', [fixture.round]),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: played ? AppColors.ink2 : AppColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.only(right: 12),
              color: AppColors.line,
            ),
            Expanded(
              child: Column(
                children: [
                  team(h, fixture.homeScore, played && fixture.homeScore! > fixture.awayScore!),
                  team(a, fixture.awayScore, played && fixture.awayScore! > fixture.homeScore!),
                ],
              ),
            ),
            if (result.isNotEmpty) ...[
              const SizedBox(width: 10),
              FormChip(result, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

/// League table. [compact] shows only rank, team, played, GD and points.
class StandingsTable extends StatelessWidget {
  final bool compact;
  final String? highlightClubId;
  final ValueChanged<Club>? onTapClub;

  /// Another league of the pyramid (its background table); null = own.
  final String? leagueId;
  const StandingsTable({
    super.key,
    this.compact = false,
    this.highlightClubId,
    this.onTapClub,
    this.leagueId,
  });

  static const _blue = Color(0xFF374DF5),
      _green = Color(0xFF12A150),
      _orange = Color(0xFFF5A524),
      _teal = Color(0xFF14B8A6),
      _red = Color(0xFFE5352B);

  /// Table zones. Top flights: champion, Champions/Europa/Conference
  /// League and relegation; lower tiers: automatic promotion, play-offs
  /// and relegation.
  static Color zoneColor(int pos, [int? clubs, String? league]) {
    final game = GameState();
    final info = InitialDatabase.info(league ?? game.leagueId);
    final n = clubs ?? (league == null || league == game.leagueId ? game.clubCount : game.divisions[league]?.clubs.length ?? 20);
    if (info.tier > 1) {
      if (pos <= info.promote) return _green;
      if (info.hasPlayoff && pos >= info.playoffFrom && pos <= info.playoffTo) return _orange;
      if (info.relegate > 0 && pos > n - info.relegate) return _red;
      return Colors.transparent;
    }
    if (pos == 1) return _blue;
    if (pos <= 4) return _green;
    if (pos == 5) return _orange;
    if (n > 10 && pos == 6) return _teal;
    if (n > 10 ? pos > n - 3 : pos == n) return _red;
    return Colors.transparent;
  }

  /// Legend label of the zone [pos] falls in (null in mid-table).
  static String? zoneLabel(int pos) {
    final c = zoneColor(pos);
    return legend().where((e) => e.$1 == c).firstOrNull?.$2;
  }

  /// Legend entries matching [zoneColor] for a league.
  static List<(Color, String)> legend([String? league]) {
    final game = GameState();
    final info = InitialDatabase.info(league ?? game.leagueId);
    if (info.tier > 1) {
      return [
        (_green, tr('Avtomatik ko‘tarilish')),
        if (info.hasPlayoff) (_orange, trf('Pley-off ({0}–{1})', [info.playoffFrom, info.playoffTo])),
        if (info.relegate > 0) (_red, tr('Quyi ligaga tushish')),
      ];
    }
    final big = (league == null || league == game.leagueId ? game.clubCount : 20) > 10;
    // Generic names: the real continental competitions are trademarks.
    return [
      (_blue, tr('Chempion')),
      (_green, tr('Kontinental kubok')),
      (_orange, tr('Ikkinchi kontinental kubok')),
      if (big) (_teal, tr('Kontinental saralash')),
      (_red, big ? tr('Quyi ligaga tushish') : tr('Quyi liga xavfi')),
    ];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GameState(),
    builder: (context, _) => _table(context),
  );

  Widget _table(BuildContext context) {
    final game = GameState();
    final other = leagueId == null || leagueId == game.leagueId ? null : game.divisions[leagueId];
    final rows = other?.sorted ?? game.sortedStandings;
    TextStyle head = AppText.caption.copyWith(fontWeight: FontWeight.w600);
    Widget cell(String t, double w, {TextStyle? style, bool bold = false}) => SizedBox(
      width: w,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: style ??
            AppText.number.copyWith(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? AppColors.ink : AppColors.ink2,
            ),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
      final full = !compact && box.maxWidth >= 520;
      final form = !compact && box.maxWidth >= 680;
      return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              cell('#', 28, style: head),
              Expanded(child: Text(tr('Jamoa'), style: head)),
              cell(tr('O'), 26, style: head),
              if (full) ...[
                cell(tr('G'), 24, style: head),
                cell(tr('D'), 24, style: head),
                cell(tr('M'), 24, style: head),
                cell(tr('To‘plar'), 50, style: head),
              ],
              cell('±', 32, style: head),
              cell(tr('O‘'), 32, style: head),
              if (form) SizedBox(width: 118, child: Text(tr('  Forma'), style: head)),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++)
          // The compact table of a big league shows the top four and the
          // clubs around the manager's side.
          if (!compact ||
              rows.length <= 10 ||
              i < 4 ||
              (i - rows.indexWhere((r) => r.clubId == highlightClubId)).abs() <= 2)
          Builder(
            builder: (context) {
              final s = rows[i];
              final club = game.getClubById(s.clubId)!;
              final mine = club.id == highlightClubId;
              return Material(
                color: mine ? AppColors.primarySoft : Colors.transparent,
                child: InkWell(
                  onTap: onTapClub == null ? null : () => onTapClub!(club),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Center(
                            child: Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: zoneColor(i + 1, rows.length, leagueId),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: zoneColor(i + 1, rows.length, leagueId) == Colors.transparent
                                      ? AppColors.ink
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        ClubCrestWidget(config: club.crestConfig, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            compact ? club.name : club.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        cell('${s.played}', 26),
                        if (full) ...[
                          cell('${s.won}', 24),
                          cell('${s.drawn}', 24),
                          cell('${s.lost}', 24),
                          cell('${s.goalsFor}:${s.goalsAgainst}', 50),
                        ],
                        cell('${s.goalDifference > 0 ? '+' : ''}${s.goalDifference}', 32),
                        cell('${s.points}', 32, bold: true),
                        if (form)
                          SizedBox(
                            width: 118,
                            child: Row(
                              children: [
                                const SizedBox(width: 6),
                                for (final r in s.formGuide) FormChip(r, size: 19),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
      },
    );
  }
}

/// Player list row: portrait, name, position, status and quality badges.
class PlayerTile extends StatelessWidget {
  final Player player;
  final Club club;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? subtitle;
  final bool showRating;
  const PlayerTile({
    super.key,
    required this.player,
    required this.club,
    this.onTap,
    this.trailing,
    this.subtitle,
    this.showRating = true,
  });
  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final p = player;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                FaceAvatar(
                  config: p.face,
                  size: 42,
                  shirt: club.primaryColor,
                  trim: club.secondaryColor,
                  circle: true,
                ),
                if (!p.isAvailable)
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        p.isInjured ? Icons.local_hospital_rounded : Icons.block_rounded,
                        size: 13,
                        color: AppColors.live,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyStrong,
                        ),
                      ),
                      const SizedBox(width: 6),
                      FlagView(p.countryFlag, nationality: p.nationality, height: 11),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      PositionChip(p.mainPosition.code),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle ?? trf('#{0} · {1} yosh · {2}%', [p.number, p.age, p.currentStamina]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (showRating && p.averageRating != null) ...[
              RatingBadge(p.averageRating, size: 12),
              const SizedBox(width: 8),
            ],
            trailing ?? ValueBadge(p.ovr, size: 32),
          ],
        ),
      ),
    );
  }
}

/// Small crest + name block used in headers.
class ClubHeading extends StatelessWidget {
  final Club club;
  final double size;
  final CrossAxisAlignment align;
  final String? caption;
  const ClubHeading({
    super.key,
    required this.club,
    this.size = 56,
    this.align = CrossAxisAlignment.center,
    this.caption,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    children: [
      ClubCrestWidget(config: club.crestConfig, size: size),
      const SizedBox(height: 8),
      Text(
        club.name,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      if (caption != null) ...[
        const SizedBox(height: 2),
        Text(caption!, style: AppText.caption),
      ],
    ],
  );
}
