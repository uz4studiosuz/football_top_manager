import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/league.dart';
import '../models/player.dart';
import '../services/match_field.dart';
import 'face_avatar.dart';
import 'football_pitch.dart';
import 'widgets.dart';

/// One statistic row shared by the live screen and the match report.
class StatLine {
  final String label;
  final num home, away;
  final String Function(num)? format;
  final bool higherIsBetter;
  const StatLine(
    this.label,
    this.home,
    this.away, {
    this.format,
    this.higherIsBetter = true,
  });
}

String _pct(num v) => '${v.round()}%';
String _dec(num v) => v.toStringAsFixed(2);

List<(String, List<StatLine>)> statGroupsFromEngine(MatchField e) {
  final h = e.homeStats, a = e.awayStats;
  final hp = e.homePossessionPercent;
  return [
    (
      'Umumiy',
      [
        StatLine('To‘p nazorati', hp, 100 - hp, format: _pct),
        StatLine('Kutilgan gollar (xG)', h.xg, a.xg, format: _dec),
        StatLine('Katta imkoniyatlar', h.bigChances, a.bigChances),
        StatLine('Jami zarbalar', h.shots, a.shots),
        StatLine('Darvozabon seyvlari', h.saves, a.saves),
        StatLine('Burchaklar', h.corners, a.corners),
        StatLine('Qoidabuzarliklar', h.fouls, a.fouls, higherIsBetter: false),
        StatLine('Jarima zarbalari', h.freeKicks, a.freeKicks),
      ],
    ),
    (
      'Zarbalar',
      [
        StatLine('Nishonga', h.onTarget, a.onTarget),
        StatLine('Nishondan tashqari', h.shots - h.onTarget - h.blocked, a.shots - a.onTarget - a.blocked),
        StatLine('To‘silgan', h.blocked, a.blocked),
      ],
    ),
    (
      'Hujum va paslar',
      [
        StatLine('Paslar', h.passes, a.passes),
        StatLine('Aniq paslar', h.completedPasses, a.completedPasses),
        StatLine('Pas aniqligi', h.passAccuracy, a.passAccuracy, format: _pct),
        StatLine('Krosslar', h.crosses, a.crosses),
        StatLine('Driblinglar', h.dribbles, a.dribbles),
        StatLine('Ofsaydlar', h.offsides, a.offsides, higherIsBetter: false),
      ],
    ),
    (
      'Himoya va intizom',
      [
        StatLine('Olib qo‘yishlar', h.tackles, a.tackles),
        StatLine('Pas kesishlar', h.interceptions, a.interceptions),
        StatLine('Sariq kartochkalar', h.yellows, a.yellows, higherIsBetter: false),
        StatLine('Qizil kartochkalar', h.reds, a.reds, higherIsBetter: false),
      ],
    ),
  ];
}

List<(String, List<StatLine>)> statGroupsFromFixture(Fixture f) {
  final hAcc = f.homePasses == 0 ? 0 : f.homeCompletedPasses * 100 / f.homePasses;
  final aAcc = f.awayPasses == 0 ? 0 : f.awayCompletedPasses * 100 / f.awayPasses;
  return [
    (
      'Umumiy',
      [
        StatLine('To‘p nazorati', f.homePossession, f.awayPossession, format: _pct),
        StatLine('Kutilgan gollar (xG)', f.homeXG, f.awayXG, format: _dec),
        StatLine('Katta imkoniyatlar', f.homeBigChances, f.awayBigChances),
        StatLine('Jami zarbalar', f.homeShots, f.awayShots),
        StatLine('Nishonga', f.homeShotsOnTarget, f.awayShotsOnTarget),
        StatLine('Darvozabon seyvlari', f.homeSaves, f.awaySaves),
        StatLine('Burchaklar', f.homeCorners, f.awayCorners),
      ],
    ),
    (
      'Paslar va himoya',
      [
        StatLine('Paslar', f.homePasses, f.awayPasses),
        StatLine('Pas aniqligi', hAcc, aAcc, format: _pct),
        StatLine('Olib qo‘yishlar', f.homeTackles, f.awayTackles),
        StatLine('Ofsaydlar', f.homeOffsides, f.awayOffsides, higherIsBetter: false),
        StatLine('Qoidabuzarliklar', f.homeFouls, f.awayFouls, higherIsBetter: false),
        StatLine(
          'Jarima zarbalari',
          f.awayFouls + f.awayOffsides,
          f.homeFouls + f.homeOffsides,
        ),
        StatLine('Sariq kartochkalar', f.homeYellows, f.awayYellows, higherIsBetter: false),
        StatLine('Qizil kartochkalar', f.homeReds, f.awayReds, higherIsBetter: false),
      ],
    ),
  ];
}

class StatGroupsView extends StatelessWidget {
  final List<(String, List<StatLine>)> groups;
  final Color homeColor, awayColor;
  const StatGroupsView({
    super.key,
    required this.groups,
    required this.homeColor,
    required this.awayColor,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final g in groups)
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(g.$1, padding: const EdgeInsets.only(bottom: 4)),
              for (final s in g.$2)
                StatCompareRow(
                  label: s.label,
                  homeText: s.format?.call(s.home) ?? '${s.home}',
                  awayText: s.format?.call(s.away) ?? '${s.away}',
                  home: s.home.toDouble(),
                  away: s.away.toDouble(),
                  higherIsBetter: s.higherIsBetter,
                  homeColor: homeColor,
                  awayColor: awayColor,
                ),
            ],
          ),
        ),
    ],
  );
}

/// Picks contrasting display colours for two clubs.
(Color, Color) teamColors(Club home, Club away) {
  Color pick(Club c) {
    final p = c.primaryColor;
    return p.computeLuminance() > 0.82 ? c.secondaryColor : p;
  }

  final h = pick(home);
  var a = pick(away);
  final diff = (h.r - a.r).abs() + (h.g - a.g).abs() + (h.b - a.b).abs();
  if (diff < 0.45) {
    a = away.secondaryColor.computeLuminance() > 0.82
        ? const Color(0xFF16A6A0)
        : away.secondaryColor;
  }
  return (h, a);
}

/// SofaScore "attack momentum": bars above the axis for home pressure,
/// below for away, with goal markers.
class MomentumChart extends StatelessWidget {
  final List<double> values;
  final List<MatchEvent> events;
  final Color homeColor, awayColor;
  final double height;
  const MomentumChart({
    super.key,
    required this.values,
    required this.events,
    required this.homeColor,
    required this.awayColor,
    this.height = 96,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(
      painter: _MomentumPainter(values, events, homeColor, awayColor),
    ),
  );
}

class _MomentumPainter extends CustomPainter {
  final List<double> values;
  final List<MatchEvent> events;
  final Color home, away;
  _MomentumPainter(this.values, this.events, this.home, this.away);
  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final axis = Paint()
      ..color = AppColors.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), axis);
    final total = max(96, values.length);
    final bw = size.width / total;
    final halfX = size.width * 47 / total;
    canvas.drawLine(
      Offset(halfX, 4),
      Offset(halfX, size.height - 4),
      axis..color = AppColors.line.withValues(alpha: 0.9),
    );
    for (var i = 0; i < values.length; i++) {
      final v = values[i] / 100;
      final hgt = (mid - 8) * min(1, v.abs() * 2.4);
      if (hgt < 0.5) continue;
      final r = v > 0
          ? Rect.fromLTWH(i * bw + 0.5, mid - hgt, max(1, bw - 1), hgt)
          : Rect.fromLTWH(i * bw + 0.5, mid, max(1, bw - 1), hgt);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(1.2)),
        Paint()..color = (v > 0 ? home : away).withValues(alpha: 0.85),
      );
    }
    for (final e in events.where((e) => e.type == MatchEventType.goal)) {
      final idx = (e.minute <= 45 ? e.minute + e.extraMinute : e.minute + 2 + e.extraMinute) - 1;
      final x = (idx.clamp(0, total - 1) + 0.5) * bw;
      final y = e.isHomeTeam ? 7.0 : size.height - 7;
      canvas.drawCircle(Offset(x, y), 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(x, y),
        5.5,
        Paint()
          ..color = e.isHomeTeam ? home : away
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      canvas.drawCircle(Offset(x, y), 2, Paint()..color = AppColors.ink);
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter old) => true;
}

/// Key incidents (goals, cards, subs) on a centred timeline.
class IncidentTimeline extends StatelessWidget {
  final List<MatchEvent> events;
  final bool newestFirst;
  const IncidentTimeline({super.key, required this.events, this.newestFirst = true});
  @override
  Widget build(BuildContext context) {
    bool key(MatchEvent e) =>
        e.type.isIncident &&
        e.type != MatchEventType.halfTime &&
        e.type != MatchEventType.fullTime;
    final htIndex = events.indexWhere((e) => e.type == MatchEventType.halfTime);
    final ftIndex = events.indexWhere((e) => e.type == MatchEventType.fullTime);
    final firstEnd = htIndex < 0 ? events.length : htIndex;
    final first = events.take(firstEnd).where(key).toList();
    final second = htIndex < 0 ? <MatchEvent>[] : events.skip(htIndex).where(key).toList();
    Widget divider(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(text, style: AppText.overline),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
    Widget quiet(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(child: Text(text, style: AppText.caption)),
    );
    final ht = htIndex < 0 ? null : events[htIndex];
    final ft = ftIndex < 0 ? null : events[ftIndex];
    // SofaScore layout: one section per half, each with its own score.
    final firstSection = <Widget>[
      divider(ht == null ? '1-BO‘LIM' : '1-BO‘LIM  ${ht.homeScore} – ${ht.awayScore}'),
      if (first.isEmpty)
        quiet(ht == null ? 'Hozircha muhim voqealar yo‘q' : 'Muhim voqealar bo‘lmadi')
      else
        for (final e in (newestFirst ? first.reversed : first)) _IncidentRow(e),
    ];
    final secondSection = ht == null
        ? <Widget>[]
        : <Widget>[
            divider(ft == null ? '2-BO‘LIM' : '2-BO‘LIM  ${ft.homeScore} – ${ft.awayScore}'),
            if (second.isEmpty)
              quiet(ft == null ? 'Hozircha muhim voqealar yo‘q' : 'Muhim voqealar bo‘lmadi')
            else
              for (final e in (newestFirst ? second.reversed : second)) _IncidentRow(e),
          ];
    return Column(
      children: newestFirst
          ? [...secondSection, ...firstSection]
          : [...firstSection, ...secondSection],
    );
  }
}

class _IncidentRow extends StatelessWidget {
  final MatchEvent e;
  const _IncidentRow(this.e);
  Widget _icon() => switch (e.type) {
    MatchEventType.goal => const Icon(Icons.sports_soccer, size: 18, color: AppColors.ink),
    MatchEventType.yellowCard => Container(
      width: 11,
      height: 15,
      decoration: BoxDecoration(color: const Color(0xFFF5C518), borderRadius: BorderRadius.circular(2)),
    ),
    MatchEventType.redCard => Container(
      width: 11,
      height: 15,
      decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(2)),
    ),
    MatchEventType.substitution => const Icon(Icons.swap_vert_rounded, size: 18, color: AppColors.win),
    MatchEventType.injury => const Icon(Icons.local_hospital_outlined, size: 18, color: AppColors.live),
    _ => Icon(e.type.iconData, size: 18, color: AppColors.ink2),
  };
  @override
  Widget build(BuildContext context) {
    final name = e.playerName?.split(' ').last ?? '';
    final title = switch (e.type) {
      MatchEventType.substitution => e.playerName == null ? '' : e.playerName!,
      _ => name.isEmpty ? e.type.label : (e.playerName ?? ''),
    };
    final sub = switch (e.type) {
      MatchEventType.goal => e.secondaryName == null ? 'Gol' : 'Assist: ${e.secondaryName}',
      MatchEventType.substitution => 'Chiqdi: ${e.secondaryName ?? ''}',
      MatchEventType.injury => 'Jarohat',
      MatchEventType.yellowCard => 'Sariq kartochka',
      MatchEventType.redCard => 'Qizil kartochka',
      _ => e.type.label,
    };
    final content = Flexible(
      child: Column(
        crossAxisAlignment: e.isHomeTeam ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyStrong.copyWith(fontSize: 13),
          ),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
        ],
      ),
    );
    final score = e.type == MatchEventType.goal
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${e.homeScore} - ${e.awayScore}',
              style: AppText.number.copyWith(fontSize: 12),
            ),
          )
        : const SizedBox(width: 6);
    final row = <Widget>[
      SizedBox(
        width: 42,
        child: Text(
          e.minuteLabel,
          textAlign: e.isHomeTeam ? TextAlign.left : TextAlign.right,
          style: AppText.number.copyWith(fontSize: 12, color: AppColors.ink2),
        ),
      ),
      _icon(),
      score,
      content,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: e.isHomeTeam ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: e.isHomeTeam ? row : row.reversed.toList(),
      ),
    );
  }
}

/// Commentary feed entry (full play-by-play log).
class CommentaryTile extends StatelessWidget {
  final MatchEvent event;
  final Color homeColor, awayColor;
  const CommentaryTile({
    super.key,
    required this.event,
    required this.homeColor,
    required this.awayColor,
  });
  @override
  Widget build(BuildContext context) {
    final e = event;
    final key = e.type == MatchEventType.goal;
    final strong = key ||
        e.type == MatchEventType.redCard ||
        e.type == MatchEventType.penalty ||
        e.type == MatchEventType.halfTime ||
        e.type == MatchEventType.fullTime;
    final accent = e.isHomeTeam ? homeColor : awayColor;
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      color: key ? accent.withValues(alpha: 0.07) : AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              e.minuteLabel,
              style: AppText.number.copyWith(
                fontSize: 12,
                color: key ? accent : AppColors.ink2,
              ),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: switch (e.type) {
                MatchEventType.goal => accent,
                MatchEventType.yellowCard => const Color(0xFFF5C518),
                MatchEventType.redCard => AppColors.live,
                _ => AppColors.surfaceAlt,
              },
              shape: BoxShape.circle,
            ),
            child: Icon(
              e.type.iconData,
              size: 14,
              color: switch (e.type) {
                MatchEventType.goal || MatchEventType.redCard => Colors.white,
                MatchEventType.yellowCard => AppColors.ink,
                _ => AppColors.ink2,
              },
            ),
          ),
          Expanded(
            child: Text(
              e.description,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: strong ? AppColors.ink : AppColors.ink2,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact name for pitch labels: "K. Mbappé" → "Mbappé", "Vinícius Jr" stays.
String surname(Player p) {
  final s = p.shortName;
  final dot = s.indexOf('. ');
  return dot >= 0 && dot <= 3 ? s.substring(dot + 2) : s;
}

/// Line-up on a vertical pitch with SofaScore rating pills under each name.
class LineupPitch extends StatelessWidget {
  final Club club;
  final List<Player> players; // slot order
  final Map<String, double?> ratings;
  final Set<String> dismissed;
  final Map<String, int> goals;
  final Set<String> booked;
  final Color shirt;
  final ValueChanged<Player>? onTap;
  final bool flip;
  final Map<String, PlayerMatchStats> lines;
  const LineupPitch({
    super.key,
    required this.club,
    required this.players,
    required this.ratings,
    this.dismissed = const {},
    this.goals = const {},
    this.booked = const {},
    required this.shirt,
    this.onTap,
    this.flip = false,
    this.lines = const {},
  });
  @override
  Widget build(BuildContext context) {
    final slots = club.tactics.formation.slots;
    return AspectRatio(
      aspectRatio: 0.92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: const FootballPitchPainter(vertical: true),
                ),
              ),
              for (var i = 0; i < min(players.length, slots.length); i++)
                Positioned(
                  left: (slots[i].x * box.maxWidth - 34).clamp(2, box.maxWidth - 70),
                  top: ((flip ? 1 - slots[i].y : slots[i].y) * 0.92 * box.maxHeight + 0.02 * box.maxHeight - 26)
                      .clamp(2, box.maxHeight - 62),
                  child: _LineupNode(
                    player: players[i],
                    rating: ratings[players[i].id],
                    shirt: shirt,
                    out: dismissed.contains(players[i].id),
                    goals: goals[players[i].id] ?? 0,
                    booked: booked.contains(players[i].id),
                    subOn: lines[players[i].id]?.subOnMinute,
                    subOff: lines[players[i].id]?.subOffMinute,
                    onTap: onTap == null ? null : () => onTap!(players[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LineupNode extends StatelessWidget {
  final Player player;
  final double? rating;
  final Color shirt;
  final bool out, booked;
  final int goals;
  final int? subOn, subOff;
  final VoidCallback? onTap;
  const _LineupNode({
    required this.player,
    required this.rating,
    required this.shirt,
    required this.out,
    required this.goals,
    required this.booked,
    this.subOn,
    this.subOff,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: out ? 0.4 : 1,
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: FaceAvatar(
                    config: player.face,
                    size: 34,
                    shirt: shirt,
                    circle: true,
                    background: true,
                  ),
                ),
                if (rating != null)
                  Positioned(right: -14, top: -4, child: RatingBadge(rating, size: 9.5)),
                if (goals > 0)
                  Positioned(
                    left: -8,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.sports_soccer, size: 11, color: AppColors.ink),
                    ),
                  ),
                if (subOn != null)
                  Positioned(
                    left: -10,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward_rounded, size: 10, color: AppColors.win),
                    ),
                  ),
                if (subOff != null)
                  Positioned(
                    left: -12,
                    bottom: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 9, color: AppColors.live),
                          Text(
                            '$subOff′',
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.live),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (booked)
                  Positioned(
                    right: -4,
                    bottom: 0,
                    child: Container(
                      width: 7,
                      height: 10,
                      decoration: BoxDecoration(
                        color: out ? AppColors.live : const Color(0xFFF5C518),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              '${player.number} ${surname(player)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Player rating list for one team (SofaScore "Player statistics").
class RatingsList extends StatelessWidget {
  final Club club;
  final List<String> ids;
  final Map<String, double?> ratings;
  final Map<String, PlayerMatchStats> lines;
  final String? motmId;
  final ValueChanged<Player>? onTap;
  const RatingsList({
    super.key,
    required this.club,
    required this.ids,
    required this.ratings,
    required this.lines,
    this.motmId,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final players = ids.map(club.playerById).whereType<Player>().toList()
      ..sort((a, b) => (ratings[b.id] ?? 0).compareTo(ratings[a.id] ?? 0));
    return Column(
      children: [
        for (final p in players)
          InkWell(
            onTap: onTap == null ? null : () => onTap!(p),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  FaceAvatar(config: p.face, size: 34, shirt: club.primaryColor, circle: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                p.shortName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.bodyStrong.copyWith(fontSize: 13),
                              ),
                            ),
                            if (p.id == motmId) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            if (lines[p.id]?.subOnMinute != null || lines[p.id]?.subOffMinute != null) ...[
                              SubstitutionMarks(on: lines[p.id]?.subOnMinute, off: lines[p.id]?.subOffMinute),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                _lineSummary(lines[p.id]),
                                style: AppText.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PositionChip(p.mainPosition.code),
                  const SizedBox(width: 10),
                  RatingBadge(ratings[p.id], size: 12.5),
                ],
              ),
            ),
          ),
      ],
    );
  }

  static String _lineSummary(PlayerMatchStats? l) {
    if (l == null) return '';
    final parts = <String>[
      '${min(90, l.minutes.round())}′',
      if (l.goals > 0) '${l.goals} gol',
      if (l.assists > 0) '${l.assists} assist',
      if (l.saves > 0) '${l.saves} seyv',
      '${l.passesCompleted}/${l.passes} pas',
      if (l.tackles + l.interceptions > 0) '${l.tackles + l.interceptions} Olib qo‘yish',
      if (l.keyPasses > 0) '${l.keyPasses} key pas',
    ];
    return parts.join(' · ');
  }
}

/// Shot map on a half pitch – circles sized by xG, filled when a goal.
class ShotMap extends StatelessWidget {
  final List<ShotRecord> shots;
  final Color homeColor, awayColor;
  const ShotMap({super.key, required this.shots, required this.homeColor, required this.awayColor});
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 105 / 68,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CustomPaint(
        painter: _ShotMapPainter(shots, homeColor, awayColor),
      ),
    ),
  );
}

class _ShotMapPainter extends CustomPainter {
  final List<ShotRecord> shots;
  final Color home, away;
  _ShotMapPainter(this.shots, this.home, this.away);
  @override
  void paint(Canvas canvas, Size size) {
    const inset = EdgeInsets.all(4);
    const FootballPitchPainter(
      vertical: false,
      inset: inset,
      grass: Color(0xFF3C8D5C),
      grassAlt: Color(0xFF368453),
    ).paint(canvas, size);
    final r = FootballPitchPainter.field(size, inset);
    for (final s in shots) {
      final o = Offset(r.left + s.origin.dx * r.width, r.top + s.origin.dy * r.height);
      final c = s.home ? home : away;
      final radius = 3 + s.xg * 12;
      if (s.goal) {
        canvas.drawCircle(o, radius, Paint()..color = c);
        canvas.drawCircle(o, radius, Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
      } else {
        canvas.drawCircle(o, radius, Paint()..color = c.withValues(alpha: 0.25));
        canvas.drawCircle(o, radius, Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShotMapPainter old) => true;
}

/// SofaScore-style player match card in a bottom sheet; the full profile
/// stays one tap away.
Future<void> showPlayerMatchSheet(
  BuildContext context, {
  required Player player,
  required Club club,
  PlayerMatchStats? line,
  double? rating,
  required VoidCallback onOpenProfile,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) {
    final l = line;
    final gk = player.mainPosition.isGoalkeeper;
    String pct(int a, int b) => b == 0 ? '0%' : '${(a * 100 / b).round()}%';
    final rows = <(String, String)>[
      if (l != null) ...[
        ('Daqiqalar', '${min(90, l.minutes.round())}′'),
        if (gk) ('Seyvlar', '${l.saves}'),
        if (gk) ('O‘tkazilgan gollar', '${l.goalsConceded}'),
        ('Gollar', '${l.goals}'),
        ('Assistlar', '${l.assists}'),
        ('xG / xA', '${l.xg.toStringAsFixed(2)} / ${l.xa.toStringAsFixed(2)}'),
        ('Zarbalar (nishonga)', '${l.shots} (${l.shotsOnTarget})'),
        if (l.bigChancesMissed > 0) ('Boy berilgan katta imkoniyat', '${l.bigChancesMissed}'),
        ('Kalit paslar', '${l.keyPasses}'),
        ('Aniq paslar', '${l.passesCompleted}/${l.passes} (${pct(l.passesCompleted, l.passes)})'),
        ('Krosslar', '${l.crosses}'),
        ('Driblinglar', '${l.dribblesWon}/${l.dribbles}'),
        ('To‘pga tegishlar', '${l.touches}'),
        ('Olib qo‘yishlar', '${l.tackles}'),
        ('Pas kesishlar', '${l.interceptions}'),
        ('Tozalashlar', '${l.clearances}'),
        ('Bloklangan zarbalar', '${l.blocks}'),
        ('Yakkakurash (yutgan/yutqazgan)', '${l.duelsWon}/${l.duelsLost}'),
        ('To‘p yo‘qotish', '${l.possessionLost}'),
        ('Qoidabuzarlik', '${l.fouls}'),
        ('Qoidabuzarlikka uchragan', '${l.fouled}'),
        if (l.offsides > 0) ('Ofsaydlar', '${l.offsides}'),
        if (l.yellow + l.red > 0) ('Kartochkalar', '${l.yellow} sariq · ${l.red} qizil'),
      ],
    ];
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  FaceAvatar(config: player.face, size: 56, shirt: club.primaryColor, circle: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.name, style: AppText.h3),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            PositionChip(player.mainPosition.code),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${club.shortName} · ${player.playingStyle.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                        if (l?.subOnMinute != null || l?.subOffMinute != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: SubstitutionMarks(on: l?.subOnMinute, off: l?.subOffMinute),
                          ),
                      ],
                    ),
                  ),
                  RatingBadge(rating, size: 16),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: rows.isEmpty
                  ? const EmptyState(icon: Icons.bar_chart_rounded, text: 'Bu o‘yinda maydonga tushmadi')
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      children: [
                        for (final r in rows)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            child: Row(
                              children: [
                                Expanded(child: Text(r.$1, style: AppText.small.copyWith(color: AppColors.ink))),
                                Text(r.$2, style: AppText.number.copyWith(fontSize: 13)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onOpenProfile();
                  },
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profilni ko‘rish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);

/// Green "in" / red "out" arrows with minutes, as on SofaScore line-ups.
class SubstitutionMarks extends StatelessWidget {
  final int? on, off;
  const SubstitutionMarks({super.key, this.on, this.off});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (on != null) ...[
        const Icon(Icons.arrow_upward_rounded, size: 13, color: AppColors.win),
        Text('$on′', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.win)),
        const SizedBox(width: 6),
      ],
      if (off != null) ...[
        const Icon(Icons.arrow_downward_rounded, size: 13, color: AppColors.live),
        Text('$off′', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.live)),
      ],
    ],
  );
}

/// Bench block under the line-up: who came on (with minute and rating)
/// and the unused substitutes.
class SubstitutesList extends StatelessWidget {
  final Club club;
  final List<String> benchIds;
  final Map<String, PlayerMatchStats> lines;
  final Map<String, double?> ratings;
  final ValueChanged<Player>? onTap;
  const SubstitutesList({
    super.key,
    required this.club,
    required this.benchIds,
    required this.lines,
    required this.ratings,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final players = benchIds.map(club.playerById).whereType<Player>().toList();
    final used = players.where((p) => lines[p.id]?.subOnMinute != null).toList();
    final unused = players.where((p) => lines[p.id]?.subOnMinute == null).toList();
    Widget row(Player p) => InkWell(
      onTap: onTap == null ? null : () => onTap!(p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          children: [
            FaceAvatar(config: p.face, size: 32, shirt: club.primaryColor, circle: true),
            const SizedBox(width: 10),
            SizedBox(width: 26, child: Text('${p.number}', style: AppText.caption)),
            Expanded(child: Text(p.shortName, style: AppText.bodyStrong.copyWith(fontSize: 13))),
            if (lines[p.id]?.subOnMinute != null) ...[
              SubstitutionMarks(on: lines[p.id]?.subOnMinute, off: lines[p.id]?.subOffMinute),
              const SizedBox(width: 8),
            ],
            PositionChip(p.mainPosition.code),
            const SizedBox(width: 8),
            RatingBadge(ratings[p.id], size: 12),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text('ZAXIRADAN TUSHGANLAR', style: AppText.overline),
        ),
        if (used.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Hali almashtirish bo‘lmadi', style: AppText.caption),
          ),
        for (final p in used) row(p),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('ZAXIRA', style: AppText.overline),
        ),
        for (final p in unused) row(p),
      ],
    );
  }
}

/// SofaScore-style line-up list: the starting XI in formation order, then
/// substitutes who came on and finally unused bench players. Each change
/// shows who replaced whom and when.
class LineupList extends StatelessWidget {
  final Club club;
  final List<String> starters;
  final List<String> bench;
  final Map<String, PlayerMatchStats> lines;
  final Map<String, double?> ratings;
  final List<MatchEvent> events;
  final String? motmId;
  final ValueChanged<Player>? onTap;
  const LineupList({
    super.key,
    required this.club,
    required this.starters,
    required this.bench,
    required this.lines,
    required this.ratings,
    required this.events,
    this.motmId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Substitution events carry the incoming id and the outgoing short name.
    final replacedBy = <String, String>{}; // out short name -> in short name
    final replaced = <String, String>{}; // in id -> out short name
    for (final e in events.where((e) => e.type == MatchEventType.substitution && e.clubId == club.id)) {
      final incoming = e.playerId == null ? null : club.playerById(e.playerId!);
      if (incoming == null || e.secondaryName == null) continue;
      replacedBy[e.secondaryName!] = incoming.shortName;
      replaced[incoming.id] = e.secondaryName!;
    }
    final xi = starters.map(club.playerById).whereType<Player>().toList();
    final benchPlayers = bench.map(club.playerById).whereType<Player>().toList();
    final cameOn = benchPlayers.where((p) => lines[p.id]?.subOnMinute != null).toList()
      ..sort((a, b) => lines[a.id]!.subOnMinute!.compareTo(lines[b.id]!.subOnMinute!));
    final unused = benchPlayers.where((p) => lines[p.id]?.subOnMinute == null).toList();

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text, style: AppText.overline),
    );

    Widget row(Player p, {String? change, bool on = false, bool off = false}) {
      final l = lines[p.id];
      return InkWell(
        onTap: onTap == null ? null : () => onTap!(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('${p.number}', style: AppText.number.copyWith(fontSize: 12, color: AppColors.ink2)),
              ),
              FaceAvatar(config: p.face, size: 34, shirt: club.primaryColor, circle: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.shortName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyStrong.copyWith(fontSize: 13),
                          ),
                        ),
                        if (p.id == motmId) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, size: 15, color: AppColors.gold),
                        ],
                        if ((l?.goals ?? 0) > 0) ...[
                          const SizedBox(width: 4),
                          for (var i = 0; i < l!.goals; i++)
                            const Icon(Icons.sports_soccer, size: 13, color: AppColors.ink),
                        ],
                        if ((l?.yellow ?? 0) > 0)
                          Container(width: 7, height: 10, margin: const EdgeInsets.only(left: 4), color: const Color(0xFFF5C518)),
                        if ((l?.red ?? 0) > 0)
                          Container(width: 7, height: 10, margin: const EdgeInsets.only(left: 3), color: AppColors.live),
                      ],
                    ),
                    if (change != null)
                      Row(
                        children: [
                          Icon(
                            on ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                            size: 13,
                            color: on ? AppColors.win : AppColors.live,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              change,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: on ? AppColors.win : AppColors.live,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (l != null)
                      Text(RatingsList._lineSummary(l), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption),
                  ],
                ),
              ),
              PositionChip(p.mainPosition.code),
              const SizedBox(width: 8),
              RatingBadge(ratings[p.id], size: 12),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header('ASOSIY TARKIB'),
        for (final p in xi)
          row(
            p,
            off: lines[p.id]?.subOffMinute != null,
            change: lines[p.id]?.subOffMinute == null
                ? null
                : '${lines[p.id]!.subOffMinute}′ · chiqdi'
                      '${replacedBy[p.shortName] == null ? '' : ', o‘rniga ${replacedBy[p.shortName]}'}',
          ),
        header('ZAXIRADAN TUSHGANLAR'),
        if (cameOn.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Almashtirish bo‘lmadi', style: AppText.caption),
          ),
        for (final p in cameOn)
          row(
            p,
            on: true,
            change: '${lines[p.id]!.subOnMinute}′ · tushdi'
                '${replaced[p.id] == null ? '' : ', ${replaced[p.id]} o‘rniga'}',
          ),
        header('ZAXIRA'),
        if (unused.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text('Barcha zaxiralar maydonga tushdi', style: AppText.caption),
          ),
        for (final p in unused) row(p),
        const SizedBox(height: 6),
      ],
    );
  }
}
