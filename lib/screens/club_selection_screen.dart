import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'custom_club_creator_screen.dart';
import 'main_navigation_screen.dart';
import '../models/manager_profile.dart';
import '../l10n/l10n.dart';

/// Choose a club from any league (or create a new one).
class ClubSelectionScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  const ClubSelectionScreen({super.key, this.managerProfile});
  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  String _league = 'super';
  late List<Club> _clubs = InitialDatabase.getClubs(_league);
  int _selected = 0;

  void _switchLeague(String id) => setState(() {
    _league = id;
    _clubs = InitialDatabase.getClubs(id)..sort((a, b) => b.reputation.compareTo(a.reputation));
    // Big-league seed files list squads only; show each club's real best XI.
    if (id != 'super') {
      for (final c in _clubs) {
        GameState().autoPickLineup(c);
      }
    }
    _selected = 0;
  });
  Club get _club => _clubs[_selected];

  void _start(Club club) {
    GameState().startCareerWithExistingClub(club, managerProfile: widget.managerProfile, league: _league);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  String _expectation(Club c) {
    final ranked = List<Club>.of(_clubs)..sort((a, b) => b.squadDepthRating.compareTo(a.squadDepthRating));
    final rank = ranked.indexOf(c) + 1;
    final info = InitialDatabase.info(_league);
    if (info.tier > 1) {
      return switch (rank) {
        <= 2 => tr('Avtomatik ko‘tarilish'),
        <= 6 => trf('Pley-off (top-{0})', [info.playoffTo]),
        <= 12 => tr('Top-12'),
        _ => info.relegate > 0 ? tr('Ligada qolish') : tr('Top-16'),
      };
    }
    if (_clubs.length > 10) {
      return switch (rank) {
        1 => tr('Chempionlik'),
        <= 4 => tr('Top-4 (Chempionlar ligasi)'),
        <= 7 => tr('Top-6 (Yevrokubok)'),
        <= 12 => tr('Top-10'),
        _ => tr('Ligada qolish'),
      };
    }
    return switch (rank) {
      1 => tr('Chempionlik'),
      2 || 3 => tr('Top-3'),
      4 || 5 => tr('Top-4'),
      _ => tr('Top-6'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final club = _club;
    final stars = List.of(club.squad)..sort((a, b) => b.ovr.compareTo(a.ovr));
    return Scaffold(
      appBar: AppBar(title: Text(tr('Klubni tanlang'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          PillTabs(
            labels: [
              for (final l in InitialDatabase.leagues)
                '${l.name} · ${InitialDatabase.getClubs(l.id).length} klub',
            ],
            index: InitialDatabase.leagues.indexWhere((l) => l.id == _league),
            onChanged: (i) => _switchLeague(InitialDatabase.leagues[i].id),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _clubs.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == _clubs.length) {
                  return _clubChip(
                    selected: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => CustomClubCreatorScreen(managerProfile: widget.managerProfile, league: _league),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 38, color: AppColors.primary),
                        SizedBox(height: 8),
                        Text(tr('Yangi klub'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                  );
                }
                final c = _clubs[i];
                return _clubChip(
                  selected: i == _selected,
                  onTap: () => setState(() => _selected = i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClubCrestWidget(config: c.crestConfig, size: 50),
                      const SizedBox(height: 6),
                      Text(c.shortName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                ClubCrestWidget(config: club.crestConfig, size: 104),
                const SizedBox(height: 10),
                Text(club.name, style: AppText.h1),
                const SizedBox(height: 2),
                Text('${club.nickname} · ${club.city} · ${club.founded}', style: AppText.caption),
                const SizedBox(height: 4),
                Text(
                  trf('{0} · {1}K muxlis', [club.stadiumName, (club.stadiumCapacity / 1000).toStringAsFixed(0)]),
                  style: AppText.caption,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _metric('OVR', ValueBadge(club.teamOVR, size: 40)),
                    _metric(tr('HUJUM'), ValueBadge(club.attackRating, size: 40, filled: false)),
                    _metric(tr('MARKAZ'), ValueBadge(club.midfieldRating, size: 40, filled: false)),
                    _metric(tr('HIMOYA'), ValueBadge(club.defenseRating, size: 40, filled: false)),
                  ],
                ),
                const Divider(height: 28),
                InfoRow(tr('Transfer byudjeti'), club.formattedTransferBudget),
                InfoRow(tr('Maosh limiti'), club.formattedWageBudget),
                InfoRow(tr('Tarkib'), '${club.squad.length} futbolchi · qiymati ${formatMoney(club.squadValue)}'),
                InfoRow(tr('Kengash kutmoqda'), _expectation(club)),
                InfoRow(tr('O‘yin uslubi'), club.tactics.playstyle.displayName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SectionHeader(tr('Asosiy yulduzlar'), icon: Icons.star_outline_rounded),
                ),
                for (final p in stars.take(5)) PlayerTile(player: p, club: club, showRating: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _start(club),
              icon: const Icon(Icons.play_arrow_rounded),
              label: FittedBox(child: Text(trf('{0}NI BOSHQARISH', [club.name.toUpperCase()]))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _clubChip({required bool selected, required VoidCallback onTap, required Widget child}) => SizedBox(
    width: 92,
    child: Material(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: child,
      ),
    ),
  );

  Widget _metric(String label, Widget value) => Expanded(
    child: Column(
      children: [
        value,
        const SizedBox(height: 6),
        Text(label, style: AppText.overline.copyWith(fontSize: 10)),
      ],
    ),
  );
}
