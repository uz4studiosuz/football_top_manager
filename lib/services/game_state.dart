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
import 'press.dart';
import 'world.dart';
import 'save_codec.dart';
import '../models/transfer_deal.dart';
import 'division.dart';
import 'lineup_solver.dart';
import 'season_calendar.dart';
import 'coin_wallet.dart';
import 'club_life.dart';
import 'cup.dart';
import '../l10n/l10n.dart';

/// Yetakchi futbolchilar reytingi modeli
class PlayerLeaderboardEntry {
  final Player player;
  final Club club;
  const PlayerLeaderboardEntry({required this.player, required this.club});
}

/// The board's season goal. [key] is the Uzbek text (with {0} for [arg]),
/// translated whenever it is shown, so switching language updates it.
class BoardObjective {
  final String key;
  final int targetPosition;
  final Object? arg;
  const BoardObjective(this.key, this.targetPosition, [this.arg]);
  String get title => arg == null ? tr(key) : trf(key, [arg]);
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

  /// Double round robin: 14 rounds for 8 clubs, 38 for 20.
  int get totalRounds => _allClubs.length < 2 ? 14 : (_allClubs.length - 1) * 2;
  String leagueId = 'super';
  String get leagueName => InitialDatabase.leagueName(leagueId);
  int get clubCount => _allClubs.length;
  LeagueInfo get leagueInfo => InitialDatabase.info(leagueId);

  /// Other leagues of the pyramid (e.g. Championship and League One while
  /// managing in the Premier League), simulated in the background.
  final Map<String, Division> divisions = {};

  /// Promotions and relegations decided when the season ends (club id →
  /// new league id); applied when the next season starts.
  final Map<String, String> pendingMoves = {};

  /// The career's own leagues: this league plus the pyramid.
  List<Club> get domesticClubs => [
    ..._allClubs,
    for (final d in divisions.values) ...d.clubs,
  ];

  /// Every club the user can trade with: the pyramid plus the countries the
  /// scouts have opened.
  List<Club> get marketClubs => [...domesticClubs, ...world.clubs];

  /// The rest of the football world (scouted countries as a market).
  final WorldMarket world = WorldMarket();

  String leagueOfClub(String clubId) {
    if (_allClubs.any((c) => c.id == clubId)) return leagueId;
    for (final d in divisions.values) {
      if (d.clubs.any((c) => c.id == clubId)) return d.id;
    }
    return world.leagueOf(clubId) ?? leagueId;
  }

  /// Whether [c] is a foreign club from the scouted world market.
  bool isWorldClub(Club c) => world.club(c.id) != null;

  /// Country of a club's league.
  String countryOfClub(String clubId) => InitialDatabase.info(leagueOfClub(clubId)).country;

  double _economyOf(Club c) => InitialDatabase.info(leagueOfClub(c.id)).economy;
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
  /// Open and recently finished transfer negotiations involving the user.
  final List<TransferDeal> deals = [];

  /// The user's players on the transfer list (attract more offers).
  final Set<String> transferListed = {};

  /// Bids from other clubs waiting for the user's answer.
  List<TransferDeal> get offers =>
      deals.where((d) => d.stage == DealStage.offerReceived).toList();

  /// Deals where the next move is the user's.
  List<TransferDeal> get dealsNeedingAction =>
      deals.where((d) => d.stage.waitsForUser).toList();
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
      return trf('Transfer oynasi ochiq · {0} gacha', [SeasonCalendar.format(close)]);
    }
    final next = currentDate.isBefore(calendar.winterOpen)
        ? calendar.winterOpen
        : DateTime(calendar.year + 1, 6, 16);
    return trf('Transfer oynasi yopiq · {0} da ochiladi', [SeasonCalendar.format(next)]);
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
      _allClubs.where((c) => c.id == id).firstOrNull ??
      divisions.values.map((d) => d.club(id)).nonNulls.firstOrNull ??
      world.club(id);

  Club? clubOfPlayer(Player p) =>
      marketClubs.where((c) => c.squad.contains(p)).firstOrNull;

  List<LeagueStanding> get sortedStandings => sortStandings(_standingsMap.values);

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

  /// Facilities, training, academy, fans, press and the club's history.
  final ClubLife life = ClubLife();

  /// This season's domestic cup and the user's cup matches (for reports).
  Cup? cup;
  final List<Fixture> cupFixtures = [];
  Fixture? _openCupFixture;

  String get cupName => trf('{0} kubogi', [leagueName]);

  bool isCupFixture(Fixture f) => f.id.startsWith('cup_');

  /// Knockout matches (cup and Super Cup) end in penalties when drawn.
  bool isKnockout(Fixture f) => isCupFixture(f) || f.id.startsWith('super_');

  /// Season opener between last season's champion and the cup winner.
  Fixture? superCup;
  (int, int)? superPens;

  Fixture? get pendingSuperCup {
    final f = superCup;
    if (f == null || f.isPlayed || _userClubId == null || _currentRound != 1 || !f.involves(_userClubId!)) return null;
    return f;
  }

  void _finishSuperCup(Fixture f, int homeScore, int awayScore, List<MatchEvent> events, MatchField? engine, (int, int)? penalties) {
    if (engine != null) {
      engine.writeTo(f);
      if (f.involves(_userClubId!)) _applyEngine(f, engine);
    } else {
      f.events = events;
    }
    f
      ..homeScore = homeScore
      ..awayScore = awayScore
      ..isPlayed = true;
    if (homeScore == awayScore) {
      superPens = penalties ?? _autoShootout(getClubById(f.homeClubId)!, getClubById(f.awayClubId)!, Random(_salt(f.id.hashCode)));
    }
    final homeWon = homeScore > awayScore || (homeScore == awayScore && superPens!.$1 > superPens!.$2);
    final winner = getClubById(homeWon ? f.homeClubId : f.awayClubId)!;
    if (f.involves(_userClubId!)) {
      _recordManagerResult(f);
      _restoreUserLineup();
      _afterUserMatch(f);
    }
    final mine = winner.id == _userClubId;
    if (mine) {
      life.trophies.insert(0, trf('{0} · Super Kubok', [seasonLabel]));
      CoinWallet().reward(CoinWallet.objectiveReward);
    }
    _news(NewsKind.award, mine ? tr('SUPER KUBOK BIZNIKI! 🏆') : trf('Super Kubok: {0}', [winner.name]),
        '${getClubById(f.homeClubId)!.name} $homeScore – $awayScore ${getClubById(f.awayClubId)!.name}'
        '${superPens != null ? ' (pen. ${superPens!.$1}–${superPens!.$2})' : ''}',
        alert: f.involves(_userClubId!));
    notifyListeners();
  }

  void _setupSuperCup(List<LeagueStanding> lastTable, String? cupWinner) {
    superCup = null;
    superPens = null;
    if (lastTable.length < 2) return;
    final champion = lastTable.first.clubId;
    final other = cupWinner != null && cupWinner != champion && getClubById(cupWinner) != null && _allClubs.any((c) => c.id == cupWinner)
        ? cupWinner
        : lastTable[1].clubId;
    if (!_allClubs.any((c) => c.id == champion) || !_allClubs.any((c) => c.id == other)) return;
    superCup = Fixture(id: 'super_${calendar.year}', round: 1, homeClubId: champion, awayClubId: other, date: currentDate);
    _news(NewsKind.match, tr('Super Kubok'), trf('{0} – {1}: mavsum ochilishi.', [getClubById(champion)!.name, getClubById(other)!.name]),
        alert: superCup!.involves(_userClubId!));
  }

  // ------------------------------------------------------------ sponsors
  static const _sponsorNames = ['Registon Group', 'Aral Bank', 'Silk Road Air', 'Turon Energy', 'Navoiy Motors', 'Samarqand Telecom', 'Amu Logistics', 'Zarafshon Gold'];

  void _offerSponsors() {
    final rnd = Random(_salt(calendar.year * 59));
    final econ = _economyOf(userClub) * (0.6 + userClub.reputation / 125);
    int m(double millions) => ((millions * 1000000 * econ) / 50000).round() * 50000;
    final names = List.of(_sponsorNames)..shuffle(rnd);
    life.sponsor = null;
    life.sponsorOffers
      ..clear()
      ..addAll([
        {'name': names[0], 'type': 'fixed', 'perRound': m(1.1), 'bonus': 0},
        {'name': names[1], 'type': 'wins', 'perRound': m(0.55), 'bonus': m(1.4)},
        {'name': names[2], 'type': 'target', 'perRound': m(0.45), 'bonus': m(16)},
      ]);
  }

  void signSponsor(Map<String, dynamic> offer) {
    life.sponsor = offer;
    life.sponsorOffers.clear();
    _news(NewsKind.board, trf('Homiylik shartnomasi: {0}', [offer['name']]), tr('Shartnoma mavsum oxirigacha amal qiladi.'));
    notifyListeners();
  }

  /// "League · 5-tur" or "Cup · Semi-final".
  String fixtureTitle(Fixture f) {
    if (f.id.startsWith('super_')) return tr('Super Kubok');
    if (!isCupFixture(f)) return trf('{0} · {1}-tur', [leagueName, f.round]);
    final r = int.tryParse(f.id.split('_')[2]) ?? 0;
    return '$cupName · ${Cup.stageName(r, cup?.totalRounds ?? r + 1)}';
  }

  void _drawCup() {
    cup = Cup.draw(_allClubs, totalRounds, Random(_salt(calendar.year * 131)));
    cupFixtures.clear();
    _openCupFixture = null;
  }

  /// The user's cup tie due this week (after the league match), if any.
  Fixture? get pendingCupFixture {
    final c = cup;
    if (c == null || _userClubId == null || seasonFinished || nextUserFixture != null) return null;
    final r = c.currentRound;
    if (r == null || r >= c.rounds.length || c.schedule[r] != _currentRound) return null;
    final i = c.rounds[r].indexWhere((t) => t.involves(_userClubId!) && !t.played);
    if (i < 0) return null;
    final id = 'cup_${calendar.year}_${r}_$i';
    if (_openCupFixture?.id != id) {
      final t = c.rounds[r][i];
      _openCupFixture = Fixture(id: id, round: _currentRound, homeClubId: t.home, awayClubId: t.away!, date: currentDate);
    }
    return _openCupFixture;
  }

  (int, int) _autoShootout(Club home, Club away, Random rnd) => PenaltyModel.simulate(
    PenaltyModel.takers(home.startingXI),
    PenaltyModel.takers(away.startingXI),
    home.startingXI.firstWhere((p) => p.mainPosition.isGoalkeeper, orElse: () => home.startingXI.first),
    away.startingXI.firstWhere((p) => p.mainPosition.isGoalkeeper, orElse: () => away.startingXI.first),
    rnd,
  );

  /// Finishes the user's cup match; a draw goes to [penalties] (or an
  /// automatic shootout).
  void _finishCupMatch(Fixture f, int homeScore, int awayScore, List<MatchEvent> events, MatchField? engine, (int, int)? penalties) {
    final parts = f.id.split('_');
    final r = int.parse(parts[2]), i = int.parse(parts[3]);
    final tie = cup!.rounds[r][i];
    if (engine != null) {
      engine.writeTo(f);
      _applyEngine(f, engine);
    } else {
      f.events = events;
    }
    f
      ..homeScore = homeScore
      ..awayScore = awayScore
      ..isPlayed = true;
    tie
      ..homeGoals = homeScore
      ..awayGoals = awayScore;
    if (homeScore == awayScore) {
      final pens = penalties ?? _autoShootout(getClubById(tie.home)!, getClubById(tie.away!)!, Random(_salt(f.id.hashCode)));
      tie
        ..homePens = pens.$1
        ..awayPens = pens.$2;
    }
    cupFixtures.add(f);
    _openCupFixture = null;
    _recordManagerResult(f);
    _restoreUserLineup();
    _afterUserMatch(f);
    final won = tie.winner == _userClubId;
    _news(
      NewsKind.match,
      won ? trf('{0}: keyingi bosqichga chiqdik!', [cupName]) : trf('{0}: kubokdan chiqdik', [cupName]),
      '${getClubById(tie.home)!.name} ${tie.score()} ${getClubById(tie.away!)!.name}',
      alert: true,
    );
    _resolveCupRound(r);
    notifyListeners();
  }

  /// Plays the rest of a cup round in the background and draws the next.
  void _resolveCupRound(int r) {
    final c = cup;
    if (c == null || r >= c.rounds.length) return;
    final rnd = Random(_salt(calendar.year * 977 + r));
    for (final t in c.rounds[r]) {
      if (t.played) continue;
      final home = getClubById(t.home)!, away = getClubById(t.away!)!;
      if (home.id == _userClubId || away.id == _userClubId) {
        // Not played by the manager in time: played as a quick result.
        final fx = pendingCupFixture ?? Fixture(id: 'cup_${calendar.year}_${r}_${c.rounds[r].indexOf(t)}', round: _currentRound, homeClubId: t.home, awayClubId: t.away!);
        final engine = _userEngine(fx)..simulateToEnd();
        _finishCupMatch(fx, engine.homeStats.goals, engine.awayStats.goals, engine.events, engine, null);
        return;
      }
      final (hs, aw) = quickScore(home, away, rnd);
      t
        ..homeGoals = hs
        ..awayGoals = aw;
      if (hs == aw) {
        final pens = _autoShootout(home, away, rnd);
        t
          ..homePens = pens.$1
          ..awayPens = pens.$2;
      }
    }
    c.advance(rnd);
    if (c.winner != null) {
      final champ = getClubById(c.winner!)!;
      final mine = champ.id == _userClubId;
      _news(NewsKind.award, mine ? trf('{0} BIZNIKI! 🏆', [cupName]) : trf('{0} g‘olibi: {1}', [cupName, champ.name]),
          trf('{0} mavsumi kubok finali yakunlandi.', [seasonLabel]), alert: mine);
      if (mine) {
        life.trophies.insert(0, trf('{0} · {1} g‘olibi', [seasonLabel, cupName]));
        CoinWallet().reward(CoinWallet.promotionReward);
      }
    } else if (c.rounds.length > r + 1 && c.rounds[r + 1].any((t) => t.involves(_userClubId!))) {
      final t = c.rounds[r + 1].firstWhere((t) => t.involves(_userClubId!));
      final rival = getClubById(t.home == _userClubId ? t.away! : t.home)!;
      _news(NewsKind.match, trf('{0}: {1} qur’asi', [cupName, Cup.stageName(r + 1, c.totalRounds)]),
          trf('Raqibimiz: {0} ({1}-turdan keyin).', [rival.name, c.schedule[r + 1]]));
    }
  }

  void _resetRecords() {
    life.reset();
    world.reset();
    ledger.clear();
    transferHistory.clear();
    news.clear();
    alerts.clear();
    deals.clear();
    transferListed.clear();
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
    String? league,
  }) {
    if (managerProfile != null) _managerProfile = managerProfile;
    _resetRecords();
    leagueId = league ?? InitialDatabase.leagueOf(selectedClub.id) ?? 'super';
    _allClubs = InitialDatabase.getClubs(leagueId);
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
    String league = 'super',
  }) {
    if (managerProfile != null) _managerProfile = managerProfile;
    final baseClubs = InitialDatabase.getClubs(league);
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
      city: tr('Toshkent'),
      nickname: tr('Yangi kuch'),
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
    // Lower divisions pay less: wages, budget and reputation follow suit.
    final econ = InitialDatabase.info(league).economy;
    if (econ < 1) {
      final scale = max(0.2, econ * 2);
      for (final p in customClub.squad) {
        p.contract = p.contract.copyWith(weeklyWage: max(2000, (p.contract.weeklyWage * scale).round()));
      }
      customClub
        ..transferBudget = (80000000 * max(0.1, econ * 1.5)).round()
        ..wageBudget = (2600000 * scale).round()
        ..reputation = InitialDatabase.info(league).tier == 2 ? 64 : 55
        ..ticketPrice = 30;
    }
    _resetRecords();
    leagueId = league;
    // The new club takes the place of the league's weakest side.
    final keep = List<Club>.of(baseClubs)..sort((a, b) => b.reputation.compareTo(a.reputation));
    _allClubs = [...keep.take(baseClubs.length - 1), customClub];
    _userClubId = customClubId;
    _beginCareer();
  }

  /// [year] and [seasons] (summers since the data files) for a career that
  /// continues in another league.
  void _beginCareer({int year = firstSeason, int seasons = 0}) {
    careerSeed = Random().nextInt(1 << 30);
    calendar = SeasonCalendar(year, totalRounds);
    for (final c in _allClubs) {
      _ensureMatchdaySquad(c);
      // Seed files for big leagues list squads, not a tactical XI.
      if (c.id != _userClubId || leagueId != 'super') autoPickLineup(c);
      // Seed values have a floor; weak players and smaller leagues start at
      // their real worth.
      final econ = _economyOf(c);
      for (final p in c.squad) {
        if (p.ovr < 68 || econ < 1) p.marketValue = min(p.marketValue, p.fairValueIn(econ));
      }
    }
    _setupDivisions(seasons: seasons);
    _generateSeasonSchedule();
    _drawCup();
    _offerSponsors();
    superCup = null;
    superPens = null;
    _initializeStandings();
    _currentRound = 1;
    _isInitialized = true;
    objective = _objectiveFor(userClub);
    balanceHistory.add(userClub.transferBudget);
    _seedFreeAgents();
    _news(
      NewsKind.board,
      trf('{0}ga xush kelibsiz!', [userClub.name]),
      trf('Boshqaruv kengashi {0}ni bosh murabbiy etib tayinladi. Mavsum maqsadi: {1}. Transfer byudjeti {2}.', [_managerProfile.name, objective.title, _m(userClub.transferBudget)]),
    );
    _news(
      NewsKind.window,
      tr('Yozgi transfer oynasi ochiq'),
      trf('Oyna {0} gacha ishlaydi. Qishki oyna: {1} – {2}.', [SeasonCalendar.format(calendar.summerClose), SeasonCalendar.format(calendar.winterOpen), SeasonCalendar.format(calendar.winterClose)]),
    );
    notifyListeners();
  }

  /// Fresh background leagues for the rest of the pyramid.
  void _setupDivisions({int seasons = 0}) {
    divisions.clear();
    pendingMoves.clear();
    for (final l in InitialDatabase.pyramidOf(leagueId)) {
      if (l.id == leagueId) continue;
      final clubs = InitialDatabase.getClubs(l.id);
      for (final c in clubs) {
        WorldMarket.age(c, seasons, Random(c.id.hashCode ^ seasons));
        _ensureMatchdaySquad(c);
        autoPickLineup(c);
      }
      final d = Division(l.id, clubs, SeasonCalendar(calendar.year, (clubs.length - 1) * 2));
      d.newSeason(_salt(calendar.year * 3 + l.tier));
      divisions[l.id] = d;
    }
  }

  /// Background leagues catch up with the calendar.
  void _playDivisions(DateTime until) {
    if (divisions.isEmpty) return;
    final rnd = Random(_salt(until.millisecondsSinceEpoch ~/ 86400000));
    for (final d in divisions.values) {
      d.playUntil(until, rnd);
    }
  }

  BoardObjective _objectiveFor(Club c) {
    final ranked = List<Club>.of(_allClubs)
      ..sort((a, b) => b.squadDepthRating.compareTo(a.squadDepthRating));
    final rank = ranked.indexOf(c) + 1;
    final n = _allClubs.length;
    final info = leagueInfo;
    if (info.tier > 1) {
      return switch (rank) {
        <= 2 => const BoardObjective('Avtomatik ko‘tarilish (top-2)', 2),
        <= 6 when info.hasPlayoff => BoardObjective('Pley-off (top-{0})', info.playoffTo, info.playoffTo),
        <= 6 => const BoardObjective('Top-6', 6),
        <= 12 => const BoardObjective('Top-12', 12),
        _ => info.relegate > 0
            ? BoardObjective('Ligada qolish', n - info.relegate)
            : const BoardObjective('Top-16', 16),
      };
    }
    if (n > 10) {
      return switch (rank) {
        1 => const BoardObjective('Chempionlik', 1),
        <= 4 => const BoardObjective('Top-4 (kontinental kubok)', 4),
        <= 7 => const BoardObjective('Top-6 (kontinental kubok)', 6),
        <= 12 => const BoardObjective('Top-10', 10),
        _ => BoardObjective('Ligada qolish', n - 3),
      };
    }
    return switch (rank) {
      1 => const BoardObjective('Chempionlik', 1),
      2 || 3 => const BoardObjective('Top-3', 3),
      4 || 5 => BoardObjective('Top-4', 4),
      _ => BoardObjective('Top-6', 6),
    };
  }

  void _initializeStandings() {
    _standingsMap = {
      for (final club in _allClubs) club.id: LeagueStanding(clubId: club.id),
    };
  }

  /// Berger round-robin; the draw is shuffled per career and per season.
  void _generateSeasonSchedule() {
    _fixtures = roundRobin([for (final c in _allClubs) c.id], calendar, 'fix', _salt(calendar.year));
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

  /// Man marking for the coming (or current) match: our player id → the
  /// rival player he follows. Cleared after the match.
  final Map<String, String> manMarks = {};

  /// The club the user plays next (cup and Super Cup first).
  Club? get upcomingRival {
    final f = pendingSuperCup ?? pendingCupFixture ?? nextUserFixture;
    if (f == null) return null;
    return getClubById(f.homeClubId == _userClubId ? f.awayClubId : f.homeClubId);
  }

  /// [ours] follows [theirs] everywhere (null: back to zonal marking).
  /// One marker per rival player.
  void setManMark(Player ours, Player? theirs) {
    manMarks.remove(ours.id);
    if (theirs != null) {
      manMarks.removeWhere((_, v) => v == theirs.id);
      manMarks[ours.id] = theirs.id;
    }
    notifyListeners();
  }

  void setPlayerInstruction(Player p, PlayerInstruction instruction) {
    if (userClub.squad.contains(p)) {
      p.instruction = instruction;
      notifyListeners();
    }
  }

  /// Injured and suspended players drop from the bench to the reserves;
  /// the best available reserves fill the nine places (keeper first).
  void _ensureMatchdaySquad(Club c) {
    c.benchIds.removeWhere(
      (id) => c.playerById(id) == null || c.startingLineupIds.contains(id) || !c.playerById(id)!.isAvailable,
    );
    final reserves = c.reserves.where((p) => p.isAvailable).toList()..sort((a, b) => b.ovr.compareTo(a.ovr));
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
    // Optimal assignment: natural positions are strongly preferred, so the
    // best centre-back plays centre-back instead of filling a full-back gap.
    double fit(Player p, PlayerPosition pos) {
      if (pos.isGoalkeeper != p.mainPosition.isGoalkeeper) return -1000;
      return score(p, pos) +
          switch (p.fitFor(pos)) {
            PositionFit.natural => 10,
            PositionFit.alternative => 6,
            PositionFit.similar => 1,
            PositionFit.poor => -12,
          };
    }

    if (pool.length >= slots.length) {
      final matrix = [
        for (final s in slots) [for (final p in pool) fit(p, s.defaultPosition)],
      ];
      final pick = LineupSolver.assign(matrix);
      for (var i = 0; i < slots.length; i++) {
        if (pick[i] >= 0 && fit(pool[pick[i]], slots[i].defaultPosition) > -500) {
          chosen[i] = pool[pick[i]];
        }
      }
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

  /// How well [p] suits a slot played as [pos] right now (in-match use).
  static double slotFit(Player p, PlayerPosition pos) {
    if (pos.isGoalkeeper != p.mainPosition.isGoalkeeper) return -1000;
    return p.getEffectiveOVR(pos) * (0.86 + p.currentStamina / 100 * 0.14) +
        switch (p.fitFor(pos)) {
          PositionFit.natural => 10,
          PositionFit.alternative => 6,
          PositionFit.similar => 1,
          PositionFit.poor => -12,
        };
  }

  void autoPickUserLineup({bool byForm = false}) {
    autoPickLineup(userClub, byForm: byForm);
    notifyListeners();
  }

  /// The line-up the manager picked, kept while a match is played:
  /// substitutions during the match must not change it for later rounds.
  List<String>? _preMatchXI, _preMatchBench;

  /// Remembers the regular XI, bench, tactics and instructions: whatever is
  /// changed for one match (before kick-off or during it) is undone after.
  /// A match-day plan made before kick-off keeps the earlier snapshot.
  void beginUserMatch() {
    if (_preMatchXI != null) return;
    _preMatchXI = List.of(userClub.startingLineupIds);
    _preMatchBench = List.of(userClub.benchIds);
    preMatchTactics = userClub.tactics;
    preMatchInstructions = {for (final p in userClub.squad) p.id: p.instruction};
  }

  /// The regular tactics and instructions while a match (plan) is running.
  TeamTactics? preMatchTactics;
  Map<String, PlayerInstruction>? preMatchInstructions;
  bool get matchPlanActive => _preMatchXI != null;

  /// Drops a match-day plan (or an abandoned match): everything returns.
  void cancelMatchPlan() {
    final tactics = preMatchTactics, instructions = preMatchInstructions;
    _restoreUserLineup();
    if (tactics != null) userClub.tactics = tactics;
    for (final p in userClub.squad) {
      final ins = instructions?[p.id];
      if (ins != null) p.instruction = ins;
    }
    notifyListeners();
  }

  void _restoreUserLineup() {
    final xi = _preMatchXI, bench = _preMatchBench;
    _preMatchXI = _preMatchBench = null;
    manMarks.clear();
    preMatchTactics = null;
    preMatchInstructions = null;
    if (xi == null || bench == null) return;
    final c = userClub;
    if (xi.length != 11 || !xi.every((id) => c.playerById(id) != null)) return;
    c.startingLineupIds
      ..clear()
      ..addAll(xi);
    c.benchIds
      ..clear()
      ..addAll(bench.where((id) => c.playerById(id) != null && !xi.contains(id)));
    _ensureMatchdaySquad(c);
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
    (int, int)? penalties,
  }) {
    if (fixture.isPlayed) return;
    if (isCupFixture(fixture)) {
      _finishCupMatch(fixture, homeScore, awayScore, events, engine, penalties);
      return;
    }
    if (fixture.id.startsWith('super_')) {
      _finishSuperCup(fixture, homeScore, awayScore, events, engine, penalties);
      return;
    }
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
    if (fixture.involves(_userClubId!)) {
      _recordManagerResult(fixture);
      _afterUserMatch(fixture);
      final mine = fixture.homeClubId == _userClubId ? homeScore - awayScore : awayScore - homeScore;
      final derbyWin = isDerby(getClubById(fixture.homeClubId)!, getClubById(fixture.awayClubId)!);
      final deal = life.sponsor;
      if (deal != null && deal['type'] == 'wins' && mine > 0) {
        _post(userClub, trf('Homiy g‘alaba bonusi: {0}', [deal['name']]), deal['bonus'] as int, category: FinanceCategory.commercial);
      }
      CoinWallet().reward((mine > 0 ? CoinWallet.winReward : mine == 0 ? CoinWallet.drawReward : 0) * (derbyWin ? 2 : 1));
      _restoreUserLineup();
    }
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
        trf('Menejer reytingi oshdi: {0}', [style.title]),
        trf('{0} – {1} uslubi {2} ga ko‘tarildi. Bu uslubda jamoa aniqroq pas beradi va to‘g‘ri qaror qabul qiladi.', [m.name, style.title, m.proficiency[style]]),
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
    // Reputation follows results against expectations: beating stronger
    // sides lifts it, losing to weaker ones costs more.
    final home = f.homeClubId == _userClubId;
    final edge = userClub.teamOVR - opp.teamOVR + (home ? 2 : -2);
    final expected = (1.35 + edge * 0.09).clamp(0.3, 2.6);
    final points = r == 'W' ? 3 : r == 'D' ? 1 : 0;
    m.reputation = (m.reputation + (points - expected) * 0.32).clamp(1.0, 99.0);
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
    final names = [
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
      final rounds = userClub.squad.contains(p)
          ? max(1, (entry.value * life.injuryFactor * (1 - 0.04 * life.staffLevel(StaffRole.fitness))).round())
          : entry.value;
      p.injuryRounds = max(p.injuryRounds, rounds);
      p.injury = names[rnd.nextInt(names.length)];
      if (homeClub.id == _userClubId || awayClub.id == _userClubId) {
        if (userClub.squad.contains(p)) {
          _news(
            NewsKind.injury,
            trf('{0} jarohat oldi', [p.name]),
            trf('{0}. Shifokorlar xulosasi: taxminan {1} tur o‘tkazib yuboradi.', [p.injury, p.injuryRounds]),
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
    final boost = userClub.squad.contains(p) ? life.growthFactor : 1.0;
    p.growth += ((rating - 6.6) * 0.18 * (minutes / 90) + youth) * (youth > 0 || rating > 6.6 ? boost : 1);
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
        trf('{0} rivojlandi: OVR {1} → {2}', [p.shortName, before, p.ovr]),
        trf('Yaxshi o‘yinlar va mashg‘ulotlar natijasi. Bozor bahosi: {0}.', [_m(p.marketValue)]),
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

  /// Other matches of the round already played in the background while the
  /// user watched the live match (fixture id → finished engine).
  final Map<String, MatchField> _presimulated = {};
  int _presimulation = 0;

  /// Plays the round's other matches in small slices during the live match,
  /// so finishing it does not freeze the screen (web especially).
  Future<void> presimulateRound(String userFixtureId) async {
    final token = ++_presimulation;
    _presimulated.clear();
    final round = _currentRound;
    for (final f in _fixtures.where((f) => f.round == round && f.id != userFixtureId && !f.isPlayed).toList()) {
      final engine = _otherEngine(f, round);
      await engine.simulateToEndAsync(sliceMs: 4, pauseMs: 12);
      if (token != _presimulation || f.isPlayed || round != _currentRound) return;
      _presimulated[f.id] = engine;
    }
  }

  MatchField _otherEngine(Fixture f, int round) {
    final home = getClubById(f.homeClubId)!, away = getClubById(f.awayClubId)!;
    if (home.id != _userClubId) autoPickLineup(home);
    if (away.id != _userClubId) autoPickLineup(away);
    return MatchField(
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
  }

  void _simulateOtherMatchesInRound(int round, String userFixtureId) {
    _presimulation++;
    for (final f in _fixtures.where(
      (f) => f.round == round && f.id != userFixtureId && !f.isPlayed,
    )) {
      final home = getClubById(f.homeClubId)!, away = getClubById(f.awayClubId)!;
      final engine = _presimulated.remove(f.id) ?? (_otherEngine(f, round)..simulateToEnd());
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
    _presimulated.clear();
  }

  /// A full instant simulation of the user's own fixture (no live view).
  MatchField simulateUserFixture(Fixture f) {
    final engine = _userEngine(f)..simulateToEnd();
    _finishUserEngine(f, engine);
    return engine;
  }

  /// Quick result without freezing the UI; [onProgress] gets 0..1.
  Future<MatchField> simulateUserFixtureAsync(Fixture f, {void Function(double)? onProgress}) async {
    final engine = _userEngine(f);
    await engine.simulateToEndAsync(onProgress: onProgress);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    _finishUserEngine(f, engine);
    return engine;
  }

  MatchField _userEngine(Fixture f) {
    beginUserMatch();
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
    applyClubBoosts(engine, userHome);
    engine.derby = isDerby(home, away);
    return engine;
  }

  void _finishUserEngine(Fixture f, MatchField engine) => finishMatch(
    fixture: f,
    homeScore: engine.homeStats.goals,
    awayScore: engine.awayStats.goals,
    events: engine.events,
    engine: engine,
  );

  // ------------------------------------------------------------ economy
  int baseTicketPrice(Club c) => _economyOf(c) < 1 ? 18 + c.reputation ~/ 3 : 35 + c.reputation ~/ 2;

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

  int weeklyCommercial(Club c) => (c.reputation * c.reputation * 520 * _economyOf(c)).round();

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
    final days = calendar.daysAfterRound(_currentRound);
    final weeks = calendar.weeksAfterRound(_currentRound);
    int perDays(int weekly) => (weekly * days / 7).round();
    final econ = leagueInfo.economy;
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
        _post(club, trf('Chipta tushumi · {0} muxlis', [attendance]), attendance * club.ticketPrice,
            category: FinanceCategory.tickets);
        _post(club, tr('Stadion va xavfsizlik'), -(attendance * 6 + (180000 * econ).round()),
            category: FinanceCategory.stadium);
        final ratio = club.ticketPrice / baseTicketPrice(club);
        club.fanMood = (club.fanMood - ((ratio - 1) * 6).round()).clamp(10, 100);
      }
      final pos = positionOf(club.id);
      final n = _allClubs.length;
      final tv = n <= 8 ? 1800000 + (8 - pos) * 150000 : ((1800000 + (n - pos) * 60000) * econ).round();
      _post(club, tr('Teletranslyatsiya ulushi'), tv, category: FinanceCategory.broadcast);
      final span = days % 7 == 0 ? trf('{0} hafta', [weeks]) : trf('{0} kun', [days]);
      _post(club, trf('Homiylik va savdo · {0}', [span]), perDays(weeklyCommercial(club)),
          category: FinanceCategory.commercial);
      _post(club, trf('Futbolchi maoshlari · {0}', [span]), -perDays(club.totalWeeklyWages),
          category: FinanceCategory.wages);
      _post(club, trf('Klub, akademiya va xodimlar · {0}', [span]),
          -perDays(((250000 + club.reputation * 2000) * econ).round()),
          category: FinanceCategory.operations);
      for (final p in club.squad) {
        final starter = club.startingLineupIds.contains(p.id);
        p.morale = (p.morale + (starter ? 1 : 0)).clamp(30, 100);
      }
    }
  }

  // ----------------------------------------------------------- rounds
  /// Every round values drift toward each player's current worth (ability,
  /// age, potential and form), so good runs raise prices step by step.
  void _revalueMarket() {
    for (final p in [for (final c in _allClubs) ...c.squad, ...freeAgents]) {
      final club = _allClubs.where((c) => c.squad.contains(p)).firstOrNull;
      final target = p.fairValueIn(club == null ? 0.5 : _economyOf(club));
      p.marketValue = Player.roundValue(p.marketValue + (target - p.marketValue) * 0.12);
    }
  }

  void nextRound() {
    if (seasonFinished ||
        _currentRound >= totalRounds ||
        currentRoundFixtures.any((f) => !f.isPlayed)) {
      return;
    }
    final sc = superCup;
    if (sc != null && !sc.isPlayed) {
      final engine = _userEngine(sc)..simulateToEnd();
      if (!sc.involves(_userClubId!)) _restoreUserLineup();
      _finishSuperCup(sc, engine.homeStats.goals, engine.awayStats.goals, engine.events, engine, null);
    }
    final deal = life.sponsor;
    if (deal != null) {
      _post(userClub, trf('Homiy: {0}', [deal['name']]), deal['perRound'] as int, category: FinanceCategory.commercial);
    }
    final dueCup = cup?.currentRound;
    if (dueCup != null && dueCup < (cup?.rounds.length ?? 0) && cup!.schedule[dueCup] <= _currentRound) {
      _resolveCupRound(dueCup);
    }
    _playDivisions(calendar.dateOfRound(_currentRound));
    final playedOn = currentDate;
    if (calendar.dateOfRound(_currentRound + 1).month != playedOn.month) {
      _monthAwards(playedOn.year, playedOn.month);
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
    _processDeals();
    _ensureMatchdaySquad(userClub);
    _revalueMarket();
    _weeklyClubLife(days);
    _dressingRoom();
    _weeklyStaff();
    _rumours();
    _boardPatience();
    final open = isTransferWindowOpen;
    if (!wasOpen && open) {
      _news(
        NewsKind.window,
        tr('Qishki transfer oynasi ochildi'),
        trf('Oyna {0} gacha ochiq. Tarkibni kuchaytirish vaqti!', [SeasonCalendar.format(calendar.winterClose)]),
      );
    } else if (wasOpen && !open) {
      _aiWindowBuyers.clear();
      _news(
        NewsKind.window,
        tr('Transfer oynasi yopildi'),
        trf('Keyingi oyna: {0}.', [SeasonCalendar.format(currentDate.isBefore(calendar.winterOpen) ? calendar.winterOpen : DateTime(calendar.year + 1, 6, 16))]),
      );
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
          tr('Shartnomasi tugayotgan futbolchilar'),
          trf('{0}{1}: yangilanmasa, mavsum oxirida klubni tark etadi.', [expiring.take(4).map((p) => p.shortName).join(', '), expiring.length > 4 ? tr(' va boshqalar') : '']),
        );
      }
    }
    notifyListeners();
  }

  /// Player and Manager of the Month for the user's league.
  void _monthAwards(int year, int month) {
    final played = _fixtures
        .where((f) => f.isPlayed && f.date != null && f.date!.year == year && f.date!.month == month)
        .toList();
    if (played.length < _allClubs.length ~/ 2) return;
    final sums = <String, (double, int)>{};
    final points = <String, int>{};
    for (final f in played) {
      for (final e in f.ratings.entries) {
        final s = sums[e.key] ?? (0.0, 0);
        sums[e.key] = (s.$1 + e.value, s.$2 + 1);
      }
      final h = f.homeScore!, a = f.awayScore!;
      points[f.homeClubId] = (points[f.homeClubId] ?? 0) + (h > a ? 3 : h == a ? 1 : 0);
      points[f.awayClubId] = (points[f.awayClubId] ?? 0) + (a > h ? 3 : h == a ? 1 : 0);
    }
    final games = played.where((f) => f.involves(_userClubId!)).length;
    final eligible = sums.entries.where((e) => e.value.$2 >= max(2, games - 1)).toList()
      ..sort((a, b) => (b.value.$1 / b.value.$2).compareTo(a.value.$1 / a.value.$2));
    final monthName = SeasonCalendar.months[month - 1];
    if (eligible.isNotEmpty) {
      final best = eligible.first;
      Player? player;
      Club? club;
      for (final c in _allClubs) {
        player = c.playerById(best.key);
        if (player != null) {
          club = c;
          break;
        }
      }
      if (player != null && club != null) {
        final mine = club.id == _userClubId;
        if (mine) player.morale = min(100, player.morale + 8);
        _news(
          NewsKind.award,
          trf('{0} oyi futbolchisi: {1}', [monthName, player.name]),
          trf('{0} · {1} o‘yinda o‘rtacha reyting {2}.', [club.name, best.value.$2, (best.value.$1 / best.value.$2).toStringAsFixed(2)]),
          alert: mine,
        );
      }
    }
    final top = points.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty && top.first.key == _userClubId) {
      _managerProfile.gainExperience(ManagerPhilosophy.forStyle(userClub.tactics.playstyle), 6);
      boardConfidence = min(100, boardConfidence + 3);
      _news(
        NewsKind.award,
        trf('{0} oyi murabbiyi: {1}', [monthName, _managerProfile.name]),
        trf('{0} oy davomida {1} ochko to‘pladi – ligada eng yaxshi natija.', [userClub.name, top.first.value]),
        alert: true,
      );
    }
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

  /// What the selling club actually wants: key players, thin positions and
  /// sales to a league rival cost more.
  int askingPrice(Player p, Club seller, [Club? buyer]) =>
      (transferFee(p) * sellerStance(p, seller, buyer ?? userClub).premium / 100000).round() * 100000;

  /// How the selling club values [p]: a price premium, whether he is simply
  /// not for sale, and the reasons shown to the user.
  ({double premium, bool notForSale, List<String> reasons}) sellerStance(Player p, Club seller, Club buyer) {
    final reasons = <String>[];
    var premium = 1.0;
    final cat = p.mainPosition.category;
    final same = [for (final q in seller.squad) if (q.id != p.id && q.mainPosition.category == cat) q];
    final starter = seller.startingLineupIds.contains(p.id);
    final best = same.every((q) => q.ovr <= p.ovr);
    final key = starter && best && p.ovr >= seller.teamOVR;
    if (key) {
      premium *= 1.35;
      reasons.add(tr('Jamoaning asosiy o‘yinchisi'));
    } else if (starter) {
      premium *= 1.15;
      reasons.add(tr('Asosiy tarkib o‘yinchisi'));
    } else if (!seller.benchIds.contains(p.id)) {
      premium *= 0.9;
      reasons.add(tr('Klubda o‘ynamayapti – sotishga tayyor'));
    }
    final cover = same.where((q) => q.ovr >= p.ovr - 6).length;
    if (cover < (cat == PositionCategory.goalkeeper ? 1 : 2)) {
      premium *= 1.12;
      reasons.add(tr('Bu pozitsiyada o‘rinbosar yo‘q'));
    }
    if (p.age >= 31) premium *= 0.92;
    if (movedThisSeason(p)) {
      premium *= 1.25;
      reasons.add(tr('Yaqinda klubga kelgan'));
    }
    if (p.age <= 21 && p.potential >= p.ovr + 6) {
      premium *= 1.15;
      reasons.add(tr('Klub iste’dodni qadrlaydi'));
    }
    if (leagueOfClub(buyer.id) == leagueOfClub(seller.id)) {
      premium *= 1.1;
      reasons.add(tr('Raqib klubga sotish qimmatroq'));
    }
    if (seller.transferBudget < 0) {
      premium *= 0.88;
      reasons.add(tr('Klubga pul kerak'));
    }
    if (seller.id != _userClubId && transferListed.contains(p.id)) premium *= 0.9;
    // A club from a much poorer league cannot turn big money down.
    final poorer = _economyOf(buyer) >= _economyOf(seller) * 3;
    if (poorer) {
      premium *= 0.85;
      reasons.add(tr('Kichik liga klubi katta taklifga qarshi tura olmaydi'));
    }
    // A bigger club keeps its stars unless the money is huge.
    final notForSale = key && !poorer && seller.reputation >= buyer.reputation && p.contract.contractYears > 1;
    if (notForSale) reasons.add(tr('Sotilmaydi: faqat juda katta taklif yoki kompensatsiya summasi'));
    return (premium: premium, notForSale: notForSale, reasons: reasons);
  }

  /// How keen [p] is to join [buyer] from [seller] (0–100) and why: club
  /// size, league level, a place in the team, mood and character.
  ({int interest, List<String> reasons}) moveInterest(Player p, Club buyer, Club seller) {
    final reasons = <String>[];
    var v = 55.0;
    final ambitious = p.personality == Personality.ambitious;
    final repDiff = (buyer.reputation - seller.reputation).toDouble();
    v += (repDiff * (ambitious ? 1.6 : 1.1)).clamp(-35.0, 30.0);
    if (repDiff >= 6) reasons.add(tr('Kattaroq klub – qiziqadi'));
    if (repDiff <= -6) reasons.add(tr('Kichikroq klubga o‘tishni istamaydi'));
    final lb = leagueOfClub(buyer.id), ls = leagueOfClub(seller.id);
    final eb = InitialDatabase.info(lb).economy, es = InitialDatabase.info(ls).economy;
    if (eb > 0 && es > 0 && lb != ls) {
      final d = (log(eb / es) * 7).clamp(-18.0, 14.0);
      v += d;
      if (d.abs() >= 3) reasons.add(d > 0 ? tr('Kuchliroq liga') : tr('Zaifroq liga – kam qiziqadi'));
    }
    // Moving abroad: a new country and language; the young and the
    // ambitious mind it least.
    if (InitialDatabase.info(lb).country != InitialDatabase.info(ls).country) {
      v -= p.age <= 23 || ambitious ? 3 : 8;
      reasons.add(tr('Chet elga ko‘chishi kerak'));
    }
    final cat = p.mainPosition.category;
    final better = buyer.squad.where((q) => q.id != p.id && q.mainPosition.category == cat && q.ovr > p.ovr + 1).length;
    final slots = switch (cat) {
      PositionCategory.goalkeeper => 1,
      PositionCategory.defense => 4,
      _ => 3,
    };
    if (better == 0) {
      v += 10;
      reasons.add(tr('Asosiy tarkibda o‘ynashi aniq'));
    } else if (better >= slots) {
      v -= p.age < 30 ? (ambitious ? 22 : 15) : 8;
      reasons.add(tr('O‘yin vaqti kam bo‘lishidan xavotirda'));
    }
    if (p.morale < 55) {
      v += 12;
      reasons.add(tr('Hozirgi klubida baxtsiz'));
    }
    final unwanted = seller.id == _userClubId
        ? transferListed.contains(p.id)
        : !seller.startingLineupIds.contains(p.id) && !seller.benchIds.contains(p.id);
    if (unwanted) v += 8;
    if (p.personality == Personality.loyal && p.contract.contractYears > 1) {
      v -= 14;
      reasons.add(tr('Klubiga sodiq'));
    }
    if (p.age >= 31) {
      v += 4;
      reasons.add(tr('Yoshi katta: maosh muhimroq'));
    }
    if (p.contract.contractYears <= 1) v += 8;
    return (interest: v.round().clamp(0, 100), reasons: reasons);
  }

  int offeredWage(Player p) =>
      max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
  int signingCost(Player p, [int? fee]) =>
      ((fee ?? transferFee(p)) * 0.03).round() + offeredWage(p) * 4;

  String? transferIssue(Player player, Club seller, Club buyer, [int? fee]) {
    final price = fee ?? transferFee(player);
    if (!isTransferWindowOpen) {
      return trf('Transfer oynasi yopiq. {0}.', [transferWindowLabel]);
    }
    if (seller.id == buyer.id ||
        !seller.squad.any((p) => p.id == player.id) ||
        buyer.squad.any((p) => p.id == player.id)) {
      return tr('Futbolchi bu transfer uchun mavjud emas.');
    }
    if (seller.squad.length <= minSquad) {
      return trf('Sotuvchi klub kamida {0} futbolchini saqlashi kerak.', [minSquad]);
    }
    if (player.mainPosition.isGoalkeeper &&
        seller.squad.where((p) => p.mainPosition.isGoalkeeper).length <= 2) {
      return tr('Klub darvozabonlar sonini kamaytirmaydi.');
    }
    if (buyer.squad.length >= maxSquad) {
      return trf('Ro‘yxat to‘la: ko‘pi bilan {0} futbolchi.', [maxSquad]);
    }
    if (buyer.transferBudget < price + signingCost(player, price)) {
      return tr('Transfer, agent va imzo xarajatlari uchun mablag‘ yetarli emas.');
    }
    if (buyer.remainingWageBudget < offeredWage(player)) {
      return tr('Haftalik maosh limiti yetarli emas.');
    }
    return null;
  }

  void _completeTransfer(Player p, Club seller, Club buyer, [int? agreedFee, int? wage, int years = 3]) {
    final fee = agreedFee ?? transferFee(p);
    if ((buyer.id == _userClubId || seller.id == _userClubId) && (fee >= 10000000 || p.ovr >= 78)) {
      life.post(life.transferPost(userClub, p, fee, buyer.id == _userClubId, trf('{0} · {1}-tur', [seasonLabel, _currentRound]), Random(_salt(p.id.hashCode))));
    }
    final costs = signingCost(p, fee);
    _post(buyer, trf('{0}: transfer', [p.shortName]), -fee,
        category: FinanceCategory.transferOut);
    _post(buyer, trf('{0}: agent va imzo', [p.shortName]), -costs,
        category: FinanceCategory.agent);
    _post(seller, trf('{0}: transfer tushumi', [p.shortName]), fee,
        category: FinanceCategory.transferIn);
    // A player bought abroad must not reappear when the world is rebuilt.
    if (isWorldClub(seller)) world.gone.add(p.id);
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
    p.contract = p.contract.copyWith(contractYears: years, weeklyWage: wage ?? offeredWage(p));
    transferListed.remove(p.id);
    p.morale = 88;
    buyer.squad.add(p);
    if (buyer.benchIds.length < Club.matchdayBench) buyer.benchIds.add(p.id);
    transferHistory.insert(
      0,
      TransferRecord(_currentRound, p.name, seller.name, buyer.name, fee, date: currentDate),
    );
    p.transfers.insert(0, '$seasonLabel|${seller.name}|${buyer.name}|$fee|${seller.id}|${buyer.id}');
    if (buyer.id != _userClubId && seller.id != _userClubId) {
      _news(
        NewsKind.transfer,
        '${p.name} → ${buyer.name}',
        trf('{0} futbolchini {1} evaziga sotdi.', [seller.name, _m(fee)]),
      );
    }
  }

  bool buyPlayer(Player player, Club sellerClub) {
    lastTransferError = transferIssue(player, sellerClub, userClub);
    if (lastTransferError != null) return false;
    _completeTransfer(player, sellerClub, userClub);
    _news(
      NewsKind.transfer,
      trf('{0} jamoaga qo‘shildi', [player.name]),
      trf('{0}dan {1} evaziga. Shartnoma: 3 yil.', [sellerClub.name, _m(transferFee(player))]),
    );
    notifyListeners();
    return true;
  }

  /// How the selling club judges a bid: a met release clause always works;
  /// key players of bigger clubs need a huge offer; otherwise accepted at
  /// the asking price, countered when close, rejected below that.
  (NegotiationResult, int) evaluateBid(Player p, Club seller, int fee, [Club? buyer]) {
    final b = buyer ?? userClub;
    if (p.contract.releaseClause > 0 && fee >= p.contract.releaseClause) return (NegotiationResult.accepted, fee);
    final ask = askingPrice(p, seller, b);
    if (sellerStance(p, seller, b).notForSale) {
      final huge = (ask * 1.5 / 100000).round() * 100000;
      return fee >= huge ? (NegotiationResult.accepted, fee) : (NegotiationResult.rejected, huge);
    }
    if (fee >= ask) return (NegotiationResult.accepted, fee);
    if (fee >= ask * 0.85) {
      final counter = ((fee + ask) / 2 / 100000).round() * 100000;
      return (NegotiationResult.countered, max(counter, fee + 100000));
    }
    return (NegotiationResult.rejected, ask);
  }

  /// Weekly wage the player asks from [buyer]: the less he wants the move,
  /// the more it costs; ambitious players always ask a bit more.
  int wageDemand(Player p, Club buyer, Club seller) {
    final interest = moveInterest(p, buyer, seller).interest;
    final factor = (1 + (60 - interest) / 100).clamp(0.9, 1.6) * (p.personality == Personality.ambitious ? 1.08 : 1.0);
    return max(1000, (offeredWage(p) * factor / 1000).round() * 1000);
  }

  /// Below this interest a player will not discuss a move at all.
  static const refuseInterest = 25;

  TransferDeal? dealFor(Player p) =>
      deals.where((d) => d.player.id == p.id && !d.stage.finished).firstOrNull;

  /// Step 1 of a purchase: the bid goes to the club, which answers next round.
  String? makeBid(Player p, Club seller, int fee) {
    final issue = transferIssue(p, seller, userClub, fee);
    if (issue != null) return lastTransferError = issue;
    final existing = dealFor(p);
    if (existing != null && existing.buyer.id != _userClubId) return tr('Bu futbolchi bo‘yicha boshqa muzokara bor.');
    if (existing != null) {
      existing
        ..fee = fee
        ..stage = DealStage.clubReview
        ..dueRound = _currentRound + 1
        ..note = tr('Yangi taklif yuborildi.');
    } else {
      deals.add(TransferDeal(
        player: p,
        seller: seller,
        buyer: userClub,
        fee: fee,
        stage: DealStage.clubReview,
        dueRound: _currentRound + 1,
        note: tr('Taklif yuborildi. Klub keyingi turda javob beradi.'),
      ));
    }
    notifyListeners();
    return null;
  }

  void acceptCounter(TransferDeal d) {
    if (d.stage != DealStage.clubCountered || d.counterFee == null) return;
    d
      ..fee = d.counterFee!
      ..stage = DealStage.contractTalks
      ..wage = wageDemand(d.player, d.buyer, d.seller)
      ..dueRound = _currentRound + 3
      ..note = tr('Narx kelishildi. Endi futbolchiga shartnoma taklif qiling.');
    notifyListeners();
  }

  /// Step 2: personal terms. The player answers next round.
  String? offerContract(TransferDeal d, int wage, int years) {
    if (d.stage != DealStage.contractTalks) return null;
    final c = userClub;
    if (c.remainingWageBudget < wage) return lastTransferError = tr('Haftalik maosh limiti yetarli emas.');
    if (c.transferBudget < d.fee + ((d.fee * 0.03).round() + wage * 4)) {
      return lastTransferError = tr('Transfer, agent va imzo xarajatlari uchun mablag‘ yetarli emas.');
    }
    d
      ..wage = wage
      ..years = years.clamp(1, 5)
      ..stage = DealStage.playerReview
      ..dueRound = _currentRound + 1
      ..note = tr('Shartnoma taklifi futbolchiga yuborildi.');
    notifyListeners();
    return null;
  }

  /// Selling: accept an AI bid; the player and buyer agree terms next round.
  void acceptDealOffer(TransferDeal d) {
    if (d.stage != DealStage.offerReceived) return;
    d
      ..stage = DealStage.medical
      ..dueRound = _currentRound + 1
      ..note = tr('Taklif qabul qilindi. Futbolchi xaridor bilan shartlarni kelishmoqda.');
    notifyListeners();
  }

  void counterDealOffer(TransferDeal d, int fee) {
    if (d.stage != DealStage.offerReceived) return;
    d
      ..counterFee = fee
      ..stage = DealStage.buyerReview
      ..dueRound = _currentRound + 1
      ..note = trf('Siz {0} so‘radingiz. Xaridor keyingi turda javob beradi.', [_m(fee)]);
    notifyListeners();
  }

  void cancelDeal(TransferDeal d) {
    if (d.stage == DealStage.offerReceived) d.player.morale = max(35, d.player.morale - 2);
    d
      ..stage = DealStage.collapsed
      ..dueRound = _currentRound
      ..note = tr('Muzokara to‘xtatildi.');
    notifyListeners();
  }

  void toggleTransferList(Player p) {
    if (!transferListed.remove(p.id)) transferListed.add(p.id);
    notifyListeners();
  }

  /// Answers every negotiation that is due (called when a round passes).
  void _processDeals({bool force = false}) {
    final rnd = Random(_salt(_currentRound * 53 + calendar.year));
    deals.removeWhere((d) => d.stage.finished && d.dueRound < _currentRound - 1);
    for (final d in List.of(deals)) {
      if (d.stage.finished || (!force && d.dueRound > _currentRound)) continue;
      final p = d.player;
      final buying = d.buyer.id == _userClubId;
      void collapse(String why) {
        d
          ..stage = DealStage.collapsed
          ..note = why;
        _news(NewsKind.transfer, trf('{0}: muzokara tugadi', [p.name]), why, alert: true);
      }

      if (!isTransferWindowOpen) {
        collapse(tr('Transfer oynasi yopildi – muzokara bekor bo‘ldi.'));
        continue;
      }
      if (!d.seller.squad.contains(p)) {
        collapse(tr('Futbolchi endi bu klubda emas.'));
        continue;
      }
      switch (d.stage) {
        case DealStage.clubReview:
          final (result, value) = evaluateBid(p, d.seller, d.fee);
          switch (result) {
            case NegotiationResult.accepted:
              d
                ..stage = DealStage.contractTalks
                ..wage = wageDemand(p, d.buyer, d.seller)
                ..dueRound = _currentRound + 3
                ..note = trf('{0} taklifni qabul qildi. Endi futbolchiga shartnoma taklif qiling.', [d.seller.name]);
              _news(NewsKind.transfer, trf('{0}: taklif qabul qilindi', [p.name]), d.note, alert: true);
            case NegotiationResult.countered:
              d
                ..stage = DealStage.clubCountered
                ..counterFee = value
                ..dueRound = _currentRound + 3
                ..note = trf('{0} {1} so‘ramoqda.', [d.seller.name, _m(value)]);
              _news(NewsKind.transfer, trf('{0}: qarshi taklif', [p.name]), d.note, alert: true);
            default:
              collapse(trf('{0} taklifni rad etdi. Klub kamida {1} kutmoqda.', [d.seller.name, _m(value)]));
          }
        case DealStage.playerReview:
          final demand = wageDemand(p, d.buyer, d.seller) * (d.years >= 4 ? 0.97 : 1.0);
          final mind = moveInterest(p, d.buyer, d.seller);
          if (mind.interest < refuseInterest) {
            collapse(trf('{0} {1}ga o‘tishni xohlamaydi: {2}.', [p.name, d.buyer.name, mind.reasons.take(2).join(', ')]));
            continue;
          }
          if (d.wage >= demand) {
            final issue = transferIssue(p, d.seller, d.buyer, d.fee);
            if (issue != null) {
              collapse(issue);
              continue;
            }
            _completeTransfer(p, d.seller, d.buyer, d.fee, d.wage, d.years);
            d
              ..stage = DealStage.done
              ..note = trf('{0} {1} yillik shartnoma imzoladi.', [p.name, d.years]);
            _news(NewsKind.transfer, trf('{0} jamoaga qo‘shildi', [p.name]),
                trf('{0}dan {1} evaziga. Shartnoma: {2} yil, {3}/hafta.', [d.seller.name, _m(d.fee), d.years, _m(d.wage)]),
                alert: true);
          } else if (d.wage >= demand * 0.85) {
            d
              ..stage = DealStage.contractTalks
              ..wage = demand.round()
              ..dueRound = _currentRound + 3
              ..note = trf('Futbolchi haftasiga {0} so‘ramoqda.', [_m(demand.round())]);
            _news(NewsKind.transfer, trf('{0}: maosh talabi', [p.name]), d.note, alert: true);
          } else {
            collapse(trf('{0} shartnoma taklifini rad etdi.', [p.name]));
          }
        case DealStage.buyerReview:
          final limit = p.marketValue * (1.05 + rnd.nextDouble() * 0.3);
          final asked = d.counterFee ?? d.fee;
          if (asked <= limit && d.buyer.transferBudget >= asked) {
            d
              ..fee = asked
              ..stage = DealStage.medical
              ..dueRound = _currentRound + 1
              ..note = trf('{0} {1} to‘lashga rozi bo‘ldi.', [d.buyer.name, _m(asked)]);
            _news(NewsKind.transfer, trf('{0}: narx kelishildi', [p.name]), d.note, alert: true);
          } else if (rnd.nextBool()) {
            final meet = ((d.fee + asked) / 2 / 100000).round() * 100000;
            d
              ..fee = meet
              ..stage = DealStage.offerReceived
              ..dueRound = _currentRound + 3
              ..note = trf('{0} o‘rtada kelishishni taklif qildi: {1}.', [d.buyer.name, _m(meet)]);
            _news(NewsKind.transfer, trf('{0}: yangi taklif', [p.name]), d.note, alert: true);
          } else {
            collapse(trf('{0} muzokaradan chiqdi.', [d.buyer.name]));
          }
        case DealStage.medical:
          final issue = transferIssue(p, d.seller, d.buyer, d.fee);
          // The player decides too: keen players sign, unwilling ones refuse.
          final keen = moveInterest(p, d.buyer, d.seller).interest;
          if (issue == null && rnd.nextDouble() < (0.25 + keen / 100).clamp(0.1, 0.97)) {
            _completeTransfer(p, d.seller, d.buyer, d.fee);
            d
              ..stage = DealStage.done
              ..note = trf('{0} {1}ga o‘tdi.', [p.name, d.buyer.name]);
            _news(NewsKind.transfer, trf('{0} {1}ga sotildi', [p.name, d.buyer.name]),
                trf('Kelishuv summasi: {0}.', [_m(d.fee)]), alert: true);
          } else {
            collapse(issue ?? trf('{0} {1}ga o‘tishni rad etdi.', [p.name, d.buyer.name]));
          }
        case DealStage.clubCountered:
        case DealStage.contractTalks:
        case DealStage.offerReceived:
          // Waiting for the user too long.
          collapse(buying
              ? tr('Javob berilmagani uchun muzokara bekor bo‘ldi.')
              : trf('{0} javob kutib, taklifini qaytarib oldi.', [d.buyer.name]));
        default:
          break;
      }
    }
  }

  /// Answers all open negotiations at once (tests and debugging).
  @visibleForTesting
  void resolveDealsNow() {
    _processDeals(force: true);
    notifyListeners();
  }

  void _generateOffers() {
    final rnd = Random(_salt(_currentRound * 131 + calendar.year));
    if (userClub.squad.length <= minSquad) return;
    final targets = List<Player>.of(userClub.squad)
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final picks = <Player>[
      // Transfer-listed players are offered around.
      for (final p in userClub.squad)
        if (transferListed.contains(p.id) && rnd.nextDouble() < 0.6) p,
      for (var i = rnd.nextInt(3); i > 0; i--) targets[rnd.nextInt(min(10, targets.length))],
    ];
    for (final p in picks) {
      if (dealFor(p) != null || (movedThisSeason(p) && !transferListed.contains(p.id))) continue;
      final buyers = _allClubs
          .where((c) => c.id != _userClubId && c.transferBudget > p.marketValue)
          .toList();
      if (buyers.isEmpty) continue;
      final buyer = buyers[rnd.nextInt(buyers.length)];
      final listed = transferListed.contains(p.id);
      final fee = (p.marketValue * ((listed ? 0.75 : 0.9) + rnd.nextDouble() * 0.35) / 100000).round() * 100000;
      deals.add(TransferDeal(
        player: p,
        seller: userClub,
        buyer: buyer,
        fee: fee,
        stage: DealStage.offerReceived,
        dueRound: _currentRound + 3,
        note: trf('{0} {1} taklif qildi.', [buyer.name, _m(fee)]),
      ));
      _news(
        NewsKind.transfer,
        trf('{0} {1} uchun taklif yubordi', [buyer.name, p.shortName]),
        trf('{0} miqdoridagi taklif Transfer → Takliflar bo‘limida kutmoqda.', [_m(fee)]),
        alert: true,
      );
    }
  }

  /// AI clubs that already signed someone in the current window.
  final Set<String> _aiWindowBuyers = {};

  /// True when [p] changed clubs this season: nobody moves twice a year.
  bool movedThisSeason(Player p) => p.transfers.isNotEmpty && p.transfers.first.startsWith('$seasonLabel|');

  /// Real-life pace: a few AI clubs sign one player per window, only
  /// someone better than their weakest starter in that line, who wants to
  /// come, has not just moved, and whose club lets him go.
  void _simulateAITransfers() {
    final ai = _allClubs.where((c) => c.id != _userClubId).toList();
    final random = Random(_salt(_currentRound * 7919 + calendar.year));
    ai.shuffle(random);
    for (final buyer in ai) {
      if (_aiWindowBuyers.contains(buyer.id) || random.nextDouble() > 0.09) continue;
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
      final line = weakest.first;
      final starters = [for (final p in buyer.startingXI) if (p.mainPosition.category == line) p.ovr];
      if (starters.isEmpty) continue;
      final weakestStarter = starters.reduce(min);
      final candidates = <({Player player, Club seller})>[];
      for (final seller in ai.where((c) => c.id != buyer.id)) {
        for (final p in [...seller.bench, ...seller.reserves]) {
          if (p.mainPosition.category == line &&
              p.ovr > weakestStarter &&
              !movedThisSeason(p) &&
              (p.ovr < 85 || random.nextDouble() < 0.1) &&
              !sellerStance(p, seller, buyer).notForSale &&
              moveInterest(p, buyer, seller).interest >= 50 &&
              transferIssue(p, seller, buyer) == null) {
            candidates.add((player: p, seller: seller));
          }
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => b.player.ovr.compareTo(a.player.ovr));
        final target = candidates[random.nextInt(min(3, candidates.length))];
        _completeTransfer(target.player, target.seller, buyer);
        _aiWindowBuyers.add(buyer.id);
      }
    }
  }

  /// Out-of-contract players can be signed at any time (as in real
  /// football); the club only pays a signing bonus of eight weeks' wages.
  String? freeAgentIssue(Player p) {
    final c = userClub;
    if (c.squad.length >= maxSquad) return trf('Ro‘yxat to‘la: ko‘pi bilan {0} futbolchi.', [maxSquad]);
    final wage = max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
    if (c.remainingWageBudget < wage) return tr('Haftalik maosh limiti yetarli emas.');
    if (c.transferBudget < wage * 8) return tr('Imzo bonusi uchun mablag‘ yetarli emas.');
    return null;
  }

  bool signFreeAgent(Player p) {
    lastTransferError = freeAgentIssue(p);
    if (lastTransferError != null || !freeAgents.contains(p)) return false;
    final wage = max(p.contract.weeklyWage, p.calculatedRenewalWageDemand);
    freeAgents.remove(p);
    p.contract = p.contract.copyWith(contractYears: p.age >= 32 ? 1 : 2, weeklyWage: wage);
    p.morale = 85;
    _post(userClub, trf('{0}: imzo bonusi', [p.shortName]), -wage * 8, category: FinanceCategory.agent);
    userClub.squad.add(p);
    if (userClub.benchIds.length < Club.matchdayBench) userClub.benchIds.add(p.id);
    transferHistory.insert(
      0,
      TransferRecord(_currentRound, p.name, tr('Erkin agent'), userClub.name, 0, date: currentDate),
    );
    p.transfers.insert(0, '$seasonLabel|-|${userClub.name}|0||${userClub.id}');
    _news(NewsKind.transfer, trf('{0} imzoladi', [p.name]), trf('Erkin agent sifatida {0} yillik shartnoma.', [p.contract.contractYears]));
    notifyListeners();
    return true;
  }

  void _seedFreeAgents() {
    final rnd = Random(_salt(calendar.year * 3 + 11));
    const positions = ['GK', 'CB', 'CB', 'LB', 'RB', 'DMF', 'CMF', 'AMF', 'LWF', 'RWF', 'CF', 'CF'];
    for (var i = 0; i < positions.length; i++) {
      final pool = InitialDatabase.randomPool(rnd);
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
      ? trf('Ro‘yxat to‘la: ko‘pi bilan {0} futbolchi. Avval kimnidir soting.', [maxSquad])
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
      contract: PlayerContract(contractYears: 3, weeklyWage: 10000),
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
    // A new signing goes on the matchday bench; if it is full, the weakest
    // outfield substitute drops to the reserves to make room.
    if (club.benchIds.length >= Club.matchdayBench) {
      final outfield = club.bench.where((b) => !b.mainPosition.isGoalkeeper).toList()
        ..sort((a, b) => a.ovr.compareTo(b.ovr));
      if (outfield.isNotEmpty) club.benchIds.remove(outfield.first.id);
    }
    if (club.benchIds.length < Club.matchdayBench) club.benchIds.add(draft.id);
    _news(
      NewsKind.transfer,
      trf('{0} jamoaga qo‘shildi', [draft.name]),
      trf('Yangi futbolchi yaratildi: {0}, OVR {1}, salohiyat {2}. Haftalik maosh {3}.', [draft.mainPosition.code, draft.ovr, draft.potential, _m(draft.contract.weeklyWage)]),
    );
    notifyListeners();
    return draft;
  }

  bool _unhappyWithMinutes(Player p) {
    final played = _fixtures.where((f) => f.isPlayed && f.involves(userClub.id)).length;
    final share = played == 0 ? 1.0 : p.seasonMinutes / (played * 90);
    return played >= 4 && share < 0.3 && p.age < 31;
  }

  /// What the player really wants per week (his agent's figure): base
  /// demand adjusted for character, playing time, mood and club stature.
  int renewalDemand(Player p) {
    var demand = p.calculatedRenewalWageDemand.toDouble();
    demand *= switch (p.personality) {
      Personality.ambitious => 1.15,
      Personality.loyal => 0.9,
      _ => 1.0,
    };
    if (_unhappyWithMinutes(p)) demand *= 1.2;
    if (p.morale < 45) demand *= 1.15;
    if (p.ovr > userClub.reputation + 4) demand *= 1.1;
    return (demand / 1000).round() * 1000;
  }

  /// The player's answer to a contract offer: he weighs the wage against his
  /// demand, the length he wants, his playing time, mood and character.
  ({String status, int wage, int years, String message}) proposeRenewal(Player p, int years, int wage) {
    final club = userClub;
    if (club.remainingWageBudget + p.contract.weeklyWage < wage) {
      return (status: 'budget', wage: wage, years: years, message: tr('Maosh limiti yetarli emas'));
    }
    final unhappyTime = _unhappyWithMinutes(p);
    final demand = renewalDemand(p) * (0.97 + Random(p.id.hashCode + _currentRound).nextDouble() * 0.06);
    final wanted = p.age <= 23 ? 4 : p.age <= 29 ? 3 : 2;
    final yearsOk = p.age >= 31 ? years >= 1 : (years - wanted).abs() <= 1;
    if (unhappyTime && p.personality == Personality.ambitious && years > 2) {
      return (status: 'rejected', wage: wage, years: years, message: tr('Kam o‘ynayapman. Uzoq muddatli shartnomaga hozir tayyor emasman.'));
    }
    if (wage >= demand && yearsOk) {
      renewContract(p, years, wage);
      return (status: 'accepted', wage: wage, years: years, message: tr('Shartnoma imzolandi'));
    }
    if (wage >= demand * 0.82) {
      final counter = (demand / 1000).ceil() * 1000;
      return (
        status: 'counter',
        wage: counter,
        years: yearsOk ? years : wanted,
        message: trf('Haftasiga {0} va {1} yillik shartnomaga roziman.', [_m(counter), yearsOk ? years : wanted]),
      );
    }
    p.morale = max(0, p.morale - 4);
    return (status: 'rejected', wage: wage, years: years, message: tr('Bu taklif meni hurmat qilmaydi. Rad etaman.'));
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
      // Merit payments: the 20-club league pays about £2.4M per place.
      final prize = table.length <= 8
          ? prizes[i.clamp(0, 7)] * 1000000
          : ((20 + (table.length - 1 - i) * 2.4) * leagueInfo.economy).round() * 1000000;
      _post(club, trf('Liga mukofot puli · {0}-o‘rin', [i + 1]), prize,
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
    final pts = standingOf(_userClubId!).points;
    if (pts > life.bestPoints) {
      life.bestPoints = pts;
      life.bestPointsSeason = '$seasonLabel · ${userClub.name}';
    }
    if (life.bestFinish == 0 || userPos < life.bestFinish) {
      life.bestFinish = userPos;
      life.bestFinishSeason = '$seasonLabel · ${leagueInfo.name}';
    }
    // The season against expectations moves the manager's reputation; clubs
    // around the world with a matching reputation then call.
    final ranked = List<Club>.of(_allClubs)..sort((a, b) => b.squadDepthRating.compareTo(a.squadDepthRating));
    final expectedRank = ranked.indexWhere((c) => c.id == _userClubId) + 1;
    final scale = 20 / max(8, _allClubs.length);
    _managerProfile.reputation = (_managerProfile.reputation +
            (expectedRank - userPos) * 0.9 * scale +
            (champion.id == _userClubId ? 6 : 0) +
            (met ? 2 : -3) +
            (userPos > _allClubs.length - leagueInfo.relegate ? -6 : 0))
        .clamp(1.0, 99.0);
    _offerJobs();
    final deal = life.sponsor;
    if (deal != null && deal['type'] == 'target' && met) {
      _post(userClub, trf('Homiy maqsad bonusi: {0}', [deal['name']]), (deal['bonus'] as int) * (userPos == 1 ? 2 : 1),
          category: FinanceCategory.commercial);
    }
    CoinWallet().reward((champion.id == _userClubId ? CoinWallet.titleReward : 0) + (met ? CoinWallet.objectiveReward : 0));
    if (champion.id == _userClubId) life.trophies.insert(0, trf('{0} · {1} chempioni', [seasonLabel, leagueInfo.name]));
    _seasonAwards();
    boardConfidence = (boardConfidence + (met ? 15 : -20)).clamp(5, 100);
    final style = ManagerPhilosophy.forStyle(userClub.tactics.playstyle);
    final bonus = (userPos == 1 ? 24 : userPos <= 3 ? 16 : 0) + (met ? 8 : 0);
    if (bonus > 0) _managerProfile.gainExperience(style, bonus);
    _news(
      NewsKind.award,
      champion.id == _userClubId ? trf('CHEMPION! {0}', [champion.name]) : trf('{0} – chempion', [champion.name]),
      trf('Mavsum {0} yakunlandi. {1}: {2}-o‘rin. Kengash maqsadi ({3}) {4}.', [seasonLabel, userClub.name, userPos, objective.title, met ? tr('bajarildi') : tr('bajarilmadi')]),
    );
    final best = topRated.firstOrNull;
    if (scorer != null || best != null) {
      _news(
        NewsKind.award,
        tr('Mavsum mukofotlari'),
        '${scorer != null ? trf('Oltin butsa: {0} – {1} gol. ', [scorer.player.name, scorer.player.seasonGoals]) : ''}'
            '${best != null ? trf('Eng yuqori reyting: {0} ({1}).', [best.player.name, best.player.averageRating!.toStringAsFixed(2)]) : ''}',
      );
    }
    _resolvePyramid();
    final move = pendingMoves[_userClubId];
    if (move != null && InitialDatabase.info(move).tier < leagueInfo.tier) {
      CoinWallet().reward(CoinWallet.promotionReward);
      life.trophies.insert(0, trf('{0} · {1}ga ko‘tarilish', [seasonLabel, InitialDatabase.info(move).name]));
    }
  }

  /// Finishes the background leagues, plays the play-offs and decides who
  /// goes up and down. Moves are applied in [startNextSeason].
  void _resolvePyramid() {
    pendingMoves.clear();
    final pyramid = InitialDatabase.pyramidOf(leagueId);
    if (pyramid.length < 2) return;
    final rnd = Random(_salt(calendar.year * 41));
    for (final d in divisions.values) {
      d.playUntil(DateTime(9999), rnd);
    }
    List<Club> table(LeagueInfo l) => l.id == leagueId
        ? [for (final s in sortedStandings) getClubById(s.clubId)!]
        : [for (final s in divisions[l.id]!.sorted) divisions[l.id]!.club(s.clubId)!];
    for (var i = 0; i < pyramid.length; i++) {
      final l = pyramid[i];
      final t = table(l);
      if (l.id != leagueId) {
        _news(NewsKind.award, trf('{0}: {1} chempion', [l.name, t.first.name]),
            trf('Mavsum {0}. {1} {2} chempioni bo‘ldi.', [seasonLabel, t.first.name, l.name]),
            alert: false);
      }
      if (i + 1 < pyramid.length) {
        for (final c in t.reversed.take(l.relegate)) {
          pendingMoves[c.id] = pyramid[i + 1].id;
        }
      }
      if (i > 0) {
        final up = t.take(l.promote).toList();
        if (l.hasPlayoff && t.length >= l.playoffTo) {
          final lines = <String>[];
          final seeds = t.sublist(l.playoffFrom - 1, l.playoffTo);
          final winner = playoff(seeds, rnd, lines.add);
          up.add(winner);
          final mine = seeds.any((c) => c.id == _userClubId);
          _news(
            NewsKind.match,
            trf('{0} pley-off: {1} ko‘tarildi', [l.name, winner.name]),
            lines.join(' · '),
            alert: mine,
          );
        }
        for (final c in up) {
          pendingMoves[c.id] = pyramid[i - 1].id;
        }
      }
    }
    String names(bool upward) => pendingMoves.entries
        .where((e) => (InitialDatabase.info(e.value).tier < InitialDatabase.info(leagueOfClub(e.key)).tier) == upward)
        .map((e) => getClubById(e.key)!.shortName)
        .join(', ');
    _news(NewsKind.board, tr('Ko‘tarilish va tushish'), trf('Ko‘tarildi: {0}. Tushdi: {1}.', [names(true), names(false)]), alert: false);
    final target = pendingMoves[_userClubId];
    if (target != null) {
      final up = InitialDatabase.info(target).tier < leagueInfo.tier;
      final name = InitialDatabase.leagueName(target);
      boardConfidence = (boardConfidence + (up ? 25 : -30)).clamp(5, 100);
      if (up) _managerProfile.trophies++;
      _news(
        up ? NewsKind.award : NewsKind.board,
        up ? trf('KO‘TARILDINGIZ! {0} → {1}', [userClub.name, name]) : trf('{0} {1} ga tushib ketdi', [userClub.name, name]),
        up
            ? trf('Tarixiy mavsum! Keyingi mavsum {0} {1} da o‘ynaydi.', [userClub.name, name])
            : tr('Kengash qayta ko‘tarilishni kutmoqda. Kompensatsiya to‘lovlari byudjetni yumshatadi.'),
        alert: true,
      );
    }
  }

  /// Applies [pendingMoves]: clubs change league, reputations shift, and
  /// relegated top-flight sides get parachute money.
  void _applyMoves() {
    if (pendingMoves.isEmpty) return;
    final members = <String, List<Club>>{
      leagueId: List.of(_allClubs),
      for (final d in divisions.values) d.id: List.of(d.clubs),
    };
    for (final e in pendingMoves.entries) {
      final from = leagueOfClub(e.key);
      final club = getClubById(e.key);
      if (club == null || members[e.value] == null) continue;
      members[from]!.remove(club);
      members[e.value]!.add(club);
      final fromInfo = InitialDatabase.info(from), toInfo = InitialDatabase.info(e.value);
      final up = toInfo.tier < fromInfo.tier;
      club.reputation = (club.reputation + (up ? 4 : -4)).clamp(30, 99);
      if (!up && fromInfo.tier == 1) {
        _post(club, trf('Parashyut to‘lovi ({0})', [fromInfo.name]), 35000000, category: FinanceCategory.prize);
      } else if (up && toInfo.tier == 1) {
        _post(club, trf('{0}ga ko‘tarilish bonusi', [toInfo.name]), 15000000, category: FinanceCategory.prize);
      } else if (up) {
        _post(club, tr('Ko‘tarilish bonusi'), 3000000, category: FinanceCategory.prize);
      }
    }
    leagueId = members.entries.firstWhere((e) => e.value.any((c) => c.id == _userClubId)).key;
    _allClubs = members[leagueId]!;
    divisions.clear();
    for (final e in members.entries) {
      if (e.key == leagueId) continue;
      divisions[e.key] = Division(e.key, e.value, SeasonCalendar(calendar.year + 1, (e.value.length - 1) * 2));
    }
    pendingMoves.clear();
  }

  /// Ages the league, develops players, renews or releases contracts,
  /// adds academy graduates and builds a fresh fixture list.
  void startNextSeason() {
    if (!seasonFinished) return;
    final rnd = Random(_salt(calendar.year * 17));
    final lastTable = sortedStandings, lastCup = cup?.winner, lastLeague = leagueId;
    // Round numbers restart: trips still abroad report now.
    _finishScoutTrips(all: true);
    _returnLoans(rnd);
    life.jobOffers.clear();
    final wasLeague = leagueId;
    _applyMoves();
    calendar = SeasonCalendar(calendar.year + 1, totalRounds);
    final released = <String>[];
    for (final club in domesticClubs) {
      final user = club.id == _userClubId;
      for (final p in List<Player>.of(club.squad)) {
        p.history.insert(
          0,
          trf('{0}/{1}: {2} o‘yin, {3} gol, {4} assist{5}', [calendar.year - 1, calendar.year % 100, p.seasonMatches, p.seasonGoals, p.seasonAssists, p.averageRating != null ? ', ${p.averageRating!.toStringAsFixed(2)}' : '']),
        );
        p.careerSeasons.insert(0, [
          '${calendar.year - 1}/${calendar.year % 100}',
          club.id,
          club.name,
          p.seasonMatches,
          p.seasonGoals,
          p.seasonAssists,
          p.averageRating?.toStringAsFixed(2) ?? '',
        ].join('|'));
        _develop(p, rnd);
        p.resetSeasonStats();
        p.currentStamina = 100;
        p.injuryRounds = 0;
        p.injury = null;
        p.suspensionRounds = 0;
        final years = p.contract.contractYears - 1;
        if (p.age >= 37 && rnd.nextDouble() < 0.7) {
          _remove(club, p);
          if (user) released.add(trf('{0} (faoliyatini yakunladi)', [p.shortName]));
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
      if (user) {
        _academyIntake(club, rnd);
      } else {
        for (var i = 0; i < 2; i++) {
          if (club.squad.length >= maxSquad) break;
          final youth = _youthProspect(club, rnd, i);
          club.squad.add(youth);
        }
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
    // Released AI players flood the market; keep the best of them.
    if (freeAgents.length > 80) {
      freeAgents.sort((a, b) => b.ovr.compareTo(a.ovr));
      freeAgents.removeRange(80, freeAgents.length);
    }
    final u = userClub;
    if (u.startingXI.length < 11) autoPickLineup(u);
    _ensureMatchdaySquad(u);
    seasonFinished = false;
    deals.clear();
    _generateSeasonSchedule();
    _drawCup();
    _offerSponsors();
    if (leagueId == lastLeague) _setupSuperCup(lastTable, lastCup);
    _initializeStandings();
    for (final d in divisions.values) {
      d.calendar = SeasonCalendar(calendar.year, d.rounds);
      d.newSeason(_salt(calendar.year * 3 + InitialDatabase.info(d.id).tier));
    }
    _currentRound = 1;
    objective = _objectiveFor(u);
    _news(
      NewsKind.board,
      trf('Yangi mavsum: {0}{1}', [seasonLabel, wasLeague != leagueId ? ' · ${leagueInfo.name}' : '']),
      trf('Kengash maqsadi: {0}. Akademiyadan {1} ta yosh futbolchi asosiy jamoaga ko‘tarildi.{2}', [objective.title, life.lastIntake.length, released.isNotEmpty ? trf(' Klubni tark etganlar: {0}.', [released.join(', ')]) : '']),
    );
    _news(
      NewsKind.window,
      tr('Yozgi transfer oynasi ochiq'),
      trf('Oyna {0} gacha ishlaydi.', [SeasonCalendar.format(calendar.summerClose)]),
    );
    balanceHistory
      ..clear()
      ..add(u.transferBudget);
    // Foreign squads age a year too (rebuilt from the files in the background).
    if (world.countries.isNotEmpty || world.missions.isNotEmpty) refreshWorld();
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

  void _develop(Player p, Random rnd) => WorldMarket.develop(p, rnd);

  Player _youthProspect(Club club, Random rnd, int i, {int? ovr, int? potential, int? age, String? nationality}) {
    // Academies mostly produce players from the club's own country.
    final pool = nationality != null
        ? InitialDatabase.randomPool(rnd, prefer: nationality, preferShare: 1)
        : InitialDatabase.randomPool(rnd, prefer: InitialDatabase.info(leagueOfClub(club.id)).country);
    final first = pool['firstNames'] as List, last = pool['lastNames'] as List;
    final name = '${first[rnd.nextInt(first.length)]} ${last[rnd.nextInt(last.length)]}';
    const positions = ['CB', 'CMF', 'CF', 'LWF', 'RB', 'DMF', 'AMF', 'GK'];
    final pos = PlayerPosition.fromCode(positions[rnd.nextInt(positions.length)]);
    final target = ovr ?? 58 + rnd.nextInt(9);
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
      age: age ?? 17 + rnd.nextInt(2),
      nationality: pool['nationality'] as String,
      countryFlag: pool['flag'] as String,
      number: number,
      mainPosition: pos,
      altPositions: const [],
      preferredFoot: rnd.nextInt(4) == 0 ? PreferredFoot.left : PreferredFoot.right,
      weakFoot: 2 + rnd.nextInt(3),
      stats: stats,
      contract: PlayerContract(contractYears: 3, weeklyWage: 8000),
      marketValue: Player.valuation(target, 17, target + 18),
      potential: potential ?? (target + 12 + rnd.nextInt(16)).clamp(70, 92),
    );
  }

  // ------------------------------------------------------------ club life
  /// Academy graduates: more and better with a bigger academy, sometimes a
  /// "golden generation" wonderkid with 85–92 potential.
  void _academyIntake(Club club, Random rnd) {
    final level = life.level(Facility.academy);
    final count = 2 + (level >= 2 ? 1 : 0) + (level >= 4 ? 1 : 0) - (rnd.nextDouble() < 0.3 ? 1 : 0) + 1;
    life.lastIntake.clear();
    final names = <String>[];
    for (var i = 0; i < count && club.squad.length < maxSquad; i++) {
      final wonderkid = rnd.nextDouble() < 0.04 + 0.04 * level;
      final ovr = 55 + level * 2 + rnd.nextInt(8) + (wonderkid ? 5 : 0);
      final potential = wonderkid ? 85 + rnd.nextInt(8) : (ovr + 10 + rnd.nextInt(12) + level).clamp(68, 86);
      final youth = _youthProspect(club, rnd, i, ovr: ovr, potential: potential, age: 16 + rnd.nextInt(3));
      youth.marketValue = Player.valuation(youth.ovr, youth.age, youth.potential);
      club.squad.add(youth);
      life.lastIntake.add(youth.id);
      names.add('${wonderkid ? '⭐ ' : ''}${youth.name} (${youth.mainPosition.code}, ${youth.ovr}→${youth.potential})');
    }
    if (names.isNotEmpty) {
      _news(NewsKind.board, tr('Akademiyadan yangi avlod'), names.join(', '), alert: names.any((n) => n.startsWith('⭐')));
    }
  }

  /// Starts a facility upgrade; returns an error message or null.
  String? upgradeFacility(Facility f) {
    final c = userClub;
    final level = life.level(f);
    if (level >= Facility.maxLevel) return tr('Eng yuqori darajaga yetgan.');
    if (life.building.containsKey(f)) return tr('Qurilish allaqachon ketmoqda.');
    if (f == Facility.stadium && c.stadiumCapacity >= 80000) return tr('Stadion maksimal sig‘imda.');
    final cost = ClubLife.upgradeCost(f, level, _economyOf(c));
    if (c.transferBudget < cost) return tr('Byudjet yetarli emas.');
    _post(c, trf('{0}: {1}-bosqich qurilishi', [f.label, level + 1]), -cost, category: FinanceCategory.operations);
    life.building[f] = _currentRound + ClubLife.buildRounds(f);
    _news(NewsKind.board, trf('{0}: qurilish boshlandi', [f.label]),
        trf('{0}-bosqich {1} turdan keyin ishga tushadi. Narxi {2}.', [level + 1, ClubLife.buildRounds(f), _m(cost)]));
    notifyListeners();
    return null;
  }

  int facilityCost(Facility f) => ClubLife.upgradeCost(f, life.level(f), _economyOf(userClub));

  void setTrainingFocus(TrainingFocus f) {
    life.focus = f;
    notifyListeners();
  }

  /// Sets (or clears with null) a player's individual training target: an
  /// attribute key or `style:<PlayingStyle name>`.
  void setTrainingTarget(Player p, String? target) {
    if (target == null) {
      life.targets.remove(p.id);
    } else {
      life.targets[p.id] = target;
    }
    life.progress.remove(p.id);
    notifyListeners();
  }

  static const _focusAttributes = <TrainingFocus, List<String>>{
    TrainingFocus.attacking: ['finishing', 'attackingAwareness', 'dribbling', 'kickingPower', 'curl'],
    TrainingFocus.defensive: ['defensiveAwareness', 'tackling', 'defensiveEngagement', 'heading'],
    TrainingFocus.fitness: ['stamina', 'speed', 'acceleration', 'physicalContact'],
    TrainingFocus.tactical: ['lowPass', 'loftedPass', 'ballControl', 'tightPossession'],
  };

  /// Weekly: constructions finish, individual and team training progress.
  void _weeklyClubLife(int days) {
    final c = userClub;
    for (final f in List.of(life.building.keys)) {
      if (_currentRound < life.building[f]!) continue;
      life.building.remove(f);
      life.levels[f] = life.level(f) + 1;
      var detail = trf('{0}-bosqich ishga tushdi.', [life.level(f)]);
      if (f == Facility.stadium) {
        final add = ClubLife.seatsAdded(c.stadiumCapacity);
        c.stadiumCapacity += add;
        detail = trf('+{0} o‘rindiq. Yangi sig‘im: {1}.', [add, c.stadiumCapacity]);
      }
      _news(NewsKind.board, trf('{0} tayyor', [f.label]), detail, alert: true);
    }
    final rnd = Random(_salt(_currentRound * 7919));
    final focusKeys = _focusAttributes[life.focus];
    for (final p in c.squad) {
      if (life.focus == TrainingFocus.fitness) p.currentStamina = min(100, p.currentStamina + 5);
      final rate = (p.age <= 21 ? 0.42 : p.age <= 24 ? 0.3 : p.age <= 28 ? 0.18 : p.age <= 31 ? 0.1 : 0.05) *
          life.growthFactor *
          (p.mainPosition.isGoalkeeper ? 1 + 0.2 * life.staffLevel(StaffRole.goalkeeping) : 1) *
          switch (p.personality) {
            Personality.professional => 1.3,
            Personality.lazy => 0.6,
            _ => 1.0,
          } *
          (p.isInjured ? 0.2 : 1);
      final target = life.targets[p.id];
      if (target != null && target.startsWith('style:')) {
        final style = PlayingStyle.values.asNameMap()[target.substring(6)];
        if (style == null) continue;
        final v = (life.progress[p.id] ?? 0) + rate;
        if (v >= 4) {
          life.progress.remove(p.id);
          life.targets.remove(p.id);
          p.playingStyle = style;
          _news(NewsKind.award, trf('{0} yangi uslubni o‘zlashtirdi', [p.shortName]), trf('Endi u {0} sifatida o‘ynaydi.', [style.title]));
        } else {
          life.progress[p.id] = v;
        }
        continue;
      }
      final key = target ?? (focusKeys == null ? null : focusKeys[rnd.nextInt(focusKeys.length)]);
      if (key == null) continue;
      final v = (life.progress[p.id] ?? 0) + rate * (target != null ? 1 : 0.3) * (focusKeys?.contains(key) == true ? 1.2 : 1);
      if (v < 1) {
        life.progress[p.id] = v;
        continue;
      }
      life.progress[p.id] = v - 1;
      final m = p.stats.toMap().map((k, x) => MapEntry(k, x as int));
      // Beyond the player's potential, gains become rare.
      if ((m[key] ?? 99) >= 99 || (p.ovr >= p.potential && rnd.nextDouble() < 0.7)) continue;
      m[key] = m[key]! + 1;
      p.stats = PlayerStats.fromMap(m);
      if (target != null && rnd.nextDouble() < 0.35) {
        _news(NewsKind.award, trf('{0}: mashg‘ulot natijasi', [p.shortName]),
            trf('{0} {1} ga oshdi.', [PlayerStats.labels[key], m[key]]),
            alert: false);
      }
    }
  }

  /// Applies the user's training focus to a match engine.
  void applyClubBoosts(MatchField f, bool userHome) {
    final leaders = userClub.startingXI.where((p) => p.personality == Personality.leader).length;
    final boost = min(4, leaders * 2) + life.staffLevel(StaffRole.assistant);
    if (userHome) {
      f.homeCoaching += boost;
    } else {
      f.awayCoaching += boost;
    }
    switch (life.focus) {
      case TrainingFocus.attacking:
        if (userHome) {
          f.homeAttackBoost *= 1.04;
        } else {
          f.awayAttackBoost *= 1.04;
        }
      case TrainingFocus.defensive:
        if (userHome) {
          f.homeFocus *= 0.95;
        } else {
          f.awayFocus *= 0.95;
        }
      case TrainingFocus.fitness:
        if (userHome) {
          f.homeFitness *= 0.88;
        } else {
          f.awayFitness *= 0.88;
        }
      case TrainingFocus.tactical:
        if (userHome) {
          f.homeCoaching += 4;
        } else {
          f.awayCoaching += 4;
        }
      case TrainingFocus.balanced:
        break;
    }
  }

  static const _rivalries = {
    'real_madrid|barcelona', 'epl_new|epl_sun', 'epl_ars|epl_tot', 'epl_liv|epl_eve', 'epl_mci|epl_mun',
    'uz_pak|uz_bun', 'uz_nef|uz_and', 'uz_nav|uz_nef', 'uz_nas|uz_bux',
  };

  /// Derby: a classic rivalry or two clubs from the same city.
  bool isDerby(Club a, Club b) =>
      _rivalries.contains('${a.id}|${b.id}') ||
      _rivalries.contains('${b.id}|${a.id}') ||
      (a.city.isNotEmpty && a.city == b.city);

  /// The user's last results, newest first ('W', 'D', 'L').
  List<String> _recentResults(int n) {
    final mine = _fixtures.where((f) => f.isPlayed && f.involves(_userClubId!)).toList()
      ..sort((a, b) => b.round.compareTo(a.round));
    return [for (final f in mine.take(n)) f.resultFor(_userClubId!)];
  }

  /// Press questions before a match (null when the conference was held).
  /// Every match has one; the questions follow the club's situation.
  List<PressQuestion>? pressFor(Fixture f) {
    if (!f.involves(_userClubId!) || f.isPlayed || life.pressDone.contains(f.id)) return null;
    final user = userClub;
    final rival = getClubById(f.homeClubId == _userClubId ? f.awayClubId : f.homeClubId)!;
    final recent = _recentResults(4);
    var wins = 0, losses = 0;
    for (final r in recent) {
      if (r != 'W') break;
      wins++;
    }
    for (final r in recent) {
      if (r != 'L') break;
      losses++;
    }
    final signedNames = {
      for (final t in transferHistory.take(6))
        if (t.toClub == user.name) t.playerName,
    };
    final table = _standingsMap.isNotEmpty && _currentRound > 1;
    final context = PreMatchContext(
      user: user,
      rival: rival,
      rivalStar: (List.of(rival.squad)..sort((a, b) => b.ovr.compareTo(a.ovr))).firstOrNull,
      unhappy: life.wantsOut.map(user.playerById).nonNulls.firstOrNull,
      newSigning: user.squad.where((p) => signedNames.contains(p.name)).firstOrNull,
      youngster: user.startingXI.where((p) => p.age <= 20).firstOrNull,
      derby: isDerby(user, rival),
      home: f.homeClubId == _userClubId,
      position: table ? positionOf(user.id) : 0,
      rivalPosition: table ? positionOf(rival.id) : 0,
      clubs: _allClubs.length,
      round: _currentRound,
      recentWins: wins,
      recentLosses: losses,
      injured: user.squad.where((p) => p.isInjured).length,
      board: boardConfidence,
    );
    return Press.preMatch(context, Random(_salt(f.id.hashCode)));
  }

  /// The last played user match, if its post-match conference is still open.
  Fixture? get postPressFixture {
    final last = _fixtures.where((f) => f.isPlayed && f.involves(_userClubId ?? '')).fold<Fixture?>(
          null,
          (best, f) => best == null || f.round > best.round ? f : best,
        );
    if (last == null || life.pressDone.contains('post_${last.id}')) return null;
    final next = nextUserFixture;
    if (next != null && next.round > last.round + 1) return null;
    return last;
  }

  /// Questions after [f]: the result, the referee, standout performances.
  List<PressQuestion>? postPressFor(Fixture f) {
    if (life.pressDone.contains('post_${f.id}')) return null;
    final home = f.homeClubId == _userClubId;
    final user = userClub;
    final rival = getClubById(home ? f.awayClubId : f.homeClubId);
    if (rival == null) return null;
    final ratings = [
      for (final e in f.ratings.entries)
        if (user.playerById(e.key) != null) (user.playerById(e.key)!, e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    bool against(MatchEventType t) => f.events.any((e) => e.type == t && e.isHomeTeam == home);
    final context = PostMatchContext(
      user: user,
      rival: rival,
      scored: (home ? f.homeScore : f.awayScore) ?? 0,
      conceded: (home ? f.awayScore : f.homeScore) ?? 0,
      best: ratings.firstOrNull?.$1,
      bestRating: ratings.firstOrNull?.$2 ?? 0,
      worst: ratings.length > 1 ? ratings.last.$1 : null,
      worstRating: ratings.length > 1 ? ratings.last.$2 : 10,
      redCardAgainst: against(MatchEventType.redCard),
      penaltyAgainst: f.events.any((e) => e.type == MatchEventType.penalty && e.isHomeTeam != home),
      derby: isDerby(user, rival),
    );
    return Press.postMatch(context, Random(_salt(f.id.hashCode + 3)));
  }

  /// Applies a conference: morale, fans, board, single players; the press
  /// quotes the boldest answer and the fans react.
  void answerPress(Fixture f, List<(PressQuestion, PressAnswer)> picks, {bool post = false}) {
    final user = userClub;
    var morale = 0, fans = 0, board = 0;
    for (final (_, a) in picks) {
      morale += a.morale;
      fans += a.fans;
      board += a.board;
      final p = a.playerId == null ? null : user.playerById(a.playerId!);
      if (p != null) {
        final hit = a.playerMorale < 0 && p.personality == Personality.temperamental ? a.playerMorale * 3 ~/ 2 : a.playerMorale;
        p.morale = (p.morale + hit).clamp(0, 100);
      }
    }
    for (final p in user.squad) {
      p.morale = (p.morale + morale).clamp(0, 100);
    }
    user.fanMood = (user.fanMood + fans).clamp(0, 100);
    boardConfidence = (boardConfidence + board).clamp(5, 100);
    // Criticising the referee costs a fine.
    if (picks.any((e) => e.$2.tone == PressTone.critical && e.$1.question == tr('Hakamlik qarorlari haqida nima deysiz?'))) {
      final fine = ((20000 * max(0.2, _economyOf(user))) / 1000).round() * 1000;
      _post(user, tr('Federatsiya jarimasi: hakamni tanqid'), -fine, category: FinanceCategory.operations);
      _news(NewsKind.board, tr('Federatsiya jarimasi'), trf('Hakamlik haqidagi gaplar uchun {0} jarima.', [_m(fine)]));
    }
    life.pressDone.add(post ? 'post_${f.id}' : f.id);
    final quoted = picks.where((e) => e.$2.tone != PressTone.calm).firstOrNull ?? picks.firstOrNull;
    if (quoted != null) {
      final rnd = Random(_salt(f.id.hashCode + (post ? 11 : 5)));
      for (final post in life.pressPosts(user, quoted.$1.outlet, quoted.$2.text, quoted.$2.tone, trf('{0} · {1}-tur', [seasonLabel, f.round]), rnd).reversed) {
        life.post(post);
      }
    }
    notifyListeners();
  }

  /// Weekly: journalists spread transfer rumours about the club.
  void _rumours() {
    final rnd = Random(_salt(_currentRound * 97 + calendar.year));
    if (rnd.nextDouble() > 0.35) return;
    final user = userClub;
    final when = trf('{0} · {1}-tur', [seasonLabel, _currentRound]);
    final buying = deals.where((d) => d.buyer.id == user.id && !d.stage.finished).firstOrNull;
    if (buying != null && rnd.nextBool()) {
      life.post(life.rumourPost(trf('Manbalar: {0} {1} bilan muzokara olib bormoqda 👀', [user.name, buying.player.name]), when, rnd));
      return;
    }
    final star = (List.of(user.squad)..sort((a, b) => b.ovr.compareTo(a.ovr))).take(3).toList();
    final bigger = domesticClubs.where((c) => c.reputation > user.reputation + 3).toList();
    if (star.isEmpty || bigger.isEmpty) return;
    final p = star[rnd.nextInt(star.length)], club = bigger[rnd.nextInt(bigger.length)];
    life.post(life.rumourPost(trf('Mish-mish: {0} {1}ni kuzatmoqda. Yozda taklif bo‘lishi mumkin 👀', [club.name, p.name]), when, rnd));
  }

  /// Fans react and records update after one of the user's matches.
  void _afterUserMatch(Fixture f) {
    final userHome = f.homeClubId == _userClubId;
    final user = userClub, rival = getClubById(userHome ? f.awayClubId : f.homeClubId)!;
    final scored = (userHome ? f.homeScore : f.awayScore) ?? 0, conceded = (userHome ? f.awayScore : f.homeScore) ?? 0;
    final goals = <String, int>{};
    int? firstSub;
    for (final e in f.events) {
      if (e.isHomeTeam != userHome) continue;
      if (e.type == MatchEventType.goal && e.playerName != null) goals[e.playerName!] = (goals[e.playerName!] ?? 0) + 1;
      if (e.type == MatchEventType.substitution && (firstSub == null || e.minute < firstSub)) firstSub = e.minute;
    }
    final ratings = [
      for (final e in f.ratings.entries)
        if (user.playerById(e.key) != null) (user.playerById(e.key)!, e.value),
    ];
    final rnd = Random(_salt(f.id.hashCode + 7));
    for (final post in life.matchPosts(
      user: user,
      rival: rival,
      scored: scored,
      conceded: conceded,
      userGoals: goals,
      ratings: ratings,
      firstSubMinute: firstSub,
      when: trf('{0} · {1}-tur', [seasonLabel, f.round]),
      rnd: rnd,
    ).reversed) {
      life.post(post);
    }
    life.recordMatch(user, rival, scored, conceded, seasonLabel, f.events);
    for (final p in user.squad) {
      if ((f.playerStats[p.id]?.minutes ?? 0) > 0) {
        life.benchRounds.remove(p.id);
        life.promises.remove(p.id);
      } else {
        life.benchRounds[p.id] = (life.benchRounds[p.id] ?? 0) + 1;
      }
    }
  }

  /// Players who expect to play: the best 14 of the squad.
  Set<String> _keyPlayers(Club c) =>
      (List.of(c.squad)..sort((a, b) => b.ovr.compareTo(a.ovr))).take(14).map((p) => p.id).toSet();

  /// Weekly dressing-room mood: playing time, promises and transfer requests.
  void _dressingRoom() {
    final c = userClub;
    final key = _keyPlayers(c);
    for (final p in c.squad) {
      final benched = life.benchRounds[p.id] ?? 0;
      final deadline = life.promises[p.id];
      if (deadline != null && _currentRound > deadline) {
        life.promises.remove(p.id);
        p.morale = max(0, p.morale - 15);
        _news(NewsKind.board, trf('{0} va’da buzilganidan norozi', [p.shortName]),
            tr('O‘yin vaqti haqidagi va’da bajarilmadi. Futbolchining kayfiyati keskin tushdi.'));
      }
      if (key.contains(p.id) && benched >= 3 && !p.isInjured && !life.promises.containsKey(p.id)) {
        p.morale = max(0, p.morale - switch (p.personality) {
          Personality.ambitious => 7,
          Personality.loyal || Personality.professional => 2,
          _ => 4,
        });
        if (p.personality == Personality.ambitious && p.morale < 45 && life.wantsOut.add(p.id)) {
          _news(NewsKind.transfer, trf('{0} klubni tark etmoqchi', [p.name]),
              tr('Futbolchi kam o‘ynayotganidan norozi va transfer so‘radi.'), alert: true);
        }
      } else if (benched == 0 && p.morale < 85) {
        p.morale = min(85, p.morale + 2);
      }
    }
    life.wantsOut.removeWhere((id) => c.playerById(id) == null);
  }

  // ------------------------------------------------------------ staff & scouting
  int staffWage(StaffRole r, int level) => ClubLife.staffWage(level, _economyOf(userClub));

  /// Hires (or promotes to) [level]; a signing fee of six weeks' wages.
  String? setStaff(StaffRole r, int level) {
    final c = userClub;
    final fee = level > life.staffLevel(r) ? staffWage(r, level) * 6 : 0;
    if (c.transferBudget < fee) return tr('Byudjet yetarli emas.');
    if (fee > 0) _post(c, trf('{0}: shartnoma bonusi', [r.label]), -fee, category: FinanceCategory.operations);
    life.staff[r] = level;
    notifyListeners();
    return null;
  }

  /// Players from the user's own league are known; others need a report.
  bool isScouted(Player p) =>
      _allClubs.any((c) => c.squad.contains(p)) || life.scouted.contains(p.id);

  /// What the scouts believe a player's OVR is (exact once scouted).
  (int, int) ovrRange(Player p) {
    if (isScouted(p)) return (p.ovr, p.ovr);
    final width = max(2, 7 - life.staffLevel(StaffRole.scouting));
    final bias = (p.id.hashCode % 5) - 2;
    return (p.ovr + bias - width ~/ 2, p.ovr + bias + width - width ~/ 2);
  }

  int get scoutCapacity => 2 + life.staffLevel(StaffRole.scouting);

  String? scoutPlayer(Player p) {
    if (isScouted(p)) return tr('Bu futbolchi allaqachon o‘rganilgan.');
    if (life.scoutQueue.length >= scoutCapacity) return tr('Barcha skautlar band.');
    life.scoutQueue[p.id] = _currentRound + max(1, 3 - life.staffLevel(StaffRole.scouting) ~/ 2);
    notifyListeners();
    return null;
  }

  // ------------------------------------------------------------ world scouting
  /// Countries scouts can travel to (every league outside the pyramid).
  List<String> get scoutDestinations =>
      WorldMarket.destinations(_pyramidIds(leagueId))..sort((a, b) => tr(a).compareTo(tr(b)));

  /// Trips abroad at the same time: one more for every two staff levels.
  int get worldScoutCapacity => 1 + life.staffLevel(StaffRole.scouting) ~/ 2;

  /// Rounds a trip takes (a better chief scout is quicker).
  int get worldScoutRounds => max(1, 3 - life.staffLevel(StaffRole.scouting) ~/ 2);

  /// Trip cost: richer football countries are dearer to cover.
  int worldScoutCost(String country) {
    final leagues = WorldMarket.leaguesOf(country, _pyramidIds(leagueId));
    final eco = leagues.isEmpty ? 0.1 : leagues.map((l) => l.economy).reduce(max);
    return ((30000 + 300000 * eco) * max(0.25, _economyOf(userClub)) / 1000).round() * 1000;
  }

  /// Sends scouts to [country]: its leagues load now (once), the report and
  /// the market open after [worldScoutRounds].
  Future<String?> sendScouts(String country) async {
    if (world.countries.contains(country)) return tr('Bu davlat allaqachon o‘rganilgan.');
    if (world.missions.containsKey(country)) return tr('Skautlar u yerda ishlamoqda.');
    if (world.missions.length >= worldScoutCapacity) return tr('Barcha skautlar band.');
    final cost = worldScoutCost(country);
    if (userClub.transferBudget < cost) return tr('Byudjet yetarli emas.');
    await world.loadCountry(country, _pyramidIds(leagueId), _prepareWorldClub);
    _post(userClub, trf('Skaut safari: {0}', [tr(country)]), -cost, category: FinanceCategory.operations);
    world.missions[country] = _currentRound + worldScoutRounds;
    _news(NewsKind.transfer, trf('Skautlar {0}ga jo‘nadi', [tr(country)]),
        trf('Hisobot {0} turdan keyin keladi; shundan so‘ng bu davlat klublari transfer bozorida.', [worldScoutRounds]));
    notifyListeners();
    return null;
  }

  /// Finished trips: the country joins the market and the scouts name its
  /// best talents and stars (now fully scouted).
  void _finishScoutTrips({bool all = false}) {
    for (final e in List.of(world.missions.entries)) {
      if (!all && _currentRound < e.value) continue;
      world.missions.remove(e.key);
      world.countries.add(e.key);
      final pool = [
        for (final c in world.clubs)
          if (countryOfClub(c.id) == e.key)
            for (final p in c.squad) p,
      ];
      final talents = pool.where((p) => p.age <= 21).toList()
        ..sort((a, b) => (b.potential * 2 - b.age).compareTo(a.potential * 2 - a.age));
      final stars = List.of(pool)..sort((a, b) => b.ovr.compareTo(a.ovr));
      final picks = <Player>{...talents.take(3), ...stars.take(3)};
      life.scouted.addAll(picks.map((p) => p.id));
      _news(
        NewsKind.transfer,
        trf('Skaut hisoboti: {0}', [tr(e.key)]),
        trf('{0} ta klub bozorda. Diqqatga sazovor: {1}.', [
          {for (final c in world.clubs) if (countryOfClub(c.id) == e.key) c.id}.length,
          picks.map((p) => '${p.name} (${p.mainPosition.code}, ${p.age}, ${p.ovr}→${p.potential})').join(', '),
        ]),
        alert: true,
      );
    }
  }

  String? startYouthMission(String nationality) {
    if (life.youthMission != null) return tr('Skautlar hozir boshqa topshiriqda.');
    life.youthMission = nationality;
    life.youthMissionDue = _currentRound + 3;
    notifyListeners();
    return null;
  }

  Player? findPlayerById(String id) {
    for (final c in marketClubs) {
      final p = c.playerById(id);
      if (p != null) return p;
    }
    return freeAgents.where((p) => p.id == id).firstOrNull;
  }

  /// Weekly: staff wages, finished scouting reports and youth searches.
  void _weeklyStaff() {
    final c = userClub;
    final wages = StaffRole.values.fold<int>(0, (a, r) => a + staffWage(r, life.staffLevel(r)));
    if (wages > 0) _post(c, tr('Murabbiylar shtabi maoshi'), -wages, category: FinanceCategory.operations);
    final fitness = life.staffLevel(StaffRole.fitness);
    if (fitness > 0) {
      for (final p in c.squad) {
        p.currentStamina = min(100, p.currentStamina + fitness * 2);
      }
    }
    _finishScoutTrips();
    for (final e in List.of(life.scoutQueue.entries)) {
      if (_currentRound < e.value) continue;
      life.scoutQueue.remove(e.key);
      life.scouted.add(e.key);
      final p = findPlayerById(e.key);
      if (p != null) {
        _news(NewsKind.transfer, trf('Skaut hisoboti: {0}', [p.name]),
            trf('OVR {0}, salohiyat {1}, xarakter: {2}. Bozor bahosi {3}.', [p.ovr, p.potential, p.personality.label, _m(p.marketValue)]));
      }
    }
    final nat = life.youthMission;
    if (nat != null && _currentRound >= life.youthMissionDue) {
      life.youthMission = null;
      final rnd = Random(_salt(_currentRound * 313));
      final level = life.staffLevel(StaffRole.scouting);
      final names = <String>[];
      for (var i = 0; i < 2 + (level >= 3 ? 1 : 0); i++) {
        final star = rnd.nextDouble() < 0.1 + level * 0.05;
        final ovr = 56 + rnd.nextInt(8) + level + (star ? 5 : 0);
        final p = _youthProspect(c, rnd, 50 + i, ovr: ovr, potential: star ? 84 + rnd.nextInt(8) : ovr + 10 + rnd.nextInt(10), age: 16 + rnd.nextInt(4), nationality: nat);
        final prospect = Player.fromMap({...p.toMap(), 'id': 'scout_${calendar.year}_${_currentRound}_$i'});
        freeAgents.add(prospect);
        life.scouted.add(prospect.id);
        names.add('${star ? '⭐ ' : ''}${prospect.name} (${prospect.mainPosition.code}, ${prospect.ovr}→${prospect.potential})');
      }
      _news(NewsKind.transfer, trf('Skautlar {0}dan yosh iste’dodlar topdi', [tr(nat)]),
          trf('{0}. Ular erkin agentlar ro‘yxatida.', [names.join(', ')]), alert: true);
    }
  }

  // ------------------------------------------------------------ loans & jobs
  /// A club where [p] would play regularly: a lower division when there is
  /// one, otherwise a weaker club in this league.
  Club? loanDestination(Player p) {
    final pyramid = InitialDatabase.pyramidOf(leagueId);
    final lower = [
      for (var i = pyramid.indexWhere((l) => l.id == leagueId) + 1; i < pyramid.length; i++)
        ...?divisions[pyramid[i].id]?.clubs,
    ];
    final pool = lower.isNotEmpty ? lower : _allClubs.where((c) => c.id != _userClubId).toList();
    final fits = pool.where((c) {
      final xi = (List.of(c.squad)..sort((a, b) => b.ovr.compareTo(a.ovr))).take(11).toList();
      return xi.isNotEmpty && p.ovr >= xi.last.ovr;
    }).toList()
      ..sort((a, b) => b.reputation.compareTo(a.reputation));
    return fits.firstOrNull ?? (pool..sort((a, b) => a.reputation.compareTo(b.reputation))).firstOrNull;
  }

  /// Sends a player on a season-long loan; he returns (developed) in summer.
  String? loanOut(Player p) {
    final c = userClub;
    if (!c.squad.contains(p)) return tr('Futbolchi jamoada emas.');
    if (c.squad.length <= minSquad) return tr('Tarkibda futbolchi yetishmaydi.');
    final dest = loanDestination(p);
    if (dest == null) return tr('Mos klub topilmadi.');
    _remove(c, p);
    dest.squad.add(p);
    life.loans[p.id] = dest.id;
    _ensureMatchdaySquad(c);
    _news(NewsKind.transfer, trf('{0} ijaraga ketdi', [p.name]), trf('Mavsum oxirigacha {0} safida o‘ynaydi.', [dest.name]));
    notifyListeners();
    return null;
  }

  /// Loaned players come back; regular football has made them better.
  void _returnLoans(Random rnd) {
    for (final e in List.of(life.loans.entries)) {
      final dest = marketClubs.where((c) => c.id == e.value).firstOrNull;
      final p = dest?.playerById(e.key);
      if (dest == null || p == null) {
        life.loans.remove(e.key);
        continue;
      }
      _remove(dest, p);
      if (p.ovr < p.potential) {
        final m = p.stats.toMap().map((k, v) => MapEntry(k, v as int));
        final gain = 1 + rnd.nextInt(3);
        for (final k in _keyAttributes(p.mainPosition)) {
          m[k] = (m[k]! + gain).clamp(40, 99);
        }
        p.stats = PlayerStats.fromMap(m);
      }
      userClub.squad.add(p);
      life.loans.remove(e.key);
      _news(NewsKind.transfer, trf('{0} ijaradan qaytdi', [p.name]), trf('{0}dagi o‘yin tajribasi: OVR {1}.', [dest.name, p.ovr]));
    }
  }

  /// Takes over [club] in this league (after an offer or the sack).
  void switchClub(Club club) {
    final rnd = Random(_salt(_currentRound));
    _returnLoans(rnd);
    final old = userClub;
    _userClubId = club.id;
    final trophies = List.of(life.trophies), awards = List.of(life.awards);
    life.reset();
    life.trophies.addAll(trophies);
    life.awards.addAll(awards);
    life.pressDone.clear();
    objective = _objectiveFor(club);
    boardConfidence = 65;
    _news(NewsKind.board, trf('Yangi ish: {0}', [club.name]),
        trf('{0}ni tark etib, {1} bosh murabbiyi bo‘ldingiz. Maqsad: {2}.', [old.name, club.name, objective.title]),
        alert: true);
    notifyListeners();
  }

  void declineJobOffers() {
    life.jobOffers.clear();
    notifyListeners();
  }

  /// A job offer as (id, name, reputation, league), from any league.
  (String, String, int, String)? jobOfferInfo(String id) {
    final local = getClubById(id);
    if (local != null) return (local.id, local.name, local.reputation, leagueOfClub(id));
    return InitialDatabase.clubIndex.where((e) => e.$1 == id).firstOrNull;
  }

  /// Club reputation a manager of [reputation] is offered (30 → about 55,
  /// 90 → the elite).
  static double jobLevel(double reputation) => 35 + reputation * 0.65;

  /// Clubs anywhere in the world whose reputation matches the manager's
  /// call; after a sack, smaller clubs only. No offers until the manager
  /// is good enough for a step up.
  void _offerJobs({bool sacked = false}) {
    final mine = userClub;
    final target = jobLevel(_managerProfile.reputation);
    final rnd = Random(_salt(calendar.year * 59 + _currentRound));
    final pool = [
      for (final e in InitialDatabase.clubIndex)
        if (e.$1 != mine.id &&
            (e.$3 - target).abs() <= 7 &&
            (sacked ? e.$3 <= mine.reputation : e.$3 >= mine.reputation - 2))
          e,
    ]..shuffle(rnd);
    final want = sacked ? 3 : 1 + (_managerProfile.reputation >= 55 ? 2 : 1);
    final picks = <String>[];
    final leagues = <String>{};
    for (final e in pool) {
      if (picks.length >= want) break;
      if (leagues.add(e.$4)) picks.add(e.$1);
    }
    life.jobOffers
      ..clear()
      ..addAll(picks);
    if (picks.isNotEmpty && !sacked) {
      _news(NewsKind.board, tr('Ish takliflari'),
          trf('{0} sizni bosh murabbiy sifatida ko‘rmoqchi. Menejer reytingi: {1} ({2}).', [
            picks.map((id) => jobOfferInfo(id)!.$2).join(', '),
            _managerProfile.reputation.round(),
            _managerProfile.reputationLevel,
          ]),
          alert: true);
    }
  }

  /// Takes a job: a club of this league at once; any other league (abroad
  /// too) starts there with a fresh season.
  Future<String?> acceptJob(String id) async {
    final info = jobOfferInfo(id);
    if (info == null) return tr('Klub topilmadi.');
    final local = _allClubs.where((c) => c.id == id).firstOrNull;
    if (local != null) {
      switchClub(local);
      return null;
    }
    await _moveTo(id, info.$4);
    return null;
  }

  /// A new chapter in another league: trophies, awards, the manager and the
  /// scouting network move along; squads there have aged with the calendar.
  Future<void> _moveTo(String clubId, String league) async {
    await InitialDatabase.ensurePyramid(league);
    final year = seasonFinished ? calendar.year + 1 : calendar.year;
    final seasons = year - firstSeason;
    final trophies = List.of(life.trophies), awards = List.of(life.awards);
    final scouting = world.toMap();
    final old = userClub.name;
    _resetRecords();
    world.restore(scouting);
    life.trophies.addAll(trophies);
    life.awards.addAll(awards);
    leagueId = league;
    _allClubs = InitialDatabase.getClubs(league);
    for (final c in _allClubs) {
      WorldMarket.age(c, seasons, Random(c.id.hashCode ^ seasons));
    }
    _userClubId = clubId;
    _beginCareer(year: year, seasons: seasons);
    _news(NewsKind.board, trf('Yangi ish: {0}', [userClub.name]),
        trf('{0}ni tark etib, {1} ({2}) bosh murabbiyi bo‘ldingiz.', [old, userClub.name, tr(leagueInfo.country)]),
        alert: true);
    refreshWorld();
  }

  /// Weekly: a board out of patience sacks the manager.
  void _boardPatience() {
    if (life.sacked || _currentRound < 6 || boardConfidence > 12) return;
    life.sacked = true;
    _managerProfile.reputation = max(1.0, _managerProfile.reputation - 8);
    _offerJobs(sacked: true);
    _news(NewsKind.board, tr('Siz ishdan bo‘shatildingiz'),
        tr('Kengash natijalardan norozi. Yangi klub tanlang: takliflar bosh sahifada.'), alert: true);
  }

  /// Talk to a player: promise him games (morale up now, big drop if broken).
  String promisePlayingTime(Player p) {
    if (life.promises.containsKey(p.id)) return tr('Bu futbolchiga allaqachon va’da berilgan.');
    life.promises[p.id] = _currentRound + 3;
    p.morale = min(100, p.morale + 10);
    if (p.morale >= 55) life.wantsOut.remove(p.id);
    notifyListeners();
    return trf('{0}: “Yaxshi, keyingi 3 o‘yinda imkoniyat kutaman.”', [p.shortName]);
  }

  /// Season honours across every club in the career's leagues.
  void _seasonAwards() {
    final all = [for (final c in domesticClubs) for (final p in c.squad) (p, c)];
    double score(Player p) =>
        (p.averageRating ?? 6) * 10 + p.seasonGoals * 1.2 + p.seasonAssists * 0.8 + p.seasonMotm * 1.5;
    final eligible = all.where((e) => e.$1.seasonMinutes >= 900).toList()
      ..sort((a, b) => score(b.$1).compareTo(score(a.$1)));
    if (eligible.isEmpty) return;
    final ballon = eligible.first;
    final boot = (List.of(all)..sort((a, b) => b.$1.seasonGoals.compareTo(a.$1.seasonGoals))).first;
    final young = eligible.where((e) => e.$1.age <= 21).firstOrNull ?? eligible.first;
    final used = <String>{};
    List<String> pick(bool Function(PlayerPosition) at, int n) {
      final list = [
        for (final e in eligible)
          if (at(e.$1.mainPosition) && !used.contains(e.$1.id)) e,
      ].take(n).toList();
      used.addAll(list.map((e) => e.$1.id));
      return [for (final e in list) '${e.$1.mainPosition.code} · ${e.$1.name} · ${e.$2.shortName}'];
    }

    final tots = [
      ...pick((p) => p.isGoalkeeper, 1),
      ...pick((p) => p == PlayerPosition.cb, 2),
      ...pick((p) => p == PlayerPosition.lb || p == PlayerPosition.rb, 2),
      ...pick((p) => p.category == PositionCategory.midfield, 3),
      ...pick((p) => p.isAttacker, 3),
    ];
    final awards = SeasonAwards(
      seasonLabel,
      '${ballon.$1.name} (${ballon.$2.name})',
      '${boot.$1.name} (${boot.$2.name}) · ${boot.$1.seasonGoals}',
      '${young.$1.name} (${young.$2.name})',
      tots,
    );
    life.awards.insert(0, awards);
    _news(
      NewsKind.award,
      trf('Oltin to‘p: {0}', [ballon.$1.name]),
      trf('Oltin butsa: {0}. Eng yaxshi yosh futbolchi: {1}. Mavsum ramziy jamoasi e’lon qilindi.', [awards.goldenBoot, awards.youngPlayer]),
      alert: ballon.$2.id == _userClubId,
    );
    final mine = (List.of(userClub.squad)..sort((a, b) => b.seasonGoals.compareTo(a.seasonGoals))).firstOrNull;
    if (mine != null && mine.seasonGoals > life.bestSeasonGoals) {
      life.bestSeasonGoals = mine.seasonGoals;
      life.bestSeasonScorer = '${mine.name} · $seasonLabel';
    }
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
    final templates = InitialDatabase.customSquadTemplates;
    return templates.asMap().entries.map((entry) {
      final idx = entry.key;
      final d = entry.value;
      final pool = InitialDatabase.randomPool(random);
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
    const positions = ['CF', 'AMF', 'LWF', 'RWF', 'CMF', 'CB', 'GK', 'DMF'];
    final picked = (List.of(positions)..shuffle(random)).take(3).toList();
    return [
      for (var i = 0; i < picked.length; i++)
        () {
          final pool = InitialDatabase.randomPool(random);
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
            contract: PlayerContract(contractYears: 4, weeklyWage: 160000),
            marketValue: Player.valuation(ovr, age, ovr + 2),
          );
        }(),
    ];
  }

  // --------------------------------------------------------------- news
  void _news(NewsKind kind, String title, String body, {bool? alert}) {
    final item = NewsItem(date: currentDate, title: title, body: body, kind: kind);
    news.insert(0, item);
    if (news.length > 80) news.removeLast();
    // Things the manager must not miss also pop up as a banner.
    if (alert ?? const {NewsKind.injury, NewsKind.award, NewsKind.contract, NewsKind.window}.contains(kind)) {
      alerts.add(item);
      if (alerts.length > 6) alerts.removeAt(0);
    }
  }

  /// Banners waiting to be shown by the main screen (not saved).
  final List<NewsItem> alerts = [];

  NewsItem? takeAlert() => alerts.isEmpty ? null : alerts.removeAt(0);

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
        ? tr('G‘alaba!')
        : r == 'D'
        ? tr('Durang')
        : tr('Mag‘lubiyat');
    _news(
      NewsKind.match,
      '$verdict ${home.shortName} ${f.homeScore}–${f.awayScore} ${away.shortName}',
      trf('{0}-tur. xG {1} – {2}, to‘p nazorati {3}% – {4}%.{5}', [f.round, f.homeXG.toStringAsFixed(2), f.awayXG.toStringAsFixed(2), f.homePossession, f.awayPossession, motm != null ? trf(' O‘yin qahramoni: {0} ({1}).', [motm.name, f.ratings[motm.id]?.toStringAsFixed(1)]) : '']),
    );
  }

  static String _m(int v) => '€${(v / 1000000).toStringAsFixed(1)}M';

  Set<String> get _recentUserFixtures {
    final mine = _fixtures.where((f) => f.isPlayed && f.involves(_userClubId ?? '')).toList();
    return {for (final f in mine.skip(max(0, mine.length - 3))) f.id};
  }

  // ------------------------------------------------------------ save/load
  static const saveVersion = 1;

  Map<String, dynamic> toSave() => {
    'v': saveVersion,
    'seed': careerSeed,
    'clubs': _allClubs.map(SaveCodec.club).toList(),
    'user': _userClubId,
    'round': _currentRound,
    'year': calendar.year,
    'league': leagueId,
    'finished': seasonFinished,
    'objective': [objective.key, objective.targetPosition, objective.arg],
    'board': boardConfidence,
    'manager': _managerProfile.toMap(),
    'standings': _standingsMap.values.map(SaveCodec.standing).toList(),
    // Full detail (shots, lines, momentum) only for the user's matches and
    // commentary only for the last three of them: saves must fit browser
    // storage over a 46-round season.
    'fixtures': [
      for (final f in _fixtures)
        SaveCodec.fixture(
          f,
          shots: f.involves(_userClubId ?? ''),
          full: f.involves(_userClubId ?? ''),
          commentary: _recentUserFixtures.contains(f.id),
        ),
    ],
    'ledger': [
      for (final e in ledger)
        if (e.clubId == _userClubId) SaveCodec.entry(e),
    ],
    'transfers': transferHistory.map(SaveCodec.transfer).toList(),
    'news': news.map(SaveCodec.news).toList(),
    'deals': [
      for (final d in deals)
        {
          'p': d.player.id,
          's': d.seller.id,
          'b': d.buyer.id,
          'f': d.fee,
          'w': d.wage,
          'y': d.years,
          'st': d.stage.name,
          'due': d.dueRound,
          if (d.counterFee != null) 'c': d.counterFee,
          'n': d.note,
        },
    ],
    'listed': transferListed.toList(),
    'free': freeAgents.map(SaveCodec.player).toList(),
    'history': [
      for (final h in seasonHistory)
        [h.season, h.championName, h.userPosition, h.userPoints, h.topScorer],
    ],
    'balance': balanceHistory,
    'divisions': [
      for (final d in divisions.values)
        {
          'id': d.id,
          'clubs': d.clubs.map(SaveCodec.club).toList(),
          'standings': d.table.values.map(SaveCodec.standing).toList(),
          // Background results only: [round, home, away, homeGoals, awayGoals].
          'fixtures': [
            for (final f in d.fixtures)
              [f.round, f.homeClubId, f.awayClubId, if (f.isPlayed) ...[f.homeScore, f.awayScore]],
          ],
        },
    ],
    'moves': pendingMoves,
    'life': life.toMap(),
    'world': world.toMap(),
    if (superCup != null) 'super': SaveCodec.fixture(superCup!, shots: true, full: true, commentary: false),
    if (superPens != null) 'superPens': [superPens!.$1, superPens!.$2],
    if (cup != null) 'cup': cup!.toMap(),
    'cupFx': [for (final f in cupFixtures) SaveCodec.fixture(f, shots: true, full: true, commentary: false)],
  };

  bool _worldPrepared = false;

  /// League ids of [league]'s pyramid (the world market skips them).
  static Set<String> _pyramidIds(String league) => {for (final l in InitialDatabase.pyramidOf(league)) l.id};

  /// A foreign club fresh from the data files: a real XI and fair prices
  /// for its league.
  void _prepareWorldClub(Club c) {
    _ensureMatchdaySquad(c);
    autoPickLineup(c);
    final econ = _economyOf(c);
    for (final p in c.squad) {
      if (p.ovr < 68 || econ < 1) p.marketValue = min(p.marketValue, p.fairValueIn(econ));
    }
  }

  /// Loads a saved career's scouted world before [restore]: negotiations
  /// with foreign clubs need their squads.
  Future<void> prepareWorld(Map<String, dynamic> m) async {
    world.restore(m['world'] == null ? null : Map<String, dynamic>.from(m['world']));
    try {
      await world.reload(_pyramidIds(m['league'] as String? ?? 'super'), _prepareWorldClub);
    } catch (e) {
      // A missing data file must never cost the career: the market is empty.
      debugPrint('World market not loaded: $e');
    }
    _worldPrepared = true;
  }

  /// Rebuilds the world market (new season or new pyramid) in the background.
  Future<void> refreshWorld() async {
    world.seasons = calendar.year - firstSeason;
    await world.reload(_pyramidIds(leagueId), _prepareWorldClub);
    notifyListeners();
  }

  /// Restores a career written by [toSave]. Returns false for unknown data.
  bool restore(Map<String, dynamic> m) {
    if (m['v'] != saveVersion) return false;
    final prepared = _worldPrepared;
    _worldPrepared = false;
    if (!prepared) world.restore(m['world'] == null ? null : Map<String, dynamic>.from(m['world']));
    life.restore(m['life'] == null ? null : Map<String, dynamic>.from(m['life']));
    cup = m['cup'] == null ? null : Cup.fromMap(Map<String, dynamic>.from(m['cup']));
    cupFixtures
      ..clear()
      ..addAll([for (final f in (m['cupFx'] as List? ?? [])) SaveCodec.fixtureFrom(Map<String, dynamic>.from(f))]);
    _openCupFixture = null;
    superCup = m['super'] == null ? null : SaveCodec.fixtureFrom(Map<String, dynamic>.from(m['super']));
    final sp = m['superPens'] as List?;
    superPens = sp == null ? null : (sp[0] as int, sp[1] as int);
    _allClubs = [for (final c in m['clubs'] as List) SaveCodec.clubFrom(Map<String, dynamic>.from(c))];
    _userClubId = m['user'];
    careerSeed = m['seed'] ?? careerSeed;
    _currentRound = m['round'];
    leagueId = m['league'] ?? 'super';
    divisions.clear();
    seasonFinished = m['finished'] ?? false;
    final o = m['objective'] as List;
    objective = BoardObjective(o[0], o[1], o.length > 2 ? o[2] : null);
    boardConfidence = m['board'] ?? 70;
    _managerProfile = ManagerProfile.fromMap(Map<String, dynamic>.from(m['manager']));
    calendar = SeasonCalendar(m['year'], totalRounds);
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
    deals.clear();
    for (final raw in m['deals'] as List? ?? []) {
      final seller = getClubById(raw['s']), buyer = getClubById(raw['b']);
      final player = seller?.playerById(raw['p']);
      final stage = DealStage.values.asNameMap()[raw['st']];
      if (seller == null || buyer == null || player == null || stage == null) continue;
      deals.add(TransferDeal(
        player: player,
        seller: seller,
        buyer: buyer,
        fee: raw['f'],
        wage: raw['w'] ?? 0,
        years: raw['y'] ?? 3,
        stage: stage,
        dueRound: raw['due'],
        counterFee: raw['c'],
        note: raw['n'] ?? '',
      ));
    }
    transferListed
      ..clear()
      ..addAll(List<String>.from(m['listed'] ?? []));
    seasonHistory
      ..clear()
      ..addAll([
        for (final h in m['history'] as List? ?? [])
          SeasonSummary(h[0], h[1], h[2], h[3], h[4]),
      ]);
    balanceHistory
      ..clear()
      ..addAll([for (final v in m['balance'] as List? ?? []) (v as num).toInt()]);
    divisions.clear();
    for (final raw in m['divisions'] as List? ?? []) {
      final dm = Map<String, dynamic>.from(raw);
      final clubs = [for (final c in dm['clubs'] as List) SaveCodec.clubFrom(Map<String, dynamic>.from(c))];
      final d = Division(dm['id'], clubs, SeasonCalendar(calendar.year, (clubs.length - 1) * 2));
      d.table = {
        for (final s in dm['standings'] as List)
          (s as Map)['c'] as String: SaveCodec.standingFrom(Map<String, dynamic>.from(s)),
      };
      var i = 0;
      d.fixtures = [
        for (final f in dm['fixtures'] as List)
          Fixture(
            id: 'd${d.id}_${calendar.year}_${i++}',
            round: f[0],
            homeClubId: f[1],
            awayClubId: f[2],
            date: d.calendar.dateOfRound(f[0]),
            homeScore: f.length > 3 ? f[3] : null,
            awayScore: f.length > 3 ? f[4] : null,
            isPlayed: f.length > 3,
          ),
      ];
      divisions[d.id] = d;
    }
    if (divisions.isEmpty && InitialDatabase.pyramidOf(leagueId).length > 1) {
      // Saves from before the pyramid: start the other leagues now.
      _setupDivisions();
      if (_currentRound > 1) _playDivisions(calendar.dateOfRound(_currentRound - 1));
    }
    pendingMoves
      ..clear()
      ..addAll(Map<String, String>.from(m['moves'] ?? {}));
    // Portrait hints may have improved since the save was written.
    for (final c in marketClubs) {
      for (final p in c.squad) {
        final hint = InitialDatabase.faceHints[p.id];
        if (hint != null) p.face = FaceConfig.fromMap({...p.face.toMap(), ...hint});
      }
    }
    lastTransferError = null;
    _isInitialized = true;
    if (!prepared && (world.countries.isNotEmpty || world.missions.isNotEmpty)) refreshWorld();
    notifyListeners();
    return true;
  }
}
