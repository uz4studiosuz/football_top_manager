import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/league.dart';
import 'package:football_top_manager/services/match_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('pass statistics come from played passes, not invented actions', () {
    for (var seed = 0; seed < 4; seed++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final field = MatchField(clubs[0], clubs[1], seed: seed)..simulateToEnd();
      for (final club in clubs.take(2)) {
        for (final player in club.startingXI) {
          final line = field.lines[player.id];
          if (line == null) continue;
          final recorded = (field.actions[player.id] ?? [])
              .where((a) => a.kind == ActionKind.pass || a.kind == ActionKind.cross)
              .length;
          // An offside or the final whistle can stop a pass before a flight
          // is recorded, but ordinary passes must have a visible action.
          expect(line.passes - recorded, lessThanOrEqualTo(line.offsides + 2));
          expect(line.passesCompleted, lessThanOrEqualTo(line.passes));
        }
      }
    }
  });

  test('a completed ground pass reaches its receiver', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final field = MatchField(clubs[0], clubs[1], seed: 41);
    var verified = 0;
    while (!field.isFinished) {
      if (field.isHalfTime) field.startSecondHalf();
      final before = field.homeStats.completedPasses + field.awayStats.completedPasses;
      final wasPass = field.phase == FieldPhase.pass;
      field.update(1 / 60);
      final after = field.homeStats.completedPasses + field.awayStats.completedPasses;
      if (wasPass && after > before && field.phase == FieldPhase.openPlay && !field.ballIsLoose) {
        final positions = field.homePossession ? field.homePositions : field.awayPositions;
        expect((positions[field.owner] - field.ball).distance, lessThanOrEqualTo(0.045));
        verified++;
      }
    }
    expect(verified, greaterThan(0));
  });
}
