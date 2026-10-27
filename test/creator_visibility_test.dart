import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/countries.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/screens/main_navigation_screen.dart';
import 'package:football_top_manager/screens/player_creator_screen.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/ui/flag.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  test('every selectable nationality has a bundled SVG flag', () async {
    for (final entry in countryFlags.entries) {
      final code = FlagView.code(entry.value, entry.key);
      expect(code, isNotNull, reason: entry.key);
      final data = await rootBundle.load('assets/flags/$code.svg');
      expect(data.lengthInBytes, greaterThan(0), reason: entry.key);
    }
  });
  testWidgets('player creator shows SVG flags in preview and nationality menu', (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    GameState().startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    await t.pumpWidget(const MaterialApp(home: PlayerCreatorScreen()));
    await t.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is FlagView && w.nationality == 'O‘zbekiston'), findsWidgets);
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pumpAndSettle();
    final england = find.byWidgetPredicate((w) => w is FlagView && w.nationality == 'Angliya');
    expect(england, findsWidgets);
    expect(FlagView.code('🏴', 'Angliya'), 'gb-eng');
    await t.tap(find.text('Angliya').last);
    await t.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is FlagView && w.nationality == 'Angliya'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('player created through the UI shows up in the squad', (t) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final game = GameState();
    game.startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    game.alerts.clear(); // the welcome banner would cover the app bar
    await t.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.groups_outlined).last);
    await t.pumpAndSettle();
    final before = game.userClub.squad.length;
    await t.tap(find.byTooltip('Futbolchi yaratish'));
    await t.pumpAndSettle();
    final add = find.textContaining('Jamoaga qo‘shish');
    await t.dragUntilVisible(add, find.byType(ListView).first, const Offset(0, -400));
    await t.tap(add);
    await t.pumpAndSettle();
    expect(game.userClub.squad.length, before + 1);
    expect(game.userClub.bench.any((p) => p.id.startsWith('own_')), isTrue);
    expect(game.userClub.benchIds.length, 9);
  });
}
