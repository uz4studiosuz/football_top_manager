import 'dart:math';
import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';
import '../models/manager_profile.dart';
import '../models/finance.dart';
import 'match_field.dart';

/// Yetakchi futbolchilar reytingi modeli
class PlayerLeaderboardEntry {
  final Player player;
  final Club club;
  const PlayerLeaderboardEntry({required this.player, required this.club});
}

/// Barcha o'yin ma'lumotlari, liga taqvimi, byudjet va natijalarni boshqaruvchi State Manager
class GameState extends ChangeNotifier {
  static final GameState _instance = GameState._internal();
  factory GameState() => _instance;
  GameState._internal();
  List<Club> _allClubs = [];
  String? _userClubId;
  List<Fixture> _fixtures = [];
  Map<String, LeagueStanding> _standingsMap = {};
  int _currentRound = 1;
  bool _isInitialized = false;
  final List<FinanceEntry> ledger = [];
  final List<TransferRecord> transferHistory = [];
  String? lastTransferError;
  bool get isTransferWindowOpen =>
      _currentRound <= 3 || (_currentRound >= 8 && _currentRound <= 9);
  String get transferWindowLabel => isTransferWindowOpen
      ? 'Transfer oynasi ochiq'
      : 'Transfer oynasi yopiq • 8-turda ochiladi';
  void _post(Club club, String label, int amount) {
    club.transferBudget += amount;
    ledger.add(FinanceEntry(_currentRound, club.id, label, amount));
  }

  void _resetRecords() {
    ledger.clear();
    transferHistory.clear();
    lastTransferError = null;
  }

  // Murabbiy profili
  ManagerProfile _managerProfile = ManagerProfile(
    name: 'Azizbek Rahimov',
    avatarId: 'suit_dark',
    nationality: 'O‘zbekiston',
    countryFlag: '🇺🇿',
    age: 42,
    philosophy: ManagerPhilosophy.possession,
  );
  // Getters
  bool get isInitialized => _isInitialized;
  List<Club> get allClubs => _allClubs;
  String? get userClubId => _userClubId;
  int get currentRound => _currentRound;
  List<Fixture> get fixtures => _fixtures;
  ManagerProfile get managerProfile => _managerProfile;
  void updateManagerProfile(ManagerProfile profile) {
    _managerProfile = profile;
    notifyListeners();
  }

  Club get userClub {
    return _allClubs.firstWhere(
      (c) => c.id == _userClubId,
      orElse: () => _allClubs.first,
    );
  }

  Club? getClubById(String id) {
    try {
      return _allClubs.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Turnir jadvali (ochkolar, to'plar nisbati bo'yicha saralangan)
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

  /// Liga bo'yicha to'purarlar ro'yxati (Golden Boot)
  List<PlayerLeaderboardEntry> get topScorers {
    final list = <PlayerLeaderboardEntry>[];
    for (final club in _allClubs) {
      for (final player in club.squad) {
        if (player.seasonGoals > 0) {
          list.add(PlayerLeaderboardEntry(player: player, club: club));
        }
      }
    }
    list.sort((a, b) {
      if (b.player.seasonGoals != a.player.seasonGoals) {
        return b.player.seasonGoals.compareTo(a.player.seasonGoals);
      }
      return b.player.seasonAssists.compareTo(a.player.seasonAssists);
    });
    return list;
  }

  /// Liga bo'yicha eng yaxshi assistentlar ro'yxati
  List<PlayerLeaderboardEntry> get topAssists {
    final list = <PlayerLeaderboardEntry>[];
    for (final club in _allClubs) {
      for (final player in club.squad) {
        if (player.seasonAssists > 0) {
          list.add(PlayerLeaderboardEntry(player: player, club: club));
        }
      }
    }
    list.sort(
      (a, b) => b.player.seasonAssists.compareTo(a.player.seasonAssists),
    );
    return list;
  }

  /// Liga bo'yicha quruq o'yinlar (Clean sheets)
  List<PlayerLeaderboardEntry> get topCleanSheets {
    final list = <PlayerLeaderboardEntry>[];
    for (final club in _allClubs) {
      for (final player in club.squad) {
        if (player.mainPosition.isGoalkeeper && player.seasonCleanSheets > 0) {
          list.add(PlayerLeaderboardEntry(player: player, club: club));
        }
      }
    }
    list.sort(
      (a, b) =>
          b.player.seasonCleanSheets.compareTo(a.player.seasonCleanSheets),
    );
    return list;
  }

  /// Foydalanuvchi jamoasining joriy turdagi o'yini
  Fixture? get nextUserFixture {
    try {
      return _fixtures.firstWhere(
        (f) =>
            f.round == _currentRound &&
            !f.isPlayed &&
            (f.homeClubId == _userClubId || f.awayClubId == _userClubId),
      );
    } catch (_) {
      return null;
    }
  }

  /// Joriy turdagi barcha o'yinlar
  List<Fixture> get currentRoundFixtures {
    return _fixtures.where((f) => f.round == _currentRound).toList();
  }

  // ===========================================================================
  // 1. O'YINNI BOSHLASH / KLUB TANLASH YOKI YARATISH
  // ===========================================================================
  /// Karyerani to'liq tozalash / yangidan boshlash
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

  /// Mavjud 8 ta top klubdan birini tanlab karyera boshlash
  void startCareerWithExistingClub(
    Club selectedClub, {
    ManagerProfile? managerProfile,
  }) {
    if (managerProfile != null) {
      _managerProfile = managerProfile;
    }
    _resetRecords();
    _allClubs = InitialDatabase.getSuperLeagueClubs();
    _userClubId = selectedClub.id;
    _generateSeasonSchedule();
    _initializeStandings();
    _currentRound = 1;
    _isInitialized = true;
    notifyListeners();
  }

  /// O'zining yangi klubini yaratib karyera boshlash
  void startCareerWithCustomClub({
    required String name,
    required String shortName,
    required String stadiumName,
    required int stadiumCapacity,
    required ClubCrestConfig crestConfig,
    ManagerProfile? managerProfile,
  }) {
    if (managerProfile != null) {
      _managerProfile = managerProfile;
    }
    // 8 ta klubning oxirgisini almashtiramiz yoki o'rniga qo'shamiz
    final baseClubs = InitialDatabase.getSuperLeagueClubs();
    final customClubId = 'custom_${DateTime.now().millisecondsSinceEpoch}';
    final generatedSquad = _generateCustomSquad(customClubId);
    final customClub = Club(
      id: customClubId,
      name: name,
      shortName: shortName.toUpperCase(),
      primaryColor: crestConfig.primaryColor,
      secondaryColor: crestConfig.secondaryColor,
      accentColor: crestConfig.trimColor,
      stadiumName: stadiumName,
      stadiumCapacity: stadiumCapacity,
      transferBudget: 80000000, // €80.0M start
      wageBudget: 2500000, // €2.5M/hafta
      tactics: const TeamTactics(
        formation: FormationType.f433,
        playstyle: TeamPlaystyle.possession,
        defensiveLine: 3,
        attackingIntensity: 3,
      ),
      crestConfig: crestConfig,
      squad: generatedSquad,
      startingLineupIds: generatedSquad.take(11).map((p) => p.id).toList(),
      benchIds: generatedSquad.skip(11).map((p) => p.id).toList(),
    );
    // 8-klub o'rniga joylashtiramiz (8 ta jamoa ligasi saqlanadi)
    _resetRecords();
    _allClubs = [...baseClubs.take(7), customClub];
    _userClubId = customClubId;
    _generateSeasonSchedule();
    _initializeStandings();
    _currentRound = 1;
    _isInitialized = true;
    notifyListeners();
  }

  void _initializeStandings() {
    _standingsMap = {};
    for (final club in _allClubs) {
      _standingsMap[club.id] = LeagueStanding(clubId: club.id);
    }
  }

  /// 8 ta klub uchun 14 turdan iborat to'liq taqvim (Berger tizimi)
  void _generateSeasonSchedule() {
    _fixtures = [];
    final n = _allClubs.length; // 8
    final clubIds = _allClubs.map((c) => c.id).toList();
    for (int r = 0; r < n - 1; r++) {
      // 1-davra (1.0.7 tur)
      for (int i = 0; i < n ~/ 2; i++) {
        final home = clubIds[i];
        final away = clubIds[n - 1 - i];
        _fixtures.add(
          Fixture(
            id: 'fix_r${r + 1}_$i',
            round: r + 1,
            homeClubId: (r % 2 == 0) ? home : away,
            awayClubId: (r % 2 == 0) ? away : home,
          ),
        );
      }
      // Rotate list except first
      final last = clubIds.removeLast();
      clubIds.insert(1, last);
    }
    // 2-davra (8.0.14 tur - mehmonda o'ynaladi)
    final firstHalfFixtures = List<Fixture>.from(_fixtures);
    for (final f in firstHalfFixtures) {
      _fixtures.add(
        Fixture(
          id: 'fix_r${f.round + 7}_${f.id}',
          round: f.round + 7,
          homeClubId: f.awayClubId, // Joylar almashadi
          awayClubId: f.homeClubId,
        ),
      );
    }
  }

  // ===========================================================================
  // 2. TAKTIKA VA TARKIB BOSHQARUVI
  // ===========================================================================
  void updateTactics(TeamTactics newTactics) {
    userClub.tactics = newTactics;
    notifyListeners();
  }

  /// Asosiy tarkibdagi o'yinchini zaxiradagi bilan almashtirish (Swap)
  bool swapPlayer(String firstId, String secondId) {
    final club = userClub;
    if (firstId == secondId ||
        !club.squad.any((p) => p.id == firstId) ||
        !club.squad.any((p) => p.id == secondId)) {
      return false;
    }
    final a = club.startingLineupIds.indexOf(firstId),
        b = club.startingLineupIds.indexOf(secondId);
    if (a >= 0 && b >= 0) {
      club.startingLineupIds[a] = secondId;
      club.startingLineupIds[b] = firstId;
    } else if (a < 0 && b < 0) {
      final x = club.benchIds.indexOf(firstId),
          y = club.benchIds.indexOf(secondId);
      if (x < 0 || y < 0) return false;
      club.benchIds[x] = secondId;
      club.benchIds[y] = firstId;
    } else {
      final starter = a >= 0 ? firstId : secondId,
          bench = a >= 0 ? secondId : firstId;
      final slot = club.startingLineupIds.indexOf(starter),
          reserve = club.benchIds.indexOf(bench);
      if (reserve < 0) return false;
      club.startingLineupIds[slot] = bench;
      club.benchIds[reserve] = starter;
    }
    notifyListeners();
    return true;
  }

  void setPlayerInstruction(Player p, PlayerInstruction instruction) {
    if (userClub.squad.contains(p)) {
      p.instruction = instruction;
      notifyListeners();
    }
  }

  // ===========================================================================
  // 3. MATCH ENGINE VA SIMULYATSIYA
  // ===========================================================================
  /// Bitta o'yin natijasini hisoblash va hodisalarni generatsiya qilish
  void finishMatch({
    required Fixture fixture,
    required int homeScore,
    required int awayScore,
    required List<MatchEvent> events,
    Set<String>? participantIds,
  }) {
    if (fixture.isPlayed) return;
    fixture.homeScore = homeScore;
    fixture.awayScore = awayScore;
    fixture.isPlayed = true;
    fixture.events = events;
    final homeClub = getClubById(fixture.homeClubId);
    final awayClub = getClubById(fixture.awayClubId);
    // Turnir jadvaliga yozish
    _standingsMap[fixture.homeClubId]?.recordMatch(
      myGoals: homeScore,
      opponentGoals: awayScore,
    );
    _standingsMap[fixture.awayClubId]?.recordMatch(
      myGoals: awayScore,
      opponentGoals: homeScore,
    );
    // Murabbiy natijalarini hisobga olish
    _managerProfile.matchesManaged++;
    if (_managerProfile.matchesManaged % 5 == 0) {
      final style = ManagerPhilosophy.forStyle(userClub.tactics.playstyle);
      _managerProfile.proficiency[style] = min(
        100,
        (_managerProfile.proficiency[style] ?? 70) + 1,
      );
    }
    final isUserHome = fixture.homeClubId == _userClubId;
    final userScore = isUserHome ? homeScore : awayScore;
    final oppScore = isUserHome ? awayScore : homeScore;
    if (userScore > oppScore) {
      _managerProfile.wins++;
    } else if (userScore == oppScore) {
      _managerProfile.draws++;
    } else {
      _managerProfile.losses++;
    }
    // O'yinchilarning individual statistikasini yangilash
    if (homeClub != null) {
      for (final p in homeClub.squad.where(
        (p) =>
            participantIds?.contains(p.id) ??
            homeClub.startingLineupIds.contains(p.id),
      )) {
        p.seasonMatches++;
      }
      if (awayScore == 0) {
        final gk = homeClub.startingXI.firstWhere(
          (p) => p.mainPosition.isGoalkeeper,
          orElse: () => homeClub.startingXI.first,
        );
        gk.seasonCleanSheets++;
      }
    }
    if (awayClub != null) {
      for (final p in awayClub.squad.where(
        (p) =>
            participantIds?.contains(p.id) ??
            awayClub.startingLineupIds.contains(p.id),
      )) {
        p.seasonMatches++;
      }
      if (homeScore == 0) {
        final gk = awayClub.startingXI.firstWhere(
          (p) => p.mainPosition.isGoalkeeper,
          orElse: () => awayClub.startingXI.first,
        );
        gk.seasonCleanSheets++;
      }
    }
    // Voqealardan gol urganlar va assistentlarni yozib olish
    for (final ev in events) {
      if (ev.type == MatchEventType.goal && ev.playerName != null) {
        final scoringClub = (ev.clubId == homeClub?.id) ? homeClub : awayClub;
        final scorer = scoringClub?.squad.firstWhere(
          (p) => p.name == ev.playerName || p.shortName == ev.playerName,
          orElse: () => scoringClub.squad.first,
        );
        if (scorer != null) {
          scorer.seasonGoals++;
        }
      }
    }
    for (final event in events) {
      final club = getClubById(event.clubId);
      final player = club?.squad
          .where(
            (p) =>
                p.name == event.playerName || p.shortName == event.playerName,
          )
          .firstOrNull;
      if (event.type == MatchEventType.yellowCard) player?.seasonYellowCards++;
      if (event.type == MatchEventType.redCard) player?.seasonRedCards++;
      if (event.assistPlayerId != null) {
        final assister = club?.squad
            .where((p) => p.id == event.assistPlayerId)
            .firstOrNull;
        assister?.seasonAssists++;
      }
    }
    // AI o'yinlarini ham simulyatsiya qilish
    _simulateOtherMatchesInRound(_currentRound, fixture.id);
    // Moliyaviy hisob-kitob (chipta tushumi, g'alaba mukofoti, maosh)
    _applyMatchEconomics(fixture);
    notifyListeners();
  }

  /// Foydalanuvchining o'yinidan tashqari ayni turdagi boshqa o'yinlarni simulyatsiya qilish
  void _simulateOtherMatchesInRound(int round, String userFixtureId) {
    for (final f in _fixtures.where(
      (f) => f.round == round && f.id != userFixtureId && !f.isPlayed,
    )) {
      final home = getClubById(f.homeClubId)!,
          away = getClubById(f.awayClubId)!;
      final engine = MatchField(
        home,
        away,
        seed: f.id.codeUnits.fold<int>(
          round,
          (a, b) => (a * 31 + b) & 0x7fffffff,
        ),
      );
      var halftime = false;
      while (engine.time < 90 - 0.000001) {
        final limit = halftime ? 90.0 : 45.0;
        engine.update(min(1 / 30, limit - engine.time), {});
        if (!halftime && engine.time >= 45 - 0.000001) {
          halftime = true;
          engine.restart(false);
        }
      }
      final h = engine.homeStats, a = engine.awayStats;
      f.homeScore = h.goals;
      f.awayScore = a.goals;
      f.homeShots = h.shots;
      f.awayShots = a.shots;
      f.homeShotsOnTarget = h.onTarget;
      f.awayShotsOnTarget = a.onTarget;
      f.homeXG = h.xg;
      f.awayXG = a.xg;
      f.homePossession = engine.homePossessionPercent;
      f.awayPossession = 100 - f.homePossession;
      f.homeCorners = h.corners;
      f.awayCorners = a.corners;
      f.homeFouls = h.fouls;
      f.awayFouls = a.fouls;
      f.homePasses = h.passes;
      f.awayPasses = a.passes;
      f.homeCompletedPasses = h.completedPasses;
      f.awayCompletedPasses = a.completedPasses;
      f.events = List.of(engine.events);
      f.isPlayed = true;
      for (final club in [home, away]) {
        for (final p in club.startingXI) {
          p.seasonMatches++;
        }
        if ((club == home ? a.goals : h.goals) == 0) {
          club.startingXI
              .where((p) => p.mainPosition.isGoalkeeper)
              .firstOrNull
              ?.seasonCleanSheets++;
        }
      }
      for (final event in engine.events) {
        final club = getClubById(event.clubId)!;
        final p = club.squad
            .where((p) => p.name == event.playerName)
            .firstOrNull;
        if (event.type == MatchEventType.goal) {
          p?.seasonGoals++;
          club.squad
              .where((p) => p.id == event.assistPlayerId)
              .firstOrNull
              ?.seasonAssists++;
        }
        if (event.type == MatchEventType.yellowCard) p?.seasonYellowCards++;
        if (event.type == MatchEventType.redCard) p?.seasonRedCards++;
      }
      _standingsMap[home.id]?.recordMatch(
        myGoals: h.goals,
        opponentGoals: a.goals,
      );
      _standingsMap[away.id]?.recordMatch(
        myGoals: a.goals,
        opponentGoals: h.goals,
      );
    }
  }

  void _applyMatchEconomics(Fixture fixture) {
    for (final club in _allClubs) {
      final clubFixture = _fixtures
          .where(
            (f) =>
                f.round == _currentRound &&
                (f.homeClubId == club.id || f.awayClubId == club.id),
          )
          .firstOrNull;
      if (clubFixture == null || !clubFixture.isPlayed) continue;
      if (clubFixture.homeClubId == club.id) {
        final attendance = (club.stadiumCapacity * (0.78 + club.teamOVR / 700))
            .round()
            .clamp(0, club.stadiumCapacity);
        _post(club, 'Chipta va stadion tushumi', attendance * 35);
        _post(
          club,
          'Stadion va uchrashuv xarajatlari',
          -(attendance * 8 + 120000),
        );
      }
      _post(club, 'Homiy va teletranslyatsiya', 1250000);
      _post(club, 'Haftalik futbolchi maoshlari', -club.totalWeeklyWages);
      _post(club, 'Akademiya va klub xarajatlari', -175000);
      for (final p in club.squad) {
        p.morale = (p.morale + (club.startingLineupIds.contains(p.id) ? 1 : -1))
            .clamp(30, 100);
      }
    }
  }

  void nextRound() {
    if (_currentRound >= 14 || currentRoundFixtures.any((f) => !f.isPlayed)) {
      return;
    }
    _currentRound++;
    for (final club in _allClubs) {
      for (final p in club.squad) {
        p.currentStamina = min(100, p.currentStamina + 22);
      }
    }
    _simulateAITransfers();
    notifyListeners();
  }

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

  int offeredWage(Player p) =>
      max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
  int signingCost(Player p) =>
      (transferFee(p) * 0.03).round() + offeredWage(p) * 4;
  String? transferIssue(Player player, Club seller, Club buyer) {
    if (!isTransferWindowOpen) {
      return 'Transfer oynasi yopiq. 1–3 va 8–9-turlarda transfer mumkin.';
    }
    if (seller.id == buyer.id ||
        !seller.squad.any((p) => p.id == player.id) ||
        buyer.squad.any((p) => p.id == player.id)) {
      return 'Futbolchi bu transfer uchun mavjud emas.';
    }
    if (seller.squad.length <= 14) {
      return 'Sotuvchi klub kamida 14 futbolchini saqlashi kerak.';
    }
    if (player.mainPosition.isGoalkeeper &&
        seller.squad.where((p) => p.mainPosition.isGoalkeeper).length <= 1) {
      return 'Klub yagona darvozabonini sotmaydi.';
    }
    if (buyer.squad.length >= 25) {
      return 'Ro‘yxat to‘la: ko‘pi bilan 25 futbolchi.';
    }
    if (buyer.transferBudget < transferFee(player) + signingCost(player)) {
      return 'Transfer, agent va imzo xarajatlari uchun mablag‘ yetarli emas.';
    }
    if (buyer.remainingWageBudget < offeredWage(player)) {
      return 'Haftalik maosh limiti yetarli emas.';
    }
    return null;
  }

  void _completeTransfer(Player p, Club seller, Club buyer) {
    final fee = transferFee(p);
    final costs = signingCost(p);
    _post(buyer, '${p.shortName}: transfer', -fee);
    _post(buyer, '${p.shortName}: agent va imzo', -costs);
    _post(seller, '${p.shortName}: transfer tushumi', fee);
    seller.squad.removeWhere((q) => q.id == p.id);
    final starterIndex = seller.startingLineupIds.indexOf(p.id);
    seller.startingLineupIds.remove(p.id);
    seller.benchIds.remove(p.id);
    if (starterIndex >= 0) {
      final candidates = seller.bench
        ..sort(
          (a, b) => b
              .getEffectiveOVR(p.mainPosition)
              .compareTo(a.getEffectiveOVR(p.mainPosition)),
        );
      if (candidates.isNotEmpty) {
        seller.startingLineupIds.insert(starterIndex, candidates.first.id);
        seller.benchIds.remove(candidates.first.id);
      }
    }
    p.contract = p.contract.copyWith(
      contractYears: 3,
      weeklyWage: offeredWage(p),
    );
    buyer.squad.add(p);
    buyer.benchIds.add(p.id);
    transferHistory.insert(
      0,
      TransferRecord(_currentRound, p.name, seller.name, buyer.name, fee),
    );
  }

  bool buyPlayer(Player player, Club sellerClub) {
    lastTransferError = transferIssue(player, sellerClub, userClub);
    if (lastTransferError != null) return false;
    _completeTransfer(player, sellerClub, userClub);
    notifyListeners();
    return true;
  }

  bool sellPlayer(Player player) {
    for (final buyer in _allClubs.where((c) => c.id != userClub.id)) {
      if (transferIssue(player, userClub, buyer) == null) {
        _completeTransfer(player, userClub, buyer);
        notifyListeners();
        return true;
      }
    }
    lastTransferError = 'Hozircha shartlarga mos xaridor yo‘q.';
    return false;
  }

  void _simulateAITransfers() {
    if (!isTransferWindowOpen) return;
    final ai = _allClubs.where((c) => c.id != _userClubId).toList();
    final random = Random(_currentRound * 7919);
    ai.shuffle(random);
    for (final buyer in ai.take(2)) {
      final candidates = <({Player player, Club seller})>[];
      for (final seller in ai.where((c) => c.id != buyer.id)) {
        for (final p in seller.bench) {
          if (transferIssue(p, seller, buyer) == null) {
            candidates.add((player: p, seller: seller));
          }
        }
      }
      if (candidates.isNotEmpty) {
        final target = candidates[random.nextInt(candidates.length)];
        _completeTransfer(target.player, target.seller, buyer);
      }
    }
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

  // ===========================================================================
  // 5. YASAMA SQUAD GENERATORI (CUSTOM CLUB UCHUN)
  // ===========================================================================
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
        name =
            '${first[random.nextInt(first.length)]} ${last[random.nextInt(last.length)]}';
      } while (!used.add(name));
      final targetOvr = (d['ovr'] as int) + random.nextInt(7) - 3;
      final pos = PlayerPosition.fromCode(d['pos'] as String);
      int value(int bias) =>
          (targetOvr + bias + random.nextInt(9) - 4).clamp(40, 100);
      final attributes = {
        for (final key in PlayerStats.labels.keys) key: value(0),
      };
      if (pos.isAttacker) {
        for (final key in [
          'finishing',
          'attackingAwareness',
          'dribbling',
          'speed',
        ]) {
          attributes[key] = value(5);
        }
        for (final key in [
          'defensiveAwareness',
          'defensiveEngagement',
          'tackling',
        ]) {
          attributes[key] = value(-24);
        }
      }
      if (pos.isDefender) {
        for (final key in [
          'defensiveAwareness',
          'defensiveEngagement',
          'tackling',
          'heading',
        ]) {
          attributes[key] = value(5);
        }
        attributes['finishing'] = value(-20);
      }
      for (final key in [
        'gkAwareness',
        'gkCatching',
        'gkParrying',
        'gkReflexes',
        'gkReach',
      ]) {
        attributes[key] = pos.isGoalkeeper ? value(5) : 40;
      }
      final stats = PlayerStats.fromMap(attributes);
      return Player(
        id: '${prefix}_p$idx',
        name: name,
        shortName: '${name.split(' ').first[0]}. ${name.split(' ').last}',
        age: 21 + (idx % 10),
        nationality: pool['nationality'] as String,
        countryFlag: pool['flag'] as String,
        number: d['num'] as int,
        mainPosition: pos,
        altPositions: [],
        preferredFoot: (idx % 3 == 0)
            ? PreferredFoot.left
            : PreferredFoot.right,
        weakFoot: 3 + (idx % 2),
        marketValue: targetOvr * 350000,
        contract: const PlayerContract(contractYears: 3, weeklyWage: 45000),
        stats: stats,
      );
    }).toList();
  }
}
