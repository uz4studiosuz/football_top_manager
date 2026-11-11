import 'package:flutter/material.dart';
import '../models/player.dart';
import '../models/club.dart';
import '../ui/face_avatar.dart';
import '../services/game_state.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';
import 'player_creator_screen.dart';
import '../l10n/l10n.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tr('Futbolchilar'))),
    body: PageWidth(
      maxWidth: 1000,
      child: const SquadList(),
    ),
  );
}

/// Squad list grouped by line with filters and sorting (no scaffold, so it
/// can live inside the Jamoa hub).
class SquadList extends StatefulWidget {
  const SquadList({super.key});
  @override
  State<SquadList> createState() => _SquadListState();
}

class _SquadListState extends State<SquadList> {
  String query = '';
  int filter = 0;
  String sort = 'OVR';
  static const filters = ['Hammasi', 'Asosiy', 'Zaxira', 'Rezerv', 'Jarohat'];
  static Map<PositionCategory, String> get groupNames => {
    PositionCategory.goalkeeper: tr('Darvozabonlar'),
    PositionCategory.defense: tr('Himoyachilar'),
    PositionCategory.midfield: tr('Yarim himoyachilar'),
    PositionCategory.attack: tr('Hujumchilar'),
  };

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette tokens when appearance changes.
    final game = GameState();
    return ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          if (!game.isInitialized) return const SizedBox();
          final club = game.userClub;
          bool include(Player p) => switch (filter) {
            1 => club.startingLineupIds.contains(p.id),
            2 => club.benchIds.contains(p.id),
            3 => club.reserves.contains(p),
            4 => !p.isAvailable,
            _ => true,
          };
          int compare(Player a, Player b) => switch (sort) {
            'Reyting' => (b.averageRating ?? 0).compareTo(a.averageRating ?? 0),
            'Yosh' => a.age.compareTo(b.age),
            'Qiymat' => b.marketValue.compareTo(a.marketValue),
            'Raqam' => a.number.compareTo(b.number),
            _ => b.ovr.compareTo(a.ovr),
          };
          final players = club.squad.where((p) => include(p) && p.name.toLowerCase().contains(query.toLowerCase())).toList()..sort(compare);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: StatTile('${club.squad.length}', tr('Futbolchi'))),
                    Expanded(child: StatTile(club.averageAge.toStringAsFixed(1), tr('O‘rtacha yosh'))),
                    Expanded(child: StatTile(formatMoney(club.squadValue), 'Qiymati')),
                    Expanded(child: StatTile(formatMoney(club.totalWeeklyWages), tr('Maosh/hafta'))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: AppColors.primarySoft,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const PlayerCreatorScreen()),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Futbolchi yaratish'), style: AppText.bodyStrong),
                          Text(tr('Ism, yuz, pozitsiya, uslub va 26 atributni noldan sozlang'), style: AppText.caption),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PillTabs(labels: [for (final f in filters) tr(f)], index: filter, onChanged: (i) => setState(() => filter = i)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: tr('Saralash'),
                    icon: const Icon(Icons.sort_rounded),
                    initialValue: sort,
                    onSelected: (v) => setState(() => sort = v),
                    itemBuilder: (_) => [
                      for (final s in ['OVR', 'Reyting', 'Yosh', 'Qiymat', 'Raqam'])
                        PopupMenuItem(value: s, child: Text(tr(s))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => query = v.trim()),
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search, size: 20), hintText: tr('Futbolchi qidirish')),
              ),
              const SizedBox(height: 12),
              if (players.isEmpty)
                AppCard(child: EmptyState(icon: Icons.person_off_outlined, text: tr('Bu bo‘limda futbolchi yo‘q'))),
              if (MediaQuery.sizeOf(context).width >= 1100)
                _SquadTable(players: players, club: club)
              else
              for (final cat in PositionCategory.values.reversed)
                if (players.any((p) => p.mainPosition.category == cat))
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SectionHeader(groupNames[cat]!),
                        ),
                        for (final p in players.where((p) => p.mainPosition.category == cat))
                          PlayerTile(
                            player: p,
                            club: club,
                            subtitle: _subtitle(club.startingLineupIds.contains(p.id), club.benchIds.contains(p.id), p),
                            onTap: () => PlayerDetailView.show(context, player: p, club: club),
                            trailing: p.id.startsWith('own_') ? PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => PlayerCreatorScreen(player: p)));
                                } else {
                                  final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                                    title: Text(tr('Futbolchini o‘chirish?')),
                                    content: Text(p.name),
                                    actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Bekor'))),
                                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('O‘chirish')))],
                                  ));
                                  if (confirmed == true && !game.deleteCreatedPlayer(p) && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('O‘chirish imkoni yo‘q'))));
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(value: 'edit', child: Text(tr('Tahrirlash'))),
                                PopupMenuItem(value: 'delete', child: Text(tr('O‘chirish'))),
                              ],
                            ) : null,
                          ),
                      ],
                    ),
                  ),
            ],
          );
        },
    );
  }

  String _subtitle(bool starter, bool bench, Player p) {
    final role = starter ? tr('Asosiy') : bench ? tr('Zaxira') : tr('Rezerv');
    if (p.isInjured) return trf('{0} · jarohat ({1} tur)', [role, p.injuryRounds]);
    if (p.isSuspended) return '$role · diskvalifikatsiya';
    return '$role · ${p.age} yosh · ${p.currentStamina}% · ${p.contract.contractYears} yil';
  }
}

class _SquadTable extends StatelessWidget {
  final List<Player> players;
  final Club club;
  const _SquadTable({required this.players, required this.club});
  @override
  Widget build(BuildContext context) {
    Widget cell(String text, double width, {Color? color, bool strong = false}) => SizedBox(width: width,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
        style: (strong ? AppText.number : AppText.small).copyWith(color: color ?? AppColors.ink2)));
    return AppCard(padding: EdgeInsets.zero, child: Column(children: [
      Container(color: AppColors.surfaceAlt, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Row(children: [
        cell('#', 30), const SizedBox(width: 42), Expanded(flex: 3, child: Text(tr('Futbolchi'), style: AppText.overline)),
        cell(tr('Pozitsiya'), 80), cell(tr('Yosh'), 42), cell(tr('Holat'), 70), cell('OVR', 50), cell(tr('Reyting'), 65),
        Expanded(flex: 2, child: Text(tr('Individual ko‘rsatma'), style: AppText.caption)), cell(tr('Qiymat'), 95),
      ])),
      for (final (i, p) in players.indexed) Material(
        color: i.isEven ? AppColors.surface : AppColors.surfaceAlt,
        child: InkWell(onTap: () => PlayerDetailView.show(context, player: p, club: club), child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            cell('${p.number}', 30),
            FaceAvatar(config: p.face, size: 30, shirt: club.primaryColor, circle: true), const SizedBox(width: 12),
            Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong.copyWith(fontSize: 13)),
              const SizedBox(height: 3),
              Text(club.startingLineupIds.contains(p.id) ? tr('Asosiy') : club.benchIds.contains(p.id) ? tr('Zaxira') : tr('Rezerv'), style: AppText.caption),
            ])),
            SizedBox(width: 80, child: Center(child: PositionChip(p.mainPosition.code))),
            cell('${p.age}', 42),
            cell(p.isAvailable ? '${p.currentStamina}%' : tr('Jarohat'), 70, color: !p.isAvailable ? AppColors.loss : p.currentStamina > 70 ? AppColors.teal : AppColors.warning),
            cell('${p.ovr}', 50, strong: true, color: AppColors.attribute(p.ovr)),
            SizedBox(width: 65, child: Center(child: RatingBadge(p.averageRating))),
            Expanded(flex: 2, child: Text(p.instruction.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.small)),
            cell(formatMoney(p.marketValue), 95),
          ]),
        )),
      ),
    ]));
  }
}
