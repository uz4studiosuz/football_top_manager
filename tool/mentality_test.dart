import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/match_field.dart';

/// Goals for/against per mentality shape (home side), same opponents:
///   flutter test tool/mentality_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('mentality trade-offs', () {
    final clubs = InitialDatabase.getClubs('super');
    for (final shape in [-2.0, -1.0, 0.0, 1.0, 2.0]) {
      var gf = 0, ga = 0, sf = 0, sa = 0, counters = 0;
      const n = 240;
      for (var i = 0; i < n; i++) {
        final home = clubs[i % clubs.length], away = clubs[(i + 3) % clubs.length];
        final f = MatchField(home, away, seed: 1000 + i)
          ..homeShape = shape
          ..homeAttack = 1 + shape * 0.1;
        f.simulateToEnd();
        counters += f.countersStarted;
        gf += f.homeStats.goals;
        ga += f.awayStats.goals;
        sf += f.homeStats.shots;
        sa += f.awayStats.shots;
      }
      // ignore: avoid_print
      print('shape ${shape.toStringAsFixed(0).padLeft(2)}: goals ${(gf / n).toStringAsFixed(2)} – ${(ga / n).toStringAsFixed(2)}'
          '   shots ${(sf / n).toStringAsFixed(1)} – ${(sa / n).toStringAsFixed(1)}   counters ${(counters / n).toStringAsFixed(1)}');
    }
  });
}
