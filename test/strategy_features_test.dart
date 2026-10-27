import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/club.dart';
import 'package:football_top_manager/models/league.dart';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/services/automatic_tactics.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('automatic tactics require the minute, score and opposing style', () {
    final rule = {'enabled': true, 'minute': 60, 'score': 'losing', 'opponent': TeamPlaystyle.outWide.name, 'action': 'attack'};
    final tactics = TeamTactics();
    TeamTactics? evaluate(int minute, int forGoals, int againstGoals, TeamPlaystyle opponent) => automaticTactics(rule, minute: minute, goalsFor: forGoals, goalsAgainst: againstGoals, opponentStyle: opponent, current: tactics);
    expect(evaluate(59, 0, 1, TeamPlaystyle.outWide), isNull);
    expect(evaluate(60, 1, 1, TeamPlaystyle.outWide), isNull);
    expect(evaluate(60, 0, 1, TeamPlaystyle.values.firstWhere((x) => x != TeamPlaystyle.outWide)), isNull);
    final result = evaluate(60, 0, 1, TeamPlaystyle.outWide);
    expect(result, isNotNull);
    expect(result!.attackingIntensity, 5);
  });

  test('keeper action encoding stays fixed width and round trips', () {
    final actions = [for (final kind in ActionKind.values) PlayerAction(kind, const Offset(.2, .3), const Offset(.7, .8), true, 60)];
    final encoded = actions.map((a) => a.encode()).join();
    expect(encoded.length, actions.length * 12);
    expect(PlayerAction.decodeAll(encoded).map((a) => a.kind).toList(), ActionKind.values);
  });

  test('corner plans, match rules, player bonds and position training persist', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final player = game.userClub.startingXI.firstWhere((p) => !p.mainPosition.isGoalkeeper);
    final position = PlayerPosition.values.firstWhere((p) => !p.isGoalkeeper && p != player.mainPosition && !player.altPositions.contains(p));
    game.setCornerPlan(player, 'near', 'forward');
    game.setAutomaticRule({'enabled': true, 'minute': 30, 'score': 'any', 'opponent': 'any', 'action': 'press'});
    game.setTrainingTarget(player, 'position:${position.code}');
    game.life.progress[player.id] = 5.99;
    final fixture = game.nextUserFixture!;
    final regular = game.userClub.tactics;
    final field = game.simulateUserFixture(fixture);
    expect(field.automaticRuleApplied, isTrue);
    expect(game.userClub.tactics.pressing, regular.pressing);
    expect(game.life.relationships, isNotEmpty);
    game.nextRound();
    expect(player.altPositions, contains(position));
    final save = game.toSave();
    game.restore(save);
    expect(game.userClub.cornerPlans[player.id], ['near', 'forward']);
    expect(game.life.autoRule['action'], 'press');
    expect(game.life.relationships, isNotEmpty);
    expect(game.userClub.playerById(player.id)!.altPositions, contains(position));
  });
}
