import 'dart:math';
import '../models/club.dart';
import '../models/league.dart';
import 'season_calendar.dart';

/// Double round robin (Berger): n-1 rounds, then mirrored with venues swapped.
/// The draw order is shuffled with [seed].
List<Fixture> roundRobin(List<String> clubIds, SeasonCalendar calendar, String prefix, int seed) {
  final fixtures = <Fixture>[];
  final n = clubIds.length;
  final ids = List<String>.of(clubIds)..shuffle(Random(seed));
  for (var r = 0; r < n - 1; r++) {
    for (var i = 0; i < n ~/ 2; i++) {
      final home = ids[i], away = ids[n - 1 - i];
      fixtures.add(
        Fixture(
          id: '${prefix}_${calendar.year}_r${r + 1}_$i',
          round: r + 1,
          homeClubId: r % 2 == 0 ? home : away,
          awayClubId: r % 2 == 0 ? away : home,
          date: calendar.dateOfRound(r + 1),
        ),
      );
    }
    ids.insert(1, ids.removeLast());
  }
  for (final f in List<Fixture>.of(fixtures)) {
    fixtures.add(
      Fixture(
        id: '${prefix}_${calendar.year}_r${f.round + n - 1}_${f.id}',
        round: f.round + n - 1,
        homeClubId: f.awayClubId,
        awayClubId: f.homeClubId,
        date: calendar.dateOfRound(f.round + n - 1),
      ),
    );
  }
  return fixtures;
}

/// Points, then goal difference, then goals scored.
List<LeagueStanding> sortStandings(Iterable<LeagueStanding> rows) => rows.toList()
  ..sort((a, b) {
    if (b.points != a.points) return b.points.compareTo(a.points);
    if (b.goalDifference != a.goalDifference) return b.goalDifference.compareTo(a.goalDifference);
    return b.goalsFor.compareTo(a.goalsFor);
  });

int _poisson(double lambda, Random rnd) {
  final limit = exp(-lambda);
  var k = 0;
  var p = 1.0;
  do {
    k++;
    p *= rnd.nextDouble();
  } while (p > limit);
  return k - 1;
}

/// Fast score model for background leagues: Poisson goals driven by the
/// difference in line-up strength, with home advantage unless [neutral].
(int, int) quickScore(Club home, Club away, Random rnd, {bool neutral = false}) {
  final d = (home.teamOVR - away.teamOVR).toDouble();
  final h = (neutral ? 1.32 : 1.5) * exp(d * 0.07);
  final a = (neutral ? 1.32 : 1.17) * exp(-d * 0.07);
  return (_poisson(h, rnd), _poisson(a, rnd));
}

/// Winner of a drawn knockout tie: slightly favours the stronger side.
Club shootout(Club a, Club b, Random rnd) =>
    rnd.nextDouble() < 0.5 + (a.teamOVR - b.teamOVR) * 0.01 ? a : b;

/// A league played in the background (results only) so the whole pyramid
/// moves together: tables, promotion, relegation and play-offs.
class Division {
  final String id;
  final List<Club> clubs;
  SeasonCalendar calendar;
  List<Fixture> fixtures = [];
  Map<String, LeagueStanding> table = {};
  Division(this.id, this.clubs, this.calendar);

  int get rounds => (clubs.length - 1) * 2;
  List<LeagueStanding> get sorted => sortStandings(table.values);
  int positionOf(String clubId) => sorted.indexWhere((s) => s.clubId == clubId) + 1;

  Club? club(String clubId) => clubs.where((c) => c.id == clubId).firstOrNull;

  void newSeason(int seed) {
    fixtures = roundRobin([for (final c in clubs) c.id], calendar, 'd$id', seed);
    table = {for (final c in clubs) c.id: LeagueStanding(clubId: c.id)};
  }

  /// Plays every fixture dated on or before [day].
  void playUntil(DateTime day, Random rnd) {
    for (final f in fixtures) {
      if (f.isPlayed || f.date!.isAfter(day)) continue;
      final home = club(f.homeClubId), away = club(f.awayClubId);
      if (home == null || away == null) continue;
      final (hs, aw) = quickScore(home, away, rnd);
      f
        ..homeScore = hs
        ..awayScore = aw
        ..isPlayed = true;
      table[home.id]?.recordMatch(myGoals: hs, opponentGoals: aw);
      table[away.id]?.recordMatch(myGoals: aw, opponentGoals: hs);
    }
  }

  int get playedRounds => fixtures.where((f) => f.isPlayed).length * 2 ~/ max(1, clubs.length);
}

/// Two-legged semi-finals (3rd v 6th, 4th v 5th) and a one-off final.
/// [seeds] are ordered by league position; [log] receives each result line.
Club playoff(List<Club> seeds, Random rnd, void Function(String line) log) {
  Club tie(Club high, Club low) {
    final (a1, b1) = quickScore(low, high, rnd);
    final (a2, b2) = quickScore(high, low, rnd);
    final highGoals = b1 + a2, lowGoals = a1 + b2;
    final winner = highGoals == lowGoals
        ? shootout(high, low, rnd)
        : (highGoals > lowGoals ? high : low);
    log('${high.shortName} – ${low.shortName}: $highGoals–$lowGoals'
        '${highGoals == lowGoals ? ' (pen. ${winner.shortName})' : ''}');
    return winner;
  }

  final first = tie(seeds[0], seeds[3]);
  final second = tie(seeds[1], seeds[2]);
  final (x, y) = quickScore(first, second, rnd, neutral: true);
  final winner = x == y ? shootout(first, second, rnd) : (x > y ? first : second);
  log('Final: ${first.shortName} $x–$y ${second.shortName}${x == y ? ' (pen. ${winner.shortName})' : ''}');
  return winner;
}
