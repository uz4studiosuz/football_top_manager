import 'package:flutter/material.dart';
import '../../models/club.dart';
import '../../models/player.dart';
import '../../services/game_state.dart';
import '../../ui/match_widgets.dart';
import '../../ui/team_widgets.dart';
import '../../ui/widgets.dart';
import '../match_report_screen.dart';
import 'player_detail_view.dart';

/// Pre-match scouting: head-to-head comparison, rival line-up and form.
class OpponentSquadSheet extends StatelessWidget {
  final Club opponentClub;
  const OpponentSquadSheet({super.key, required this.opponentClub});
  static void show(BuildContext context, {required Club opponentClub}) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => OpponentSquadSheet(opponentClub: opponentClub)),
    );
  }

  double average(Club c, int Function(Player) value) =>
      c.startingXI.fold<int>(0, (sum, p) => sum + value(p)) / c.startingXI.length;

  @override
  Widget build(BuildContext context) {
    final game = GameState(), user = game.userClub, rival = opponentClub;
    final colors = teamColors(user, rival);
    final star = List<Player>.of(rival.startingXI)..sort((a, b) => b.getMatchOVR().compareTo(a.getMatchOVR()));
    final userStanding = game.standingOf(user.id), rivalStanding = game.standingOf(rival.id);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Raqib tahlili'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(150),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      Expanded(child: ClubHeading(club: user, size: 48, caption: '${game.positionOf(user.id)}-o‘rin · ${userStanding.points} o‘')),
                      const Text('vs', style: TextStyle(fontSize: 18, color: AppColors.ink3, fontWeight: FontWeight.w600)),
                      Expanded(child: ClubHeading(club: rival, size: 48, caption: '${game.positionOf(rival.id)}-o‘rin · ${rivalStanding.points} o‘')),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Solishtirish'),
                    Tab(text: 'Tarkib'),
                    Tab(text: 'Forma'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Jamoalar kuchi', icon: Icons.compare_arrows_rounded),
                      for (final row in <(String, num, num)>[
                        ('Match OVR', user.teamOVR, rival.teamOVR),
                        ('Hujum', user.attackRating, rival.attackRating),
                        ('Yarim himoya', user.midfieldRating, rival.midfieldRating),
                        ('Himoya va GK', user.defenseRating, rival.defenseRating),
                        ('Tarkib chuqurligi', user.squadDepthRating, rival.squadDepthRating),
                        ('O‘rtacha tezlik', average(user, (p) => p.stats.pace).round(), average(rival, (p) => p.stats.pace).round()),
                        ('Jismoniy tayyorlik', average(user, (p) => p.currentStamina).round(), average(rival, (p) => p.currentStamina).round()),
                      ])
                        StatCompareRow(
                          label: row.$1,
                          homeText: '${row.$2}',
                          awayText: '${row.$3}',
                          home: row.$2.toDouble(),
                          away: row.$3.toDouble(),
                          homeColor: colors.$1,
                          awayColor: colors.$2,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Skaut hisoboti', icon: Icons.assignment_outlined),
                      InfoRow('Sxema', '${user.tactics.formation.short}  vs  ${rival.tactics.formation.short}'),
                      InfoRow('O‘rtacha yosh', '${average(user, (p) => p.age).toStringAsFixed(1)}  vs  ${average(rival, (p) => p.age).toStringAsFixed(1)}'),
                      const Divider(height: 22),
                      _report(Icons.psychology_outlined, 'Raqib rejasi', rival.tactics.playstyle.displayName, rival.tactics.playstyle.description),
                      _report(
                        Icons.shield_outlined,
                        'Pressing va himoya',
                        'Chiziq ${rival.tactics.defensiveLine}/5 · pressing ${rival.tactics.pressing}/5',
                        rival.tactics.counterPress
                            ? 'Yo‘qotishdan keyin bosim qiladi. Tez, xavfsiz pas uchun sheriklarni yaqin tuting.'
                            : 'To‘pni qaytargach sxemaga tushadi. Qanotlar va chiziqlar orasidagi bo‘shliqni qidiring.',
                      ),
                      if (star.isNotEmpty)
                        _report(
                          Icons.warning_amber_rounded,
                          'Asosiy xavf',
                          star.first.name,
                          '${star.first.mainPosition.code} · OVR ${star.first.ovr} · Zarba ${star.first.stats.finishing} · Tezlik ${star.first.stats.speed}',
                        ),
                      if (rival.squad.any((p) => !p.isAvailable))
                        _report(
                          Icons.local_hospital_outlined,
                          'O‘ynay olmaydiganlar',
                          rival.squad.where((p) => !p.isAvailable).map((p) => p.shortName).join(', '),
                          'Jarohat yoki diskvalifikatsiya sababli.',
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader('${rival.name} · ${rival.tactics.formation.label}', icon: Icons.sports_soccer),
                      LineupPitch(
                        club: rival,
                        players: rival.startingXI,
                        ratings: {for (final p in rival.squad) p.id: p.averageRating},
                        shirt: colors.$2,
                        onTap: (p) => PlayerDetailView.show(context, player: p, club: rival),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: SectionHeader('Barcha futbolchilar'),
                      ),
                      for (final p in List.of(rival.squad)..sort((a, b) => b.ovr.compareTo(a.ovr)))
                        PlayerTile(
                          player: p,
                          club: rival,
                          onTap: () => PlayerDetailView.show(context, player: p, club: rival),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final c in [user, rival]) ...[
                  AppCard(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              ClubCrestWidget(config: c.crestConfig, size: 22),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.name, style: AppText.h3)),
                              for (final r in game.standingOf(c.id).formGuide) FormChip(r, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (!game.fixturesOf(c.id).any((f) => f.isPlayed))
                          const EmptyState(icon: Icons.event_outlined, text: 'Mavsum hali boshlanmagan.'),
                        for (final f in game.fixturesOf(c.id).where((f) => f.isPlayed).toList().reversed.take(5))
                          FixtureTile(
                            fixture: f,
                            highlightClubId: c.id,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(builder: (_) => MatchReportScreen(fixture: f)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _report(IconData icon, String label, String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: AppText.overline),
              const SizedBox(height: 2),
              Text(title, style: AppText.bodyStrong),
              const SizedBox(height: 2),
              Text(text, style: AppText.small.copyWith(height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );
}
