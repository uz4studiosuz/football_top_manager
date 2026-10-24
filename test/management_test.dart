import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/save_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
  });

  test('Contract talks: low offers are refused, fair ones accepted or countered', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final p = game.userClub.squad.firstWhere((x) => x.age <= 29);
    final demand = game.renewalDemand(p);
    expect(game.proposeRenewal(p, 3, (demand * 0.5).round()).status, 'rejected');
    final mid = game.proposeRenewal(p, 3, (demand * 0.95).round());
    expect(mid.status, anyOf('counter', 'accepted'));
    final fair = game.proposeRenewal(p, 3, (demand * 1.4).round());
    expect(fair.status, 'accepted');
    expect(p.contract.weeklyWage, (demand * 1.4).round());
  });

  test('Loans, Super Cup and sponsors over two seasons', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    expect(game.life.sponsorOffers, hasLength(3));
    game.signSponsor(game.life.sponsorOffers.first);
    final youngster = game.userClub.squad.where((p) => p.age <= 22).reduce((a, b) => a.ovr < b.ovr ? a : b);
    expect(game.loanOut(youngster), isNull);
    expect(game.userClub.squad.contains(youngster), isFalse);
    final budget = game.userClub.transferBudget;
    for (var round = 1; round <= game.totalRounds; round++) {
      game.simulateUserFixture(game.nextUserFixture!);
      final cup = game.pendingCupFixture;
      if (cup != null) game.simulateUserFixture(cup);
      if (round < game.totalRounds) game.nextRound();
    }
    expect(game.userClub.transferBudget, isNot(budget), reason: 'sponsor money flows');
    game.startNextSeason();
    expect(game.userClub.squad.contains(youngster), isTrue, reason: 'loan returns');
    expect(game.life.loans, isEmpty);
    expect(game.superCup, isNotNull);
    expect(game.life.sponsorOffers, hasLength(3));
    final sc = game.superCup!;
    if (game.pendingSuperCup != null) {
      game.simulateUserFixture(sc);
    } else {
      game.simulateUserFixture(game.nextUserFixture!);
      game.nextRound();
    }
    expect(sc.isPlayed, isTrue);
  });

  test('Save slots keep separate careers and export/import round-trips', () async {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    await SaveService.setActiveSlot(0);
    await SaveService.save();
    final exported = SaveService.exportCareer();
    await SaveService.setActiveSlot(2);
    expect(await SaveService.meta(2), isNull);
    expect(await SaveService.importCareer(exported), isTrue);
    expect((await SaveService.meta(2))!['club'], game.userClub.name);
    expect((await SaveService.meta(0))!['club'], game.userClub.name);
    await SaveService.clearSlot(2);
    expect(await SaveService.meta(2), isNull);
  });
}
