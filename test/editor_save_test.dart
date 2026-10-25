import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Editor saves only the changes, and they survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
    final file = InitialDatabase.leagues.firstWhere((l) => l.id == 'it1');
    expect(file.lazy, isTrue);
    final doc = await InitialDatabase.readFile('world/it1.json');
    final juve = (doc['clubs'] as List).cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Juventus');
    juve['name'] = 'Juventus Torino';
    final player = (doc['players'] as List).cast<Map<String, dynamic>>().first;
    (player['stats'] as Map)['finishing'] = 99;

    expect(await InitialDatabase.saveOverrides({'world/it1.json': doc}), isNull);
    final stored = (await SharedPreferences.getInstance()).getString(InitialDatabase.overridesKey)!;
    expect(stored.length, lessThan(20000), reason: 'a patch, not the whole league file');

    await InitialDatabase.reload();
    await InitialDatabase.ensureLeague('it1');
    final clubs = InitialDatabase.getClubs('it1');
    expect(clubs.map((c) => c.name), contains('Juventus Torino'));
    expect(clubs.length, 20);
    final again = await InitialDatabase.readFile('world/it1.json');
    final p = (again['players'] as List).cast<Map<String, dynamic>>().firstWhere((x) => x['id'] == player['id']);
    expect((p['stats'] as Map)['finishing'], 99);
    expect(jsonDecode(stored)['world/it1.json'], isNotNull);
    await InitialDatabase.clearOverrides();
  });

  test('Edits saved during a career change that career too', () async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
    await InitialDatabase.ensurePyramid('es1');
    final game = GameState();
    final club = InitialDatabase.getClubs('es1').firstWhere((c) => c.name == 'Real Madrid');
    game.startCareerWithExistingClub(club, league: 'es1');
    game.simulateUserFixture(game.nextUserFixture!);
    final doc = await InitialDatabase.readFile('world/es1.json');
    final barca = (doc['clubs'] as List).cast<Map<String, dynamic>>().firstWhere((c) => c['name'] == 'Barcelona');
    barca['name'] = 'FC Barcelona';
    (barca['crest'] as Map)['monogram'] = 'FCB';
    final mine = (doc['players'] as List).cast<Map<String, dynamic>>().firstWhere((p) => p['id'] == game.userClub.squad.first.id);
    (mine['stats'] as Map)['finishing'] = 99;
    final goalsBefore = game.userClub.squad.first.seasonGoals;

    expect(await InitialDatabase.saveOverrides({'world/es1.json': doc}), isNull);
    game.applyDatabaseEdits(InitialDatabase.lastChanges);
    final career = game.getClubById(barca['id'] as String)!;
    expect(career.name, 'FC Barcelona');
    expect(career.crestConfig.monogram, 'FCB');
    expect(game.userClub.squad.first.stats.finishing, 99);
    expect(game.userClub.squad.first.seasonGoals, goalsBefore, reason: 'season numbers stay');
    await InitialDatabase.clearOverrides();
  });
}
