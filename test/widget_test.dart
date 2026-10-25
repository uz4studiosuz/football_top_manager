import 'package:football_top_manager/data/initial_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football_top_manager/services/coin_wallet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await InitialDatabase.load();
    SharedPreferences.setMockInitialValues({'ftm27_lang': 'uz'});
  });
  testWidgets('App starts at Onboarding screen and allows selecting club', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const FootballTopManagerApp());
    await tester.pumpAndSettle();

    // First launch: the welcome coin bonus is shown once.
    expect(find.text('Xush kelibsiz!'), findsOneWidget);
    await tester.tap(find.text('Boshladik'));
    await tester.pumpAndSettle();

    // Check Onboarding Screen elements
    expect(find.text('Menejer Karyerasi'), findsOneWidget);
    expect(find.text('FOOTBALL TOP MANAGER 2027'), findsOneWidget);
    expect(find.text('YANGI KLUB YARATISH'), findsNothing);
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Davom etish'));
      await tester.pumpAndSettle();
    }
    expect(find.text('YANGI KLUB YARATISH'), findsOneWidget);
    expect(find.text('MAVJUD TOP KLUBNI TANLASH'), findsOneWidget);

    // Tap "MAVJUD TOP KLUBNI TANLASH"
    final selectClubBtn = find.text('MAVJUD TOP KLUBNI TANLASH');
    await tester.ensureVisible(selectClubBtn);
    await tester.tap(selectClubBtn);
    await tester.pumpAndSettle();

    // Clubs are listed strongest first: pick Real Madrid's tile.
    await tester.ensureVisible(find.text('RMA'));
    await tester.tap(find.text('RMA'));
    await tester.pumpAndSettle();
    expect(find.text('Real Madrid'), findsWidgets);

    // Select Real Madrid
    final startButton = find.text('REAL MADRIDNI BOSHQARISH');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Verify MainNavigationScreen / Dashboard loaded
    expect(find.text('NAVBATDAGI UCHRASHUV'), findsOneWidget);
    expect(find.text('Jamoa'), findsWidgets);
    expect(find.text('Jadval'), findsOneWidget);

    // Check opponent inspection button exists
    expect(find.byIcon(Icons.remove_red_eye_rounded), findsWidgets);

    // Tap Standings tab
    await tester.tap(find.text('Jadval'));
    await tester.pumpAndSettle();

    expect(find.text('Super League Markazi'), findsOneWidget);
    expect(find.text('Turnir jadvali'), findsOneWidget);

    // Player leaderboards live in the third tab.
    // A notification banner may cover the tab bar: switch tabs directly.
    DefaultTabController.of(tester.element(find.text('Turnir jadvali'))).animateTo(2);
    await tester.pumpAndSettle();

    expect(find.text('To\'purarlar'), findsOneWidget);
    expect(find.text('Assistentlar'), findsOneWidget);
  });

  testWidgets('Can navigate to Custom Club Creator from Onboarding screen', (
    WidgetTester tester,
  ) async {
    // The first test spent coins on Real Madrid; top up for the custom club.
    CoinWallet().reward(CoinWallet.customClubCost);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const FootballTopManagerApp());
    await tester.pumpAndSettle();

    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Davom etish'));
      await tester.pumpAndSettle();
    }
    // Tap "YANGI KLUB YARATISH" on onboarding
    final createClubBtn = find.text('YANGI KLUB YARATISH');
    await tester.ensureVisible(createClubBtn);
    await tester.tap(createClubBtn);
    await tester.pumpAndSettle();

    // Verify custom club creator screen elements
    expect(find.text('Yangi Jamoa Yaratish'), findsOneWidget);
    expect(find.text('1. Jamoa Ma\'lumotlari'), findsOneWidget);
    expect(find.text('2. Emblem Shakli'), findsOneWidget);
    expect(find.text('KLUBNI YARATISH VA BOSHLASH'), findsOneWidget);
  });
}
