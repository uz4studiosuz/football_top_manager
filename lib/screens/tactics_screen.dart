import 'dart:async';
import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/football_pitch.dart';
import 'widgets/player_detail_view.dart';

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
          (_squadScroll.offset + step).clamp(
            0.0,
            _squadScroll.position.maxScrollExtent,
          ),
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
    final p = club.squad.where((p) => p.id == a).firstOrNull,
        q = club.squad.where((p) => p.id == b).firstOrNull;
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: StatefulBuilder(
            builder: (ctx, update) => Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaceAvatar(
                        config: p.face,
                        size: 54,
                        shirt: game.userClub.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${p.mainPosition.code} · OVR ${p.ovr} · ${p.currentStamina}% tayyor',
                              style: const TextStyle(
                                color: Color(0xFF637184),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      PlayerDetailView.show(
                        context,
                        player: p,
                        club: game.userClub,
                      );
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text('To‘liq profil'),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<PlayerInstruction>(
                    initialValue: p.instruction,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Individual ko‘rsatma',
                      border: OutlineInputBorder(),
                    ),
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
                  const SizedBox(height: 8),
                  Text(
                    p.instruction.description,
                    style: const TextStyle(
                      color: Color(0xFF637184),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Almashtirish uchun futbolchi tanlang',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final q in game.userClub.squad.where(
                          (q) =>
                              q.id != p.id &&
                              !widget.unavailable.contains(q.id),
                        ))
                          Material(
                            color: Colors.transparent,
                            child: ListTile(
                              leading: FaceAvatar(
                                config: q.face,
                                size: 36,
                                shirt: game.userClub.primaryColor,
                              ),
                              title: Text(
                                q.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${q.mainPosition.code} · ${game.userClub.startingLineupIds.contains(q.id) ? 'Asosiy' : 'Zaxira'}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                '${q.ovr}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () {
                                if (_swap(p.id, q.id)) Navigator.pop(ctx);
                              },
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
    final club = game.userClub, t = club.tactics;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Taktika va Tarkib'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sxema va tarkib'),
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        _rating('JAMOA', club.teamOVR),
                        _rating('HUJUM', club.attackRating),
                        _rating('MARKAZ', club.midfieldRating),
                        _rating('HIMOYA', club.defenseRating),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in FormationType.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(f.label),
                                selected: t.formation == f,
                                onSelected: (_) {
                                  game.updateTactics(t.copyWith(formation: f));
                                  setState(() {});
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          size: 16,
                          color: Color(0xFF637184),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ushlab suring: o‘rin almashtirish. Bosing: profil va ko‘rsatma.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF637184),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _pitch(club),
                    const SizedBox(height: 24),
                    Text(
                      'Zaxira · ${club.bench.length}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final p in club.bench)
                          _dragTarget(p, null, bench: true),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'O‘yin uslubi',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (final style in TeamPlaystyle.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: t.playstyle == style
                              ? const Color(0xFFE7F0FF)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: ListTile(
                            leading: Icon(
                              style.icon,
                              color: const Color(0xFF1769E0),
                            ),
                            title: Text(
                              style.displayName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              style.description,
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '${game.managerProfile.ratingFor(style)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1769E0),
                              ),
                            ),
                            onTap: () {
                              game.updateTactics(t.copyWith(playstyle: style));
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _slider(
                      'Himoya chizig‘i',
                      t.defensiveLine,
                      (v) => t.copyWith(defensiveLine: v),
                    ),
                    _slider(
                      'Hujum intensivligi',
                      t.attackingIntensity,
                      (v) => t.copyWith(attackingIntensity: v),
                    ),
                    _slider('Temp', t.tempo, (v) => t.copyWith(tempo: v)),
                    _slider(
                      'Qanot kengligi',
                      t.width,
                      (v) => t.copyWith(width: v),
                    ),
                    Material(
                      color: Colors.white,
                      child: SwitchListTile(
                        title: const Text('Yo‘qotishdan keyin pressing'),
                        subtitle: const Text('Ko‘proq bosim, ko‘proq charchoq'),
                        value: t.counterPress,
                        onChanged: (v) {
                          game.updateTactics(t.copyWith(counterPress: v));
                          setState(() {});
                        },
                      ),
                    ),
                    Material(
                      color: Colors.white,
                      child: SwitchListTile(
                        title: const Text('Himoyadan qisqa pas'),
                        value: t.playOutFromBack,
                        onChanged: (v) {
                          game.updateTactics(t.copyWith(playOutFromBack: v));
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rating(String text, int value) => Expanded(
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              color: Color(0xFF1769E0),
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            text,
            style: const TextStyle(fontSize: 9, color: Color(0xFF637184)),
          ),
        ],
      ),
    ),
  );
  Widget _slider(String label, int value, TeamTactics Function(int) create) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label · $value / 5',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: value.toDouble(),
              label: '$value',
              onChanged: (v) {
                game.updateTactics(create(v.round()));
                setState(() {});
              },
            ),
          ],
        ),
      );
  Widget _pitch(Club c) => AspectRatio(
    aspectRatio: 0.78,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ColoredBox(
        color: const Color(0xFF15563E),
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              const Positioned.fill(
                child: CustomPaint(painter: FootballPitchPainter()),
              ),
              for (final slot in c.tactics.formation.slots)
                if (slot.index < c.startingXI.length)
                  Positioned(
                    key: ValueKey('slot_${slot.index}'),
                    left: (slot.x * box.maxWidth - 37).clamp(
                      3,
                      box.maxWidth - 77,
                    ),
                    top: (slot.y * box.maxHeight - 29).clamp(
                      3,
                      box.maxHeight - 61,
                    ),
                    child: _dragTarget(
                      c.startingXI[slot.index],
                      slot.defaultPosition,
                    ),
                  ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _dragTarget(Player p, PlayerPosition? pos, {bool bench = false}) =>
      DragTarget<String>(
        onWillAcceptWithDetails: (d) =>
            d.data != p.id && !widget.unavailable.contains(p.id),
        onAcceptWithDetails: (d) => _swap(d.data, p.id),
        builder: (context, candidates, rejected) {
          final node = _node(
            p,
            pos,
            bench: bench,
            selected: candidates.isNotEmpty,
          );
          final feedback = Material(
            color: Colors.transparent,
            child: _node(p, pos, bench: bench, selected: true),
          );
          final child = GestureDetector(onTap: () => _menu(p), child: node);
          if (widget.unavailable.contains(p.id)) {
            return Opacity(opacity: 0.35, child: node);
          }
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
  Widget _node(
    Player p,
    PlayerPosition? pos, {
    bool bench = false,
    bool selected = false,
  }) => Container(
    key: ValueKey('tactical_${p.id}'),
    width: bench ? 100 : 74,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFFE7F0FF) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: selected ? const Color(0xFF1769E0) : const Color(0xFFD9E3EE),
        width: selected ? 2 : 1,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              pos?.code ?? p.mainPosition.code,
              style: const TextStyle(fontSize: 9, color: Color(0xFF637184)),
            ),
            const SizedBox(width: 4),
            Text(
              '${p.getEffectiveOVR(pos)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1769E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          p.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: Color(0xFF192B42)),
        ),
        if (bench)
          Text(
            '${p.currentStamina}%',
            style: const TextStyle(fontSize: 9, color: Color(0xFF637184)),
          ),
      ],
    ),
  );
}
