"""One-off patch: negotiation UI on the transfer screen and player profile."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def patch(rel, pairs):
    p = ROOT / rel
    s = p.read_text(encoding='utf8')
    for a, b in pairs:
        assert s.count(a) == 1, (rel, s.count(a), a[:80])
        s = s.replace(a, b, 1)
    p.write_text(s, encoding='utf8')


patch('lib/screens/transfer_screen.dart', [
    ("import '../models/club.dart';", "import '../models/club.dart';\nimport '../models/transfer_deal.dart';"),
    ("""                  InfoRow(tr('Agent va imzo'), formatMoney(game.signingCost(p, f))),
                  InfoRow(tr('Haftalik maosh'), formatMoney(game.offeredWage(p))),
                  InfoRow(tr('Shartnoma'), '3 yil'),""", """                  InfoRow(tr('Agent va imzo'), formatMoney(game.signingCost(p, f))),
                  InfoRow(tr('Kutilayotgan maosh talabi'), formatMoney(game.wageDemand(p, game.userClub, seller))),"""),
    ("""                onPressed: issue == null
                    ? () {
                        final (result, value) = game.bidForPlayer(p, seller, f);
                        switch (result) {
                          case NegotiationResult.accepted:
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(trf('{0} jamoaga qo‘shildi', [p.name]))),
                            );
                          case NegotiationResult.countered:
                            update(() {
                              fee = value.toDouble();
                              message = '${seller.shortName} qarshi taklif qildi: ${formatMoney(value)}';
                            });
                          case NegotiationResult.rejected:
                            update(() => message = trf('Taklif rad etildi. Klub kamida {0} kutmoqda.', [formatMoney(value)]));
                          case NegotiationResult.blocked:
                            update(() => message = game.lastTransferError);
                        }
                      }
                    : null,""", """                onPressed: issue == null
                    ? () {
                        final error = game.makeBid(p, seller, f);
                        if (error != null) {
                          update(() => message = error);
                          return;
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(trf('Taklif yuborildi: {0} keyingi turda javob beradi.', [seller.name]))),
                        );
                      }
                    : null,"""),
    ("""            Tab(text: tr('Takliflar')),""", """            Tab(text: game.dealsNeedingAction.isEmpty ? tr('Muzokaralar') : trf('Muzokaralar ({0})', [game.dealsNeedingAction.length])),"""),
])

# Replace the offers tab body with a negotiations list.
p = ROOT / 'lib/screens/transfer_screen.dart'
s = p.read_text(encoding='utf8')
a = s.index("  Widget _offers(BuildContext context) => ListView(")
b = s.index("  Widget _rules() => ListView(")
s = s[:a] + '''  Widget _offers(BuildContext context) {
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
              d.dueRound > game.currentRound ? trf('Javob: {0}-turda', [d.dueRound]) : tr('Javob keyingi turda'),
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
                    FilledButton(onPressed: () => game.acceptDealOffer(d), child: Text(tr('Qabul qilish'))),
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
                result = error ?? tr('Shartnoma taklifi yuborildi. Futbolchi keyingi turda javob beradi.');
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

''' + s[b:]
p.write_text(s, encoding='utf8')

patch('lib/screens/widgets/player_detail_view.dart', [
    ("""                OutlinedButton.icon(
                  onPressed: () {
                    final ok = game.sellPlayer(p);
                    message(ok ? trf('{0} sotildi', [p.name]) : game.lastTransferError ?? tr('Sotilmadi'));
                    if (ok) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.sell_outlined),
                  label: Text(tr('Xaridor topish va sotish')),
                ),""", """                OutlinedButton.icon(
                  onPressed: () {
                    game.toggleTransferList(p);
                    setState(() {});
                    message(game.transferListed.contains(p.id)
                        ? tr('Sotuvga qo‘yildi: transfer oynasida klublar taklif yuboradi.')
                        : tr('Sotuv ro‘yxatidan olindi.'));
                  },
                  icon: Icon(game.transferListed.contains(p.id) ? Icons.remove_shopping_cart_outlined : Icons.sell_outlined),
                  label: Text(game.transferListed.contains(p.id) ? tr('Sotuv ro‘yxatidan olish') : tr('Sotuvga qo‘yish')),
                ),"""),
])
print('ok')
