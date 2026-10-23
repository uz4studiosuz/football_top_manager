import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import 'widgets/player_detail_view.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final game = GameState();
  String query = '';
  PositionCategory? category;
  String sort = 'Reyting';
  String money(int n) => '€${(n / 1000000).toStringAsFixed(2)}M';
  void _offer(Player p, Club seller) {
    final issue = game.transferIssue(p, seller, game.userClub);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer taklifi'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _row('Sotuvchi', seller.name),
              _row('Klubga to‘lov', money(game.transferFee(p))),
              _row('Agent va imzo', money(game.signingCost(p))),
              _row(
                'Haftalik maosh',
                '€${(game.offeredWage(p) / 1000).toStringAsFixed(0)}K',
              ),
              _row('Yangi shartnoma', '3 yil'),
              const Divider(),
              _row(
                'Jami boshlang‘ich xarajat',
                money(game.transferFee(p) + game.signingCost(p)),
              ),
              if (issue != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    issue,
                    style: const TextStyle(color: Color(0xFFAD3F38)),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: issue == null
                ? () {
                    final ok = game.buyPlayer(p, seller);
                    Navigator.pop(ctx);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? '${p.name} jamoaga qo‘shildi'
                              : game.lastTransferError ??
                                    'Transfer bajarilmadi',
                        ),
                      ),
                    );
                  }
                : null,
            child: const Text('Imzolash'),
          ),
        ],
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: const TextStyle(color: Color(0xFF637184))),
        ),
        Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Transfer markazi'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Bozor'),
            Tab(text: 'Qoidalar va tarix'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          final entries = <({Player p, Club c})>[];
          for (final c in game.allClubs.where((c) => c.id != game.userClubId)) {
            for (final p in c.squad) {
              if ((category == null || p.mainPosition.category == category) &&
                  p.name.toLowerCase().contains(query.toLowerCase())) {
                entries.add((p: p, c: c));
              }
            }
          }
          entries.sort(
            (a, b) => sort == 'Narx'
                ? game.transferFee(a.p).compareTo(game.transferFee(b.p))
                : sort == 'Yosh'
                ? a.p.age.compareTo(b.p.age)
                : b.p.ovr.compareTo(a.p.ovr),
          );
          return TabBarView(
            children: [
              Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                game.transferWindowLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1769E0),
                                ),
                              ),
                            ),
                            Text(
                              game.userClub.formattedTransferBudget,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          onChanged: (v) => setState(() => query = v),
                          decoration: InputDecoration(
                            hintText: 'Futbolchini qidirish',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: const Color(0xFFF3F5F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Barchasi'),
                                selected: category == null,
                                onSelected: (_) =>
                                    setState(() => category = null),
                              ),
                              for (final cat in PositionCategory.values)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: ChoiceChip(
                                    label: Text(cat.label),
                                    selected: category == cat,
                                    onSelected: (_) =>
                                        setState(() => category = cat),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entries.length} futbolchi',
                            style: const TextStyle(color: Color(0xFF637184)),
                          ),
                        ),
                        DropdownButton<String>(
                          value: sort,
                          underline: const SizedBox(),
                          items: [
                            for (final label in ['Reyting', 'Narx', 'Yosh'])
                              DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ),
                          ],
                          onChanged: (v) => setState(() => sort = v!),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: entries.isEmpty
                        ? const Center(child: Text('Mos futbolchi topilmadi'))
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, i) {
                              final entry = entries[i];
                              final p = entry.p;
                              return Container(
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 1),
                                child: Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 7,
                                    ),
                                    leading: FaceAvatar(
                                      config: p.face,
                                      size: 44,
                                      shirt: entry.c.primaryColor,
                                    ),
                                    title: Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${entry.c.shortName} · ${p.mainPosition.code} · ${p.age} yosh · OVR ${p.ovr}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    onTap: () => PlayerDetailView.show(
                                      context,
                                      player: p,
                                      club: entry.c,
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => _offer(p, entry.c),
                                      child: Text(
                                        money(game.transferFee(p)),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
              ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text(
                    'Liga transfer reglamenti',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ushbu 14 turlik liga uchun o‘yin qoidalari',
                    style: TextStyle(color: Color(0xFF637184)),
                  ),
                  const SizedBox(height: 16),
                  for (final rule in [
                    'Transfer oynalari: 1–3 va 8–9-turlar.',
                    'Ro‘yxat: ko‘pi bilan 25 futbolchi. Sotuvchi kamida 14 futbolchini va bitta darvozabonni saqlaydi.',
                    'Maoshlar klubning haftalik limitidan oshmasligi kerak.',
                    'Narx qolgan kontrakt muddatiga bog‘liq; tovon puli bo‘lsa narx shu limitdan oshmaydi.',
                    'Agent haqi: transferning 3%. Imzo bonusi: to‘rt haftalik maosh.',
                    'Xarid yangi uch yillik shartnoma bilan yakunlanadi.',
                    'AI klublar ochiq oynada o‘z mablag‘i bilan transfer qiladi.',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(rule, style: const TextStyle(height: 1.5)),
                    ),
                  const Divider(height: 36),
                  const Text(
                    'Yakunlangan transferlar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  if (game.transferHistory.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('Hali transfer amalga oshirilmagan.'),
                    ),
                  for (final t in game.transferHistory)
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t.playerName),
                        subtitle: Text('${t.fromClub} > ${t.toClub}'),
                        trailing: Text(money(t.fee)),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
