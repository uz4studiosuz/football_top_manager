import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/club.dart';
import 'package:football_top_manager/models/manager_profile.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('chosen manager style starts as team tactics and earns match experience', () {
    final game = GameState();
    final manager = ManagerProfile(name: 'Manager', philosophy: ManagerPhilosophy.outWide);
    game.startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first, managerProfile: manager);
    expect(game.userClub.tactics.playstyle, TeamPlaystyle.outWide);
    final before = manager.experience[ManagerPhilosophy.outWide]!;
    game.simulateUserFixture(game.nextUserFixture!);
    expect(manager.experience[ManagerPhilosophy.outWide], greaterThan(before));
    expect(manager.experience[ManagerPhilosophy.possession], 0);
  });

  test('editor lineup and formation apply to an existing career and survive saves', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final c = game.userClub;
    final before = c.toMap();
    final after = jsonDecode(jsonEncode(before)) as Map<String, dynamic>;
    final xi = List<String>.from(after['startingLineupIds']);
    final bench = List<String>.from(after['benchIds']);
    final original = xi[1];
    xi[1] = bench[0];
    bench[0] = original;
    after['startingLineupIds'] = xi;
    after['benchIds'] = bench;
    after['lineupPinned'] = true;
    (after['tactics'] as Map)['formation'] = FormationType.f442.name;
    game.applyDatabaseEdits([('clubs', before, after)]);
    expect(c.startingLineupIds, xi);
    expect(c.benchIds, bench);
    expect(c.tactics.formation, FormationType.f442);
    final copy = Club.fromMap(jsonDecode(jsonEncode(c.toMap())) as Map<String, dynamic>);
    expect(copy.lineupPinned, isTrue);
    expect(copy.startingLineupIds, xi);
    expect(copy.tactics.formation, FormationType.f442);
  });

  test('created player can be removed without corrupting the starting lineup', () {
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    final template = game.userClub.squad.first;
    final created = game.addCreatedPlayer(
      name: 'Alren Valton', age: 21, nationality: template.nationality,
      countryFlag: template.countryFlag, number: 99, position: template.mainPosition,
      altPositions: [], foot: template.preferredFoot, weakFoot: template.weakFoot,
      stats: template.stats, potential: template.potential, face: template.face,
    )!;
    expect(game.deleteCreatedPlayer(template), isFalse);
    expect(game.deleteCreatedPlayer(created), isTrue);
    expect(game.userClub.playerById(created.id), isNull);
    expect(game.userClub.startingLineupIds.toSet(), hasLength(11));
  });
}
