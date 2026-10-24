import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
  });

  test('A bigger club keeps its key player even at the asking price', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').last, league: 'epl');
    final city = game.allClubs.firstWhere((c) => c.id == 'epl_mci');
    final star = city.startingXI.where((p) => game.sellerStance(p, city, game.userClub).notForSale).firstOrNull;
    expect(star, isNotNull, reason: 'City has untouchable starters');
    final ask = game.askingPrice(star!, city);
    expect(game.evaluateBid(star, city, ask).$1, NegotiationResult.rejected);
    expect(game.evaluateBid(star, city, (ask * 1.6).round()).$1, NegotiationResult.accepted);
  });

  test('Players weigh club size and playing time', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('l1').last, league: 'l1');
    final epl = InitialDatabase.getClubs('epl');
    final city = epl.firstWhere((c) => c.id == 'epl_mci');
    final star = city.startingXI.reduce((a, b) => a.ovr > b.ovr ? a : b);
    final mind = game.moveInterest(star, game.userClub, city);
    expect(mind.interest, lessThan(GameState.refuseInterest));
    expect(mind.reasons, isNotEmpty);
    // A reserve at a small club is keen on a step up.
    final small = game.userClub;
    final reserve = small.squad.where((p) => !small.startingLineupIds.contains(p.id)).first;
    expect(game.moveInterest(reserve, city, small).interest, greaterThan(game.moveInterest(star, small, city).interest));
  });

  test('AI clubs move few players and nobody moves twice a season', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    final before = game.transferHistory.length;
    for (var round = 1; round <= 6; round++) {
      game.simulateUserFixture(game.nextUserFixture!);
      final cup = game.pendingCupFixture;
      if (cup != null) game.simulateUserFixture(cup);
      game.nextRound();
    }
    final moves = game.transferHistory.skip(0).take(game.transferHistory.length - before).toList();
    expect(moves.length, lessThanOrEqualTo(8));
    final names = moves.map((m) => m.playerName).toList();
    expect(names.toSet().length, names.length);
  });

  test('Injured or suspended players leave the bench for the reserves', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final c = game.userClub;
    final hurt = c.bench.first;
    hurt.injuryRounds = 3;
    game.beginUserMatch();
    game.cancelMatchPlan();
    expect(c.benchIds.contains(hurt.id), isFalse);
    expect(c.reserves.contains(hurt), isTrue);
    expect(c.benchIds.length, lessThanOrEqualTo(9));
  });

  test('A match-day plan and man marks are undone after the match', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final c = game.userClub;
    final xi = List.of(c.startingLineupIds);
    final tactics = c.tactics;
    game.beginUserMatch();
    final starter = c.startingXI[3], sub = c.bench.firstWhere((p) => !p.mainPosition.isGoalkeeper);
    c.startingLineupIds[3] = sub.id;
    c.benchIds[c.benchIds.indexOf(sub.id)] = starter.id;
    game.setPlayerInstruction(c.startingXI[5], PlayerInstruction.tightMarking);
    game.setManMark(c.startingXI[4], game.upcomingRival!.startingXI[9]);
    game.simulateUserFixture(game.nextUserFixture!);
    expect(c.startingLineupIds, xi);
    expect(c.tactics, tactics);
    expect(game.manMarks, isEmpty);
  });
}
