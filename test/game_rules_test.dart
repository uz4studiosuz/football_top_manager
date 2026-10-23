import 'package:football_top_manager/services/match_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_clock.dart';
import 'package:football_top_manager/models/league.dart';
import 'package:football_top_manager/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  final game = GameState();
  setUp(
    () => game.startCareerWithExistingClub(
      InitialDatabase.getSuperLeagueClubs().first,
    ),
  );
  test('1x minute equals one real second, and paused time is ignored', () {
    final c = MatchClock();
    expect(c.advance(const Duration(milliseconds: 999)), isEmpty);
    expect(c.advance(const Duration(milliseconds: 1)), [1]);
    c.paused = true;
    expect(c.advance(const Duration(seconds: 5)), isEmpty);
    expect(c.minutes, 1);
    c.paused = false;
    c.speed = 5;
    expect(c.advance(const Duration(seconds: 1)), [2, 3, 4, 5, 6]);
  });
  test('Clock processes every minute and clamps full time', () {
    final c = MatchClock()..speed = 5;
    expect(
      c.advance(const Duration(seconds: 30)),
      List.generate(90, (i) => i + 1),
    );
    expect(c.minutes, 90);
    expect(c.advance(const Duration(seconds: 1)), isEmpty);
  });
  test('JSON produces independent valid careers and 56 unique fixtures', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    clubs.first.squad.first.morale = 1;
    expect(InitialDatabase.getSuperLeagueClubs().first.squad.first.morale, 85);
    expect(game.fixtures.length, 56);
    for (final c in game.allClubs) {
      expect(game.fixtures.where((f) => f.homeClubId == c.id).length, 7);
      expect(c.startingXI.length, 11);
      expect(c.startingLineupIds.toSet().length, 11);
    }
  });
  test(
    'Transfer conserves ownership, fills seller XI and accounts all costs',
    () {
      final seller = game.allClubs[1];
      final p = seller.startingXI.firstWhere(
        (p) => !p.mainPosition.isGoalkeeper,
      );
      final buyer = game.userClub;
      buyer.transferBudget = 1000000000;
      buyer.wageBudget = 100000000;
      final fee = game.transferFee(p), costs = game.signingCost(p);
      final before = buyer.transferBudget + seller.transferBudget;
      expect(game.buyPlayer(p, seller), isTrue);
      expect(seller.squad.contains(p), isFalse);
      expect(buyer.squad.where((q) => q.id == p.id).length, 1);
      expect(seller.startingXI.length, 11);
      expect(buyer.transferBudget + seller.transferBudget, before - costs);
      expect(game.transferHistory.single.fee, fee);
      expect(game.buyPlayer(p, seller), isFalse);
    },
  );
  test('Wage limit rejection has no financial or ownership side effects', () {
    final seller = game.allClubs[1];
    final p = seller.bench.first;
    final buyer = game.userClub;
    buyer.wageBudget = 0;
    final money = buyer.transferBudget;
    expect(game.buyPlayer(p, seller), isFalse);
    expect(buyer.transferBudget, money);
    expect(seller.squad.contains(p), isTrue);
    expect(game.transferHistory, isEmpty);
  });
  test(
    'Contract renewal updates actual squad object and respects max term',
    () {
      final p = game.userClub.squad.first;
      game.userClub.wageBudget = 100000000;
      expect(game.renewContract(p, 5, p.calculatedRenewalWageDemand), isTrue);
      expect(game.userClub.squad.first.contract.contractYears, 5);
      expect(game.renewContract(p, 6, p.calculatedRenewalWageDemand), isFalse);
    },
  );
  test('Result is idempotent; assists and economics are recorded once', () {
    final f = game.nextUserFixture!;
    final c = game.getClubById(f.homeClubId)!;
    final scorer = c.startingXI.last;
    final assist = c.startingXI[5];
    final events = [
      MatchEvent(
        minute: 32,
        type: MatchEventType.goal,
        description: 'Goal',
        clubId: c.id,
        playerName: scorer.name,
        isHomeTeam: true,
        assistPlayerId: assist.id,
      ),
    ];
    game.finishMatch(fixture: f, homeScore: 1, awayScore: 0, events: events);
    final cash = game.userClub.transferBudget;
    final ledgerCount = game.ledger.length;
    game.finishMatch(fixture: f, homeScore: 1, awayScore: 0, events: events);
    expect(scorer.seasonGoals, 1);
    expect(assist.seasonAssists, 1);
    expect(game.userClub.transferBudget, cash);
    expect(game.ledger.length, ledgerCount);
    expect(game.sortedStandings.every((s) => s.played == 1), isTrue);
    for (final fixture in game.currentRoundFixtures) {
      expect(fixture.homeShotsOnTarget, lessThanOrEqualTo(fixture.homeShots));
      expect(fixture.homePossession + fixture.awayPossession, 100);
    }
    game.nextRound();
    expect(game.currentRound, 2);
  });
  test('Next round cannot skip an unplayed round', () {
    game.nextRound();
    expect(game.currentRound, 1);
  });
  test('Fitness affects match strength without changing natural OVR', () {
    final p = game.userClub.squad.firstWhere(
      (p) => p.mainPosition.isGoalkeeper,
    );
    final natural = p.ovr;
    p.currentStamina = 20;
    expect(p.ovr, natural);
    expect(p.getMatchOVR(), lessThan(natural));
    expect(p.getEffectiveOVR(PlayerPosition.st), lessThan(natural));
  });
  test('Field keeps 22 players in bounds and moves continuously', () {
    final field = MatchField(game.allClubs[0], game.allClubs[1]);
    final start = field.homePositions[8];
    for (var i = 0; i < 600; i++) {
      final before = List.of(field.homePositions);
      final active =
          field.phase == FieldPhase.openPlay ||
          field.phase == FieldPhase.pass ||
          field.phase == FieldPhase.shot;
      field.update(1 / 30, {});
      for (var n = 0; n < 11; n++) {
        final point = field.homePositions[n];
        expect(point.dx, inInclusiveRange(0.025, 0.975));
        expect(point.dy, inInclusiveRange(0.045, 0.955));
        if (active &&
            (field.phase == FieldPhase.openPlay ||
                field.phase == FieldPhase.pass ||
                field.phase == FieldPhase.shot)) {
          expect((point - before[n]).distance, lessThan(0.005));
        }
      }
      expect(field.ball.dx, inInclusiveRange(0, 1));
      expect(field.ball.dy, inInclusiveRange(0, 1));
    }
    expect((field.homePositions[8] - start).distance, greaterThan(0.01));
  });
  test('Full season keeps ownership unique and all clubs play 14 matches', () {
    for (var round = 1; round <= 14; round++) {
      expect(game.currentRound, round);
      expect(
        game.isTransferWindowOpen,
        round <= 3 || (round >= 8 && round <= 9),
      );
      final fixture = game.nextUserFixture!;
      game.finishMatch(
        fixture: fixture,
        homeScore: 0,
        awayScore: 0,
        events: [],
      );
      if (round < 14) game.nextRound();
    }
    expect(game.nextUserFixture, isNull);
    expect(game.fixtures.every((f) => f.isPlayed), isTrue);
    expect(game.sortedStandings.every((s) => s.played == 14), isTrue);
    final ids = game.allClubs.expand((c) => c.squad.map((p) => p.id)).toList();
    expect(ids.length, 128);
    expect(ids.toSet().length, 128);
    expect(game.allClubs.every((c) => c.startingXI.length == 11), isTrue);
  });
}
