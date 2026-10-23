import 'package:flutter/material.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';

class SquadScreen extends StatelessWidget {
  const SquadScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Futbolchilar')),
    body: const SquadList(),
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
  int filter = 0;
  String sort = 'OVR';
  static const filters = ['Hammasi', 'Asosiy', 'Zaxira', 'Rezerv', 'Jarohat'];
  static const groupNames = {
    PositionCategory.goalkeeper: 'Darvozabonlar',
    PositionCategory.defense: 'Himoyachilar',
    PositionCategory.midfield: 'Yarim himoyachilar',
    PositionCategory.attack: 'Hujumchilar',
  };

  @override
  Widget build(BuildContext context) {
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
          final players = club.squad.where(include).toList()..sort(compare);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              AppCard(
                child: Row(
                  children: [
                    Expanded(child: StatTile('${club.squad.length}', 'Futbolchi')),
                    Expanded(child: StatTile(club.averageAge.toStringAsFixed(1), 'O‘rtacha yosh')),
                    Expanded(child: StatTile(formatMoney(club.squadValue), 'Qiymati')),
                    Expanded(child: StatTile(formatMoney(club.totalWeeklyWages), 'Maosh/hafta')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PillTabs(labels: filters, index: filter, onChanged: (i) => setState(() => filter = i)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Saralash',
                    icon: const Icon(Icons.sort_rounded),
                    initialValue: sort,
                    onSelected: (v) => setState(() => sort = v),
                    itemBuilder: (_) => [
                      for (final s in ['OVR', 'Reyting', 'Yosh', 'Qiymat', 'Raqam'])
                        PopupMenuItem(value: s, child: Text(s)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (players.isEmpty)
                const AppCard(child: EmptyState(icon: Icons.person_off_outlined, text: 'Bu bo‘limda futbolchi yo‘q')),
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
    final role = starter ? 'Asosiy' : bench ? 'Zaxira' : 'Rezerv';
    if (p.isInjured) return '$role · jarohat (${p.injuryRounds} tur)';
    if (p.isSuspended) return '$role · diskvalifikatsiya';
    return '$role · ${p.age} yosh · ${p.currentStamina}% · ${p.contract.contractYears} yil';
  }
}
