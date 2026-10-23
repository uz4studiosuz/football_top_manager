import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/main.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/screens/main_navigation_screen.dart';
import 'package:football_top_manager/screens/match_screen.dart';
import 'package:football_top_manager/screens/widgets/player_detail_view.dart';
import 'package:football_top_manager/screens/onboarding_screen.dart';
import 'package:football_top_manager/screens/widgets/opponent_squad_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await InitialDatabase.load();
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/user/develop/flutter';
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    final font = File(
      '$sdk/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (font.existsSync()) {
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
  });
  testWidgets('mobile and desktop QA and complete match flow', (tester) async {
    final game = GameState();
    game.startCareerWithExistingClub(
      InitialDatabase.getSuperLeagueClubs().first,
    );
    final key = GlobalKey();
    await tester.pumpWidget(const FootballTopManagerApp());
    await tester.pump();
    final theme =
        (const FootballTopManagerApp().build(
                  tester.element(find.byType(FootballTopManagerApp)),
                )
                as MaterialApp)
            .theme;
    Future<void> mount(Widget child, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: child,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> shot(String name) async {
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      final data = await tester.runAsync(
        () => img.toByteData(format: ui.ImageByteFormat.png),
      );
      await tester.runAsync(() async {
        await File(
          'artifacts/qa/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
      });
      img.dispose();
    }

    await mount(const OnboardingScreen(), const Size(390, 844));
    await shot('onboarding-identity-mobile');
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    await shot('onboarding-face-mobile');
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    await shot('onboarding-philosophy-mobile');
    await tester.tap(find.text('Davom etish'));
    await tester.pumpAndSettle();
    await shot('onboarding-club-mobile');
    await mount(const MainNavigationScreen(), const Size(1200, 850));
    await shot('dashboard-desktop');
    await mount(const MainNavigationScreen(), const Size(390, 844));
    await shot('dashboard-mobile');
    await tester.tap(find.byIcon(Icons.people_outline).last);
    await tester.pumpAndSettle();
    await shot('squad-mobile');
    await tester.tap(find.byIcon(Icons.tune_outlined).last);
    await tester.pumpAndSettle();
    await shot('tactics-mobile');
    await tester.tap(find.text('Ko‘rsatmalar'));
    await tester.pumpAndSettle();
    await shot('instructions-mobile');
    await tester.tap(find.byIcon(Icons.swap_horiz).last);
    await tester.pumpAndSettle();
    await shot('transfers-mobile');
    await mount(
      PlayerDetailView(player: game.userClub.squad.first, club: game.userClub),
      const Size(390, 844),
    );
    await shot('player-mobile');
    await tester.tap(find.text('Atributlar'));
    await tester.pumpAndSettle();
    await shot('attributes-mobile');
    await tester.tap(find.text('Pozitsiyalar'));
    await tester.pumpAndSettle();
    await shot('positions-mobile');
    await mount(
      OpponentSquadSheet(opponentClub: game.allClubs[1]),
      const Size(390, 844),
    );
    await shot('scouting-mobile');

    await mount(
      MatchScreen(fixture: game.nextUserFixture!),
      const Size(390, 844),
    );
    await shot('match-mobile');
    await tester.tap(find.text('Statistika'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('match-stats-mobile');
    await tester.tap(find.text('Tezkor'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.nextUserFixture, isNull);
    expect(game.currentRoundFixtures.every((f) => f.isPlayed), isTrue);
    await shot('match-result-mobile');
    await mount(const MainNavigationScreen(), const Size(390, 844));
    await tester.tap(find.text('Keyingi turga o‘tish'));
    await tester.pumpAndSettle();
    expect(game.currentRound, 2);
    await tester.pumpWidget(const SizedBox());
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
