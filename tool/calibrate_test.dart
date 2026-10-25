import 'dart:io';
import 'dart:math';
// Prints league-wide averages from many simulated matches so the engine can
// be tuned toward real football numbers. Run: flutter test tool/calibrate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('calibration report', () {
    const n = 160;
    var goals = 0, shots = 0, onTarget = 0, passes = 0, completed = 0;
    var corners = 0, fouls = 0, yellows = 0, reds = 0, offsides = 0;
    var homeWins = 0, draws = 0, saves = 0, pens = 0, injuries = 0, subs = 0, errShot = 0, errGoal = 0;
    final buckets = List<int>.filled(6, 0);
    var breaks = 0, inBox = 0, longShots = 0, longGoals = 0, recorded = 0;
    var xg = 0.0, ratingSum = 0.0, ratingN = 0, ratingMin = 10.0, ratingMax = 0.0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      // Premier League: 20 clubs of every level, like a real season.
      final clubs = InitialDatabase.getClubs(Platform.environment['LEAGUE'] ?? 'epl');
      final k = clubs.length;
      final h = clubs[i % k], a = clubs[(i * 7 + 3) % k == i % k ? (i + 1) % k : (i * 7 + 3) % k];
      // Real careers pick each club's best XI; the seed files only list squads.
      GameState().autoPickLineup(h);
      GameState().autoPickLineup(a);
      final f = MatchField(h, a, seed: i * 977);
      f.simulateToEnd();
      breaks += f.breakaways;
      for (final sh in f.shots) {
        final dx = ((sh.home ? 1.0 : 0.0) - sh.origin.dx) * 105, dy = (0.5 - sh.origin.dy) * 68;
        final m = sqrt(dx * dx + dy * dy);
        recorded++;
        buckets[min(5, m ~/ 6)]++;
        if (m < 18) inBox++;
        if (m >= 22) {
          longShots++;
          if (sh.goal) longGoals++;
        }
      }
      final hs = f.homeStats, as = f.awayStats;
      goals += hs.goals + as.goals;
      shots += hs.shots + as.shots;
      onTarget += hs.onTarget + as.onTarget;
      passes += hs.passes + as.passes;
      completed += hs.completedPasses + as.completedPasses;
      corners += hs.corners + as.corners;
      fouls += hs.fouls + as.fouls;
      yellows += hs.yellows + as.yellows;
      reds += hs.reds + as.reds;
      offsides += hs.offsides + as.offsides;
      saves += hs.saves + as.saves;
      subs += hs.subs + as.subs;
      xg += hs.xg + as.xg;
      injuries += f.injuries.length;
      pens += f.shots.where((s) => s.xg == 0.76).length;
      for (final l in f.lines.values) {
        errShot += l.errorsLeadingToShot;
        errGoal += l.errorsLeadingToGoal;
      }
      if (hs.goals > as.goals) homeWins++;
      if (hs.goals == as.goals) draws++;
      for (final r in f.allRatings().values) {
        ratingSum += r;
        ratingN++;
        if (r < ratingMin) ratingMin = r;
        if (r > ratingMax) ratingMax = r;
      }
    }
    String avg(num v) => (v / n).toStringAsFixed(2);
    // ignore: avoid_print
    print('''
matches $n  (${sw.elapsedMilliseconds ~/ n} ms/match)
breakaway shots ${avg(breaks)}   shots in box ${(inBox * 100 / max(1, recorded)).round()}%   from 22m+ ${avg(longShots)} (goals ${avg(longGoals)})
by 6m: ${buckets.map((b) => (b * 100 / max(1, recorded)).round()).join('/')}%
goals/match ${avg(goals)}  xG ${avg(xg)}  shots ${avg(shots)}  onTarget ${avg(onTarget)}
passes ${avg(passes)}  accuracy ${(completed * 100 / passes).toStringAsFixed(1)}%
corners ${avg(corners)}  fouls ${avg(fouls)}  yellows ${avg(yellows)}  reds ${avg(reds)}
offsides ${avg(offsides)}  saves ${avg(saves)}  penalties ${avg(pens)}  injuries ${avg(injuries)}  subs ${avg(subs)}
home win ${(homeWins * 100 / n).round()}%  draw ${(draws * 100 / n).round()}%
rating avg ${(ratingSum / ratingN).toStringAsFixed(2)}  min $ratingMin  max $ratingMax
errors → shot ${avg(errShot)}  → goal ${avg(errGoal)}
''');
  });
}
