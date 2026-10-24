// Prints league-wide averages from many simulated matches so the engine can
// be tuned toward real football numbers. Run: flutter test tool/calibrate_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/match_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('calibration report', () {
    const n = 160;
    var goals = 0, shots = 0, onTarget = 0, passes = 0, completed = 0;
    var corners = 0, fouls = 0, yellows = 0, reds = 0, offsides = 0;
    var homeWins = 0, draws = 0, saves = 0, pens = 0, injuries = 0, subs = 0, errShot = 0, errGoal = 0;
    var xg = 0.0, ratingSum = 0.0, ratingN = 0, ratingMin = 10.0, ratingMax = 0.0;
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final h = clubs[i % 8], a = clubs[(i * 3 + 1) % 8 == i % 8 ? (i + 1) % 8 : (i * 3 + 1) % 8];
      final f = MatchField(h, a, seed: i * 977);
      f.simulateToEnd();
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
