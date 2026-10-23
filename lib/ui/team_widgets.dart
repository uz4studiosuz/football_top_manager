import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../services/season_calendar.dart';
import 'face_avatar.dart';
import 'widgets.dart';

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
                    d == null ? '${fixture.round}-tur' : SeasonCalendar.short(d),
                    style: AppText.caption,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    played ? 'FT' : '${fixture.round}-tur',
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
  const StandingsTable({
    super.key,
    this.compact = false,
    this.highlightClubId,
    this.onTapClub,
  });

  static Color zoneColor(int pos) => switch (pos) {
    1 => const Color(0xFF374DF5),
    2 || 3 || 4 => const Color(0xFF12A150),
    5 => const Color(0xFFF5A524),
    8 => const Color(0xFFE5352B),
    _ => Colors.transparent,
  };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: GameState(),
    builder: (context, _) => _table(context),
  );

  Widget _table(BuildContext context) {
    final game = GameState();
    final rows = game.sortedStandings;
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
              Expanded(child: Text('Jamoa', style: head)),
              cell('O', 26, style: head),
              if (full) ...[
                cell('G', 24, style: head),
                cell('D', 24, style: head),
                cell('M', 24, style: head),
                cell('To‘plar', 50, style: head),
              ],
              cell('±', 32, style: head),
              cell('O‘', 32, style: head),
              if (form) SizedBox(width: 118, child: Text('  Forma', style: head)),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++)
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
                                color: zoneColor(i + 1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: zoneColor(i + 1) == Colors.transparent
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
                      Text(p.countryFlag, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      PositionChip(p.mainPosition.code),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle ?? '#${p.number} · ${p.age} yosh · ${p.currentStamina}%',
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
