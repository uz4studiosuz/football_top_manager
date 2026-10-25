import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
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
}
