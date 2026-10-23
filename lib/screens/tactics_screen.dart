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

class TacticsScreen extends StatefulWidget {
  final bool Function(Player, Player)? onSwap;
  final Set<String> unavailable;
  const TacticsScreen({super.key, this.onSwap, this.unavailable = const {}});
  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  final game = GameState();
  final _squadScroll = ScrollController();
  Timer? _dragTimer;
  Offset? _dragPointer;
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

  bool _swap(String a, String b) {
    final club = game.userClub;
    final p = club.playerById(a), q = club.playerById(b);
    if (p == null || q == null || a == b) return false;
    final ok = widget.onSwap?.call(p, q) ?? game.swapPlayer(a, b);
    if (ok) {
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu almashtirishga hozir ruxsat yo‘q. Limit va o‘yindan chiqqan futbolchilarni tekshiring.',
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
                                Text('${p.currentStamina}% tayyor', style: AppText.caption),
                              ],
                            ),
                          ],
                        ),
                      ),
                      ValueBadge(p.ovr, size: 38),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PlayerDetailView.show(context, player: p, club: club);
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('To‘liq profil'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PlayerInstruction>(
                    initialValue: p.instruction,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Individual ko‘rsatma'),
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
                  const SizedBox(height: 16),
                  const Text('Almashtirish uchun futbolchi tanlang', style: AppText.bodyStrong),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final q in club.squad.where((q) => q.id != p.id && !widget.unavailable.contains(q.id)))
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
                                          '${q.mainPosition.code} · ${club.startingLineupIds.contains(q.id) ? 'Asosiy' : club.benchIds.contains(q.id) ? 'Zaxira' : 'Rezerv'}'
                                          '${q.isAvailable ? '' : ' · o‘ynay olmaydi'}',
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
              title: const Text('Jamoa'),
              actions: [
                if (!_inMatch)
                  IconButton(
                    tooltip: 'Futbolchi yaratish',
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const PlayerCreatorScreen()),
                    ),
                  ),
                if (!_inMatch)
                  PopupMenuButton<bool>(
                    tooltip: 'Avto tarkib',
                    onSelected: (byForm) {
                      game.autoPickUserLineup(byForm: byForm);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            byForm
                                ? 'Tarkib forma va jismoniy holat bo‘yicha tanlandi'
                                : 'Eng kuchli va pozitsiyaga mos tarkib tanlandi',
                          ),
                        ),
                      );
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: false,
                        child: ListTile(
                          leading: Icon(Icons.bolt_rounded),
                          title: Text('Eng kuchli tarkib'),
                          subtitle: Text('Pozitsiyaga mos OVR'),
                        ),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: ListTile(
                          leading: Icon(Icons.trending_up_rounded),
                          title: Text('Forma bo‘yicha'),
                          subtitle: Text('Reyting va jismoniy holat'),
                        ),
                      ),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Avto tarkib',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              bottom: const TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: 'Sxema va tarkib'),
                  Tab(text: 'Ro‘yxat'),
                  Tab(text: 'Taktika'),
                  Tab(text: 'Ko‘rsatmalar'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      controller: _squadScroll,
                      padding: const EdgeInsets.all(12),
                      children: [
                        AppCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          child: Row(
                            children: [
                              _rating('JAMOA', club.teamOVR),
                              _rating('HUJUM', club.attackRating),
                              _rating('MARKAZ', club.midfieldRating),
                              _rating('HIMOYA', club.defenseRating),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final f in FormationType.values)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(f.short),
                                    selected: t.formation == f,
                                    showCheckmark: false,
                                    onSelected: (_) => game.updateTactics(t.copyWith(formation: f)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Row(
                          children: [
                            Icon(Icons.drag_indicator, size: 16, color: AppColors.ink3),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ushlab suring: o‘rin almashtirish. Bosing: profil va ko‘rsatma.',
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _pitch(club),
                        const SizedBox(height: 16),
                        _group('Zaxira', club.bench, 'O‘yin kuni zaxirasi · ${club.bench.length}/${Club.matchdayBench}'),
                        const SizedBox(height: 12),
                        _group('Rezerv', club.reserves, 'Tarkibdan tashqari · ${club.reserves.length}'),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                const SquadList(),
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
            Text(title, style: AppText.h3),
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
        Text(text, style: AppText.overline.copyWith(fontSize: 10)),
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

  Widget _dragTarget(Player p, PlayerPosition? pos, {bool bench = false}) => DragTarget<String>(
    onWillAcceptWithDetails: (d) => d.data != p.id && !widget.unavailable.contains(p.id),
    onAcceptWithDetails: (d) => _swap(d.data, p.id),
    builder: (context, candidates, rejected) {
      final node = _node(p, pos, bench: bench, selected: candidates.isNotEmpty);
      final feedback = Material(
        color: Colors.transparent,
        child: _node(p, pos, bench: bench, selected: true),
      );
      final child = GestureDetector(onTap: () => _menu(p), child: node);
      if (widget.unavailable.contains(p.id)) return Opacity(opacity: 0.35, child: node);
      if (MediaQuery.sizeOf(context).width >= 700) {
        return Draggable<String>(
          onDragStarted: _startDrag,
          onDragUpdate: (d) => _dragPointer = d.globalPosition,
          onDragEnd: (_) => _endDrag(),
          data: p.id,
          feedback: feedback,
          childWhenDragging: Opacity(opacity: 0.3, child: node),
          child: child,
        );
      }
      return LongPressDraggable<String>(
        onDragStarted: _startDrag,
        onDragUpdate: (d) => _dragPointer = d.globalPosition,
        onDragEnd: (_) => _endDrag(),
        data: p.id,
        delay: const Duration(milliseconds: 180),
        feedback: feedback,
        childWhenDragging: Opacity(opacity: 0.3, child: node),
        child: child,
      );
    },
  );

  Widget _node(Player p, PlayerPosition? pos, {bool bench = false, bool selected = false}) {
    final ovr = p.getEffectiveOVR(pos);
    final outOfPosition = pos != null && pos != p.mainPosition && !p.altPositions.contains(pos);
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
                  color: outOfPosition ? AppColors.live : AppColors.ink3,
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
