import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/cup.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('Shootout rules: best of five, then sudden death', () {
    expect(PenaltyModel.decided([true, true, true], [false, false, false]), isTrue);
    expect(PenaltyModel.decided([true, true, true], [false, false]), isFalse);
    expect(PenaltyModel.decided(List.filled(5, true), List.filled(5, true)), isFalse);
    expect(PenaltyModel.decided([...List.filled(5, true), true], [...List.filled(5, true), false]), isTrue);
    final clubs = InitialDatabase.getClubs('epl');
    final a = clubs[0], b = clubs[1];
    final (h, w) = PenaltyModel.simulate(
      PenaltyModel.takers(a.squad.take(11).toList()),
      PenaltyModel.takers(b.squad.take(11).toList()),
      a.squad.first,
      b.squad.first,
      Random(1),
    );
    expect(h == w, isFalse);
  });

  test('The cup is played through the season and has a winner', () {
    final game = GameState();
    game.startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    final cup = game.cup!;
    expect(cup.totalRounds, 5); // 20 clubs: 12 byes, then 16, 8, 4, 2
    expect(cup.rounds.first.where((t) => !t.isBye).length, 4);
    var cupMatches = 0;
    for (var round = 1; round <= game.totalRounds; round++) {
      game.simulateUserFixture(game.nextUserFixture!);
      final cupFixture = game.pendingCupFixture;
      if (cupFixture != null) {
        expect(game.isCupFixture(cupFixture), isTrue);
        game.simulateUserFixture(cupFixture);
        cupMatches++;
      }
      if (round < game.totalRounds) game.nextRound();
    }
    expect(cup.winner, isNotNull);
    expect(cup.rounds.length, cup.totalRounds);
    expect(cup.rounds.expand((r) => r).every((t) => t.played), isTrue);
    expect(game.cupFixtures.length, cupMatches);

    final copy = GameState()..restore(game.toSave());
    expect(copy.cup!.winner, cup.winner);
    expect(copy.cupFixtures.length, cupMatches);
  });
}
