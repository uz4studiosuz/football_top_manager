import '../models/club.dart';
import '../models/finance.dart';
import '../models/league.dart';
import '../models/player.dart';

/// JSON codecs for everything a career needs to survive an app restart.
/// Kept apart from the models so static data loading stays untouched.
abstract final class SaveCodec {
  // ---------------------------------------------------------------- player
  // Compact player format (short keys, attribute and face lists): a
  // 68-club pyramid has ~1,700 players and must fit browser storage.
  static const _statKeys = [
    'attackingAwareness', 'ballControl', 'dribbling', 'tightPossession', 'lowPass', 'loftedPass',
    'finishing', 'heading', 'setPieceTaking', 'curl', 'defensiveAwareness', 'defensiveEngagement',
    'tackling', 'aggression', 'gkAwareness', 'gkCatching', 'gkParrying', 'gkReflexes', 'gkReach',
    'speed', 'acceleration', 'kickingPower', 'jumping', 'physicalContact', 'balance', 'stamina',
  ];
  static const _faceKeys = [
    'skin', 'hair', 'cut', 'shape', 'eyes', 'nose', 'mouth', 'brow', 'age', 'eyeColor', 'beardStyle',
    'glasses', 'freckles',
  ];

  static Map<String, dynamic> player(Player p) {
    final stats = p.stats.toMap();
    final face = p.face.toMap();
    final rt = <String, dynamic>{
      'st': p.currentStamina,
      'mo': p.morale,
      'ir': p.injuryRounds,
      'in': p.injury,
      'su': p.suspensionRounds,
      'g': p.seasonGoals,
      'a': p.seasonAssists,
      'm': p.seasonMatches,
      'cs': p.seasonCleanSheets,
      'y': p.seasonYellowCards,
      'r': p.seasonRedCards,
      'min': p.seasonMinutes,
      'motm': p.seasonMotm,
      'rs': double.parse(p.seasonRatingSum.toStringAsFixed(2)),
      'rn': p.seasonRated,
      'rr': p.recentRatings,
      'h': p.history,
      'tf': p.transfers,
      'car': p.careerSeasons,
      'gr': double.parse(p.growth.toStringAsFixed(3)),
    }..removeWhere((k, v) => v == null || v == 0 || (v is List && v.isEmpty) || (k == 'st' && v == 100));
    return {
      'k': 1,
      'i': p.id,
      'n': p.name,
      's': p.shortName,
      'a': p.age,
      'na': p.nationality,
      'fl': p.countryFlag,
      'no': p.number,
      'po': p.mainPosition.code,
      if (p.altPositions.isNotEmpty) 'al': [for (final x in p.altPositions) x.code],
      'ft': p.preferredFoot.name == 'left' ? 1 : 0,
      'wf': p.weakFoot,
      'sv': [for (final k in _statKeys) stats[k]],
      'c': [p.contract.contractYears, p.contract.weeklyWage, p.contract.releaseClause],
      'mv': p.marketValue,
      'pt': p.potential,
      'ps': p.playingStyle.name,
      if (p.instruction.name != 'balanced') 'ins': p.instruction.name,
      'he': ?p.height,
      if (p.traits.isNotEmpty) 'tr': p.traits,
      'fc': [for (final k in _faceKeys) face[k] is bool ? (face[k] ? 1 : 0) : face[k]],
      if (rt.isNotEmpty) 'rt': rt,
    };
  }

  /// Expands the compact format back into the asset/legacy layout.
  static Map<String, dynamic> _expand(Map<String, dynamic> m) {
    final sv = m['sv'] as List, fc = m['fc'] as List, c = m['c'] as List;
    return {
      'id': m['i'],
      'name': m['n'],
      'shortName': m['s'],
      'age': m['a'],
      'nationality': m['na'],
      'countryFlag': m['fl'],
      'number': m['no'],
      'mainPosition': m['po'],
      'altPositions': m['al'] ?? const [],
      'preferredFoot': m['ft'] == 1 ? 'left' : 'right',
      'weakFoot': m['wf'],
      'stats': {for (var i = 0; i < _statKeys.length; i++) _statKeys[i]: sv[i]},
      'contract': {'contractYears': c[0], 'weeklyWage': c[1], 'releaseClause': c[2]},
      'marketValue': m['mv'],
      'potential': m['pt'],
      'playingStyle': m['ps'],
      'instruction': m['ins'] ?? 'balanced',
      'height': m['he'],
      'traits': m['tr'],
      'face': {
        for (var i = 0; i < _faceKeys.length; i++)
          _faceKeys[i]: i >= 11 ? fc[i] == 1 : fc[i],
      },
      'rt': m['rt'],
    };
  }

  static Player playerFrom(Map<String, dynamic> raw) {
    final m = raw['k'] == 1 ? _expand(raw) : raw;
    final p = Player.fromMap(m);
    final rt = m['rt'] == null ? null : Map<String, dynamic>.from(m['rt']);
    if (rt == null) return p;
    p.currentStamina = rt['st'] ?? 100;
    p.morale = rt['mo'] ?? 85;
    p.injuryRounds = rt['ir'] ?? 0;
    p.injury = rt['in'];
    p.suspensionRounds = rt['su'] ?? 0;
    p.seasonGoals = rt['g'] ?? 0;
    p.seasonAssists = rt['a'] ?? 0;
    p.seasonMatches = rt['m'] ?? 0;
    p.seasonCleanSheets = rt['cs'] ?? 0;
    p.seasonYellowCards = rt['y'] ?? 0;
    p.seasonRedCards = rt['r'] ?? 0;
    p.seasonMinutes = rt['min'] ?? 0;
    p.seasonMotm = rt['motm'] ?? 0;
    p.seasonRatingSum = (rt['rs'] as num? ?? 0).toDouble();
    p.seasonRated = rt['rn'] ?? 0;
    p.recentRatings.addAll([for (final v in (rt['rr'] as List? ?? [])) (v as num).toDouble()]);
    p.history.addAll([for (final v in (rt['h'] as List? ?? [])) v as String]);
    p.transfers.addAll([for (final v in (rt['tf'] as List? ?? [])) v as String]);
    p.careerSeasons.addAll([for (final v in (rt['car'] as List? ?? [])) v as String]);
    p.growth = (rt['gr'] as num? ?? 0).toDouble();
    return p;
  }

  // ------------------------------------------------------------------ club
  static Map<String, dynamic> club(Club c) => {
    ...c.toMap(),
    'squad': c.squad.map(player).toList(),
  };

  static Club clubFrom(Map<String, dynamic> m) {
    final squad = (m['squad'] as List).map((p) => playerFrom(Map<String, dynamic>.from(p))).toList();
    final c = Club.fromMap({...m, 'squad': const []});
    c.squad = squad;
    return c;
  }

  // ---------------------------------------------------------------- events
  static Map<String, dynamic> event(MatchEvent e, {bool text = true}) => {
    'mi': e.minute,
    if (e.extraMinute > 0) 'x': e.extraMinute,
    't': e.type.name,
    if (text) 'd': e.description,
    'c': e.clubId,
    if (e.playerName != null) 'pn': e.playerName,
    if (e.playerId != null) 'pi': e.playerId,
    if (e.secondaryName != null) 'sn': e.secondaryName,
    'h': e.isHomeTeam,
    if (e.assistPlayerId != null) 'as': e.assistPlayerId,
    'hs': e.homeScore,
    'aw': e.awayScore,
  };

  static MatchEvent eventFrom(Map<String, dynamic> m) => MatchEvent(
    minute: m['mi'],
    extraMinute: m['x'] ?? 0,
    type: MatchEventType.values.asNameMap()[m['t']] ?? MatchEventType.info,
    description: m['d'] ?? '',
    clubId: m['c'],
    playerName: m['pn'],
    playerId: m['pi'],
    secondaryName: m['sn'],
    isHomeTeam: m['h'],
    assistPlayerId: m['as'],
    homeScore: m['hs'] ?? 0,
    awayScore: m['aw'] ?? 0,
  );

  static const _lineFields = [
    'passes', 'passesCompleted', 'keyPasses', 'shots', 'shotsOnTarget', 'goals', 'assists',
    'tackles', 'interceptions', 'clearances', 'blocks', 'dribbles', 'dribblesWon', 'duelsWon',
    'duelsLost', 'fouls', 'fouled', 'saves', 'goalsConceded', 'yellow', 'red', 'possessionLost',
    'offsides', 'bigChancesMissed', 'crosses', 'touches',
    'errorsLeadingToShot', 'errorsLeadingToGoal', 'penaltiesConceded', 'penaltiesWon', 'penaltiesSaved', 'bigChancesCreated', 'dribbledPast',
  ];

  static List<int> _lineValues(PlayerMatchStats l) => [
    l.passes, l.passesCompleted, l.keyPasses, l.shots, l.shotsOnTarget, l.goals, l.assists,
    l.tackles, l.interceptions, l.clearances, l.blocks, l.dribbles, l.dribblesWon, l.duelsWon,
    l.duelsLost, l.fouls, l.fouled, l.saves, l.goalsConceded, l.yellow, l.red, l.possessionLost,
    l.offsides, l.bigChancesMissed, l.crosses, l.touches,
    l.errorsLeadingToShot, l.errorsLeadingToGoal, l.penaltiesConceded, l.penaltiesWon, l.penaltiesSaved, l.bigChancesCreated, l.dribbledPast,
  ];

  static Map<String, dynamic> line(PlayerMatchStats l) => {
    's': l.started,
    'mn': double.parse(l.minutes.toStringAsFixed(1)),
    'v': _lineValues(l),
    'xg': double.parse(l.xg.toStringAsFixed(3)),
    'xa': double.parse(l.xa.toStringAsFixed(3)),
    if (l.distanceM > 0) 'dm': l.distanceM.round(),
    if (l.injured) 'inj': true,
    if (l.subOnMinute != null) 'on': l.subOnMinute,
    if (l.subOffMinute != null) 'off': l.subOffMinute,
  };

  static PlayerMatchStats lineFrom(String id, Map<String, dynamic> m) {
    final l = PlayerMatchStats(id, started: m['s'] ?? true)
      ..minutes = (m['mn'] as num).toDouble()
      ..xg = (m['xg'] as num? ?? 0).toDouble()
      ..xa = (m['xa'] as num? ?? 0).toDouble()
      ..distanceM = (m['dm'] as num? ?? 0).toDouble()
      ..injured = m['inj'] == true
      ..subOnMinute = m['on']
      ..subOffMinute = m['off'];
    final v = (m['v'] as List).cast<num>();
    // Older saves stop after 'touches'; missing values stay 0.
    assert(v.length == _lineFields.length || v.length == 26);
    int next(int i) => i < v.length ? v[i].toInt() : 0;
    var i = 0;
    l
      ..passes = v[i++].toInt()
      ..passesCompleted = v[i++].toInt()
      ..keyPasses = v[i++].toInt()
      ..shots = v[i++].toInt()
      ..shotsOnTarget = v[i++].toInt()
      ..goals = v[i++].toInt()
      ..assists = v[i++].toInt()
      ..tackles = v[i++].toInt()
      ..interceptions = v[i++].toInt()
      ..clearances = v[i++].toInt()
      ..blocks = v[i++].toInt()
      ..dribbles = v[i++].toInt()
      ..dribblesWon = v[i++].toInt()
      ..duelsWon = v[i++].toInt()
      ..duelsLost = v[i++].toInt()
      ..fouls = v[i++].toInt()
      ..fouled = v[i++].toInt()
      ..saves = v[i++].toInt()
      ..goalsConceded = v[i++].toInt()
      ..yellow = v[i++].toInt()
      ..red = v[i++].toInt()
      ..possessionLost = v[i++].toInt()
      ..offsides = v[i++].toInt()
      ..bigChancesMissed = v[i++].toInt()
      ..crosses = v[i++].toInt()
      ..touches = v[i++].toInt()
      ..errorsLeadingToShot = next(i++)
      ..errorsLeadingToGoal = next(i++)
      ..penaltiesConceded = next(i++)
      ..penaltiesWon = next(i++)
      ..penaltiesSaved = next(i++)
      ..bigChancesCreated = next(i++)
      ..dribbledPast = next(i++);
    return l;
  }

  // --------------------------------------------------------------- fixture
  /// [full] keeps everything for the user's own matches; other matches keep
  /// incidents, ratings and a mini line per player (minutes, goals,
  /// assists, cards) so tables, histories and reports still work.
  /// [commentary] also keeps the play-by-play text.
  static Map<String, dynamic> fixture(Fixture f, {bool shots = true, bool full = true, bool commentary = true, bool actions = false}) => {
    'id': f.id,
    'r': f.round,
    'h': f.homeClubId,
    'a': f.awayClubId,
    if (f.date != null) 'dt': f.date!.millisecondsSinceEpoch,
    'p': f.isPlayed,
    if (f.isPlayed) ...{
      'hs': f.homeScore,
      'as': f.awayScore,
      'n': [
        f.homePasses, f.awayPasses, f.homeCompletedPasses, f.awayCompletedPasses,
        f.homeShots, f.awayShots, f.homeShotsOnTarget, f.awayShotsOnTarget,
        f.homePossession, f.awayPossession, f.homeCorners, f.awayCorners,
        f.homeFouls, f.awayFouls, f.homeSaves, f.awaySaves, f.homeOffsides, f.awayOffsides,
        f.homeTackles, f.awayTackles, f.homeBigChances, f.awayBigChances,
        f.homeYellows, f.awayYellows, f.homeReds, f.awayReds, f.attendance,
      ],
      'xg': [f.homeXG, f.awayXG],
      'e': [
        for (final e in f.events)
          if (commentary || e.type.isIncident) event(e, text: commentary),
      ],
      if (full) 'ra': {for (final e in f.ratings.entries) e.key: double.parse(e.value.toStringAsFixed(1))},
      if (full)
        'ps': {for (final e in f.playerStats.entries) e.key: line(e.value)}
      else
        'pm': {
          for (final e in f.playerStats.entries)
            if (e.value.minutes > 0)
              e.key: [
                e.value.minutes.round(), e.value.goals, e.value.assists, e.value.yellow, e.value.red,
                if (f.ratings[e.key] != null) double.parse(f.ratings[e.key]!.toStringAsFixed(1)),
              ],
        },
      // Line-ups are kept for every match of every club.
      if (f.homeLineup.isNotEmpty) ...{
        'hl': f.homeLineup,
        'al': f.awayLineup,
        'hb': f.homeBench,
        'ab': f.awayBench,
      },
      if (full) 'mo': f.momentum.map((v) => v.round()).toList(),
      if (shots && f.shots.isNotEmpty) 'sh': f.shots.map((s) => s.toMap()).toList(),
      if (full && f.heat.isNotEmpty) 'hm': f.heat,
      if (actions && f.actions.isNotEmpty) 'ac': f.actions,
      if (f.motmId != null) 'motm': f.motmId,
    },
  };

  static Fixture fixtureFrom(Map<String, dynamic> m) {
    final f = Fixture(
      id: m['id'],
      round: m['r'],
      homeClubId: m['h'],
      awayClubId: m['a'],
      date: m['dt'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['dt']),
      isPlayed: m['p'] ?? false,
    );
    if (!f.isPlayed) return f;
    f.homeScore = m['hs'];
    f.awayScore = m['as'];
    final n = (m['n'] as List).cast<num>().map((e) => e.toInt()).toList();
    var i = 0;
    f
      ..homePasses = n[i++]
      ..awayPasses = n[i++]
      ..homeCompletedPasses = n[i++]
      ..awayCompletedPasses = n[i++]
      ..homeShots = n[i++]
      ..awayShots = n[i++]
      ..homeShotsOnTarget = n[i++]
      ..awayShotsOnTarget = n[i++]
      ..homePossession = n[i++]
      ..awayPossession = n[i++]
      ..homeCorners = n[i++]
      ..awayCorners = n[i++]
      ..homeFouls = n[i++]
      ..awayFouls = n[i++]
      ..homeSaves = n[i++]
      ..awaySaves = n[i++]
      ..homeOffsides = n[i++]
      ..awayOffsides = n[i++]
      ..homeTackles = n[i++]
      ..awayTackles = n[i++]
      ..homeBigChances = n[i++]
      ..awayBigChances = n[i++]
      ..homeYellows = n[i++]
      ..awayYellows = n[i++]
      ..homeReds = n[i++]
      ..awayReds = n[i++]
      ..attendance = n[i++];
    final xg = (m['xg'] as List).cast<num>();
    f.homeXG = xg[0].toDouble();
    f.awayXG = xg[1].toDouble();
    f.events = [for (final e in m['e'] as List) eventFrom(Map<String, dynamic>.from(e))];
    f.ratings = {
      for (final e in Map<String, dynamic>.from(m['ra'] ?? {}).entries) e.key: (e.value as num).toDouble(),
      for (final e in Map<String, dynamic>.from(m['pm'] ?? {}).entries)
        if ((e.value as List).length > 5) e.key: (e.value[5] as num).toDouble(),
    };
    f.playerStats = {
      for (final e in Map<String, dynamic>.from(m['ps'] ?? {}).entries)
        e.key: lineFrom(e.key, Map<String, dynamic>.from(e.value)),
      for (final e in Map<String, dynamic>.from(m['pm'] ?? {}).entries)
        e.key: PlayerMatchStats(e.key)
          ..minutes = (e.value[0] as num).toDouble()
          ..goals = e.value[1]
          ..assists = e.value[2]
          ..yellow = e.value[3]
          ..red = e.value[4],
    };
    f.homeLineup = List<String>.from(m['hl'] ?? []);
    f.awayLineup = List<String>.from(m['al'] ?? []);
    f.homeBench = List<String>.from(m['hb'] ?? []);
    f.awayBench = List<String>.from(m['ab'] ?? []);
    f.momentum = [for (final v in (m['mo'] as List? ?? [])) (v as num).toDouble()];
    f.motmId = m['motm'];
    f.shots = [for (final s in (m['sh'] as List? ?? [])) ShotRecord.fromMap(Map<String, dynamic>.from(s))];
    f.heat = Map<String, String>.from(m['hm'] ?? {});
    f.actions = Map<String, String>.from(m['ac'] ?? {});
    return f;
  }

  // ----------------------------------------------------------------- misc
  static Map<String, dynamic> standing(LeagueStanding s) => {
    'c': s.clubId,
    'v': [s.played, s.won, s.drawn, s.lost, s.goalsFor, s.goalsAgainst],
    'f': s.formGuide,
  };

  static LeagueStanding standingFrom(Map<String, dynamic> m) {
    final v = (m['v'] as List).cast<num>().map((e) => e.toInt()).toList();
    return LeagueStanding(
      clubId: m['c'],
      played: v[0],
      won: v[1],
      drawn: v[2],
      lost: v[3],
      goalsFor: v[4],
      goalsAgainst: v[5],
      formGuide: List<String>.from(m['f'] ?? []),
    );
  }

  static Map<String, dynamic> entry(FinanceEntry e) => {
    'r': e.round,
    'c': e.clubId,
    'l': e.label,
    'a': e.amount,
    'k': e.category.name,
    if (e.date != null) 'd': e.date!.millisecondsSinceEpoch,
  };

  static FinanceEntry entryFrom(Map<String, dynamic> m) => FinanceEntry(
    m['r'],
    m['c'],
    m['l'],
    m['a'],
    category: FinanceCategory.values.asNameMap()[m['k']] ?? FinanceCategory.operations,
    date: m['d'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['d']),
  );

  static Map<String, dynamic> transfer(TransferRecord t) => {
    'r': t.round,
    'p': t.playerName,
    'f': t.fromClub,
    't': t.toClub,
    'fee': t.fee,
    if (t.date != null) 'd': t.date!.millisecondsSinceEpoch,
  };

  static TransferRecord transferFrom(Map<String, dynamic> m) => TransferRecord(
    m['r'],
    m['p'],
    m['f'],
    m['t'],
    m['fee'],
    date: m['d'] == null ? null : DateTime.fromMillisecondsSinceEpoch(m['d']),
  );

  static Map<String, dynamic> news(NewsItem n) => {
    'd': n.date.millisecondsSinceEpoch,
    't': n.title,
    'b': n.body,
    'k': n.kind.name,
    'r': n.read,
  };

  static NewsItem newsFrom(Map<String, dynamic> m) => NewsItem(
    date: DateTime.fromMillisecondsSinceEpoch(m['d']),
    title: m['t'],
    body: m['b'],
    kind: NewsKind.values.asNameMap()[m['k']] ?? NewsKind.board,
    read: m['r'] ?? false,
  );
}
