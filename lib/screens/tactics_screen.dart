import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/football_pitch.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';
import 'widgets/team_instructions_view.dart';
import 'squad_screen.dart';
import 'player_creator_screen.dart';
import '../l10n/l10n.dart';

class TacticsScreen extends StatefulWidget {
  final bool Function(Player, Player)? onSwap;

  /// In a match: re-arranges the XI and replaces tired starters; returns
  /// the number of changes made.
  final int Function()? onAutoPick;

  /// In a match: who came on (true) or went off (false), and the minute.
  final Map<String, (bool, int)> Function()? subMarks;
  final Set<String> unavailable;

  /// Before kick-off: a line-up and tactics for the coming match only.
  final bool matchPlan;

  /// App bar title of the match-day plan ("Match plan vs …").
  final String? planTitle;
  const TacticsScreen({
    super.key,
    this.onSwap,
    this.onAutoPick,
    this.subMarks,
    this.unavailable = const {},
    this.matchPlan = false,
    this.planTitle,
  });
  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  final game = GameState();
  final _squadScroll = ScrollController();
  Timer? _dragTimer;
  Offset? _dragPointer;
  Player? _dragging; // shows every slot's fit while a player is dragged

  static Color fitColor(PositionFit f) => switch (f) {
    PositionFit.natural || PositionFit.alternative => AppColors.win,
    PositionFit.similar => AppColors.warning,
    PositionFit.poor => AppColors.live,
  };
  bool get _inMatch => widget.onSwap != null;

  void _startDrag() {
    _dragTimer?.cancel();
    _dragTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      if (!_squadScroll.hasClients || _dragPointer == null) return;
      final h = MediaQuery.sizeOf(context).height;
      final dy = _dragPointer!.dy;
      final step = dy < 170
          ? -9.0
          : dy > h - 125
          ? 9.0
          : 0.0;
      if (step != 0) {
        _squadScroll.jumpTo(
          (_squadScroll.offset + step).clamp(0.0, _squadScroll.position.maxScrollExtent),
        );
      }
    });
  }

  void _endDrag() {
    _dragTimer?.cancel();
    _dragPointer = null;
  }

  @override
  void dispose() {
    _endDrag();
    _squadScroll.dispose();
    super.dispose();
  }

  /// Sent off, or already substituted in this match (live).
  bool _isOut(String id) => widget.unavailable.contains(id) || widget.subMarks?.call()[id]?.$1 == false;

  bool _swap(String a, String b) {
    final club = game.userClub;
    final p = club.playerById(a), q = club.playerById(b);
    if (p == null || q == null || a == b) return false;
    final starters = club.startingLineupIds.toSet();
    final substitution = _inMatch && starters.contains(a) != starters.contains(b);
    final ok = widget.onSwap?.call(p, q) ?? game.swapPlayer(a, b);
    if (ok) {
      setState(() {});
      if (substitution) {
        final incoming = starters.contains(a) ? q : p, outgoing = starters.contains(a) ? p : q;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('Almashtirish: ↑ {0}  ↓ {1}', [incoming.shortName, outgoing.shortName]))),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Bu almashtirishga hozir ruxsat yo‘q. Limit va o‘yindan chiqqan futbolchilarni tekshiring.'),
          ),
        ),
      );
    }
    return ok;
  }

  void _menu(Player p) {
    final club = game.userClub;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.74,
          child: StatefulBuilder(
            builder: (ctx, update) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaceAvatar(config: p.face, size: 56, shirt: club.primaryColor, trim: club.secondaryColor, circle: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: AppText.h3),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                PositionChip(p.mainPosition.code),
                                const SizedBox(width: 8),
                                Text(trf('{0}% tayyor', [p.currentStamina]), style: AppText.caption),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ValueBadge(p.ovr, size: 38),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _fitSummary(p, club),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PlayerDetailView.show(context, player: p, club: club);
                    },
                    icon: const Icon(Icons.person_outline),
                    label: Text(tr('To‘liq profil')),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PlayerInstruction>(
                    initialValue: p.instruction,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Individual ko‘rsatma')),
                    items: [
                      for (final role in PlayerInstruction.values)
                        DropdownMenuItem(value: role, child: Text(role.label)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        game.setPlayerInstruction(p, v);
                        update(() {});
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(p.instruction.description, style: AppText.caption),
                  if (!p.mainPosition.isGoalkeeper && game.upcomingRival != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: game.manMarks[p.id] ?? '',
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: trf('Shaxsiy qo‘riqlash (man marking) · {0}', [game.upcomingRival!.shortName]),
                      ),
                      items: [
                        DropdownMenuItem(value: '', child: Text(tr('Yo‘q – zonali himoya'))),
                        for (final r in game.upcomingRival!.startingXI.where((r) => !r.mainPosition.isGoalkeeper))
                          DropdownMenuItem(value: r.id, child: Text('${r.mainPosition.code} · ${r.shortName} (${r.ovr})')),
                      ],
                      onChanged: (v) {
                        final rival = game.upcomingRival!;
                        game.setManMark(p, v == null || v.isEmpty ? null : rival.playerById(v));
                        update(() {});
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(tr('Faqat shu o‘yin uchun: tanlangan raqib qayerga borsa, unga yopishib yuradi.'), style: AppText.caption),
                  ],
                  const SizedBox(height: 16),
                  Text(tr('Almashtirish uchun futbolchi tanlang'), style: AppText.bodyStrong),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final q in club.squad.where((q) => q.id != p.id && !_isOut(q.id)))
                          InkWell(
                            onTap: () {
                              if (_swap(p.id, q.id)) Navigator.pop(ctx);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  FaceAvatar(config: q.face, size: 34, shirt: club.primaryColor, circle: true),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(q.name, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                                        Text(
                                          '${q.mainPosition.code} · ${club.startingLineupIds.contains(q.id) ? tr('Asosiy') : club.benchIds.contains(q.id) ? tr('Zaxira') : tr('Rezerv')}'
                                          '${q.isAvailable ? '' : ' · ${tr('o‘ynay olmaydi')}'}',
                                          style: AppText.caption,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ValueBadge(q.ovr, size: 28),
                                ],
                              ),
                            ),
                          ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isInitialized) return const Scaffold();
        final club = game.userClub, t = club.tactics;
        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.planTitle ?? tr('Jamoa')),
              actions: [
                if (!_inMatch)
                  IconButton(
                    tooltip: tr('Futbolchi yaratish'),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => PlayerCreatorScreen()),
                    ),
                  ),
                if (_inMatch && widget.onAutoPick != null)
                  TextButton.icon(
                    onPressed: () {
                      final n = widget.onAutoPick!();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            n == 0 ? tr('Tarkib allaqachon eng yaxshi holatda') : trf('Avto tarkib: {0} ta o‘zgarish', [n]),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: Text(tr('Avto tarkib')),
                  ),
                if (!_inMatch)
                  PopupMenuButton<bool>(
                    tooltip: tr('Avto tarkib'),
                    onSelected: (byForm) {
                      game.autoPickUserLineup(byForm: byForm);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            byForm
                                ? tr('Tarkib forma va jismoniy holat bo‘yicha tanlandi')
                                : tr('Eng kuchli va pozitsiyaga mos tarkib tanlandi'),
                          ),
                        ),
                      );
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: false,
                        child: ListTile(
                          leading: Icon(Icons.bolt_rounded),
                          title: Text(tr('Eng kuchli tarkib')),
                          subtitle: Text(tr('Pozitsiyaga mos OVR')),
                        ),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: ListTile(
                          leading: Icon(Icons.trending_up_rounded),
                          title: Text(tr('Forma bo‘yicha')),
                          subtitle: Text(tr('Reyting va jismoniy holat')),
                        ),
                      ),
                    ],
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            tr('Avto tarkib'),
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: tr('Sxema va tarkib')),
                  Tab(text: tr('Ro‘yxat')),
                  Tab(text: tr('Taktika')),
                  Tab(text: tr('Ko‘rsatmalar')),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                LayoutBuilder(
                  builder: (context, box) {
                    final top = <Widget>[
                        AppCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              _rating(tr('JAMOA'), club.teamOVR),
                              _rating(tr('HUJUM'), club.attackRating),
                              _rating(tr('MARKAZ'), club.midfieldRating),
                              _rating(tr('HIMOYA'), club.defenseRating),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Wide screens show every formation; phones scroll one row
                        // (touch or mouse drag).
                        Builder(
                          builder: (context) {
                            final chips = [
                              for (final f in FormationType.values)
                                ChoiceChip(
                                  label: Text(f.label),
                                  selected: t.formation == f,
                                  showCheckmark: false,
                                  onSelected: (_) => game.updateTactics(t.copyWith(formation: f)),
                                ),
                            ];
                            if (box.maxWidth >= 700) return Wrap(spacing: 8, runSpacing: 8, children: chips);
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final c in chips) Padding(padding: const EdgeInsets.only(right: 8), child: c),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        if (_inMatch || widget.matchPlan)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.matchPlan
                                        ? tr('Bu tarkib va taktika faqat shu o‘yin uchun: o‘yindan keyin asosiy tarkib qaytadi.')
                                        : tr('O‘yin davomidagi o‘zgarishlar faqat shu o‘yin uchun: o‘yindan keyin asosiy taktika qaytadi.'),
                                    style: AppText.caption.copyWith(color: AppColors.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Icon(Icons.drag_indicator, size: 16, color: AppColors.ink3),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tr('Ushlab suring: o‘rin almashtirish. Bosing: profil va ko‘rsatma.'),
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                    ];
                    final groups = <Widget>[
                        _group(tr('Zaxira'), club.bench, trf('O‘yin kuni zaxirasi · {0}/{1}', [club.bench.length, Club.matchdayBench])),
                        const SizedBox(height: 12),
                        if (_inMatch)
                          Text(
                            tr('O‘yin davomida faqat zaxiradagi futbolchilar maydonga tushishi mumkin. Rezervdagilarni o‘yindan oldin zaxira yoki asosiy tarkibga qo‘ying.'),
                            style: AppText.caption,
                          )
                        else
                          _group(tr('Rezerv'), club.reserves, trf('Tarkibdan tashqari · {0}', [club.reserves.length])),
                    ];
                    // Desktop: pitch on the left, bench and reserves beside it.
                    if (box.maxWidth >= 1000) {
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: min(620, box.maxWidth * 0.52),
                              child: ListView(children: [...top, _pitch(club)]),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ListView(controller: _squadScroll, children: [...groups, const SizedBox(height: 24)]),
                            ),
                          ],
                        ),
                      );
                    }
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: ListView(
                          controller: _squadScroll,
                          padding: const EdgeInsets.all(12),
                          children: [...top, _pitch(club), const SizedBox(height: 16), ...groups, const SizedBox(height: 24)],
                        ),
                      ),
                    );
                  },
                ),
                SquadList(),
                const TeamTacticsView(),
                const IndividualInstructionsView(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _group(String title, List<Player> players, String caption) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr(title), style: AppText.h3),
            const SizedBox(width: 8),
            Expanded(child: Text(caption, style: AppText.caption)),
          ],
        ),
        const SizedBox(height: 12),
        if (players.isEmpty) const Text('—', style: AppText.caption),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final p in players) _dragTarget(p, null, bench: true)],
        ),
      ],
    ),
  );

  Widget _rating(String text, int value) => Expanded(
    child: Column(
      children: [
        ValueBadge(value, size: 40),
        const SizedBox(height: 6),
        Text(tr(text), style: AppText.overline.copyWith(fontSize: 10)),
      ],
    ),
  );

  Widget _pitch(Club c) => AspectRatio(
    aspectRatio: 0.8,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            const Positioned.fill(child: CustomPaint(painter: FootballPitchPainter(vertical: true))),
            for (final slot in c.tactics.formation.slots)
              if (slot.index < c.startingXI.length)
                Positioned(
                  key: ValueKey('slot_${slot.index}'),
                  left: (slot.x * box.maxWidth - 37).clamp(3, box.maxWidth - 77),
                  top: (slot.y * box.maxHeight - 33).clamp(3, box.maxHeight - 69),
                  child: _dragTarget(c.startingXI[slot.index], slot.defaultPosition),
                ),
          ],
        ),
      ),
    ),
  );

  /// Current slot, fit and the player's best positions (no need to open
  /// the full profile while picking a line-up).
  Widget _fitSummary(Player p, Club club) {
    final slot = club.startingLineupIds.indexOf(p.id);
    final pos = slot >= 0 ? club.slotPosition(slot) : null;
    final best = p.bestPositions.where((x) => x != PlayerPosition.gk || p.mainPosition.isGoalkeeper).take(5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pos != null)
          Row(
            children: [
              Icon(Icons.place_outlined, size: 16, color: fitColor(p.fitFor(pos))),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  trf('Hozir: {0} · {1} · OVR {2}', [pos.code, p.fitFor(pos).label, p.getEffectiveOVR(pos)]),
                  style: AppText.small.copyWith(color: fitColor(p.fitFor(pos)), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        Text(tr('Mos pozitsiyalar'), style: AppText.caption),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final x in best)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fitColor(p.fitFor(x)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: fitColor(p.fitFor(x)).withValues(alpha: 0.5)),
                ),
                child: Text(
                  '${x.code}  ${p.getEffectiveOVR(x)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fitColor(p.fitFor(x))),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _beginDrag(Player p) {
    _startDrag();
    setState(() => _dragging = p);
  }

  void _finishDrag() {
    _endDrag();
    if (mounted) setState(() => _dragging = null);
  }

  Widget _dragTarget(Player p, PlayerPosition? pos, {bool bench = false}) => DragTarget<String>(
    onWillAcceptWithDetails: (d) => d.data != p.id && !_isOut(p.id),
    onAcceptWithDetails: (d) => _swap(d.data, p.id),
    builder: (context, candidates, rejected) {
      final base = _node(p, pos, bench: bench, selected: candidates.isNotEmpty);
      final dragged = _dragging;
      // While dragging, each pitch slot previews the dragged player's
      // rating and fit there: green = his position, amber = close, red = foreign.
      final node = dragged != null && pos != null && dragged != p
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                base,
                Positioned(
                  top: -12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: fitColor(dragged.fitFor(pos)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: candidates.isNotEmpty ? 2 : 1),
                      ),
                      child: Text(
                        '${pos.code} ${dragged.getEffectiveOVR(pos)}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : base;
      final feedback = Material(
        color: Colors.transparent,
        child: _node(p, pos, bench: bench, selected: true),
      );
      final child = GestureDetector(onTap: () => _menu(p), child: _marked(node, p.id));
      if (_isOut(p.id)) return Opacity(opacity: 0.45, child: _marked(base, p.id));
      if (MediaQuery.sizeOf(context).width >= 700) {
        return Draggable<String>(
          onDragStarted: () => _beginDrag(p),
          onDragUpdate: (d) => _dragPointer = d.globalPosition,
          onDragEnd: (_) => _finishDrag(),
          data: p.id,
          feedback: feedback,
          childWhenDragging: Opacity(opacity: 0.3, child: node),
          child: child,
        );
      }
      return LongPressDraggable<String>(
        onDragStarted: () => _beginDrag(p),
        onDragUpdate: (d) => _dragPointer = d.globalPosition,
        onDragEnd: (_) => _finishDrag(),
        data: p.id,
        delay: const Duration(milliseconds: 180),
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.3, child: node),
        child: child,
      );
    },
  );

  /// Substitution badge: green ↑ (came on) or red ↓ (went off) with minute.
  Widget _marked(Widget node, String id) {
    final mark = widget.subMarks?.call()[id];
    if (mark == null) return node;
    final (on, minute) = mark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        node,
        Positioned(
          left: -6,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: on ? AppColors.win : AppColors.live,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Text(
              "${on ? '↑' : '↓'} $minute'",
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }

  Widget _node(Player p, PlayerPosition? pos, {bool bench = false, bool selected = false}) {
    final ovr = p.getEffectiveOVR(pos);
    final fit = pos == null ? PositionFit.natural : p.fitFor(pos);
    final club = game.userClub;
    return Container(
      key: ValueKey('tactical_${p.id}'),
      width: bench ? 96 : 74,
      padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppColors.primary : (bench ? AppColors.line : Colors.white),
          width: selected ? 2 : 1,
        ),
        boxShadow: bench
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaceAvatar(config: p.face, size: 22, shirt: club.primaryColor, circle: true),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.attribute(ovr),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$ovr',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            p.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                pos?.code ?? p.mainPosition.code,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: fit == PositionFit.natural || fit == PositionFit.alternative
                      ? AppColors.ink3
                      : fitColor(fit),
                ),
              ),
              if (!p.isAvailable) ...[
                const SizedBox(width: 3),
                Icon(p.isInjured ? Icons.local_hospital_rounded : Icons.block_rounded, size: 10, color: AppColors.live),
              ],
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: p.currentStamina / 100,
              minHeight: 3,
              color: p.currentStamina > 75
                  ? AppColors.win
                  : p.currentStamina > 55
                  ? AppColors.warning
                  : AppColors.loss,
              backgroundColor: AppColors.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}
