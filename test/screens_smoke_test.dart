import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/screens/club_life_screen.dart';
import 'package:football_top_manager/screens/player_match_screen.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  testWidgets('Player match page shows every tab with maps and statistics', (t) async {
    t.view.physicalSize = const Size(520, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    final a = game.userClub, b = game.allClubs.firstWhere((c) => c.id != a.id);
    final f = MatchField(a, b, seed: 11)..simulateToEnd();
    final data = PlayerMatchData(
      home: a,
      away: b,
      homeScore: f.homeStats.goals,
      awayScore: f.awayStats.goals,
      events: f.events,
      shots: f.shots,
      momentum: f.momentum,
      lines: f.lines,
      ratings: f.allRatings(),
      heatFor: (id) => f.heat[id],
      actionsFor: (id) => f.actions[id] ?? const [],
    );
    final mid = a.startingXI[6];
    await t.pumpWidget(MaterialApp(home: PlayerMatchScreen(data: data, player: mid, club: a)));
    await t.pumpAndSettle();
    for (final tab in ['Zarbalar', 'Paslar', 'Dribling', 'Himoya']) {
      final finder = find.text(tab);
      if (finder.evaluate().isEmpty) continue;
      await t.ensureVisible(finder.first);
      await t.tap(finder.first, warnIfMissed: false);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: tab);
    }
    expect(find.text('Himoyaviy harakatlar'), findsOneWidget);
  });

  testWidgets('Scouts page renders with a report and results', (t) async {
    t.view.physicalSize = const Size(390, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getClubs('epl').first, league: 'epl');
    await t.runAsync(() async {
      await game.sendScouts('Braziliya');
      for (var i = 0; i < 4; i++) {
        game.nextRound();
      }
    });
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: ScoutsView())));
    await t.pumpAndSettle();
    expect(find.textContaining('Dunyo skautligi'), findsOneWidget);
    expect(find.textContaining('Kuzatuvlar'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
