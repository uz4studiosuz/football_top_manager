import 'dart:math';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/cup.dart';
import '../ui/widgets.dart';
import '../l10n/l10n.dart';

/// Interactive penalty shootout. On the manager's kicks he picks the corner;
/// on the opponent's he picks where the keeper dives. Returns (home, away).
class ShootoutScreen extends StatefulWidget {
  final Club home, away;
  final bool userHome;
  final List<Player> homeTakers, awayTakers;
  final Player homeKeeper, awayKeeper;
  const ShootoutScreen({
    super.key,
    required this.home,
    required this.away,
    required this.userHome,
    required this.homeTakers,
    required this.awayTakers,
    required this.homeKeeper,
    required this.awayKeeper,
  });

  @override
  State<ShootoutScreen> createState() => _ShootoutScreenState();
}

class _ShootoutScreenState extends State<ShootoutScreen> {
  final _rnd = Random();
  final List<bool> _home = [], _away = [];
  bool _homeTurn = true;
  bool _busy = false;
  String? _banner;
  Alignment _ball = const Alignment(0, 0.88);
  Alignment _keeper = const Alignment(0, 0.02);

  bool get _done => PenaltyModel.decided(_home, _away);
  bool get _userKicks => _homeTurn == widget.userHome;
  Player get _taker {
    final list = _homeTurn ? widget.homeTakers : widget.awayTakers;
    return list[(_homeTurn ? _home.length : _away.length) % list.length];
  }

  Player get _keeperNow => _homeTurn ? widget.awayKeeper : widget.homeKeeper;

  static Alignment _zoneAlign(Zone z) => Alignment(-0.62 + z.col * 0.62, z.row == 1 ? -0.5 : 0.1);

  /// Plays one kick; [userZone] is the corner (own kick) or dive (opponent's).
  Future<void> _kick(Zone userZone) async {
    if (_busy || _done) return;
    final taker = _taker;
    final shot = _userKicks ? userZone : PenaltyModel.aim(taker, _rnd);
    final dive = _userKicks ? PenaltyModel.dive(_rnd) : userZone;
    final result = PenaltyModel.kick(taker, _keeperNow, shot, dive, _rnd);
    setState(() {
      _busy = true;
      _keeper = Alignment(_zoneAlign(dive).x * 0.9, _zoneAlign(dive).y + 0.05);
      _ball = result == 'miss'
          ? Alignment(shot.col == 1 ? 0.15 : (shot.col == 0 ? -0.98 : 0.98), shot.row == 1 ? -0.98 : 0.0)
          : result == 'save'
          ? Alignment(_zoneAlign(dive).x * 0.9, _zoneAlign(dive).y + 0.25)
          : _zoneAlign(shot);
    });
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      (_homeTurn ? _home : _away).add(result == 'goal');
      _banner = switch (result) {
        'goal' => trf('GOL! {0}', [taker.shortName]),
        'save' => tr('QAYTARDI!'),
        _ => trf('{0} darvozadan tashqariga tepdi', [taker.shortName]),
      };
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _banner = null;
      _busy = false;
      _ball = const Alignment(0, 0.88);
      _keeper = const Alignment(0, 0.02);
      if (!_done) _homeTurn = !_homeTurn;
    });
  }

  /// Plays every remaining kick automatically.
  void _auto() {
    setState(() {
      while (!_done) {
        final taker = _taker;
        (_homeTurn ? _home : _away).add(PenaltyModel.kick(taker, _keeperNow, PenaltyModel.aim(taker, _rnd), PenaltyModel.dive(_rnd), _rnd) == 'goal');
        if (!_done) _homeTurn = !_homeTurn;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hs = _home.where((x) => x).length, as = _away.where((x) => x).length;
    final winnerHome = hs > as;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F3D26),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF0F3D26),
          foregroundColor: Colors.white,
          title: Text(tr('Penaltilar seriyasi'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
          actions: [
            if (!_done) TextButton(onPressed: _busy ? null : _auto, child: Text(tr('Avto'), style: const TextStyle(color: Colors.white))),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                children: [
                  _scoreboard(hs, as),
                  const SizedBox(height: 12),
                  Text(
                    _done
                        ? trf('{0} penaltilarda g‘alaba qozondi!', [(winnerHome ? widget.home : widget.away).name])
                        : _userKicks
                        ? trf('Zarba: {0}. Burchakni tanlang', [_taker.shortName])
                        : trf('Raqib zarbasi: {0}. Darvozabon qayerga sakraydi?', [_taker.shortName]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AspectRatio(aspectRatio: 1.45, child: _goal()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _done
                        ? SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(context, (hs, as)),
                              child: Text(tr('Davom etish')),
                            ),
                          )
                        : Text(
                            _userKicks
                                ? trf('Darvozabon: {0}', [_keeperNow.shortName])
                                : trf('Bizning darvozabon: {0}', [_keeperNow.shortName]),
                            style: const TextStyle(color: Colors.white70),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _scoreboard(int hs, int as) {
    Widget dots(List<bool> kicks) => Wrap(
      spacing: 4,
      children: [
        for (var i = 0; i < max(5, kicks.length); i++)
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i >= kicks.length ? Colors.white24 : (kicks[i] ? AppColors.win : AppColors.live),
            ),
          ),
      ],
    );
    Widget team(Club c, List<bool> kicks) => Expanded(
      child: Column(
        children: [
          ClubCrestWidget(config: c.crestConfig, size: 44),
          const SizedBox(height: 6),
          Text(c.shortName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          dots(kicks),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          team(widget.home, _home),
          Text('$hs – $as', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          team(widget.away, _away),
        ],
      ),
    );
  }

  Widget _goal() => LayoutBuilder(
    builder: (context, box) => Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: _GoalPainter())),
        AnimatedAlign(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOut,
          alignment: _keeper,
          child: _KeeperFigure(width: box.maxWidth * 0.13),
        ),
        AnimatedAlign(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          alignment: _ball,
          child: Icon(Icons.sports_soccer, color: Colors.white, size: box.maxWidth * 0.07),
        ),
        // Tap a zone: own kick = where to shoot, opponent's = where to dive.
        if (!_busy && !_done)
          Positioned(
            left: box.maxWidth * 0.1,
            right: box.maxWidth * 0.1,
            top: box.maxHeight * 0.12,
            height: box.maxHeight * 0.55,
            child: Column(
              children: [
                for (final row in [1, 0])
                  Expanded(
                    child: Row(
                      children: [
                        for (final col in [0, 1, 2])
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Material(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _kick((col: col, row: row)),
                                  child: Center(
                                    child: Icon(
                                      _userKicks ? Icons.adjust_rounded : Icons.back_hand_outlined,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (_banner != null)
          Align(
            alignment: const Alignment(0, -0.9),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
              child: Text(_banner!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
          ),
      ],
    ),
  );
}

class _KeeperFigure extends StatelessWidget {
  final double width;
  const _KeeperFigure({required this.width});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width * 1.8,
    height: width * 1.9,
    child: CustomPaint(painter: _KeeperPainter()),
  );
}

class _KeeperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final kit = Paint()..color = const Color(0xFFF5C518);
    final skin = Paint()..color = const Color(0xFFD9A47F);
    final glove = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w / 2, h * 0.14), w * 0.13, skin);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.33, h * 0.26, w * 0.34, h * 0.36), const Radius.circular(6)), kit);
    final arm = Paint()
      ..color = const Color(0xFFF5C518)
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.36, h * 0.32), Offset(w * 0.08, h * 0.12), arm);
    canvas.drawLine(Offset(w * 0.64, h * 0.32), Offset(w * 0.92, h * 0.12), arm);
    canvas.drawCircle(Offset(w * 0.06, h * 0.1), w * 0.07, glove);
    canvas.drawCircle(Offset(w * 0.94, h * 0.1), w * 0.07, glove);
    final leg = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.42, h * 0.62), Offset(w * 0.34, h * 0.95), leg);
    canvas.drawLine(Offset(w * 0.58, h * 0.62), Offset(w * 0.66, h * 0.95), leg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GoalPainter extends CustomPainter {
  const _GoalPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final goal = Rect.fromLTRB(w * 0.1, h * 0.1, w * 0.9, h * 0.67);
    // Grass and penalty spot.
    canvas.drawRect(Rect.fromLTRB(0, goal.bottom, w, h), Paint()..color = const Color(0xFF2E8B57));
    canvas.drawCircle(Offset(w / 2, h * 0.94), 4, Paint()..color = Colors.white);
    canvas.drawLine(Offset(0, goal.bottom), Offset(w, goal.bottom), Paint()
      ..color = Colors.white
      ..strokeWidth = 2);
    final net = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (var x = goal.left; x <= goal.right; x += w * 0.03) {
      canvas.drawLine(Offset(x, goal.top), Offset(x, goal.bottom), net);
    }
    for (var y = goal.top; y <= goal.bottom; y += h * 0.045) {
      canvas.drawLine(Offset(goal.left, y), Offset(goal.right, y), net);
    }
    final post = Paint()
      ..color = Colors.white
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(goal.bottomLeft, goal.topLeft, post);
    canvas.drawLine(goal.topLeft, goal.topRight, post);
    canvas.drawLine(goal.topRight, goal.bottomRight, post);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
