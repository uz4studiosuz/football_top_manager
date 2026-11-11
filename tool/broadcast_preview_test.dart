import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/screens/match_screen.dart';
import 'package:football_top_manager/services/game_state.dart';
import 'package:football_top_manager/services/match_clock.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/ui/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await InitialDatabase.load();
    await (FontLoader('Roboto')
          ..addFont(rootBundle.load('assets/fonts/roboto-regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/roboto-bold.ttf')))
        .load();
  });
  testWidgets('capture actual broadcast physics at the reference video pace', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = GameState()
      ..startCareerWithExistingClub(
        InitialDatabase.getClubs('epl').first,
        league: 'epl',
      );
    final file = File('artifacts/qa/manager-preview-career.json');
    await tester.runAsync(() async {
      await file.writeAsString(jsonEncode(game.toSave()));
    });
    final fixture = game.nextUserFixture!;
    final h = game.getClubById(fixture.homeClubId)!,
        a = game.getClubById(fixture.awayClubId)!;
    final field = MatchField(h, a, seed: 91, realTime: true);
    while (field.time < 47.7 && !field.isFinished) {
      if (field.isHalfTime) field.startSecondHalf();
      field.update(1 / 30);
    }
    final key = GlobalKey(), repaint = ValueNotifier<int>(0);
    addTearDown(repaint.dispose);
    var focus = field.ball.dx;
    Widget kit(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: color,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          color: color.computeLuminance() > .5 ? Colors.black : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: repaint,
              builder: (context, _, child) => Column(
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: MatchPitchPainter(
                            field: field,
                            homeColor: h.primaryColor,
                            awayColor: a.primaryColor,
                            focusX: focus,
                            overview: false,
                          ),
                        ),
                        Positioned(
                          left: 16,
                          top: 12,
                          child: Container(
                            color: const Color(0xE6171D28),
                            child: Row(
                              children: [
                                kit(h.shortName.toUpperCase(), h.primaryColor),
                                kit(
                                  '${field.homeStats.goals}–${field.awayStats.goals}',
                                  const Color(0xFFF5F5F0),
                                ),
                                kit(a.shortName.toUpperCase(), a.primaryColor),
                                kit(
                                  field.digitalClock,
                                  const Color(0xFFF5F5F0),
                                ),
                                kit('1x', const Color(0xFF212A39)),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            color: h.primaryColor.withValues(alpha: .9),
                            child: Text(
                              field.actionLabel,
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 40,
                    color: const Color(0xFF141923),
                    child: Row(
                      children: [
                        for (final (i, p) in field.homeXI.indexed)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.white12),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${p.number} ${h.slotPosition(i).code}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LinearProgressIndicator(
                                    value: p.currentStamina / 100,
                                    minHeight: 3,
                                    color: AppColors.teal,
                                    backgroundColor: Colors.white12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final folder = Directory('artifacts/releases/broadcast-frames');
    await tester.runAsync(() => folder.create(recursive: true));
    const fps = 24, count = fps * 8;
    for (var frame = 0; frame < count; frame++) {
      field.update(MatchClock.rates['1x']! / fps);
      focus += (field.renderBall.dx - focus) * (1 - exp(-2.8 / fps));
      repaint.value++;
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final img = await boundary.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${folder.path}/${frame.toString().padLeft(4, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        if (frame == count ~/ 2) {
          await File(
            'artifacts/qa/broadcast-in-play-mobile.png',
          ).writeAsBytes(bytes.buffer.asUint8List());
        }
        img.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
