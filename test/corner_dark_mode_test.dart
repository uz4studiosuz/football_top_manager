import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/league.dart';
import 'package:football_top_manager/screens/dashboard_screen.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/ui/match_widgets.dart';
import 'package:football_top_manager/ui/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  tearDown(() => AppAppearance.instance.value = false);

  test('Corners for both teams start at a pitch corner and are taken from there', () {
    final sides = <bool>{};
    var deliveries = 0;
    for (var seed = 0; seed < 20 && sides.length < 2; seed++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final field = MatchField(clubs[0], clubs[1], seed: seed);
      var corners = 0;
      bool? awaitingHome;
      for (var i = 0; i < 18000 && !field.isFinished; i++) {
        final previousBall = field.ball;
        field.update(1 / 60);
        if (field.isHalfTime) field.startSecondHalf();
        final count = field.homeStats.corners + field.awayStats.corners;
        if (count > corners) {
          corners = count;
          final event = field.events.lastWhere((e) => e.type == MatchEventType.corner);
          awaitingHome = event.isHomeTeam;
          sides.add(awaitingHome);
          expect(field.ball.dx, awaitingHome ? 1.0 : 0.0);
          expect(field.ball.dy == 0 || field.ball.dy == 1, isTrue);
          if ((previousBall.dy - 0.5).abs() > 0.03) {
            expect(field.ball.dy, previousBall.dy < 0.5 ? 0.0 : 1.0);
          }
        }
        if (awaitingHome != null && field.flightFrom != null) {
          final origin = field.flightFrom!;
          expect(origin.dx, awaitingHome ? 1.0 : 0.0);
          expect(origin.dy == 0 || origin.dy == 1, isTrue);
          deliveries++;
          awaitingHome = null;
        }
      }
    }
    expect(sides, {true, false});
    expect(deliveries, greaterThanOrEqualTo(2));
  });

  testWidgets('Injury warning and goal markers remain legible in both themes', (t) async {
    t.view.physicalSize = const Size(1100, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameState()..startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    game.userClub.startingXI.first.injuryRounds = 2;
    for (final dark in [false, true]) {
      AppAppearance.instance.value = dark;
      await t.pumpWidget(MaterialApp(theme: buildAppTheme(), home: DashboardScreen(onNavigateToTactics: () {})));
      await t.pumpAndSettle();
      final warning = find.textContaining('Asosiy tarkibda o‘ynay olmaydiganlar:');
      expect(warning, findsOneWidget);
      final card = t.widget<AppCard>(find.ancestor(of: warning, matching: find.byType(AppCard)).first);
      expect(card.color, AppColors.dangerSurface);
      expect(card.color.computeLuminance(), dark ? lessThan(0.1) : greaterThan(0.8));
      expect(t.takeException(), isNull);

      final club = game.userClub;
      final scorer = club.startingXI.last;
      await t.pumpWidget(MaterialApp(theme: buildAppTheme(), home: Scaffold(body: LineupPitch(
        club: club, players: club.startingXI, ratings: const {}, shirt: Colors.blue,
        goals: {scorer.id: 1},
      ))));
      await t.pumpAndSettle();
      final icon = t.widget<Icon>(find.byIcon(Icons.sports_soccer).last);
      final marker = t.widget<Container>(find.ancestor(of: find.byIcon(Icons.sports_soccer).last,
        matching: find.byWidgetPredicate((w) => w is Container && w.decoration is BoxDecoration)).first);
      final bg = (marker.decoration! as BoxDecoration).color!;
      expect((icon.color!.computeLuminance() - bg.computeLuminance()).abs(), greaterThan(0.6));
      expect(t.takeException(), isNull);
    }
  });
}
