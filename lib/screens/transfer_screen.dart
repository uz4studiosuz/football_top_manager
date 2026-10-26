import 'package:flutter/material.dart';
import '../data/initial_database.dart';
import '../models/club.dart';
import '../models/transfer_deal.dart';
import '../models/player.dart';
import '../services/game_state.dart';
import '../ui/face_avatar.dart';
import '../ui/team_widgets.dart';
import '../ui/flag.dart';
import '../ui/league_picker.dart';
import '../ui/widgets.dart';
import 'widgets/player_detail_view.dart';
import '../l10n/l10n.dart';
import '../ui/scout_badge.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final game = GameState();
  String query = '';
  int category = 0;
  PlayerPosition? position; // optional exact position inside the category
  int page = 0;
  static const pageSize = 25;
  int league = 0; // 0 = every league of the pyramid

  /// One opened foreign league (null: every opened one).
  String? worldLeague;

  /// Opens any league of the world in the market (its players show at once;
  /// their attributes need a scout).
  Future<void> _openLeague() async {
    final pyramid = {for (final l in InitialDatabase.pyramidOf(game.leagueId)) l.id};
    final id = await pickLeague(
      context,
      only: InitialDatabase.leagues.where((l) => !pyramid.contains(l.id) && l.id != 'super'),
    );
    if (id == null || !mounted) return;
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      await game.browseCountry(InitialDatabase.info(id).country);
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;
    setState(() {
      league = InitialDatabase.pyramidOf(game.leagueId).length + 1;
      worldLeague = id;
      page = 0;
    });
  }
  String sort = 'Reyting';
  RangeValues ageRange = const RangeValues(16, 40);

  /// What the club and the player think of the move, before any bid.
  Future<void> _offer(Player p, Club seller) => showTransferOffer(context, p, seller);

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    child: Scaffold(
      appBar: AppBar(
        title: Text(tr('Transfer markazi')),
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Bozor')),
            Tab(text: tr('Erkin agentlar')),
            Tab(text: game.dealsNeedingAction.isEmpty ? tr('Muzokaralar') : trf('Muzokaralar ({0})', [game.dealsNeedingAction.length])),
            Tab(text: tr('Qoidalar')),
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
              Text(trf('{0}/{1} futbolchi', [game.userClub.squad.length, GameState.maxSquad]), style: AppText.caption),
            ],
          ),
        ],
      ),
    );
  }

  Widget _market(BuildContext context) {
    // Same order as the filter labels: all, attack, midfield, defence, keepers.
    final cats = [null, ...PositionCategory.values];
    final entries = <({Player p, Club c})>[];
    final pyramid = InitialDatabase.pyramidOf(game.leagueId);
    // The last tab lists clubs from the countries the scouts have opened.
    final foreign = game.world.clubs.isNotEmpty;
    final abroadTab = pyramid.length + 1;
    final only = league == 0 || league > pyramid.length ? null : pyramid[league - 1].id;
    for (final c in game.marketClubs.where((c) => c.id != game.userClubId)) {
      if (only != null && game.leagueOfClub(c.id) != only) continue;
      if (league == abroadTab && !game.isWorldClub(c)) continue;
      if (league == abroadTab && worldLeague != null && game.leagueOfClub(c.id) != worldLeague) continue;
      for (final p in c.squad) {
        final cat = cats[category];
        final fits = position == null
            ? (cat == null || p.mainPosition.category == cat)
            : (p.mainPosition == position || p.altPositions.contains(position));
        if (fits &&
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
          onChanged: (v) => setState(() {
            query = v;
            page = 0;
          }),
          decoration: InputDecoration(
            hintText: tr('Futbolchini qidirish'),
            prefixIcon: Icon(Icons.search_rounded),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
        if (pyramid.length > 1 || foreign) ...[
          const SizedBox(height: 10),
          PillTabs(
            labels: [
              tr('Barcha ligalar'),
              for (final l in pyramid) l.name,
              if (foreign) trf('🌍 Chet el ({0})', [game.world.countries.length]),
            ],
            index: league,
            onChanged: (i) => setState(() {
              league = i;
              page = 0;
            }),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            if (league == abroadTab && foreign)
              Expanded(
                child: DropdownButton<String?>(
                  value: worldLeague,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(tr('Barcha ochilgan ligalar'))),
                    for (final id in {for (final c in game.world.clubs) game.leagueOfClub(c.id)})
                      DropdownMenuItem<String?>(
                        value: id,
                        child: FlagLabel(InitialDatabase.info(id).flag, InitialDatabase.info(id).name, nationality: InitialDatabase.info(id).country),
                      ),
                  ],
                  onChanged: (v) => setState(() {
                    worldLeague = v;
                    page = 0;
                  }),
                ),
              )
            else
              const Spacer(),
            TextButton.icon(
              onPressed: _openLeague,
              icon: const Icon(Icons.public_rounded, size: 18),
              label: Text(tr('Boshqa ligalar')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        PillTabs(
          labels: [tr('Barchasi'), tr('Hujum'), tr('Yarim himoya'), tr('Himoya'), tr('Darvozabonlar')],
          index: category,
          onChanged: (i) => setState(() {
            category = i;
            position = null;
            page = 0;
          }),
        ),
        if (cats[category] case final cat? when cat != PositionCategory.goalkeeper) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final options = PlayerPosition.values.where((x) => x.category == cat).toList();
              return PillTabs(
                labels: [tr('Barcha pozitsiyalar'), for (final x in options) x.code],
                index: position == null ? 0 : options.indexOf(position!) + 1,
                onChanged: (i) => setState(() {
                  position = i == 0 ? null : options[i - 1];
                  page = 0;
                }),
              );
            },
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            Text(trf('Yosh: {0}–{1}', [ageRange.start.round(), ageRange.end.round()]), style: AppText.caption),
            Expanded(
              child: RangeSlider(
                min: 16,
                max: 40,
                divisions: 24,
                values: ageRange,
                onChanged: (v) => setState(() {
                  ageRange = v;
                  page = 0;
                }),
              ),
            ),
            DropdownButton<String>(
              value: sort,
              underline: const SizedBox(),
              items: [
                for (final label in ['Reyting', 'Forma', 'Salohiyat', 'Narx', 'Yosh'])
                  DropdownMenuItem(value: label, child: Text(tr(label), style: AppText.small)),
              ],
              onChanged: (v) => setState(() {
                sort = v!;
                page = 0;
              }),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: entries.isEmpty
              ? EmptyState(icon: Icons.search_off_rounded, text: tr('Mos futbolchi topilmadi'))
              : Column(
                  children: [
                    for (final e in entries.skip(page * pageSize).take(pageSize))
                      PlayerTile(
                        player: e.p,
                        club: e.c,
                        subtitle: trf('{0} · {1} yosh · salohiyat {2}', [
                          game.isWorldClub(e.c) ? '${InitialDatabase.info(game.leagueOfClub(e.c.id)).flag} ${e.c.shortName}' : e.c.shortName,
                          e.p.age,
                          game.isScouted(e.p) ? '${e.p.potential}' : '?',
                        ]),
                        onTap: () => PlayerDetailView.show(context, player: e.p, club: e.c),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScoutedOvr(e.p, size: 30),
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
        _pager(entries.length),
      ],
    );
  }

  /// "‹ 26–50 of 412 ›" – only one page of players is built at a time.
  Widget _pager(int total) {
    final pages = (total / pageSize).ceil();
    if (pages <= 1) return const SizedBox.shrink();
    final current = page.clamp(0, pages - 1);
    final from = current * pageSize + 1, to = ((current + 1) * pageSize).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: current > 0 ? () => setState(() => page = current - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(trf('{0}–{1} / {2}', [from, to, total]), style: AppText.small),
          IconButton(
            onPressed: current < pages - 1 ? () => setState(() => page = current + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _freeAgents(BuildContext context) => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      AppCard(
        color: AppColors.primarySoft,
        child: Text(
          tr('Shartnomasi tugagan futbolchilarni istalgan vaqtda (oyna yopiq bo‘lsa ham) imzolash mumkin. To‘lov – faqat 8 haftalik maosh miqdorida imzo bonusi.'),
          style: AppText.small,
        ),
      ),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: game.freeAgents.isEmpty
            ? EmptyState(icon: Icons.person_search_outlined, text: tr('Hozircha erkin agentlar yo‘q'))
            : Column(
                children: [
                  for (final p in List.of(game.freeAgents)..sort((a, b) => b.ovr.compareTo(a.ovr)))
                    PlayerTile(
                      player: p,
                      club: game.userClub,
                      subtitle: trf('{0} yosh · {1}/hafta', [p.age, formatMoney(p.calculatedRenewalWageDemand)]),
                      showRating: false,
                      onTap: () => PlayerDetailView.show(context, player: p),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScoutedOvr(p, size: 30),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(minimumSize: const Size(64, 34)),
                            onPressed: () {
                              final ok = game.signFreeAgent(p);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? trf('{0} imzoladi', [p.name]) : (game.lastTransferError ?? tr('Bajarilmadi')))),
                              );
                            },
                            child: Text(tr('Imzolash'), style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    ],
  );

  Widget _offers(BuildContext context) {
    final open = [for (final d in game.deals) if (!d.stage.finished) d];
    final closed = [for (final d in game.deals) if (d.stage.finished) d];
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _windowBanner(),
        const SizedBox(height: 12),
        if (game.deals.isEmpty)
          AppCard(
            child: EmptyState(
              icon: Icons.handshake_outlined,
              text: tr('Hozircha muzokaralar yo‘q. Bozordan futbolchiga taklif yuboring yoki o‘z futbolchingizni sotuvga qo‘ying.'),
            ),
          ),
        for (final d in [...open, ...closed]) _dealCard(context, d),
      ],
    );
  }

  Widget _dealCard(BuildContext context, TransferDeal d) {
    final buying = d.buyer.id == game.userClubId;
    final other = buying ? d.seller : d.buyer;
    final color = d.stage == DealStage.done
        ? AppColors.win
        : d.stage == DealStage.collapsed
        ? AppColors.ink3
        : d.stage.waitsForUser
        ? AppColors.warning
        : AppColors.primary;
    void snack(String? text) {
      if (text != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaceAvatar(config: d.player.face, size: 40, shirt: d.seller.primaryColor, circle: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.player.name, style: AppText.bodyStrong),
                    Row(
                      children: [
                        Icon(buying ? Icons.call_received_rounded : Icons.call_made_rounded, size: 13, color: AppColors.ink3),
                        const SizedBox(width: 4),
                        ClubCrestWidget(config: other.crestConfig, size: 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${other.shortName} · ${formatMoney(d.fee)}',
                            style: AppText.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(d.stage.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          if (d.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(d.note, style: AppText.small),
          ],
          if (!d.stage.finished && !d.stage.waitsForUser) ...[
            const SizedBox(height: 4),
            Text(
              d.dueRound > game.currentRound ? trf('Javob: {0}', [game.roundDate(d.dueRound)]) : trf('Javob: {0}', [game.roundDate(game.currentRound + 1)]),
              style: AppText.caption,
            ),
          ],
          if (!d.stage.finished)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (d.stage == DealStage.clubCountered) ...[
                    FilledButton(
                      onPressed: () => game.acceptCounter(d),
                      child: Text(trf('Qabul qilish ({0})', [formatMoney(d.counterFee ?? d.fee)])),
                    ),
                    OutlinedButton(onPressed: () => _offer(d.player, d.seller), child: Text(tr('Yangi taklif'))),
                  ],
                  if (d.stage == DealStage.contractTalks)
                    FilledButton.icon(
                      onPressed: () => _contractDialog(d).then(snack),
                      icon: const Icon(Icons.edit_document, size: 18),
                      label: Text(tr('Shartnoma taklif qilish')),
                    ),
                  if (d.stage == DealStage.offerReceived) ...[
                    FilledButton(
                      onPressed: () {
                        final issue = game.acceptDealOffer(d);
                        if (issue != null) snack(issue);
                      },
                      child: Text(tr('Qabul qilish')),
                    ),
                    OutlinedButton(onPressed: () => _counterDialog(d), child: Text(tr('Qarshi taklif'))),
                  ],
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: AppColors.live),
                    onPressed: () => game.cancelDeal(d),
                    child: Text(d.stage == DealStage.offerReceived ? tr('Rad etish') : tr('Bekor qilish')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Personal terms for a player whose fee is agreed.
  Future<String?> _contractDialog(TransferDeal d) async {
    final demand = game.wageDemand(d.player, d.buyer, d.seller);
    var wage = (d.wage > 0 ? d.wage : demand).toDouble();
    var years = d.years;
    String? result;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(trf('{0} bilan shartnoma', [d.player.shortName])),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(tr('Futbolchi talabi'), '${formatMoney(demand)}/${tr('hafta')}'),
              InfoRow(tr('Bo‘sh maosh limiti'), formatMoney(game.userClub.remainingWageBudget)),
              const SizedBox(height: 8),
              Text(trf('Maosh: {0}/hafta', [formatMoney((wage / 1000).round() * 1000)]), style: AppText.h3),
              Slider(
                min: demand * 0.7,
                max: demand * 1.4,
                value: wage.clamp(demand * 0.7, demand * 1.4),
                onChanged: (v) => update(() => wage = v),
              ),
              Text(trf('Muddat: {0} yil', [years]), style: AppText.bodyStrong),
              Slider(
                min: 1,
                max: 5,
                divisions: 4,
                value: years.toDouble(),
                onChanged: (v) => update(() => years = v.round()),
              ),
              Text(tr('Talabdan kam taklif qilsangiz, futbolchi rad etishi yoki ko‘proq so‘rashi mumkin.'), style: AppText.caption),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
            FilledButton(
              onPressed: () {
                final error = game.offerContract(d, (wage / 1000).round() * 1000, years);
                result = error ?? trf('Shartnoma taklifi yuborildi. Futbolchi {0} da javob beradi.', [game.roundDate(game.currentRound + 1)]);
                Navigator.pop(ctx);
              },
              child: Text(tr('Taklif yuborish')),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  Future<void> _counterDialog(TransferDeal d) async {
    var fee = (d.fee * 1.2).toDouble();
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(tr('Qarshi taklif')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InfoRow(tr('Ularning taklifi'), formatMoney(d.fee)),
              InfoRow(tr('Bozor bahosi'), formatMoney(d.player.marketValue)),
              const SizedBox(height: 8),
              Text(formatMoney((fee / 100000).round() * 100000), style: AppText.h3.copyWith(color: AppColors.primary)),
              Slider(
                min: d.fee.toDouble(),
                max: d.fee * 2.0,
                value: fee.clamp(d.fee.toDouble(), d.fee * 2.0),
                onChanged: (v) => update(() => fee = v),
              ),
              Text(tr('Juda baland narx so‘rasangiz, xaridor muzokaradan chiqishi mumkin.'), style: AppText.caption),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
            FilledButton(
              onPressed: () {
                game.counterDealOffer(d, (fee / 100000).round() * 100000);
                Navigator.pop(ctx);
              },
              child: Text(tr('Yuborish')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rules() => ListView(
    padding: const EdgeInsets.all(12),
    children: [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(tr('Liga transfer reglamenti'), icon: Icons.gavel_rounded),
            for (final rule in [
              tr('Yozgi oyna: 16 iyun – 1 sentabr. Qishki oyna: 1 yanvar – 2 fevral.'),
              trf('Ro‘yxat: {0}–{1} futbolchi. Klub kamida ikki darvozabonni saqlaydi.', [GameState.minSquad, GameState.maxSquad]),
              trf('O‘yin kuni zaxirasi: {0} kishi. Har o‘yinda 5 ta almashtirish.', [Club.matchdayBench]),
              tr('Maoshlar klubning haftalik limitidan oshmasligi kerak.'),
              tr('Narx qolgan shartnoma muddatiga bog‘liq; asosiy tarkib futbolchisi uchun klub 15% ko‘proq so‘raydi.'),
              tr('Taklif narxdan past bo‘lsa klub qarshi taklif qiladi yoki rad etadi.'),
              tr('Agent haqi: transferning 3%. Imzo bonusi: to‘rt haftalik maosh.'),
              tr('Mavsum oxirida shartnomasi tugagan futbolchilar klubni tark etadi.'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SectionHeader(tr('Yakunlangan transferlar'), icon: Icons.history_rounded),
            ),
            if (game.transferHistory.isEmpty)
              EmptyState(icon: Icons.swap_horiz_rounded, text: tr('Hali transfer amalga oshirilmagan.')),
            for (final t in game.transferHistory)
              ListTile(
                dense: true,
                title: Text(t.playerName, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                subtitle: Text(trf('{0} → {1} · {2}-tur', [t.fromClub, t.toClub, t.round]), style: AppText.caption),
                trailing: Text(formatMoney(t.fee), style: AppText.number.copyWith(fontSize: 13)),
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _opinions(Player p, Club seller) {
  final game = GameState();
  final club = game.sellerStance(p, seller, game.userClub);
  final mind = game.moveInterest(p, game.userClub, seller);
  final color = mind.interest >= 60
      ? AppColors.win
      : mind.interest >= GameState.refuseInterest
      ? AppColors.warning
      : AppColors.live;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      Text(tr('Klub fikri'), style: AppText.bodyStrong),
      if (club.reasons.isEmpty) Text(tr('Oddiy savdo: so‘ralgan narxga rozi bo‘ladi.'), style: AppText.caption),
      for (final r in club.reasons)
        Text('• $r', style: AppText.caption.copyWith(color: club.notForSale && r == club.reasons.last ? AppColors.live : null)),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: Text(tr('Futbolchining qiziqishi'), style: AppText.bodyStrong)),
          Text('${mind.interest}%', style: AppText.bodyStrong.copyWith(color: color)),
        ],
      ),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: mind.interest / 100, color: color, backgroundColor: AppColors.line, minHeight: 6),
      ),
      for (final r in mind.reasons) Text('• $r', style: AppText.caption),
      if (mind.interest < GameState.refuseInterest)
        Text(tr('Futbolchi bu klubga o‘tishni xohlamaydi: narx kelishilsa ham shartnomani rad etadi.'),
            style: AppText.caption.copyWith(color: AppColors.live)),
    ],
  );
}

/// The bid dialog for [p] of [seller] (market list, negotiations, player page).
Future<void> showTransferOffer(BuildContext context, Player p, Club seller) async {
  final game = GameState();
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
          title: Text(tr('Transfer taklifi')),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
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
                          Text(trf('{0} · {1} · {2} yosh', [seller.name, p.mainPosition.code, p.age]), style: AppText.caption),
                        ],
                      ),
                    ),
                    ScoutedOvr(p, size: 34),
                  ],
                ),
                const SizedBox(height: 16),
                InfoRow(tr('Klub so‘ragan narx'), formatMoney(ask)),
                InfoRow(tr('Bozor bahosi'), formatMoney(p.marketValue)),
                const SizedBox(height: 8),
                Text(trf('Taklifingiz: {0}', [formatMoney(f)]), style: AppText.h3.copyWith(color: AppColors.primary)),
                Slider(
                  min: ask * 0.6,
                  max: ask * 1.4,
                  value: fee.clamp(ask * 0.6, ask * 1.4),
                  onChanged: (v) => update(() {
                    fee = v;
                    message = null;
                  }),
                ),
                InfoRow(tr('Agent va imzo'), formatMoney(game.signingCost(p, f))),
                InfoRow(tr('Kutilayotgan maosh talabi'), formatMoney(game.wageDemand(p, game.userClub, seller))),
                const Divider(),
                InfoRow(tr('Jami xarajat'), formatMoney(f + game.signingCost(p, f))),
                InfoRow(tr('Byudjetingiz'), game.userClub.formattedTransferBudget),
                _opinions(p, seller),
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Bekor qilish'))),
            FilledButton(
              onPressed: issue == null
                  ? () {
                      final error = game.makeBid(p, seller, f);
                      if (error != null) {
                        update(() => message = error);
                        return;
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(trf('Taklif yuborildi: {0} {1} da javob beradi.', [seller.name, game.roundDate(game.currentRound + 1)]))),
                      );
                    }
                  : null,
              child: Text(tr('Taklif yuborish')),
            ),
          ],
        );
      },
    ),
  );
}
