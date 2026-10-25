import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';

/// Playing-style mix per league:  flutter test tool/style_mix_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('style mix', () {
    for (final id in ['super', 'epl', 'ch', 'uzb']) {
      final counts = <String, int>{};
      for (final c in InitialDatabase.getClubs(id)) {
        for (final p in c.squad) {
          final k = p.playingStyle.name;
          counts[k] = (counts[k] ?? 0) + 1;
        }
      }
      final keys = counts.keys.toList()..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      // ignore: avoid_print
      print('$id: ${keys.map((k) => '$k ${counts[k]}').join(', ')}');
    }
  });
}
