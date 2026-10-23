import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../models/league.dart';
import '../services/game_state.dart';
import '../services/match_field.dart';
import 'widgets/opponent_squad_sheet.dart';
import 'tactics_screen.dart';

/// O'yin davomidagi taktik kayfiyat (In-Game Mentality)
enum InGameMentality {
  ultraAttack(
    'Ultra Hujum',
    Icons.keyboard_double_arrow_up_rounded,
    Color(0xFF1769E0),
    1.35,
    0.70,
  ),
  attack('Hujumkor', Icons.arrow_upward_rounded, Color(0xFF1769E0), 1.18, 0.85),
  balanced(
    'Muvozanat',
    Icons.horizontal_rule_rounded,
    Color(0xFF1769E0),
    1.00,
    1.00,
  ),
  defensive(
    'Himoyaviy',
    Icons.arrow_downward_rounded,
    Color(0xFF1769E0),
    0.80,
    1.25,
  ),
  parkBus('Avtobus', Icons.shield_rounded, Color(0xFF1769E0), 0.55, 1.50);

  final String label;
  final IconData icon;
  final Color color;
  final double attackMultiplier;
  final double defenseMultiplier;
  const InGameMentality(
    this.label,
    this.icon,
    this.color,
    this.attackMultiplier,
    this.defenseMultiplier,
  );
}

/// 2D Match Engine va Jonli Uchrashuv Simulyatsiyasi Ekrani
class MatchScreen extends StatefulWidget {
  final Fixture fixture;
  const MatchScreen({super.key, required this.fixture});
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen>
    with SingleTickerProviderStateMixin {
  late Club _homeClub;
  late Club _awayClub;
  late Timer _matchTimer;
  final GameState _gameState = GameState();
  bool _halfTimeTaken = false;
  final Stopwatch _wallClock = Stopwatch();
  Duration _lastTick = Duration.zero;
  late MatchField _field;
  final Set<String> _dismissed = {};
  final Set<String> _subbedOff = {};
  final Set<String> _participants = {};
  int _minute = 0;
  int _homeScore = 0;
  int _awayScore = 0;
  int _speedMultiplier = 1; // 1x, 2x, 5x
  bool _isPlaying = true;
  bool _isFinished = false;
  // Real-time Match Statistics
  int _homeShots = 0;
  int _awayShots = 0;
  int _homeShotsOnTarget = 0;
  int _awayShotsOnTarget = 0;
  int _homeCorners = 0;
  int _awayCorners = 0;
  int _homeFouls = 0;
  int _awayFouls = 0;
  int _homeYellowCards = 0;
  int _awayYellowCards = 0;
  int _homeRedCards = 0;
  int _awayRedCards = 0;
  double _homeXG = 0.0;
  double _awayXG = 0.0;
  int _homePossession = 50;
  int _awayPossession = 50;
  // Foydalanuvchi taktik kayfiyati va almashtirishlar
  InGameMentality _userMentality = InGameMentality.balanced;
  int _substitutionsRemaining = 5;
  final List<MatchEvent> _events = [];
  final ScrollController _commentaryScroll = ScrollController();
  // 2D Maydondagi to'p va o'yinchilar koordinatalari
  double _ballX = 0.5;
  double _ballY = 0.5;
  bool get _isUserHome => _homeClub.id == _gameState.userClubId;
  Club get _userClub => _isUserHome ? _homeClub : _awayClub;
  Club get _rivalClub => _isUserHome ? _awayClub : _homeClub;
  @override
  void initState() {
    super.initState();
    _homeClub =
        _gameState.getClubById(widget.fixture.homeClubId) ??
        _gameState.userClub;
    _awayClub =
        _gameState.getClubById(widget.fixture.awayClubId) ??
        _gameState.allClubs.first;
    _field = MatchField(
      _homeClub,
      _awayClub,
      seed: widget.fixture.id.codeUnits.fold<int>(
        0,
        (a, b) => (a * 31 + b) & 0x7fffffff,
      ),
      homeCoaching: _isUserHome
          ? _gameState.managerProfile.ratingFor(_homeClub.tactics.playstyle)
          : 70,
      awayCoaching: !_isUserHome
          ? _gameState.managerProfile.ratingFor(_awayClub.tactics.playstyle)
          : 70,
    );
    _participants.addAll([
      ..._homeClub.startingLineupIds,
      ..._awayClub.startingLineupIds,
    ]);
    _calculatePossession();
    // Boshlang'ich hushtak voqeasi
    _addEvent(
      0,
      MatchEventType.kickoff,
      'Uchrashuv boshlandi! Hakam hushtagi chalindi. Muxlislar shiddatli bahs kutishmoqda.',
      _homeClub.id,
      true,
    );
    _startSimulationTimer();
  }

  @override
  void dispose() {
    _matchTimer.cancel();
    _commentaryScroll.dispose();
    super.dispose();
  }

  void _calculatePossession() {
    if (_isUserHome) {
      _field.homeCoaching = _gameState.managerProfile.ratingFor(
        _homeClub.tactics.playstyle,
      );
    } else {
      _field.awayCoaching = _gameState.managerProfile.ratingFor(
        _awayClub.tactics.playstyle,
      );
    }
    _field.homeAttack = _isUserHome
        ? _userMentality.attackMultiplier
        : 1 / _userMentality.defenseMultiplier;
    _field.awayAttack = !_isUserHome
        ? _userMentality.attackMultiplier
        : 1 / _userMentality.defenseMultiplier;
  }

  void _syncField() {
    final h = _field.homeStats, a = _field.awayStats;
    _homeScore = h.goals;
    _awayScore = a.goals;
    _homeShots = h.shots;
    _awayShots = a.shots;
    _homeShotsOnTarget = h.onTarget;
    _awayShotsOnTarget = a.onTarget;
    _homeCorners = h.corners;
    _awayCorners = a.corners;
    _homeFouls = h.fouls;
    _awayFouls = a.fouls;
    _homeYellowCards = h.yellows;
    _awayYellowCards = a.yellows;
    _homeRedCards = h.reds;
    _awayRedCards = a.reds;
    _homeXG = h.xg;
    _awayXG = a.xg;
    _homePossession = _field.homePossessionPercent;
    _awayPossession = 100 - _homePossession;
    _ballX = _field.ball.dx;
    _ballY = _field.ball.dy;
    _minute = _field.time.floor().clamp(0, 90);
    _dismissed.addAll(_field.dismissed);
    for (final event in _field.takeEvents()) {
      _events.insert(0, event);
    }
  }

  void _finish() {
    _isFinished = true;
    _matchTimer.cancel();
    _addEvent(
      90,
      MatchEventType.fullTime,
      'Uchrashuv yakunlandi.',
      _homeClub.id,
      true,
    );
    _saveMatchResult();
  }

  void _startSimulationTimer() {
    _wallClock.start();
    _matchTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = _wallClock.elapsed, delta = now - _lastTick;
      _lastTick = now;
      if (!_isPlaying || _isFinished) return;
      setState(() {
        _calculatePossession();
        final remaining = (_halfTimeTaken ? 90 : 45) - _field.time;
        _field.update(
          min(remaining, delta.inMicroseconds / 1000000 * _speedMultiplier),
          _dismissed,
        );
        _syncField();
        if (!_halfTimeTaken && _field.time >= 45) {
          _halfTimeTaken = true;
          _isPlaying = false;
          _field.restart(false);
          _addEvent(
            45,
            MatchEventType.halfTime,
            'Tanaffus. Ko‘rsatmalarni tekshirib davom ettiring.',
            _homeClub.id,
            true,
          );
        }
        if (_field.time >= 90) _finish();
      });
    });
  }

  void _addEvent(
    int min,
    MatchEventType type,
    String desc,
    String clubId,
    bool isHome, {
    String? playerName,
  }) {
    final event = MatchEvent(
      minute: min,
      type: type,
      description: desc,
      clubId: clubId,
      playerName: playerName,
      isHomeTeam: isHome,
    );
    _events.insert(0, event);
    if (_commentaryScroll.hasClients) {
      _commentaryScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  /// Tezkor yakunlash ("Instant Result")
  void _instantFinish() {
    _matchTimer.cancel();
    _calculatePossession();
    while (_field.time < 90 - 0.000001) {
      final limit = _halfTimeTaken ? 90.0 : 45.0;
      _field.update(min(1 / 30, limit - _field.time), _dismissed);
      if (!_halfTimeTaken && _field.time >= 45 - 0.000001) {
        _halfTimeTaken = true;
        _field.restart(false);
      }
    }
    _syncField();
    _minute = 90;
    _finish();
    setState(() {});
  }

  void _saveMatchResult() {
    widget.fixture.homePasses = _field.homeStats.passes;
    widget.fixture.awayPasses = _field.awayStats.passes;
    widget.fixture.homeCompletedPasses = _field.homeStats.completedPasses;
    widget.fixture.awayCompletedPasses = _field.awayStats.completedPasses;
    widget.fixture.homeShots = _homeShots;
    widget.fixture.awayShots = _awayShots;
    widget.fixture.homeShotsOnTarget = _homeShotsOnTarget;
    widget.fixture.awayShotsOnTarget = _awayShotsOnTarget;
    widget.fixture.homePossession = _homePossession;
    widget.fixture.awayPossession = _awayPossession;
    widget.fixture.homeCorners = _homeCorners;
    widget.fixture.awayCorners = _awayCorners;
    widget.fixture.homeFouls = _homeFouls;
    widget.fixture.awayFouls = _awayFouls;
    widget.fixture.homeXG = double.parse(_homeXG.toStringAsFixed(2));
    widget.fixture.awayXG = double.parse(_awayXG.toStringAsFixed(2));
    GameState().finishMatch(
      fixture: widget.fixture,
      homeScore: _homeScore,
      awayScore: _awayScore,
      events: _events,
      participantIds: _participants,
    );
  }

  bool _swapInMatch(Player a, Player b) {
    if (_isFinished || _dismissed.contains(a.id) || _dismissed.contains(b.id)) {
      return false;
    }
    final aStarts = _userClub.startingLineupIds.contains(a.id),
        bStarts = _userClub.startingLineupIds.contains(b.id);
    if (aStarts == bStarts) {
      final ok = _gameState.swapPlayer(a.id, b.id);
      if (ok && mounted) setState(() {});
      return ok;
    }
    final outgoing = aStarts ? a : b, incoming = aStarts ? b : a;
    if (_substitutionsRemaining <= 0 || _subbedOff.contains(incoming.id)) {
      return false;
    }
    _subbedOff.add(outgoing.id);
    _participants.add(incoming.id);
    _substitutionsRemaining--;
    final ok = _gameState.swapPlayer(outgoing.id, incoming.id);
    _addEvent(
      _minute,
      MatchEventType.substitution,
      '${outgoing.shortName} o‘rniga ${incoming.shortName} maydonga tushdi.',
      _userClub.id,
      _isUserHome,
      playerName: incoming.name,
    );
    if (mounted) setState(() {});
    return ok;
  }

  /// Jonli O'yinda Almashtirish (Live In-Match Substitution Modal)
  void _showLiveSubstitutionModal() {
    final user = _userClub;
    final starters = user.startingXI
        .where((p) => !_dismissed.contains(p.id))
        .toList();
    final bench = user.bench;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz_rounded,
                            color: Color(0xFF1769E0),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Almashtirishlar ($substitutionsRemaining qoldi)',
                            style: const TextStyle(
                              color: Color(0xFF192B42),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF637184),
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Text(
                    'Maydondagi o\'yinchini tanlang, so\'ng uning o\'rniga tushadigan futbolchini bosing:',
                    style: TextStyle(color: Color(0xFF637184), fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  // Maydondagi o'yinchilar
                  SizedBox(
                    height: 280,
                    child: ListView.builder(
                      itemCount: starters.length,
                      itemBuilder: (context, i) {
                        final starter = starters[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F5F8),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Color(0xFFE9EDF3)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: ListTile(
                              dense: true,
                              leading: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EDF3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  starter.mainPosition.code,
                                  style: const TextStyle(
                                    color: Color(0xFF192B42),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                starter.name,
                                style: const TextStyle(
                                  color: Color(0xFF192B42),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Stamina: ${starter.currentStamina}% • OVR ${starter.ovr}',
                                style: const TextStyle(
                                  color: Color(0xFF778496),
                                  fontSize: 11,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1769E0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed:
                                    _substitutionsRemaining > 0 &&
                                        bench.isNotEmpty
                                    ? () {
                                        _showPickBenchPlayerModal(starter, ctx);
                                      }
                                    : null,
                                child: const Text(
                                  'Almashtirish',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPickBenchPlayerModal(Player starter, BuildContext parentCtx) {
    final bench = _userClub.bench
        .where((p) => !_subbedOff.contains(p.id) && !_dismissed.contains(p.id))
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFFFFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (benchCtx) {
        return Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${starter.name} o\'rniga zaxiradan kim tushadi?',
                style: const TextStyle(
                  color: Color(0xFF192B42),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 240,
                child: ListView.builder(
                  itemCount: bench.length,
                  itemBuilder: (context, i) {
                    final bp = bench[i];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EDF3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            bp.mainPosition.code,
                            style: const TextStyle(
                              color: Color(0xFF192B42),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          bp.name,
                          style: const TextStyle(
                            color: Color(0xFF192B42),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'OVR ${bp.ovr} • Stamina: ${bp.currentStamina}%',
                          style: const TextStyle(
                            color: Color(0xFF778496),
                            fontSize: 11,
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1769E0),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            if (!_swapInMatch(starter, bp)) return;
                            Navigator.pop(benchCtx);
                            Navigator.pop(parentCtx);
                          },
                          child: const Text(
                            'Maydonga',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Jonli Statistika Modali (Live Stats Breakdown)
  Widget _buildStatBar(
    String label,
    String val1,
    String val2,
    int flex1,
    int flex2,
  ) {
    final f1 = max(1, flex1);
    final f2 = max(1, flex2);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              val1,
              style: const TextStyle(
                color: Color(0xFF192B42),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF637184), fontSize: 11),
            ),
            Text(
              val2,
              style: const TextStyle(
                color: Color(0xFF192B42),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Row(
            children: [
              Expanded(
                flex: f1,
                child: Container(height: 4, color: const Color(0xFF1769E0)),
              ),
              const SizedBox(width: 2),
              Expanded(
                flex: f2,
                child: Container(height: 4, color: const Color(0xFF3B82F6)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int get substitutionsRemaining => _substitutionsRemaining;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        title: Text(
          'Super League · ${widget.fixture.round}-tur',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Raqib tarkibi',
            icon: const Icon(Icons.people_outline),
            onPressed: () =>
                OpponentSquadSheet.show(context, opponentClub: _rivalClub),
          ),
          if (!_isFinished)
            TextButton.icon(
              onPressed: _instantFinish,
              icon: const Icon(Icons.fast_forward_outlined, size: 18),
              label: const Text('Tezkor'),
            ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Jonli'),
            Tab(text: 'Statistika'),
            Tab(text: 'Ko‘rsatmalar'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildScoreboardHeader(),
          Expanded(
            child: TabBarView(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Icon(
                            _field.phase == FieldPhase.goal
                                ? Icons.sports_soccer
                                : Icons.near_me_outlined,
                            size: 14,
                            color: const Color(0xFF1769E0),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _field.actionLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF526174),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _build2DPitchCanvas(),
                    _buildTacticsAndSimulationBar(),
                    Expanded(child: _buildCommentaryFeed()),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildStatBar(
                      'To‘p nazorati',
                      '$_homePossession%',
                      '$_awayPossession%',
                      _homePossession,
                      _awayPossession,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Kutilgan gollar · xG',
                      _homeXG.toStringAsFixed(2),
                      _awayXG.toStringAsFixed(2),
                      (_homeXG * 100).round(),
                      (_awayXG * 100).round(),
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Zarbalar',
                      '$_homeShots',
                      '$_awayShots',
                      _homeShots,
                      _awayShots,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Aniq zarbalar',
                      '$_homeShotsOnTarget',
                      '$_awayShotsOnTarget',
                      _homeShotsOnTarget,
                      _awayShotsOnTarget,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Aniq pas / jami',
                      '${_field.homeStats.completedPasses} / ${_field.homeStats.passes}',
                      '${_field.awayStats.completedPasses} / ${_field.awayStats.passes}',
                      _field.homeStats.completedPasses,
                      _field.awayStats.completedPasses,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Burchaklar',
                      '$_homeCorners',
                      '$_awayCorners',
                      _homeCorners,
                      _awayCorners,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Qoidabuzarliklar',
                      '$_homeFouls',
                      '$_awayFouls',
                      _homeFouls,
                      _awayFouls,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Sariq kartochkalar',
                      '$_homeYellowCards',
                      '$_awayYellowCards',
                      _homeYellowCards,
                      _awayYellowCards,
                    ),
                    const SizedBox(height: 24),
                    _buildStatBar(
                      'Qizil kartochkalar',
                      '$_homeRedCards',
                      '$_awayRedCards',
                      _homeRedCards,
                      _awayRedCards,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'xG har zarbaning imkoniyat sifatidan yig‘iladi. Gol bo‘lishi kafolatlanmaydi.',
                      style: TextStyle(color: Color(0xFF637184), height: 1.5),
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Match rejasi',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_userClub.tactics.formation.label),
                    const SizedBox(height: 8),
                    Text(
                      _userClub.tactics.playstyle.description,
                      style: const TextStyle(
                        color: Color(0xFF637184),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTacticsAndSimulationBar(),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isFinished
                          ? null
                          : () async {
                              final resume = _isPlaying;
                              setState(() => _isPlaying = false);
                              await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => TacticsScreen(
                                    onSwap: _swapInMatch,
                                    unavailable: {..._dismissed, ..._subbedOff},
                                  ),
                                ),
                              );
                              if (mounted) {
                                setState(() {
                                  _isPlaying = resume;
                                  _calculatePossession();
                                });
                              }
                            },
                      icon: const Icon(Icons.tune_outlined),
                      label: const Text('Sxema va ko‘rsatmalarni o‘zgartirish'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Hujumkor rejim ko‘proq imkoniyat yaratadi va himoyada bo‘shliq qoldiradi. Himoyaviy rejim zarbalarni kamaytiradi. Pressing va yuqori temp futbolchilarni tezroq charchatadi.',
                      style: TextStyle(height: 1.6, color: Color(0xFF637184)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isFinished) _buildMatchCompletedBar(),
        ],
      ),
    ),
  );
  Widget _buildScoreboardHeader() {
    return GestureDetector(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border(
            bottom: BorderSide(
              color: Color(0xFF192B42).withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Uy jamoasi
            Expanded(
              child: Row(
                children: [
                  ClubCrestWidget(config: _homeClub.crestConfig, size: 38),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _homeClub.shortName,
                          style: const TextStyle(
                            color: Color(0xFF192B42),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                        ),
                        Text(
                          'xG ${_homeXG.toStringAsFixed(2)} • $_homePossession%',
                          style: const TextStyle(
                            color: Color(0xFF778496),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Hisob va Daqiqa
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1769E0).withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$_homeScore - $_awayScore',
                    style: const TextStyle(
                      color: Color(0xFF192B42),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '$_minute\'',
                    style: TextStyle(
                      color: _isFinished
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1769E0),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Mehmon jamoasi
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _awayClub.shortName,
                          style: const TextStyle(
                            color: Color(0xFF192B42),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                        ),
                        Text(
                          '$_awayPossession% • xG ${_awayXG.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF778496),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ClubCrestWidget(config: _awayClub.crestConfig, size: 38),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2DPitchCanvas() {
    return Container(
      height: MediaQuery.sizeOf(context).height < 650 ? 150 : 220,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F5132),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Color(0xFF192B42).withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: MatchPitchPainter(
            ballX: _ballX,
            ballY: _ballY,
            homeColor: _homeClub.primaryColor,
            awayColor: _awayClub.primaryColor == _homeClub.primaryColor
                ? _awayClub.secondaryColor
                : _awayClub.primaryColor,
            homePositions: List.of(_field.homePositions),
            awayPositions: List.of(_field.awayPositions),
            homeClub: _homeClub,
            awayClub: _awayClub,
            dismissed: _dismissed,
          ),
        ),
      ),
    );
  }

  Widget _buildTacticsAndSimulationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFFFFFFF),
      child: Column(
        children: [
          // Taktik Mentality Segmented Picker
          Row(
            children: [
              const Text(
                'Taktika:',
                style: TextStyle(
                  color: Color(0xFF778496),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: InGameMentality.values.length,
                    itemBuilder: (context, i) {
                      final m = InGameMentality.values[i];
                      final isSel = m == _userMentality;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _userMentality = m;
                            _addEvent(
                              _minute,
                              MatchEventType.pass,
                              'Taktik ko\'rsatma (${_userClub.shortName}): Murabbiy jamoani "${m.label}" o\'yin uslubiga o\'tkazdi.',
                              _userClub.id,
                              _isUserHome,
                            );
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSel ? m.color : const Color(0xFFF3F5F8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSel ? m.color : Color(0xFFE4E9F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                m.icon,
                                size: 12,
                                color: isSel ? Colors.white : m.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                m.label,
                                style: TextStyle(
                                  color: isSel
                                      ? Colors.white
                                      : Color(0xFF526174),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Controls & Actions Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Play/Pause & Speed
              Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _isPlaying = !_isPlaying),
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      color: const Color(0xFF1769E0),
                      size: 28,
                    ),
                  ),
                  ...[1, 2, 5].map((spd) {
                    final isCur = _speedMultiplier == spd;
                    return GestureDetector(
                      onTap: () => setState(() => _speedMultiplier = spd),
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isCur
                              ? const Color(0xFF1769E0)
                              : const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${spd}x',
                          style: TextStyle(
                            color: isCur ? Colors.white : Color(0xFF526174),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              // Jonli almashtirish va Raqibni ko'rish tugmalari
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => OpponentSquadSheet.show(
                      context,
                      opponentClub: _rivalClub,
                    ),
                    icon: const Icon(
                      Icons.remove_red_eye_rounded,
                      size: 14,
                      color: Color(0xFF3B82F6),
                    ),
                    label: const Text(
                      'Raqib',
                      style: TextStyle(
                        color: Color(0xFF3B82F6),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1769E0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _showLiveSubstitutionModal,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                    label: Text(
                      'Subs ($_substitutionsRemaining)',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentaryFeed() {
    return ListView.builder(
      controller: _commentaryScroll,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final ev = _events[index];
        final isGoal = ev.type == MatchEventType.goal;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isGoal
                ? const Color(0xFF1769E0).withValues(alpha: 0.15)
                : const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isGoal
                  ? const Color(0xFF1769E0)
                  : Color(0xFF192B42).withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${ev.minute}\'',
                  style: const TextStyle(
                    color: Color(0xFF1769E0),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(ev.type.iconData, size: 17, color: const Color(0xFF637184)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ev.description,
                  style: TextStyle(
                    color: isGoal ? Color(0xFF192B42) : Color(0xFF526174),
                    fontWeight: isGoal ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchCompletedBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(color: Color(0xFF192B42).withValues(alpha: 0.08)),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          label: const Text(
            'BOSHQARUV PANELIGA QAYTISH',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1769E0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

/// 2D Futbol Maydoni Chizuvchi CustomPainter (Field lines, 22 ta o'yinchi nuqtalari va to'p)
class MatchPitchPainter extends CustomPainter {
  final double ballX;
  final double ballY;
  final Color homeColor;
  final Color awayColor;
  final List<Offset> homePositions, awayPositions;
  final Club homeClub;
  final Club awayClub;
  final Set<String> dismissed;
  MatchPitchPainter({
    required this.ballX,
    required this.ballY,
    required this.homeColor,
    required this.awayColor,
    required this.homePositions,
    required this.awayPositions,
    required this.homeClub,
    required this.awayClub,
    required this.dismissed,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Maydon chiziqlari (Oq)
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Chegara
    canvas.drawRect(Rect.fromLTWH(8, 8, w - 16, h - 16), linePaint);
    // O'rta chiziq
    canvas.drawLine(Offset(w / 2, 8), Offset(w / 2, h - 8), linePaint);
    // Markaziy aylana
    canvas.drawCircle(Offset(w / 2, h / 2), h * 0.22, linePaint);
    canvas.drawCircle(
      Offset(w / 2, h / 2),
      2,
      linePaint..style = PaintingStyle.fill,
    );
    // Chap Jarima maydonchasi (Home Goal Box)
    canvas.drawRect(
      Rect.fromLTWH(8, h * 0.22, w * 0.16, h * 0.56),
      linePaint..style = PaintingStyle.stroke,
    );
    // O'ng Jarima maydonchasi (Away Goal Box)
    canvas.drawRect(
      Rect.fromLTWH(w - 8 - (w * 0.16), h * 0.22, w * 0.16, h * 0.56),
      linePaint,
    );
    // O'yinchilar nuqtalari (11 ta Home, 11 ta Away)
    _drawTeamNodes(canvas, w, h, isHome: true, color: homeColor);
    _drawTeamNodes(canvas, w, h, isHome: false, color: awayColor);
    // To'p (Oq nuqta va soya)
    final bx = 8 + (ballX * (w - 16));
    final by = 8 + (ballY * (h - 16));
    final ballPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(bx, by), 4.5, ballPaint);
    canvas.drawCircle(
      Offset(bx, by),
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawTeamNodes(
    Canvas canvas,
    double w,
    double h, {
    required bool isHome,
    required Color color,
  }) {
    final paint = Paint()..color = color;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final club = isHome ? homeClub : awayClub;
    final slots = club.tactics.formation.slots;
    final players = club.startingXI;
    for (var i = 0; i < min(players.length, slots.length); i++) {
      if (dismissed.contains(players[i].id)) continue;
      final pos = (isHome ? homePositions : awayPositions)[i];
      final x = pos.dx;
      final y = pos.dy;
      final point = Offset(8 + x * (w - 16), 8 + y * (h - 16));
      canvas.drawCircle(point, 8, paint);
      canvas.drawCircle(point, 8, stroke);
      final text = TextPainter(
        text: TextSpan(
          text: '${players[i].number}',
          style: TextStyle(
            color: color.computeLuminance() > 0.5
                ? const Color(0xFF192B42)
                : Colors.white,
            fontSize: 8,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant MatchPitchPainter oldDelegate) {
    return true;
  }
}
