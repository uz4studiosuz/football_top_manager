import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/club_life.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('Facilities, training, fans, awards and academy work over a season', () {
    final game = GameState();
    game.startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().firstWhere((c) => c.stadiumCapacity < 70000));
    final club = game.userClub;
    final budget = club.transferBudget;
    final capacity = club.stadiumCapacity;
    expect(game.upgradeFacility(Facility.stadium), isNull);
    expect(game.upgradeFacility(Facility.medical), isNull);
    expect(club.transferBudget, lessThan(budget));
    expect(game.upgradeFacility(Facility.medical), isNotNull, reason: 'already building');
    final trainee = club.squad.firstWhere((p) => !p.mainPosition.isGoalkeeper && p.age <= 23, orElse: () => club.squad[5]);
    final before = trainee.stats.finishing;
    game.setTrainingTarget(trainee, 'finishing');
    game.setTrainingFocus(TrainingFocus.attacking);

    for (var round = 1; round <= 14; round++) {
      final f = game.nextUserFixture!;
      game.simulateUserFixture(f);
      if (round < 14) game.nextRound();
    }
    expect(game.life.level(Facility.stadium), 1);
    expect(game.life.level(Facility.medical), 1);
    expect(club.stadiumCapacity, greaterThan(capacity));
    expect(trainee.stats.finishing, greaterThan(before));
    expect(game.life.feed, isNotEmpty);
    expect(game.life.awards, hasLength(1));
    expect(game.life.awards.first.teamOfSeason, hasLength(11));

    game.startNextSeason();
    expect(game.life.lastIntake.length, greaterThanOrEqualTo(2));
    expect(game.life.lastIntake.every((id) => club.playerById(id) != null), isTrue);

    // Survives a save/restore round trip.
    final save = game.toSave();
    final copy = GameState()..restore(save);
    expect(copy.life.level(Facility.stadium), 1);
    expect(copy.life.focus, TrainingFocus.attacking);
    expect(copy.life.awards, hasLength(1));
    expect(copy.userClub.stadiumCapacity, club.stadiumCapacity);
  });
}
