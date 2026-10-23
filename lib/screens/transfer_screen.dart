import 'package:flutter/material.dart';
import '../models/club.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/team_widgets.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final game = GameState();
  String query = '';
  int category = 0;
  String sort = 'Reyting';
  RangeValues ageRange = const RangeValues(16, 40);

  Future<void> _offer(Player p, Club seller) async {
    final ask = game.askingPrice(p, seller);
    var fee = ask.toDouble();
    String? message;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          final f = (fee / 100000).round() * 100000;
          final issue = game.transferIssue(p, seller, game.userClub, f);
          return AlertDialog(
            title: const Text('Transfer taklifi'),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaceAvatar(config: p.face, size: 48, shirt: seller.primaryColor, circle: true),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: AppText.h3),
                            Text('${seller.name} · ${p.mainPosition.code} · ${p.age} yosh', style: AppText.caption),
                          ],
                        ),
                      ),
                      ValueBadge(p.ovr, size: 34),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InfoRow('Klub so‘ragan narx', formatMoney(ask)),
                  InfoRow('Bozor bahosi', formatMoney(p.marketValue)),
                  const SizedBox(height: 8),
                  Text('Taklifingiz: ${formatMoney(f)}', style: AppText.h3.copyWith(color: AppColors.primary)),
                  Slider(
                    min: ask * 0.6,
                    max: ask * 1.4,
                    value: fee.clamp(ask * 0.6, ask * 1.4),
                    onChanged: (v) => update(() {
                      fee = v;
                      message = null;
                    }),
                  ),
                  InfoRow('Agent va imzo', formatMoney(game.signingCost(p, f))),
                  InfoRow('Haftalik maosh', formatMoney(game.offeredWage(p))),
                  InfoRow('Shartnoma', '3 yil'),
                  const Divider(),
                  InfoRow('Jami xarajat', formatMoney(f + game.signingCost(p, f))),
                  InfoRow('Byudjetingiz', game.userClub.formattedTransferBudget),
                  if (issue != null || message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        message ?? issue!,
                        style: TextStyle(color: message != null && issue == null ? AppColors.warning : AppColors.live),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
              FilledButton(
                onPressed: issue == null
                    ? () {
                        final (result, value) = game.bidForPlayer(p, seller, f);
                        switch (result) {
                          case NegotiationResult.accepted:
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${p.name} jamoaga qo‘shildi')),
                            );
                          case NegotiationResult.countered:
                            update(() {
                              fee = value.toDouble();
                              message = '${seller.shortName} qarshi taklif qildi: ${formatMoney(value)}';
                            });
                          case NegotiationResult.rejected:
                            update(() => message = 'Taklif rad etildi. Klub kamida ${formatMoney(value)} kutmoqda.');
                          case NegotiationResult.blocked:
                            update(() => message = game.lastTransferError);
                        }
                      }
                    : null,
                child: const Text('Taklif yuborish'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Transfer markazi'),
        bottom: const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: 'Bozor'),
            Tab(text: 'Erkin agentlar'),
            Tab(text: 'Takliflar'),
            Tab(text: 'Qoidalar'),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: game,
        builder: (context, _) {
          if (!game.isInitialized) return const SizedBox();
          return TabBarView(
            children: [_market(context), _freeAgents(context), _offers(context), _rules()],
          );
        },
      ),
    ),
  );

  Widget _windowBanner() {
    final open = game.isTransferWindowOpen;
    return AppCard(
      color: open ? const Color(0xFFEFFAF3) : const Color(0xFFFFF6EC),
      child: Row(
        children: [
          Icon(open ? Icons.lock_open_rounded : Icons.lock_clock_outlined, color: open ? AppColors.win : AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(game.transferWindowLabel, style: AppText.small.copyWith(color: AppColors.ink))),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(game.userClub.formattedTransferBudget, style: AppText.number),
              Text('${game.userClub.squad.length}/${GameState.maxSquad} futbolchi', style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _market(BuildContext context) {
    final cats = [null, ...PositionCategory.values.reversed];
    final entries = <({Player p, Club c})>[];
    for (final c in game.allClubs.where((c) => c.id != game.userClubId)) {
      for (final p in c.squad) {
        final cat = cats[category];
        if ((cat == null || p.mainPosition.category == cat) &&
            p.age >= ageRange.start &&
            p.age <= ageRange.end &&
            p.name.toLowerCase().contains(query.toLowerCase())) {
          entries.add((p: p, c: c));
        }
      }
    }
    entries.sort(
      (a, b) => switch (sort) {
        'Narx' => game.transferFee(a.p).compareTo(game.transferFee(b.p)),
        'Yosh' => a.p.age.compareTo(b.p.age),
        'Salohiyat' => b.p.potential.compareTo(a.p.potential),
        'Forma' => (b.p.averageRating ?? 0).compareTo(a.p.averageRating ?? 0),
        _ => b.p.ovr.compareTo(a.p.ovr),
      },
    );
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _windowBanner(),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Futbolchini qidirish',
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        const SizedBox(height: 10),
        PillTabs(
          labels: const ['Barchasi', 'Hujum', 'Yarim himoya', 'Himoya', 'Darvoza'],
          index: category,
          onChanged: (i) => setState(() => category = i),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text('Yosh: ${ageRange.start.round()}–${ageRange.end.round()}', style: AppText.caption),
            Expanded(
              child: RangeSlider(
                min: 16,
                max: 40,
                divisions: 24,
                values: ageRange,
                onChanged: (v) => setState(() => ageRange = v),
              ),
            ),
            DropdownButton<String>(
              value: sort,
              underline: const SizedBox(),
              items: [
                for (final label in ['Reyting', 'Forma', 'Salohiyat', 'Narx', 'Yosh'])
                  DropdownMenuItem(value: label, child: Text(label, style: AppText.small)),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: entries.isEmpty
              ? const EmptyState(icon: Icons.search_off_rounded, text: 'Mos futbolchi topilmadi')
              : Column(
                  children: [
                    for (final e in entries.take(80))
                      PlayerTile(
                        player: e.p,
                        club: e.c,
                        subtitle: '${e.c.shortName} · ${e.p.age} yosh · salohiyat ${e.p.potential}',
                        onTap: () => PlayerDetailView.show(context, player: e.p, club: e.c),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ValueBadge(e.p.ovr, size: 30),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(64, 34),
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                              ),
                              onPressed: () => _offer(e.p, e.c),
                              child: Text(formatMoney(game.askingPrice(e.p, e.c)), style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _freeAgents(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      const AppCard(
        color: AppColors.primarySoft,
        child: Text(
          'Shartnomasi tugagan futbolchilarni istalgan vaqtda (oyna yopiq bo‘lsa ham) imzolash mumkin. To‘lov – faqat 8 haftalik maosh miqdorida imzo bonusi.',
          style: AppText.small,
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: game.freeAgents.isEmpty
            ? const EmptyState(icon: Icons.person_search_outlined, text: 'Hozircha erkin agentlar yo‘q')
            : Column(
                children: [
                  for (final p in List.of(game.freeAgents)..sort((a, b) => b.ovr.compareTo(a.ovr)))
                    PlayerTile(
                      player: p,
                      club: game.userClub,
                      subtitle: '${p.age} yosh · ${formatMoney(p.calculatedRenewalWageDemand)}/hafta',
                      showRating: false,
                      onTap: () => PlayerDetailView.show(context, player: p),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueBadge(p.ovr, size: 30),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 34)),
                            onPressed: () {
                              final ok = game.signFreeAgent(p);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? '${p.name} imzoladi' : (game.lastTransferError ?? 'Bajarilmadi'))),
                              );
                            },
                            child: const Text('Imzolash', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _offers(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      _windowBanner(),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: game.offers.isEmpty
            ? const EmptyState(
                icon: Icons.mark_email_unread_outlined,
                text: 'Futbolchilaringiz uchun hozircha taklif yo‘q. Ochiq transfer oynasida klublar taklif yuboradi.',
              )
            : Column(
                children: [
                  for (final o in List.of(game.offers))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          ClubCrestWidget(config: o.buyer.crestConfig, size: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.player.name, style: AppText.bodyStrong),
                                Text('${o.buyer.name} · ${formatMoney(o.fee)} (baho ${formatMoney(o.player.marketValue)})', style: AppText.caption),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rad etish',
                            onPressed: () => game.rejectOffer(o),
                            icon: const Icon(Icons.close_rounded, color: AppColors.live),
                          ),
                          IconButton.filled(
                            tooltip: 'Qabul qilish',
                            onPressed: () {
                              final ok = game.acceptOffer(o);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? '${o.player.name} sotildi' : (game.lastTransferError ?? 'Bajarilmadi'))),
                              );
                            },
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _rules() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader('Liga transfer reglamenti', icon: Icons.gavel_rounded),
            for (final rule in [
              'Yozgi oyna: 16 iyun – 1 sentabr. Qishki oyna: 1 yanvar – 2 fevral.',
              'Ro‘yxat: ${GameState.minSquad}–${GameState.maxSquad} futbolchi. Klub kamida ikki darvozabonni saqlaydi.',
              'O‘yin kuni zaxirasi: ${Club.matchdayBench} kishi. Har o‘yinda 5 ta almashtirish.',
              'Maoshlar klubning haftalik limitidan oshmasligi kerak.',
              'Narx qolgan shartnoma muddatiga bog‘liq; asosiy tarkib futbolchisi uchun klub 15% ko‘proq so‘raydi.',
              'Taklif narxdan past bo‘lsa klub qarshi taklif qiladi yoki rad etadi.',
              'Agent haqi: transferning 3%. Imzo bonusi: to‘rt haftalik maosh.',
              'Mavsum oxirida shartnomasi tugagan futbolchilar klubni tark etadi.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rule, style: AppText.body.copyWith(height: 1.45))),
                  ],
                ),
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
              child: SectionHeader('Yakunlangan transferlar', icon: Icons.history_rounded),
            ),
            if (game.transferHistory.isEmpty)
              const EmptyState(icon: Icons.swap_horiz_rounded, text: 'Hali transfer amalga oshirilmagan.'),
            for (final t in game.transferHistory)
              ListTile(
                dense: true,
                title: Text(t.playerName, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                subtitle: Text('${t.fromClub} → ${t.toClub} · ${t.round}-tur', style: AppText.caption),
                trailing: Text(formatMoney(t.fee), style: AppText.number.copyWith(fontSize: 13)),
              ),
          ],
        ),
      ),
    ],
  );
}
