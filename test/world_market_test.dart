import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/club_life.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
  });

  test('Scouts open a country, its players can be bought and saves stay small', () async {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    final before = jsonEncode(game.toSave()).length;
    game.userClub.transferBudget = 900000000;
    // A top chief scout reports after one round, inside the summer window.
    game.life.staff[StaffRole.scouting] = 4;
    expect(game.worldScoutRounds, 1);
    expect(game.scoutDestinations, contains('Ispaniya'));
    expect(await game.sendScouts('Ispaniya'), isNull);
    expect(game.world.clubs, isEmpty, reason: 'hidden until the report');
    for (var i = 0; i < game.worldScoutRounds; i++) {
      game.simulateUserFixture(game.nextUserFixture!);
      final cup = game.pendingCupFixture;
      if (cup != null) game.simulateUserFixture(cup);
      game.nextRound();
    }
    expect(game.world.countries, contains('Ispaniya'));
    final spanish = game.marketClubs.where(game.isWorldClub).toList();
    expect(spanish.length, greaterThanOrEqualTo(40), reason: 'LaLiga and LaLiga2');
    expect(game.countryOfClub(spanish.first.id), 'Ispaniya');

    // A squad player of a Spanish club, bought outright.
    final seller = spanish.firstWhere((c) => c.name != 'Real Madrid' && c.name != 'Barcelona');
    final target = seller.bench.firstWhere((p) => !p.mainPosition.isGoalkeeper);
    expect(game.buyPlayer(target, seller), isTrue, reason: game.lastTransferError ?? '');
    expect(game.world.gone, contains(target.id));
    expect(game.userClub.squad.contains(target), isTrue);

    // The save holds only the world's summary, not 40 squads.
    final save = game.toSave();
    expect(jsonEncode(save).length, lessThan(before * 1.3));
    final restored = jsonDecode(jsonEncode(save)) as Map<String, dynamic>;
    final other = GameState();
    await other.prepareWorld(restored);
    expect(other.restore(restored), isTrue);
    expect(other.world.countries, contains('Ispaniya'));
    expect(other.marketClubs.where(other.isWorldClub).length, spanish.length);
    expect(other.world.club(seller.id)!.playerById(target.id), isNull, reason: 'bought players never come back');
  });

  test('Foreign moves weigh the move abroad; poor clubs cannot refuse', () async {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    await game.sendScouts('Braziliya');
    game.world.countries.add('Braziliya');
    game.world.missions.clear();
    final br = game.marketClubs.where(game.isWorldClub).first;
    final p = br.startingXI.last;
    expect(game.moveInterest(p, game.userClub, br).reasons, contains('Chet elga ko‘chishi kerak'));
    final stance = game.sellerStance(p, br, game.userClub);
    expect(stance.notForSale, isFalse);
  });

  test('A strong manager is offered jobs abroad and can move there', timeout: const Timeout(Duration(minutes: 4)), () async {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('l1').first, league: 'l1');
    game.managerProfile.reputation = 80;
    for (var round = 1; round <= game.totalRounds; round++) {
      game.simulateUserFixture(game.nextUserFixture!);
      final cup = game.pendingCupFixture;
      if (cup != null) game.simulateUserFixture(cup);
      if (round < game.totalRounds) game.nextRound();
    }
    expect(game.seasonFinished, isTrue);
    final offers = List.of(game.life.jobOffers);
    expect(offers, isNotEmpty);
    final abroad = offers.map(game.jobOfferInfo).firstWhere((o) => InitialDatabase.info(o!.$4).pyramid != 'eng', orElse: () => null);
    expect(abroad, isNotNull, reason: 'offers come from the whole world: $offers');
    final trophies = List.of(game.life.trophies);
    expect(await game.acceptJob(abroad!.$1), isNull);
    expect(game.userClubId, abroad.$1);
    expect(game.leagueId, abroad.$4);
    expect(game.calendar.year, GameState.firstSeason + 1);
    expect(game.life.trophies, trophies);
    game.simulateUserFixture(game.nextUserFixture!);
  });
}
