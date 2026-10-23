import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';
import '../../ui/football_pitch.dart';
import 'player_detail_view.dart';

class OpponentSquadSheet extends StatelessWidget {
  final Club opponentClub;
  const OpponentSquadSheet({super.key, required this.opponentClub});
  static void show(BuildContext context, {required Club opponentClub}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OpponentSquadSheet(opponentClub: opponentClub),
      ),
    );
  }

  static const blue = Color(0xFF1769E0),
      ink = Color(0xFF192B42),
      muted = Color(0xFF637184);
  double average(Club c, int Function(Player) value) =>
      c.startingXI.fold<int>(0, (sum, p) => sum + value(p)) /
      c.startingXI.length;
  @override
  Widget build(BuildContext context) {
    final game = GameState(), user = GameState().userClub, rival = opponentClub;
    final star = List<Player>.of(rival.startingXI)
      ..sort((a, b) => b.getMatchOVR().compareTo(a.getMatchOVR()));
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Raqib tahlili'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Solishtirish'),
              Tab(text: 'Tarkib'),
              Tab(text: 'Forma'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  _heading(user, true),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      'vs',
                      style: TextStyle(color: muted, fontSize: 18),
                    ),
                  ),
                  _heading(rival, false),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const Text(
                        'Jamoalar kuchi',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Har bir chiziq bir xil 0–100 shkalada. Farq sizning jamoangizga nisbatan ko‘rsatilgan.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _compare('Match OVR', user.teamOVR, rival.teamOVR),
                      _compare('Hujum', user.attackRating, rival.attackRating),
                      _compare(
                        'Yarim himoya',
                        user.midfieldRating,
                        rival.midfieldRating,
                      ),
                      _compare(
                        'Himoya va GK',
                        user.defenseRating,
                        rival.defenseRating,
                      ),
                      _compare(
                        'O‘rtacha tezlik',
                        average(user, (p) => p.stats.pace).round(),
                        average(rival, (p) => p.stats.pace).round(),
                      ),
                      _compare(
                        'Jismoniy tayyorlik',
                        average(user, (p) => p.currentStamina).round(),
                        average(rival, (p) => p.currentStamina).round(),
                      ),
                      const SizedBox(height: 12),
                      _pair(
                        'Sxema',
                        user.tactics.formation.label.split(' ').first,
                        rival.tactics.formation.label.split(' ').first,
                      ),
                      _pair(
                        'Zaxira',
                        user.bench.length.toString(),
                        rival.bench.length.toString(),
                      ),
                      _pair(
                        'O‘rtacha yosh',
                        average(user, (p) => p.age).toStringAsFixed(1),
                        average(rival, (p) => p.age).toStringAsFixed(1),
                      ),
                      const SizedBox(height: 24),
                      _report(
                        'Raqib rejasi',
                        rival.tactics.playstyle.displayName,
                        rival.tactics.playstyle.description,
                      ),
                      const SizedBox(height: 12),
                      _report(
                        'Pressing va himoya',
                        'Chiziq ${rival.tactics.defensiveLine}/5 · temp ${rival.tactics.tempo}/5',
                        rival.tactics.counterPress
                            ? 'Yo‘qotishdan keyin bosim qiladi. Tez, xavfsiz pas uchun sheriklarni yaqin tuting.'
                            : 'To‘pni qaytargach sxemaga tushadi. Qanotlar va chiziqlar orasidagi bo‘shliqni qidiring.',
                      ),
                      const SizedBox(height: 12),
                      if (star.isNotEmpty)
                        _report(
                          'Asosiy xavf',
                          star.first.name,
                          '${star.first.mainPosition.code} · OVR ${star.first.ovr} · Finishing ${star.first.stats.finishing} · Speed ${star.first.stats.speed}',
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        '${rival.name} · ${rival.tactics.formation.label}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: AspectRatio(
                            aspectRatio: 0.74,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ColoredBox(
                                color: const Color(0xFF15563E),
                                child: LayoutBuilder(
                                  builder: (context, box) => Stack(
                                    children: [
                                      const Positioned.fill(
                                        child: CustomPaint(
                                          painter: FootballPitchPainter(),
                                        ),
                                      ),
                                      for (final slot
                                          in rival.tactics.formation.slots)
                                        if (slot.index <
                                            rival.startingXI.length)
                                          Positioned(
                                            left: (slot.x * box.maxWidth - 34)
                                                .clamp(3, box.maxWidth - 71),
                                            top: (slot.y * box.maxHeight - 25)
                                                .clamp(3, box.maxHeight - 53),
                                            child: InkWell(
                                              onTap: () =>
                                                  PlayerDetailView.show(
                                                    context,
                                                    player: rival
                                                        .startingXI[slot.index],
                                                    club: rival,
                                                  ),
                                              child: Container(
                                                width: 68,
                                                padding: const EdgeInsets.all(
                                                  5,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      '${slot.defaultPosition.code} ${rival.startingXI[slot.index].getEffectiveOVR(slot.defaultPosition)}',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: blue,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      rival
                                                          .startingXI[slot
                                                              .index]
                                                          .shortName,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Barcha futbolchilar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final p in rival.squad)
                        Material(
                          color: Colors.white,
                          child: ListTile(
                            leading: FaceAvatar(
                              config: p.face,
                              size: 38,
                              shirt: rival.primaryColor,
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${p.mainPosition.code} · ${p.currentStamina}% tayyor',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Text(
                              '${p.ovr}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: blue,
                              ),
                            ),
                            onTap: () => PlayerDetailView.show(
                              context,
                              player: p,
                              club: rival,
                            ),
                          ),
                        ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      for (final c in [user, rival]) ...[
                        _report(
                          'Oxirgi uchrashuvlar',
                          c.name,
                          game.sortedStandings
                                  .firstWhere((s) => s.clubId == c.id)
                                  .formGuide
                                  .isEmpty
                              ? 'Mavsum hali boshlanmagan.'
                              : game.sortedStandings
                                    .firstWhere((s) => s.clubId == c.id)
                                    .formGuide
                                    .join('  '),
                        ),
                        const SizedBox(height: 12),
                        for (final f
                            in game.fixtures
                                .where(
                                  (f) =>
                                      f.isPlayed &&
                                      (f.homeClubId == c.id ||
                                          f.awayClubId == c.id),
                                )
                                .toList()
                                .reversed
                                .take(5))
                          Material(
                            color: Colors.white,
                            child: ListTile(
                              title: Text(
                                '${game.getClubById(f.homeClubId)!.shortName} – ${game.getClubById(f.awayClubId)!.shortName}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: Text(
                                '${f.round}-tur · xG ${f.homeXG.toStringAsFixed(2)} – ${f.awayXG.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                f.scoreDisplay,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(Club c, bool own) => Expanded(
    child: Row(
      children: [
        ClubCrestWidget(config: c.crestConfig, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.shortName,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: own ? blue : ink,
                ),
              ),
              Text(
                'OVR ${c.teamOVR}',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _compare(String label, int a, int b) {
    final diff = a - b;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$a',
                style: const TextStyle(
                  color: blue,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      diff == 0
                          ? 'Teng'
                          : diff > 0
                          ? 'Siz +$diff'
                          : 'Raqib +${-diff}',
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              Text(
                '$b',
                style: const TextStyle(
                  color: ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: a / 100,
            minHeight: 4,
            backgroundColor: const Color(0xFFE6ECF4),
            color: blue,
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: b / 100,
            minHeight: 4,
            backgroundColor: const Color(0xFFE6ECF4),
            color: const Color(0xFF65768C),
          ),
        ],
      ),
    );
  }

  Widget _pair(String label, String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            a,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: blue,
            ),
          ),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: muted),
          ),
        ),
        Expanded(
          child: Text(
            b,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );
  Widget _report(String label, String title, String text) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: muted)),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
        ),
      ],
    ),
  );
}
