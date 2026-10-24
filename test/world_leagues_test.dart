import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
  });

  test('Every world league loads on demand with valid squads', () async {
    final world = InitialDatabase.leagues.where((l) => l.lazy).toList();
    expect(world.length, greaterThan(100));
    for (final l in world) {
      await InitialDatabase.ensureLeague(l.id);
      final clubs = InitialDatabase.getClubs(l.id);
      expect(clubs.length, l.clubCount, reason: l.id);
      for (final c in clubs) {
        expect(c.squad.where((p) => p.mainPosition.code == 'GK').length, greaterThanOrEqualTo(2), reason: c.id);
        expect(c.squad.length, greaterThanOrEqualTo(16), reason: c.id);
      }
    }
  });

  test('A LaLiga career runs with its second division in the background', () async {
    await InitialDatabase.ensurePyramid('es1');
    final game = GameState();
    final madrid = InitialDatabase.getClubs('es1').firstWhere((c) => c.name == 'Real Madrid');
    game.startCareerWithExistingClub(madrid, league: 'es1');
    expect(game.leagueId, 'es1');
    expect(game.divisions.keys, contains('es2'));
    for (var round = 1; round <= 3; round++) {
      game.simulateUserFixture(game.nextUserFixture!);
      game.nextRound();
    }
    expect(game.userClub.name, 'Real Madrid');
  });
}
