import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('natural match calibration', () {
    const n = 12;
    var goals = 0,
        shots = 0,
        passes = 0,
        completed = 0,
        fouls = 0,
        corners = 0,
        offsides = 0;
    var xg = 0.0;
    final situations = <String, int>{};
    final watch = Stopwatch()..start();
    for (var seed = 0; seed < n; seed++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final home = clubs[seed % clubs.length],
          away = clubs[(seed + 3) % clubs.length];
      GameState().autoPickLineup(home);
      GameState().autoPickLineup(away);
      final field = MatchField(home, away, seed: seed * 977, realTime: true)
        ..simulateToEnd();
      for (final shot in field.shots) {
        situations.update(
          '${shot.situation}/${shot.body}',
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
      for (final s in [field.homeStats, field.awayStats]) {
        goals += s.goals;
        shots += s.shots;
        passes += s.passes;
        completed += s.completedPasses;
        fouls += s.fouls;
        corners += s.corners;
        offsides += s.offsides;
        xg += s.xg;
      }
    }
    // ignore: avoid_print
    print(
      'natural matches $n (${watch.elapsedMilliseconds ~/ n}ms/match) goals ${goals / n} xG ${xg / n} shots ${shots / n} passes ${passes / n} accuracy ${100 * completed / max(1, passes)}% fouls ${fouls / n} corners ${corners / n} offsides ${offsides / n}',
    );
    // ignore: avoid_print
    print(situations.map((k, v) => MapEntry(k, v / n)));
    expect(goals / n, inInclusiveRange(.5, 6));
  });
}
