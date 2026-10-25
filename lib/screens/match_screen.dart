import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';
import '../services/game_state.dart';
import '../services/match_field.dart';
import '../ui/face_avatar.dart';
import '../ui/football_pitch.dart';
import '../ui/match_widgets.dart';
import '../ui/shot_widgets.dart';
import '../ui/widgets.dart';
import 'match_report_screen.dart';
import 'widgets/opponent_squad_sheet.dart';
import 'widgets/player_detail_view.dart';
import 'player_match_screen.dart';
import 'shootout_screen.dart';
import '../ui/goal_replay.dart';
import '../ui/press_dialog.dart';
import '../services/cup.dart';
import '../services/lineup_solver.dart';
import 'tactics_screen.dart';
import '../l10n/l10n.dart';

/// O'yin davomidagi taktik kayfiyat (In-Game Mentality)
enum InGameMentality {
  ultraAttack('Ultra hujum', Icons.keyboard_double_arrow_up_rounded, 1.35, 0.70, 2),
  attack('Hujumkor', Icons.arrow_upward_rounded, 1.18, 0.85, 1),
  balanced('Muvozanat', Icons.horizontal_rule_rounded, 1.00, 1.00, 0),
  defensive('Himoyaviy', Icons.arrow_downward_rounded, 0.82, 1.22, -1),
  parkBus('Avtobus', Icons.shield_rounded, 0.58, 1.45, -2);

  final String _label;
  String get label => tr(_label);
  final IconData icon;
  final double attackMultiplier;
  final double defenseMultiplier;

  /// Team shape in the engine: -2 everyone behind the ball … +2 all forward.
  final double shape;
  const InGameMentality(
    this._label,
    this.icon,
    this.attackMultiplier,
    this.defenseMultiplier,
    this.shape,
  );
}

/// Live 2D match – SofaScore-style event page around a real-time pitch.
class MatchScreen extends StatefulWidget {
  final Fixture fixture;
  const MatchScreen({super.key, required this.fixture});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  /// Match minutes per real second at each speed step (1x ≈ 3 min match).
  static const speeds = <String, double>{'1x': 0.5, '2x': 1, '4x': 2, '8x': 4};
  final GameState _game = GameState();
  late final Club _home, _away;
  late final MatchField _field;
  late final Timer _timer;
  final Stopwatch _clock = Stopwatch();
  Duration _last = Duration.zero;
  String _speed = '1x';
  bool _playing = true;
  bool _saved = false;
  int _lineupTab = 0;
  InGameMentality _mentality = InGameMentality.balanced;
  final List<MatchEvent> _feed = [];
  final Set<String> _handledInjuries = {};

  /// Live orders shouted from the touchline; they change the tactics for
  /// this match only (restored at the final whistle).
  late TeamTactics _baseTactics;

  /// The tactics and individual instructions from before kick-off: changes
  /// made during the match apply to this match only.
  late final TeamTactics _preMatchTactics;
  late final Map<String, PlayerInstruction> _preMatchInstructions;

  void _restorePreMatch() {
    _user.tactics = _preMatchTactics;
    for (final p in _user.squad) {
      final ins = _preMatchInstructions[p.id];
      if (ins != null) p.instruction = ins;
    }
  }
  final Set<String> _orders = {};

  /// A player tapped on the pitch: highlighted, with a card for a while.
  String? _pickedId;
  Timer? _pickTimer;

  void _pickAt(Offset at, Size size) {
    final r = FootballPitchPainter.field(size, const EdgeInsets.all(6));
    String? best;
    var bestD = double.infinity;
    for (final (xi, pts) in [(_field.homeXI, _field.homePositions), (_field.awayXI, _field.awayPositions)]) {
      for (var i = 0; i < min(xi.length, pts.length); i++) {
        if (_field.dismissed.contains(xi[i].id)) continue;
        final c = Offset(r.left + pts[i].dx * r.width, r.top + pts[i].dy * r.height);
        final d = (c - at).distance;
        if (d < bestD) {
          bestD = d;
          best = xi[i].id;
        }
      }
    }
    if (best == null || bestD > max(22.0, size.height * 0.09)) return;
    final id = best;
    _pickTimer?.cancel();
    setState(() => _pickedId = id);
    _pickTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _pickedId = null);
    });
    // The same player sheet as in the line-ups.
    final home = _home.playerById(id) != null;
    final club = home ? _home : _away;
    final p = club.playerById(id);
    if (p != null) _showPlayer(p, club);
  }



  /// Orders already set in the pre-match tactics show as selected; the base
  /// they toggle against is the same tactics with those settings neutral.
  void _ordersFromTactics() {
    final t = _user.tactics;
    const neutral = TeamTactics();
    var base = t;
    if (t.attackingArea == AttackingArea.wide && t.width >= 4) {
      _orders.add('wings');
      base = base.copyWith(attackingArea: neutral.attackingArea, width: neutral.width);
    } else if (t.attackingArea == AttackingArea.centre && t.width <= 2) {
      _orders.add('centre');
      base = base.copyWith(attackingArea: neutral.attackingArea, width: neutral.width);
    }
    if (t.buildUp == BuildUpStyle.long) {
      _orders.add('long');
      base = base.copyWith(buildUp: neutral.buildUp);
    }
    if (t.pressing >= 5 && t.counterPress) {
      _orders.add('press');
      base = base.copyWith(pressing: neutral.pressing, counterPress: neutral.counterPress);
    }
    if (t.timeWasting) {
      _orders.add('slow');
      base = base.copyWith(tempo: neutral.tempo, timeWasting: false);
    } else if (t.tempo >= 5) {
      _orders.add('fast');
      base = base.copyWith(tempo: neutral.tempo);
    }
    _baseTactics = base;
  }

  void _toggleOrder(String order) {
    setState(() {
      if (!_orders.remove(order)) {
        _orders.add(order);
        if (order == 'wings') _orders.remove('centre');
        if (order == 'centre') _orders.remove('wings');
        if (order == 'slow') _orders.remove('fast');
        if (order == 'fast') _orders.remove('slow');
      }
      var t = _baseTactics;
      if (_orders.contains('wings')) t = t.copyWith(attackingArea: AttackingArea.wide, width: 5);
      if (_orders.contains('centre')) t = t.copyWith(attackingArea: AttackingArea.centre, width: 2);
      if (_orders.contains('long')) t = t.copyWith(buildUp: BuildUpStyle.long);
      if (_orders.contains('press')) t = t.copyWith(pressing: 5, counterPress: true);
      if (_orders.contains('slow')) t = t.copyWith(tempo: 1, timeWasting: true);
      if (_orders.contains('fast')) t = t.copyWith(tempo: 5, timeWasting: false);
      _user.tactics = t;
      _field.announce(
        MatchEventType.info,
        _orders.isEmpty ? tr('Murabbiy jamoani asl taktikaga qaytardi.') : trf('Murabbiy ko‘rsatmasi: {0}.', [_orders.map(_orderLabel).join(', ')]),
        _userHome,
      );
      _drain();
    });
  }

  static String _orderLabel(String o) => switch (o) {
    'wings' => tr('Qanotdan hujum'),
    'centre' => tr('Markazdan hujum'),
    'long' => tr('Uzun to‘plar'),
    'press' => tr('Yuqori pressing'),
    'slow' => tr('Vaqtni cho‘zish'),
    _ => tr('Tezkor o‘yin'),
  };

  @override
  void deactivate() {
    // Nothing changed during the match outlives it (and the save knows);
    // an abandoned match also gives the regular XI back.
    _restorePreMatch();
    if (!_saved) _game.cancelMatchPlan();
    Future.microtask(GameState().touch);
    super.deactivate();
  }

  /// VAR review on screen (text) and whether the half-time talk was given.
  String? _varText;
  bool _talkGiven = false;

  /// Play stops while VAR looks at the incident, then resumes.
  void _showVar(String text) {
    final resume = _playing;
    _varText = text;
    _playing = false;
    Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        _varText = null;
        if (!_field.isHalfTime && !_field.isFinished) _playing = resume;
      });
    });
  }

  /// Half-time team talk: each choice changes morale and how the team plays.
  void _teamTalk(int choice) {
    final rnd = Random();
    final xi = _user.startingXI.where((p) => !_field.dismissed.contains(p.id)).toList();
    final my = _userHome ? _field.homeStats.goals : _field.awayStats.goals;
    final their = _userHome ? _field.awayStats.goals : _field.homeStats.goals;
    String said;
    switch (choice) {
      case 0:
        for (final p in xi) {
          p.morale = min(100, p.morale + 8);
        }
        if (_userHome) {
          _field.homeAttackBoost *= 1.06;
        } else {
          _field.awayAttackBoost *= 1.06;
        }
        said = tr('“Sizlar bundan yaxshisiga qodirsizlar! Oldinga!” Jamoa hujumga ruhlandi.');
      case 1:
        for (final p in xi) {
          p.morale = min(100, p.morale + 3);
        }
        if (_userHome) {
          _field.homeFocus *= 0.93;
        } else {
          _field.awayFocus *= 0.93;
        }
        said = tr('“Himoyani ushlanglar, xato qilmanglar!” Jamoa diqqatini jamladi.');
      default:
        // Shouting wakes some players up and breaks others, more so when ahead.
        final wake = my < their ? 0.6 : my == their ? 0.5 : 0.35;
        var woke = 0;
        for (final p in xi) {
          if (rnd.nextDouble() < wake) {
            p.morale = min(100, p.morale + 12);
            p.currentStamina = min(100, p.currentStamina + 6);
            woke++;
          } else {
            p.morale = max(0, p.morale - 12);
          }
        }
        if (woke > xi.length / 2) {
          if (_userHome) {
            _field.homeAttackBoost *= 1.05;
          } else {
            _field.awayAttackBoost *= 1.05;
          }
        }
        said = trf('Murabbiy kiyinish xonasida baqirdi: {0} futbolchi uyg‘ondi, {1} tasi ruhan cho‘kdi.', [woke, xi.length - woke]);
    }
    _field.announce(MatchEventType.info, said, _userHome);
    setState(() {
      _talkGiven = true;
      _drain();
    });
  }

  Future<void> _askTeamTalk() async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Tanaffusdagi nutq')),
        children: [
          for (final (i, icon, title, hint) in [
            (0, Icons.campaign_outlined, tr('Ruhlantirish'), tr('Kayfiyat +8, hujum kuchayadi')),
            (1, Icons.shield_outlined, tr('Diqqat va himoya'), tr('Xatolar kamayadi, raqib imkoniyatlari pasayadi')),
            (2, Icons.sports_kabaddi_outlined, tr('Baqirish'), tr('Ba’zilar uyg‘onadi, ba’zilar ruhan cho‘kadi')),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon, color: AppColors.primary),
                title: Text(title, style: AppText.bodyStrong),
                subtitle: Text(hint, style: AppText.caption),
              ),
            ),
        ],
      ),
    );
    if (choice != null && mounted) _teamTalk(choice);
  }

  bool get _userHome => _home.id == _game.userClubId;
  Club get _user => _userHome ? _home : _away;
  Club get _rival => _userHome ? _away : _home;
  int get _subsLeft => 5 - (_userHome ? _field.homeSubsUsed : _field.awaySubsUsed);

  @override
  void initState() {
    super.initState();
    _home = _game.getClubById(widget.fixture.homeClubId)!;
    _away = _game.getClubById(widget.fixture.awayClubId)!;
    if (_home.id != _game.userClubId) _game.autoPickLineup(_home);
    if (_away.id != _game.userClubId) _game.autoPickLineup(_away);
    final coaching = _game.managerProfile.ratingFor(_user.tactics.playstyle);
    _game.beginUserMatch();
    _preMatchTactics = _game.preMatchTactics ?? _user.tactics;
    _preMatchInstructions = _game.preMatchInstructions ?? {for (final p in _user.squad) p.id: p.instruction};
    _field = MatchField(
      _home,
      _away,
      // Every kick-off plays out differently.
      seed: Random().nextInt(1 << 30),
      homeCoaching: _userHome ? coaching : 66 + _home.reputation ~/ 10,
      awayCoaching: _userHome ? 66 + _away.reputation ~/ 10 : coaching,
      homeAI: !_userHome,
      awayAI: _userHome,
    );
    _applyMentality();
    _game.applyClubBoosts(_field, _userHome);
    _field.slowSetPieces = true;
    _field.recordReplays = true;
    _field.marks = _game.manMarks;
    _field.derby = _game.isDerby(_home, _away);
    _baseTactics = _user.tactics;
    _ordersFromTactics();
    _feed.addAll(_field.takeEvents().reversed);
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    // The round's other matches are played in the background meanwhile.
    if (!_game.isKnockout(widget.fixture)) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted && !_saved) _game.presimulateRound(widget.fixture.id);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _pickTimer?.cancel();
    super.dispose();
  }

  void _applyMentality() {
    final m = _mentality;
    // Mentality changes the team's shape; the risks follow from it
    // (space behind a high block, few bodies forward in a low one).
    final attack = (1 + m.shape * 0.1).toDouble();
    if (_userHome) {
      _field
        ..homeShape = m.shape
        ..homeAttack = attack
        ..awayAttack = 1;
    } else {
      _field
        ..awayShape = m.shape
        ..awayAttack = attack
        ..homeAttack = 1;
    }
  }

  void _tick() {
    final now = _clock.elapsed, delta = now - _last;
    _last = now;
    if (!_playing || _field.isFinished || _field.isHalfTime) return;
    setState(() {
      _field.update(delta.inMicroseconds / 1e6 * speeds[_speed]!);
      _drain();
    });
  }

  void _drain() {
    for (final e in _field.takeEvents()) {
      _feed.insert(0, e);
      if (e.type == MatchEventType.varCheck) _showVar(e.description);
    }
    if (_field.isHalfTime) {
      _playing = false;
      if (!_talkGiven) {
        _talkGiven = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _askTeamTalk();
        });
      }
    }
    if (_field.isFinished) _save();
    // Pause so the manager can react to an injury on their side.
    for (final id in _field.injuredOnPitch) {
      if (_handledInjuries.contains(id) || _user.playerById(id) == null) continue;
      _handledInjuries.add(id);
      if (_subsLeft > 0) {
        // An injured player cannot go on: the substitution is compulsory.
        _playing = false;
        final p = _user.playerById(id)!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _forceInjurySub(p);
        });
      }
    }
  }

  /// Shootout result for a drawn cup match.
  (int, int)? _pens;

  bool get _needsShootout =>
      _game.isKnockout(widget.fixture) && _field.homeStats.goals == _field.awayStats.goals && _pens == null;

  void _save() {
    if (_saved || _needsShootout) return;
    _saved = true;
    _restorePreMatch();
    _game.finishMatch(
      fixture: widget.fixture,
      homeScore: _field.homeStats.goals,
      awayScore: _field.awayStats.goals,
      events: _field.events,
      engine: _field,
      penalties: _pens,
    );
  }

  Future<void> _playShootout() async {
    List<Player> onPitch(Club c) => c.startingXI.where((p) => !_field.dismissed.contains(p.id)).toList();
    Player keeper(Club c) => onPitch(c).firstWhere((p) => p.mainPosition.isGoalkeeper, orElse: () => onPitch(c).first);
    final result = await Navigator.push<(int, int)>(
      context,
      MaterialPageRoute(
        builder: (_) => ShootoutScreen(
          home: _home,
          away: _away,
          userHome: _userHome,
          homeTakers: PenaltyModel.takers(onPitch(_home)),
          awayTakers: PenaltyModel.takers(onPitch(_away)),
          homeKeeper: keeper(_home),
          awayKeeper: keeper(_away),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _pens = result;
      _save();
    });
  }

  Future<void> _instantFinish() async {
    setState(() => _playing = false);
    await runWithProgress(
      context,
      tr('Uchrashuv simulyatsiya qilinmoqda…'),
      (report) => _field.simulateToEndAsync(onProgress: report),
    );
    if (!mounted) return;
    setState(() {
      _drain();
      _save();
    });
  }

  void _setMentality(InGameMentality m) {
    setState(() {
      _mentality = m;
      _applyMentality();
      _field.announce(
        MatchEventType.info,
        trf('{0} murabbiyi jamoani "{1}" rejimiga o‘tkazdi.', [_user.shortName, m.label]),
        _userHome,
      );
      _drain();
    });
  }

  bool _swapInMatch(Player a, Player b) {
    if (_field.isFinished || _field.dismissed.contains(a.id) || _field.dismissed.contains(b.id)) {
      return false;
    }
    final aStarts = _user.startingLineupIds.contains(a.id), bStarts = _user.startingLineupIds.contains(b.id);
    if (aStarts && bStarts) {
      final i = _user.startingLineupIds.indexOf(a.id), j = _user.startingLineupIds.indexOf(b.id);
      _user.startingLineupIds[i] = b.id;
      _user.startingLineupIds[j] = a.id;
      setState(() {});
      return true;
    }
    if (!aStarts && !bStarts) return false;
    final out = aStarts ? a : b, incoming = aStarts ? b : a;
    final ok = _field.substitute(_userHome, out.id, incoming.id);
    if (ok) setState(_drain);
    return ok;
  }

  /// Compulsory substitution for an injured player: the match waits until
  /// a bench player is chosen.
  Future<void> _forceInjurySub(Player injured) async {
    final c = _user;
    final slot = c.startingLineupIds.indexOf(injured.id);
    if (slot < 0) return;
    final pos = c.slotPosition(slot);
    final options = [
      for (final b in c.bench)
        if (!_field.subbedOff.contains(b.id) && !_field.dismissed.contains(b.id) && b.isAvailable) b,
    ]..sort((a, b) => GameState.slotFit(b, pos).compareTo(GameState.slotFit(a, pos)));
    if (options.isEmpty) {
      setState(() => _playing = true);
      return;
    }
    final pick = await showDialog<Player>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(trf('{0} jarohat oldi', [injured.shortName])),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(trf('U o‘ynay olmaydi: {0} o‘rniga kimni chiqarasiz?', [pos.code]), style: AppText.small),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final b in options)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: PositionChip(b.mainPosition.code),
                          title: Text(b.shortName),
                          subtitle: Text(trf('Chidamlilik {0}%', [b.currentStamina])),
                          trailing: ValueBadge(b.getEffectiveOVR(pos), size: 28),
                          onTap: () => Navigator.pop(ctx, b),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || pick == null) return;
    setState(() {
      _field.substitute(_userHome, injured.id, pick.id);
      _drain();
      _playing = true;
    });
  }

  Future<void> _openSubs({Player? preselect}) async {
    final resume = _playing;
    setState(() => _playing = false);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SubstitutionSheet(
        field: _field,
        club: _user,
        isHome: _userHome,
        preselect: preselect,
        onDone: () => setState(_drain),
      ),
    );
    if (mounted && !_field.isHalfTime && !_field.isFinished) setState(() => _playing = resume || preselect != null);
  }

  /// In-match auto pick: injured or exhausted starters make way for the best
  /// bench fit (while substitutions remain), then everyone on the pitch is
  /// moved to the slot that suits him best. Reserves are never used.
  int _autoInMatch() {
    final c = _user;
    var changes = 0;
    for (var i = 0; i < 11; i++) {
      final id = c.startingLineupIds[i];
      final p = c.playerById(id);
      if (p == null || _field.dismissed.contains(id)) continue;
      if (!_field.isInjuredOnPitch(id) && p.currentStamina >= 45) continue;
      final pos = c.slotPosition(i);
      final options = [
        for (final b in c.bench)
          if (!_field.subbedOff.contains(b.id) && !_field.dismissed.contains(b.id)) b,
      ]..sort((a, b) => GameState.slotFit(b, pos).compareTo(GameState.slotFit(a, pos)));
      if (options.isNotEmpty && _field.substitute(_userHome, id, options.first.id)) changes++;
    }
    final free = [
      for (var i = 0; i < 11; i++)
        if (!_field.dismissed.contains(c.startingLineupIds[i])) i,
    ];
    final players = [for (final i in free) c.playerById(c.startingLineupIds[i])!];
    final pick = LineupSolver.assign([
      for (final i in free) [for (final p in players) GameState.slotFit(p, c.slotPosition(i))],
    ]);
    final next = List.of(c.startingLineupIds);
    for (var k = 0; k < free.length; k++) {
      if (pick[k] >= 0) next[free[k]] = players[pick[k]].id;
    }
    if (next.toSet().length == 11) {
      for (var i = 0; i < 11; i++) {
        if (next[i] != c.startingLineupIds[i]) changes++;
      }
      c.startingLineupIds
        ..clear()
        ..addAll(next);
    }
    setState(_drain);
    return changes;
  }

  Future<void> _openTactics() async {
    final resume = _playing;
    setState(() => _playing = false);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TacticsScreen(
          onSwap: _swapInMatch,
          onAutoPick: _autoInMatch,
          subMarks: () => {
            for (final e in _field.lines.entries)
              if (e.value.subOnMinute != null)
                e.key: (true, e.value.subOnMinute!)
              else if (e.value.subOffMinute != null)
                e.key: (false, e.value.subOffMinute!),
          },
          unavailable: {..._field.dismissed, ..._field.subbedOff},
        ),
      ),
    );
    // Changes made in the Tactics screen become the base for live orders
    // (for this match only; the pre-match tactics return at full time).
    if (_orders.isEmpty) _baseTactics = _user.tactics;
    if (mounted) setState(() => _playing = resume && !_field.isHalfTime);
  }

  void _openGoal(MatchEvent e, (Color, Color) colors) {
    // A recorded replay of this goal plays first.
    final replay = _field.replays.where((r) => r.minute == e.minute + e.extraMinute || r.minute == e.minute).lastOrNull;
    if (replay != null) {
      showGoalReplay(context, replay, colors.$1, colors.$2);
      return;
    }
    final shot = shotForGoal(_field.shots, e);
    if (shot == null) return;
    showShotDetailSheet(
      context,
      shot: shot,
      home: _home,
      away: _away,
      color: shot.home ? colors.$1 : colors.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = teamColors(_home, _away);
    final finished = _field.isFinished;
    return PopScope(
      canPop: finished && !_needsShootout,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_game.fixtureTitle(widget.fixture), style: AppText.h3),
          actions: [
            IconButton(
              tooltip: tr('Raqib tarkibi'),
              icon: const Icon(Icons.groups_outlined),
              onPressed: () => OpponentSquadSheet.show(context, opponentClub: _rival),
            ),
            if (!finished)
              IconButton(
                tooltip: tr('Taktika'),
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openTactics,
              ),
            if (!finished)
              TextButton.icon(
                onPressed: _instantFinish,
                icon: const Icon(Icons.fast_forward_rounded, size: 18),
                label: Text(tr('Tezkor')),
              ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, box) {
            final wide = box.maxWidth >= 980;
            final pitchArea = Column(
              children: [
                Container(
                  color: AppColors.surface,
                  child: MatchHeader(
                    home: _home,
                    away: _away,
                    homeScore: _field.homeStats.goals,
                    awayScore: _field.awayStats.goals,
                    status: _field.clockLabel,
                    live: !finished && !_field.isHalfTime,
                    events: _field.events,
                  ),
                ),
                _pitch(colors, wide ? box.maxWidth * 0.58 : box.maxWidth, box.maxHeight),
                _controls(),
              ],
            );
            final tabBar = TabBar(
              tabs: [
                Tab(text: tr('Jonli')),
                Tab(text: tr('Statistika')),
                Tab(text: tr('Tarkiblar')),
                Tab(text: tr('Izohlar')),
              ],
            );
            final tabViews = TabBarView(
                    children: [
                      _liveTab(colors),
                      ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          StatGroupsView(
                            groups: statGroupsFromEngine(_field),
                            homeColor: colors.$1,
                            awayColor: colors.$2,
                          ),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SectionHeader(tr('Zarbalar xaritasi'), icon: Icons.scatter_plot_outlined),
                                ShotMapView(
                                  shots: _field.shots,
                                  home: _home,
                                  away: _away,
                                  homeColor: colors.$1,
                                  awayColor: colors.$2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      _lineupsTab(colors),
                      ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _feed.length,
                        itemBuilder: (context, i) => CommentaryTile(
                          event: _feed[i],
                          homeColor: colors.$1,
                          awayColor: colors.$2,
                        ),
                      ),
                    ],
                  );
            final tabs = Column(
              children: [
                Container(color: AppColors.surface, child: tabBar),
                Expanded(child: tabViews),
              ],
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: box.maxWidth * 0.58, child: SingleChildScrollView(child: pitchArea)),
                  const VerticalDivider(width: 1),
                  Expanded(child: tabs),
                ],
              );
            }
            // Phones: the pitch scrolls away when reading the tabs (which stay
            // pinned), so live stats and commentary get the whole screen.
            return NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(child: pitchArea),
                SliverPersistentHeader(pinned: true, delegate: _PinnedTabs(tabBar)),
              ],
              body: tabViews,
            );
          },
        ),
      ),
    ),
    );
  }

  Future<void> _confirmExit() async {
    final resume = _playing;
    setState(() => _playing = false);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('O‘yindan chiqasizmi?')),
        content: Text(
          tr('Uchrashuv to‘xtatilmaydi: qolgan vaqt avtomatik simulyatsiya qilinadi va natija jadvalga yoziladi.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Davom etish'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Natijani hisoblab chiqish'))),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      _instantFinish();
      Navigator.of(context).pop();
    } else {
      setState(() => _playing = resume);
    }
  }

  void _showPlayer(Player p, Club club) => showPlayerMatchSheet(
    context,
    player: p,
    club: club,
    line: _field.lines[p.id],
    rating: _field.ratingFor(p.id),
    heat: _field.heat[p.id],
    onOpenProfile: () => PlayerDetailView.show(context, player: p, club: club).then((_) {
      if (mounted) setState(() {}); // a portrait may have been edited
    }),
    onOpenDetails: () => PlayerMatchScreen.show(
      context,
      PlayerMatchData(
        home: _home,
        away: _away,
        homeScore: _field.homeStats.goals,
        awayScore: _field.awayStats.goals,
        events: List.of(_field.events),
        shots: List.of(_field.shots),
        momentum: List.of(_field.momentum),
        lines: Map.of(_field.lines),
        ratings: {for (final id in _field.lines.keys) id: ?_field.ratingFor(id)},
        heatFor: (id) => _field.heat[id],
      ),
      p,
      club,
    ),
  );

  Widget _pitch((Color, Color) colors, double width, double maxHeight) {
    // Keep the real pitch shape (105×68): on wide screens the height limit
    // narrows the pitch instead of stretching it.
    final limit = maxHeight < 700 ? 190.0 : max(320.0, maxHeight * 0.5);
    final h = ((width - 20) * 68 / 105).clamp(150.0, limit);
    final w = min(width - 20, h * 105 / 68);
    return Container(
      height: h,
      width: w,
      margin: EdgeInsets.fromLTRB(max(10, (width - w) / 2), 8, max(10, (width - w) / 2), 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTapUp: (d) => _pickAt(d.localPosition, Size(w, h)),
                child: CustomPaint(
                  painter: MatchPitchPainter(
                    field: _field,
                    homeColor: colors.$1,
                    awayColor: colors.$2,
                    selectedId: _pickedId,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 10,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _field.actionLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (_field.isHalfTime || _field.isFinished)
              Positioned.fill(child: _breakOverlay(colors)),
            if (_varText != null)
              Positioned(
                left: 0,
                right: 0,
                top: 34,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.82), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                          child: const Text('VAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(_varText!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            if (_field.phase == FieldPhase.goal)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                  alignment: Alignment.center,
                  child: Text(
                    tr('GOOOL!'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    final done = _field.isFinished;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filled(
                onPressed: done || _field.isHalfTime ? null : () => setState(() => _playing = !_playing),
                icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
              ),
              const SizedBox(width: 4),
              for (final s in speeds.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: _speed == s,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _speed = s),
                  ),
                ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: done || _subsLeft <= 0 ? null : () => _openSubs(),
                icon: const Icon(Icons.swap_vert_rounded, size: 18),
                label: Text('$_subsLeft'),
              ),
            ],
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in InGameMentality.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(m.icon, size: 15, color: _mentality == m ? AppColors.primary : AppColors.ink2),
                      label: Text(m.label),
                      selected: _mentality == m,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: done ? null : (_) => _setMentality(m),
                    ),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.tune_rounded, size: 15),
                  label: Text(tr('Taktika')),
                  visualDensity: VisualDensity.compact,
                  onPressed: done ? null : _openTactics,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (o, icon) in [
                  ('wings', Icons.swap_horiz_rounded),
                  ('centre', Icons.vertical_align_center_rounded),
                  ('long', Icons.call_made_rounded),
                  ('press', Icons.compress_rounded),
                  ('slow', Icons.hourglass_bottom_rounded),
                  ('fast', Icons.fast_forward_rounded),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      avatar: Icon(icon, size: 15),
                      label: Text(_orderLabel(o)),
                      selected: _orders.contains(o),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: done ? null : (_) => _toggleOrder(o),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakOverlay((Color, Color) colors) {
    final h = _field.homeStats, a = _field.awayStats;
    final ft = _field.isFinished;
    Widget stat(String l, String hv, String av) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(hv, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          Expanded(child: Text(l, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12))),
          SizedBox(width: 44, child: Text(av, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    return Container(
      color: const Color(0xE6121826),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            ft ? tr('O‘YIN TUGADI') : tr('TANAFFUS'),
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
          ),
          Text(
            '${_home.shortName}  ${h.goals} – ${a.goals}  ${_away.shortName}',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          stat(tr('To‘p nazorati'), '${_field.homePossessionPercent}%', '${100 - _field.homePossessionPercent}%'),
          stat('xG', h.xg.toStringAsFixed(2), a.xg.toStringAsFixed(2)),
          stat(tr('Zarbalar'), '${h.shots}', '${a.shots}'),
          const SizedBox(height: 8),
          if (ft && _needsShootout)
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _playShootout,
              icon: const Icon(Icons.sports_soccer),
              label: Text(tr('Penaltilar seriyasi')),
            )
          else if (ft)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 38)),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: widget.fixture)),
                  ),
                  child: Text(tr('Hisobot')),
                ),
                // The post-match press conference, right after the whistle.
                if (_saved && _game.postPressFixture?.id == widget.fixture.id)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 38)),
                    onPressed: () async {
                      await runPressConference(context, widget.fixture, post: true);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.campaign_outlined, size: 18),
                    label: Text(tr('Matbuot anjumani')),
                  ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(tr('Boshqaruvga qaytish')),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 38)),
                  onPressed: _subsLeft > 0 ? () => _openSubs() : null,
                  child: Text(tr('Almashtirish')),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: () => setState(() {
                    _field.startSecondHalf();
                    _drain();
                    _playing = true;
                  }),
                  child: Text(tr('2-bo‘limni boshlash')),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _liveTab((Color, Color) colors) {
    final latest = _feed.where((e) => e.type != MatchEventType.info).take(4).toList();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(tr('Hujum momenti'), icon: Icons.insights_outlined),
              MomentumChart(
                values: _field.momentum,
                events: _field.events,
                homeColor: colors.$1,
                awayColor: colors.$2,
              ),
              const SizedBox(height: 10),
              StatCompareRow(
                label: tr('To‘p nazorati'),
                homeText: '${_field.homePossessionPercent}%',
                awayText: '${100 - _field.homePossessionPercent}%',
                home: _field.homePossessionPercent.toDouble(),
                away: 100.0 - _field.homePossessionPercent,
                homeColor: colors.$1,
                awayColor: colors.$2,
              ),
              StatCompareRow(
                label: 'xG',
                homeText: _field.homeStats.xg.toStringAsFixed(2),
                awayText: _field.awayStats.xg.toStringAsFixed(2),
                home: _field.homeStats.xg,
                away: _field.awayStats.xg,
                homeColor: colors.$1,
                awayColor: colors.$2,
              ),
              StatCompareRow(
                label: tr('Zarbalar (nishonga)'),
                homeText: '${_field.homeStats.shots} (${_field.homeStats.onTarget})',
                awayText: '${_field.awayStats.shots} (${_field.awayStats.onTarget})',
                home: _field.homeStats.shots.toDouble(),
                away: _field.awayStats.shots.toDouble(),
                homeColor: colors.$1,
                awayColor: colors.$2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              for (final e in latest)
                CommentaryTile(event: e, homeColor: colors.$1, awayColor: colors.$2),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            children: [
              SectionHeader(tr('Muhim voqealar'), icon: Icons.timeline_rounded),
              IncidentTimeline(
                events: _field.events,
                onGoalTap: (e) => _openGoal(e, colors),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _lineupsTab((Color, Color) colors) {
    final club = _lineupTab == 0 ? _home : _away;
    final xi = _lineupTab == 0 ? _field.homeXI : _field.awayXI;
    final ratings = {for (final p in club.squad) p.id: _field.ratingFor(p.id)};
    final ids = _field.lines.keys.where((id) => club.playerById(id) != null && _field.lines[id]!.minutes > 0).toList();
    final goals = <String, int>{
      for (final id in ids)
        if (_field.lines[id]!.goals > 0) id: _field.lines[id]!.goals,
    };
    final booked = _field.bookings.keys.where((id) => club.playerById(id) != null).toSet()
      ..addAll(_field.dismissed.where((id) => club.playerById(id) != null));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Center(
          child: PillTabs(
            labels: [_home.shortName, _away.shortName],
            index: _lineupTab,
            onChanged: (i) => setState(() => _lineupTab = i),
          ),
        ),
        const SizedBox(height: 12),
        LineupPitch(
          club: club,
          players: xi,
          ratings: ratings,
          dismissed: _field.dismissed,
          goals: goals,
          booked: booked,
          lines: _field.lines,
          shirt: _lineupTab == 0 ? colors.$1 : colors.$2,
          onTap: (p) => _showPlayer(p, club),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.only(bottom: 6),
          child: LineupList(
            club: club,
            starters: _lineupTab == 0 ? _field.homeStartIds : _field.awayStartIds,
            bench: _lineupTab == 0 ? _field.homeBenchIds : _field.awayBenchIds,
            lines: _field.lines,
            ratings: ratings,
            events: _field.events,
            motmId: _field.isFinished ? _field.manOfTheMatch : null,
            onTap: (p) => _showPlayer(p, club),
          ),
        ),
      ],
    );
  }
}

/// Two-step live substitution: choose who leaves, then who comes on.
class _SubstitutionSheet extends StatefulWidget {
  final MatchField field;
  final Club club;
  final bool isHome;
  final Player? preselect;
  final VoidCallback onDone;
  const _SubstitutionSheet({
    required this.field,
    required this.club,
    required this.isHome,
    required this.onDone,
    this.preselect,
  });
  @override
  State<_SubstitutionSheet> createState() => _SubstitutionSheetState();
}

class _SubstitutionSheetState extends State<_SubstitutionSheet> {
  Player? out;
  @override
  void initState() {
    super.initState();
    out = widget.preselect;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.field, c = widget.club;
    final used = widget.isHome ? f.homeSubsUsed : f.awaySubsUsed;
    final starters = c.startingXI.where((p) => !f.dismissed.contains(p.id)).toList();
    final bench = c.bench.where((p) => !f.subbedOff.contains(p.id) && p.isAvailable).toList();
    final outIndex = out == null ? -1 : c.startingLineupIds.indexOf(out!.id);
    final pos = outIndex < 0 ? null : c.slotPosition(outIndex);
    if (pos != null) {
      bench.sort((a, b) => GameState.slotFit(b, pos).compareTo(GameState.slotFit(a, pos)));
    }
    // Stars mark substitutes who know the position; the best one is filled.
    bool suits(Player p) =>
        pos != null && (p.fitFor(pos) == PositionFit.natural || p.fitFor(pos) == PositionFit.alternative);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      out == null ? tr('Kim maydonni tark etadi?') : trf('{0} o‘rniga kim?', [out!.shortName]),
                      style: AppText.h3,
                    ),
                  ),
                  Text(trf('{0}/5 qoldi', [5 - used]), style: AppText.small),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  if (out == null)
                    for (final p in starters)
                      _row(
                        p,
                        trailing: RatingBadge(f.ratingFor(p.id), size: 12),
                        subtitle: f.isInjuredOnPitch(p.id) ? tr('Jarohatlangan') : null,
                        onTap: () => setState(() => out = p),
                      )
                  else ...[
                    for (final p in bench)
                      _row(
                        p,
                        star: !suits(p) ? null : p == bench.first,
                        trailing: ValueBadge(pos == null ? p.ovr : p.getEffectiveOVR(pos), size: 30),
                        onTap: () {
                          if (f.substitute(widget.isHome, out!.id, p.id)) {
                            widget.onDone();
                            Navigator.pop(context);
                          }
                        },
                      ),
                    TextButton.icon(
                      onPressed: () => setState(() => out = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(tr('Boshqa futbolchini tanlash')),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Where the player is playing right now (his slot), or his own position
  /// for substitutes.
  String _slotCode(Player p) {
    final i = widget.club.startingLineupIds.indexOf(p.id);
    return i < 0 ? p.mainPosition.code : widget.club.slotPosition(i).code;
  }

  /// [star]: null = no star, false = suits the position, true = best choice.
  Widget _row(Player p, {required Widget trailing, String? subtitle, bool? star, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    child: Container(
      color: star == true ? AppColors.gold.withValues(alpha: 0.09) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FaceAvatar(config: p.face, size: 36, shirt: widget.club.primaryColor, circle: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (star != null) ...[
                      Icon(
                        star ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Flexible(child: Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 13))),
                    if (star == true) ...[
                      const SizedBox(width: 6),
                      Text(tr('Eng mos'), style: AppText.caption.copyWith(color: AppColors.gold, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PositionChip(_slotCode(p)),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: p.currentStamina / 100,
                          minHeight: 5,
                          color: p.currentStamina > 70
                              ? AppColors.win
                              : p.currentStamina > 50
                              ? AppColors.warning
                              : AppColors.loss,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(subtitle ?? '${p.currentStamina}%', style: AppText.caption.copyWith(color: subtitle != null ? AppColors.live : null)),
                  ],
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    ),
  );
}

/// Horizontal 2D pitch with 22 players, ball height/shadow and pass trail.
class MatchPitchPainter extends CustomPainter {
  final MatchField field;
  final Color homeColor, awayColor;

  /// The tapped player: ringed, with his number shown at any size.
  final String? selectedId;
  MatchPitchPainter({required this.field, required this.homeColor, required this.awayColor, this.selectedId});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = EdgeInsets.all(6);
    const FootballPitchPainter(vertical: false, inset: inset).paint(canvas, size);
    final r = FootballPitchPainter.field(size, inset);
    Offset at(Offset p) => Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);
    // Markers stay big enough for the shirt number to be read at any size.
    final radius = max(6.5, size.height * 0.026);
    final from = field.flightFrom, to = field.flightTo;
    if (from != null && to != null) {
      final trail = Paint()
        ..color = Colors.white.withValues(alpha: field.flightIsShot ? 0.65 : 0.35)
        ..strokeWidth = field.flightIsShot ? 2 : 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(at(from), at(field.ball), trail);
    }
    void team(List<Player> xi, List<Offset> pts, Color color, bool home) {
      final text = color.computeLuminance() > 0.55 ? const Color(0xFF14181F) : Colors.white;
      for (var i = 0; i < min(xi.length, pts.length); i++) {
        final p = xi[i];
        if (field.dismissed.contains(p.id)) continue;
        final c = at(pts[i]);
        final carrier = field.ballCarrier == p;
        final picked = p.id == selectedId;
        if (picked) {
          canvas.drawCircle(c, radius + 4, Paint()..color = Colors.white.withValues(alpha: 0.35));
        }
        canvas.drawCircle(c + const Offset(0, 1.5), radius, Paint()..color = Colors.black.withValues(alpha: 0.25));
        canvas.drawCircle(c, radius, Paint()..color = i == 0 ? Color.lerp(color, Colors.black, 0.25)! : color);
        canvas.drawCircle(
          c,
          radius,
          Paint()
            ..color = carrier ? const Color(0xFFFFE066) : Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = carrier ? 2.4 : 1.3,
        );
        {
          final tp = TextPainter(
            text: TextSpan(
              text: '${p.number}',
              style: TextStyle(color: text, fontSize: radius * 0.95, fontWeight: FontWeight.w800, fontFamily: 'Roboto'),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
        }
        if (field.isInjuredOnPitch(p.id)) {
          canvas.drawCircle(c + Offset(radius * 0.8, -radius * 0.8), radius * 0.38, Paint()..color = AppColors.live);
        }
      }
    }

    team(field.homeXI, field.homePositions, homeColor, true);
    team(field.awayXI, field.awayPositions, awayColor, false);
    final b = at(field.ball);
    final lift = field.ballHeight * radius * 1.6;
    canvas.drawOval(
      Rect.fromCenter(center: b + const Offset(0, 2), width: radius * 0.9, height: radius * 0.45),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    final ballR = radius * 0.5 * (1 + field.ballHeight * 0.35);
    final bc = b - Offset(0, lift);
    canvas.drawCircle(bc, ballR, Paint()..color = Colors.white);
    canvas.drawCircle(
      bc,
      ballR,
      Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawCircle(bc, ballR * 0.35, Paint()..color = const Color(0xFF222222));
  }

  @override
  bool shouldRepaint(covariant MatchPitchPainter oldDelegate) => true;
}

/// The match tabs, pinned under the pitch while the page scrolls.
class _PinnedTabs extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  const _PinnedTabs(this.bar);
  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: AppColors.surface, elevation: overlapsContent ? 2 : 0, child: bar);
  @override
  bool shouldRebuild(covariant _PinnedTabs old) => old.bar != bar;
}
