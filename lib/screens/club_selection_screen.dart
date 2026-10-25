import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../services/game_state.dart';
import '../ui/team_widgets.dart';
import '../ui/league_picker.dart';
import '../ui/widgets.dart';
import 'custom_club_creator_screen.dart';
import 'main_navigation_screen.dart';
import 'save_slots_screen.dart';
import '../models/manager_profile.dart';
import '../l10n/l10n.dart';
import '../services/coin_wallet.dart';
import '../ui/coin.dart';

/// Choose a club from any league (or create a new one).
class ClubSelectionScreen extends StatefulWidget {
  final ManagerProfile? managerProfile;
  const ClubSelectionScreen({super.key, this.managerProfile});
  @override
  State<ClubSelectionScreen> createState() => _ClubSelectionScreenState();
}

class _ClubSelectionScreenState extends State<ClubSelectionScreen> {
  String _league = 'epl';
  late List<Club> _clubs = _load(_league);

  /// Clubs strongest first, with each club's real best XI picked.
  static List<Club> _load(String id) {
    final clubs = InitialDatabase.getClubs(id);
    for (final c in clubs) {
      GameState().autoPickLineup(c);
    }
    return clubs..sort((a, b) => b.teamOVR.compareTo(a.teamOVR));
  }
  int _selected = 0;

  void _switchLeague(String id) => setState(() {
    _league = id;
    _clubs = _load(id);
    _selected = 0;
  });
  Club get _club => _clubs[_selected];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && CoinWallet().welcomePending) {
        CoinWallet().welcomePending = false;
        showWelcomeCoins(context);
      }
    });
  }

  void _start(Club club) {
    if (!CoinWallet().spend(CoinWallet.clubCost(club))) return;
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
        <= 6 when info.hasPlayoff => trf('Pley-off (top-{0})', [info.playoffTo]),
        <= 12 => tr('Top-12'),
        _ => info.relegate > 0 ? tr('Ligada qolish') : tr('Top-16'),
      };
    }
    if (_clubs.length > 10) {
      return switch (rank) {
        1 => tr('Chempionlik'),
        <= 4 => tr('Top-4 (kontinental kubok)'),
        <= 7 => tr('Top-6 (kontinental kubok)'),
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
      appBar: AppBar(
        title: Text(tr('Klubni tanlang')),
        actions: [
          IconButton(
            tooltip: tr('Karyeralarim'),
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const SaveSlotsScreen())),
          ),
          InkWell(borderRadius: BorderRadius.circular(20), onTap: () => showCoinInfo(context), child: const CoinBalance()),
        ],
      ),
      body: PageWidth(
      maxWidth: 1100,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          SectionHeader(tr('Liga'), icon: Icons.emoji_events_outlined),
          LeaguePicker(selected: _league, onChanged: _switchLeague),
          const SizedBox(height: 16),
          SectionHeader(trf('Klublar ({0})', [_clubs.length]), icon: Icons.shield_outlined),
          LayoutBuilder(
            builder: (context, box) {
              final perRow = (box.maxWidth / 112).floor().clamp(3, 8);
              final tiles = <Widget>[
                for (var i = 0; i < _clubs.length; i++)
                  _clubChip(
                    selected: i == _selected,
                    onTap: () => setState(() => _selected = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClubCrestWidget(config: _clubs[i].crestConfig, size: 40),
                        const SizedBox(height: 6),
                        Text(_clubs[i].shortName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        ValueBadge(_clubs[i].teamOVR, size: 22),
                        const SizedBox(height: 4),
                        CoinAmount(CoinWallet.clubCost(_clubs[i]), size: 12),
                      ],
                    ),
                  ),
                _clubChip(
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
                      const Icon(Icons.add_circle_outline_rounded, size: 34, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(
                        tr('Yangi klub'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ];
              return GridView.count(
                crossAxisCount: perRow,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.7,
                children: tiles,
              );
            },
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
                    _metric(tr('OVR'), ValueBadge(club.teamOVR, size: 40)),
                    _metric(tr('HUJUM'), ValueBadge(club.attackRating, size: 40, filled: false)),
                    _metric(tr('MARKAZ'), ValueBadge(club.midfieldRating, size: 40, filled: false)),
                    _metric(tr('HIMOYA'), ValueBadge(club.defenseRating, size: 40, filled: false)),
                  ],
                ),
                const Divider(height: 28),
                InfoRow(tr('Transfer byudjeti'), club.formattedTransferBudget),
                InfoRow(tr('Maosh limiti'), club.formattedWageBudget),
                InfoRow(tr('Tarkib'), trf('{0} futbolchi · qiymati {1}', [club.squad.length, formatMoney(club.squadValue)])),
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
        ],
      ),
    ),
      // Always reachable, however long the club list is.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: ValueListenableBuilder<int>(
            valueListenable: CoinWallet().balance,
            builder: (context, coins, _) {
              final cost = CoinWallet.clubCost(club);
              final ok = coins >= cost;
              return SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: ok ? () => _start(club) : () => showCoinInfo(context),
                  style: ok ? null : FilledButton.styleFrom(backgroundColor: AppColors.ink3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          child: Text(ok ? trf('{0}NI BOSHQARISH', [club.name.toUpperCase()]) : tr('TANGA YETARLI EMAS')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.fromLTRB(3, 3, 9, 3),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: CoinAmount(cost, size: 18),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _clubChip({required bool selected, required VoidCallback onTap, required Widget child}) => SizedBox(
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
        Text(tr(label), style: AppText.overline.copyWith(fontSize: 10)),
      ],
    ),
  );
}
