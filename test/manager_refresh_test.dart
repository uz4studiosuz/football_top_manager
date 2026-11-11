import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/club.dart';
import 'package:football_top_manager/services/club_life.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/services/touchline_orders.dart';
import 'package:football_top_manager/services/training_schedule.dart';
import 'package:football_top_manager/screens/main_navigation_screen.dart';
import 'package:football_top_manager/screens/training_screen.dart';
import 'package:football_top_manager/screens/tactics_screen.dart';
import 'package:football_top_manager/screens/squad_screen.dart';
import 'package:football_top_manager/screens/standings_screen.dart';
import 'package:football_top_manager/screens/match_screen.dart';
import 'package:football_top_manager/screens/widgets/player_detail_view.dart';
import 'package:football_top_manager/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await InitialDatabase.load();
    for (final weight in ['regular', 'medium', 'bold']) {
      await (FontLoader(
        'Roboto',
      )..addFont(rootBundle.load('assets/fonts/roboto-$weight.ttf'))).load();
    }
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/src/flutter';
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameState().startCareerWithExistingClub(
      InitialDatabase.getSuperLeagueClubs().first,
    );
  });

  test(
    'Orders resolve conflicts, preserve unrelated tactics, and serialize',
    () {
      final selected = <String>{};
      const base = TeamTactics(
        width: 4,
        formation: FormationType.f442,
        offsideTrap: true,
      );
      TouchlineOrders.toggle(selected, 'press');
      TouchlineOrders.toggle(selected, 'breather');
      expect(selected, {'breather'});
      TouchlineOrders.toggle(selected, 'fast');
      TouchlineOrders.toggle(selected, 'wings');
      TouchlineOrders.toggle(selected, 'centre');
      TouchlineOrders.toggle(selected, 'physical');
      final applied = TouchlineOrders.apply(base, selected);
      expect(selected, {'fast', 'centre', 'physical'});
      expect(applied.formation, FormationType.f442);
      expect(applied.offsideTrap, isTrue);
      expect(applied.tacklingIntensity, 5);
      expect(
        TeamTactics.fromMap(jsonDecode(jsonEncode(applied.toMap()))).toMap(),
        applied.toMap(),
      );
      selected.clear();
      expect(TouchlineOrders.apply(base, selected).toMap(), base.toMap());
      final legacy = base.toMap()
        ..remove('tacklingIntensity')
        ..remove('swapWings')
        ..remove('keeperUpForCorners');
      expect(TeamTactics.fromMap(legacy).tacklingIntensity, 3);
    },
  );

  test(
    'Match days override sessions; recovery and rest limit load and development',
    () {
      final plan = TrainingSchedule();
      final monday = DateTime(2026, 8, 17), match = DateTime(2026, 8, 22);
      plan.sessions = List.filled(21, TrainingSession.conditioning);
      plan.intensity = 3;
      expect(plan.session(match, 1, [match]), TrainingSession.rest);
      expect(
        plan.session(match.add(const Duration(days: 1)), 0, [match]),
        TrainingSession.recovery,
      );
      final heavy = plan.workload(monday, 7, [match]);
      expect(heavy.overloaded, isTrue);
      plan.sessions = List.filled(21, TrainingSession.rest);
      final rested = plan.workload(monday, 7, [match]);
      expect(rested.development, 0);
      expect(rested.fitnessCost, 0);
      expect(heavy.fitnessCost, greaterThan(rested.fitnessCost));
      plan.sessions = List.filled(21, TrainingSession.tactical);
      final before = plan.understanding(const TeamTactics());
      plan.complete(const TeamTactics(), plan.workload(monday, 7, [match]));
      expect(plan.understanding(const TeamTactics()), greaterThan(before));
      final life = ClubLife()..training.restore(plan.toMap());
      final copy = ClubLife()..restore(jsonDecode(jsonEncode(life.toMap())));
      expect(copy.training.toMap(), life.training.toMap());
      copy.restore({'fo': 'balanced'});
      expect(copy.training.sessions, hasLength(21));
    },
  );

  test('Weekly training progresses once and survives a career save', () {
    final game = GameState();
    final t = game.userClub.tactics;
    game.life.training.sessions = List.filled(21, TrainingSession.tactical);
    final before = game.life.training.understanding(t);
    game.simulateUserFixture(game.nextUserFixture!);
    game.nextRound();
    expect(game.life.training.understanding(t), greaterThan(before));
    final save = game.toSave();
    final expected = jsonEncode(game.life.training.toMap());
    game.restore(save);
    expect(jsonEncode(game.life.training.toMap()), expected);
  });

  test(
    'Attacking and defensive schedules develop different eligible skills',
    () {
      final plan = TrainingSchedule();
      final random = Random(81), date = DateTime(2026, 8, 17);
      final picks = <TrainingSession, int>{};
      for (final type in [
        TrainingSession.attacking,
        TrainingSession.defending,
      ]) {
        plan.sessions = List.filled(21, type);
        final work = plan.workload(date, 7, []);
        picks[type] = List.generate(
          500,
          (_) => work.chooseAttribute(['finishing', 'tackling'], random),
        ).where((key) => key == 'finishing').length;
      }
      expect(picks[TrainingSession.attacking], greaterThan(450));
      expect(picks[TrainingSession.defending], lessThan(50));
    },
  );

  test(
    'High intensity costs more stamina than taking a breather in played matches',
    () {
      var hard = 0, easy = 0;
      for (var seed = 0; seed < 4; seed++) {
        for (final intense in [false, true]) {
          final clubs = InitialDatabase.getSuperLeagueClubs();
          clubs[0].tactics = TouchlineOrders.apply(
            const TeamTactics(),
            intense ? {'press', 'fast'} : {'breather'},
          );
          final f = MatchField(clubs[0], clubs[1], seed: seed)..simulateToEnd();
          expect(f.isFinished, isTrue);
          final stamina = clubs[0].startingXI
              .skip(1)
              .fold<int>(0, (sum, p) => sum + p.currentStamina);
          if (intense) {
            hard += stamina;
          } else {
            easy += stamina;
          }
        }
      }
      expect(hard, lessThan(easy));
    },
  );

  test('An exposed goal cannot be saved by a keeper stranded upfield', () {
    var inspected = 0;
    for (var seed = 0; seed < 12; seed++) {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final field = MatchField(clubs[0], clubs[1], seed: seed)
        ..period = 2
        ..time = 85;
      while (!field.isFinished) {
        // Put both keepers in the centre circle before a shot is decided.
        field.homePositions[0] = const Offset(.5, .5);
        field.awayPositions[0] = const Offset(.5, .5);
        final before = field.shots.length;
        field.update(1 / 30);
        if (field.shots.length > before) {
          inspected++;
          expect(field.shots.last.outcome, isNot('save'));
        }
      }
    }
    expect(inspected, greaterThan(3));
  });

  test(
    'Swapping wings changes positions while preserving player identities',
    () {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      clubs[0].tactics = const TeamTactics(formation: FormationType.f433);
      final regular = MatchField(clubs[0], clubs[1], seed: 6);
      final ids = regular.homeXI.map((p) => p.id).toList();
      clubs[0].tactics = clubs[0].tactics.copyWith(swapWings: true);
      final swapped = MatchField(clubs[0], clubs[1], seed: 6);
      expect(swapped.homeXI.map((p) => p.id), ids);
      expect(
        swapped.homePositions[8].dy,
        closeTo(regular.homePositions[10].dy, .001),
      );
      expect(
        swapped.homePositions[10].dy,
        closeTo(regular.homePositions[8].dy, .001),
      );
      expect(swapped.homePositions[2], regular.homePositions[2]);
    },
  );

  testWidgets(
    'Manager screens adapt to phone, tablet, desktop and large text',
    (tester) async {
      addTearDown(tester.view.reset);
      AppAppearance.instance.value = true;
      final game = GameState();
      final key = GlobalKey();
      Future<void> mount(Widget screen, Size size, {double scale = 1}) async {
        await tester.pumpWidget(const SizedBox());
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: screen,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.takeException(),
          isNull,
          reason: '${screen.runtimeType} $size scale=$scale',
        );
      }

      Future<void> capture(String name) async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = (await tester.runAsync(() => boundary.toImage()))!;
        final bytes = await tester.runAsync(
          () => img.toByteData(format: ui.ImageByteFormat.png),
        );
        await tester.runAsync(() async {
          final file = File('artifacts/qa/manager-$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
        img.dispose();
      }

      for (final size in [const Size(390, 844), const Size(1440, 960)]) {
        final suffix = size.width < 500 ? 'mobile' : 'desktop';
        await mount(const MainNavigationScreen(), size);
        await capture('dashboard-$suffix');
        await mount(const TrainingScreen(), size);
        await capture('training-$suffix');
        await mount(
          PlayerDetailView(
            player: game.userClub.startingXI[6],
            club: game.userClub,
          ),
          size,
        );
        await tester.tap(find.text('Atributlar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('attributes-$suffix');
        await mount(const TacticsScreen(), size);
        await capture('tactics-$suffix');
        await mount(const SquadScreen(), size);
        await capture('squad-$suffix');
        await mount(const StandingsScreen(), size);
        await capture('table-$suffix');
        await mount(MatchScreen(fixture: game.nextUserFixture!), size);
        await capture('match-$suffix');
        await tester.tap(find.byKey(const ValueKey('touchline_orders')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await capture('orders-$suffix');
        await tester.tap(find.text('Nafas rostlash'));
        await tester.pump();
        expect(game.userClub.tactics.pressing, 1);
        await tester.tap(find.text('Individual ko‘rsatma').first);
        await tester.pump(const Duration(milliseconds: 350));
        expect(tester.takeException(), isNull);
      }
      for (final size in [
        const Size(320, 640),
        const Size(768, 1024),
        const Size(844, 390),
      ]) {
        await mount(const MainNavigationScreen(), size, scale: 1.2);
        await mount(const TrainingScreen(), size, scale: 1.2);
        await mount(const TacticsScreen(), size, scale: 1.2);
        await mount(
          MatchScreen(fixture: game.nextUserFixture!),
          size,
          scale: 1.2,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
