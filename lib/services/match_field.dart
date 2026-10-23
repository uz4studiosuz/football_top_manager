import 'dart:math';
import 'dart:ui';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';

enum FieldPhase { kickoff, openPlay, pass, shot, goal, stoppage }

class SideMatchStats {
  int goals = 0,
      shots = 0,
      onTarget = 0,
      corners = 0,
      fouls = 0,
      yellows = 0,
      reds = 0,
      passes = 0,
      completedPasses = 0;
  double xg = 0, possessionSeconds = 0;
}

class ShotRecord {
  final Offset origin, end;
  final bool home, goal;
  final double xg;
  final String playerId;
  final int minute;
  const ShotRecord(
    this.origin,
    this.end,
    this.home,
    this.goal,
    this.xg,
    this.playerId,
    this.minute,
  );
}

class _Flight {
  final Offset from, to;
  final bool home, shot, lofted;
  final int receiver;
  final String outcome;
  final Player actor;
  final String? assist;
  final double duration, xg;
  double elapsed = 0;
  final Set<String> checked = {};
  _Flight({
    required this.from,
    required this.to,
    required this.home,
    required this.actor,
    this.receiver = 0,
    this.shot = false,
    this.lofted = false,
    this.outcome = 'pass',
    this.assist,
    this.duration = 0.4,
    this.xg = 0,
  });
}

/// The pitch is authoritative: decisions create flights; completed flights
/// create goals, saves, turnovers and the same statistics used by the UI/AI.
class MatchField {
  final Club home, away;
  final Random random;
  int homeCoaching, awayCoaching;
  final SideMatchStats homeStats = SideMatchStats(),
      awayStats = SideMatchStats();
  final List<MatchEvent> events = [];
  final List<ShotRecord> shots = [];
  late List<Player> _homeXI, _awayXI;
  String _homeSignature = '', _awaySignature = '';
  final Map<Club, TeamTactics> _baseTactics = {};
  final Map<Club, List<Offset>> _basePositions = {};
  List<Player> _xi(Club c) => identical(c, home) ? _homeXI : _awayXI;
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

  final Set<String> dismissed = {};
  final Map<String, int> bookings = {};
  late List<Offset> homePositions, awayPositions;
  late List<Offset> _homeVelocity, _awayVelocity;
  Offset ball = const Offset(0.5, 0.5);
  bool homePossession = true;
  int owner = 6;
  double time = 0;
  FieldPhase phase = FieldPhase.kickoff;
  double homeAttack = 1, awayAttack = 1;
  double _hold = 0, _stoppage = 0.65, _tackleClock = 0;
  int _consumed = 0, _fitnessMinute = 0;
  String? _lastPasser;
  bool _headerOpportunity = false, _setPiece = false;
  _Flight? _flight;
  MatchField(
    this.home,
    this.away, {
    int seed = 73,
    this.homeCoaching = 70,
    this.awayCoaching = 70,
  }) : random = Random(seed) {
    _refreshLineups();
    homePositions = List.of(_bases(home, true));
    awayPositions = List.of(_bases(away, false));
    _homeVelocity = List.filled(11, Offset.zero);
    _awayVelocity = List.filled(11, Offset.zero);
    homePositions[owner] = ball;
  }
  SideMatchStats get _att => homePossession ? homeStats : awayStats;
  Club get _club => homePossession ? home : away;
  Club get _opponent => homePossession ? away : home;
  List<Offset> get _points => homePossession ? homePositions : awayPositions;
  List<Offset> get _rivals => homePossession ? awayPositions : homePositions;
  String get actionLabel => switch (phase) {
    FieldPhase.kickoff => 'Markazdan boshlash',
    FieldPhase.openPlay =>
      '${_club.shortName} · ${_xi(_club)[owner].shortName}',
    FieldPhase.pass => 'Uzatma',
    FieldPhase.shot => 'Zarba',
    FieldPhase.goal => 'GOL',
    FieldPhase.stoppage => 'O‘yin to‘xtadi',
  };
  int get homePossessionPercent {
    final total = homeStats.possessionSeconds + awayStats.possessionSeconds;
    return total == 0
        ? 50
        : (homeStats.possessionSeconds / total * 100).round();
  }

  List<MatchEvent> takeEvents() {
    final fresh = events.skip(_consumed).toList();
    _consumed = events.length;
    return fresh;
  }

  List<Offset> _bases(Club c, bool isHome) {
    if (identical(_baseTactics[c], c.tactics)) return _basePositions[c]!;
    _baseTactics[c] = c.tactics;
    final positions = List<Offset>.unmodifiable(
      c.tactics.formation.slots.map((slot) {
        final x = 0.075 + (1 - slot.y) * 0.79;
        return Offset(
          isHome ? x : 1 - x,
          0.5 + (slot.x - 0.5) * (0.6 + c.tactics.width * 0.065),
        );
      }),
    );
    _basePositions[c] = positions;
    return positions;
  }

  Offset _bound(Offset p) =>
      Offset(p.dx.clamp(0.025, 0.975), p.dy.clamp(0.045, 0.955));
  void update(double dt, Set<String> excluded) {
    _refreshLineups();
    dismissed.addAll(excluded);
    var left = min(dt, max(0.0, 90 - time));
    while (left > 0.000001) {
      final step = min(left, 1 / 60);
      _step(step);
      left -= step;
    }
  }

  void _step(double dt) {
    time = min(90, time + dt);
    if (time.floor() > _fitnessMinute) {
      _fitnessMinute = time.floor();
      for (final club in [home, away]) {
        for (final p in _xi(club)) {
          if (dismissed.contains(p.id)) continue;
          final pressure =
              club.tactics.counterPress ||
              club.tactics.playstyle == TeamPlaystyle.highPressing;
          final rate =
              (pressure ? 0.5 : 0.27) + (club.tactics.tempo - 3) * 0.025;
          if (random.nextDouble() < rate * (1.4 - p.stats.stamina / 170)) {
            p.currentStamina = max(20, p.currentStamina - 1);
          }
        }
      }
    }
    if (phase == FieldPhase.goal ||
        phase == FieldPhase.stoppage ||
        phase == FieldPhase.kickoff) {
      _stoppage -= dt;
      if (_stoppage <= 0) {
        if (phase == FieldPhase.goal) {
          restart(homePossession);
        } else {
          phase = FieldPhase.openPlay;
          _hold = 0;
          _lastPasser = null;
        }
      }
      return;
    }
    _att.possessionSeconds += dt;
    _move(home, homePositions, _homeVelocity, true, dt);
    _move(away, awayPositions, _awayVelocity, false, dt);
    if (_flight != null) {
      _advanceFlight(dt);
      return;
    }
    if (dismissed.contains(_xi(_club)[owner].id)) {
      owner = _nearest(_points, ball, _club);
    }
    final carrier = _xi(_club)[owner];
    ball = _bound(_points[owner] + Offset(homePossession ? 0.012 : -0.012, 0));
    _hold += dt;
    _tackleClock += dt;
    final pressure = _nearest(_rivals, ball, _opponent, ignoreKeeper: true);
    final defender = _xi(_opponent)[pressure];
    final distance = (_rivals[pressure] - ball).distance;
    if (distance < 0.044 && _tackleClock > 0.32) {
      _tackleClock = 0;
      if (random.nextDouble() < 0.05 + (defender.stats.aggression - 40) / 700) {
        _foul(defender);
        return;
      }
      final chance =
          (0.30 +
                  (defender.stats.tackling +
                          defender.stats.defensiveEngagement -
                          carrier.stats.tightPossession -
                          carrier.stats.balance) /
                      240)
              .clamp(0.08, 0.68);
      if (random.nextDouble() < chance) {
        _turnover(pressure);
        _emit(
          MatchEventType.pass,
          '${defender.shortName} to‘pni olib qo‘ydi.',
          homePossession,
          defender,
        );
        return;
      }
    }
    final progress = homePossession ? ball.dx : 1 - ball.dx;
    final goalDistance = (ball - Offset(homePossession ? 1 : 0, 0.5)).distance;
    final mentality = homePossession ? homeAttack : awayAttack;
    final decisionInterval = (1.0 - _club.tactics.tempo * 0.11).clamp(
      0.27,
      0.9,
    );
    if (_hold < decisionInterval) return;
    final central = (ball.dy - 0.5).abs() < 0.27;
    if (owner != 0 &&
        progress > 0.66 &&
        central &&
        goalDistance < 0.39 &&
        (_hold > 1.25 ||
            random.nextDouble() <
                (0.24 + carrier.stats.attackingAwareness / 400) * mentality)) {
      _startShot(carrier, header: _headerOpportunity);
      return;
    }
    final next = _choosePass();
    if (next != null &&
        (distance < 0.14 ||
            _hold > 1.1 ||
            _club.tactics.playstyle == TeamPlaystyle.possession ||
            _club.tactics.playstyle == TeamPlaystyle.longBall ||
            _club.tactics.playstyle == TeamPlaystyle.longBallCounter)) {
      _startPass(next, carrier);
      return;
    }
    // A carrier with open grass drives forward instead of passing blindly.
    if (_hold > 2.1 && next != null) {
      _startPass(next, carrier);
    }
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
    for (var i = 0; i < 11; i++) {
      if (i == owner || dismissed.contains(_xi(club)[i].id)) continue;
      if (!_setPiece && _offsidePoint(points[i], homePossession)) continue;
      final distance = (points[i] - ball).distance;
      if (distance < 0.05 || distance > 0.68) continue;
      final space =
          (_rivals[_nearest(_rivals, points[i], _opponent)] - points[i])
              .distance;
      final progress = (points[i].dx - ball.dx) * direction;
      final wide = (points[i].dy - 0.5).abs();
      var score = progress * 0.95 + min(space, 0.25) * 1.8 - distance * 0.22;
      if (club.tactics.playstyle == TeamPlaystyle.possession) {
        score += 0.2 - distance * 0.55;
      }
      if (club.tactics.playstyle == TeamPlaystyle.outWide) {
        score += wide * 0.65;
        if ((ball.dy - 0.5).abs() > 0.26 &&
            _xi(club)[i].mainPosition.isAttacker) {
          score += (0.4 - wide) * 1.4;
        }
      }
      if (club.tactics.playstyle == TeamPlaystyle.longBall ||
          club.tactics.playstyle == TeamPlaystyle.longBallCounter) {
        score += progress * 0.65 + _xi(club)[i].stats.physicalContact / 1000;
      }
      if (i == 0) score -= 0.2;
      if (owner == 0 && !club.tactics.playOutFromBack) score += progress * 0.9;
      score += random.nextDouble() * 0.12;
      candidates.add((index: i, score: score));
    }
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates[random.nextDouble() < 0.8
            ? 0
            : min(1, candidates.length - 1)]
        .index;
  }

  void _startPass(int target, Player passer) {
    final point = _points[target];
    final distance = (point - ball).distance;
    final lofted =
        distance > 0.32 || _club.tactics.playstyle == TeamPlaystyle.longBall;
    final skill = _setPiece
        ? (passer.stats.setPieceTaking + passer.stats.loftedPass) / 2
        : lofted
        ? passer.stats.loftedPass
        : passer.stats.lowPass;
    final defenders = [
      for (var i = 0; i < 11; i++)
        if (!dismissed.contains(_xi(_opponent)[i].id)) _rivals[i].dx,
    ]..sort();
    if (!_setPiece && defenders.length >= 2) {
      final beyond = homePossession
          ? point.dx > defenders[defenders.length - 2] + 0.01 &&
                point.dx > ball.dx + 0.01 &&
                point.dx > 0.5
          : point.dx < defenders[1] - 0.01 &&
                point.dx < ball.dx - 0.01 &&
                point.dx < 0.5;
      if (beyond) {
        _att.passes++;
        _emit(
          MatchEventType.pass,
          'Ofsayd: ${_xi(_club)[target].shortName}.',
          homePossession,
          _xi(_club)[target],
        );
        homePossession = !homePossession;
        owner = _nearest(_points, point, _club);
        phase = FieldPhase.stoppage;
        _stoppage = 0.35;
        _lastPasser = null;
        return;
      }
    }
    final accuracy =
        (0.75 +
                skill / 500 -
                distance * 0.18 +
                ((homePossession ? homeCoaching : awayCoaching) - 70) / 1500)
            .clamp(0.6, 0.98);
    _att.passes++;
    final accurate = random.nextDouble() < accuracy;
    final end = accurate
        ? point
        : _bound(
            point +
                Offset(
                  (random.nextDouble() - 0.5) * 0.14,
                  (random.nextDouble() - 0.5) * 0.16,
                ),
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
    _headerOpportunity = false;
    _setPiece = false;
  }

  double _segmentDistance(Offset point, Offset a, Offset b) {
    final ab = b - a;
    final length = ab.dx * ab.dx + ab.dy * ab.dy;
    if (length == 0) return (point - a).distance;
    final t = (((point - a).dx * ab.dx + (point - a).dy * ab.dy) / length)
        .clamp(0.0, 1.0);
    return (point - (a + ab * t)).distance;
  }

  void _startShot(Player shooter, {bool header = false}) {
    final strike = header
        ? (shooter.stats.heading * 0.65 +
              shooter.stats.jumping * 0.2 +
              shooter.stats.physicalContact * 0.15)
        : _setPiece
        ? (shooter.stats.setPieceTaking * 0.5 +
              shooter.stats.curl * 0.25 +
              shooter.stats.kickingPower * 0.25)
        : shooter.stats.finishing.toDouble();
    final isHome = homePossession;
    final defend = _opponent;
    final keeperIndex = dismissed.contains(_xi(defend)[0].id) ? -1 : 0;
    final keeper = keeperIndex < 0 ? null : _xi(defend)[keeperIndex];
    final goal = Offset(isHome ? 1.0 : 0.0, 0.5);
    final distance = (ball - goal).distance;
    final angle = (ball.dy - 0.5).abs();
    final xg =
        (0.07 +
                max(0, 0.43 - distance) * 0.9 -
                angle * 0.2 +
                (strike - 70) / 600)
            .clamp(0.025, 0.55)
            .toDouble();
    _att.shots++;
    _att.xg += xg;
    var outcome = 'miss';
    Offset end;
    final onTarget =
        random.nextDouble() <
        (0.65 + (strike - 70) / 160 - distance * 0.3).clamp(0.25, 0.94);
    if (onTarget) {
      final saveChance = keeper == null
          ? 0.0
          : (0.59 +
                    (keeper.stats.gkReflexes +
                            keeper.stats.gkAwareness +
                            keeper.stats.gkReach -
                            3 * strike) /
                        450 +
                    distance * 0.25)
                .clamp(0.16, 0.9);
      outcome = random.nextDouble() < saveChance ? 'save' : 'goal';
      end = Offset(isHome ? 1.0 : 0.0, 0.458 + random.nextDouble() * 0.084);
      if (outcome == 'save') end = Offset(isHome ? 0.925 : 0.075, end.dy);
    } else {
      end = Offset(
        isHome ? 1.0 : 0.0,
        random.nextBool()
            ? 0.32 + random.nextDouble() * 0.1
            : 0.58 + random.nextDouble() * 0.1,
      );
    }
    final rivals = _rivals;
    for (var i = 0; i < 11; i++) {
      if (i == keeperIndex || dismissed.contains(_xi(defend)[i].id)) {
        continue;
      }
      if (_segmentDistance(rivals[i], ball, end) < 0.025 &&
          (rivals[i] - ball).distance > 0.035 &&
          random.nextDouble() < 0.35) {
        outcome = 'block';
        end = rivals[i];
        break;
      }
    }
    _flight = _Flight(
      from: ball,
      to: end,
      home: isHome,
      actor: shooter,
      assist: _lastPasser,
      shot: true,
      outcome: outcome,
      duration: max(
        0.17,
        (end - ball).distance / (0.95 + shooter.stats.kickingPower / 180),
      ),
      xg: xg,
    );
    phase = FieldPhase.shot;
    _headerOpportunity = false;
    _setPiece = false;
    _emit(
      MatchEventType.shot,
      '${shooter.shortName} ${header ? 'bosh bilan zarba berdi' : 'darvozani nishonga oldi'}.',
      isHome,
      shooter,
    );
  }

  void _advanceFlight(double dt) {
    final flight = _flight!;
    flight.elapsed += dt;
    final t = (flight.elapsed / flight.duration).clamp(0.0, 1.0);
    ball = Offset.lerp(flight.from, flight.to, t)!;
    if (!flight.shot) {
      final defending = flight.home ? away : home;
      final rivals = flight.home ? awayPositions : homePositions;
      for (var i = 0; i < 11; i++) {
        final p = _xi(defending)[i];
        if (dismissed.contains(p.id) ||
            flight.checked.contains(p.id) ||
            i == 0) {
          continue;
        }
        if ((rivals[i] - ball).distance < 0.027) {
          flight.checked.add(p.id);
          if (random.nextDouble() <
              (0.25 +
                      (p.stats.defensiveEngagement -
                              flight.actor.stats.lowPass) /
                          160)
                  .clamp(0.08, 0.7)) {
            homePossession = !flight.home;
            owner = i;
            _flight = null;
            phase = FieldPhase.openPlay;
            _hold = 0;
            _lastPasser = null;
            _emit(
              MatchEventType.pass,
              '${p.shortName} pasni kesib oldi.',
              homePossession,
              p,
            );
            return;
          }
        }
      }
    }
    if (t < 1) return;
    _flight = null;
    _hold = 0;
    if (flight.shot) {
      _resolveShot(flight);
      return;
    }
    if (flight.outcome == 'pass') {
      homePossession = flight.home;
      owner = flight.receiver;
      _headerOpportunity = flight.lofted;
      _att.completedPasses++;
      _lastPasser = flight.actor.id;
      phase = FieldPhase.openPlay;
    } else {
      homePossession = !flight.home;
      owner = _nearest(_points, ball, _club);
      _lastPasser = null;
      phase = FieldPhase.openPlay;
      final p = _xi(_club)[owner];
      _emit(
        MatchEventType.pass,
        '${p.shortName} noaniq uzatmani egalladi.',
        homePossession,
        p,
      );
    }
  }

  void _resolveShot(_Flight f) {
    final stats = f.home ? homeStats : awayStats;
    shots.add(
      ShotRecord(
        f.from,
        f.to,
        f.home,
        f.outcome == 'goal',
        f.xg,
        f.actor.id,
        time.floor().clamp(0, 90),
      ),
    );
    if (f.outcome == 'goal') {
      stats.onTarget++;
      stats.goals++;
      phase = FieldPhase.goal;
      _stoppage = 1.1;
      _emit(
        MatchEventType.goal,
        'GOL! ${f.actor.shortName} to‘pni darvoza chizig‘idan o‘tkazdi.',
        f.home,
        f.actor,
        assist: f.assist,
      );
      homePossession = !f.home;
      owner = 6;
      _lastPasser = null;
    } else if (f.outcome == 'save') {
      stats.onTarget++;
      homePossession = !f.home;
      owner = 0;
      phase = FieldPhase.openPlay;
      _lastPasser = null;
      final keeper = _xi(_club).firstWhere(
        (p) => p.mainPosition.isGoalkeeper,
        orElse: () => _xi(_club).first,
      );
      owner = _xi(_club).indexOf(keeper);
      _emit(
        MatchEventType.save,
        '${keeper.shortName} zarbani qaytardi.',
        homePossession,
        keeper,
      );
      if (random.nextDouble() >
          (keeper.stats.gkCatching + keeper.stats.gkParrying) / 220) {
        homePossession = f.home;
        stats.corners++;
        owner = _nearest(
          _points,
          Offset(f.home ? 0.88 : 0.12, 0.09),
          _club,
          ignoreKeeper: true,
        );
        _points[owner] = Offset(f.home ? 0.95 : 0.05, 0.06);
        ball = _points[owner];
        phase = FieldPhase.stoppage;
        _stoppage = 0.45;
        _setPiece = true;
        _emit(
          MatchEventType.pass,
          'Burchak to‘pi: ${_club.shortName}.',
          f.home,
          null,
        );
      }
    } else if (f.outcome == 'block') {
      homePossession = !f.home;
      owner = _nearest(_points, ball, _club);
      phase = FieldPhase.openPlay;
      _lastPasser = null;
      _emit(
        MatchEventType.shot,
        'Zarba himoyachi tomonidan to‘sildi.',
        f.home,
        f.actor,
      );
    } else {
      homePossession = !f.home;
      owner = 0;
      phase = FieldPhase.stoppage;
      _stoppage = 0.55;
      _lastPasser = null;
      _emit(
        MatchEventType.shot,
        '${f.actor.shortName} zarbasi darvoza yonidan o‘tdi.',
        f.home,
        f.actor,
      );
    }
  }

  void _foul(Player defender) {
    final defendingHome = !homePossession;
    final stats = defendingHome ? homeStats : awayStats;
    stats.fouls++;
    final yellow = random.nextDouble() < 0.17;
    final red = yellow && (bookings[defender.id] ?? 0) > 0;
    if (red) {
      dismissed.add(defender.id);
      stats.reds++;
    } else if (yellow) {
      bookings[defender.id] = 1;
      stats.yellows++;
    }
    _emit(
      red
          ? MatchEventType.redCard
          : yellow
          ? MatchEventType.yellowCard
          : MatchEventType.foul,
      '${defender.shortName}: ${red
          ? 'ikkinchi ogohlantirish, qizil kartochka'
          : yellow
          ? 'sariq kartochka'
          : 'qoidabuzarlik'}.',
      defendingHome,
      defender,
    );
    phase = FieldPhase.stoppage;
    _stoppage = 0.4;
    _lastPasser = null;
    _setPiece = true;
  }

  void _emit(
    MatchEventType type,
    String text,
    bool isHome,
    Player? p, {
    String? assist,
  }) {
    events.add(
      MatchEvent(
        minute: time.floor().clamp(0, 90),
        type: type,
        description: text,
        clubId: (isHome ? home : away).id,
        isHomeTeam: isHome,
        playerName: p?.name,
        assistPlayerId: assist,
      ),
    );
  }

  void _turnover(int index) {
    homePossession = !homePossession;
    owner = index;
    _hold = 0;
    _lastPasser = null;
    _headerOpportunity = false;
    _setPiece = false;
  }

  int _nearest(
    List<Offset> points,
    Offset target,
    Club c, {
    bool ignoreKeeper = false,
  }) {
    var result = ignoreKeeper ? 1 : 0;
    var best = double.infinity;
    for (var i = ignoreKeeper ? 1 : 0; i < 11; i++) {
      if (dismissed.contains(_xi(c)[i].id)) continue;
      final d = (points[i] - target).distance;
      if (d < best) {
        best = d;
        result = i;
      }
    }
    return result;
  }

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
    final press = _nearest(points, ball, c, ignoreKeeper: true);
    for (var i = 0; i < 11; i++) {
      final p = _xi(c)[i];
      if (dismissed.contains(p.id)) continue;
      final keeper = i == 0;
      final height = hasBall
          ? 0.08 + (c.tactics.attackingIntensity - 3) * 0.015
          : -0.055 +
                (c.tactics.defensiveLine - 3) * 0.025 -
                (c.tactics.playstyle == TeamPlaystyle.longBallCounter
                    ? 0.04
                    : 0);
      var target =
          bases[i] +
          Offset(
            (ball.dx - 0.5) * 0.20 + height * direction,
            (ball.dy - 0.5) * (keeper ? 0.08 : 0.24),
          );
      if (keeper) {
        target = Offset(isHome ? 0.065 : 0.935, 0.5 + (ball.dy - 0.5) * 0.25);
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
        } else if (c.tactics.formation.slots[i].defaultPosition.isAttacker) {
          target += Offset(
            direction * 0.08,
            (c.tactics.playstyle == TeamPlaystyle.outWide
                ? (bases[i].dy - 0.5) * 0.18
                : 0),
          );
        }
      } else if (i == press ||
          (c.tactics.counterPress && (points[i] - ball).distance < 0.16)) {
        target = ball + Offset(-direction * 0.012, 0);
      }
      if (_flight != null &&
          !_flight!.shot &&
          _flight!.home == isHome &&
          _flight!.receiver == i) {
        target = _flight!.to;
      }
      if (p.instruction == PlayerInstruction.stayBack && hasBall) {
        target = Offset(bases[i].dx, target.dy);
      }
      if (p.instruction == PlayerInstruction.makeRuns &&
          hasBall &&
          i != owner) {
        target += Offset(direction * 0.09, 0);
      }
      if (p.instruction == PlayerInstruction.holdWidth) {
        target = Offset(target.dx, bases[i].dy < 0.5 ? 0.10 : 0.90);
      }
      if (p.instruction == PlayerInstruction.playmaker &&
          hasBall &&
          i != owner) {
        target = Offset.lerp(target, ball, 0.35)!;
      }
      if (hasBall &&
          i != owner &&
          !keeper &&
          p.stats.attackingAwareness >= 60 &&
          !_setPiece) {
        final rivals = isHome ? awayPositions : homePositions;
        final opponent = isHome ? away : home;
        final line = [
          for (var j = 0; j < 11; j++)
            if (!dismissed.contains(_xi(opponent)[j].id)) rivals[j].dx,
        ]..sort();
        if (line.length >= 2) {
          final limit = isHome
              ? max(ball.dx, line[line.length - 2]) - 0.018
              : min(ball.dx, line[1]) + 0.018;
          target = Offset(
            isHome ? min(target.dx, limit) : max(target.dx, limit),
            target.dy,
          );
        }
      }
      // Keep passing lanes and teammate spacing rather than oscillating in place.
      for (var j = 0; j < 11; j++) {
        if (i == j) continue;
        final difference = points[i] - points[j];
        if (difference.distance > 0.001 && difference.distance < 0.045) {
          target += difference / difference.distance * 0.035;
        }
      }
      final delta = _bound(target) - points[i];
      final speed =
          (0.045 + p.stats.speed / 1100) *
          (0.75 + p.currentStamina / 400) *
          (hasBall && i == owner ? 0.86 : 1);
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

  void restart(bool homeBall) {
    homePossession = homeBall;
    owner = 6;
    _lastPasser = null;
    _flight = null;
    ball = const Offset(0.5, 0.5);
    homePositions = List.of(_bases(home, true));
    awayPositions = List.of(_bases(away, false));
    _points[owner] = ball;
    _homeVelocity = List.filled(11, Offset.zero);
    _awayVelocity = List.filled(11, Offset.zero);
    phase = FieldPhase.kickoff;
    _stoppage = 0.45;
  }
}
