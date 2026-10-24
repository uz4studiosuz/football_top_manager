import 'dart:math';
import 'dart:ui';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';
import 'commentary.dart';
import '../ui/heatmap.dart' show encodeHeat, heatCols, heatRows;
import '../l10n/l10n.dart';

enum FieldPhase {
  kickoff,
  openPlay,
  pass,
  shot,
  goal,
  stoppage,
  halfTime,
  fullTime,
}

class SideMatchStats {
  int goals = 0,
      shots = 0,
      onTarget = 0,
      corners = 0,
      fouls = 0,
      yellows = 0,
      reds = 0,
      passes = 0,
      completedPasses = 0,
      saves = 0,
      offsides = 0,
      tackles = 0,
      interceptions = 0,
      bigChances = 0,
      dribbles = 0,
      crosses = 0,
      blocked = 0,
      subs = 0,
      freeKicks = 0,
      throwIns = 0;
  double xg = 0, possessionSeconds = 0;
  int get passAccuracy =>
      passes == 0 ? 0 : (completedPasses * 100 / passes).round();
}

enum _Kind { pass, cross, shot, header, penalty, freeKick, corner }

enum _SetPiece { none, corner, freeKick, penalty, throwIn, goalKick }

class _Flight {
  final Offset from, to;
  final bool home;
  final _Kind kind;
  final bool lofted;
  final int receiver;
  final String outcome;
  final Player actor;
  final String? assist;
  final double duration, xg;
  final Player? blocker;
  final ShotRecord? record;
  final String? errorBy;
  double elapsed = 0;
  final Set<String> checked = {};
  _Flight({
    required this.from,
    required this.to,
    required this.home,
    required this.actor,
    this.kind = _Kind.pass,
    this.receiver = 0,
    this.lofted = false,
    this.outcome = 'pass',
    this.assist,
    this.duration = 0.4,
    this.xg = 0,
    this.blocker,
    this.record,
    this.errorBy,
  });
  bool get shot =>
      kind == _Kind.shot ||
      kind == _Kind.header ||
      kind == _Kind.penalty ||
      kind == _Kind.freeKick;
}

/// One recorded moment of play (for goal replays).
class ReplayFrame {
  final List<Offset> home, away;
  final Offset ball;
  final double ballHeight;
  const ReplayFrame(this.home, this.away, this.ball, this.ballHeight);
}

/// The build-up to a goal and the moments after it.
class GoalReplay {
  final int minute;
  final String scorer;
  final bool home;
  final List<ReplayFrame> frames;
  GoalReplay(this.minute, this.scorer, this.home, this.frames);
}

/// The pitch is authoritative: decisions create ball flights; completed
/// flights create goals, saves, turnovers and every statistic the UI shows.
/// Each player also accumulates a SofaScore-style match line and rating.
class MatchField {
  /// Action time runs faster than the match clock so a 90-minute match has a
  /// realistic number of attacks, shots and set pieces.
  static const tempo = 2.6;
  final Club home, away;
  final Random random;
  late final Commentary _talk;
  int homeCoaching, awayCoaching;
  bool homeAI, awayAI;
  final SideMatchStats homeStats = SideMatchStats(),
      awayStats = SideMatchStats();
  final List<MatchEvent> events = [];
  final List<ShotRecord> shots = [];
  final Map<String, PlayerMatchStats> lines = {};
  final List<double> momentum = [];
  final Map<String, int> injuries = {}; // id → rounds out
  late final List<String> homeStartIds, awayStartIds;
  late final List<String> homeBenchIds, awayBenchIds;
  late List<Player> _homeXI, _awayXI;
  String _homeSignature = '', _awaySignature = '';
  final Map<Club, TeamTactics> _baseTactics = {};
  final Map<Club, List<Offset>> _basePositions = {};
  final Set<String> dismissed = {};
  final Set<String> subbedOff = {};
  final Map<String, int> bookings = {};
  final Set<String> _injuredOnPitch = {};
  final Map<String, double> _beaten = {};

  /// Where each player has been (heatCols × heatRows, attacking right).
  final Map<String, List<int>> heat = {};
  double _heatClock = 0;

  void _sampleHeat() {
    for (final side in [true, false]) {
      final xi = _xi(side ? home : away);
      final points = side ? homePositions : awayPositions;
      for (var i = 0; i < 11; i++) {
        if (dismissed.contains(xi[i].id)) continue;
        var pt = points[i];
        if (!side) pt = Offset(1 - pt.dx, 1 - pt.dy);
        final cx = (pt.dx * heatCols).floor().clamp(0, heatCols - 1);
        final cy = (pt.dy * heatRows).floor().clamp(0, heatRows - 1);
        (heat[xi[i].id] ??= List.filled(heatCols * heatRows, 0))[cy * heatCols + cx]++;
      }
    }
  }

  /// Players who just lost a duel cannot challenge again straight away, so
  /// two players never stand on the ball trading tackles.
  final Map<String, double> _duelCooldown = {};
  late List<Offset> homePositions, awayPositions;
  late List<Offset> _homeVelocity, _awayVelocity;
  Offset ball = const Offset(0.5, 0.5);
  double ballHeight = 0;
  bool homePossession = true;
  int owner = 6;
  double time = 0;
  int period = 1;
  int extraFirst = 0, extraSecond = 0;
  FieldPhase phase = FieldPhase.kickoff;
  double homeAttack = 1, awayAttack = 1;

  /// Training and team-talk effects: attack multiplier, the share of the
  /// opponents' chance quality allowed (lower = tighter) and stamina drain.
  double homeAttackBoost = 1, awayAttackBoost = 1;
  double homeFocus = 1, awayFocus = 1;
  double homeFitness = 1, awayFitness = 1;

  /// VAR reviews so far (shown by the match screen as they happen).
  int varReviews = 0;

  /// Derby: more duels, fouls and cards.
  bool derby = false;

  /// Level shift: absolute stat thresholds were set for elite squads, so
  /// stats are lifted most of the way towards that level. Who is better
  /// than whom stays the same; a weaker league just plays a similar game.
  late final double _lvl = _levelShift(false), _gkLvl = _levelShift(true);

  double _levelShift(bool keepers) {
    const keys = ['finishing', 'lowPass', 'loftedPass', 'attackingAwareness', 'ballControl', 'kickingPower', 'curl', 'dribbling'];
    var sum = 0.0, n = 0;
    for (final c in [home, away]) {
      for (final p in _xi(c)) {
        if (p.mainPosition.isGoalkeeper != keepers) continue;
        final m = p.stats.toMap();
        if (keepers) {
          sum += p.stats.gkRating;
          n++;
        } else {
          for (final k in keys) {
            sum += m[k] as int;
            n++;
          }
        }
      }
    }
    if (n == 0) return 0;
    return ((keepers ? 83.0 : 77.0) - sum / n).clamp(0.0, 25.0) * 0.8;
  }

  /// Live view only: keeps the last moments of play so goals can be replayed.
  bool recordReplays = false;
  final List<ReplayFrame> _frames = [];
  final List<GoalReplay> replays = [];
  double _frameClock = 0;
  GoalReplay? _pendingReplay;
  int _framesAfterGoal = 0;

  void _recordFrame(double dt) {
    _frameClock += dt;
    if (_frameClock < 0.015) return;
    _frameClock = 0;
    final frame = ReplayFrame(List.of(homePositions), List.of(awayPositions), ball, ballHeight);
    _frames.add(frame);
    if (_frames.length > 70) _frames.removeAt(0);
    final pending = _pendingReplay;
    if (pending != null) {
      pending.frames.add(frame);
      if (--_framesAfterGoal <= 0) {
        replays.add(pending);
        _pendingReplay = null;
      }
    }
  }

  /// Team mentality as a shape: -2 park the bus … 0 balanced … +2 all-out attack.
  double homeShape = 0, awayShape = 0;

  /// Effective shape, including AI chasing a game or protecting a lead.
  double _shape(bool isHome) =>
      ((isHome ? homeShape : awayShape) + ((isHome ? _aiHomeMentality : _aiAwayMentality) - 1) * 6).clamp(-2.0, 2.0);

  /// How much space a defending side leaves: an attacking shape opens gaps
  /// behind (experienced, aware defenders cover part of it); a deep block
  /// crowds the box and makes shots harder.
  /// Defensive actions in a side's own half: fewer bodies back in an
  /// attacking shape, more in a low block.
  double _ownHalfCover(bool defendingHome) {
    final inOwnHalf = defendingHome ? ball.dx < 0.5 : ball.dx > 0.5;
    return inOwnHalf ? 1 - _shape(defendingHome) * 0.13 : 1;
  }

  double _exposure(bool defendingHome) {
    final s = _shape(defendingHome);
    if (s < 0) return 1 + s * 0.12;
    if (s == 0) return 1;
    final xi = _xi(defendingHome ? home : away);
    final backs = [
      for (var i = 1; i < 11; i++)
        if (!dismissed.contains(xi[i].id) &&
            (xi[i].mainPosition.isDefender || xi[i].mainPosition == PlayerPosition.dmf))
          xi[i],
    ];
    final experience = backs.isEmpty
        ? 0.5
        : (backs
                      .map((p) => (p.stats.defensiveAwareness - 60) / 35 + (p.age - 23) / 20)
                      .reduce((a, b) => a + b) /
                  backs.length)
              .clamp(0.0, 1.0);
    return 1 + s * 0.22 * (1 - experience * 0.5);
  }
  double _aiHomeMentality = 1, _aiAwayMentality = 1;
  double _hold = 0, _stoppage = 0.65, _tackleClock = 0, _minuteAcc = 0;
  double _recycleAcc = 0, _momHome = 0, _momAway = 0;
  int _consumed = 0;
  String? _lastPasser;
  Offset? _lastPassFrom;
  // Last ball lost deep in a team's own third (for "error leading to shot").
  ({String id, bool home, double time})? _error;

  void _markError(Player p, bool losingHome, Offset at) {
    final depth = losingHome ? 1 - at.dx : at.dx;
    if (depth > 0.8) _error = (id: p.id, home: losingHome, time: time);
  }
  // Set-piece origin of the current attack (corner / free-kick delivery).
  String? _origin;
  bool _originHome = true;
  bool _setPieceDelivery = false;
  int _pendingTaker = 1;
  double _regroup = 0; // fast jog back to shape after a set piece
  int _homeSubWindows = 0, _awaySubWindows = 0;
  int _homeLastSubMinute = -9, _awayLastSubMinute = -9;
  _SetPiece _pending = _SetPiece.none;
  Offset _pendingSpot = const Offset(0.5, 0.5);
  bool _pendingHome = true;
  _Flight? _flight;
  final List<int> _homeSubMinutes = [], _awaySubMinutes = [];
  int _homeWindows = 0, _awayWindows = 0;

  MatchField(
    this.home,
    this.away, {
    int seed = 73,
    this.homeCoaching = 70,
    this.awayCoaching = 70,
    this.homeAI = true,
    this.awayAI = true,
  }) : random = Random(seed) {
    _talk = Commentary(random);
    _refreshLineups();
    homeStartIds = List.of(home.startingLineupIds);
    awayStartIds = List.of(away.startingLineupIds);
    homeBenchIds = List.of(home.benchIds);
    awayBenchIds = List.of(away.benchIds);
    homePositions = List.of(_bases(home, true));
    awayPositions = List.of(_bases(away, false));
    _homeVelocity = List.filled(11, Offset.zero);
    _awayVelocity = List.filled(11, Offset.zero);
    homePositions[owner] = ball;
    for (final p in [..._homeXI, ..._awayXI]) {
      lines[p.id] = PlayerMatchStats(p.id);
    }
    for (final list in [_homeSubMinutes, _awaySubMinutes]) {
      list
        ..add(56 + random.nextInt(12))
        ..add(69 + random.nextInt(10))
        ..add(81 + random.nextInt(6));
    }
    _emit(
      MatchEventType.kickoff,
      _talk.say('kickoff', t: home.shortName),
      true,
      null,
    );
  }

  // ------------------------------------------------------------ accessors
  List<Player> _xi(Club c) => identical(c, home) ? _homeXI : _awayXI;
  static bool _is(Player p, Set<PlayingStyle> styles) =>
      styles.contains(p.playingStyle);
  static const _finishers = {
    PlayingStyle.goalPoacher,
    PlayingStyle.foxInTheBox,
    PlayingStyle.advancedStriker,
  };
  static const _creators = {
    PlayingStyle.creativePlaymaker,
    PlayingStyle.orchestrator,
    PlayingStyle.classicNo10,
    PlayingStyle.deepLyingForward,
  };
  List<Player> get homeXI => _homeXI;
  List<Player> get awayXI => _awayXI;
  void _refreshLineups() {
    final h = home.startingLineupIds.join('|'),
        a = away.startingLineupIds.join('|');
    if (h != _homeSignature) {
      _homeSignature = h;
      _homeXI = home.startingXI;
    }
    if (a != _awaySignature) {
      _awaySignature = a;
      _awayXI = away.startingXI;
    }
  }

  SideMatchStats get _att => homePossession ? homeStats : awayStats;
  SideMatchStats get _def => homePossession ? awayStats : homeStats;
  Club get _club => homePossession ? home : away;
  Club get _opponent => homePossession ? away : home;
  List<Offset> get _points => homePossession ? homePositions : awayPositions;
  List<Offset> get _rivals => homePossession ? awayPositions : homePositions;
  PlayerMatchStats _line(Player p) =>
      lines.putIfAbsent(p.id, () => PlayerMatchStats(p.id, started: false));
  bool get isHalfTime => phase == FieldPhase.halfTime;
  bool get isFinished => phase == FieldPhase.fullTime;
  int get homeSubsUsed => homeStats.subs;
  int get awaySubsUsed => awayStats.subs;
  bool isOnPitch(String id) =>
      (home.startingLineupIds.contains(id) ||
          away.startingLineupIds.contains(id)) &&
      !dismissed.contains(id);
  bool isInjuredOnPitch(String id) => _injuredOnPitch.contains(id);
  Set<String> get injuredOnPitch => Set.unmodifiable(_injuredOnPitch);

  double get _periodEnd => period == 1 ? 45.0 + extraFirst : 90.0 + extraSecond;
  int get displayMinute {
    if (period == 1) return min(45, time.floor() + 1);
    return min(90, time.floor() + 1);
  }

  int get displayExtra {
    final cap = period == 1 ? 45.0 : 90.0;
    return time >= cap ? (time - cap).floor() + 1 : 0;
  }

  String get clockLabel {
    if (isFinished) return 'FT';
    if (isHalfTime) return 'HT';
    final cap = period == 1 ? 45 : 90;
    final t = time;
    if (t >= cap) return '$cap+${(t - cap).floor() + 1}\'';
    return '${t.floor() + (t > 0 ? 1 : 0)}\'';
  }

  String get actionLabel => switch (phase) {
    FieldPhase.kickoff => tr('Markazdan boshlash'),
    FieldPhase.openPlay =>
      '${_club.shortName} · ${_xi(_club)[owner].shortName}',
    FieldPhase.pass => switch (_flight?.kind) {
      _Kind.cross || _Kind.corner => tr('Kross'),
      _ => tr('Uzatma'),
    },
    FieldPhase.shot => tr('Zarba'),
    FieldPhase.goal => 'GOL',
    FieldPhase.stoppage => switch (_pending) {
      _SetPiece.corner => tr('Burchak to‘pi'),
      _SetPiece.freeKick => tr('Jarima zarbasi'),
      _SetPiece.penalty => tr('Penalti'),
      _SetPiece.throwIn => tr('Autdan tashlash'),
      _SetPiece.goalKick => tr('Darvozadan zarba'),
      _ => tr('O‘yin to‘xtadi'),
    },
    FieldPhase.halfTime => tr('Tanaffus'),
    FieldPhase.fullTime => tr('O‘yin yakunlandi'),
  };

  int get homePossessionPercent {
    final total = homeStats.possessionSeconds + awayStats.possessionSeconds;
    return total == 0
        ? 50
        : (homeStats.possessionSeconds / total * 100).round();
  }

  bool get ballOwnedByHome => homePossession;
  Offset? get flightFrom => _flight?.from;
  Offset? get flightTo => _flight?.to;
  bool get flightIsShot => _flight?.shot ?? false;
  bool get flightIsHome => _flight?.home ?? homePossession;
  int get ownerIndex => owner;
  Player? get ballCarrier =>
      _flight == null && phase == FieldPhase.openPlay
          ? _xi(_club)[owner]
          : null;

  List<MatchEvent> takeEvents() {
    final fresh = events.skip(_consumed).toList();
    _consumed = events.length;
    return fresh;
  }

  // ---------------------------------------------------------- formations
  List<Offset> _bases(Club c, bool isHome) {
    if (identical(_baseTactics[c], c.tactics)) return _basePositions[c]!;
    _baseTactics[c] = c.tactics;
    final positions = List<Offset>.unmodifiable(
      c.tactics.formation.slots.map((slot) {
        final x = 0.075 + (1 - slot.y) * 0.79;
        // Facing the opponents' goal, the right flank is +y for the home side
        // (attacking towards x = 1) and -y for the away side.
        final side = (slot.x - 0.5) * (0.62 + c.tactics.width * 0.065);
        return Offset(isHome ? x : 1 - x, isHome ? 0.5 + side : 0.5 - side);
      }),
    );
    _basePositions[c] = positions;
    return positions;
  }

  Offset _bound(Offset p) =>
      Offset(p.dx.clamp(0.025, 0.975), p.dy.clamp(0.045, 0.955));
  bool _inBounds(Offset p) =>
      p.dx >= 0.0 && p.dx <= 1.0 && p.dy >= 0.03 && p.dy <= 0.97;

  // ----------------------------------------------------------------- tick
  /// Live view only: the clock runs slower while players walk to a set
  /// piece, so corners, free kicks and penalties are set up visibly.
  bool slowSetPieces = false;

  void update(double dt, [Set<String> excluded = const {}]) {
    if (isFinished || isHalfTime) return;
    _refreshLineups();
    dismissed.addAll(excluded);
    if (slowSetPieces &&
        ((phase == FieldPhase.stoppage && _pending != _SetPiece.none) || phase == FieldPhase.goal || phase == FieldPhase.kickoff)) {
      dt *= 0.35;
    }
    var left = dt;
    while (left > 0.000001 && !isFinished && !isHalfTime) {
      final step = min(left, 1 / 60);
      _step(step);
      left -= step;
    }
  }

  /// Runs the remaining match (both halves) at simulation speed.
  void simulateToEnd() {
    while (!isFinished) {
      if (isHalfTime) startSecondHalf();
      update(1 / 30);
    }
  }

  /// Same as [simulateToEnd] but in ~12 ms slices, so loaders keep animating.
  /// [onProgress] receives 0..1.
  Future<void> simulateToEndAsync({void Function(double progress)? onProgress}) async {
    final watch = Stopwatch()..start();
    while (!isFinished) {
      if (isHalfTime) startSecondHalf();
      update(1 / 30);
      if (watch.elapsedMilliseconds >= 12) {
        onProgress?.call((time / 90).clamp(0.0, 1.0));
        await Future<void>.delayed(const Duration(milliseconds: 4));
        watch.reset();
      }
    }
    onProgress?.call(1);
  }

  void startSecondHalf() {
    if (!isHalfTime) return;
    period = 2;
    time = 45;
    restart(false);
    _emit(
      MatchEventType.kickoff,
      _talk.say('secondHalf', t: away.shortName),
      false,
      null,
    );
  }

  void _step(double dt) {
    time += dt;
    if (recordReplays) _recordFrame(dt);
    _minuteAcc += dt;
    for (final club in [home, away]) {
      for (final p in _xi(club)) {
        if (!dismissed.contains(p.id)) _line(p).minutes += dt;
      }
    }
    if (_minuteAcc >= 1) {
      _minuteAcc -= 1;
      _onMinute();
    }
    if (time >= _periodEnd &&
        (_flight == null || !_flight!.shot || time >= _periodEnd + 0.4)) {
      _endPeriod();
      return;
    }
    final adt = dt * tempo;
    _heatClock += dt;
    if (_heatClock >= 0.1 && phase != FieldPhase.halfTime && phase != FieldPhase.fullTime) {
      _heatClock = 0;
      _sampleHeat();
    }
    for (final map in [_beaten, _duelCooldown]) {
      for (final id in map.keys.toList()) {
        final v = map[id]! - adt;
        if (v <= 0) {
          map.remove(id);
        } else {
          map[id] = v;
        }
      }
    }
    if (phase == FieldPhase.goal ||
        phase == FieldPhase.stoppage ||
        phase == FieldPhase.kickoff) {
      _stoppage -= adt;
      if (phase == FieldPhase.stoppage && _pending != _SetPiece.none) {
        _walkToSetPiece(home, homePositions, _homeVelocity, true, adt);
        _walkToSetPiece(away, awayPositions, _awayVelocity, false, adt);
      }
      // After a goal everyone walks back to his own half for the kick-off.
      if (phase == FieldPhase.goal || phase == FieldPhase.kickoff) {
        _walkToKickoff(home, homePositions, _homeVelocity, true, adt);
        _walkToKickoff(away, awayPositions, _awayVelocity, false, adt);
        if (phase == FieldPhase.kickoff && _stoppage <= 0 && _stoppage > -0.8 && _awayFromKickoff) return;
      }
      // The kick waits (a little) until the taker has reached the ball.
      if (_stoppage <= 0 && (_stoppage < -0.8 || !_takerWalking)) _resume();
      return;
    }
    _att.possessionSeconds += dt;
    if (_regroup > 0) _regroup -= adt;
    _move(home, homePositions, _homeVelocity, true, adt);
    _move(away, awayPositions, _awayVelocity, false, adt);
    _trackMomentum(dt);
    if (_flight != null) {
      _advanceFlight(adt);
      return;
    }
    _carrierDecision(adt, dt);
  }

  void _onMinute() {
    // Fatigue.
    for (final club in [home, away]) {
      final t = club.tactics;
      final pressure =
          t.counterPress || t.playstyle == TeamPlaystyle.highPressing;
      final rate =
          (pressure ? 0.46 : 0.28) +
          (t.tempo - 3) * 0.025 +
          (t.pressing - 3) * 0.03;
      for (final p in _xi(club)) {
        if (dismissed.contains(p.id)) continue;
        // Running instructions cost energy.
        final extra = switch (p.instruction) {
          PlayerInstruction.pressing => 0.14,
          PlayerInstruction.makeRuns || PlayerInstruction.trackBack => 0.07,
          PlayerInstruction.anchoring || PlayerInstruction.stayBack => -0.04,
          _ => 0.0,
        };
        if (random.nextDouble() < (rate + extra) * (1.4 - p.stats.stamina / 170) * (club == home ? homeFitness : awayFitness)) {
          p.currentStamina = max(20, p.currentStamina - 1);
        }
      }
    }
    // Attack momentum (SofaScore-style bars): positive = home pressure.
    momentum.add((_momHome - _momAway).clamp(-100.0, 100.0));
    _momHome = 0;
    _momAway = 0;
    // Added time is announced shortly before each half ends.
    if (period == 1 && extraFirst == 0 && time >= 44) {
      extraFirst = _addedTime(first: true);
      _emit(
        MatchEventType.info,
        _talk.say('addedTime', p: '$extraFirst'),
        true,
        null,
      );
    }
    if (period == 2 && extraSecond == 0 && time >= 89) {
      extraSecond = _addedTime(first: false);
      _emit(
        MatchEventType.info,
        _talk.say('addedTime', p: '$extraSecond'),
        true,
        null,
      );
    }
    if (homeAI) _manageAI(true);
    if (awayAI) _manageAI(false);
  }

  int _addedTime({required bool first}) {
    final from = first ? 0 : 45;
    final half = events.where((e) => e.minute > from && e.minute <= from + 45);
    var weight = 0.0;
    for (final e in half) {
      weight += switch (e.type) {
        MatchEventType.goal => 0.5,
        MatchEventType.substitution => 0.35,
        MatchEventType.injury => 1.0,
        MatchEventType.yellowCard || MatchEventType.redCard => 0.25,
        MatchEventType.penalty => 0.6,
        _ => 0,
      };
    }
    final base = first ? 1 : 2;
    return (base + weight.round() + random.nextInt(2)).clamp(1, 7);
  }

  void _endPeriod() {
    _flight = null;
    time = _periodEnd;
    final score = _scoreLine();
    if (period == 1) {
      phase = FieldPhase.halfTime;
      _emit(MatchEventType.halfTime, _talk.say('halfTime', s: score), true, null);
      for (final club in [home, away]) {
        for (final p in _xi(club)) {
          p.currentStamina = min(100, p.currentStamina + 4);
        }
      }
    } else {
      phase = FieldPhase.fullTime;
      if (_momHome != 0 || _momAway != 0) {
        momentum.add((_momHome - _momAway).clamp(-100.0, 100.0));
      }
      _emit(MatchEventType.fullTime, _talk.say('fullTime', s: score), true, null);
    }
  }

  String _scoreLine() =>
      '${home.shortName} ${homeStats.goals}–${awayStats.goals} ${away.shortName}';

  void _trackMomentum(double dt) {
    final progress = homePossession ? ball.dx : 1 - ball.dx;
    if (progress < 0.55) return;
    final weight = pow((progress - 0.55) / 0.45, 2) * 55 * dt;
    if (homePossession) {
      _momHome += weight;
    } else {
      _momAway += weight;
    }
  }

  void _spike(bool forHome, double v) {
    if (forHome) {
      _momHome += v;
    } else {
      _momAway += v;
    }
  }

  // ------------------------------------------------------------- AI bench
  void _manageAI(bool isHome) {
    final club = isHome ? home : away;
    final stats = isHome ? homeStats : awayStats;
    final minute = time.floor();
    final mine = isHome ? homeStats.goals : awayStats.goals;
    final theirs = isHome ? awayStats.goals : homeStats.goals;
    var mentality = 1.0;
    if (period == 2 && minute >= 65 && mine < theirs) mentality = 1.22;
    if (period == 2 && minute >= 80 && mine == theirs + 1) mentality = 0.86;
    if (isHome) {
      _aiHomeMentality = mentality;
    } else {
      _aiAwayMentality = mentality;
    }
    if (stats.subs >= 5) return;
    // Injured players are replaced at once.
    for (final p in _xi(club)) {
      if (_injuredOnPitch.contains(p.id) && !dismissed.contains(p.id)) {
        final sub = _bestReplacement(club, club.startingLineupIds.indexOf(p.id));
        if (sub != null) substitute(isHome, p.id, sub.id);
        return;
      }
    }
    final windows = isHome ? _homeWindows : _awayWindows;
    final plan = isHome ? _homeSubMinutes : _awaySubMinutes;
    if (period != 2 || windows >= plan.length || minute < plan[windows]) {
      return;
    }
    if (isHome) {
      _homeWindows++;
    } else {
      _awayWindows++;
    }
    final candidates = [
      for (var i = 1; i < _xi(club).length; i++)
        if (!dismissed.contains(_xi(club)[i].id)) i,
    ]..sort((a, b) {
        double tired(int i) {
          final p = _xi(club)[i];
          final booked = bookings.containsKey(p.id) ? 12 : 0;
          return p.currentStamina - booked - (_line(p).rating(
                    goalkeeper: false,
                    defender: club.slotPosition(i).isDefender,
                    forward: club.slotPosition(i).isAttacker,
                    goalDifference: mine - theirs,
                  ) -
                  6.5) *
              10;
        }

        return tired(a).compareTo(tired(b));
      });
    final count = windows == 2 ? 1 : 1 + random.nextInt(2);
    var done = 0;
    for (final i in candidates) {
      if (done >= count || stats.subs >= 5) break;
      final out = _xi(club)[i];
      if (out.currentStamina > 82 && windows < 2) continue;
      final sub = _bestReplacement(club, i);
      if (sub == null) continue;
      if (substitute(isHome, out.id, sub.id)) done++;
    }
  }

  Player? _bestReplacement(Club club, int slot) {
    final pos = club.slotPosition(slot);
    final options = club.bench
        .where(
          (p) =>
              !subbedOff.contains(p.id) &&
              !dismissed.contains(p.id) &&
              p.isAvailable &&
              (pos.isGoalkeeper == p.mainPosition.isGoalkeeper),
        )
        .toList();
    if (options.isEmpty) return null;
    options.sort(
      (a, b) => b.getMatchOVR(pos).compareTo(a.getMatchOVR(pos)),
    );
    return options.first;
  }

  /// Live substitution: [inId] from the bench replaces [outId] in its slot.
  bool substitute(bool isHome, String outId, String inId) {
    final club = isHome ? home : away;
    final stats = isHome ? homeStats : awayStats;
    final slot = club.startingLineupIds.indexOf(outId);
    final benchIndex = club.benchIds.indexOf(inId);
    if (stats.subs >= 5 ||
        slot < 0 ||
        benchIndex < 0 ||
        dismissed.contains(outId) ||
        subbedOff.contains(inId) ||
        dismissed.contains(inId) ||
        isFinished) {
      return false;
    }
    final minute0 = displayMinute + displayExtra;
    if (!isHalfTime) {
      final last = isHome ? _homeLastSubMinute : _awayLastSubMinute;
      final windows = isHome ? _homeSubWindows : _awaySubWindows;
      final newWindow = (minute0 - last).abs() > 1;
      if (newWindow && windows >= 3) return false;
      if (newWindow) {
        if (isHome) {
          _homeSubWindows++;
        } else {
          _awaySubWindows++;
        }
      }
      if (isHome) {
        _homeLastSubMinute = minute0;
      } else {
        _awayLastSubMinute = minute0;
      }
    }
    final out = club.playerById(outId)!, incoming = club.playerById(inId)!;
    club.startingLineupIds[slot] = inId;
    club.benchIds[benchIndex] = outId;
    subbedOff.add(outId);
    _injuredOnPitch.remove(outId);
    stats.subs++;
    _refreshLineups();
    final minute = displayMinute;
    _line(out).subOffMinute = minute;
    _line(incoming).subOnMinute = minute;
    if (phase == FieldPhase.openPlay && _flight == null) {
      phase = FieldPhase.stoppage;
      _stoppage = 0.25;
    }
    _emit(
      MatchEventType.substitution,
      _talk.say('sub', p: incoming.shortName, a: out.shortName, t: club.shortName),
      isHome,
      incoming,
      secondary: out.shortName,
    );
    return true;
  }

  // --------------------------------------------------------- carrier play
  void _carrierDecision(double dt, double clockDt) {
    if (dismissed.contains(_xi(_club)[owner].id)) {
      owner = _nearest(_points, ball, _club);
    }
    final carrier = _xi(_club)[owner];
    final dir = homePossession ? 1.0 : -1.0;
    ball = _bound(_points[owner] + Offset(0.012 * dir, 0));
    ballHeight = 0;
    _hold += dt;
    _tackleClock += dt;
    _recycle(clockDt, carrier);
    final pressure = _nearest(_rivals, ball, _opponent, ignoreKeeper: true);
    final defender = _xi(_opponent)[pressure];
    final distance = (_rivals[pressure] - ball).distance;
    final progress = homePossession ? ball.dx : 1 - ball.dx;
    final pressRadius = 0.042 +
        (_opponent.tactics.pressing - 3) * 0.002 +
        (_xi(_opponent)[_nearest(_rivals, ball, _opponent, ignoreKeeper: true)].instruction ==
                PlayerInstruction.pressing
            ? 0.012
            : 0);
    // A keeper with the ball in hand cannot be tackled.
    if (owner != 0 &&
        distance < pressRadius &&
        _tackleClock > 0.3 &&
        !_beaten.containsKey(defender.id) &&
        !_duelCooldown.containsKey(defender.id)) {
      _tackleClock = 0;
      final foulChance =
          0.16 +
          (defender.playingStyle == PlayingStyle.destroyer ? 0.01 : 0) +
          (defender.instruction == PlayerInstruction.tightMarking ? 0.012 : 0) +
          (progress > 0.84 && (ball.dy - 0.5).abs() < 0.29 ? -0.15 : 0) +
          (derby ? 0.03 : 0) +
          (defender.personality == Personality.temperamental ? 0.02 : 0) +
          (defender.stats.aggression - 40) / 800 -
          (defender.stats.tackling - 70) / 700 +
          (_opponent.tactics.pressing - 3) * 0.006 +
          (_injuredOnPitch.contains(defender.id) ? 0.02 : 0);
      if (random.nextDouble() < foulChance) {
        _foul(defender, carrier);
        return;
      }
      final chance =
          (0.31 +
                  (homePossession ? -0.015 : 0.015) +
                  (defender.playingStyle == PlayingStyle.destroyer
                      ? 0.04
                      : 0) +
                  (defender.defendingStyle == DefendingStyle.allActionDefender
                      ? 0.02
                      : 0) +
                  (defender.instruction == PlayerInstruction.tightMarking ||
                          defender.instruction == PlayerInstruction.pressing
                      ? 0.03
                      : 0) +
                  (defender.stats.tackling +
                          defender.stats.defensiveEngagement -
                          carrier.stats.tightPossession -
                          carrier.stats.balance) /
                      170 -
                  // A target man holds the ball up against his marker.
                  (carrier.playingStyle == PlayingStyle.targetMan ? 0.05 : 0) -
                  // Attackers in the final third are harder to dispossess.
                  (progress > 0.62 ? 0.07 : 0))
              .clamp(0.08, 0.6) *
          _ownHalfCover(!homePossession) *
          (_onCounter(homePossession) ? 0.55 : 1);
      if (random.nextDouble() < chance) {
        _line(defender)
          ..tackles += 1
          ..duelsWon += 1;
        _line(carrier)
          ..possessionLost += 1
          ..duelsLost += 1;
        _markError(carrier, homePossession, ball);
        _duelCooldown[carrier.id] = 0.9;
        _tackleClock = -0.5;
        _def.tackles++;
        if (random.nextDouble() < 0.18) {
          _emit(
            MatchEventType.pass,
            _talk.say('tackle', p: defender.shortName),
            !homePossession,
            defender,
          );
        }
        _turnover(pressure);
        return;
      }
      _line(carrier).duelsWon += 1;
      _line(defender).duelsLost += 1;
      _duelCooldown[defender.id] = 0.6;
    }
    final mentality =
        (homePossession
            ? homeAttack * homeAttackBoost * _aiHomeMentality
            : awayAttack * awayAttackBoost * _aiAwayMentality);
    final leading = homePossession
        ? homeStats.goals > awayStats.goals
        : awayStats.goals > homeStats.goals;
    final wasting =
        _club.tactics.timeWasting && leading && period == 2 && time >= 75;
    final decisionInterval =
        (1.02 - _club.tactics.tempo * 0.1).clamp(0.3, 0.92) *
        (progress > 0.62 ? 0.7 : 1) *
        (wasting ? 1.4 : 1) *
        (_onCounter(homePossession) ? 0.5 : 1);
    if (_hold < decisionInterval) return;
    final goal = Offset(homePossession ? 1 : 0, 0.5);
    final meters = _meters(ball, goal);
    // Through on goal: keep running and finish, never turn back. The better
    // the finisher, the earlier and calmer the shot.
    if (owner != 0 && progress > 0.6 && _breakaway()) {
      // The chasing defender may pull him down: a penalty in the box,
      // otherwise a free kick (and often a card) for denying a chance.
      final boxRisk = progress > 0.843 && (ball.dy - 0.5).abs() < 0.296 ? 0.1 : 1.0;
      if (distance < 0.07 && random.nextDouble() < (0.05 + (defender.stats.aggression - 70) / 600) * boxRisk) {
        _foul(defender, carrier);
        return;
      }
      final keeper = _rivals[0];
      // Through on goal a player runs in close; better finishers can shoot a bit earlier.
      final shootFrom = 6 + (carrier.stats.finishing + _lvl) / 16 + (carrier.stats.attackingAwareness + _lvl) / 50;
      if (meters < shootFrom || (keeper - ball).distance < 0.07) {
        breakaways++;
        _startShot(carrier, pressured: false);
      }
      return;
    }
    final central = (ball.dy - 0.5).abs() < 0.26;
    final wide = (ball.dy - 0.5).abs() > 0.27;
    // Shoot. From outside the box only players who can strike a ball try it.
    final longOk = meters <= 18 || random.nextDouble() < _longShotWill(carrier);
    if (owner != 0 &&
        longOk &&
        progress > (_onCounter(homePossession) ? 0.56 : 0.6) &&
        meters < 30 &&
        (central || meters < 18) &&
        // Holding the ball near the box leads to a shot; from range the
        // player keeps looking for a way in instead.
        ((_hold > 1.1 && meters < 22) ||
            (_onCounter(homePossession) && meters < 18) ||
            meters < 17 ||
            random.nextDouble() <
                (0.22 + (carrier.stats.attackingAwareness + _lvl) / 380) *
                    mentality *
                    (meters < 20 ? 7.0 : 0.3))) {
      _startShot(carrier, pressured: distance < 0.06);
      return;
    }
    // Style-driven extra shots: poachers in the box, inside forwards
    // cutting in, and long rangers from distance.
    if (owner != 0 && progress > 0.6) {
      final cutter = _is(carrier, {
            PlayingStyle.prolificWinger,
            PlayingStyle.fullBackFinisher,
          }) ||
          carrier.aiStyles.contains(AiStyle.incisiveRun);
      final styleShot = ((_is(carrier, _finishers) || carrier.playingStyle == PlayingStyle.holePlayer) && meters < 20)
          ? 0.06
          : (cutter && meters < 18)
          ? 0.05
          : (carrier.aiStyles.contains(AiStyle.longRanger) &&
                meters < 33 &&
                central &&
                carrier.stats.kickingPower >= 78)
          ? 0.045
          : 0.0;
      if (styleShot > 0 && random.nextDouble() < styleShot * mentality) {
        _startShot(carrier, pressured: distance < 0.06);
        return;
      }
    }
    // Cross from wide areas in the final third.
    final crossBias =
        (_club.tactics.playstyle == TeamPlaystyle.outWide ? 0.65 : 0.45) +
        (_is(carrier, {
              PlayingStyle.crossSpecialist,
              PlayingStyle.attackingFullBack,
            })
            ? 0.2
            : 0) +
        (carrier.aiStyles.contains(AiStyle.earlyCrosser) ? 0.15 : 0) +
        switch (_club.tactics.attackingArea) {
          AttackingArea.wide => 0.12,
          AttackingArea.centre => -0.1,
          _ => 0.0,
        };
    final crossZone = carrier.aiStyles.contains(AiStyle.earlyCrosser)
        ? 0.64
        : 0.7;
    if (wide && progress > crossZone && random.nextDouble() < crossBias) {
      if (_startCross(carrier)) return;
    }
    // Take on the nearest defender.
    if (distance < 0.075 &&
        owner != 0 &&
        progress > 0.35 &&
        random.nextDouble() <
            (carrier.stats.dribbling + _lvl - 55) /
                150 *
                (carrier.aiStyles.contains(AiStyle.trickster) ||
                        carrier.aiStyles.contains(AiStyle.mazingRun)
                    ? 1.6
                    : 1)) {
      _dribble(carrier, pressure);
      return;
    }
    final next = _choosePass();
    final style = _club.tactics.playstyle;
    // In the final third a player with room carries the ball into the box.
    final drive = progress > 0.62 && progress < 0.86 && distance > 0.08;
    if (next != null &&
        ((distance < 0.13 && !drive) ||
            _hold > 1.15 ||
            owner == 0 ||
            style == TeamPlaystyle.possession ||
            style == TeamPlaystyle.longBall ||
            style == TeamPlaystyle.longBallCounter)) {
      _startPass(next, carrier);
      return;
    }
    if (_hold > 2.1 && next != null) _startPass(next, carrier);
  }

  /// Short recycling passes between the visual "key" actions keep pass
  /// totals and accuracy at broadcast-realistic levels.
  void _recycle(double dt, Player carrier) {
    final style = _club.tactics.playstyle;
    final rate = switch (style) {
          TeamPlaystyle.possession => 13.5,
          TeamPlaystyle.longBall => 7.0,
          TeamPlaystyle.longBallCounter => 7.5,
          TeamPlaystyle.quickCounter => 9.2,
          _ => 10.4,
        } +
        (_club.tactics.tempo - 3) * 0.6;
    _recycleAcc += dt * rate;
    while (_recycleAcc >= 1) {
      _recycleAcc -= 1;
      final xi = _xi(_club);
      final i = 1 + random.nextInt(10);
      final p = xi[i];
      if (dismissed.contains(p.id)) continue;
      final pressureMod = (_opponent.tactics.pressing - 3) * 0.015;
      final ok =
          random.nextDouble() <
          (0.84 + (p.stats.lowPass + _lvl - 75) / 160 - pressureMod).clamp(0.6, 0.97);
      _att.passes++;
      _line(p)
        ..passes += 1
        ..touches += 2;
      if (ok) {
        _att.completedPasses++;
        _line(p).passesCompleted += 1;
      }
    }
  }

  double _meters(Offset a, Offset b) {
    final dx = (a.dx - b.dx) * 105, dy = (a.dy - b.dy) * 68;
    return sqrt(dx * dx + dy * dy);
  }

  bool _offsidePoint(Offset point, bool attackingHome) {
    final defenders = [
      for (var i = 0; i < 11; i++)
        if (!dismissed.contains(_xi(_opponent)[i].id)) _rivals[i].dx,
    ]..sort();
    if (defenders.length < 2) return false;
    return attackingHome
        ? point.dx > defenders[defenders.length - 2] + 0.008 &&
              point.dx > ball.dx + 0.008 &&
              point.dx > 0.5
        : point.dx < defenders[1] - 0.008 &&
              point.dx < ball.dx - 0.008 &&
              point.dx < 0.5;
  }

  int? _choosePass() {
    final club = _club;
    final points = _points;
    final direction = homePossession ? 1.0 : -1.0;
    final candidates = <({int index, double score})>[];
    final style = club.tactics.playstyle;
    final carrier = _xi(club)[owner];
    // How deep the ball is in our own half (1 = own goal line).
    final depth = homePossession ? 1 - ball.dx : ball.dx;
    final ownThird = depth > 0.67;
    final pressed = _nearestDistance(_rivals, ball, _opponent).$2 < 0.1;
    // Open space in front (nobody within reach ahead): no square or back passes.
    final freeAhead = depth < 0.6 && !pressed && _spaceAhead(direction) > 0.14;
    for (var i = 0; i < 11; i++) {
      final mate = _xi(club)[i];
      if (i == owner || dismissed.contains(mate.id)) continue;
      if (!_setPieceDelivery && _offsidePoint(points[i], homePossession)) {
        // Aware passers rarely pick an offside runner.
        final slip = (1 - (carrier.stats.attackingAwareness + _lvl) / 105) * 0.3 +
            (_opponent.tactics.offsideTrap ? 0.08 : 0);
        if (random.nextDouble() > slip) continue;
      }
      final distance = (points[i] - ball).distance;
      final reach =
          carrier.aiStyles.contains(AiStyle.longBallExpert) ||
              carrier.playingStyle == PlayingStyle.orchestrator
          ? 0.82
          : 0.7;
      if (distance < 0.05 || distance > reach) continue;
      final space =
          (_rivals[_nearest(_rivals, points[i], _opponent)] - points[i])
              .distance;
      final progress = (points[i].dx - ball.dx) * direction * (_onCounter(homePossession) ? 1.6 : 1);
      if (freeAhead && progress < 0.02) continue;
      final wide = (points[i].dy - 0.5).abs();
      var score = progress * 0.95 + min(space, 0.25) * 1.8 - distance * 0.22;
      if (style == TeamPlaystyle.possession) score += 0.2 - distance * 0.55;
      if (style == TeamPlaystyle.outWide) {
        score += wide * 0.65;
        if ((ball.dy - 0.5).abs() > 0.26 && mate.mainPosition.isAttacker) {
          score += (0.4 - wide) * 1.4;
        }
      }
      if (style == TeamPlaystyle.quickCounter) score += progress * 0.35;
      final t = club.tactics;
      switch (t.buildUp) {
        case BuildUpStyle.long:
          if (distance > 0.3) score += progress * 0.5;
        case BuildUpStyle.short:
          score += 0.1 - distance * 0.3;
        case BuildUpStyle.mixed:
          break;
      }
      switch (t.attackingArea) {
        case AttackingArea.wide:
          score += wide * 0.4;
        case AttackingArea.centre:
          score += (0.3 - wide) * 0.5;
        case AttackingArea.balanced:
          break;
      }
      if (style == TeamPlaystyle.overload &&
          (points[i].dy - ball.dy).abs() > 0.4 &&
          progress > 0) {
        score += 0.15;
      }
      if (style == TeamPlaystyle.longBall ||
          style == TeamPlaystyle.longBallCounter) {
        score += progress * 0.65 + mate.stats.physicalContact / 1000;
      }
      if (mate.instruction == PlayerInstruction.playmaker) score += 0.08;
      // Runners are found more often going forward; holders get the safe ball.
      if (mate.instruction == PlayerInstruction.makeRuns && progress > 0.05) score += 0.07;
      if (mate.instruction == PlayerInstruction.stayBack && progress > 0.1) score -= 0.05;
      if (_is(carrier, _creators)) score += progress * 0.3;
      if (mate.playingStyle == PlayingStyle.targetMan &&
          (style == TeamPlaystyle.longBall ||
              style == TeamPlaystyle.longBallCounter)) {
        score += 0.12;
      }
      if (_is(mate, _finishers) && progress > 0.1) score += 0.05;
      // A free team-mate inside the box is the pass everyone looks for.
      final mateDepth = homePossession ? points[i].dx : 1 - points[i].dx;
      if (mateDepth > 0.82 && (points[i].dy - 0.5).abs() < 0.3 && space > 0.035) score += 0.55;
      if (i == 0) score -= ownThird ? 0.6 : 0.25;
      // Passing lanes: a rival close to the line can cut the ball out.
      // Near our own goal that is fatal, so keepers and defenders avoid it.
      final lane = _laneGap(ball, points[i]);
      if (ownThird && lane < 0.035) score -= 1.1;
      if (ownThird && space < 0.06) score -= 0.5;
      if (owner == 0 && !club.tactics.playOutFromBack) score += progress * 0.9;
      if (owner == 0 && club.tactics.playOutFromBack && distance < 0.3 && !pressed) {
        score += 0.15;
      }
      // Under pressure in the box the keeper goes long instead of risking it.
      if ((owner == 0 || ownThird) && pressed && distance > 0.3) score += 0.45;
      score += random.nextDouble() * 0.12;
      candidates.add((index: i, score: score));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    if (ownThird) return candidates.first.index; // no gambles at the back
    return candidates[random.nextDouble() < 0.8
            ? 0
            : min(1, candidates.length - 1)]
        .index;
  }

  /// True when no outfield rival stands between the ball and goal.
  bool _breakaway() {
    final direction = homePossession ? 1.0 : -1.0;
    final xi = _xi(_opponent);
    for (var i = 1; i < 11; i++) {
      if (dismissed.contains(xi[i].id)) continue;
      final r = _rivals[i];
      final ahead = (r.dx - ball.dx) * direction;
      // Goalside within a cone, or close enough to catch up from behind.
      if (ahead > -0.03 && (r.dy - ball.dy).abs() < 0.2 + ahead * 0.8) return false;
      if ((r - ball).distance < 0.05) return false;
      // A quicker defender close behind can still get back.
      if ((r - ball).distance < 0.1 && xi[i].stats.speed + 4 >= _xi(_club)[owner].stats.speed) return false;
    }
    return true;
  }

  /// Goalkeeping quality against one shot: reflexes up close, reach and
  /// positioning from mid-range, handling and reading from distance.
  double _keeperSkill(Player k, double meters, _Kind kind) {
    final s = k.stats;
    if (kind == _Kind.header) return s.gkReflexes * 0.4 + s.gkReach * 0.35 + s.gkAwareness * 0.25;
    if (kind == _Kind.freeKick) return s.gkReach * 0.4 + s.gkAwareness * 0.4 + s.gkReflexes * 0.2;
    if (meters < 12) return s.gkReflexes * 0.5 + s.gkAwareness * 0.3 + s.gkReach * 0.2;
    if (meters < 20) return s.gkReach * 0.35 + s.gkReflexes * 0.3 + s.gkAwareness * 0.35;
    return s.gkAwareness * 0.35 + s.gkCatching * 0.3 + s.gkReach * 0.25 + s.gkReflexes * 0.1;
  }

  /// Open-play strike quality: finishing in the box, power and curl from
  /// range, and a penalty for the weaker foot.
  double _openPlayStrike(Player p, double meters) {
    final s = p.stats;
    var strike = meters < 12
        ? s.finishing * 0.8 + s.ballControl * 0.2
        : meters < 18
        ? s.finishing * 0.6 + s.kickingPower * 0.2 + s.curl * 0.2
        : s.kickingPower * 0.45 + s.curl * 0.3 + s.finishing * 0.25;
    if (random.nextDouble() < 0.25) strike -= (5 - p.weakFoot) * 4;
    return strike;
  }

  /// How willing a player is to shoot from distance (power, curl, finishing).
  double _longShotWill(Player p) {
    final s = p.stats;
    final quality = s.kickingPower * 0.45 + s.curl * 0.3 + s.finishing * 0.25;
    return ((quality + _lvl - 70) / 24).clamp(0.02, 0.7) * (p.aiStyles.contains(AiStyle.longRanger) ? 1.5 : 1);
  }

  /// Distance to the nearest rival ahead of the ball, within a forward cone.
  double _spaceAhead(double direction) {
    var best = 1.0;
    final xi = _xi(_opponent);
    for (var i = 0; i < 11; i++) {
      if (dismissed.contains(xi[i].id)) continue;
      final r = _rivals[i];
      final ahead = (r.dx - ball.dx) * direction;
      if (ahead < -0.01 || (r.dy - ball.dy).abs() > 0.1 + ahead * 0.7) continue;
      best = min(best, (r - ball).distance);
    }
    return best;
  }

  /// Closest rival to the passing line from [a] to [b].
  double _laneGap(Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    var best = double.infinity;
    final xi = _xi(_opponent);
    for (var i = 0; i < 11; i++) {
      if (dismissed.contains(xi[i].id)) continue;
      final ap = _rivals[i] - a;
      final t = len2 == 0 ? 0.0 : ((ap.dx * ab.dx + ap.dy * ab.dy) / len2).clamp(0.0, 1.0);
      final d = (_rivals[i] - (a + ab * t)).distance;
      if (d < best) best = d;
    }
    return best;
  }

  void _startPass(int target, Player passer) {
    final point = _points[target];
    final receiver = _xi(_club)[target];
    final distance = (point - ball).distance;
    final lofted =
        distance > 0.32 || _club.tactics.playstyle == TeamPlaystyle.longBall;
    final skill = _setPieceDelivery
        ? (passer.stats.setPieceTaking + passer.stats.loftedPass) / 2
        : lofted
        ? passer.stats.loftedPass
        : passer.stats.lowPass;
    _att.passes++;
    _line(passer)
      ..passes += 1
      ..touches += 1;
    if (!_setPieceDelivery) _origin = null; // the set piece has been worked away
    final forward = (point.dx - ball.dx) * (homePossession ? 1 : -1);
    final mistimed =
        !_setPieceDelivery &&
        forward > 0.12 &&
        receiver.mainPosition.isAttacker &&
        random.nextDouble() <
            0.065 +
                (_opponent.tactics.offsideTrap ? 0.05 : 0) +
                (_xi(_opponent).any(
                      (d) => d.defendingStyle == DefendingStyle.highLineMaster,
                    )
                    ? 0.015
                    : 0) +
                (_opponent.tactics.defensiveLine - 3) * 0.012 -
                (receiver.stats.attackingAwareness + _lvl - 75) / 900;
    if (!_setPieceDelivery &&
        (mistimed || _offsidePoint(point, homePossession))) {
      _att.offsides++;
      _def.freeKicks++;
      _line(receiver).offsides += 1;
      _emit(
        MatchEventType.offside,
        _talk.say('offside', p: receiver.shortName),
        homePossession,
        receiver,
      );
      final spot = point;
      homePossession = !homePossession;
      owner = _nearest(_points, spot, _club);
      _setStoppage(_SetPiece.none, 0.35);
      _lastPasser = null;
      return;
    }
    final coaching = homePossession ? homeCoaching : awayCoaching;
    // Skill decides almost everything: a 90 passer barely misses short balls
    // and still finds long ones; a 55 passer struggles with both. Long balls
    // lose more accuracy with distance unless the lofted pass is good.
    final distancePenalty = lofted ? 0.30 - skill / 420 : 0.24 - skill / 520;
    final pressedNow = _nearestDistance(_rivals, ball, _opponent).$2 < 0.06;
    final accuracy =
        (0.87 +
                (skill + _lvl - 72) / 200 -
                distance * max(0.02, distancePenalty) -
                (pressedNow ? 0.05 - (passer.stats.ballControl - 75) / 1500 : 0) +
                (coaching - 70) / 1500 +
                (homePossession ? 0.006 : 0) +
                (_is(passer, _creators) ? 0.02 : 0) +
                (_is(passer, {PlayingStyle.buildUp, PlayingStyle.orchestrator}) ? 0.025 : 0) +
                (_club.captainId != null &&
                        _club.startingLineupIds.contains(_club.captainId) &&
                        !dismissed.contains(_club.captainId)
                    ? 0.004
                    : 0) +
                (lofted && passer.aiStyles.contains(AiStyle.longBallExpert)
                    ? 0.05
                    : 0))
            .clamp(0.55, 0.98);
    final deep = (homePossession ? 1 - ball.dx : ball.dx) > 0.67;
    final accurate = random.nextDouble() < accuracy + (deep && !lofted ? 0.06 : 0);
    final end = accurate
        ? point
        : point +
              Offset(
                deep
                    ? random.nextDouble() * 0.12 * (homePossession ? 1 : -1)
                    : (random.nextDouble() - 0.5) * 0.16,
                (random.nextDouble() - 0.5) * 0.2,
              );
    _flight = _Flight(
      from: ball,
      to: end,
      home: homePossession,
      actor: passer,
      lofted: lofted,
      receiver: target,
      outcome: accurate ? 'pass' : 'loose',
      duration: max(0.18, distance / (lofted ? 1.0 : 1.3)),
    );
    phase = FieldPhase.pass;
    _hold = 0;
    _setPieceDelivery = false;
  }

  bool _startCross(Player crosser, {bool corner = false}) {
    final points = _points;
    final attackHome = homePossession;
    final targets = <int>[];
    for (var i = 1; i < 11; i++) {
      final p = points[i];
      final mate = _xi(_club)[i];
      if (i == owner || dismissed.contains(mate.id)) continue;
      final progress = attackHome ? p.dx : 1 - p.dx;
      if (progress > 0.8 && (p.dy - 0.5).abs() < 0.24) targets.add(i);
    }
    if (targets.isEmpty) return false;
    targets.sort(
      (a, b) => (_xi(_club)[b].stats.heading + _xi(_club)[b].stats.jumping)
          .compareTo(_xi(_club)[a].stats.heading + _xi(_club)[a].stats.jumping),
    );
    final target = targets[random.nextDouble() < 0.65 ? 0 : random.nextInt(targets.length)];
    final skill = corner
        ? (crosser.stats.setPieceTaking * 0.6 + crosser.stats.curl * 0.4)
        : (crosser.stats.loftedPass * 0.6 + crosser.stats.curl * 0.4);
    final accurate =
        random.nextDouble() < (0.66 + (skill + _lvl - 72) / 140).clamp(0.3, 0.92);
    final to = accurate
        ? points[target]
        : Offset(
            points[target].dx + (random.nextDouble() - 0.5) * 0.12,
            points[target].dy + (random.nextDouble() - 0.5) * 0.3,
          );
    _att.passes++;
    _att.crosses++;
    _line(crosser)
      ..passes += 1
      ..crosses += 1
      ..touches += 1;
    if (!corner && random.nextDouble() < 0.12) {
      _emit(
        MatchEventType.pass,
        _talk.say('cross', p: crosser.shortName),
        attackHome,
        crosser,
      );
    }
    _flight = _Flight(
      from: ball,
      to: to,
      home: attackHome,
      actor: crosser,
      kind: corner ? _Kind.corner : _Kind.cross,
      lofted: true,
      receiver: target,
      outcome: accurate ? 'cross' : 'loose',
      duration: max(0.3, (to - ball).distance / 0.95),
    );
    phase = FieldPhase.pass;
    _hold = 0;
    _setPieceDelivery = false;
    return true;
  }

  void _dribble(Player carrier, int defenderIndex) {
    final d = _xi(_opponent)[defenderIndex];
    final success =
        random.nextDouble() <
        (0.46 +
                (carrier.stats.dribbling +
                        carrier.stats.balance +
                        carrier.stats.acceleration -
                        d.stats.defensiveAwareness -
                        d.stats.tackling -
                        d.stats.speed) /
                    230 +
                (carrier.aiStyles.contains(AiStyle.trickster) ||
                        carrier.aiStyles.contains(AiStyle.mazingRun)
                    ? 0.06
                    : 0))
            .clamp(0.2, 0.84);
    _att.dribbles++;
    final line = _line(carrier)
      ..dribbles += 1
      ..touches += 1;
    if (success) {
      line
        ..dribblesWon += 1
        ..duelsWon += 1;
      _line(d)
        ..duelsLost += 1
        ..dribbledPast += 1;
      _beaten[d.id] = 0.85;
      _hold = _hold * 0.4;
      if (random.nextDouble() < 0.14) {
        _emit(
          MatchEventType.pass,
          _talk.say('dribble', p: carrier.shortName, a: d.shortName),
          homePossession,
          carrier,
        );
      }
    } else {
      line
        ..possessionLost += 1
        ..duelsLost += 1;
      _markError(carrier, homePossession, ball);
      _line(d)
        ..tackles += 1
        ..duelsWon += 1;
      _def.tackles++;
      _turnover(defenderIndex);
    }
  }

  double _segmentDistance(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length == 0) return (point - a).distance;
    final t = (((point - a).dx * ab.dx + (point - a).dy * ab.dy) / length)
        .clamp(0.0, 1.0);
    return (point - (a + ab * t)).distance;
  }

  double _xgFor(Offset from, bool attackHome) {
    final gx = attackHome ? 1.0 : 0.0;
    final dx = (gx - from.dx).abs() * 105, dy = (from.dy - 0.5) * 68;
    final dist = sqrt(dx * dx + dy * dy);
    var angle = atan((7.32 * dx) / max(0.01, dx * dx + dy * dy - 3.66 * 3.66));
    if (angle < 0) angle += pi;
    return 1 / (1 + exp(0.12 * dist - 1.2 * angle + 0.8));
  }

  void _startShot(
    Player shooter, {
    bool header = false,
    bool pressured = false,
    bool crowded = false,
    _Kind kind = _Kind.shot,
  }) {
    final isHome = homePossession;
    final defend = _opponent;
    final keeperIndex = dismissed.contains(_xi(defend)[0].id) ? -1 : 0;
    final keeper = keeperIndex < 0 ? null : _xi(defend)[keeperIndex];
    final effectiveKind = header ? _Kind.header : kind;
    final strike = _lvl + switch (effectiveKind) {
      _Kind.header =>
        shooter.stats.heading * 0.65 +
            shooter.stats.jumping * 0.2 +
            shooter.stats.physicalContact * 0.15,
      _Kind.freeKick =>
        shooter.stats.setPieceTaking * 0.5 +
            shooter.stats.curl * 0.3 +
            shooter.stats.kickingPower * 0.2,
      _Kind.penalty =>
        shooter.stats.setPieceTaking * 0.4 + shooter.stats.finishing * 0.6,
      _ => _openPlayStrike(shooter, _meters(ball, Offset(isHome ? 1.0 : 0.0, 0.5))),
    };
    final goalPoint = Offset(isHome ? 1.0 : 0.0, 0.5);
    final distance = _meters(ball, goalPoint);
    var xg = switch (effectiveKind) {
      _Kind.penalty => 0.76,
      _Kind.freeKick => (0.075 * (24 / max(16, distance))).clamp(0.03, 0.12),
      _ => _xgFor(ball, isHome) *
          (header ? 0.62 : 1) *
          (pressured ? 0.86 : 1) *
          (crowded ? 0.66 : 1),
    };
    if (effectiveKind != _Kind.penalty) {
      // More bodies forward create slightly better chances.
      xg *= _exposure(!isHome) *
          (_onCounter(isHome) ? 1 + _shape(!isHome) * 0.25 : 1) *
          (1 + max(0.0, _shape(isHome)) * 0.14);
    }
    // A focused defence (training, team talk) concedes slightly worse chances.
    if (effectiveKind != _Kind.penalty) xg *= isHome ? awayFocus : homeFocus;
    xg = xg.clamp(0.01, 0.96).toDouble();
    final big = xg >= 0.3;
    _att.shots++;
    _att.xg += xg;
    if (big) _att.bigChances++;
    final line = _line(shooter)
      ..shots += 1
      ..xg += xg
      ..touches += 1;
    if (_lastPasser != null && effectiveKind != _Kind.penalty) {
      final passer = _club.playerById(_lastPasser!);
      if (passer != null) {
        _line(passer)
          ..keyPasses += 1
          ..xa += xg;
        if (big) _line(passer).bigChancesCreated += 1;
      }
    }
    String? errorBy;
    final err = _error;
    if (err != null && err.home != isHome && time - err.time < 0.3) {
      final culprit = defend.playerById(err.id);
      if (culprit != null) {
        _line(culprit).errorsLeadingToShot += 1;
        errorBy = culprit.id;
      }
    }
    _error = null;
    _spike(isHome, xg * 110 + (big ? 18 : 0));
    // The keeper's attributes for this kind of shot decide how much of the
    // chance he takes away: a 90+ keeper turns big chances into saves.
    final gkFactor = keeper == null
        ? 2.4
        : (1 - (_keeperSkill(keeper, distance, effectiveKind) + _gkLvl - 75) / 46).clamp(0.38, 1.65) *
              (keeper.playingStyle == PlayingStyle.defensiveGoalkeeper && distance < 14 ? 0.95 : 1);
    // From range only real strikers of the ball hurt the keeper.
    final skill = (1.24 + (strike - 75) / (distance > 18 ? 30 : 48)).clamp(0.3, 1.9);
    final pGoal = effectiveKind == _Kind.penalty
        ? (0.77 +
                  (shooter.stats.setPieceTaking + shooter.stats.finishing - 160) /
                      420 -
                  ((keeper?.stats.gkReflexes ?? 40) +
                          (keeper?.stats.gkAwareness ?? 40) -
                          160) /
                      520)
              .clamp(0.62, 0.92)
        : (xg * skill * gkFactor * (isHome ? 1.08 : 0.94)).clamp(0.005, 0.97);
    var outcome = random.nextDouble() < pGoal ? 'goal' : 'miss';
    Player? blocker;
    final rivals = _rivals;
    if (effectiveKind == _Kind.shot) {
      for (var i = 0; i < 11; i++) {
        if (i == keeperIndex || dismissed.contains(_xi(defend)[i].id)) continue;
        if (_segmentDistance(rivals[i], ball, goalPoint) < 0.025 &&
            (rivals[i] - ball).distance > 0.03 &&
            random.nextDouble() <
                (outcome == 'goal' ? 0.18 : 0.34) *
                    (0.7 + _xi(defend)[i].stats.defensiveAwareness / 250) *
                    (1 + max(0.0, -_shape(!isHome)) * 0.22) *
                    (_onCounter(isHome) ? 0.5 : 1)) {
          outcome = 'block';
          blocker = _xi(defend)[i];
          break;
        }
      }
    } else if (effectiveKind == _Kind.freeKick &&
        random.nextDouble() < (outcome == 'goal' ? 0.1 : 0.3)) {
      outcome = 'block';
      blocker = _xi(defend)[_nearest(rivals, ball, defend, ignoreKeeper: true)];
    }
    if (outcome == 'miss') {
      final onTarget =
          (effectiveKind == _Kind.penalty ? 0.62 : 0.34) +
          (strike - 70) / 260 -
          distance * 0.004;
      if (random.nextDouble() < onTarget.clamp(0.15, 0.7) && keeper != null) {
        outcome = 'save';
      } else if (random.nextDouble() < 0.06) {
        outcome = 'woodwork';
      }
    }
    Offset end;
    switch (outcome) {
      case 'goal':
        end = Offset(isHome ? 1.0 : 0.0, 0.458 + random.nextDouble() * 0.084);
      case 'save':
        end = Offset(isHome ? 0.93 : 0.07, 0.46 + random.nextDouble() * 0.08);
      case 'block':
        end = blocker == null
            ? ball
            : _rivals[_xi(defend).indexOf(blocker)];
      case 'woodwork':
        end = Offset(isHome ? 1.0 : 0.0, random.nextBool() ? 0.447 : 0.553);
      default:
        end = Offset(
          isHome ? 1.0 : 0.0,
          random.nextBool()
              ? 0.33 + random.nextDouble() * 0.1
              : 0.57 + random.nextDouble() * 0.1,
        );
    }
    if (outcome == 'goal' || outcome == 'save') {
      line.shotsOnTarget += 1;
    }
    // Goal-frame placement (shooter's view) and the derived xGOT.
    double mx, my;
    switch (outcome) {
      case 'goal':
        final side = random.nextBool() ? 1 : -1;
        mx = 0.5 + side * (0.12 + 0.36 * sqrt(random.nextDouble()));
        my = random.nextDouble() < 0.55 ? 0.05 + random.nextDouble() * 0.3 : 0.35 + random.nextDouble() * 0.58;
      case 'save':
        mx = 0.5 + (random.nextDouble() - 0.5) * 0.75;
        my = 0.05 + random.nextDouble() * 0.7;
      case 'woodwork':
        final bar = random.nextDouble() < 0.35;
        mx = bar ? 0.1 + random.nextDouble() * 0.8 : (random.nextBool() ? 0.0 : 1.0);
        my = bar ? 1.0 : 0.15 + random.nextDouble() * 0.75;
      case 'block':
        mx = -9;
        my = 0;
      default:
        final high = random.nextDouble() < 0.4;
        mx = high
            ? 0.05 + random.nextDouble() * 0.9
            : (random.nextBool() ? -0.05 - random.nextDouble() * 0.45 : 1.05 + random.nextDouble() * 0.45);
        my = high ? 1.06 + random.nextDouble() * 0.5 : random.nextDouble() * 0.8;
    }
    if (outcome == 'goal' || outcome == 'woodwork' || outcome == 'miss') {
      // Keep the pitch drawing consistent with the frame point.
      final y = isHome ? 0.446 + mx * 0.108 : 0.554 - mx * 0.108;
      end = Offset(end.dx, outcome == 'miss' && my < 1 ? end.dy : y);
    }
    var xgot = 0.0;
    if (outcome == 'goal' || outcome == 'save') {
      final edge = max((mx - 0.5).abs() * 2, my).clamp(0.0, 1.0);
      xgot = effectiveKind == _Kind.penalty
          ? 0.6 + 0.35 * edge
          : (xg * (0.55 + 1.6 * edge * edge) + 0.02).clamp(0.02, 0.97);
    }
    final weak = (0.92 - shooter.weakFoot * 0.05).clamp(0.6, 0.9);
    final strong = shooter.preferredFoot == PreferredFoot.left ? 'left' : 'right';
    final body = effectiveKind == _Kind.header
        ? 'head'
        : random.nextDouble() < weak
        ? strong
        : (strong == 'left' ? 'right' : 'left');
    final assisted = effectiveKind != _Kind.penalty && _lastPasser != null;
    final situation = switch (effectiveKind) {
      _Kind.penalty => 'penalty',
      _Kind.freeKick => 'freeKick',
      _ when _origin != null && _originHome == isHome => _origin!,
      _ when assisted => 'assisted',
      _ => 'open',
    };
    final record = ShotRecord(
      ball,
      end,
      isHome,
      outcome == 'goal',
      xg,
      shooter.id,
      displayMinute,
      outcome,
      body,
      situation,
      assisted ? _lastPasser : null,
      assisted ? _lastPassFrom : null,
      mx,
      my,
      xgot,
    );
    _origin = null;
    _flight = _Flight(
      from: ball,
      to: end,
      home: isHome,
      actor: shooter,
      assist: effectiveKind == _Kind.penalty ? null : _lastPasser,
      kind: effectiveKind,
      outcome: outcome,
      blocker: blocker,
      duration: max(
        0.15,
        (end - ball).distance / (0.95 + shooter.stats.kickingPower / 180),
      ),
      xg: xg,
      record: record,
      errorBy: errorBy,
    );
    phase = FieldPhase.shot;
    _setPieceDelivery = false;
    if (outcome != 'goal' &&
        effectiveKind != _Kind.penalty &&
        random.nextDouble() < 0.45) {
      _emit(
        MatchEventType.shot,
        effectiveKind == _Kind.header
            ? _talk.say('headerShot', p: shooter.shortName)
            : effectiveKind == _Kind.freeKick
            ? _talk.say('freeKick', p: shooter.shortName)
            : _talk.say('shot', p: shooter.shortName),
        isHome,
        shooter,
      );
    }
  }

  void _advanceFlight(double dt) {
    final flight = _flight!;
    flight.elapsed += dt;
    final t = (flight.elapsed / flight.duration).clamp(0.0, 1.0);
    ball = Offset.lerp(flight.from, flight.to, t)!;
    ballHeight = flight.lofted ? sin(t * pi) : 0;
    if (!flight.shot && !(flight.lofted && t > 0.15 && t < 0.85)) {
      final defending = flight.home ? away : home;
      final rivals = flight.home ? awayPositions : homePositions;
      for (var i = 1; i < 11; i++) {
        final p = _xi(defending)[i];
        if (dismissed.contains(p.id) || flight.checked.contains(p.id)) continue;
        if ((rivals[i] - ball).distance < 0.027) {
          flight.checked.add(p.id);
          if (random.nextDouble() <
              (0.24 +
                      (p.defendingStyle == DefendingStyle.passDisruptor
                          ? 0.07
                          : 0) +
                      (p.stats.defensiveEngagement * 0.5 +
                              p.stats.defensiveAwareness * 0.5 -
                              flight.actor.stats.lowPass) /
                          130)
                  .clamp(0.08, 0.68) *
                  _ownHalfCover(!flight.home) *
                  (_onCounter(flight.home) ? 0.55 : 1) *
                  ((flight.home ? 1 - flight.from.dx : flight.from.dx) > 0.67 ? 0.6 : 1)) {
            homePossession = !flight.home;
            _maybeCounter(homePossession);
            owner = i;
            _flight = null;
            phase = FieldPhase.openPlay;
            _hold = 0;
            _lastPasser = null;
            _line(p)
              ..interceptions += 1
              ..touches += 1;
            _line(flight.actor).possessionLost += 1;
            _markError(flight.actor, flight.home, ball);
            (homePossession ? homeStats : awayStats).interceptions++;
            if (random.nextDouble() < 0.12) {
              _emit(
                MatchEventType.pass,
                _talk.say('interception', p: p.shortName),
                homePossession,
                p,
              );
            }
            return;
          }
        }
      }
    }
    if (t < 1) return;
    _flight = null;
    _hold = 0;
    ballHeight = 0;
    if (flight.shot) {
      _resolveShot(flight);
      return;
    }
    if (flight.kind == _Kind.cross || flight.kind == _Kind.corner) {
      _resolveCross(flight);
      return;
    }
    if (flight.outcome == 'pass') {
      homePossession = flight.home;
      owner = flight.receiver;
      final stats = flight.home ? homeStats : awayStats;
      stats.completedPasses++;
      _line(flight.actor).passesCompleted += 1;
      _line(_xi(_club)[owner]).touches += 1;
      _lastPasser = flight.actor.id;
      _lastPassFrom = flight.from;
      phase = FieldPhase.openPlay;
      return;
    }
    // Misplaced pass: out of play → throw-in, otherwise a loose ball.
    _line(flight.actor).possessionLost += 1;
    if (!_inBounds(flight.to)) {
      final spot = _bound(flight.to);
      if (spot.dy <= 0.05 || spot.dy >= 0.95) {
        _setPendingRestart(_SetPiece.throwIn, !flight.home, spot);
      } else {
        _setPendingRestart(_SetPiece.goalKick, !flight.home, spot);
      }
      return;
    }
    ball = _bound(flight.to);
    final homeNear = _nearestDistance(homePositions, ball, home);
    final awayNear = _nearestDistance(awayPositions, ball, away);
    homePossession = homeNear.$2 <= awayNear.$2 + (flight.home ? -0.01 : 0.01);
    owner = homePossession ? homeNear.$1 : awayNear.$1;
    if (homePossession == flight.home) {
      _lastPasser = null;
    } else {
      _lastPasser = null;
      _markError(flight.actor, flight.home, ball);
      _line(_xi(_club)[owner]).touches += 1;
    }
    phase = FieldPhase.openPlay;
  }

  void _resolveCross(_Flight f) {
    final attackClub = f.home ? home : away;
    final defendClub = f.home ? away : home;
    final attackPts = f.home ? homePositions : awayPositions;
    final defendPts = f.home ? awayPositions : homePositions;
    if (f.outcome != 'cross') {
      // Overhit or wayward delivery – usually a goal kick.
      homePossession = !f.home;
      if (random.nextDouble() < 0.6) {
        _setPendingRestart(_SetPiece.goalKick, !f.home, ball);
      } else {
        owner = _nearest(_points, ball, _club);
        phase = FieldPhase.openPlay;
      }
      _lastPasser = null;
      return;
    }
    final attacker = _xi(attackClub)[f.receiver];
    final di = _nearest(defendPts, attackPts[f.receiver], defendClub);
    final defender = _xi(defendClub)[di];
    final keeperClaims = di == 0 ||
        (!dismissed.contains(_xi(defendClub)[0].id) &&
            (defendPts[0] - ball).distance < 0.05 &&
            random.nextDouble() <
                (_xi(defendClub)[0].stats.gkCatching * 0.45 +
                        _xi(defendClub)[0].stats.gkReach * 0.35 +
                        _xi(defendClub)[0].stats.gkAwareness * 0.2 -
                        40) /
                    (_xi(defendClub)[0].defendingStyle == DefendingStyle.sweeperGk ? 95 : 120));
    final atk = attacker.stats.heading * 0.5 +
        attacker.stats.jumping * 0.35 +
        attacker.stats.physicalContact * 0.15 +
        random.nextDouble() * 30 +
        (f.kind == _Kind.corner ? 2 : 0) +
        (attacker.playingStyle == PlayingStyle.targetMan ? 8 : 0) +
        (attacker.playingStyle == PlayingStyle.extraFrontman &&
                f.kind == _Kind.corner
            ? 6
            : 0);
    final def = defender.stats.heading * 0.45 +
        defender.stats.jumping * 0.3 +
        defender.stats.defensiveAwareness * 0.25 +
        random.nextDouble() * 30 +
        4 +
        // A packed, organised box at set pieces favours the defenders.
        (f.kind == _Kind.corner ? 9 : 0);
    if (!keeperClaims && atk > def) {
      homePossession = f.home;
      owner = f.receiver;
      _line(attacker)
        ..duelsWon += 1
        ..touches += 1;
      _line(defender).duelsLost += 1;
      (f.home ? homeStats : awayStats).completedPasses++;
      _line(f.actor).passesCompleted += 1;
      _lastPasser = f.actor.id;
      _lastPassFrom = f.from;
      phase = FieldPhase.openPlay;
      _startShot(attacker, header: true, pressured: true, crowded: f.kind == _Kind.corner);
      return;
    }
    _lastPasser = null;
    homePossession = !f.home;
    if (keeperClaims) {
      owner = 0;
      phase = FieldPhase.openPlay;
      return;
    }
    _line(defender)
      ..clearances += 1
      ..duelsWon += 1;
    _line(attacker).duelsLost += 1;
    if (random.nextDouble() < 0.12) {
      _emit(
        MatchEventType.pass,
        _talk.say('clearance', p: defender.shortName),
        !f.home,
        defender,
      );
    }
    if (random.nextDouble() < 0.55) {
      _awardCorner(f.home);
      return;
    }
    // Cleared to the edge of the box: second ball.
    ball = _bound(Offset(f.home ? 0.68 + random.nextDouble() * 0.1 : 0.32 - random.nextDouble() * 0.1, 0.25 + random.nextDouble() * 0.5));
    final h = _nearestDistance(homePositions, ball, home);
    final a = _nearestDistance(awayPositions, ball, away);
    homePossession = h.$2 < a.$2;
    owner = homePossession ? h.$1 : a.$1;
    phase = FieldPhase.openPlay;
  }

  void _resolveShot(_Flight f) {
    final stats = f.home ? homeStats : awayStats;
    final defendClub = f.home ? away : home;
    shots.add(
      f.record ??
          ShotRecord(f.from, f.to, f.home, f.outcome == 'goal', f.xg, f.actor.id, displayMinute, f.outcome),
    );
    final line = _line(f.actor);
    if (f.outcome == 'goal') {
      if (recordReplays) {
        _pendingReplay = GoalReplay(displayMinute, f.actor.shortName, f.home, List.of(_frames));
        _framesAfterGoal = 12;
      }
      stats.onTarget++;
      stats.goals++;
      line.goals += 1;
      phase = FieldPhase.goal;
      _stoppage = 1.1;
      _spike(f.home, 40);
      if (f.assist != null) {
        final assister = (f.home ? home : away).playerById(f.assist!);
        if (assister != null) _line(assister).assists += 1;
      }
      if (f.errorBy != null) {
        final culprit = defendClub.playerById(f.errorBy!);
        if (culprit != null) {
          _line(culprit)
            ..errorsLeadingToShot -= 1
            ..errorsLeadingToGoal += 1;
        }
      }
      for (var i = 0; i < 11; i++) {
        final p = _xi(defendClub)[i];
        if (!dismissed.contains(p.id)) _line(p).goalsConceded += 1;
      }
      final assistName = f.assist == null
          ? null
          : (f.home ? home : away).playerById(f.assist!)?.shortName;
      final text = switch (f.kind) {
        _Kind.penalty => _talk.say('penaltyGoal', p: f.actor.shortName, s: _scoreLine()),
        _Kind.freeKick => _talk.say('freeKickGoal', p: f.actor.shortName, s: _scoreLine()),
        _Kind.header => _talk.say('header', p: f.actor.shortName, s: _scoreLine()),
        _ => assistName != null
            ? _talk.say('goalAssist', p: f.actor.shortName, a: assistName, s: _scoreLine())
            : _talk.say('goal', p: f.actor.shortName, s: _scoreLine()),
      };
      _emit(
        MatchEventType.goal,
        text,
        f.home,
        f.actor,
        assist: f.assist,
        secondary: assistName,
      );
      homePossession = !f.home;
      owner = 6;
      _lastPasser = null;
      return;
    }
    if (f.xg >= 0.3) line.bigChancesMissed += 1;
    final keeperIdx = 0;
    final keeper = _xi(defendClub)[keeperIdx];
    if (f.outcome == 'save') {
      stats.onTarget++;
      (f.home ? awayStats : homeStats).saves++;
      _line(keeper)
        ..saves += 1
        ..touches += 1;
      homePossession = !f.home;
      owner = keeperIdx;
      phase = FieldPhase.openPlay;
      _lastPasser = null;
      final parried =
          random.nextDouble() >
          (keeper.stats.gkCatching + keeper.stats.gkParrying) / 200;
      final spilled = parried &&
          f.kind != _Kind.penalty &&
          random.nextDouble() < ((90 - keeper.stats.gkParrying) / 120).clamp(0.03, 0.4);
      if (f.kind == _Kind.penalty) {
        _line(keeper).penaltiesSaved += 1;
        _emit(
          MatchEventType.save,
          _talk.say('penaltySaved', p: f.actor.shortName, a: keeper.shortName),
          !f.home,
          keeper,
        );
      } else {
        _emit(
          MatchEventType.save,
          parried
              ? _talk.say('saveCorner', p: keeper.shortName)
              : _talk.say('save', p: keeper.shortName),
          !f.home,
          keeper,
        );
      }
      if (spilled) {
        // A loose ball in front of goal: whoever is quickest to it.
        ball = Offset(f.home ? 0.9 : 0.1, 0.5 + (random.nextDouble() - 0.5) * 0.2);
        final h = _nearestDistance(homePositions, ball, home);
        final a = _nearestDistance(awayPositions, ball, away);
        homePossession = h.$2 < a.$2;
        owner = homePossession ? h.$1 : a.$1;
        _hold = 1.2;
        return;
      }
      if (parried) _awardCorner(f.home);
      return;
    }
    if (f.outcome == 'block') {
      stats.blocked++;
      if (f.blocker != null) {
        _line(f.blocker!).blocks += 1;
        if (random.nextDouble() < 0.4) {
          _emit(
            MatchEventType.shot,
            _talk.say('block', p: f.actor.shortName, a: f.blocker!.shortName),
            f.home,
            f.actor,
          );
        }
      }
      _lastPasser = null;
      if (random.nextDouble() < 0.55) {
        _awardCorner(f.home);
        return;
      }
      ball = _bound(ball);
      final h = _nearestDistance(homePositions, ball, home);
      final a = _nearestDistance(awayPositions, ball, away);
      homePossession = h.$2 < a.$2;
      owner = homePossession ? h.$1 : a.$1;
      phase = FieldPhase.openPlay;
      return;
    }
    // Miss / woodwork → goal kick.
    _lastPasser = null;
    final big = f.xg >= 0.3;
    final key = f.outcome == 'woodwork'
        ? 'woodwork'
        : f.kind == _Kind.penalty
        ? 'penaltyMissed'
        : big
        ? 'bigChanceMiss'
        : 'miss';
    _emit(
      f.outcome == 'woodwork'
          ? MatchEventType.woodwork
          : big
          ? MatchEventType.bigChance
          : MatchEventType.shot,
      _talk.say(key, p: f.actor.shortName),
      f.home,
      f.actor,
    );
    if (f.outcome == 'miss' &&
        f.kind != _Kind.penalty &&
        random.nextDouble() < 0.36) {
      _awardCorner(f.home); // deflected behind
      return;
    }
    _setPendingRestart(_SetPiece.goalKick, !f.home, ball);
  }

  void _awardCorner(bool attackingHome) {
    (attackingHome ? homeStats : awayStats).corners++;
    _spike(attackingHome, 9);
    final side = random.nextBool() ? 0.06 : 0.94;
    _setPendingRestart(
      _SetPiece.corner,
      attackingHome,
      Offset(attackingHome ? 0.975 : 0.025, side),
    );
    _emit(
      MatchEventType.corner,
      _talk.say('corner', t: (attackingHome ? home : away).shortName),
      attackingHome,
      null,
    );
  }

  // ---------------------------------------------------------- set pieces
  void _setStoppage(_SetPiece piece, double seconds) {
    _pending = piece;
    phase = FieldPhase.stoppage;
    _stoppage = seconds;
    _flight = null;
  }

  void _setPendingRestart(_SetPiece piece, bool forHome, Offset spot) {
    _pendingHome = forHome;
    _pendingSpot = spot;
    homePossession = forHome;
    _pendingTaker = _takerFor(forHome ? home : away, piece);
    if (piece == _SetPiece.throwIn) {
      _pendingTaker = _nearest(forHome ? homePositions : awayPositions, spot, forHome ? home : away, ignoreKeeper: true);
    }
    _setStoppage(
      piece,
      switch (piece) {
        _SetPiece.corner => 1.35,
        _SetPiece.penalty => 1.3,
        _SetPiece.freeKick => 0.95,
        _SetPiece.goalKick => 0.65,
        _ => 0.4,
      },
    );
  }

  /// Where the taker of the pending restart has to stand.
  Offset get _takerSpot => switch (_pending) {
    _SetPiece.penalty => Offset(_pendingHome ? 1 - 11 / 105 : 11 / 105, 0.5),
    _SetPiece.goalKick => Offset(_pendingHome ? 0.055 : 0.945, 0.5),
    _SetPiece.throwIn => Offset(_pendingSpot.dx, _pendingSpot.dy < 0.5 ? 0.046 : 0.954),
    _ => _pendingSpot,
  };

  /// True while the taker is still on his way to the ball.
  bool get _takerWalking {
    if (_pending == _SetPiece.none) return false;
    final points = _pendingHome ? homePositions : awayPositions;
    final taker = _pending == _SetPiece.goalKick ? 0 : _pendingTaker;
    return (points[taker] - _takerSpot).distance > 0.02;
  }

  void _resume() {
    if (phase == FieldPhase.goal) {
      restart(homePossession, snap: false);
      return;
    }
    final piece = _pending;
    _pending = _SetPiece.none;
    if (piece == _SetPiece.corner || piece == _SetPiece.freeKick || piece == _SetPiece.penalty) {
      _regroup = 0.7;
    }
    phase = FieldPhase.openPlay;
    _hold = 0;
    switch (piece) {
      case _SetPiece.none:
        _lastPasser = null;
      case _SetPiece.goalKick:
        homePossession = _pendingHome;
        owner = 0;
        if (dismissed.contains(_xi(_club)[0].id)) {
          owner = _nearest(_points, _pendingSpot, _club);
        }
        _points[owner] = Offset(homePossession ? 0.06 : 0.94, 0.5);
        ball = _points[owner];
        _lastPasser = null;
      case _SetPiece.throwIn:
        homePossession = _pendingHome;
        owner = _pendingTaker;
        _points[owner] = Offset(_pendingSpot.dx, _pendingSpot.dy < 0.5 ? 0.046 : 0.954);
        ball = _points[owner];
        _att.throwIns++;
        _lastPasser = null;
      case _SetPiece.corner:
        homePossession = _pendingHome;
        final taker = _pendingTaker;
        owner = taker;
        _points[owner] = _pendingSpot;
        ball = _pendingSpot;
        _origin = 'corner';
        _originHome = homePossession;
        if (!_startCross(_xi(_club)[owner], corner: true)) {
          _lastPasser = null;
        }
      case _SetPiece.freeKick:
        homePossession = _pendingHome;
        final goal = Offset(homePossession ? 1.0 : 0.0, 0.5);
        final dist = _meters(_pendingSpot, goal);
        final central = (_pendingSpot.dy - 0.5).abs() < 0.22;
        final taker = _pendingTaker;
        owner = taker;
        _points[owner] = _pendingSpot;
        ball = _pendingSpot;
        if (dist < 30 && central && random.nextDouble() < 0.5) {
          _startShot(_xi(_club)[owner], kind: _Kind.freeKick);
        } else if (dist < 40) {
          _setPieceDelivery = true;
          _origin = 'setPiece';
          _originHome = homePossession;
          if (!_startCross(_xi(_club)[owner], corner: true)) {
            _setPieceDelivery = false;
          }
        }
      case _SetPiece.penalty:
        homePossession = _pendingHome;
        final taker = _pendingTaker;
        owner = taker;
        final spot = Offset(homePossession ? 1 - 11 / 105 : 11 / 105, 0.5);
        _points[owner] = spot;
        ball = spot;
        _lastPasser = null;
        _startShot(_xi(_club)[owner], kind: _Kind.penalty);
    }
  }

  int _takerFor(Club club, _SetPiece piece) {
    final xi = _xi(club);
    final assigned = switch (piece) {
      _SetPiece.corner => club.cornerTakerId,
      _SetPiece.freeKick => club.freeKickTakerId,
      _SetPiece.penalty => club.penaltyTakerId,
      _ => null,
    };
    if (assigned != null) {
      final i = xi.indexWhere((p) => p.id == assigned);
      if (i > 0 && !dismissed.contains(assigned)) return i;
    }
    return switch (piece) {
      _SetPiece.corner => _bestTaker(club, (p) => p.stats.setPieceTaking + p.stats.curl),
      _SetPiece.freeKick => _bestTaker(club, (p) => p.stats.setPieceTaking * 2 + p.stats.curl),
      _SetPiece.penalty => _bestTaker(club, (p) => p.stats.setPieceTaking + p.stats.finishing),
      _ => 1,
    };
  }

  /// Realistic restart shapes: crowded box at corners, a wall at free kicks,
  /// everyone outside the area for a penalty.
  List<Offset?> _setPieceTargets(Club c, bool isHome) {
    final xi = _xi(c);
    final attacking = isHome == _pendingHome;
    final goalX = _pendingHome ? 1.0 : 0.0; // goal being attacked
    final dir = _pendingHome ? 1.0 : -1.0;
    double gx(double fromGoal) => goalX - dir * fromGoal;
    final targets = List<Offset?>.filled(11, null);
    final order = [for (var i = 1; i < 11; i++) if (!dismissed.contains(xi[i].id)) i];
    switch (_pending) {
      case _SetPiece.corner:
      case _SetPiece.freeKick:
        final corner = _pending == _SetPiece.corner;
        if (attacking) {
          targets[_pendingTaker] = _pendingSpot;
          final aerial = order.where((i) => i != _pendingTaker).toList()
            ..sort((a, b) => (xi[b].stats.heading + xi[b].stats.jumping)
                .compareTo(xi[a].stats.heading + xi[a].stats.jumping));
          const boxSpots = [
            Offset(0.06, 0.45), Offset(0.07, 0.55), Offset(0.10, 0.40),
            Offset(0.11, 0.60), Offset(0.12, 0.50),
          ];
          for (var k = 0; k < aerial.length; k++) {
            final i = aerial[k];
            if (k < 5) {
              targets[i] = Offset(gx(boxSpots[k].dx), boxSpots[k].dy);
            } else if (k < 7) {
              targets[i] = Offset(gx(0.2), k == 5 ? 0.4 : 0.62);
            } else {
              targets[i] = Offset(gx(corner ? 0.45 : 0.4), 0.3 + (k - 7) * 0.2);
            }
          }
          targets[0] = Offset(goalX == 1.0 ? 0.08 : 0.92, 0.5);
        } else {
          targets[0] = Offset(goalX == 1.0 ? 0.985 : 0.015, 0.5);
          final markers = order.toList()
            ..sort((a, b) => (xi[b].stats.defensiveAwareness + xi[b].stats.heading)
                .compareTo(xi[a].stats.defensiveAwareness + xi[a].stats.heading));
          if (!corner) {
            // Wall 9.15 m from the ball, on the line to goal.
            final goal = Offset(goalX, 0.5);
            final toGoal = goal - _pendingSpot;
            final unit = toGoal / max(0.001, toGoal.distance);
            final wallCentre = _pendingSpot + Offset(unit.dx * 9.15 / 105, unit.dy * 9.15 / 68);
            final wall = _meters(_pendingSpot, goal) < 32 ? 4 : 0;
            for (var k = 0; k < wall && k < markers.length; k++) {
              final i = markers.removeLast();
              targets[i] = wallCentre + Offset(0, (k - 1.5) * 0.022);
            }
          }
          final rivals = isHome ? awayPositions : homePositions;
          final rivalXi = _xi(isHome ? away : home);
          final threats = [
            for (var j = 1; j < 11; j++)
              if (!dismissed.contains(rivalXi[j].id) &&
                  (rivals[j].dx - goalX).abs() < 0.2)
                j,
          ];
          for (var k = 0; k < markers.length; k++) {
            final i = markers[k];
            if (k == 0) {
              targets[i] = Offset(gx(0.01), 0.44); // near post
            } else if (k <= threats.length && k < 8) {
              final m = rivals[threats[k - 1]];
              targets[i] = Offset(m.dx + dir * 0.012, m.dy);
            } else if (k < 9) {
              targets[i] = Offset(gx(0.18), 0.35 + (k % 3) * 0.15);
            } else {
              targets[i] = Offset(gx(0.55), 0.5); // counter outlet
            }
          }
        }
      case _SetPiece.penalty:
        final spot = Offset(_pendingHome ? 1 - 11 / 105 : 11 / 105, 0.5);
        if (attacking) targets[_pendingTaker] = spot;
        targets[0] = attacking
            ? Offset(goalX == 1.0 ? 0.3 : 0.7, 0.5)
            : Offset(goalX, 0.5);
        var k = 0;
        for (final i in order) {
          if (attacking && i == _pendingTaker) continue;
          targets[i] = Offset(gx(0.19 + (k % 3) * 0.02), 0.32 + (k % 6) * 0.07);
          k++;
        }
      case _SetPiece.goalKick:
        if (attacking) targets[0] = _takerSpot;
      case _SetPiece.throwIn:
        if (attacking) targets[_pendingTaker] = _takerSpot;
      default:
        return targets;
    }
    return targets;
  }

  void _walkToSetPiece(Club c, List<Offset> points, List<Offset> velocity, bool isHome, double dt) {
    final targets = _setPieceTargets(c, isHome);
    final xi = _xi(c);
    for (var i = 0; i < 11; i++) {
      final t = targets[i];
      if (t == null || dismissed.contains(xi[i].id)) continue;
      final delta = _bound(t) - points[i];
      // Restarts take real seconds: players have time to take position.
      final speed = 0.5 + xi[i].stats.speed / 500;
      final desired = delta.distance < 0.003
          ? Offset.zero
          : delta / delta.distance * min(speed, delta.distance * 3);
      velocity[i] = Offset.lerp(velocity[i], desired, min(1, dt * 4))!;
      points[i] = _bound(points[i] + velocity[i] * dt);
    }
    if (_pending == _SetPiece.corner || _pending == _SetPiece.freeKick || _pending == _SetPiece.penalty) {
      ball = _pending == _SetPiece.penalty
          ? Offset(_pendingHome ? 1 - 11 / 105 : 11 / 105, 0.5)
          : _pendingSpot;
    }
  }

  /// Kick-off spots: each side in its own half, the taker on the ball.
  Offset _kickoffSpot(Club c, bool isHome, int i) {
    final base = _bases(c, isHome)[i];
    if (homePossession == isHome && i == 6) return const Offset(0.5, 0.5);
    // Nobody may stand in the other half.
    return Offset(isHome ? min(base.dx, 0.48) : max(base.dx, 0.52), base.dy);
  }

  void _walkToKickoff(Club c, List<Offset> points, List<Offset> velocity, bool isHome, double dt) {
    final xi = _xi(c);
    for (var i = 0; i < 11; i++) {
      if (dismissed.contains(xi[i].id)) continue;
      final delta = _kickoffSpot(c, isHome, i) - points[i];
      final speed = 0.55 + xi[i].stats.speed / 500;
      final desired = delta.distance < 0.003 ? Offset.zero : delta / delta.distance * min(speed, delta.distance * 3);
      velocity[i] = Offset.lerp(velocity[i], desired, min(1, dt * 4))!;
      points[i] = _bound(points[i] + velocity[i] * dt);
    }
  }

  /// Someone is still far from his kick-off spot.
  bool get _awayFromKickoff {
    for (final (c, pts, isHome) in [(home, homePositions, true), (away, awayPositions, false)]) {
      final xi = _xi(c);
      for (var i = 0; i < 11; i++) {
        if (!dismissed.contains(xi[i].id) && (pts[i] - _kickoffSpot(c, isHome, i)).distance > 0.06) return true;
      }
    }
    return false;
  }

  int _bestTaker(Club club, int Function(Player) score) {
    var best = 1, bestScore = -1;
    for (var i = 1; i < 11; i++) {
      final p = _xi(club)[i];
      if (dismissed.contains(p.id)) continue;
      final s = score(p);
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  double progress0(Offset b) => homePossession ? b.dx : 1 - b.dx;

  void _foul(Player defender, Player victim) {
    final defendingHome = !homePossession;
    final stats = defendingHome ? homeStats : awayStats;
    stats.fouls++;
    // Laws of the game: every foul gives the other side a free kick (or a
    // penalty inside the box), so free kicks always mirror fouls + offsides.
    if (!(progress0(ball) > 0.843 && (ball.dy - 0.5).abs() < 0.296)) {
      (homePossession ? homeStats : awayStats).freeKicks++;
    }
    _line(defender).fouls += 1;
    _line(victim).fouled += 1;
    final spot = ball;
    final progress = homePossession ? spot.dx : 1 - spot.dx;
    final inBox = progress > 0.843 && (spot.dy - 0.5).abs() < 0.296;
    final dangerous = progress > 0.62;
    // VAR looks at some penalty calls; a few are overturned.
    if (inBox && random.nextDouble() < 0.35) {
      varReviews++;
      _emit(MatchEventType.varCheck, tr('VAR: ehtimoliy penalti tekshirilmoqda…'), homePossession, victim);
      if (random.nextDouble() < 0.2) {
        stats.fouls--;
        _line(defender).fouls -= 1;
        _line(victim).fouled -= 1;
        _emit(MatchEventType.info, tr('VAR qarori: penalti yo‘q, qoidabuzarlik bo‘lmagan.'), defendingHome, defender);
        homePossession = defendingHome;
        owner = 0;
        _setStoppage(_SetPiece.none, 0.5);
        return;
      }
      _emit(MatchEventType.info, tr('VAR qarori: penalti tasdiqlandi!'), homePossession, victim);
    }
    final yellowChance =
        0.11 +
        (defender.stats.aggression - 60) / 420 +
        (dangerous ? 0.08 : 0) +
        (inBox ? 0.1 : 0) +
        (derby ? 0.05 : 0) +
        (defender.personality == Personality.temperamental ? 0.04 : 0);
    var straightRed = random.nextDouble() < 0.0012 + (inBox ? 0.004 : 0);
    var downgraded = false;
    if (straightRed && random.nextDouble() < 0.5) {
      varReviews++;
      _emit(MatchEventType.varCheck, tr('VAR: qizil kartochka tekshirilmoqda…'), defendingHome, defender);
      downgraded = random.nextDouble() < 0.3;
      straightRed = !downgraded;
      _emit(
        MatchEventType.info,
        downgraded ? tr('VAR qarori: qizil kartochka sariqqa almashtirildi.') : tr('VAR qarori: qizil kartochka tasdiqlandi.'),
        defendingHome,
        defender,
      );
    }
    final booked = bookings.containsKey(defender.id);
    final yellow =
        !straightRed &&
        (downgraded || random.nextDouble() < yellowChance * (booked ? 0.2 : 1));
    final secondYellow = yellow && (bookings[defender.id] ?? 0) > 0;
    final red = straightRed || secondYellow;
    if (red) {
      _sendOff(defender, defendingHome);
      stats.reds++;
      _line(defender).red += 1;
      if (secondYellow) {
        stats.yellows++;
        _line(defender).yellow += 1;
      }
    } else if (yellow) {
      bookings[defender.id] = 1;
      stats.yellows++;
      _line(defender).yellow += 1;
    }
    if (red || yellow) {
      _emit(
        red ? MatchEventType.redCard : MatchEventType.yellowCard,
        secondYellow
            ? _talk.say('secondYellow', p: defender.shortName)
            : red
            ? _talk.say('red', p: defender.shortName)
            : _talk.say('yellow', p: defender.shortName),
        defendingHome,
        defender,
      );
    } else if (random.nextDouble() < 0.3 || inBox) {
      _emit(
        MatchEventType.foul,
        _talk.say('foul', p: defender.shortName),
        defendingHome,
        defender,
      );
    }
    // Contact injuries.
    if (random.nextDouble() < 0.013) _injure(victim, homePossession);
    _lastPasser = null;
    if (inBox) {
      _line(defender).penaltiesConceded += 1;
      _line(victim).penaltiesWon += 1;
      _emit(
        MatchEventType.penalty,
        _talk.say('penaltyAwarded', p: victim.shortName, a: defender.shortName),
        homePossession,
        victim,
      );
      _spike(homePossession, 25);
      _setPendingRestart(_SetPiece.penalty, homePossession, spot);
    } else if (dangerous) {
      _setPendingRestart(_SetPiece.freeKick, homePossession, spot);
    } else {
      _setStoppage(_SetPiece.none, 0.4);
    }
  }

  void _sendOff(Player p, bool isHome) {
    dismissed.add(p.id);
    _injuredOnPitch.remove(p.id);
    final club = isHome ? home : away;
    final xi = _xi(club);
    if (xi.isNotEmpty && identical(xi[0], p)) {
      // Keeper sent off: an outfielder makes way for the reserve keeper.
      final stats = isHome ? homeStats : awayStats;
      final keeper = club.bench
          .where(
            (b) =>
                b.mainPosition.isGoalkeeper &&
                !subbedOff.contains(b.id) &&
                b.isAvailable,
          )
          .firstOrNull;
      if (keeper == null || stats.subs >= 5) return;
      var outSlot = -1;
      for (var i = 10; i >= 1; i--) {
        if (!dismissed.contains(xi[i].id) && club.slotPosition(i).isAttacker) {
          outSlot = i;
          break;
        }
      }
      if (outSlot < 0) {
        for (var i = 10; i >= 1; i--) {
          if (!dismissed.contains(xi[i].id)) {
            outSlot = i;
            break;
          }
        }
      }
      if (outSlot < 0) return;
      final outfielder = xi[outSlot];
      final benchIndex = club.benchIds.indexOf(keeper.id);
      club.startingLineupIds[0] = keeper.id;
      club.startingLineupIds[outSlot] = p.id;
      club.benchIds[benchIndex] = outfielder.id;
      subbedOff.add(outfielder.id);
      stats.subs++;
      _refreshLineups();
      _line(outfielder).subOffMinute = displayMinute;
      _line(keeper).subOnMinute = displayMinute;
      _emit(
        MatchEventType.substitution,
        _talk.say('sub', p: keeper.shortName, a: outfielder.shortName, t: club.shortName),
        isHome,
        keeper,
        secondary: outfielder.shortName,
      );
    }
  }

  void _injure(Player p, bool isHome) {
    if (_injuredOnPitch.contains(p.id) || dismissed.contains(p.id)) return;
    _injuredOnPitch.add(p.id);
    _line(p).injured = true;
    final roll = random.nextDouble();
    injuries[p.id] = roll < 0.5
        ? 1
        : roll < 0.8
        ? 2
        : roll < 0.94
        ? 3
        : 5;
    p.currentStamina = max(20, p.currentStamina - 25);
    _emit(MatchEventType.injury, _talk.say('injury', p: p.shortName), isHome, p);
  }

  void _emit(
    MatchEventType type,
    String text,
    bool isHome,
    Player? p, {
    String? assist,
    String? secondary,
  }) {
    events.add(
      MatchEvent(
        minute: type == MatchEventType.kickoff && time < 0.01
            ? 0
            : (period == 1
                  ? min(45, time.floor() + 1)
                  : min(90, max(46, time.floor() + 1))),
        extraMinute: type == MatchEventType.kickoff ? 0 : displayExtra,
        type: type,
        description: text,
        clubId: (isHome ? home : away).id,
        isHomeTeam: isHome,
        playerName: p?.name,
        playerId: p?.id,
        assistPlayerId: assist,
        secondaryName: secondary,
        homeScore: homeStats.goals,
        awayScore: awayStats.goals,
      ),
    );
  }

  /// Public hook for UI-side events (e.g. tactical changes).
  void announce(MatchEventType type, String text, bool isHome) =>
      _emit(type, text, isHome, null);

  /// A side caught high up (attacking shape) is exposed for a moment.
  double _counterUntil = -1;
  int countersStarted = 0;
  int breakaways = 0;
  bool _counterHome = true;
  bool _onCounter(bool isHome) => time < _counterUntil && _counterHome == isHome;

  void _maybeCounter(bool winnerHome) {
    final shape = _shape(!winnerHome);
    if (shape > 0.4) {
      countersStarted++;
      _counterUntil = time + 0.45 + shape * 0.25;
      _counterHome = winnerHome;
    }
  }

  void _turnover(int index) {
    _origin = null;
    homePossession = !homePossession;
    _maybeCounter(homePossession);
    owner = index;
    _hold = 0;
    _lastPasser = null;
    _setPieceDelivery = false;
  }

  int _nearest(
    List<Offset> points,
    Offset target,
    Club c, {
    bool ignoreKeeper = false,
  }) => _nearestDistance(points, target, c, ignoreKeeper: ignoreKeeper).$1;

  (int, double) _nearestDistance(
    List<Offset> points,
    Offset target,
    Club c, {
    bool ignoreKeeper = false,
  }) {
    var result = ignoreKeeper ? 1 : 0;
    var best = double.infinity;
    final xi = _xi(c);
    for (var i = ignoreKeeper ? 1 : 0; i < 11; i++) {
      if (dismissed.contains(xi[i].id)) continue;
      final d = (points[i] - target).distance;
      if (d < best) {
        best = d;
        result = i;
      }
    }
    return (result, best);
  }

  // -------------------------------------------------------------- movement
  void _move(
    Club c,
    List<Offset> points,
    List<Offset> velocity,
    bool isHome,
    double dt,
  ) {
    final bases = _bases(c, isHome);
    final hasBall = homePossession == isHome;
    final direction = isHome ? 1.0 : -1.0;
    final xi = _xi(c);
    final opponent = isHome ? away : home;
    final rivals = isHome ? awayPositions : homePositions;
    final press = _nearest(points, ball, c, ignoreKeeper: true);
    var secondPress = -1;
    if (!hasBall && (c.tactics.pressing >= 4 || c.tactics.counterPress)) {
      var best = double.infinity;
      for (var i = 1; i < 11; i++) {
        if (i == press || dismissed.contains(xi[i].id)) continue;
        final d = (points[i] - ball).distance;
        if (d < best) {
          best = d;
          secondPress = i;
        }
      }
    }
    final line = [
      for (var j = 0; j < 11; j++)
        if (!dismissed.contains(_xi(opponent)[j].id)) rivals[j].dx,
    ]..sort();
    for (var i = 0; i < 11; i++) {
      final p = xi[i];
      if (dismissed.contains(p.id)) continue;
      final keeper = i == 0;
      final slotPos = c.slotPosition(i);
      final height = hasBall
          ? 0.08 + (c.tactics.attackingIntensity - 3) * 0.016
          : -0.055 +
                (c.tactics.defensiveLine - 3) * 0.026 +
                switch (c.tactics.defensiveApproach) {
                  DefensiveApproach.frontlinePressure => 0.03,
                  DefensiveApproach.allOutDefence => -0.05,
                  _ => 0.0,
                } +
                (c.tactics.offsideTrap && slotPos.isDefender ? 0.02 : 0) -
                (c.tactics.playstyle == TeamPlaystyle.longBallCounter ||
                        c.tactics.playstyle == TeamPlaystyle.longBall
                    ? 0.04
                    : 0);
      final shape = _shape(isHome);
      // Mentality moves the whole block: forward when attacking-minded,
      // deep and narrow when protecting the goal.
      final shift = keeper
          ? 0.0
          : hasBall
          ? shape * (slotPos.isDefender ? 0.03 : 0.045)
          : shape < 0
          ? shape * (slotPos.isDefender ? 0.0 : slotPos.isAttacker ? 0.09 : 0.05)
          : shape * 0.008;
      var target =
          bases[i] +
          Offset(
            (ball.dx - 0.5) * (keeper || slotPos.isDefender ? 0.2 : 0.3) + (height + shift) * direction,
            (ball.dy - 0.5) * (keeper ? 0.08 : 0.26),
          );
      if (!hasBall && shape < 0 && !keeper) {
        target = Offset(target.dx, 0.5 + (target.dy - 0.5) * (1 + shape * 0.08));
      }
      if (keeper) {
        final line = p.playingStyle == PlayingStyle.attackingGoalkeeper || p.defendingStyle == DefendingStyle.sweeperGk
            ? (hasBall ? 0.12 : 0.085)
            : p.playingStyle == PlayingStyle.defensiveGoalkeeper
            ? 0.05
            : 0.065;
        target = Offset(isHome ? line : 1 - line, 0.5 + (ball.dy - 0.5) * 0.25);
        if (_flight != null && _flight!.shot && _flight!.home != isHome) {
          target = _flight!.outcome == 'save'
              ? _flight!.to
              : Offset(isHome ? 0.045 : 0.955, _flight!.to.dy);
        }
      } else if (hasBall) {
        if (i == owner && _flight == null) {
          target = Offset(
            (points[i].dx + direction * 0.2).clamp(0.08, 0.92),
            0.5 + (points[i].dy - 0.5) * 0.62,
          );
        } else if (slotPos.isAttacker) {
          target += Offset(
            direction * 0.08,
            c.tactics.playstyle == TeamPlaystyle.outWide
                ? (bases[i].dy - 0.5) * 0.18
                : 0,
          );
        } else if ((slotPos == PlayerPosition.lb ||
                slotPos == PlayerPosition.rb) &&
            c.tactics.attackingIntensity >= 4) {
          target += Offset(direction * 0.07, (bases[i].dy - 0.5) * 0.12);
        }
      } else if (i == press ||
          i == secondPress ||
          (c.tactics.defensiveApproach == DefensiveApproach.frontlinePressure &&
              slotPos.isAttacker &&
              (points[i] - ball).distance < 0.2) ||
          (c.tactics.counterPress && (points[i] - ball).distance < 0.16)) {
        target = _duelCooldown.containsKey(p.id)
            ? ball - Offset(direction * 0.07, 0)
            : i == secondPress
            ? Offset.lerp(ball, Offset(isHome ? 0.0 : 1.0, 0.5), 0.12)!
            : ball + Offset(-direction * 0.012, 0);
      } else if (slotPos.isDefender || slotPos == PlayerPosition.dmf) {
        // Zonal marking: drift toward the nearest attacker in our zone.
        final mark = _nearest(rivals, bases[i], opponent, ignoreKeeper: true);
        final m = rivals[mark];
        if ((m - bases[i]).distance < 0.2) {
          target = Offset.lerp(target, m - Offset(direction * 0.02, 0), 0.35)!;
        }
      }
      if (_flight != null &&
          !_flight!.shot &&
          _flight!.home == isHome &&
          _flight!.receiver == i) {
        target = _flight!.to;
      }
      if (_flight != null &&
          (_flight!.kind == _Kind.cross || _flight!.kind == _Kind.corner) &&
          _flight!.home != isHome &&
          !keeper &&
          slotPos.isDefender) {
        target = Offset.lerp(target, _flight!.to, 0.5)!;
      }
      if (!keeper && i != owner) target = _styleTarget(p, i, target, bases, points, hasBall, isHome);
      // The back line drops towards its goal as the ball gets closer (to
      // about the six-yard line), with the holding midfielder in front.
      if (!hasBall && !keeper && (slotPos.isDefender || slotPos == PlayerPosition.dmf)) {
        final goalX = isHome ? 0.0 : 1.0;
        final ballFromGoal = (ball.dx - goalX).abs();
        final limit = slotPos.isDefender ? max(0.075, ballFromGoal * 0.6) : max(0.14, ballFromGoal * 0.8);
        if ((target.dx - goalX).abs() > limit) target = Offset(goalX + (isHome ? limit : -limit), target.dy);
      }
      // A compact block: midfielders and most forwards stay within reach of
      // the back line; the furthest forward waits on halfway for the counter.
      if (!hasBall && !keeper && !slotPos.isDefender && slotPos != PlayerPosition.dmf && i != press && i != secondPress) {
        final goalX = isHome ? 0.0 : 1.0;
        final ballFromGoal = (ball.dx - goalX).abs();
        final outlet = slotPos == PlayerPosition.cf || slotPos == PlayerPosition.ss;
        final limit = outlet ? max(0.45, ballFromGoal + 0.2) : max(0.24, ballFromGoal + 0.08);
        if ((target.dx - goalX).abs() > limit) target = Offset(goalX + (isHome ? limit : -limit), target.dy);
      }
      if (!keeper && i != owner) {
        final t = c.tactics;
        if (!hasBall) {
          final squeeze = 1.1 - t.compactness * 0.06;
          final spread = t.containment == ContainmentArea.wide ? 1.12 : 0.92;
          target = Offset(target.dx, 0.5 + (target.dy - 0.5) * squeeze * spread);
          if (i != press && i != secondPress) target = _coverTarget(p, i, slotPos, target, bases, isHome);
          switch (p.instruction) {
            case PlayerInstruction.counterTarget:
              target = Offset(bases[i].dx + direction * 0.1, bases[i].dy);
            case PlayerInstruction.deepLine:
              target -= Offset(direction * 0.04, 0);
            case PlayerInstruction.anchoring:
              target = Offset.lerp(target, bases[i], 0.5)!;
            case PlayerInstruction.pressing:
              // Closes down the ball when it is near.
              if ((ball - points[i]).distance < 0.2) target = Offset.lerp(target, ball, 0.55)!;
            case PlayerInstruction.trackBack:
              target = Offset.lerp(target, bases[i] - Offset(direction * 0.12, 0), 0.6)!;
            case PlayerInstruction.tightMarking:
              final m = rivals[_nearest(rivals, points[i], opponent, ignoreKeeper: true)];
              target = Offset.lerp(target, m - Offset(direction * 0.012, 0), 0.6)!;
            default:
              break;
          }
        } else {
          if (t.flexiblePositioning) {
            target += Offset(sin(time * 2 + i) * 0.025, cos(time * 1.7 + i) * 0.03);
          }
          if (t.playstyle == TeamPlaystyle.overload && !slotPos.isDefender) {
            target = Offset(target.dx, target.dy + (ball.dy - target.dy) * 0.25);
          }
          if (p.instruction == PlayerInstruction.anchoring) {
            target = Offset(bases[i].dx, (target.dy + bases[i].dy) / 2);
          }
        }
      }
      if (p.instruction == PlayerInstruction.stayBack && hasBall) {
        target = Offset(bases[i].dx, target.dy);
      }
      if (p.instruction == PlayerInstruction.makeRuns && hasBall && i != owner) {
        target += Offset(direction * 0.09, 0);
      }
      if (p.instruction == PlayerInstruction.holdWidth) {
        target = Offset(target.dx, bases[i].dy < 0.5 ? 0.1 : 0.9);
      }
      if (p.instruction == PlayerInstruction.playmaker && hasBall && i != owner) {
        target = Offset.lerp(target, ball, 0.35)!;
      }
      if (!keeper && i != owner && _flight?.receiver != i) target = _roam(p, target, hasBall, isHome, points[i]);
      if (hasBall &&
          i != owner &&
          !keeper &&
          p.stats.attackingAwareness >= 60 &&
          !_setPieceDelivery &&
          line.length >= 2) {
        final limit = isHome
            ? max(ball.dx, line[line.length - 2]) - 0.018
            : min(ball.dx, line[1]) + 0.018;
        target = Offset(
          isHome ? min(target.dx, limit) : max(target.dx, limit),
          target.dy,
        );
      }
      for (var j = 0; j < 11; j++) {
        if (i == j) continue;
        final difference = points[i] - points[j];
        if (difference.distance > 0.001 && difference.distance < 0.045) {
          target += difference / difference.distance * 0.035;
        }
      }
      final delta = _bound(target) - points[i];
      final injured = _injuredOnPitch.contains(p.id);
      final speed =
          (0.045 + p.stats.speed / 1100) *
          (0.75 + p.currentStamina / 400) *
          (hasBall && i == owner
              ? (p.aiStyles.contains(AiStyle.speedingBullet) ? 0.95 : 0.86)
              : 1) *
          (injured ? 0.7 : 1) *
          (_beaten.containsKey(p.id) ? 0.3 : 1) *
          (_regroup > 0 && _flight?.kind != _Kind.corner ? 1.3 : 1) *
          // (a brisk jog back to shape, not a sprint faster than anyone can run)
          // Caught upfield by a counter: getting back takes time.
          (time < _counterUntil && _counterHome != isHome && !hasBall ? 0.7 : 1);
      final desired = delta.distance < 0.003
          ? Offset.zero
          : delta / delta.distance * min(speed, delta.distance * 3);
      velocity[i] = Offset.lerp(
        velocity[i],
        desired,
        min(1, dt * (2 + p.stats.acceleration / 18)),
      )!;
      points[i] = _bound(points[i] + velocity[i] * dt);
    }
  }

  /// How far each role wanders from its spot (along, across the pitch).
  static const _roamRange = <PlayingStyle, (double, double)>{
    PlayingStyle.roamingFlank: (0.11, 0.13),
    PlayingStyle.prolificWinger: (0.08, 0.08),
    PlayingStyle.crossSpecialist: (0.09, 0.03),
    PlayingStyle.boxToBox: (0.13, 0.08),
    PlayingStyle.creativePlaymaker: (0.08, 0.11),
    PlayingStyle.holePlayer: (0.1, 0.07),
    PlayingStyle.classicNo10: (0.04, 0.05),
    PlayingStyle.orchestrator: (0.05, 0.09),
    PlayingStyle.anchorMan: (0.03, 0.05),
    PlayingStyle.destroyer: (0.07, 0.08),
    PlayingStyle.attackingFullBack: (0.13, 0.03),
    PlayingStyle.fullBackFinisher: (0.11, 0.07),
    PlayingStyle.defensiveFullBack: (0.04, 0.02),
    PlayingStyle.buildUp: (0.03, 0.03),
    PlayingStyle.extraFrontman: (0.07, 0.03),
    PlayingStyle.deepLyingForward: (0.1, 0.09),
    PlayingStyle.dummyRunner: (0.06, 0.13),
    PlayingStyle.goalPoacher: (0.05, 0.07),
    PlayingStyle.advancedStriker: (0.06, 0.08),
    PlayingStyle.foxInTheBox: (0.03, 0.04),
    PlayingStyle.targetMan: (0.04, 0.04),
  };

  /// Slow, player-specific wandering inside the role's range, so heatmaps
  /// show how a player really covers the pitch rather than one fixed spot.
  /// Destroyers also step out to attack the ball in their zone.
  Offset _roam(Player p, Offset target, bool hasBall, bool isHome, Offset at) {
    final (ax, ay) = _roamRange[p.playingStyle] ?? (0.05, 0.05);
    // Out of possession everyone keeps closer to the shape.
    final fit = (0.8 + p.currentStamina / 330) * (hasBall ? 1.15 : 0.5);
    final phase = (p.id.hashCode % 997) / 97.0;
    final wx = sin(time * 0.83 + phase) * 0.6 + sin(time * 0.31 + phase * 2.1) * 0.4;
    final wy = cos(time * 0.67 + phase * 1.7) * 0.6 + sin(time * 0.23 + phase * 0.6) * 0.4;
    var t = target + Offset(wx * ax * fit, wy * ay * fit);
    final ballDepth = isHome ? ball.dx : 1 - ball.dx;
    if (!hasBall && p.playingStyle == PlayingStyle.destroyer && ballDepth > 0.3 && (ball - at).distance < 0.22) {
      t = Offset.lerp(t, ball, 0.3)!;
    }
    // Attacking full-backs bomb on whenever the team has the ball.
    if (hasBall && p.playingStyle == PlayingStyle.attackingFullBack) {
      t += Offset((isHome ? 1 : -1) * (0.04 + max(0.0, wx) * 0.05), 0);
    }
    return t;
  }

  /// Moves a player's target according to their playing / defending style.
  /// Defensive duties by role: the holding midfielder screens the back
  /// line, midfielders drop between the lines and wide players track back –
  /// unless their style is to wait for the counter.
  Offset _coverTarget(Player p, int i, PlayerPosition slot, Offset target, List<Offset> bases, bool isHome) {
    final direction = isHome ? 1.0 : -1.0;
    final deep = max(0.0, -_shape(isHome)) * 0.03;
    final stayHigh = _is(p, {
          PlayingStyle.prolificWinger,
          PlayingStyle.goalPoacher,
          PlayingStyle.foxInTheBox,
          PlayingStyle.advancedStriker,
        }) ||
        p.defendingStyle == DefendingStyle.frontLinePoacher ||
        p.defendingStyle == DefendingStyle.attackOutlet ||
        p.instruction == PlayerInstruction.counterTarget;
    switch (slot) {
      case PlayerPosition.dmf:
        return Offset.lerp(
          target,
          Offset(bases[i].dx - direction * (0.07 + deep), 0.5 + (ball.dy - 0.5) * 0.35),
          0.5,
        )!;
      case PlayerPosition.cmf:
      case PlayerPosition.amf:
        final engine = _is(p, {
          PlayingStyle.boxToBox,
          PlayingStyle.destroyer,
          PlayingStyle.anchorMan,
          PlayingStyle.orchestrator,
        });
        return target - Offset(direction * ((engine ? 0.05 : 0.025) + deep), 0);
      case PlayerPosition.lmf:
      case PlayerPosition.rmf:
      case PlayerPosition.lwf:
      case PlayerPosition.rwf:
        if (stayHigh) return target;
        return Offset.lerp(
          target,
          Offset(target.dx - direction * (0.07 + deep), bases[i].dy < 0.5 ? 0.2 : 0.8),
          0.5,
        )!;
      case PlayerPosition.cf:
      case PlayerPosition.ss:
        // Forwards help when the ball is in their own half (stay just past
        // halfway for the counter), unless told to wait up front.
        final ownHalf = isHome ? ball.dx < 0.5 : ball.dx > 0.5;
        if (!ownHalf || stayHigh) return target;
        final line = 0.5 + direction * (0.04 - deep);
        return Offset(isHome ? min(target.dx, line) : max(target.dx, line), target.dy);
      default:
        return target;
    }
  }

  Offset _styleTarget(
    Player p,
    int i,
    Offset target,
    List<Offset> bases,
    List<Offset> points,
    bool hasBall,
    bool isHome,
  ) {
    final direction = isHome ? 1.0 : -1.0;
    if (hasBall) {
      final ballProgress = isHome ? ball.dx : 1 - ball.dx;
      final finalThird = ballProgress > 0.6;
      final penaltySpot = isHome ? 0.89 : 0.11;
      // The opponents' last outfield defender sets the offside line.
      final rivals = isHome ? awayPositions : homePositions;
      final oppXi = _xi(isHome ? away : home);
      var lastLine = isHome ? 0.5 : 0.5;
      for (var j = 1; j < 11; j++) {
        if (dismissed.contains(oppXi[j].id)) continue;
        lastLine = isHome ? max(lastLine, rivals[j].dx) : min(lastLine, rivals[j].dx);
      }
      final wideSide = bases[i].dy < 0.5 ? 0.07 : 0.93;
      switch (p.playingStyle) {
        // Lives on the last defender's shoulder, waiting for the ball in behind.
        case PlayingStyle.goalPoacher:
          if (ballProgress > 0.3) target = Offset(lastLine - direction * 0.012, 0.5 + (target.dy - 0.5) * 0.7);
        // Gets into the box to finish directly.
        case PlayingStyle.advancedStriker:
          if (finalThird) target = Offset.lerp(target, Offset(penaltySpot, 0.5 + (target.dy - 0.5) * 0.5), 0.45)!;
        // Waits around the penalty spot for crosses and rebounds.
        case PlayingStyle.foxInTheBox:
          if (finalThird) target = Offset(penaltySpot - direction * 0.015, 0.5 + (ball.dy - 0.5) * 0.25);
        // Holds the ball up centrally as the long-ball target.
        case PlayingStyle.targetMan:
          target = Offset(target.dx, 0.5 + (target.dy - 0.5) * 0.4);
        // False nine: drops into midfield to link play.
        case PlayingStyle.deepLyingForward:
          target = Offset.lerp(target - Offset(direction * 0.12, 0), ball, 0.2)!;
        // Decoy: pulls defenders away from the ball side.
        case PlayingStyle.dummyRunner:
          target = Offset(
            target.dx + direction * 0.03,
            (target.dy + (target.dy < ball.dy ? -0.13 : 0.13)).clamp(0.08, 0.92),
          );
        // Wide, then cuts inside to shoot in the final third.
        case PlayingStyle.prolificWinger:
          target = finalThird
              ? Offset(target.dx + direction * 0.04, 0.5 + (target.dy - 0.5) * 0.55)
              : Offset(target.dx, wideSide);
        // Drifts inside diagonally to combine.
        case PlayingStyle.roamingFlank:
          target = Offset.lerp(target, Offset(target.dx, 0.5 + (ball.dy - 0.5) * 0.4), 0.35)!;
        // Holds the width on the touchline to cross.
        case PlayingStyle.crossSpecialist:
          target = Offset(target.dx + (finalThird ? direction * 0.03 : 0), wideSide);
        // Finds pockets near the ball to play the killer pass.
        case PlayingStyle.creativePlaymaker:
          target = Offset.lerp(target + Offset(direction * 0.02, 0), ball, 0.18)!;
        // Stays in his zone; the ball comes to him.
        case PlayingStyle.classicNo10:
          target = Offset.lerp(target, bases[i] + Offset(direction * 0.06, 0), 0.5)!;
        // Late runs from midfield into the box.
        case PlayingStyle.holePlayer:
          if (finalThird) target = Offset(penaltySpot - direction * 0.07, 0.5 + (target.dy - 0.5) * 0.5);
        // Joins every attack.
        case PlayingStyle.boxToBox:
          target += Offset(direction * 0.06, 0);
        // Never leaves the space in front of the defence.
        case PlayingStyle.anchorMan:
          target = Offset(bases[i].dx + direction * 0.02, 0.5 + (target.dy - 0.5) * 0.6);
        // Deep playmaker / ball winner: stays behind the play.
        case PlayingStyle.orchestrator:
        case PlayingStyle.destroyer:
          target -= Offset(direction * 0.03, 0);
        // Calm centre-back who stays back to receive.
        case PlayingStyle.buildUp:
          target = Offset((target.dx + bases[i].dx) / 2, target.dy);
        // Centre-back who joins attacks in the final third.
        case PlayingStyle.extraFrontman:
          if (finalThird) target += Offset(direction * 0.13, 0);
        // Overlaps high and wide down the flank.
        case PlayingStyle.attackingFullBack:
          if (ballProgress > 0.4) target = Offset(target.dx + direction * 0.13, wideSide);
        // Stays in the back line.
        case PlayingStyle.defensiveFullBack:
          target = Offset(bases[i].dx + direction * 0.03, target.dy);
        // Inverts into midfield and towards the box.
        case PlayingStyle.fullBackFinisher:
          if (ballProgress > 0.45) target = Offset(target.dx + direction * 0.11, 0.5 + (bases[i].dy - 0.5) * 0.4);
        default:
          break;
      }
      // AI styles layered on top.
      if (ballProgress > 0.58 && p.aiStyles.contains(AiStyle.incisiveRun)) {
        target = Offset(target.dx, 0.5 + (target.dy - 0.5) * 0.65);
      }
      if (p.aiStyles.contains(AiStyle.speedingBullet) && ballProgress > 0.4) {
        target += Offset(direction * 0.03, 0);
      }
      if (p.aiStyles.contains(AiStyle.earlyCrosser)) target = Offset(target.dx, wideSide);
      return target;
    }
    switch (p.defendingStyle) {
      case DefendingStyle.frontLinePressure:
        if ((points[i] - ball).distance < 0.24) {
          return Offset.lerp(target, ball, 0.45)!;
        }
      case DefendingStyle.frontLinePoacher:
      case DefendingStyle.attackOutlet:
        return Offset(bases[i].dx + direction * 0.05, target.dy);
      case DefendingStyle.allActionDefender:
        return Offset.lerp(target, ball, 0.15)!;
      case DefendingStyle.highLineMaster:
        return target + Offset(direction * 0.02, 0);
      default:
        break;
    }
    return target;
  }

  /// Kick-off. [snap] places everyone instantly (start of a half); after a
  /// goal the players walk back instead.
  void restart(bool homeBall, {bool snap = true}) {
    homePossession = homeBall;
    owner = 6;
    _lastPasser = null;
    _flight = null;
    _pending = _SetPiece.none;
    ball = const Offset(0.5, 0.5);
    if (snap) {
      homePositions = List.of(_bases(home, true));
      awayPositions = List.of(_bases(away, false));
      _points[owner] = ball;
      _homeVelocity = List.filled(11, Offset.zero);
      _awayVelocity = List.filled(11, Offset.zero);
    }
    phase = FieldPhase.kickoff;
    _stoppage = 0.45;
  }

  // ------------------------------------------------------------- ratings
  int _goalDiff(bool isHome) =>
      isHome ? homeStats.goals - awayStats.goals : awayStats.goals - homeStats.goals;

  /// Live SofaScore-style rating; null until a player has played 10 minutes.
  double? ratingFor(String id) {
    final line = lines[id];
    if (line == null || line.minutes < 10) return null;
    final isHome = home.squad.any((p) => p.id == id);
    final club = isHome ? home : away;
    final p = club.playerById(id);
    if (p == null) return null;
    final idx = club.startingLineupIds.indexOf(id);
    final pos = idx >= 0 ? club.slotPosition(idx) : p.mainPosition;
    return line.rating(
      goalkeeper: pos.isGoalkeeper,
      defender: pos.isDefender,
      forward: pos.isAttacker,
      goalDifference: _goalDiff(isHome),
    );
  }

  Map<String, double> allRatings() => {
    for (final id in lines.keys)
      if (ratingFor(id) != null) id: ratingFor(id)!,
  };

  String? get manOfTheMatch {
    final ratings = allRatings();
    if (ratings.isEmpty) return null;
    return (ratings.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// Copies every statistic into the fixture record.
  void writeTo(Fixture f) {
    final h = homeStats, a = awayStats;
    f.homeScore = h.goals;
    f.awayScore = a.goals;
    f.homeShots = h.shots;
    f.awayShots = a.shots;
    f.homeShotsOnTarget = h.onTarget;
    f.awayShotsOnTarget = a.onTarget;
    f.homeXG = double.parse(h.xg.toStringAsFixed(2));
    f.awayXG = double.parse(a.xg.toStringAsFixed(2));
    f.homePossession = homePossessionPercent;
    f.awayPossession = 100 - f.homePossession;
    f.homeCorners = h.corners;
    f.awayCorners = a.corners;
    f.homeFouls = h.fouls;
    f.awayFouls = a.fouls;
    f.homePasses = h.passes;
    f.awayPasses = a.passes;
    f.homeCompletedPasses = h.completedPasses;
    f.awayCompletedPasses = a.completedPasses;
    f.homeSaves = h.saves;
    f.awaySaves = a.saves;
    f.homeOffsides = h.offsides;
    f.awayOffsides = a.offsides;
    f.homeTackles = h.tackles;
    f.awayTackles = a.tackles;
    f.homeBigChances = h.bigChances;
    f.awayBigChances = a.bigChances;
    f.homeYellows = h.yellows;
    f.awayYellows = a.yellows;
    f.homeReds = h.reds;
    f.awayReds = a.reds;
    f.events = List.of(events);
    f.ratings = allRatings();
    f.playerStats = Map.of(lines);
    f.momentum = List.of(momentum);
    f.shots = List.of(shots);
    f.heat = {for (final e in heat.entries) e.key: encodeHeat(e.value)}..removeWhere((k, v) => v.isEmpty);
    f.motmId = manOfTheMatch;
    f.homeLineup = List.of(homeStartIds);
    f.awayLineup = List.of(awayStartIds);
    f.homeBench = List.of(homeBenchIds);
    f.awayBench = List.of(awayBenchIds);
  }
}
