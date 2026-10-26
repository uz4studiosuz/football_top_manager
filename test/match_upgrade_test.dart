import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/save_codec.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/screens/player_match_screen.dart';
import 'package:football_top_manager/screens/tactics_screen.dart';
import 'package:football_top_manager/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await InitialDatabase.load();
    for (final (family, file) in [('Roboto', 'roboto-regular.ttf'), ('MaterialIcons', 'materialicons-regular.otf')]) {
      final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/Users/user/develop/flutter';
      final bytes = File('$sdk/bin/cache/artifacts/material_fonts/$file').readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  tearDown(() => AppAppearance.instance.value = false);

  test('Condition is mostly average, affects match strength and survives saves', () {
    final random = Random(37), grades = <PlayerCondition, int>{};
    for (var i = 0; i < 10000; i++) {
      final c = PlayerCondition.draw(random);
      grades[c] = (grades[c] ?? 0) + 1;
    }
    expect(grades[PlayerCondition.c], inInclusiveRange(4700, 5300));
    expect(grades[PlayerCondition.a], lessThan(800));
    expect(grades[PlayerCondition.e], lessThan(700));
    final p = InitialDatabase.getSuperLeagueClubs().first.startingXI[9];
    final natural = p.ovr;
    p.condition = PlayerCondition.a;
    final strong = p.getMatchOVR();
    p.condition = PlayerCondition.e;
    expect(p.getMatchOVR(), lessThan(strong));
    expect(p.ovr, natural);
    expect(SaveCodec.playerFrom(SaveCodec.player(p)).condition, PlayerCondition.e);
    expect(p.copyWith().condition, PlayerCondition.e);
  });

  test('A rolling loose ball is collected only by a nearby player', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final f = MatchField(clubs[0], clubs[1], seed: 18);
    var looseFrames = 0, recoveries = 0;
    for (var i = 0; i < 15000 && !f.isFinished; i++) {
      final loose = f.ballIsLoose;
      f.update(1 / 60, {});
      if (f.ballIsLoose) looseFrames++;
      if (loose && !f.ballIsLoose && f.phase == FieldPhase.openPlay) {
        final point = (f.homePossession ? f.homePositions : f.awayPositions)[f.owner];
        expect((point - f.ball).distance, lessThan(0.04));
        recoveries++;
      }
      if (f.isHalfTime) f.startSecondHalf();
    }
    expect(looseFrames, greaterThan(30));
    expect(recoveries, greaterThan(0));
    expect(f.isFinished, isTrue);
  });

  testWidgets('Tactics defaults to rating and cycles to condition and OVR', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    GameState().startCareerWithExistingClub(InitialDatabase.getSuperLeagueClubs().first);
    await t.pumpWidget(MaterialApp(theme: buildAppTheme(), home: const TacticsScreen()));
    await t.pumpAndSettle();
    expect(find.text('Rating'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('lineup_display')));
    await t.pumpAndSettle();
    expect(find.text('Holat'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('lineup_display')));
    await t.pumpAndSettle();
    expect(find.text('OVR'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Keeper details, shot selection and persisted dark theme render on mobile', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final home = clubs[0], away = clubs[1];
    final f = MatchField(home, away, seed: 27)..simulateToEnd();
    final keeper = home.startingXI.first;
    final line = f.lines[keeper.id]!;
    final faced = f.shots.where((s) => !s.home && s.onTarget).toList();
    expect(faced.length, line.saves + line.goalsConceded);
    final data = PlayerMatchData(
      home: home,
      away: away,
      homeScore: f.homeStats.goals,
      awayScore: f.awayStats.goals,
      events: f.events,
      shots: f.shots,
      momentum: f.momentum,
      lines: f.lines,
      ratings: f.allRatings(),
      heatFor: (id) => f.heat[id],
      actionsFor: (id) => f.actions[id] ?? [],
    );
    final key = GlobalKey();
    await t.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: AppAppearance.instance,
        builder: (context, dark, _) => MaterialApp(
          theme: buildAppTheme(),
          home: RepaintBoundary(
            key: key,
            child: PlayerMatchScreen(data: data, player: keeper, club: home),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Jami saqlanganlar'), findsOneWidget);
    final lightSurface = AppColors.surface;
    await AppAppearance.instance.toggle();
    await t.pumpAndSettle();
    expect(AppColors.surface, isNot(lightSurface));
    expect(Theme.of(t.element(find.byType(Scaffold).first)).brightness, Brightness.dark);
    expect((await SharedPreferences.getInstance()).getBool('darkMode'), isTrue);
    if (faced.isNotEmpty) {
      final chip = find.widgetWithText(ChoiceChip, "${faced.first.minute}'").first;
      await t.ensureVisible(chip);
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(find.textContaining('xGOT '), findsWidgets);
    }
    expect(t.takeException(), isNull);
    await t.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('artifacts/qa').createSync(recursive: true);
      File('artifacts/qa/keeper-dark-1.3.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
