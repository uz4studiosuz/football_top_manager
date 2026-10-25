import 'dart:math';
import '../models/club.dart';
import '../models/player.dart';
import '../l10n/l10n.dart';

/// One knockout tie. [away] is null for a bye.
class CupTie {
  final String home;
  final String? away;
  int? homeGoals, awayGoals, homePens, awayPens;
  CupTie(this.home, this.away);

  bool get isBye => away == null;
  bool get played => isBye || homeGoals != null;
  bool get wentToPens => homePens != null;
  bool involves(String id) => home == id || away == id;

  String? get winner {
    if (isBye) return home;
    if (homeGoals == null) return null;
    if (homeGoals != awayGoals) return homeGoals! > awayGoals! ? home : away;
    return homePens! > awayPens! ? home : away;
  }

  String score() => isBye
      ? '—'
      : homeGoals == null
      ? 'v'
      : '$homeGoals – $awayGoals${wentToPens ? ' (pen. $homePens–$awayPens)' : ''}';

  List<dynamic> toList() => [home, away, homeGoals, awayGoals, homePens, awayPens];
  factory CupTie.fromList(List l) => CupTie(l[0], l[1])
    ..homeGoals = l[2]
    ..awayGoals = l[3]
    ..homePens = l[4]
    ..awayPens = l[5];
}

/// A single-leg knockout cup for the clubs of the user's league. Rounds are
/// played in midweek after selected league rounds; draws go to penalties.
class Cup {
  final List<List<CupTie>> rounds;

  /// League round after which each cup round is played.
  final List<int> schedule;
  String? winner;
  Cup(this.rounds, this.schedule);

  int get totalRounds => schedule.length;

  /// Index of the next cup round still to be played (null when finished).
  int? get currentRound {
    for (var i = 0; i < rounds.length; i++) {
      if (rounds[i].any((t) => !t.played)) return i;
    }
    return winner == null && rounds.length < totalRounds ? rounds.length : null;
  }

  static String stageName(int round, int total) {
    final left = total - round;
    return switch (left) {
      1 => tr('Final'),
      2 => tr('Yarim final'),
      3 => tr('Chorak final'),
      4 => tr('1/8 final'),
      _ => trf('{0}-bosqich', [round + 1]),
    };
  }

  /// Draws the first round: the strongest clubs get byes so the second
  /// round has a power-of-two field.
  factory Cup.draw(List<Club> clubs, int leagueRounds, Random rnd) {
    var size = 1;
    while (size < clubs.length) {
      size *= 2;
    }
    final total = (log(size) / ln2).round();
    final seeded = List<Club>.of(clubs)..sort((a, b) => b.reputation.compareTo(a.reputation));
    final byes = size - clubs.length;
    final ties = <CupTie>[for (final c in seeded.take(byes)) CupTie(c.id, null)];
    final rest = seeded.skip(byes).toList()..shuffle(rnd);
    for (var i = 0; i + 1 < rest.length; i += 2) {
      ties.add(CupTie(rest[i].id, rest[i + 1].id));
    }
    ties.shuffle(rnd);
    // Spread the rounds through the season; the final comes before the last league round.
    final schedule = [
      for (var k = 0; k < total; k++) max(2, ((k + 1) * (leagueRounds - 1) / (total + 1)).round()),
    ];
    for (var k = 1; k < schedule.length; k++) {
      if (schedule[k] <= schedule[k - 1]) schedule[k] = schedule[k - 1] + 1;
    }
    return Cup([ties], schedule);
  }

  /// When the latest round is complete, pairs its winners for the next one.
  void advance(Random rnd) {
    final last = rounds.last;
    if (last.any((t) => !t.played)) return;
    final winners = [for (final t in last) t.winner!];
    if (winners.length == 1) {
      winner = winners.first;
      return;
    }
    final next = <CupTie>[];
    for (var i = 0; i + 1 < winners.length; i += 2) {
      // Home advantage alternates by draw.
      next.add(rnd.nextBool() ? CupTie(winners[i], winners[i + 1]) : CupTie(winners[i + 1], winners[i]));
    }
    rounds.add(next);
  }

  Map<String, dynamic> toMap() => {
    'r': [for (final r in rounds) [for (final t in r) t.toList()]],
    's': schedule,
    'w': winner,
  };

  static Cup fromMap(Map<String, dynamic> m) => Cup(
    [for (final r in m['r'] as List) [for (final t in r as List) CupTie.fromList(t as List)]],
    List<int>.from(m['s']),
  )..winner = m['w'];
}

/// Where a penalty is aimed: column 0–2 (left, centre, right as the taker
/// sees it) and row 0–1 (low, high).
typedef Zone = ({int col, int row});

/// The odds behind every penalty, shared by the interactive shootout and
/// the automatic one.
class PenaltyModel {
  static double takerSkill(Player p) => p.stats.setPieceTaking * 0.45 + p.stats.finishing * 0.35 + p.stats.kickingPower * 0.2;
  static double keeperSkill(Player k) => k.stats.gkReflexes * 0.45 + k.stats.gkReach * 0.3 + k.stats.gkAwareness * 0.25;

  /// Chance the shot misses the target entirely (high and wide is riskier).
  static double missChance(Player taker, Zone z) =>
      ((z.row == 1 ? 0.16 : 0.05) + (z.col != 1 ? 0.03 : 0) - (takerSkill(taker) - 70) / 400).clamp(0.01, 0.3);

  /// Chance the keeper saves when he guessed the right zone (or column).
  static double saveChance(Player keeper, Player taker, Zone shot, Zone dive) {
    final k = (keeperSkill(keeper) - takerSkill(taker)) / 220;
    if (shot.col == dive.col && shot.row == dive.row) return (0.62 + k).clamp(0.35, 0.85);
    if (shot.col == dive.col) return (0.36 + k).clamp(0.15, 0.6);
    if (shot.col == 1 && dive.col != 1) return 0.0;
    return 0.02;
  }

  /// Where a taker aims: better takers go for the corners more.
  static Zone aim(Player taker, Random rnd) {
    final s = takerSkill(taker);
    final high = rnd.nextDouble() < 0.18 + (s - 70) / 200;
    final centre = rnd.nextDouble() < 0.16;
    return (col: centre ? 1 : (rnd.nextBool() ? 0 : 2), row: high ? 1 : 0);
  }

  /// Where a keeper dives.
  static Zone dive(Random rnd) => (col: rnd.nextDouble() < 0.12 ? 1 : (rnd.nextBool() ? 0 : 2), row: rnd.nextDouble() < 0.3 ? 1 : 0);

  /// 'goal', 'save' or 'miss'.
  static String kick(Player taker, Player keeper, Zone shot, Zone diveZone, Random rnd) {
    if (rnd.nextDouble() < missChance(taker, shot)) return 'miss';
    return rnd.nextDouble() < saveChance(keeper, taker, shot, diveZone) ? 'save' : 'goal';
  }

  /// The five (or more) takers: best penalty takers on the pitch first.
  static List<Player> takers(List<Player> onPitch) {
    final list = onPitch.where((p) => !p.mainPosition.isGoalkeeper).toList()
      ..sort((a, b) => takerSkill(b).compareTo(takerSkill(a)));
    final keeper = onPitch.where((p) => p.mainPosition.isGoalkeeper);
    return [...list, ...keeper];
  }

  /// Whether the shootout is decided after these kicks.
  static bool decided(List<bool> home, List<bool> away) {
    final h = home.where((x) => x).length, a = away.where((x) => x).length;
    if (home.length <= 5 && away.length <= 5) {
      final hLeft = 5 - home.length, aLeft = 5 - away.length;
      if (h + hLeft < a || a + aLeft < h) return true;
      return home.length == 5 && away.length == 5 && h != a;
    }
    return home.length == away.length && h != a;
  }

  /// A complete automatic shootout: (home, away) scores.
  static (int, int) simulate(List<Player> homeTakers, List<Player> awayTakers, Player homeKeeper, Player awayKeeper, Random rnd) {
    final home = <bool>[], away = <bool>[];
    var i = 0;
    while (!decided(home, away)) {
      final hTaker = homeTakers[i % homeTakers.length], aTaker = awayTakers[i % awayTakers.length];
      home.add(kick(hTaker, awayKeeper, aim(hTaker, rnd), dive(rnd), rnd) == 'goal');
      if (decided(home, away)) break;
      away.add(kick(aTaker, homeKeeper, aim(aTaker, rnd), dive(rnd), rnd) == 'goal');
      i++;
    }
    return (home.where((x) => x).length, away.where((x) => x).length);
  }
}
