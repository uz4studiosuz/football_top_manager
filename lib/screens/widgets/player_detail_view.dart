import 'player_attributes_view.dart';
import 'package:flutter/material.dart';
import '../../models/player.dart';
import '../../models/club.dart';
import '../../services/game_state.dart';
import '../../ui/face_avatar.dart';

class PlayerDetailView extends StatefulWidget {
  final Player player;
  final Club? club;
  final VoidCallback? onContractRenewed;
  const PlayerDetailView({
    super.key,
    required this.player,
    this.club,
    this.onContractRenewed,
  });
  static Future<void> show(
    BuildContext context, {
    required Player player,
    Club? club,
    VoidCallback? onContractRenewed,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PlayerDetailView(
        player: player,
        club: club,
        onContractRenewed: onContractRenewed,
      ),
    ),
  );
  @override
  State<PlayerDetailView> createState() => _PlayerDetailViewState();
}

class _PlayerDetailViewState extends State<PlayerDetailView> {
  Player get p => widget.player;
  bool get owned =>
      GameState().isInitialized &&
      GameState().userClub.squad.any((q) => identical(p, q));
  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Widget metric(String label, String value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF637184)),
        ),
      ],
    ),
  );
  Widget row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF637184))),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
  Widget panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    color: Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Futbolchi profili'),
        actions: [
          if (owned)
            IconButton(
              tooltip: 'Portretni tahrirlash',
              icon: const Icon(Icons.face_outlined),
              onPressed: () async {
                final face = await editFace(context, p.face);
                if (face != null && mounted) setState(() => p.face = face);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                FaceAvatar(
                  config: p.face,
                  size: 86,
                  shirt: widget.club?.primaryColor ?? const Color(0xFF1769E0),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${p.mainPosition.code}  ·  #${p.number}  ·  ${p.age} yosh',
                        style: const TextStyle(color: Color(0xFF637184)),
                      ),
                      const SizedBox(height: 4),
                      Text(widget.club?.name ?? p.nationality),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1769E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${p.ovr}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'OVR',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelPadding: EdgeInsets.symmetric(horizontal: 18),
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Umumiy'),
                Tab(text: 'Atributlar'),
                Tab(text: 'Pozitsiyalar'),
                Tab(text: 'Shartnoma'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    panel([
                      const Text(
                        'Mavsum statistikasi',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          metric('Uchrashuv', '${p.seasonMatches}'),
                          metric('Gol', '${p.seasonGoals}'),
                          metric('Assist', '${p.seasonAssists}'),
                          metric(
                            'Gol / o‘yin',
                            p.goalsPerMatch.toStringAsFixed(2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      row('Quruq o‘yinlar', '${p.seasonCleanSheets}'),
                      row(
                        'Sariq / qizil kartochka',
                        '${p.seasonYellowCards} / ${p.seasonRedCards}',
                      ),
                    ]),
                    const SizedBox(height: 12),
                    panel([
                      const Text(
                        'Holat va ma’lumot',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      row('Jismoniy tayyorlik', '${p.currentStamina}%'),
                      row('Ruhiyat', '${p.morale}%'),
                      row('Millati', p.nationality),
                      row(
                        'Yetakchi oyoq',
                        p.preferredFoot == PreferredFoot.right
                            ? 'O‘ng'
                            : 'Chap',
                      ),
                      row('Zaif oyoq', '${p.weakFoot} / 5'),
                      row('Bozor bahosi', p.formattedMarketValue),
                    ]),
                  ],
                ),
                PlayerAttributesView(player: p),
                PositionRatingsView(player: p),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    panel([
                      const Text(
                        'Amaldagi shartnoma',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      row('Qolgan muddat', '${p.contract.contractYears} yil'),
                      row('Haftalik maosh', p.formattedWeeklyWage),
                      row(
                        'Yillik maosh',
                        '€${(p.contract.weeklyWage * 52 / 1000000).toStringAsFixed(2)}M',
                      ),
                      row(
                        'Tovon puli',
                        p.contract.releaseClause > 0
                            ? '€${(p.contract.releaseClause / 1000000).toStringAsFixed(1)}M'
                            : 'Belgilanmagan',
                      ),
                      if (owned) ...[
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _renew,
                          icon: const Icon(Icons.edit_document),
                          label: const Text('Yangi shartnoma taklif qilish'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            final ok = GameState().sellPlayer(p);
                            if (ok) {
                              Navigator.pop(context);
                            } else {
                              message(
                                GameState().lastTransferError ??
                                    'Transfer amalga oshmadi',
                              );
                            }
                          },
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Xaridor topish va sotish'),
                        ),
                      ],
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  void _renew() {
    var years = 3;
    final wage = p.calculatedRenewalWageDemand;
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Shartnoma taklifi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Talab: €${(wage / 1000).toStringAsFixed(0)}K / hafta'),
              const SizedBox(height: 16),
              const Text('Yangi umumiy muddat'),
              Wrap(
                spacing: 6,
                children: [
                  for (final y in [1, 2, 3, 4, 5])
                    ChoiceChip(
                      label: Text('$y yil'),
                      selected: y == years,
                      onSelected: (_) => update(() => years = y),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () {
                if (GameState().renewContract(p, years, wage)) {
                  Navigator.pop(ctx);
                  setState(() {});
                  widget.onContractRenewed?.call();
                  message('Shartnoma imzolandi');
                } else {
                  message('Maosh limiti yetarli emas');
                }
              },
              child: const Text('Imzolash'),
            ),
          ],
        ),
      ),
    );
  }
}
