import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/l10n/l10n.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/screens/main_navigation_screen.dart';
import 'package:football_top_manager/screens/match_report_screen.dart';
import 'package:football_top_manager/screens/player_match_screen.dart';
import 'package:football_top_manager/screens/db_editor_screen.dart';
import 'package:football_top_manager/screens/tactics_screen.dart';
import 'package:football_top_manager/screens/widgets/player_detail_view.dart';
import 'package:football_top_manager/screens/club_life_screen.dart';
import 'package:football_top_manager/screens/shootout_screen.dart';
import 'package:football_top_manager/screens/compare_screen.dart';
import 'package:football_top_manager/screens/season_review_screen.dart';
import 'package:football_top_manager/services/cup.dart';
import 'package:football_top_manager/screens/standings_screen.dart';
import 'package:football_top_manager/ui/app_theme.dart';
import 'package:football_top_manager/ui/heatmap.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders key screens at desktop and phone sizes into artifacts/qa:
///   flutter test tool/desktop_capture_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({'ftm27_lang': 'uz'});
    await L10n.load();
    await InitialDatabase.load();
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/user/develop/flutter';
    for (final (family, file) in [
      ('MaterialIcons', 'materialicons-regular.otf'),
      ('Roboto', 'roboto-regular.ttf'),
    ]) {
      final f = File('$sdk/bin/cache/artifacts/material_fonts/$file');
      if (f.existsSync()) {
        await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
      }
    }
    Directory('artifacts/qa').createSync(recursive: true);
  });

  testWidgets('desktop capture', (tester) async {
    final game = GameState();
    game.startCareerWithExistingClub(InitialDatabase.getClubs('epl').firstWhere((c) => c.id == 'epl_mci'), league: 'epl');
    final fixture = game.currentRoundFixtures.firstWhere((f) => f.involves(game.userClub.id));
    game.simulateUserFixture(fixture);
    final key = GlobalKey();

    Future<void> mount(Widget child, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildAppTheme(), home: child),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> shot(String name) async {
      expect(tester.takeException(), isNull);
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = (await tester.runAsync(() => boundary.toImage()))!;
      final data = await tester.runAsync(() => img.toByteData(format: ui.ImageByteFormat.png));
      await tester.runAsync(() => File('artifacts/qa/$name.png').writeAsBytes(data!.buffer.asUint8List()));
      img.dispose();
    }

    const desktop = Size(1366, 820), phone = Size(390, 1400);
    final star = game.userClub.squad.first;
    star.careerSeasons.add('2025/26|epl_mci|Manchester City|34|21|5|7.41');
    star.transfers.add('2025/26|Borussia Dortmund|Manchester City|60000000||epl_mci');
    await mount(PlayerDetailView(player: star, club: game.userClub), phone);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('m-profile-career');
    await mount(CompareScreen(first: game.userClub.squad[3], second: game.userClub.squad[5]), phone);
    await shot('m-compare');
    await mount(const SeasonReviewScreen(), phone);
    await shot('m-review');
    final h = game.userClub, a = game.getClubById(fixture.homeClubId == h.id ? fixture.awayClubId : fixture.homeClubId)!;
    await mount(
      ShootoutScreen(
        home: h,
        away: a,
        userHome: true,
        homeTakers: PenaltyModel.takers(h.startingXI),
        awayTakers: PenaltyModel.takers(a.startingXI),
        homeKeeper: h.startingXI.first,
        awayKeeper: a.startingXI.first,
      ),
      phone,
    );
    await shot('m-shootout');
    await mount(const StandingsScreen(), desktop);
    await tester.tap(find.text('Kubok'));
    await tester.pumpAndSettle();
    await shot('d-cup');
    for (var t = 0; t < 8; t++) {
      await mount(ClubSection(key: ValueKey('life$t'), index: t), phone);
      await shot('m-club-$t');
    }
    await mount(const MainNavigationScreen(), desktop);
    await shot('d-dashboard');
    for (final tab in ['Jadval', 'Transfer', 'Moliya']) {
      await tester.tap(find.text(tab).first);
      await tester.pump(const Duration(milliseconds: 400));
      await shot('d-tab-$tab');
    }
    await mount(const TacticsScreen(), desktop);
    await shot('d-team');
    await mount(MatchReportScreen(fixture: fixture), desktop);
    await shot('d-report');

    final home = game.getClubById(fixture.homeClubId)!, away = game.getClubById(fixture.awayClubId)!;
    final data = PlayerMatchData(
      home: home,
      away: away,
      homeScore: fixture.homeScore ?? 0,
      awayScore: fixture.awayScore ?? 0,
      events: fixture.events,
      shots: fixture.shots,
      momentum: fixture.momentum,
      lines: fixture.playerStats,
      ratings: fixture.ratings,
      heatFor: (id) => decodeHeat(fixture.heat[id]),
    );
    for (final name in ['epl_mci_jdoku', 'epl_mci_jgvardiol', 'epl_mci_rdias', 'epl_mci_ehaaland']) {
      final p = game.userClub.playerById(name);
      if (p == null || fixture.playerStats[p.id] == null) continue;
      await mount(PlayerMatchScreen(key: ValueKey(name), data: data, player: p, club: game.userClub), desktop);
      await shot('d-player-$name');
      await mount(PlayerMatchScreen(key: ValueKey("m$name"), data: data, player: p, club: game.userClub), phone);
      await shot('m-player-$name');
    }
    await mount(const DbEditorScreen(), desktop);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Manchester City').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Jérémy Doku').first);
    await tester.pump(const Duration(milliseconds: 300));
    await shot('d-editor');
  });
}
