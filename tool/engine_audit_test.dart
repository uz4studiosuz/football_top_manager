import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/services/game_state.dart';

/// How the 2D match behaves (not just the final numbers):
///   flutter test tool/engine_audit_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('engine audit', () {
    const n = 40, dt = 1 / 30;
    var samples = 0, stoppage = 0, openPlay = 0;
    var clumps = 0.0, maxJump = 0.0, jumps = 0;
    var lengthIn = 0.0, widthIn = 0.0, lengthOut = 0.0, widthOut = 0.0, nIn = 0, nOut = 0;
    final thirds = [0, 0, 0];
    var possessionChanges = 0, nearBall = 0.0, entries = 0, boxEntries = 0;
    var shots = 0, goals = 0, corners = 0, fouls = 0, passes = 0, setPieces = 0, crosses = 0, headers = 0;
    for (var m = 0; m < n; m++) {
      final pool = InitialDatabase.getClubs('epl');
      final home = pool[m % pool.length], away = pool[(m * 7 + 3) % pool.length];
      GameState().autoPickLineup(home);
      GameState().autoPickLineup(away);
      final f = MatchField(home, away, seed: 4000 + m);
      var lastHome = List<Offset>.of(f.homePositions), lastAway = List<Offset>.of(f.awayPositions);
      var lastPossession = f.homePossession;
      var lastPhase = f.phase;
      var inThird = false, inBox = false;
      while (!f.isFinished) {
        if (f.isHalfTime) f.startSecondHalf();
        f.update(dt);
        samples++;
        if (f.phase == FieldPhase.stoppage) {
          stoppage++;
          if (lastPhase != FieldPhase.stoppage) setPieces++;
        }
        if (f.phase == FieldPhase.openPlay) openPlay++;
        lastPhase = f.phase;
        // Teleports: a player moving more than 2 m in one 1/30 minute step
        // outside restarts (normal running is ~0.2 m per step at 1x).
        for (final (now, before) in [(f.homePositions, lastHome), (f.awayPositions, lastAway)]) {
          for (var i = 0; i < 11; i++) {
            final dx = (now[i].dx - before[i].dx) * 105, dy = (now[i].dy - before[i].dy) * 68;
            final d = sqrt(dx * dx + dy * dy);
            if (f.phase == FieldPhase.openPlay) {
              maxJump = max(maxJump, d);
              if (d > 2.5) jumps++;
            }
          }
        }
        lastHome = List.of(f.homePositions);
        lastAway = List.of(f.awayPositions);
        if (f.homePossession != lastPossession && f.phase == FieldPhase.openPlay) possessionChanges++;
        final depth = f.homePossession ? f.ball.dx : 1 - f.ball.dx;
        final third = f.ballCarrier != null && depth > 0.66;
        final box = f.ballCarrier != null && depth > 0.84 && (f.ball.dy - 0.5).abs() < 0.3;
        if (f.homePossession != lastPossession) {
          inThird = false;
          inBox = false;
        }
        if (third && !inThird) entries++;
        if (box && !inBox) boxEntries++;
        inThird = inThird || third;
        inBox = inBox || box;
        lastPossession = f.homePossession;
        if (samples % 10 == 0 && f.phase == FieldPhase.openPlay) {
          final all = [...f.homePositions, ...f.awayPositions];
          var c = 0;
          for (var i = 0; i < all.length; i++) {
            for (var j = i + 1; j < all.length; j++) {
              final dx = (all[i].dx - all[j].dx) * 105, dy = (all[i].dy - all[j].dy) * 68;
              if (dx * dx + dy * dy < 4) c++; // closer than 2 m
            }
          }
          clumps += c;
          // Team shape: outfield length (x) and width (y) in metres.
          for (final (pts, home) in [(f.homePositions, true), (f.awayPositions, false)]) {
            final xs = [for (var i = 1; i < 11; i++) pts[i].dx * 105]..sort();
            final ys = [for (var i = 1; i < 11; i++) pts[i].dy * 68]..sort();
            final len = xs.last - xs.first, wid = ys.last - ys.first;
            if (home == f.homePossession) {
              lengthIn += len;
              widthIn += wid;
              nIn++;
            } else {
              lengthOut += len;
              widthOut += wid;
              nOut++;
            }
          }
          thirds[(f.ball.dx * 3).floor().clamp(0, 2)]++;
          // Players within 10 m of the ball.
          nearBall += all.where((p) {
            final dx = (p.dx - f.ball.dx) * 105, dy = (p.dy - f.ball.dy) * 68;
            return dx * dx + dy * dy < 100;
          }).length;
        }
      }
      shots += f.homeStats.shots + f.awayStats.shots;
      goals += f.homeStats.goals + f.awayStats.goals;
      corners += f.homeStats.corners + f.awayStats.corners;
      fouls += f.homeStats.fouls + f.awayStats.fouls;
      passes += f.homeStats.passes + f.awayStats.passes;
      crosses += f.homeStats.crosses + f.awayStats.crosses;
      headers += f.shots.where((sh) => sh.body == 'head').length;
    }
    final openSamples = samples ~/ 10;
    String pct(int a, int b) => '${(a * 100 / max(1, b)).round()}%';
    // ignore: avoid_print
    print('''
matches $n
time: open play ${pct(openPlay, samples)}, stoppages ${pct(stoppage, samples)}, set pieces/restarts per match ${(setPieces / n).toStringAsFixed(1)}
teleports (>2.5 m in one step, open play) per match ${(jumps / n).toStringAsFixed(1)}, biggest ${maxJump.toStringAsFixed(1)} m
pairs closer than 2 m (open play, avg) ${(clumps / max(1, openSamples)).toStringAsFixed(2)}
team length/width in possession ${(lengthIn / nIn).toStringAsFixed(1)} / ${(widthIn / nIn).toStringAsFixed(1)} m, without ${(lengthOut / nOut).toStringAsFixed(1)} / ${(widthOut / nOut).toStringAsFixed(1)} m
ball in thirds (home def/mid/att) ${thirds.map((t) => pct(t, thirds.reduce((a, b) => a + b))).join(' / ')}
players within 10 m of the ball (avg) ${(nearBall / max(1, openSamples)).toStringAsFixed(1)}
possession changes in open play per match ${(possessionChanges / n).toStringAsFixed(0)}
final-third entries with the ball per match ${(entries / n).toStringAsFixed(1)}, box entries ${(boxEntries / n).toStringAsFixed(1)}
per match: shots ${(shots / n).toStringAsFixed(1)}, goals ${(goals / n).toStringAsFixed(2)}, corners ${(corners / n).toStringAsFixed(1)}, fouls ${(fouls / n).toStringAsFixed(1)}, passes ${(passes / n).toStringAsFixed(0)}, crosses ${(crosses / n).toStringAsFixed(1)}, headed shots ${(headers / n).toStringAsFixed(1)}
''');
  });
}
