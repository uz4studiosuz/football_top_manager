import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/services/db_editor.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await InitialDatabase.load();
  });

  test('Weak players are cheap and good form raises value', () {
    expect(Player.valuation(55, 26, 55), lessThanOrEqualTo(50000));
    expect(Player.valuation(85, 26, 85), greaterThan(Player.valuation(75, 26, 75) * 3));
    final p = InitialDatabase.getClubs('epl').first.squad.first;
    final before = p.fairValue;
    for (var i = 0; i < 10; i++) {
      p.recordRating(8.2);
    }
    expect(p.fairValue, greaterThan(before));
  });

  test('Editor moves a player between leagues and the game loads the edit', () async {
    final db = DbEditor();
    await db.load();
    final from = db.clubs('epl').first['id'] as String;
    final to = db.clubs('uzb').first['id'] as String;
    final starter = (db.club(from)['startingLineupIds'] as List).first as String;
    db.transfer(starter, from, to);
    expect((db.club(from)['squadIds'] as List), isNot(contains(starter)));
    expect((db.club(from)['startingLineupIds'] as List).length, 11);
    expect((db.club(to)['squadIds'] as List), contains(starter));
    await db.saveLocally();
    final moved = InitialDatabase.getClubs('uzb').first.squad.any((p) => p.id == starter);
    expect(moved, isTrue);
    await InitialDatabase.clearOverrides();
    expect(InitialDatabase.getClubs('uzb').first.squad.any((p) => p.id == starter), isFalse);
  });

  test('A great goalkeeper concedes clearly fewer goals than a weak one', () {
    int conceded(int gk) {
      var total = 0;
      for (var i = 0; i < 40; i++) {
        final clubs = InitialDatabase.getClubs('epl');
        final home = clubs[i % clubs.length], away = clubs[(i + 5) % clubs.length];
        final keeper = home.startingXI.first;
        keeper.stats = PlayerStats.fromMap({
          ...keeper.stats.toMap(),
          for (final k in ['gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach']) k: gk,
        });
        final f = MatchField(home, away, seed: 500 + i)..simulateToEnd();
        total += f.awayStats.goals;
      }
      return total;
    }

    expect(conceded(99), lessThan(conceded(50) * 0.7));
  });
}
