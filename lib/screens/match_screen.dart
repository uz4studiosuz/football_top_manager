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
import 'tactics_screen.dart';
import '../l10n/l10n.dart';

/// O'yin davomidagi taktik kayfiyat (In-Game Mentality)
enum InGameMentality {
  ultraAttack('Ultra hujum', Icons.keyboard_double_arrow_up_rounded, 1.35, 0.70),
  attack('Hujumkor', Icons.arrow_upward_rounded, 1.18, 0.85),
  balanced('Muvozanat', Icons.horizontal_rule_rounded, 1.00, 1.00),
  defensive('Himoyaviy', Icons.arrow_downward_rounded, 0.82, 1.22),
  parkBus('Avtobus', Icons.shield_rounded, 0.58, 1.45);

  final String _label;
  String get label => tr(_label);
  final IconData icon;
  final double attackMultiplier;
  final double defenseMultiplier;
  const InGameMentality(
    this._label,
    this.icon,
    this.attackMultiplier,
    this.defenseMultiplier,
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
    _feed.addAll(_field.takeEvents().reversed);
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _applyMentality() {
    final m = _mentality;
    if (_userHome) {
      _field.homeAttack = m.attackMultiplier;
      _field.awayAttack = 1 / m.defenseMultiplier;
    } else {
      _field.awayAttack = m.attackMultiplier;
      _field.homeAttack = 1 / m.defenseMultiplier;
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
    }
    if (_field.isHalfTime) _playing = false;
    if (_field.isFinished) _save();
    // Pause so the manager can react to an injury on their side.
    for (final id in _field.injuredOnPitch) {
      if (_handledInjuries.contains(id) || _user.playerById(id) == null) continue;
      _handledInjuries.add(id);
      if (_subsLeft > 0) {
        _playing = false;
        final p = _user.playerById(id)!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(trf('{0} jarohat oldi. Almashtirish kerak.', [p.shortName])),
              action: SnackBarAction(label: tr('Almashtirish'), onPressed: () => _openSubs(preselect: p)),
            ),
          );
        });
      }
    }
  }

  void _save() {
    if (_saved) return;
    _saved = true;
    _game.finishMatch(
      fixture: widget.fixture,
      homeScore: _field.homeStats.goals,
      awayScore: _field.awayStats.goals,
      events: _field.events,
      engine: _field,
    );
  }

  void _instantFinish() {
    setState(() {
      _field.simulateToEnd();
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

  Future<void> _openTactics() async {
    final resume = _playing;
    setState(() => _playing = false);
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TacticsScreen(
          onSwap: _swapInMatch,
          unavailable: {..._field.dismissed, ..._field.subbedOff},
        ),
      ),
    );
    if (mounted) setState(() => _playing = resume && !_field.isHalfTime);
  }

  void _openGoal(MatchEvent e, (Color, Color) colors) {
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
      canPop: finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(trf('{0} · {1}-tur', [_game.leagueName, widget.fixture.round]), style: AppText.h3),
          actions: [
            IconButton(
              tooltip: tr('Raqib tarkibi'),
              icon: const Icon(Icons.groups_outlined),
              onPressed: () => OpponentSquadSheet.show(context, opponentClub: _rival),
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
            final tabs = Column(
              children: [
                Container(
                  color: AppColors.surface,
                  child: TabBar(
                    tabs: [
                      Tab(text: tr('Jonli')),
                      Tab(text: tr('Statistika')),
                      Tab(text: tr('Tarkiblar')),
                      Tab(text: tr('Izohlar')),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
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
                  ),
                ),
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
            return Column(children: [pitchArea, Expanded(child: tabs)]);
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
    onOpenProfile: () => PlayerDetailView.show(context, player: p, club: club),
  );

  Widget _pitch((Color, Color) colors, double width, double maxHeight) {
    final h = (width * 68 / 105).clamp(150.0, maxHeight < 700 ? 190.0 : 320.0);
    return Container(
      height: h,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: MatchPitchPainter(
                  field: _field,
                  homeColor: colors.$1,
                  awayColor: colors.$2,
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
          if (ft)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size(0, 38)),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: widget.fixture)),
                  ),
                  child: Text(tr('Hisobot')),
                ),
                const SizedBox(width: 10),
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
      bench.sort((a, b) => b.getMatchOVR(pos).compareTo(a.getMatchOVR(pos)));
    }
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

  Widget _row(Player p, {required Widget trailing, String? subtitle, required VoidCallback onTap}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FaceAvatar(config: p.face, size: 36, shirt: widget.club.primaryColor, circle: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    PositionChip(p.mainPosition.code),
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
  MatchPitchPainter({required this.field, required this.homeColor, required this.awayColor});

  @override
  void paint(Canvas canvas, Size size) {
    const inset = EdgeInsets.all(6);
    const FootballPitchPainter(vertical: false, inset: inset).paint(canvas, size);
    final r = FootballPitchPainter.field(size, inset);
    Offset at(Offset p) => Offset(r.left + p.dx * r.width, r.top + p.dy * r.height);
    final radius = max(6.5, size.height * 0.036);
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
        final tp = TextPainter(
          text: TextSpan(
            text: '${p.number}',
            style: TextStyle(color: text, fontSize: radius * 0.95, fontWeight: FontWeight.w800, fontFamily: 'Roboto'),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
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
