import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:football_top_manager/data/initial_database.dart';
import 'package:football_top_manager/services/game_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(InitialDatabase.load);

  test('English pyramid: Championship season, play-offs, promotion and saving', () {
    final game = GameState();
    final leicester = InitialDatabase.getClubs('ch').firstWhere((c) => c.id == 'ch_lei');
    game.startCareerWithExistingClub(leicester);
    expect(game.leagueId, 'ch');
    expect(game.allClubs.length, 24);
    expect(game.totalRounds, 46);
    expect(game.fixtures.length, 552);
    expect(game.divisions.keys.toSet(), {'epl', 'l1'});
    expect(game.userClub.managerName, isNotEmpty);
    // ignore: avoid_print
    print([
      for (final c in (List.of(game.allClubs)..sort((a, b) => b.teamOVR.compareTo(a.teamOVR))))
        '${c.shortName} ${c.teamOVR}/${c.squadDepthRating}',
    ].join(', '));
    expect(game.objective.title, isNotEmpty);
    final dates = [for (var r = 1; r <= 46; r++) game.calendar.dateOfRound(r)];
    for (var i = 1; i < dates.length; i++) {
      expect(dates[i].isAfter(dates[i - 1]), isTrue);
    }
    expect(dates.last.isBefore(DateTime(2027, 6, 1)), isTrue);

    for (var r = 1; r <= 46; r++) {
      final f = game.nextUserFixture!;
      final home = f.homeClubId == game.userClubId;
      game.finishMatch(fixture: f, homeScore: home ? 3 : 0, awayScore: home ? 0 : 3, events: []);
      if (r == 12) {
        // Background leagues advance with the calendar and survive saving.
        game.nextRound();
        final epl = game.divisions['epl']!;
        expect(epl.table.values.every((s) => s.played >= 9 && s.played <= 13), isTrue);
        final save = jsonEncode(game.toSave());
        // ignore: avoid_print
        print('save size ${(save.length / 1024).round()} KB: ${{
          for (final e in game.toSave().entries) e.key: (jsonEncode(e.value).length / 1024).round(),
        }}');
        game.resetCareer();
        expect(game.restore(jsonDecode(save)), isTrue);
        expect(game.divisions['epl']!.table.values.map((s) => s.points).toList(),
            epl.table.values.map((s) => s.points).toList());
        expect(game.divisions['l1']!.fixtures.where((f) => f.isPlayed).length,
            greaterThan(0));
        continue;
      }
      if (r < 46) game.nextRound();
    }
    expect(game.seasonFinished, isTrue);
    expect(game.news.any((n) => n.title.contains('oyi futbolchisi')), isTrue);
    expect(game.news.any((n) => n.title.contains('pley-off')), isTrue);
    // A whole 46-round season must still fit browser storage (~5M chars).
    final full = jsonEncode(game.toSave()).length;
    // ignore: avoid_print
    print('season-end save ${(full / 1024).round()} KB');
    expect(full, lessThan(3000000));
    expect(game.positionOf('ch_lei'), 1);
    expect(game.divisions.values.every((d) => d.fixtures.every((f) => f.isPlayed)), isTrue);
    // 3 down + 3 up between each pair of tiers.
    expect(game.pendingMoves.length, 12);
    expect(game.pendingMoves['ch_lei'], 'epl');
    expect(game.pendingMoves.values.where((v) => v == 'epl').length, 3);
    expect(game.pendingMoves.values.where((v) => v == 'l1').length, 3);

    final relegated = game.pendingMoves.entries.where((e) => e.value == 'ch').map((e) => e.key).toSet();
    game.startNextSeason();
    expect(game.leagueId, 'epl');
    expect(game.allClubs.length, 20);
    expect(game.totalRounds, 38);
    expect(game.fixtures.length, 380);
    expect(game.divisions['ch']!.clubs.length, 24);
    expect(game.divisions['l1']!.clubs.length, 24);
    expect(game.divisions['ch']!.clubs.map((c) => c.id).toSet().containsAll(relegated), isTrue);
    final ids = game.marketClubs.map((c) => c.id).toList();
    expect(ids.length, 68);
    expect(ids.toSet().length, 68);
    final players = game.marketClubs.expand((c) => c.squad.map((p) => p.id)).toList();
    expect(players.toSet().length, players.length);
    expect(game.divisions.values.every((d) => d.fixtures.length == d.clubs.length * (d.clubs.length - 1)), isTrue);
    expect(game.news.any((n) => n.title.startsWith('KO‘TARILDINGIZ')), isTrue);
    expect(game.seasonHistory.isNotEmpty, isTrue);
  });
}
