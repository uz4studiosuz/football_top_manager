import 'dart:math';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// O'yindagi voqea turlari (Match Events)
enum MatchEventType {
  kickoff('O‘yin boshlandi'),
  pass('Hujum'),
  shot('Zarba'),
  save('Seyv'),
  goal('GOL!'),
  foul('Qoidabuzarlik'),
  yellowCard('Sariq kartochka'),
  redCard('Qizil kartochka'),
  halfTime('Tanaffus'),
  fullTime('O‘yin yakunlandi'),
  substitution('Almashtirish'),
  corner('Burchak'),
  freeKick('Jarima zarbasi'),
  penalty('Penalti'),
  offside('Ofsayd'),
  injury('Jarohat'),
  woodwork('Ustun'),
  bigChance('Katta imkoniyat'),
  info('Ma’lumot'),
  varCheck('VAR tekshiruvi');

  const MatchEventType(this._label);
  final String _label;
  String get label => tr(_label);
  IconData get iconData => switch (this) {
    kickoff => Icons.sports_outlined,
    pass => Icons.trending_flat_rounded,
    shot => Icons.gps_fixed,
    save => Icons.back_hand_outlined,
    goal => Icons.sports_soccer,
    foul => Icons.do_not_touch_outlined,
    yellowCard || redCard => Icons.crop_portrait_rounded,
    halfTime => Icons.pause_circle_outline,
    fullTime => Icons.flag_outlined,
    substitution => Icons.swap_vert_rounded,
    corner => Icons.flag_circle_outlined,
    freeKick => Icons.adjust_rounded,
    penalty => Icons.radio_button_checked,
    offside => Icons.outlined_flag_rounded,
    injury => Icons.healing_outlined,
    woodwork => Icons.vertical_align_center_rounded,
    bigChance => Icons.local_fire_department_outlined,
    info => Icons.info_outline_rounded,
    varCheck => Icons.tv_rounded,
  };

  /// Key moments shown in the SofaScore-like incident timeline.
  bool get isIncident =>
      this == goal ||
      this == yellowCard ||
      this == redCard ||
      this == substitution ||
      this == injury ||
      this == halfTime ||
      this == fullTime;
}

/// O'yin simulyatsiyasi voqeasi
class MatchEvent {
  final int minute;
  final int extraMinute;
  final MatchEventType type;
  final String description;
  final String clubId;
  final String? playerName;
  final String? playerId;
  final String? secondaryName;
  final bool isHomeTeam;
  final String? assistPlayerId;
  final int homeScore, awayScore;
  const MatchEvent({
    required this.minute,
    required this.type,
    required this.description,
    required this.clubId,
    this.playerName,
    required this.isHomeTeam,
    this.assistPlayerId,
    this.playerId,
    this.secondaryName,
    this.extraMinute = 0,
    this.homeScore = 0,
    this.awayScore = 0,
  });
  String get minuteLabel =>
      extraMinute > 0 ? '$minute+$extraMinute\'' : '$minute\'';
}

/// Per-player match line. The rating follows SofaScore conventions: a
/// player starts near 6.3–6.5 and every action moves it up or down.
/// One thing a player did on the pitch, for his action maps. Positions are
/// from his own side's view (attacking to the right).
enum ActionKind { pass, cross, tackle, interception, clearance, block, dribble, lost, foul, aerial ,
  claim,
  punch,
  sweep,
}

class PlayerAction {
  final ActionKind kind;
  final Offset from, to;
  final bool ok;
  final int minute;
  const PlayerAction(this.kind, this.from, this.to, this.ok, this.minute);

  /// Distance of a pass or carry in metres.
  double get meters => sqrt(pow((to.dx - from.dx) * 105, 2) + pow((to.dy - from.dy) * 68, 2)).toDouble();

  static String _d(double v) => (v * 99).round().clamp(0, 99).toString().padLeft(2, '0');
  static double _u(String s) => int.parse(s) / 99;

  /// Fixed-width text, 12 characters per action.
  String encode() => '${kind.index.toRadixString(36)}${ok ? 1 : 0}${_d(from.dx)}${_d(from.dy)}${_d(to.dx)}${_d(to.dy)}${minute.clamp(0, 99).toString().padLeft(2, '0')}';

  static List<PlayerAction> decodeAll(String? text) {
    if (text == null) return const [];
    final out = <PlayerAction>[];
    for (var i = 0; i + 12 <= text.length; i += 12) {
      final k = int.tryParse(text[i], radix: 36);
      if (k == null || k >= ActionKind.values.length) continue;
      out.add(PlayerAction(
        ActionKind.values[k],
        Offset(_u(text.substring(i + 2, i + 4)), _u(text.substring(i + 4, i + 6))),
        Offset(_u(text.substring(i + 6, i + 8)), _u(text.substring(i + 8, i + 10))),
        text[i + 1] == '1',
        int.parse(text.substring(i + 10, i + 12)),
      ));
    }
    return out;
  }
}

class PlayerMatchStats {
  final String playerId;
  final bool started;
  double minutes = 0;
  int passes = 0,
      passesCompleted = 0,
      keyPasses = 0,
      shots = 0,
      shotsOnTarget = 0,
      goals = 0,
      assists = 0,
      tackles = 0,
      interceptions = 0,
      clearances = 0,
      blocks = 0,
      dribbles = 0,
      dribblesWon = 0,
      duelsWon = 0,
      duelsLost = 0,
      fouls = 0,
      fouled = 0,
      saves = 0,
      goalsConceded = 0,
      yellow = 0,
      red = 0,
      possessionLost = 0,
      offsides = 0,
      bigChancesMissed = 0,
      crosses = 0,
      touches = 0,
      errorsLeadingToShot = 0,
      errorsLeadingToGoal = 0,
      penaltiesConceded = 0,
      penaltiesWon = 0,
      penaltiesSaved = 0,
      bigChancesCreated = 0,
      dribbledPast = 0;
  double xg = 0, xa = 0;

  /// Distance run, in metres.
  double distanceM = 0;
  bool injured = false;
  int? subOnMinute, subOffMinute;
  PlayerMatchStats(this.playerId, {this.started = true});

  double rating({
    required bool goalkeeper,
    required bool defender,
    required bool forward,
    required int goalDifference,
  }) {
    // SofaScore-like: a common core plus weights that depend on the role
    // (keepers judged on saves, defenders on defending, forwards on output).
    final midfielder = !goalkeeper && !defender && !forward;
    var r = 6.35;
    r += goals * (forward ? 0.95 : defender ? 1.2 : 1.05);
    r += assists * 0.7;
    r += keyPasses * (midfielder ? 0.18 : 0.15);
    r += bigChancesCreated * 0.22;
    r += (shotsOnTarget - goals).clamp(0, 99) * (forward ? 0.12 : 0.1);
    r -= (shots - shotsOnTarget).clamp(0, 99) * 0.03;
    r -= bigChancesMissed * (forward ? 0.25 : 0.2);
    r += passesCompleted * (midfielder ? 0.011 : 0.008);
    r -= (passes - passesCompleted) * (midfielder ? 0.034 : 0.028);
    r += tackles * (defender ? 0.13 : 0.11) +
        interceptions * (defender ? 0.12 : 0.09) +
        clearances * (defender ? 0.06 : 0.04) +
        blocks * 0.1;
    r += dribblesWon * (forward ? 0.1 : 0.08) - (dribbles - dribblesWon) * 0.04;
    r -= dribbledPast * (defender ? 0.09 : 0.06);
    r += (duelsWon - duelsLost) * 0.02;
    r -= fouls * 0.06;
    r += fouled * 0.03;
    // Discipline: a second yellow counts as a red.
    r -= yellow * 0.3 + red * 1.6;
    r -= possessionLost * (forward ? 0.016 : 0.024);
    r -= offsides * 0.04;
    // Decisive moments.
    r -= errorsLeadingToShot * 0.35 + errorsLeadingToGoal * 1.0;
    r -= penaltiesConceded * 0.7;
    r += penaltiesWon * 0.4;
    final cleanSheet = minutes >= 60 && goalsConceded == 0;
    if (goalkeeper) {
      r += saves * 0.3 + penaltiesSaved * 0.9 - goalsConceded * 0.22 + (cleanSheet ? 0.45 : 0);
    } else if (defender) {
      r -= goalsConceded * 0.09;
      if (cleanSheet) r += 0.3;
    } else if (midfielder && cleanSheet) {
      r += 0.08;
    }
    r += goalDifference.clamp(-3, 3) * 0.06;
    if (minutes < 25) r = 6.5 + (r - 6.5) * (0.5 + minutes / 50);
    return (r.clamp(3.0, 10.0) * 10).round() / 10;
  }
}

/// One attempt on goal with SofaScore-style details.
class ShotRecord {
  final Offset origin, end;
  final bool home, goal;
  final double xg;
  final String playerId;
  final int minute;
  final String outcome; // goal, save, miss, block, woodwork
  final String body; // right, left, head
  final String situation; // open, assisted, corner, setPiece, freeKick, penalty
  final String? assistId;
  final Offset? assistFrom;

  /// Goal-frame point seen from the shooter: x 0..1 post to post,
  /// y 0..1 ground to bar. Values outside the frame are misses;
  /// blocked shots have no frame point (x < -5).
  final double mouthX, mouthY;
  final double xgot;
  const ShotRecord(
    this.origin,
    this.end,
    this.home,
    this.goal,
    this.xg,
    this.playerId,
    this.minute, [
    this.outcome = 'miss',
    this.body = 'right',
    this.situation = 'open',
    this.assistId,
    this.assistFrom,
    this.mouthX = -9,
    this.mouthY = 0,
    this.xgot = 0,
  ]);

  bool get onTarget => outcome == 'goal' || outcome == 'save';
  bool get hasMouth => mouthX > -5;

  String get bodyLabel => switch (body) {
    'left' => tr('Chap oyoq'),
    'head' => tr('Bosh'),
    _ => tr('O‘ng oyoq'),
  };

  String get situationLabel => switch (situation) {
    'assisted' => tr('Uyushgan hujum'),
    'corner' => tr('Burchak to‘pi'),
    'setPiece' => tr('Standart holat'),
    'freeKick' => tr('Jarima zarbasi'),
    'penalty' => tr('Penalti'),
    _ => tr('Ochiq o‘yin'),
  };

  String get outcomeLabel => switch (outcome) {
    'goal' => tr('Gol'),
    'save' => tr('Qaytarildi'),
    'block' => tr('To‘sildi'),
    'woodwork' => tr('Darvoza ramkasi'),
    _ => tr('Nishondan tashqari'),
  };

  /// Nine-zone name of where the ball crossed the line.
  String get zoneLabel {
    if (!hasMouth) return '–';
    final col = mouthX < 0.34 ? 'chap' : (mouthX > 0.66 ? tr('o‘ng') : 'markaz');
    final row = mouthY < 0.34 ? tr('Pastki') : (mouthY > 0.66 ? tr('Yuqori') : tr('O‘rta'));
    return '$row $col';
  }

  static double _r(double v) => (v * 1000).roundToDouble() / 1000;

  Map<String, dynamic> toMap() => {
    'o': [_r(origin.dx), _r(origin.dy)],
    'e': [_r(end.dx), _r(end.dy)],
    'h': home ? 1 : 0,
    'x': _r(xg),
    'p': playerId,
    'm': minute,
    'r': outcome,
    'b': body,
    's': situation,
    if (assistId != null) 'a': assistId,
    if (assistFrom != null) 'af': [_r(assistFrom!.dx), _r(assistFrom!.dy)],
    'g': [_r(mouthX), _r(mouthY)],
    'xo': _r(xgot),
  };

  factory ShotRecord.fromMap(Map<String, dynamic> m) {
    Offset off(List v) => Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
    final g = (m['g'] as List?) ?? [-9, 0];
    return ShotRecord(
      off(m['o']),
      off(m['e']),
      m['h'] == 1,
      m['r'] == 'goal',
      (m['x'] as num).toDouble(),
      m['p'],
      m['m'],
      m['r'] ?? 'miss',
      m['b'] ?? 'right',
      m['s'] ?? 'open',
      m['a'],
      m['af'] == null ? null : off(m['af']),
      (g[0] as num).toDouble(),
      (g[1] as num).toDouble(),
      ((m['xo'] ?? 0) as num).toDouble(),
    );
  }
}

/// Uchrashuv taqvimi (Fixture)
class Fixture {
  final String id;
  final int round;
  final String homeClubId;
  final String awayClubId;
  DateTime? date;
  int? homeScore;
  int? awayScore;
  bool isPlayed;
  List<MatchEvent> events;
  int homePasses, awayPasses, homeCompletedPasses, awayCompletedPasses;
  int homeShots;
  int awayShots;
  int homeShotsOnTarget;
  int awayShotsOnTarget;
  int homePossession;
  int awayPossession;
  int homeCorners;
  int awayCorners;
  int homeFouls;
  int awayFouls;
  int homeSaves = 0, awaySaves = 0;
  int homeOffsides = 0, awayOffsides = 0;
  int homeTackles = 0, awayTackles = 0;
  int homeBigChances = 0, awayBigChances = 0;
  int homeYellows = 0, awayYellows = 0, homeReds = 0, awayReds = 0;
  int attendance = 0;
  double homeXG;
  double awayXG;
  Map<String, double> ratings = {};
  Map<String, PlayerMatchStats> playerStats = {};
  List<String> homeLineup = [], awayLineup = [];
  List<String> homeBench = [], awayBench = [];
  List<double> momentum = [];
  List<ShotRecord> shots = [];

  /// Encoded player heatmaps (user's matches only; see ui/heatmap.dart).
  Map<String, String> heat = {};

  /// Encoded [PlayerAction]s per player (the latest user matches only).
  Map<String, String> actions = {};
  String? motmId;
  Fixture({
    required this.id,
    required this.round,
    required this.homeClubId,
    required this.awayClubId,
    this.date,
    this.homeScore,
    this.awayScore,
    this.isPlayed = false,
    List<MatchEvent>? events,
    this.homePasses = 0,
    this.awayPasses = 0,
    this.homeCompletedPasses = 0,
    this.awayCompletedPasses = 0,
    this.homeShots = 0,
    this.awayShots = 0,
    this.homeShotsOnTarget = 0,
    this.awayShotsOnTarget = 0,
    this.homePossession = 50,
    this.awayPossession = 50,
    this.homeCorners = 0,
    this.awayCorners = 0,
    this.homeFouls = 0,
    this.awayFouls = 0,
    this.homeXG = 0.0,
    this.awayXG = 0.0,
  }) : events = events ?? [];
  bool get hasResult => isPlayed && homeScore != null && awayScore != null;
  String get scoreDisplay => hasResult ? '$homeScore - $awayScore' : 'VS';
  bool involves(String clubId) =>
      homeClubId == clubId || awayClubId == clubId;
  String resultFor(String clubId) {
    if (!hasResult) return '';
    final mine = clubId == homeClubId ? homeScore! : awayScore!;
    final theirs = clubId == homeClubId ? awayScore! : homeScore!;
    return mine > theirs
        ? 'W'
        : mine == theirs
        ? 'D'
        : 'L';
  }
}

/// Liga turnir jadvali qatori (Standings Row)
class LeagueStanding {
  final String clubId;
  int played;
  int won;
  int drawn;
  int lost;
  int goalsFor;
  int goalsAgainst;
  List<String> formGuide;
  LeagueStanding({
    required this.clubId,
    this.played = 0,
    this.won = 0,
    this.drawn = 0,
    this.lost = 0,
    this.goalsFor = 0,
    this.goalsAgainst = 0,
    List<String>? formGuide,
  }) : formGuide = formGuide ?? [];
  int get goalDifference => goalsFor - goalsAgainst;
  int get points => (won * 3) + drawn;
  void recordMatch({required int myGoals, required int opponentGoals}) {
    played++;
    goalsFor += myGoals;
    goalsAgainst += opponentGoals;
    if (myGoals > opponentGoals) {
      won++;
      _addForm('W');
    } else if (myGoals == opponentGoals) {
      drawn++;
      _addForm('D');
    } else {
      lost++;
      _addForm('L');
    }
  }

  void _addForm(String result) {
    formGuide.add(result);
    if (formGuide.length > 5) formGuide.removeAt(0);
  }

  LeagueStanding copy() => LeagueStanding(
    clubId: clubId,
    played: played,
    won: won,
    drawn: drawn,
    lost: lost,
    goalsFor: goalsFor,
    goalsAgainst: goalsAgainst,
    formGuide: List<String>.from(formGuide),
  );
}
