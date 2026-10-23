import 'dart:math';
import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';
import '../models/manager_profile.dart';
import '../models/finance.dart';
import '../models/face.dart';
import 'match_field.dart';
import 'save_codec.dart';
import 'season_calendar.dart';

/// Yetakchi futbolchilar reytingi modeli
class PlayerLeaderboardEntry {
  final Player player;
  final Club club;
  const PlayerLeaderboardEntry({required this.player, required this.club});
}

class BoardObjective {
  final String title;
  final int targetPosition;
  const BoardObjective(this.title, this.targetPosition);
}

class TransferOffer {
  final Player player;
  final Club buyer;
  final int fee;
  const TransferOffer(this.player, this.buyer, this.fee);
}

enum NegotiationResult { accepted, countered, rejected, blocked }

class SeasonSummary {
  final String season;
  final String championName;
  final int userPosition;
  final int userPoints;
  final String topScorer;
  const SeasonSummary(
    this.season,
    this.championName,
    this.userPosition,
    this.userPoints,
    this.topScorer,
  );
}

/// Barcha o'yin ma'lumotlari, liga taqvimi, byudjet va natijalarni boshqaruvchi State Manager
class GameState extends ChangeNotifier {
  static final GameState _instance = GameState._internal();
  factory GameState() => _instance;
  GameState._internal();

  static const totalRounds = 14;
  static const maxSquad = 28;
  static const minSquad = 18;
  static const firstSeason = 2026;

  List<Club> _allClubs = [];
  String? _userClubId;
  List<Fixture> _fixtures = [];
  Map<String, LeagueStanding> _standingsMap = {};
  int _currentRound = 1;
  bool _isInitialized = false;
  bool seasonFinished = false;
  SeasonCalendar calendar = const SeasonCalendar(firstSeason);
  final List<FinanceEntry> ledger = [];
  final List<TransferRecord> transferHistory = [];
  final List<NewsItem> news = [];
  final List<TransferOffer> offers = [];
  final List<Player> freeAgents = [];
  final List<SeasonSummary> seasonHistory = [];
  final List<int> balanceHistory = [];
  BoardObjective objective = const BoardObjective('Top-4', 4);
  /// Random per career: drives the fixture draw, match outcomes, AI deals.
  int careerSeed = Random().nextInt(1 << 30);
  int _salt(int v) => (careerSeed * 31 + v) & 0x3fffffff;
  int boardConfidence = 70;
  String? lastTransferError;

  ManagerProfile _managerProfile = ManagerProfile(
    name: 'Azizbek Rahimov',
    avatarId: 'suit_dark',
    nationality: 'O‘zbekiston',
    countryFlag: '🇺🇿',
    age: 42,
    philosophy: ManagerPhilosophy.possession,
  );

  // ---------------------------------------------------------------- getters
  bool get isInitialized => _isInitialized;
  List<Club> get allClubs => _allClubs;
  String? get userClubId => _userClubId;
  int get currentRound => _currentRound;
  List<Fixture> get fixtures => _fixtures;
  ManagerProfile get managerProfile => _managerProfile;
  String get seasonLabel => calendar.label;
  DateTime get currentDate => calendar.dateOfRound(_currentRound);
  bool get isTransferWindowOpen =>
      !seasonFinished && calendar.windowOpenOn(currentDate);
  String get transferWindowLabel {
    if (isTransferWindowOpen) {
      final close = currentDate.month >= 6
          ? calendar.summerClose
          : calendar.winterClose;
      return 'Transfer oynasi ochiq · ${SeasonCalendar.format(close)} gacha';
    }
    final next = currentDate.isBefore(calendar.winterOpen)
        ? calendar.winterOpen
        : DateTime(calendar.year + 1, 6, 16);
    return 'Transfer oynasi yopiq · ${SeasonCalendar.format(next)} da ochiladi';
  }

  int get unreadNews => news.where((n) => !n.read).length;

  void updateManagerProfile(ManagerProfile profile) {
    _managerProfile = profile;
    notifyListeners();
  }

  void touch() => notifyListeners();

  Club get userClub => _allClubs.firstWhere(
    (c) => c.id == _userClubId,
    orElse: () => _allClubs.first,
  );

  Club? getClubById(String id) =>
      _allClubs.where((c) => c.id == id).firstOrNull;

  Club? clubOfPlayer(Player p) =>
      _allClubs.where((c) => c.squad.contains(p)).firstOrNull;

  List<LeagueStanding> get sortedStandings {
    final list = _standingsMap.values.toList();
    list.sort((a, b) {
      if (b.points != a.points) return b.points.compareTo(a.points);
      if (b.goalDifference != a.goalDifference) {
        return b.goalDifference.compareTo(a.goalDifference);
      }
      return b.goalsFor.compareTo(a.goalsFor);
    });
    return list;
  }

  int positionOf(String clubId) =>
      sortedStandings.indexWhere((s) => s.clubId == clubId) + 1;
  LeagueStanding standingOf(String clubId) => _standingsMap[clubId]!;

  List<PlayerLeaderboardEntry> _board(
    bool Function(Player) include,
    int Function(Player, Player) compare,
  ) {
    final list = <PlayerLeaderboardEntry>[
      for (final club in _allClubs)
        for (final p in club.squad)
          if (include(p)) PlayerLeaderboardEntry(player: p, club: club),
    ];
    list.sort((a, b) => compare(a.player, b.player));
    return list;
  }

  List<PlayerLeaderboardEntry> get topScorers => _board(
    (p) => p.seasonGoals > 0,
    (a, b) => b.seasonGoals != a.seasonGoals
        ? b.seasonGoals.compareTo(a.seasonGoals)
        : b.seasonAssists.compareTo(a.seasonAssists),
  );
  List<PlayerLeaderboardEntry> get topAssists => _board(
    (p) => p.seasonAssists > 0,
    (a, b) => b.seasonAssists.compareTo(a.seasonAssists),
  );
  List<PlayerLeaderboardEntry> get topCleanSheets => _board(
    (p) => p.mainPosition.isGoalkeeper && p.seasonCleanSheets > 0,
    (a, b) => b.seasonCleanSheets.compareTo(a.seasonCleanSheets),
  );
  List<PlayerLeaderboardEntry> get topRated => _board(
    (p) => p.seasonRated >= max(1, (_playedRounds * 0.4).floor()),
    (a, b) => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
  );

  int get _playedRounds =>
      _fixtures.where((f) => f.isPlayed && f.involves(_userClubId ?? '')).length;

  Fixture? get nextUserFixture => _fixtures
      .where(
        (f) =>
            f.round == _currentRound &&
            !f.isPlayed &&
            f.involves(_userClubId ?? ''),
      )
      .firstOrNull;

  List<Fixture> get currentRoundFixtures =>
      _fixtures.where((f) => f.round == _currentRound).toList();

  List<Fixture> fixturesOf(String clubId) =>
      _fixtures.where((f) => f.involves(clubId)).toList();

  Fixture? get lastUserResult => _fixtures
      .where((f) => f.isPlayed && f.involves(_userClubId ?? ''))
      .lastOrNull;

  // ------------------------------------------------------------ careers
  void resetCareer() {
    _resetRecords();
    _allClubs = [];
    _userClubId = null;
    _fixtures = [];
    _standingsMap = {};
    _currentRound = 1;
    _isInitialized = false;
    notifyListeners();
  }

  void _resetRecords() {
    ledger.clear();
    transferHistory.clear();
    news.clear();
    offers.clear();
    freeAgents.clear();
    seasonHistory.clear();
    balanceHistory.clear();
    lastTransferError = null;
    seasonFinished = false;
    boardConfidence = 70;
    calendar = const SeasonCalendar(firstSeason);
  }

  void startCareerWithExistingClub(
    Club selectedClub, {
    ManagerProfile? managerProfile,
  }) {
    if (managerProfile != null) _managerProfile = managerProfile;
    _resetRecords();
    _allClubs = InitialDatabase.getSuperLeagueClubs();
    _userClubId = selectedClub.id;
    _beginCareer();
  }

  void startCareerWithCustomClub({
    required String name,
    required String shortName,
    required String stadiumName,
    required int stadiumCapacity,
    required ClubCrestConfig crestConfig,
    ManagerProfile? managerProfile,
    Player? star,
  }) {
    if (managerProfile != null) _managerProfile = managerProfile;
    final baseClubs = InitialDatabase.getSuperLeagueClubs();
    final customClubId = 'custom_${DateTime.now().microsecondsSinceEpoch}';
    final squad = _generateCustomSquad(customClubId);
    if (star != null) {
      // The chosen star takes the starting slot of the same position.
      final i = squad.indexWhere((p) => p.mainPosition == star.mainPosition);
      final slot = i >= 0 ? i : 10;
      squad[slot] = Player.fromMap({
        ...star.toMap(),
        'id': '${customClubId}_star',
        'number': squad[slot].number,
      });
    }
    final customClub = Club(
      id: customClubId,
      name: name,
      shortName: shortName.toUpperCase(),
      primaryColor: crestConfig.primaryColor,
      secondaryColor: crestConfig.secondaryColor,
      accentColor: crestConfig.trimColor,
      stadiumName: stadiumName,
      stadiumCapacity: stadiumCapacity,
      city: 'Toshkent',
      nickname: 'Yangi kuch',
      founded: firstSeason,
      reputation: 72,
      transferBudget: 80000000,
      wageBudget: 2600000,
      ticketPrice: 45,
      fanMood: 80,
      tactics: const TeamTactics(),
      crestConfig: crestConfig,
      squad: squad,
      startingLineupIds: squad.take(11).map((p) => p.id).toList(),
      benchIds: squad.skip(11).take(Club.matchdayBench).map((p) => p.id).toList(),
    );
    _resetRecords();
    _allClubs = [...baseClubs.take(7), customClub];
    _userClubId = customClubId;
    _beginCareer();
  }

  void _beginCareer() {
    careerSeed = Random().nextInt(1 << 30);
    for (final c in _allClubs) {
      _ensureMatchdaySquad(c);
      if (c.id != _userClubId) autoPickLineup(c);
    }
    _generateSeasonSchedule();
    _initializeStandings();
    _currentRound = 1;
    _isInitialized = true;
    objective = _objectiveFor(userClub);
    balanceHistory.add(userClub.transferBudget);
    _seedFreeAgents();
    _news(
      NewsKind.board,
      '${userClub.name}ga xush kelibsiz!',
      'Boshqaruv kengashi ${_managerProfile.name}ni bosh murabbiy etib tayinladi. '
          'Mavsum maqsadi: ${objective.title}. Transfer byudjeti ${_m(userClub.transferBudget)}.',
    );
    _news(
      NewsKind.window,
      'Yozgi transfer oynasi ochiq',
      'Oyna ${SeasonCalendar.format(calendar.summerClose)} gacha ishlaydi. '
          'Qishki oyna: ${SeasonCalendar.format(calendar.winterOpen)} – ${SeasonCalendar.format(calendar.winterClose)}.',
    );
    notifyListeners();
  }

  BoardObjective _objectiveFor(Club c) {
    final ranked = List<Club>.of(_allClubs)
      ..sort((a, b) => b.squadDepthRating.compareTo(a.squadDepthRating));
    final rank = ranked.indexOf(c) + 1;
    return switch (rank) {
      1 => const BoardObjective('Chempionlik', 1),
      2 || 3 => const BoardObjective('Top-3', 3),
      4 || 5 => const BoardObjective('Top-4', 4),
      _ => const BoardObjective('Top-6', 6),
    };
  }

  void _initializeStandings() {
    _standingsMap = {
      for (final club in _allClubs) club.id: LeagueStanding(clubId: club.id),
    };
  }

  /// Berger round-robin: 7 rounds, then mirrored with venues swapped.
  void _generateSeasonSchedule() {
    _fixtures = [];
    final n = _allClubs.length;
    // The draw: club order is shuffled per career and per season.
    final ids = _allClubs.map((c) => c.id).toList()
      ..shuffle(Random(_salt(calendar.year)));
    for (var r = 0; r < n - 1; r++) {
      for (var i = 0; i < n ~/ 2; i++) {
        final home = ids[i], away = ids[n - 1 - i];
        _fixtures.add(
          Fixture(
            id: 'fix_${calendar.year}_r${r + 1}_$i',
            round: r + 1,
            homeClubId: r % 2 == 0 ? home : away,
            awayClubId: r % 2 == 0 ? away : home,
            date: calendar.dateOfRound(r + 1),
          ),
        );
      }
      ids.insert(1, ids.removeLast());
    }
    for (final f in List<Fixture>.of(_fixtures)) {
      _fixtures.add(
        Fixture(
          id: 'fix_${calendar.year}_r${f.round + 7}_${f.id}',
          round: f.round + 7,
          homeClubId: f.awayClubId,
          awayClubId: f.homeClubId,
          date: calendar.dateOfRound(f.round + 7),
        ),
      );
    }
  }

  // ------------------------------------------------------ squad management
  void updateTactics(TeamTactics newTactics) {
    userClub.tactics = newTactics;
    notifyListeners();
  }

  /// Swaps any two of the user's players between XI, bench and reserves.
  bool swapPlayer(String firstId, String secondId) {
    final club = userClub;
    if (firstId == secondId ||
        club.playerById(firstId) == null ||
        club.playerById(secondId) == null) {
      return false;
    }
    List<String>? listOf(String id) => club.startingLineupIds.contains(id)
        ? club.startingLineupIds
        : club.benchIds.contains(id)
        ? club.benchIds
        : null;
    final la = listOf(firstId), lb = listOf(secondId);
    if (la == null && lb == null) return false;
    if (la != null && lb != null) {
      final a = la.indexOf(firstId), b = lb.indexOf(secondId);
      la[a] = secondId;
      lb[b] = firstId;
    } else if (la != null) {
      la[la.indexOf(firstId)] = secondId;
    } else {
      lb![lb.indexOf(secondId)] = firstId;
    }
    notifyListeners();
    return true;
  }

  /// Moves a reserve onto the matchday bench (or off it).
  bool toggleBench(String id) {
    final club = userClub;
    if (club.startingLineupIds.contains(id)) return false;
    if (club.benchIds.remove(id)) {
      notifyListeners();
      return true;
    }
    if (club.benchIds.length >= Club.matchdayBench) return false;
    club.benchIds.add(id);
    notifyListeners();
    return true;
  }

  void setPlayerInstruction(Player p, PlayerInstruction instruction) {
    if (userClub.squad.contains(p)) {
      p.instruction = instruction;
      notifyListeners();
    }
  }

  void _ensureMatchdaySquad(Club c) {
    c.benchIds.removeWhere(
      (id) => c.playerById(id) == null || c.startingLineupIds.contains(id),
    );
    final reserves = c.reserves..sort((a, b) => b.ovr.compareTo(a.ovr));
    if (!c.bench.any((p) => p.mainPosition.isGoalkeeper)) {
      final gk = reserves.where((p) => p.mainPosition.isGoalkeeper).firstOrNull;
      if (gk != null) {
        c.benchIds.add(gk.id);
        reserves.remove(gk);
      }
    }
    for (final p in reserves) {
      if (c.benchIds.length >= Club.matchdayBench) break;
      c.benchIds.add(p.id);
    }
    while (c.benchIds.length > Club.matchdayBench) {
      c.benchIds.removeLast();
    }
  }

  /// Picks the strongest available XI for the formation, then a balanced
  /// nine-man bench (always including a keeper).
  void autoPickLineup(Club c, {bool byForm = false}) {
    final slots = c.tactics.formation.slots;
    final pool = c.squad.where((p) => p.isAvailable).toList();
    final chosen = List<Player?>.filled(slots.length, null);
    // Strongest: positional OVR. Form: also recent ratings and freshness.
    double score(Player p, PlayerPosition pos) => byForm
        ? p.getEffectiveOVR(pos) * (0.75 + p.currentStamina / 100 * 0.25) +
              ((p.averageRating ?? 6.6) - 6.6) * 6
        : p.getEffectiveOVR(pos) * (0.86 + p.currentStamina / 100 * 0.14);
    // Fill scarce slots first: GK, then defence, then the rest.
    final order = List<int>.generate(slots.length, (i) => i)
      ..sort((a, b) {
        int rank(PlayerPosition p) => p.isGoalkeeper
            ? 0
            : p.isDefender
            ? 1
            : p.isAttacker
            ? 2
            : 3;
        return rank(slots[a].defaultPosition).compareTo(
          rank(slots[b].defaultPosition),
        );
      });
    for (final i in order) {
      final pos = slots[i].defaultPosition;
      final options = pool
          .where(
            (p) =>
                !chosen.contains(p) &&
                (pos.isGoalkeeper == p.mainPosition.isGoalkeeper),
          )
          .toList();
      if (options.isEmpty) continue;
      options.sort((a, b) => score(b, pos).compareTo(score(a, pos)));
      chosen[i] = options.first;
    }
    // Any hole (e.g. no keeper available) is filled by whoever is left.
    for (var i = 0; i < chosen.length; i++) {
      if (chosen[i] != null) continue;
      final rest = c.squad.where((p) => !chosen.contains(p)).toList()
        ..sort((a, b) => b.ovr.compareTo(a.ovr));
      if (rest.isNotEmpty) chosen[i] = rest.first;
    }
    c.startingLineupIds = chosen.whereType<Player>().map((p) => p.id).toList();
    final rest = c.squad
        .where((p) => !c.startingLineupIds.contains(p.id) && p.isAvailable)
        .toList()
      ..sort((a, b) => b.ovr.compareTo(a.ovr));
    final bench = <String>[];
    final gk = rest.where((p) => p.mainPosition.isGoalkeeper).firstOrNull;
    if (gk != null) bench.add(gk.id);
    for (final cat in [
      PositionCategory.defense,
      PositionCategory.midfield,
      PositionCategory.attack,
    ]) {
      final p = rest
          .where((p) => p.mainPosition.category == cat && !bench.contains(p.id))
          .firstOrNull;
      if (p != null) bench.add(p.id);
    }
    for (final p in rest) {
      if (bench.length >= Club.matchdayBench) break;
      if (!bench.contains(p.id) && !p.mainPosition.isGoalkeeper) {
        bench.add(p.id);
      }
    }
    c.benchIds = bench;
  }

  void autoPickUserLineup({bool byForm = false}) {
    autoPickLineup(userClub, byForm: byForm);
    notifyListeners();
  }

  /// Players in the user's XI who cannot play this round.
  List<Player> get unavailableStarters =>
      userClub.startingXI.where((p) => !p.isAvailable).toList();

  /// Replaces injured/suspended starters with the best bench option.
  void fixUnavailableStarters() {
    final c = userClub;
    for (var i = 0; i < c.startingLineupIds.length; i++) {
      final p = c.playerById(c.startingLineupIds[i]);
      if (p == null || p.isAvailable) continue;
      final pos = c.slotPosition(i);
      final options = [...c.bench, ...c.reserves]
          .where(
            (q) =>
                q.isAvailable &&
                (q.mainPosition.isGoalkeeper == pos.isGoalkeeper),
          )
          .toList()
        ..sort((a, b) => b.getMatchOVR(pos).compareTo(a.getMatchOVR(pos)));
      if (options.isEmpty) continue;
      final q = options.first;
      c.startingLineupIds[i] = q.id;
      final bi = c.benchIds.indexOf(q.id);
      if (bi >= 0) {
        c.benchIds[bi] = p.id;
      }
    }
    c.benchIds.removeWhere((id) => !(c.playerById(id)?.isAvailable ?? false));
    _ensureMatchdaySquad(c);
    notifyListeners();
  }

  // ------------------------------------------------------------ matches
  /// Records a fixture. With [engine] every statistic, rating and injury
  /// comes from the simulation; without it only the given events are used.
  void finishMatch({
    required Fixture fixture,
    required int homeScore,
    required int awayScore,
    required List<MatchEvent> events,
    Set<String>? participantIds,
    MatchField? engine,
  }) {
    if (fixture.isPlayed) return;
    _tickAvailability();
    final homeClub = getClubById(fixture.homeClubId)!;
    final awayClub = getClubById(fixture.awayClubId)!;
    if (engine != null) {
      engine.writeTo(fixture);
      fixture.homeScore = homeScore;
      fixture.awayScore = awayScore;
      _applyEngine(fixture, engine);
    } else {
      fixture.homeScore = homeScore;
      fixture.awayScore = awayScore;
      fixture.events = events;
      _applyEventsOnly(fixture, homeClub, awayClub, events, participantIds);
    }
    fixture.isPlayed = true;
    _standingsMap[fixture.homeClubId]?.recordMatch(
      myGoals: homeScore,
      opponentGoals: awayScore,
    );
    _standingsMap[fixture.awayClubId]?.recordMatch(
      myGoals: awayScore,
      opponentGoals: homeScore,
    );
    if (fixture.involves(_userClubId!)) _recordManagerResult(fixture);
    _simulateOtherMatchesInRound(_currentRound, fixture.id);
    _applyMatchEconomics();
    _roundNews(fixture);
    balanceHistory.add(userClub.transferBudget);
    if (_currentRound == totalRounds &&
        _fixtures.every((f) => f.isPlayed)) {
      _closeSeason();
    }
    notifyListeners();
  }

  void _tickAvailability() {
    for (final club in _allClubs) {
      for (final p in club.squad) {
        if (p.injuryRounds > 0) {
          p.injuryRounds--;
          if (p.injuryRounds == 0) p.injury = null;
        }
        if (p.suspensionRounds > 0) p.suspensionRounds--;
      }
    }
  }

  void _recordManagerResult(Fixture f) {
    final m = _managerProfile;
    m.matchesManaged++;
    final r = f.resultFor(_userClubId!);
    final style = ManagerPhilosophy.forStyle(userClub.tactics.playstyle);
    final conceded = f.homeClubId == _userClubId ? f.awayScore! : f.homeScore!;
    final xp = 2 + (r == 'W' ? 3 : r == 'D' ? 1 : 0) + (conceded == 0 ? 1 : 0);
    if (m.gainExperience(style, xp) > 0) {
      _news(
        NewsKind.board,
        'Menejer reytingi oshdi: ${style.title}',
        '${m.name} – ${style.title} uslubi ${m.proficiency[style]} ga ko‘tarildi. '
            'Bu uslubda jamoa aniqroq pas beradi va to‘g‘ri qaror qabul qiladi.',
      );
    }
    final opp = getClubById(f.homeClubId == _userClubId ? f.awayClubId : f.homeClubId)!;
    final gap = (opp.teamOVR - userClub.teamOVR) / 3;
    if (r == 'W') {
      m.wins++;
      boardConfidence += (3 + gap).round().clamp(1, 7);
    } else if (r == 'D') {
      m.draws++;
      boardConfidence += gap.round().clamp(-2, 3);
    } else {
      m.losses++;
      boardConfidence -= (4 - gap).round().clamp(1, 7);
    }
    boardConfidence = boardConfidence.clamp(5, 100);
    for (final p in userClub.squad) {
      final played = f.playerStats[p.id]?.minutes ?? 0;
      if (played <= 0 && !userClub.benchIds.contains(p.id)) {
        p.morale = max(35, p.morale - 1);
      }
    }
    userClub.fanMood = (userClub.fanMood + (r == 'W' ? 4 : r == 'D' ? 0 : -4))
        .clamp(10, 100);
  }

  void _applyEventsOnly(
    Fixture fixture,
    Club homeClub,
    Club awayClub,
    List<MatchEvent> events,
    Set<String>? participantIds,
  ) {
    for (final club in [homeClub, awayClub]) {
      for (final p in club.squad.where(
        (p) =>
            participantIds?.contains(p.id) ??
            club.startingLineupIds.contains(p.id),
      )) {
        p.seasonMatches++;
        p.seasonMinutes += 90;
      }
      final conceded = club == homeClub ? fixture.awayScore! : fixture.homeScore!;
      if (conceded == 0) {
        club.startingXI
            .where((p) => p.mainPosition.isGoalkeeper)
            .firstOrNull
            ?.seasonCleanSheets++;
      }
    }
    for (final event in events) {
      final club = getClubById(event.clubId);
      final player = club?.squad
          .where((p) => p.name == event.playerName || p.shortName == event.playerName)
          .firstOrNull;
      if (event.type == MatchEventType.goal) player?.seasonGoals++;
      if (event.type == MatchEventType.yellowCard) player?.seasonYellowCards++;
      if (event.type == MatchEventType.redCard) player?.seasonRedCards++;
      if (event.assistPlayerId != null) {
        club?.squad
            .where((p) => p.id == event.assistPlayerId)
            .firstOrNull
            ?.seasonAssists++;
      }
    }
  }

  void _applyEngine(Fixture f, MatchField e) {
    final homeClub = getClubById(f.homeClubId)!, awayClub = getClubById(f.awayClubId)!;
    final motm = e.manOfTheMatch;
    for (final entry in e.lines.entries) {
      final line = entry.value;
      if (line.minutes <= 0) continue;
      final p = homeClub.playerById(entry.key) ?? awayClub.playerById(entry.key);
      if (p == null) continue;
      p.seasonMatches++;
      p.seasonMinutes += line.minutes.round();
      p.seasonGoals += line.goals;
      p.seasonAssists += line.assists;
      if (line.yellow > 0) {
        p.seasonYellowCards += line.yellow;
        if (line.red == 0 && p.seasonYellowCards % 5 == 0) {
          p.suspensionRounds = max(p.suspensionRounds, 1);
        }
      }
      if (line.red > 0) {
        p.seasonRedCards++;
        p.suspensionRounds = max(p.suspensionRounds, line.yellow >= 2 ? 1 : 2);
      }
      final rating = e.ratingFor(entry.key);
      if (rating != null) {
        p.recordRating(rating);
        p.morale = (p.morale + (rating >= 7.5 ? 3 : rating < 6.0 ? -3 : 1))
            .clamp(30, 100);
      }
      if (entry.key == motm) p.seasonMotm++;
      if (rating != null) _inSeasonGrowth(p, rating, line.minutes);
      final isHome = homeClub.squad.contains(p);
      final conceded = isHome ? f.awayScore! : f.homeScore!;
      if (p.mainPosition.isGoalkeeper && line.started && line.minutes >= 60 && conceded == 0) {
        p.seasonCleanSheets++;
      }
    }
    const names = [
      'Son mushagi cho‘zilishi',
      'To‘piq lat yeyishi',
      'Tizza zarbasi',
      'Boldir mushagi',
      'Yelka chiqishi',
      'Bel og‘rig‘i',
    ];
    final rnd = Random(_salt(f.id.hashCode));
    for (final entry in e.injuries.entries) {
      final p = homeClub.playerById(entry.key) ?? awayClub.playerById(entry.key);
      if (p == null) continue;
      p.injuryRounds = max(p.injuryRounds, entry.value);
      p.injury = names[rnd.nextInt(names.length)];
      if (homeClub.id == _userClubId || awayClub.id == _userClubId) {
        if (userClub.squad.contains(p)) {
          _news(
            NewsKind.injury,
            '${p.name} jarohat oldi',
            '${p.injury}. Shifokorlar xulosasi: taxminan ${p.injuryRounds} tur o‘tkazib yuboradi.',
          );
        }
      }
    }
    final h = getClubById(f.homeClubId)!;
    f.attendance = _attendance(h);
  }

  /// Good performances (and youth) slowly raise attributes during the season.
  void _inSeasonGrowth(Player p, double rating, double minutes) {
    if (minutes < 30) return;
    final youth = p.age <= 21 ? 0.12 : p.age <= 24 ? 0.06 : p.age >= 31 ? -0.04 : 0.0;
    p.growth += (rating - 6.6) * 0.18 * (minutes / 90) + youth;
    if (p.growth < 1 || p.ovr >= p.potential) {
      if (p.growth < -1) p.growth = -1;
      return;
    }
    p.growth -= 1;
    final before = p.ovr;
    final weights = _keyAttributes(p.mainPosition);
    final m = p.stats.toMap().map((k, v) => MapEntry(k, v as int));
    for (final k in weights) {
      m[k] = (m[k]! + 1).clamp(40, 99);
    }
    p.stats = PlayerStats.fromMap(m);
    p.marketValue = Player.valuation(p.ovr, p.age, p.potential);
    if (p.ovr > before && userClub.squad.contains(p)) {
      _news(
        NewsKind.award,
        '${p.shortName} rivojlandi: OVR $before → ${p.ovr}',
        'Yaxshi o‘yinlar va mashg‘ulotlar natijasi. Bozor bahosi: ${_m(p.marketValue)}.',
      );
    }
  }

  static List<String> _keyAttributes(PlayerPosition pos) => switch (pos) {
    PlayerPosition.gk => ['gkReflexes', 'gkAwareness', 'gkReach'],
    PlayerPosition.cb => ['defensiveAwareness', 'tackling', 'defensiveEngagement'],
    PlayerPosition.lb || PlayerPosition.rb => ['defensiveAwareness', 'stamina', 'loftedPass'],
    PlayerPosition.dmf => ['defensiveAwareness', 'tackling', 'lowPass'],
    PlayerPosition.cmf => ['lowPass', 'loftedPass', 'tightPossession'],
    PlayerPosition.amf => ['lowPass', 'ballControl', 'tightPossession'],
    PlayerPosition.lmf || PlayerPosition.rmf => ['loftedPass', 'dribbling', 'speed'],
    PlayerPosition.lwf || PlayerPosition.rwf => ['dribbling', 'ballControl', 'speed'],
    PlayerPosition.ss => ['attackingAwareness', 'dribbling', 'lowPass'],
    PlayerPosition.cf => ['finishing', 'attackingAwareness', 'kickingPower'],
  };

  void _simulateOtherMatchesInRound(int round, String userFixtureId) {
    for (final f in _fixtures.where(
      (f) => f.round == round && f.id != userFixtureId && !f.isPlayed,
    )) {
      final home = getClubById(f.homeClubId)!, away = getClubById(f.awayClubId)!;
      if (home.id != _userClubId) autoPickLineup(home);
      if (away.id != _userClubId) autoPickLineup(away);
      final engine = MatchField(
        home,
        away,
        seed: f.id.codeUnits.fold<int>(
          _salt(round * 7 + calendar.year),
          (a, b) => (a * 31 + b) & 0x7fffffff,
        ),
        homeCoaching: home.id == _userClubId
            ? _managerProfile.ratingFor(home.tactics.playstyle)
            : 66 + home.reputation ~/ 10,
        awayCoaching: away.id == _userClubId
            ? _managerProfile.ratingFor(away.tactics.playstyle)
            : 66 + away.reputation ~/ 10,
      );
      engine.simulateToEnd();
      engine.writeTo(f);
      _applyEngine(f, engine);
      f.isPlayed = true;
      _standingsMap[home.id]?.recordMatch(
        myGoals: f.homeScore!,
        opponentGoals: f.awayScore!,
      );
      _standingsMap[away.id]?.recordMatch(
        myGoals: f.awayScore!,
        opponentGoals: f.homeScore!,
      );
      if (f.involves(_userClubId!)) _recordManagerResult(f);
      // Engine substitutions mutate lineups; AI clubs re-pick next round.
    }
  }

  /// A full instant simulation of the user's own fixture (no live view).
  MatchField simulateUserFixture(Fixture f) {
    final home = getClubById(f.homeClubId)!, away = getClubById(f.awayClubId)!;
    final userHome = home.id == _userClubId;
    final engine = MatchField(
      home,
      away,
      seed: f.id.codeUnits.fold<int>(_salt(1), (a, b) => (a * 31 + b) & 0x7fffffff),
      homeCoaching: userHome
          ? _managerProfile.ratingFor(home.tactics.playstyle)
          : 66 + home.reputation ~/ 10,
      awayCoaching: !userHome
          ? _managerProfile.ratingFor(away.tactics.playstyle)
          : 66 + away.reputation ~/ 10,
    );
    engine.simulateToEnd();
    finishMatch(
      fixture: f,
      homeScore: engine.homeStats.goals,
      awayScore: engine.awayStats.goals,
      events: engine.events,
      engine: engine,
    );
    return engine;
  }

  // ------------------------------------------------------------ economy
  int baseTicketPrice(Club c) => 35 + c.reputation ~/ 2;

  int _attendance(Club c) {
    final pos = _standingsMap.isEmpty ? 4 : positionOf(c.id);
    final priceRatio = c.ticketPrice / baseTicketPrice(c);
    final demand =
        0.62 +
        c.reputation / 420 +
        c.fanMood / 700 +
        (8 - pos) * 0.012 -
        (priceRatio - 1) * 0.42;
    return (c.stadiumCapacity * demand.clamp(0.35, 1.0)).round();
  }

  int projectedAttendance(Club c) => _attendance(c);
  int projectedGate(Club c) => _attendance(c) * c.ticketPrice;

  void setTicketPrice(int price) {
    userClub.ticketPrice = price.clamp(20, 200);
    notifyListeners();
  }

  int weeklyCommercial(Club c) => c.reputation * c.reputation * 520;

  void _post(
    Club club,
    String label,
    int amount, {
    FinanceCategory category = FinanceCategory.operations,
  }) {
    club.transferBudget += amount;
    ledger.add(
      FinanceEntry(
        _currentRound,
        club.id,
        label,
        amount,
        category: category,
        date: currentDate,
      ),
    );
  }

  void _applyMatchEconomics() {
    final weeks = calendar.weeksAfterRound(_currentRound);
    for (final club in _allClubs) {
      final f = _fixtures
          .where((f) => f.round == _currentRound && f.involves(club.id))
          .firstOrNull;
      if (f == null || !f.isPlayed) continue;
      if (ledger.any(
        (e) =>
            e.round == _currentRound &&
            e.clubId == club.id &&
            e.category == FinanceCategory.broadcast,
      )) {
        continue;
      }
      if (f.homeClubId == club.id) {
        final attendance = f.attendance > 0 ? f.attendance : _attendance(club);
        f.attendance = attendance;
        _post(club, 'Chipta tushumi · $attendance muxlis', attendance * club.ticketPrice,
            category: FinanceCategory.tickets);
        _post(club, 'Stadion va xavfsizlik', -(attendance * 6 + 180000),
            category: FinanceCategory.stadium);
        final ratio = club.ticketPrice / baseTicketPrice(club);
        club.fanMood = (club.fanMood - ((ratio - 1) * 6).round()).clamp(10, 100);
      }
      final pos = positionOf(club.id);
      _post(club, 'Teletranslyatsiya ulushi', 1800000 + (8 - pos) * 150000,
          category: FinanceCategory.broadcast);
      _post(club, 'Homiylik va savdo · $weeks hafta', weeklyCommercial(club) * weeks,
          category: FinanceCategory.commercial);
      _post(club, 'Futbolchi maoshlari · $weeks hafta', -club.totalWeeklyWages * weeks,
          category: FinanceCategory.wages);
      _post(club, 'Klub, akademiya va xodimlar · $weeks hafta',
          -(250000 + club.reputation * 2000) * weeks,
          category: FinanceCategory.operations);
      for (final p in club.squad) {
        final starter = club.startingLineupIds.contains(p.id);
        p.morale = (p.morale + (starter ? 1 : 0)).clamp(30, 100);
      }
    }
  }

  // ----------------------------------------------------------- rounds
  void nextRound() {
    if (seasonFinished ||
        _currentRound >= totalRounds ||
        currentRoundFixtures.any((f) => !f.isPlayed)) {
      return;
    }
    final wasOpen = isTransferWindowOpen;
    final days = calendar
        .dateOfRound(_currentRound + 1)
        .difference(calendar.dateOfRound(_currentRound))
        .inDays;
    _currentRound++;
    for (final club in _allClubs) {
      for (final p in club.squad) {
        p.currentStamina = min(100, p.currentStamina + 10 + days * 3);
      }
    }
    final open = isTransferWindowOpen;
    if (!wasOpen && open) {
      _news(
        NewsKind.window,
        'Qishki transfer oynasi ochildi',
        'Oyna ${SeasonCalendar.format(calendar.winterClose)} gacha ochiq. Tarkibni kuchaytirish vaqti!',
      );
    } else if (wasOpen && !open) {
      _news(
        NewsKind.window,
        'Transfer oynasi yopildi',
        'Keyingi oyna: ${SeasonCalendar.format(currentDate.isBefore(calendar.winterOpen) ? calendar.winterOpen : DateTime(calendar.year + 1, 6, 16))}.',
      );
      offers.clear();
    }
    if (open) {
      _simulateAITransfers();
      _generateOffers();
    }
    for (final c in _allClubs) {
      if (c.id != _userClubId) autoPickLineup(c);
    }
    if (_currentRound == 10) {
      final expiring = userClub.squad.where((p) => p.contract.contractYears <= 1).toList();
      if (expiring.isNotEmpty) {
        _news(
          NewsKind.contract,
          'Shartnomasi tugayotgan futbolchilar',
          '${expiring.take(4).map((p) => p.shortName).join(', ')}${expiring.length > 4 ? ' va boshqalar' : ''}: '
              'yangilanmasa, mavsum oxirida klubni tark etadi.',
        );
      }
    }
    notifyListeners();
  }

  // --------------------------------------------------------- transfers
  int transferFee(Player p) {
    final premium = p.contract.contractYears >= 3
        ? 1.15
        : p.contract.contractYears == 1
        ? 0.85
        : 1.0;
    final fee = (p.marketValue * premium).round();
    return p.contract.releaseClause > 0
        ? min(fee, p.contract.releaseClause)
        : fee;
  }

  /// What the selling club actually wants (starters carry a premium).
  int askingPrice(Player p, Club seller) =>
      (transferFee(p) * (seller.startingLineupIds.contains(p.id) ? 1.15 : 1.0))
          .round();

  int offeredWage(Player p) =>
      max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
  int signingCost(Player p, [int? fee]) =>
      ((fee ?? transferFee(p)) * 0.03).round() + offeredWage(p) * 4;

  String? transferIssue(Player player, Club seller, Club buyer, [int? fee]) {
    final price = fee ?? transferFee(player);
    if (!isTransferWindowOpen) {
      return 'Transfer oynasi yopiq. $transferWindowLabel.';
    }
    if (seller.id == buyer.id ||
        !seller.squad.any((p) => p.id == player.id) ||
        buyer.squad.any((p) => p.id == player.id)) {
      return 'Futbolchi bu transfer uchun mavjud emas.';
    }
    if (seller.squad.length <= minSquad) {
      return 'Sotuvchi klub kamida $minSquad futbolchini saqlashi kerak.';
    }
    if (player.mainPosition.isGoalkeeper &&
        seller.squad.where((p) => p.mainPosition.isGoalkeeper).length <= 2) {
      return 'Klub darvozabonlar sonini kamaytirmaydi.';
    }
    if (buyer.squad.length >= maxSquad) {
      return 'Ro‘yxat to‘la: ko‘pi bilan $maxSquad futbolchi.';
    }
    if (buyer.transferBudget < price + signingCost(player, price)) {
      return 'Transfer, agent va imzo xarajatlari uchun mablag‘ yetarli emas.';
    }
    if (buyer.remainingWageBudget < offeredWage(player)) {
      return 'Haftalik maosh limiti yetarli emas.';
    }
    return null;
  }

  void _completeTransfer(Player p, Club seller, Club buyer, [int? agreedFee]) {
    final fee = agreedFee ?? transferFee(p);
    final costs = signingCost(p, fee);
    _post(buyer, '${p.shortName}: transfer', -fee,
        category: FinanceCategory.transferOut);
    _post(buyer, '${p.shortName}: agent va imzo', -costs,
        category: FinanceCategory.agent);
    _post(seller, '${p.shortName}: transfer tushumi', fee,
        category: FinanceCategory.transferIn);
    seller.squad.removeWhere((q) => q.id == p.id);
    final starterIndex = seller.startingLineupIds.indexOf(p.id);
    seller.startingLineupIds.remove(p.id);
    seller.benchIds.remove(p.id);
    if (starterIndex >= 0) {
      final pos = seller.slotPosition(starterIndex);
      final candidates = [...seller.bench, ...seller.reserves]
        ..sort(
          (a, b) => b.getEffectiveOVR(pos).compareTo(a.getEffectiveOVR(pos)),
        );
      if (candidates.isNotEmpty) {
        seller.startingLineupIds.insert(starterIndex, candidates.first.id);
        seller.benchIds.remove(candidates.first.id);
      }
    }
    _ensureMatchdaySquad(seller);
    p.contract = p.contract.copyWith(contractYears: 3, weeklyWage: offeredWage(p));
    p.morale = 88;
    buyer.squad.add(p);
    if (buyer.benchIds.length < Club.matchdayBench) buyer.benchIds.add(p.id);
    transferHistory.insert(
      0,
      TransferRecord(_currentRound, p.name, seller.name, buyer.name, fee, date: currentDate),
    );
    if (buyer.id != _userClubId && seller.id != _userClubId) {
      _news(
        NewsKind.transfer,
        '${p.name} → ${buyer.name}',
        '${seller.name} futbolchini ${_m(fee)} evaziga sotdi.',
      );
    }
  }

  bool buyPlayer(Player player, Club sellerClub) {
    lastTransferError = transferIssue(player, sellerClub, userClub);
    if (lastTransferError != null) return false;
    _completeTransfer(player, sellerClub, userClub);
    _news(
      NewsKind.transfer,
      '${player.name} jamoaga qo‘shildi',
      '${sellerClub.name}dan ${_m(transferFee(player))} evaziga. Shartnoma: 3 yil.',
    );
    notifyListeners();
    return true;
  }

  /// Negotiated bid: accepted at/above the asking price, countered when close.
  (NegotiationResult, int) bidForPlayer(Player p, Club seller, int fee) {
    final issue = transferIssue(p, seller, userClub, fee);
    if (issue != null) {
      lastTransferError = issue;
      return (NegotiationResult.blocked, fee);
    }
    final ask = askingPrice(p, seller);
    if (fee >= ask) {
      _completeTransfer(p, seller, userClub, fee);
      _news(
        NewsKind.transfer,
        '${p.name} jamoaga qo‘shildi',
        '${seller.name} ${_m(fee)} taklifni qabul qildi. Shartnoma: 3 yil.',
      );
      notifyListeners();
      return (NegotiationResult.accepted, fee);
    }
    if (fee >= ask * 0.85) {
      final counter = ((fee + ask) / 2 / 100000).round() * 100000;
      return (NegotiationResult.countered, max(counter, fee + 100000));
    }
    return (NegotiationResult.rejected, ask);
  }

  bool sellPlayer(Player player) {
    final buyers = _allClubs.where((c) => c.id != userClub.id).toList()
      ..sort((a, b) => b.transferBudget.compareTo(a.transferBudget));
    for (final buyer in buyers) {
      if (transferIssue(player, userClub, buyer) == null) {
        _completeTransfer(player, userClub, buyer);
        _news(
          NewsKind.transfer,
          '${player.name} sotildi',
          '${buyer.name} ${_m(transferFee(player))} to‘ladi.',
        );
        notifyListeners();
        return true;
      }
    }
    lastTransferError = 'Hozircha shartlarga mos xaridor yo‘q.';
    return false;
  }

  bool acceptOffer(TransferOffer o) {
    if (!offers.contains(o)) return false;
    final issue = transferIssue(o.player, userClub, o.buyer, o.fee);
    offers.remove(o);
    if (issue != null) {
      lastTransferError = issue;
      notifyListeners();
      return false;
    }
    _completeTransfer(o.player, userClub, o.buyer, o.fee);
    _news(
      NewsKind.transfer,
      '${o.player.name} ${o.buyer.name}ga sotildi',
      'Kelishuv summasi: ${_m(o.fee)}.',
    );
    notifyListeners();
    return true;
  }

  void rejectOffer(TransferOffer o) {
    offers.remove(o);
    o.player.morale = max(35, o.player.morale - 2);
    notifyListeners();
  }

  void _generateOffers() {
    final rnd = Random(_salt(_currentRound * 131 + calendar.year));
    offers.removeWhere((o) => !userClub.squad.contains(o.player));
    if (userClub.squad.length <= minSquad) return;
    final targets = List<Player>.of(userClub.squad)
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final count = rnd.nextInt(3);
    for (var i = 0; i < count; i++) {
      final p = targets[rnd.nextInt(min(10, targets.length))];
      if (offers.any((o) => o.player == p)) continue;
      final buyers = _allClubs
          .where((c) => c.id != _userClubId && c.transferBudget > p.marketValue)
          .toList();
      if (buyers.isEmpty) continue;
      final buyer = buyers[rnd.nextInt(buyers.length)];
      final fee = (p.marketValue * (0.9 + rnd.nextDouble() * 0.35) / 100000).round() * 100000;
      offers.add(TransferOffer(p, buyer, fee));
      _news(
        NewsKind.transfer,
        '${buyer.name} ${p.shortName} uchun taklif yubordi',
        '${_m(fee)} miqdoridagi taklif Transfer → Takliflar bo‘limida kutmoqda.',
      );
    }
  }

  void _simulateAITransfers() {
    final ai = _allClubs.where((c) => c.id != _userClubId).toList();
    final random = Random(_salt(_currentRound * 7919 + calendar.year));
    ai.shuffle(random);
    for (final buyer in ai.take(2)) {
      // Strengthen the weakest line of the XI.
      final weakest = [
        PositionCategory.defense,
        PositionCategory.midfield,
        PositionCategory.attack,
      ]..sort((a, b) {
          int r(PositionCategory c) => switch (c) {
            PositionCategory.defense => buyer.defenseRating,
            PositionCategory.midfield => buyer.midfieldRating,
            _ => buyer.attackRating,
          };
          return r(a).compareTo(r(b));
        });
      final candidates = <({Player player, Club seller})>[];
      for (final seller in ai.where((c) => c.id != buyer.id)) {
        for (final p in [...seller.bench, ...seller.reserves]) {
          if (p.mainPosition.category == weakest.first &&
              transferIssue(p, seller, buyer) == null) {
            candidates.add((player: p, seller: seller));
          }
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.player.ovr.compareTo(a.player.ovr));
        final target = candidates[random.nextInt(min(3, candidates.length))];
        _completeTransfer(target.player, target.seller, buyer);
      }
    }
  }

  /// Out-of-contract players can be signed at any time (as in real
  /// football); the club only pays a signing bonus of eight weeks' wages.
  String? freeAgentIssue(Player p) {
    final c = userClub;
    if (c.squad.length >= maxSquad) return 'Ro‘yxat to‘la: ko‘pi bilan $maxSquad futbolchi.';
    final wage = max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
    if (c.remainingWageBudget < wage) return 'Haftalik maosh limiti yetarli emas.';
    if (c.transferBudget < wage * 8) return 'Imzo bonusi uchun mablag‘ yetarli emas.';
    return null;
  }

  bool signFreeAgent(Player p) {
    lastTransferError = freeAgentIssue(p);
    if (lastTransferError != null || !freeAgents.contains(p)) return false;
    final wage = max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
    freeAgents.remove(p);
    p.contract = p.contract.copyWith(contractYears: p.age >= 32 ? 1 : 2, weeklyWage: wage);
    p.morale = 85;
    _post(userClub, '${p.shortName}: imzo bonusi', -wage * 8, category: FinanceCategory.agent);
    userClub.squad.add(p);
    if (userClub.benchIds.length < Club.matchdayBench) userClub.benchIds.add(p.id);
    transferHistory.insert(
      0,
      TransferRecord(_currentRound, p.name, 'Erkin agent', userClub.name, 0, date: currentDate),
    );
    _news(NewsKind.transfer, '${p.name} imzoladi', 'Erkin agent sifatida ${p.contract.contractYears} yillik shartnoma.');
    notifyListeners();
    return true;
  }

  void _seedFreeAgents() {
    final rnd = Random(_salt(calendar.year * 3 + 11));
    final pools = InitialDatabase.namePools;
    const positions = ['GK', 'CB', 'CB', 'LB', 'RB', 'DMF', 'CMF', 'AMF', 'LWF', 'RWF', 'CF', 'CF'];
    for (var i = 0; i < positions.length; i++) {
      final pool = pools[rnd.nextInt(pools.length)];
      final first = pool['firstNames'] as List, last = pool['lastNames'] as List;
      final name = '${first[rnd.nextInt(first.length)]} ${last[rnd.nextInt(last.length)]}';
      final pos = PlayerPosition.fromCode(positions[i]);
      final ovr = 68 + rnd.nextInt(10);
      final age = 27 + rnd.nextInt(8);
      freeAgents.add(Player(
        id: 'fa_${calendar.year}_$i',
        name: name,
        shortName: '${name.split(' ').first[0]}. ${name.split(' ').last}',
        age: age,
        nationality: pool['nationality'] as String,
        countryFlag: pool['flag'] as String,
        number: 40 + i,
        mainPosition: pos,
        altPositions: const [],
        preferredFoot: rnd.nextBool() ? PreferredFoot.right : PreferredFoot.left,
        weakFoot: 2 + rnd.nextInt(3),
        stats: _statsFor(pos, ovr, rnd),
        contract: PlayerContract(contractYears: 0, weeklyWage: max(15000, (ovr - 60) * 5000)),
        marketValue: Player.valuation(ovr, age, ovr),
      ));
    }
  }

  // ------------------------------------------------------ player creator
  /// Attribute template for a position at a target OVR (creator presets).
  static PlayerStats statsTemplate(PlayerPosition pos, int target, [int? seed]) =>
      _statsFor(pos, target, Random(seed));

  String? createdPlayerIssue() => userClub.squad.length >= maxSquad
      ? 'Ro‘yxat to‘la: ko‘pi bilan $maxSquad futbolchi. Avval kimnidir soting.'
      : null;

  /// Adds a player built from scratch to the user's club. A created player
  /// costs no fee but draws a normal weekly wage from the club.
  Player? addCreatedPlayer({
    required String name,
    required int age,
    required String nationality,
    required String countryFlag,
    required int number,
    required PlayerPosition position,
    required List<PlayerPosition> altPositions,
    required PreferredFoot foot,
    required int weakFoot,
    required PlayerStats stats,
    required int potential,
    required FaceConfig face,
    PlayingStyle? style,
    int contractYears = 3,
  }) {
    lastTransferError = createdPlayerIssue();
    if (lastTransferError != null) return null;
    final club = userClub;
    final used = club.squad.map((p) => p.number).toSet();
    var shirt = number.clamp(1, 99);
    while (used.contains(shirt)) {
      shirt = shirt % 99 + 1;
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    final short = parts.length > 1 ? '${parts.first[0]}. ${parts.sublist(1).join(' ')}' : parts.first;
    final draft = Player(
      id: 'own_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      shortName: short,
      age: age,
      nationality: nationality,
      countryFlag: countryFlag,
      number: shirt,
      mainPosition: position,
      altPositions: altPositions.where((p) => p != position).toList(),
      preferredFoot: foot,
      weakFoot: weakFoot,
      stats: stats,
      contract: const PlayerContract(contractYears: 3, weeklyWage: 10000),
      marketValue: 0,
      potential: potential,
      playingStyle: style,
      face: face,
    );
    draft.potential = max(draft.potential, draft.ovr);
    draft.marketValue = Player.valuation(draft.ovr, age, draft.potential);
    draft.contract = PlayerContract(
      contractYears: contractYears,
      weeklyWage: draft.calculatedRenewalWageDemand,
    );
    club.squad.add(draft);
    if (club.benchIds.length < Club.matchdayBench) club.benchIds.add(draft.id);
    _news(
      NewsKind.transfer,
      '${draft.name} jamoaga qo‘shildi',
      'Yangi futbolchi yaratildi: ${draft.mainPosition.code}, OVR ${draft.ovr}, salohiyat ${draft.potential}. '
          'Haftalik maosh ${_m(draft.contract.weeklyWage)}.',
    );
    notifyListeners();
    return draft;
  }

  bool renewContract(Player player, int years, int newWage) {
    if (!userClub.squad.any((p) => identical(p, player)) ||
        years < 1 ||
        years > 5 ||
        newWage < player.calculatedRenewalWageDemand ||
        userClub.remainingWageBudget + player.contract.weeklyWage < newWage) {
      return false;
    }
    player.contract = player.contract.copyWith(
      contractYears: years,
      weeklyWage: newWage,
    );
    player.morale = min(100, player.morale + 10);
    notifyListeners();
    return true;
  }

  // ------------------------------------------------------------ seasons
  void _closeSeason() {
    if (seasonFinished) return;
    seasonFinished = true;
    final table = sortedStandings;
    final champion = getClubById(table.first.clubId)!;
    final userPos = positionOf(_userClubId!);
    const prizes = [60, 48, 38, 30, 24, 19, 15, 12];
    for (var i = 0; i < table.length; i++) {
      final club = getClubById(table[i].clubId)!;
      _post(club, 'Liga mukofot puli · ${i + 1}-o‘rin',
          prizes[i.clamp(0, 7)] * 1000000,
          category: FinanceCategory.prize);
    }
    if (champion.id == _userClubId) _managerProfile.trophies++;
    final scorer = topScorers.firstOrNull;
    seasonHistory.add(
      SeasonSummary(
        seasonLabel,
        champion.name,
        userPos,
        standingOf(_userClubId!).points,
        scorer == null ? '—' : '${scorer.player.shortName} (${scorer.player.seasonGoals})',
      ),
    );
    final met = userPos <= objective.targetPosition;
    boardConfidence = (boardConfidence + (met ? 15 : -20)).clamp(5, 100);
    final style = ManagerPhilosophy.forStyle(userClub.tactics.playstyle);
    final bonus = (userPos == 1 ? 24 : userPos <= 3 ? 16 : 0) + (met ? 8 : 0);
    if (bonus > 0) _managerProfile.gainExperience(style, bonus);
    _news(
      NewsKind.award,
      champion.id == _userClubId ? 'CHEMPION! ${champion.name}' : '${champion.name} – chempion',
      'Mavsum $seasonLabel yakunlandi. ${userClub.name}: $userPos-o‘rin. '
          'Kengash maqsadi (${objective.title}) ${met ? 'bajarildi' : 'bajarilmadi'}.',
    );
    final best = topRated.firstOrNull;
    if (scorer != null || best != null) {
      _news(
        NewsKind.award,
        'Mavsum mukofotlari',
        '${scorer != null ? 'Oltin butsa: ${scorer.player.name} – ${scorer.player.seasonGoals} gol. ' : ''}'
            '${best != null ? 'Eng yuqori reyting: ${best.player.name} (${best.player.averageRating!.toStringAsFixed(2)}).' : ''}',
      );
    }
  }

  /// Ages the league, develops players, renews or releases contracts,
  /// adds academy graduates and builds a fresh fixture list.
  void startNextSeason() {
    if (!seasonFinished) return;
    final rnd = Random(_salt(calendar.year * 17));
    calendar = SeasonCalendar(calendar.year + 1);
    final released = <String>[];
    for (final club in _allClubs) {
      final user = club.id == _userClubId;
      for (final p in List<Player>.of(club.squad)) {
        p.history.insert(
          0,
          '${calendar.year - 1}/${calendar.year % 100}: ${p.seasonMatches} o‘yin, ${p.seasonGoals} gol, ${p.seasonAssists} assist'
          '${p.averageRating != null ? ', ${p.averageRating!.toStringAsFixed(2)}' : ''}',
        );
        _develop(p, rnd);
        p.resetSeasonStats();
        p.currentStamina = 100;
        p.injuryRounds = 0;
        p.injury = null;
        p.suspensionRounds = 0;
        final years = p.contract.contractYears - 1;
        if (p.age >= 37 && rnd.nextDouble() < 0.7) {
          _remove(club, p);
          if (user) released.add('${p.shortName} (faoliyatini yakunladi)');
          continue;
        }
        if (years <= 0) {
          if (user && club.squad.length > minSquad) {
            _remove(club, p);
            released.add(p.shortName);
            freeAgents.add(p);
            continue;
          }
          p.contract = p.contract.copyWith(
            contractYears: user ? 1 : 2 + rnd.nextInt(2),
            weeklyWage: max(p.contract.weeklyWage, p.calculatedRenewalWageDemand),
          );
        } else {
          p.contract = p.contract.copyWith(contractYears: years);
        }
      }
      for (var i = 0; i < 2; i++) {
        if (club.squad.length >= maxSquad) break;
        final youth = _youthProspect(club, rnd, i);
        club.squad.add(youth);
      }
      if (!user) {
        while (club.squad.length > 25) {
          final worst = List<Player>.of(club.squad)
            ..sort((a, b) => a.ovr.compareTo(b.ovr));
          _remove(club, worst.first);
          freeAgents.add(worst.first);
        }
      }
      _ensureMatchdaySquad(club);
      if (!user) autoPickLineup(club);
    }
    final u = userClub;
    if (u.startingXI.length < 11) autoPickLineup(u);
    _ensureMatchdaySquad(u);
    seasonFinished = false;
    offers.clear();
    _generateSeasonSchedule();
    _initializeStandings();
    _currentRound = 1;
    objective = _objectiveFor(u);
    _news(
      NewsKind.board,
      'Yangi mavsum: $seasonLabel',
      'Kengash maqsadi: ${objective.title}. Akademiyadan 2 ta yosh futbolchi asosiy jamoaga ko‘tarildi.'
          '${released.isNotEmpty ? ' Klubni tark etganlar: ${released.join(', ')}.' : ''}',
    );
    _news(
      NewsKind.window,
      'Yozgi transfer oynasi ochiq',
      'Oyna ${SeasonCalendar.format(calendar.summerClose)} gacha ishlaydi.',
    );
    balanceHistory
      ..clear()
      ..add(u.transferBudget);
    notifyListeners();
  }

  void _remove(Club club, Player p) {
    club.squad.remove(p);
    club.startingLineupIds.remove(p.id);
    club.benchIds.remove(p.id);
    if (club.startingLineupIds.length < 11) {
      final rest = club.squad
          .where((q) => !club.startingLineupIds.contains(q.id))
          .toList()
        ..sort((a, b) => b.ovr.compareTo(a.ovr));
      for (final q in rest) {
        if (club.startingLineupIds.length >= 11) break;
        club.startingLineupIds.add(q.id);
        club.benchIds.remove(q.id);
      }
    }
  }

  void _develop(Player p, Random rnd) {
    final before = p.ovr;
    p.age++;
    final minutes = p.seasonMinutes;
    final rating = p.averageRating ?? 6.6;
    int delta;
    if (p.age <= 21) {
      delta = 1 + rnd.nextInt(4) + (minutes > 700 ? 1 : 0) + (rating > 7.2 ? 1 : 0);
    } else if (p.age <= 24) {
      delta = rnd.nextInt(4) + (minutes > 900 ? 1 : 0);
    } else if (p.age <= 28) {
      delta = rnd.nextInt(3) - 1 + (rating > 7.3 ? 1 : 0);
    } else if (p.age <= 31) {
      delta = -rnd.nextInt(3);
    } else {
      delta = -1 - rnd.nextInt(3);
    }
    if (before + delta > p.potential) delta = max(0, p.potential - before);
    final m = p.stats.toMap().map((k, v) => MapEntry(k, v as int));
    const physical = {'speed', 'acceleration', 'stamina', 'jumping'};
    final keeper = p.mainPosition.isGoalkeeper;
    for (final k in m.keys.toList()) {
      final isGk = k.startsWith('gk');
      if (isGk != keeper && delta > 0) continue;
      var change = delta + (rnd.nextInt(3) - 1);
      if (p.age >= 30 && physical.contains(k)) change -= 1 + rnd.nextInt(2);
      m[k] = (m[k]! + change).clamp(40, 99);
    }
    p.stats = PlayerStats.fromMap(m);
    p.marketValue = Player.valuation(p.ovr, p.age, p.potential);
  }

  Player _youthProspect(Club club, Random rnd, int i) {
    final pools = InitialDatabase.namePools;
    final pool = pools[rnd.nextInt(pools.length)];
    final first = pool['firstNames'] as List, last = pool['lastNames'] as List;
    final name = '${first[rnd.nextInt(first.length)]} ${last[rnd.nextInt(last.length)]}';
    const positions = ['CB', 'CMF', 'CF', 'LWF', 'RB', 'DMF', 'AMF', 'GK'];
    final pos = PlayerPosition.fromCode(positions[rnd.nextInt(positions.length)]);
    final target = 58 + rnd.nextInt(9);
    final stats = _statsFor(pos, target, rnd);
    final used = club.squad.map((p) => p.number).toSet();
    var number = 30 + rnd.nextInt(40);
    while (used.contains(number)) {
      number++;
    }
    final id = '${club.id}_y${calendar.year}_$i';
    return Player(
      id: id,
      name: name,
      shortName: '${name.split(' ').first[0]}. ${name.split(' ').last}',
      age: 17 + rnd.nextInt(2),
      nationality: pool['nationality'] as String,
      countryFlag: pool['flag'] as String,
      number: number,
      mainPosition: pos,
      altPositions: const [],
      preferredFoot: rnd.nextInt(4) == 0 ? PreferredFoot.left : PreferredFoot.right,
      weakFoot: 2 + rnd.nextInt(3),
      stats: stats,
      contract: const PlayerContract(contractYears: 3, weeklyWage: 8000),
      marketValue: Player.valuation(target, 17, target + 18),
      potential: (target + 12 + rnd.nextInt(16)).clamp(70, 92),
    );
  }

  static PlayerStats _statsFor(PlayerPosition pos, int target, Random random) {
    int value(int bias) => (target + bias + random.nextInt(9) - 4).clamp(40, 99);
    final attributes = {for (final key in PlayerStats.labels.keys) key: value(-2)};
    void boost(List<String> keys, int bias) {
      for (final k in keys) {
        attributes[k] = value(bias);
      }
    }

    if (pos.isAttacker) {
      boost(['finishing', 'attackingAwareness', 'dribbling', 'speed', 'acceleration', 'ballControl'], 4);
      boost(['defensiveAwareness', 'defensiveEngagement', 'tackling'], -26);
    } else if (pos.isMidfielder) {
      boost(['lowPass', 'loftedPass', 'ballControl', 'tightPossession', 'stamina'], 4);
      boost(['finishing'], -8);
    } else if (pos.isDefender) {
      boost(['defensiveAwareness', 'defensiveEngagement', 'tackling', 'heading', 'physicalContact'], 5);
      boost(['finishing', 'dribbling'], -20);
    }
    for (final key in ['gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach']) {
      attributes[key] = pos.isGoalkeeper ? value(5) : 40;
    }
    if (pos.isGoalkeeper) {
      boost(['finishing', 'dribbling', 'speed', 'tackling', 'heading'], -28);
    }
    return PlayerStats.fromMap(attributes);
  }

  // ------------------------------------------------------- custom squad
  static List<Player> _generateCustomSquad(String prefix) {
    final random = Random();
    final used = <String>{};
    final pools = InitialDatabase.namePools;
    final templates = InitialDatabase.customSquadTemplates;
    return templates.asMap().entries.map((entry) {
      final idx = entry.key;
      final d = entry.value;
      final pool = pools[random.nextInt(pools.length)];
      final first = pool['firstNames'] as List;
      final last = pool['lastNames'] as List;
      String name;
      do {
        name = '${first[random.nextInt(first.length)]} ${last[random.nextInt(last.length)]}';
      } while (!used.add(name));
      // A brand-new club starts with an honest, average squad (≈64–73).
      final targetOvr = ((d['ovr'] as int) - 8 + random.nextInt(5) - 2).clamp(58, 74);
      final pos = PlayerPosition.fromCode(d['pos'] as String);
      final age = 19 + random.nextInt(14);
      return Player(
        id: '${prefix}_p$idx',
        name: name,
        shortName: '${name.split(' ').first[0]}. ${name.split(' ').last}',
        age: age,
        nationality: pool['nationality'] as String,
        countryFlag: pool['flag'] as String,
        number: d['num'] as int,
        mainPosition: pos,
        altPositions: const [],
        preferredFoot: idx % 3 == 0 ? PreferredFoot.left : PreferredFoot.right,
        weakFoot: 3 + (idx % 2),
        marketValue: Player.valuation(targetOvr, age, targetOvr + 4),
        contract: PlayerContract(
          contractYears: 2 + random.nextInt(3),
          weeklyWage: max(15000, (targetOvr - 60) * 4500),
        ),
        stats: _statsFor(pos, targetOvr, random),
      );
    }).toList();
  }

  /// Three random marquee signings a new club can choose from.
  static List<Player> starCandidates([int? seed]) {
    final random = Random(seed);
    final pools = InitialDatabase.namePools;
    const positions = ['CF', 'AMF', 'LWF', 'RWF', 'CMF', 'CB', 'GK', 'DMF'];
    final picked = (List.of(positions)..shuffle(random)).take(3).toList();
    return [
      for (var i = 0; i < picked.length; i++)
        () {
          final pool = pools[random.nextInt(pools.length)];
          final first = pool['firstNames'] as List, last = pool['lastNames'] as List;
          final name = '${first[random.nextInt(first.length)]} ${last[random.nextInt(last.length)]}';
          final pos = PlayerPosition.fromCode(picked[i]);
          final ovr = 85 + random.nextInt(4);
          final age = 23 + random.nextInt(7);
          return Player(
            id: 'star_$i',
            name: name,
            shortName: '${name.split(' ').first[0]}. ${name.split(' ').last}',
            age: age,
            nationality: pool['nationality'] as String,
            countryFlag: pool['flag'] as String,
            number: 10,
            mainPosition: pos,
            altPositions: const [],
            preferredFoot: random.nextBool() ? PreferredFoot.right : PreferredFoot.left,
            weakFoot: 3 + random.nextInt(2),
            stats: _statsFor(pos, ovr, random),
            contract: const PlayerContract(contractYears: 4, weeklyWage: 160000),
            marketValue: Player.valuation(ovr, age, ovr + 2),
          );
        }(),
    ];
  }

  // --------------------------------------------------------------- news
  void _news(NewsKind kind, String title, String body) {
    news.insert(0, NewsItem(date: currentDate, title: title, body: body, kind: kind));
    if (news.length > 80) news.removeLast();
  }

  void markNewsRead() {
    for (final n in news) {
      n.read = true;
    }
    notifyListeners();
  }

  void _roundNews(Fixture f) {
    if (!f.involves(_userClubId!)) return;
    final home = getClubById(f.homeClubId)!, away = getClubById(f.awayClubId)!;
    final r = f.resultFor(_userClubId!);
    final motm = f.motmId == null
        ? null
        : (home.playerById(f.motmId!) ?? away.playerById(f.motmId!));
    final verdict = r == 'W'
        ? 'G‘alaba!'
        : r == 'D'
        ? 'Durang'
        : 'Mag‘lubiyat';
    _news(
      NewsKind.match,
      '$verdict ${home.shortName} ${f.homeScore}–${f.awayScore} ${away.shortName}',
      '${f.round}-tur. xG ${f.homeXG.toStringAsFixed(2)} – ${f.awayXG.toStringAsFixed(2)}, '
          'to‘p nazorati ${f.homePossession}% – ${f.awayPossession}%.'
          '${motm != null ? ' O‘yin qahramoni: ${motm.name} (${f.ratings[motm.id]?.toStringAsFixed(1)}).' : ''}',
    );
  }

  static String _m(int v) => '€${(v / 1000000).toStringAsFixed(1)}M';

  // ------------------------------------------------------------ save/load
  static const saveVersion = 1;

  Map<String, dynamic> toSave() => {
    'v': saveVersion,
    'seed': careerSeed,
    'clubs': _allClubs.map(SaveCodec.club).toList(),
    'user': _userClubId,
    'round': _currentRound,
    'year': calendar.year,
    'finished': seasonFinished,
    'objective': [objective.title, objective.targetPosition],
    'board': boardConfidence,
    'manager': _managerProfile.toMap(),
    'standings': _standingsMap.values.map(SaveCodec.standing).toList(),
    'fixtures': _fixtures.map(SaveCodec.fixture).toList(),
    'ledger': ledger.map(SaveCodec.entry).toList(),
    'transfers': transferHistory.map(SaveCodec.transfer).toList(),
    'news': news.map(SaveCodec.news).toList(),
    'offers': [
      for (final o in offers) {'p': o.player.id, 'b': o.buyer.id, 'f': o.fee},
    ],
    'free': freeAgents.map(SaveCodec.player).toList(),
    'history': [
      for (final h in seasonHistory)
        [h.season, h.championName, h.userPosition, h.userPoints, h.topScorer],
    ],
    'balance': balanceHistory,
  };

  /// Restores a career written by [toSave]. Returns false for unknown data.
  bool restore(Map<String, dynamic> m) {
    if (m['v'] != saveVersion) return false;
    _allClubs = [for (final c in m['clubs'] as List) SaveCodec.clubFrom(Map<String, dynamic>.from(c))];
    _userClubId = m['user'];
    careerSeed = m['seed'] ?? careerSeed;
    _currentRound = m['round'];
    calendar = SeasonCalendar(m['year']);
    seasonFinished = m['finished'] ?? false;
    final o = m['objective'] as List;
    objective = BoardObjective(o[0], o[1]);
    boardConfidence = m['board'] ?? 70;
    _managerProfile = ManagerProfile.fromMap(Map<String, dynamic>.from(m['manager']));
    _standingsMap = {
      for (final raw in m['standings'] as List)
        (raw as Map)['c'] as String: SaveCodec.standingFrom(Map<String, dynamic>.from(raw)),
    };
    _fixtures = [for (final f in m['fixtures'] as List) SaveCodec.fixtureFrom(Map<String, dynamic>.from(f))];
    ledger
      ..clear()
      ..addAll([for (final e in m['ledger'] as List) SaveCodec.entryFrom(Map<String, dynamic>.from(e))]);
    transferHistory
      ..clear()
      ..addAll([for (final e in m['transfers'] as List) SaveCodec.transferFrom(Map<String, dynamic>.from(e))]);
    news
      ..clear()
      ..addAll([for (final e in m['news'] as List) SaveCodec.newsFrom(Map<String, dynamic>.from(e))]);
    freeAgents
      ..clear()
      ..addAll([for (final e in m['free'] as List? ?? []) SaveCodec.playerFrom(Map<String, dynamic>.from(e))]);
    offers.clear();
    for (final raw in m['offers'] as List? ?? []) {
      final buyer = getClubById(raw['b']);
      final player = userClub.playerById(raw['p']);
      if (buyer != null && player != null) offers.add(TransferOffer(player, buyer, raw['f']));
    }
    seasonHistory
      ..clear()
      ..addAll([
        for (final h in m['history'] as List? ?? [])
          SeasonSummary(h[0], h[1], h[2], h[3], h[4]),
      ]);
    balanceHistory
      ..clear()
      ..addAll([for (final v in m['balance'] as List? ?? []) (v as num).toInt()]);
    lastTransferError = null;
    _isInitialized = true;
    notifyListeners();
    return true;
  }
}
