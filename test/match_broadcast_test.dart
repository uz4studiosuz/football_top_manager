import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/models/club.dart';
import 'package:football_top_manager/services/match_clock.dart';
import 'package:football_top_manager/services/match_field.dart';
import 'package:football_top_manager/ui/stadium_pitch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test(
    'Every formation kicks off in its own half with opponents outside the circle',
    () {
      for (final formation in FormationType.values) {
        final clubs = InitialDatabase.getSuperLeagueClubs();
        clubs[0].tactics = clubs[0].tactics.copyWith(formation: formation);
        clubs[1].tactics = clubs[1].tactics.copyWith(formation: formation);
        final f = MatchField(clubs[0], clubs[1], realTime: true);
        for (final homeBall in [true, false]) {
          if (!homeBall) f.restart(false);
          expect(
            f.homePositions.every((p) => p.dx <= .5),
            isTrue,
            reason: formation.name,
          );
          expect(
            f.awayPositions.every((p) => p.dx >= .5),
            isTrue,
            reason: formation.name,
          );
          final opponents = homeBall ? f.awayPositions : f.homePositions;
          for (final p in opponents) {
            final distance = sqrt(
              pow((p.dx - .5) * 105, 2) + pow((p.dy - .5) * 68, 2),
            );
            expect(distance, greaterThanOrEqualTo(9.15));
          }
        }
      }
    },
  );

  test('19 wall seconds advance 26 match seconds, matching the video', () {
    final clubs = InitialDatabase.getSuperLeagueClubs();
    final f = MatchField(clubs[0], clubs[1], realTime: true);
    for (var i = 0; i < 19 * 60; i++) {
      f.update(MatchClock.rates['1x']! / 60);
    }
    expect(f.time * 60, closeTo(26, .001));
    expect(f.digitalClock, '00:26');
    expect(f.homeStats.passes + f.awayStats.passes, greaterThan(0));
  });

  test(
    'Natural movement is continuous and completed passes reach the receiver',
    () {
      final clubs = InitialDatabase.getSuperLeagueClubs();
      final f = MatchField(clubs[0], clubs[1], seed: 81, realTime: true);
      var passes = 0, movement = 0.0;
      for (var frame = 0; frame < 120 * 30; frame++) {
        final before = [...f.renderHome, ...f.renderAway];
        final phase = f.phase;
        final count = f.homeStats.completedPasses + f.awayStats.completedPasses;
        f.update(1 / (60 * 30));
        if (phase == FieldPhase.openPlay &&
            (f.phase == FieldPhase.openPlay || f.phase == FieldPhase.pass)) {
          final after = [...f.renderHome, ...f.renderAway];
          for (var i = 0; i < before.length; i++) {
            final d = after[i] - before[i];
            final metres = sqrt(
              d.dx * d.dx * 105 * 105 + d.dy * d.dy * 68 * 68,
            );
            expect(
              metres * 30,
              lessThan(11),
              reason:
                  'Frame $frame, marker $i, $phase → ${f.phase}, time ${f.time}, ${before[i]} → ${after[i]}: a player cannot teleport.',
            );
            movement += metres;
          }
        }
        if (f.homeStats.completedPasses + f.awayStats.completedPasses > count &&
            f.phase == FieldPhase.openPlay &&
            !f.ballIsLoose) {
          final p = (f.homePossession
              ? f.homePositions
              : f.awayPositions)[f.owner];
          expect((p - f.ball).distance, lessThanOrEqualTo(.045));
          passes++;
        }
        expect(
          [...f.homeFacing, ...f.awayFacing].every((a) => a.isFinite),
          isTrue,
        );
      }
      expect(movement, greaterThan(100));
      expect(passes, greaterThan(4));
    },
  );

  test('Camera painting and hit testing use the same coordinates', () {
    for (final size in [const Size(390, 520), const Size(1000, 650)]) {
      for (final overview in [false, true]) {
        final camera = MatchCameraTransform(
          size,
          focusX: .8,
          overview: overview,
        );
        for (final p in [const Offset(.1, .3), const Offset(.8, .9)]) {
          expect(
            (camera.unproject(camera.project(p)) - p).distance,
            lessThan(1e-10),
          );
        }
      }
    }
  });

  test(
    'Fixed simulation ticks give the same result at different rendering rates',
    () {
      MatchField create() {
        final clubs = InitialDatabase.getSuperLeagueClubs();
        return MatchField(clubs[0], clubs[1], seed: 72, realTime: true);
      }

      final fine = create(), coarse = create();
      for (var i = 0; i < 600; i++) {
        fine.update(1 / 1200);
      }
      for (var i = 0; i < 30; i++) {
        coarse.update(1 / 60);
      }
      expect(fine.time, closeTo(coarse.time, 1e-10));
      expect(fine.homeStats.passes, coarse.homeStats.passes);
      expect(fine.awayStats.passes, coarse.awayStats.passes);
      expect((fine.ball - coarse.ball).distance, lessThan(1e-10));
      for (var i = 0; i < 11; i++) {
        expect(
          (fine.homePositions[i] - coarse.homePositions[i]).distance,
          lessThan(1e-10),
        );
        expect(
          (fine.awayPositions[i] - coarse.awayPositions[i]).distance,
          lessThan(1e-10),
        );
      }
    },
  );
}
