import 'package:football_top_manager/services/match_field.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_clock.dart';
import 'package:football_top_manager/models/league.dart';
import 'dart:convert';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/models/face.dart';

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
    expect(p.getEffectiveOVR(PlayerPosition.cf), lessThan(natural));
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
          // Action time runs at MatchField.tempo (players also jog back
          // quickly after set pieces); still no teleports.
          expect((point - before[n]).distance, lessThan(0.03));
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
      // Summer window until 1 Sep (rounds 1–2), winter in January (9–10).
      expect(
        game.isTransferWindowOpen,
        round <= 2 || round == 9 || round == 10,
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
    expect(ids.length, 184);
    expect(ids.toSet().length, 184);
    expect(game.allClubs.every((c) => c.startingXI.length == 11), isTrue);
    expect(game.seasonFinished, isTrue);
    final champion = game.sortedStandings.first.clubId;
    game.startNextSeason();
    expect(game.currentRound, 1);
    expect(game.seasonLabel, '2027/28');
    expect(game.fixtures.length, 56);
    expect(game.fixtures.every((f) => !f.isPlayed), isTrue);
    expect(game.seasonHistory.single.championName, game.getClubById(champion)!.name);
    expect(game.allClubs.every((c) => c.startingXI.length == 11), isTrue);
  });

  test('Engine-recorded match stores ratings, momentum and player lines', () {
    final f = game.nextUserFixture!;
    final engine = game.simulateUserFixture(f);
    expect(f.isPlayed, isTrue);
    expect(f.homeScore, engine.homeStats.goals);
    expect(f.ratings.length, greaterThanOrEqualTo(22));
    expect(f.ratings.values.every((r) => r >= 3 && r <= 10), isTrue);
    expect(f.momentum.length, greaterThanOrEqualTo(90));
    expect(f.motmId, isNotNull);
    expect(f.homePossession + f.awayPossession, 100);
    final rated = game.allClubs
        .expand((c) => c.squad)
        .where((p) => p.seasonRated > 0)
        .length;
    expect(rated, greaterThanOrEqualTo(8 * 11));
    expect(game.ledger.any((e) => e.category.name == 'tickets'), isTrue);
  });

  test('Realistic averages over many simulated matches', () {
    var goals = 0, shots = 0, homeWins = 0;
    const n = 40;
    for (var i = 0; i < n; i++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final e = MatchField(clubs[i % 8], clubs[(i + 3) % 8], seed: i * 31);
      e.simulateToEnd();
      goals += e.homeStats.goals + e.awayStats.goals;
      shots += e.homeStats.shots + e.awayStats.shots;
      if (e.homeStats.goals > e.awayStats.goals) homeWins++;
      expect(e.homeStats.subs, lessThanOrEqualTo(5));
      expect(e.awayStats.subs, lessThanOrEqualTo(5));
    }
    expect(goals / n, inInclusiveRange(1.8, 3.8));
    expect(shots / n, inInclusiveRange(18, 36));
    expect(homeWins / n, greaterThan(0.25));
  });

  test('Career survives a JSON save/restore round trip', () {
    final f = game.nextUserFixture!;
    game.simulateUserFixture(f);
    game.nextRound();
    final before = game.sortedStandings.map((s) => '${s.clubId}:${s.points}:${s.goalDifference}').join('|');
    final scorer = game.topScorers.firstOrNull?.player;
    final json = jsonEncode(game.toSave());
    game.resetCareer();
    expect(game.isInitialized, isFalse);
    expect(game.restore(jsonDecode(json)), isTrue);
    expect(game.currentRound, 2);
    expect(game.sortedStandings.map((s) => '${s.clubId}:${s.points}:${s.goalDifference}').join('|'), before);
    final restored = game.fixtures.firstWhere((x) => x.id == f.id);
    expect(restored.isPlayed, isTrue);
    expect(restored.ratings.length, f.ratings.length);
    expect(restored.playerStats.length, f.playerStats.length);
    if (scorer != null) {
      expect(game.topScorers.first.player.seasonGoals, scorer.seasonGoals);
    }
    expect(game.allClubs.expand((c) => c.squad).length, 184);
    expect(game.freeAgents, isNotEmpty);
  });

  test('Free agents can be signed outside the transfer window', () {
    for (var r = 1; r <= 2; r++) {
      game.finishMatch(fixture: game.nextUserFixture!, homeScore: 0, awayScore: 0, events: []);
      game.nextRound();
    }
    expect(game.isTransferWindowOpen, isFalse);
    game.userClub.wageBudget = 100000000;
    final p = game.freeAgents.first;
    expect(game.signFreeAgent(p), isTrue);
    expect(game.userClub.squad.contains(p), isTrue);
  });

  test('Corners pack the box with attackers and markers', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final e = MatchField(clubs[0], clubs[3], seed: 4);
    var checked = 0;
    while (!e.isFinished && checked < 3) {
      if (e.isHalfTime) e.startSecondHalf();
      e.update(1 / 60);
      if (e.actionLabel == 'Burchak to‘pi') {
        // Let players walk into position, then inspect the shape.
        var home = List.of(e.homePositions), away = List.of(e.awayPositions);
        while (e.actionLabel == 'Burchak to‘pi') {
          home = List.of(e.homePositions);
          away = List.of(e.awayPositions);
          e.update(1 / 60);
        }
        final homeAttacks = e.ballOwnedByHome;
        final goalX = e.ball.dx > 0.5 ? 1.0 : 0.0;
        bool inBox(Offset p) => (p.dx - goalX).abs() < 0.16 && (p.dy - 0.5).abs() < 0.3;
        final att = (homeAttacks ? home : away).where(inBox).length;
        final def = (homeAttacks ? away : home).where(inBox).length;
        expect(att, greaterThanOrEqualTo(4));
        expect(def, greaterThanOrEqualTo(5));
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });

  test('Fouls and free kicks mirror each other', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final e = MatchField(clubs[2], clubs[5], seed: 9)..simulateToEnd();
    final h = e.homeStats, a = e.awayStats;
    final awayPens = e.events.where((x) => x.type == MatchEventType.penalty && !x.isHomeTeam).length;
    final homePens = e.events.where((x) => x.type == MatchEventType.penalty && x.isHomeTeam).length;
    expect(a.freeKicks, h.fouls + h.offsides - awayPens);
    expect(h.freeKicks, a.fouls + a.offsides - homePens);
  });

  test('A player built from scratch joins the club and survives saving', () {
    final stats = GameState.statsTemplate(PlayerPosition.cf, 80, 1);
    final before = game.userClub.squad.length;
    final p = game.addCreatedPlayer(
      name: 'Eldor Shomurodov',
      age: 29,
      nationality: 'O‘zbekiston',
      countryFlag: '🇺🇿',
      number: 14,
      position: PlayerPosition.cf,
      altPositions: [PlayerPosition.ss, PlayerPosition.cf],
      foot: PreferredFoot.right,
      weakFoot: 4,
      stats: stats,
      potential: 84,
      face: const FaceConfig(skin: 3, cut: 1, beardStyle: 2),
      style: PlayingStyle.targetMan,
    )!;
    expect(game.userClub.squad.length, before + 1);
    expect(p.shortName, 'E. Shomurodov');
    expect(p.altPositions, [PlayerPosition.ss]);
    expect(p.playingStyle, PlayingStyle.targetMan);
    expect(p.potential, greaterThanOrEqualTo(p.ovr));
    expect(game.userClub.squad.map((q) => q.number).toSet().length, game.userClub.squad.length);
    final json = jsonEncode(game.toSave());
    game.resetCareer();
    game.restore(jsonDecode(json));
    final back = game.userClub.playerById(p.id)!;
    expect(back.name, 'Eldor Shomurodov');
    expect(back.face.beardStyle, 2);
    expect(back.ovr, p.ovr);
  });

  test('Premier League career: 20 clubs, 38 rounds, real dates and zones', () {
    final city = InitialDatabase.getClubs('epl').firstWhere((c) => c.id == 'epl_mci');
    game.startCareerWithExistingClub(city);
    expect(game.leagueId, 'epl');
    expect(game.leagueName, 'Premier League');
    expect(game.allClubs.length, 20);
    expect(game.totalRounds, 38);
    expect(game.fixtures.length, 380);
    for (final c in game.allClubs) {
      expect(game.fixtures.where((f) => f.homeClubId == c.id).length, 19);
      expect(c.startingXI.length, 11);
      expect(c.startingXI.where((p) => p.mainPosition.isGoalkeeper).length, 1);
    }
    final dates = [for (var r = 1; r <= 38; r++) game.calendar.dateOfRound(r)];
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isAfter(dates[i - 1]), isTrue);
    }
    expect(dates.last.isBefore(DateTime(2027, 6, 1)), isTrue);
    expect(game.userClub.managerName, 'Pep Guardiola');
    expect(city.squad.any((p) => p.name == 'Abdukodir Khusanov'), isTrue);
    for (var r = 1; r <= 3; r++) {
      game.finishMatch(fixture: game.nextUserFixture!, homeScore: 1, awayScore: 0, events: []);
      game.nextRound();
    }
    expect(game.sortedStandings.every((s) => s.played == 3), isTrue);
    final json = jsonEncode(game.toSave());
    game.resetCareer();
    expect(game.restore(jsonDecode(json)), isTrue);
    expect(game.leagueId, 'epl');
    expect(game.totalRounds, 38);
    expect(game.currentRound, 4);
  });

  test('Injured and suspended starters are replaced automatically', () {
    final c = game.userClub;
    final p = c.startingXI[5];
    p.injuryRounds = 2;
    expect(game.unavailableStarters, contains(p));
    game.fixUnavailableStarters();
    expect(c.startingLineupIds.contains(p.id), isFalse);
    expect(c.startingXI.length, 11);
    expect(game.unavailableStarters, isEmpty);
  });

  test('Negotiation accepts, counters and rejects by asking price', () {
    final seller = game.allClubs[2];
    final p = seller.bench.firstWhere((p) => !p.mainPosition.isGoalkeeper);
    game.userClub.transferBudget = 1000000000;
    game.userClub.wageBudget = 100000000;
    final ask = game.askingPrice(p, seller);
    expect(game.bidForPlayer(p, seller, (ask * 0.5).round()).$1,
        NegotiationResult.rejected);
    expect(game.bidForPlayer(p, seller, (ask * 0.9).round()).$1,
        NegotiationResult.countered);
    expect(game.bidForPlayer(p, seller, ask).$1, NegotiationResult.accepted);
    expect(game.userClub.squad.contains(p), isTrue);
  });
}
