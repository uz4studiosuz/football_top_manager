import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/player.dart';
import 'package:football_top_manager/models/manager_profile.dart';
import 'package:football_top_manager/models/club.dart';
import 'package:football_top_manager/models/league.dart';
import 'package:football_top_manager/models/face.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/screens/tactics_screen.dart';
import 'package:football_top_manager/screens/custom_club_creator_screen.dart';
import 'package:football_top_manager/screens/main_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);
  final game = GameState();
  setUp(
    () => game.startCareerWithExistingClub(
      InitialDatabase.getSuperLeagueClubs().first,
      managerProfile: ManagerProfile(name: 'Test Manager'),
    ),
  );
  test('All players have the exact 26 attributes in the 40–100 range', () {
    for (final p in game.allClubs.expand((c) => c.squad)) {
      expect(p.stats.toMap().keys.toSet(), PlayerStats.labels.keys.toSet());
      expect(p.stats.toMap().length, 26);
      expect(p.stats.toMap().values.every((v) => v >= 40 && v <= 100), isTrue);
    }
    final clamped = PlayerStats.fromMap({'speed': 3, 'gkReach': 200});
    expect(clamped.speed, 40);
    expect(clamped.gkReach, 100);
  });
  test('GK OVR uses real goalkeeper attributes', () {
    final keeper = game.userClub.squad.firstWhere(
      (p) => p.mainPosition.isGoalkeeper,
    );
    final elite = keeper.copyWith(
      stats: keeper.stats.copyWith(
        gkAwareness: 100,
        gkCatching: 100,
        gkParrying: 100,
        gkReflexes: 100,
        gkReach: 100,
      ),
    );
    expect(elite.ovr, 100);
    expect(elite.ovr, greaterThan(keeper.ovr));
  });
  test(
    'New manager starts at 70 in all five styles and keeps custom portrait',
    () {
      final face = const FaceConfig(shape: 3, eyes: 2, nose: 3, glasses: true);
      final m = ManagerProfile(name: 'Aziz', face: face);
      expect(m.proficiency.length, ManagerPhilosophy.values.length);
      expect(m.proficiency.values.every((v) => v == 70), isTrue);
      expect(m.ratingFor(TeamPlaystyle.outWide), 70);
      expect(FaceConfig.fromMap(m.face.toMap()).toMap(), face.toMap());
      expect(m.copyWith(name: 'Azizbek').face.toMap(), face.toMap());
    },
  );
  test(
    'New custom careers generate different names with unique identities',
    () {
      final crest = game.userClub.crestConfig;
      void start() => game.startCareerWithCustomClub(
        name: 'New Club',
        shortName: 'NEW',
        stadiumName: 'Arena',
        stadiumCapacity: 30000,
        crestConfig: crest,
        managerProfile: ManagerProfile(name: 'New Manager'),
      );
      start();
      final first = game.userClub.squad.map((p) => p.name).toList();
      expect(first.toSet().length, 23);
      start();
      final second = game.userClub.squad.map((p) => p.name).toList();
      expect(second.toSet().length, 23);
      expect(first.join('|'), isNot(second.join('|')));
      expect(game.userClub.startingXI.length, 11);
    },
  );
  test('Swaps preserve lineup membership and individual instructions', () {
    final c = game.userClub,
        a = c.startingLineupIds[8],
        b = c.startingLineupIds[10];
    expect(game.swapPlayer(a, b), isTrue);
    expect(c.startingLineupIds[8], b);
    final reserve = c.benchIds.first;
    expect(game.swapPlayer(a, reserve), isTrue);
    expect(c.startingXI.length, 11);
    expect(c.startingLineupIds.toSet().length, 11);
    expect(
      c.benchIds.toSet().intersection(c.startingLineupIds.toSet()),
      isEmpty,
    );
    final p = c.startingXI.first;
    game.setPlayerInstruction(p, PlayerInstruction.stayBack);
    expect(Player.fromMap(p.toMap()).instruction, PlayerInstruction.stayBack);
  });
  test('Goals occur after the physical shot flight crosses the goal line', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final field = MatchField(clubs[0], clubs[1], seed: 0);
    var previousGoals = 0, observedGoals = 0;
    while (!field.isFinished) {
      if (field.isHalfTime) field.startSecondHalf();
      field.update(1 / 60);
      final total = field.homeStats.goals + field.awayStats.goals;
      if (total > previousGoals) {
        observedGoals++;
        expect(field.phase, FieldPhase.goal);
        expect(field.ball.dx == 0 || field.ball.dx == 1, isTrue);
        expect(field.ball.dy, inInclusiveRange(0.44, 0.56));
        expect(field.shots.last.goal, isTrue);
      }
      previousGoals = total;
    }
    expect(observedGoals, greaterThan(0));
    expect(
      field.events.where((e) => e.type == MatchEventType.goal).length,
      observedGoals,
    );
    expect(field.shots.where((s) => s.goal).length, observedGoals);
    expect(
      field.homeStats.completedPasses,
      lessThanOrEqualTo(field.homeStats.passes),
    );
    expect(
      field.awayStats.completedPasses,
      lessThanOrEqualTo(field.awayStats.passes),
    );
    expect(field.homeStats.onTarget, lessThanOrEqualTo(field.homeStats.shots));
    expect(field.awayStats.onTarget, lessThanOrEqualTo(field.awayStats.shots));
  });
  test(
    'Aware runners and pass choices do not loop through obvious offsides',
    () {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      var offsides = 0;
      for (var seed = 0; seed < 10; seed++) {
        final field = MatchField(clubs[0], clubs[7], seed: seed);
        field.simulateToEnd();
        expect(
          field.homeStats.shots + field.awayStats.shots,
          greaterThanOrEqualTo(6),
        );
        offsides += field.events.where((e) => e.type == MatchEventType.offside).length;
      }
      // Averaged over several matches so one wild game does not decide it.
      expect(offsides / 10, lessThanOrEqualTo(7));
    },
  );
  Future<void> size(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(() {
      t.view.resetPhysicalSize();
      t.view.resetDevicePixelRatio();
    });
  }

  testWidgets('Desktop drag swaps two starters and tap opens the action menu', (
    t,
  ) async {
    await size(t, const Size(1100, 1100));
    final c = game.userClub,
        a = c.startingLineupIds[8],
        b = c.startingLineupIds[10];
    await t.pumpWidget(const MaterialApp(home: TacticsScreen()));
    await t.pumpAndSettle();
    final start = t.getCenter(find.byKey(ValueKey('tactical_$a'))),
        end = t.getCenter(find.byKey(ValueKey('tactical_$b')));
    await t.dragFrom(start, end - start);
    await t.pumpAndSettle();
    expect(c.startingLineupIds[8], b);
    await t.tap(find.byKey(ValueKey('tactical_$a')));
    await t.pumpAndSettle();
    expect(find.text('Individual ko‘rsatma'), findsOneWidget);
    expect(find.text('To‘liq profil'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('Mobile long-press drag swaps starters', (t) async {
    await size(t, const Size(390, 844));
    final c = game.userClub,
        a = c.startingLineupIds[8],
        b = c.startingLineupIds[10];
    await t.pumpWidget(const MaterialApp(home: TacticsScreen()));
    await t.pumpAndSettle();
    final start = t.getCenter(find.byKey(ValueKey('tactical_$a'))),
        end = t.getCenter(find.byKey(ValueKey('tactical_$b')));
    final gesture = await t.startGesture(start);
    await t.pump(const Duration(milliseconds: 250));
    await gesture.moveTo(end);
    await t.pump(const Duration(milliseconds: 150));
    await gesture.up();
    await t.pumpAndSettle();
    expect(c.startingLineupIds[8], b);
    expect(t.takeException(), isNull);
  });
  testWidgets('Random crest chooses distinct palette colours', (t) async {
    await size(t, const Size(390, 844));
    await t.pumpWidget(const MaterialApp(home: CustomClubCreatorScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Tasodifiy logo yaratish'));
    await t.pumpAndSettle();
    final crest = t
        .widget<ClubCrestWidget>(find.byType(ClubCrestWidget).first)
        .config;
    expect(crest.primaryColor, isNot(crest.secondaryColor));
    expect(t.takeException(), isNull);
  });
  testWidgets('Narrow 320px web/mobile dashboard does not overflow', (t) async {
    await size(t, const Size(320, 740));
    await t.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
    await t.pumpAndSettle();
    expect(find.text('Sezon markazi'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'New career returns to onboarding without rebuilding an empty dashboard',
    (t) async {
      await size(t, const Size(390, 844));
      await t.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Menejer profili'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Yangi karyera'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Yangi karyera'));
      await t.pumpAndSettle();
      await t.tap(find.text('Yangi karyera'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Yangi karyera'));
      await t.pumpAndSettle();
      expect(find.text('Menejer Karyerasi'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
