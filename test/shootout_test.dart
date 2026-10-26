import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/screens/shootout_screen.dart';
import 'package:football_top_manager/services/cup.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  testWidgets('The shootout plays itself in 2D and returns a decisive score', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final clubs = InitialDatabase.getClubs('epl');
    GameState().autoPickLineup(clubs[0]);
    GameState().autoPickLineup(clubs[1]);
    (int, int)? result;
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.push<(int, int)>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShootoutScreen(
                      home: clubs[0],
                      away: clubs[1],
                      userHome: true,
                      homeTakers: PenaltyModel.takers(clubs[0].startingXI),
                      awayTakers: PenaltyModel.takers(clubs[1].startingXI),
                      homeKeeper: clubs[0].startingXI.first,
                      awayKeeper: clubs[1].startingXI.first,
                    ),
                  ),
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    // Skip to the result: the screen then offers to continue.
    await t.tap(find.byTooltip('Natijaga o‘tish'));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('Davom etish'), findsOneWidget);
    await t.tap(find.text('Davom etish'));
    await t.pumpAndSettle();
    expect(result, isNotNull);
    expect(result!.$1 != result!.$2, isTrue);
    expect(t.takeException(), isNull);
  });
}
