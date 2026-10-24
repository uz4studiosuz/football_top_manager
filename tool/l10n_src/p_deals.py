"""One-off patch: multi-step transfer negotiations."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
p = ROOT / 'lib/services/game_state.dart'
s = p.read_text(encoding='utf8')


def rep(a, b, count=1):
    global s
    assert s.count(a) == count, (s.count(a), a[:80])
    s = s.replace(a, b)


rep("""class TransferOffer {
  final Player player;
  final Club buyer;
  final int fee;
  const TransferOffer(this.player, this.buyer, this.fee);
}

enum NegotiationResult { accepted, countered, rejected, blocked }
""", """enum NegotiationResult { accepted, countered, rejected, blocked }
""")
rep("""  final List<TransferOffer> offers = [];""", """  /// Open and recently finished transfer negotiations involving the user.
  final List<TransferDeal> deals = [];

  /// The user's players on the transfer list (attract more offers).
  final Set<String> transferListed = {};

  /// Bids from other clubs waiting for the user's answer.
  List<TransferDeal> get offers =>
      deals.where((d) => d.stage == DealStage.offerReceived).toList();

  /// Deals where the next move is the user's.
  List<TransferDeal> get dealsNeedingAction =>
      deals.where((d) => d.stage.waitsForUser).toList();""")
rep("""import 'division.dart';""", """import '../models/transfer_deal.dart';
import 'division.dart';""")
rep("""    offers.clear();
    freeAgents.clear();""", """    deals.clear();
    transferListed.clear();
    freeAgents.clear();""")

# --- completion with negotiated terms
rep("""  void _completeTransfer(Player p, Club seller, Club buyer, [int? agreedFee]) {""",
    """  void _completeTransfer(Player p, Club seller, Club buyer, [int? agreedFee, int? wage, int years = 3]) {""")
rep("""    p.contract = p.contract.copyWith(contractYears: 3, weeklyWage: offeredWage(p));""",
    """    p.contract = p.contract.copyWith(contractYears: years, weeklyWage: wage ?? offeredWage(p));
    transferListed.remove(p.id);""")

# --- bid evaluation stays a pure decision; negotiations use it
rep("""  /// Negotiated bid: accepted at/above the asking price, countered when close.
  (NegotiationResult, int) bidForPlayer(Player p, Club seller, int fee) {
    final issue = transferIssue(p, seller, userClub, fee);
    if (issue != null) {
      lastTransferError = issue;
      return (NegotiationResult.blocked, fee);
    }
    final ask = askingPrice(p, seller);
    if (fee >= ask) {
      _completeTransfer(p, seller, userClub, fee);
      _news(
        NewsKind.transfer,
        trf('{0} jamoaga qo‘shildi', [p.name]),
        trf('{0} {1} taklifni qabul qildi. Shartnoma: 3 yil.', [seller.name, _m(fee)]),
      );
      notifyListeners();
      return (NegotiationResult.accepted, fee);
    }
    if (fee >= ask * 0.85) {
      final counter = ((fee + ask) / 2 / 100000).round() * 100000;
      return (NegotiationResult.countered, max(counter, fee + 100000));
    }
    return (NegotiationResult.rejected, ask);
  }

  bool sellPlayer(Player player) {
    final buyers = _allClubs.where((c) => c.id != userClub.id).toList()
      ..sort((a, b) => b.transferBudget.compareTo(a.transferBudget));
    for (final buyer in buyers) {
      if (transferIssue(player, userClub, buyer) == null) {
        _completeTransfer(player, userClub, buyer);
        _news(
          NewsKind.transfer,
          trf('{0} sotildi', [player.name]),
          trf('{0} {1} to‘ladi.', [buyer.name, _m(transferFee(player))]),
        );
        notifyListeners();
        return true;
      }
    }
    lastTransferError = tr('Hozircha shartlarga mos xaridor yo‘q.');
    return false;
  }

  bool acceptOffer(TransferOffer o) {
    if (!offers.contains(o)) return false;
    final issue = transferIssue(o.player, userClub, o.buyer, o.fee);
    offers.remove(o);
    if (issue != null) {
      lastTransferError = issue;
      notifyListeners();
      return false;
    }
    _completeTransfer(o.player, userClub, o.buyer, o.fee);
    _news(
      NewsKind.transfer,
      trf('{0} {1}ga sotildi', [o.player.name, o.buyer.name]),
      trf('Kelishuv summasi: {0}.', [_m(o.fee)]),
    );
    notifyListeners();
    return true;
  }

  void rejectOffer(TransferOffer o) {
    offers.remove(o);
    o.player.morale = max(35, o.player.morale - 2);
    notifyListeners();
  }
""", """  /// How the selling club judges a bid: accepted at the asking price,
  /// countered when close, rejected otherwise.
  (NegotiationResult, int) evaluateBid(Player p, Club seller, int fee) {
    final ask = askingPrice(p, seller);
    if (fee >= ask) return (NegotiationResult.accepted, fee);
    if (fee >= ask * 0.85) {
      final counter = ((fee + ask) / 2 / 100000).round() * 100000;
      return (NegotiationResult.countered, max(counter, fee + 100000));
    }
    return (NegotiationResult.rejected, ask);
  }

  /// Weekly wage the player asks from [buyer]: more to join a smaller club.
  int wageDemand(Player p, Club buyer, Club seller) =>
      (offeredWage(p) * (buyer.reputation < seller.reputation ? 1.15 : 1.0) / 1000).round() * 1000;

  TransferDeal? dealFor(Player p) =>
      deals.where((d) => d.player.id == p.id && !d.stage.finished).firstOrNull;

  /// Step 1 of a purchase: the bid goes to the club, which answers next round.
  String? makeBid(Player p, Club seller, int fee) {
    final issue = transferIssue(p, seller, userClub, fee);
    if (issue != null) return lastTransferError = issue;
    final existing = dealFor(p);
    if (existing != null && existing.buyer.id != _userClubId) return tr('Bu futbolchi bo‘yicha boshqa muzokara bor.');
    if (existing != null) {
      existing
        ..fee = fee
        ..stage = DealStage.clubReview
        ..dueRound = _currentRound + 1
        ..note = tr('Yangi taklif yuborildi.');
    } else {
      deals.add(TransferDeal(
        player: p,
        seller: seller,
        buyer: userClub,
        fee: fee,
        stage: DealStage.clubReview,
        dueRound: _currentRound + 1,
        note: tr('Taklif yuborildi. Klub keyingi turda javob beradi.'),
      ));
    }
    notifyListeners();
    return null;
  }

  void acceptCounter(TransferDeal d) {
    if (d.stage != DealStage.clubCountered || d.counterFee == null) return;
    d
      ..fee = d.counterFee!
      ..stage = DealStage.contractTalks
      ..wage = wageDemand(d.player, d.buyer, d.seller)
      ..dueRound = _currentRound + 3
      ..note = tr('Narx kelishildi. Endi futbolchiga shartnoma taklif qiling.');
    notifyListeners();
  }

  /// Step 2: personal terms. The player answers next round.
  String? offerContract(TransferDeal d, int wage, int years) {
    if (d.stage != DealStage.contractTalks) return null;
    final c = userClub;
    if (c.remainingWageBudget < wage) return lastTransferError = tr('Haftalik maosh limiti yetarli emas.');
    if (c.transferBudget < d.fee + ((d.fee * 0.03).round() + wage * 4)) {
      return lastTransferError = tr('Transfer, agent va imzo xarajatlari uchun mablag‘ yetarli emas.');
    }
    d
      ..wage = wage
      ..years = years.clamp(1, 5)
      ..stage = DealStage.playerReview
      ..dueRound = _currentRound + 1
      ..note = tr('Shartnoma taklifi futbolchiga yuborildi.');
    notifyListeners();
    return null;
  }

  /// Selling: accept an AI bid; the player and buyer agree terms next round.
  void acceptDealOffer(TransferDeal d) {
    if (d.stage != DealStage.offerReceived) return;
    d
      ..stage = DealStage.medical
      ..dueRound = _currentRound + 1
      ..note = tr('Taklif qabul qilindi. Futbolchi xaridor bilan shartlarni kelishmoqda.');
    notifyListeners();
  }

  void counterDealOffer(TransferDeal d, int fee) {
    if (d.stage != DealStage.offerReceived) return;
    d
      ..counterFee = fee
      ..stage = DealStage.buyerReview
      ..dueRound = _currentRound + 1
      ..note = trf('Siz {0} so‘radingiz. Xaridor keyingi turda javob beradi.', [_m(fee)]);
    notifyListeners();
  }

  void cancelDeal(TransferDeal d) {
    if (d.stage == DealStage.offerReceived) d.player.morale = max(35, d.player.morale - 2);
    d
      ..stage = DealStage.collapsed
      ..dueRound = _currentRound
      ..note = tr('Muzokara to‘xtatildi.');
    notifyListeners();
  }

  void toggleTransferList(Player p) {
    if (!transferListed.remove(p.id)) transferListed.add(p.id);
    notifyListeners();
  }

  /// Answers every negotiation that is due (called when a round passes).
  void _processDeals({bool force = false}) {
    final rnd = Random(_salt(_currentRound * 53 + calendar.year));
    deals.removeWhere((d) => d.stage.finished && d.dueRound < _currentRound - 1);
    for (final d in List.of(deals)) {
      if (d.stage.finished || (!force && d.dueRound > _currentRound)) continue;
      final p = d.player;
      final buying = d.buyer.id == _userClubId;
      void collapse(String why) {
        d
          ..stage = DealStage.collapsed
          ..note = why;
        _news(NewsKind.transfer, trf('{0}: muzokara tugadi', [p.name]), why, alert: true);
      }

      if (!isTransferWindowOpen) {
        collapse(tr('Transfer oynasi yopildi – muzokara bekor bo‘ldi.'));
        continue;
      }
      if (!d.seller.squad.contains(p)) {
        collapse(tr('Futbolchi endi bu klubda emas.'));
        continue;
      }
      switch (d.stage) {
        case DealStage.clubReview:
          final (result, value) = evaluateBid(p, d.seller, d.fee);
          switch (result) {
            case NegotiationResult.accepted:
              d
                ..stage = DealStage.contractTalks
                ..wage = wageDemand(p, d.buyer, d.seller)
                ..dueRound = _currentRound + 3
                ..note = trf('{0} taklifni qabul qildi. Endi futbolchiga shartnoma taklif qiling.', [d.seller.name]);
              _news(NewsKind.transfer, trf('{0}: taklif qabul qilindi', [p.name]), d.note, alert: true);
            case NegotiationResult.countered:
              d
                ..stage = DealStage.clubCountered
                ..counterFee = value
                ..dueRound = _currentRound + 3
                ..note = trf('{0} {1} so‘ramoqda.', [d.seller.name, _m(value)]);
              _news(NewsKind.transfer, trf('{0}: qarshi taklif', [p.name]), d.note, alert: true);
            default:
              collapse(trf('{0} taklifni rad etdi. Klub kamida {1} kutmoqda.', [d.seller.name, _m(value)]));
          }
        case DealStage.playerReview:
          final demand = wageDemand(p, d.buyer, d.seller) * (d.years >= 4 ? 0.97 : 1.0);
          if (d.wage >= demand) {
            final issue = transferIssue(p, d.seller, d.buyer, d.fee);
            if (issue != null) {
              collapse(issue);
              continue;
            }
            _completeTransfer(p, d.seller, d.buyer, d.fee, d.wage, d.years);
            d
              ..stage = DealStage.done
              ..note = trf('{0} {1} yillik shartnoma imzoladi.', [p.name, d.years]);
            _news(NewsKind.transfer, trf('{0} jamoaga qo‘shildi', [p.name]),
                trf('{0}dan {1} evaziga. Shartnoma: {2} yil, {3}/hafta.', [d.seller.name, _m(d.fee), d.years, _m(d.wage)]),
                alert: true);
          } else if (d.wage >= demand * 0.85) {
            d
              ..stage = DealStage.contractTalks
              ..wage = demand.round()
              ..dueRound = _currentRound + 3
              ..note = trf('Futbolchi haftasiga {0} so‘ramoqda.', [_m(demand.round())]);
            _news(NewsKind.transfer, trf('{0}: maosh talabi', [p.name]), d.note, alert: true);
          } else {
            collapse(trf('{0} shartnoma taklifini rad etdi.', [p.name]));
          }
        case DealStage.buyerReview:
          final limit = p.marketValue * (1.05 + rnd.nextDouble() * 0.3);
          final asked = d.counterFee ?? d.fee;
          if (asked <= limit && d.buyer.transferBudget >= asked) {
            d
              ..fee = asked
              ..stage = DealStage.medical
              ..dueRound = _currentRound + 1
              ..note = trf('{0} {1} to‘lashga rozi bo‘ldi.', [d.buyer.name, _m(asked)]);
            _news(NewsKind.transfer, trf('{0}: narx kelishildi', [p.name]), d.note, alert: true);
          } else if (rnd.nextBool()) {
            final meet = ((d.fee + asked) / 2 / 100000).round() * 100000;
            d
              ..fee = meet
              ..stage = DealStage.offerReceived
              ..dueRound = _currentRound + 3
              ..note = trf('{0} o‘rtada kelishishni taklif qildi: {1}.', [d.buyer.name, _m(meet)]);
            _news(NewsKind.transfer, trf('{0}: yangi taklif', [p.name]), d.note, alert: true);
          } else {
            collapse(trf('{0} muzokaradan chiqdi.', [d.buyer.name]));
          }
        case DealStage.medical:
          final issue = transferIssue(p, d.seller, d.buyer, d.fee);
          if (issue == null && rnd.nextDouble() < 0.85) {
            _completeTransfer(p, d.seller, d.buyer, d.fee);
            d
              ..stage = DealStage.done
              ..note = trf('{0} {1}ga o‘tdi.', [p.name, d.buyer.name]);
            _news(NewsKind.transfer, trf('{0} {1}ga sotildi', [p.name, d.buyer.name]),
                trf('Kelishuv summasi: {0}.', [_m(d.fee)]), alert: true);
          } else {
            collapse(issue ?? trf('{0} {1}ga o‘tishni rad etdi.', [p.name, d.buyer.name]));
          }
        case DealStage.clubCountered:
        case DealStage.contractTalks:
        case DealStage.offerReceived:
          // Waiting for the user too long.
          collapse(buying
              ? tr('Javob berilmagani uchun muzokara bekor bo‘ldi.')
              : trf('{0} javob kutib, taklifini qaytarib oldi.', [d.buyer.name]));
        default:
          break;
      }
    }
  }

  /// Answers all open negotiations at once (tests and debugging).
  @visibleForTesting
  void resolveDealsNow() {
    _processDeals(force: true);
    notifyListeners();
  }
""")

# --- AI offers become negotiations; listed players attract more
rep("""  void _generateOffers() {
    final rnd = Random(_salt(_currentRound * 131 + calendar.year));
    offers.removeWhere((o) => !userClub.squad.contains(o.player));
    if (userClub.squad.length <= minSquad) return;
    final targets = List<Player>.of(userClub.squad)
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final count = rnd.nextInt(3);
    for (var i = 0; i < count; i++) {
      final p = targets[rnd.nextInt(min(10, targets.length))];
      if (offers.any((o) => o.player == p)) continue;""", """  void _generateOffers() {
    final rnd = Random(_salt(_currentRound * 131 + calendar.year));
    if (userClub.squad.length <= minSquad) return;
    final targets = List<Player>.of(userClub.squad)
      ..sort((a, b) => b.marketValue.compareTo(a.marketValue));
    final picks = <Player>[
      // Transfer-listed players are offered around.
      for (final p in userClub.squad)
        if (transferListed.contains(p.id) && rnd.nextDouble() < 0.6) p,
      for (var i = rnd.nextInt(3); i > 0; i--) targets[rnd.nextInt(min(10, targets.length))],
    ];
    for (final p in picks) {
      if (dealFor(p) != null) continue;""")
rep("""      final fee = (p.marketValue * (0.9 + rnd.nextDouble() * 0.35) / 100000).round() * 100000;
      offers.add(TransferOffer(p, buyer, fee));""", """      final listed = transferListed.contains(p.id);
      final fee = (p.marketValue * ((listed ? 0.75 : 0.9) + rnd.nextDouble() * 0.35) / 100000).round() * 100000;
      deals.add(TransferDeal(
        player: p,
        seller: userClub,
        buyer: buyer,
        fee: fee,
        stage: DealStage.offerReceived,
        dueRound: _currentRound + 3,
        note: trf('{0} {1} taklif qildi.', [buyer.name, _m(fee)]),
      ));""")

# --- round flow
rep("""    _currentRound++;
    for (final club in _allClubs) {
      for (final p in club.squad) {
        p.currentStamina = min(100, p.currentStamina + 10 + days * 3);
      }
    }""", """    _currentRound++;
    for (final club in _allClubs) {
      for (final p in club.squad) {
        p.currentStamina = min(100, p.currentStamina + 10 + days * 3);
      }
    }
    _processDeals();""")
rep("""      offers.clear();
    }
    if (open) {""", """    }
    if (open) {""")
rep("""    seasonFinished = false;
    offers.clear();""", """    seasonFinished = false;
    deals.clear();""")

# --- save / restore
rep("""    'offers': [
      for (final o in offers) {'p': o.player.id, 'b': o.buyer.id, 'f': o.fee},
    ],""", """    'deals': [
      for (final d in deals)
        {
          'p': d.player.id,
          's': d.seller.id,
          'b': d.buyer.id,
          'f': d.fee,
          'w': d.wage,
          'y': d.years,
          'st': d.stage.name,
          'due': d.dueRound,
          if (d.counterFee != null) 'c': d.counterFee,
          'n': d.note,
        },
    ],
    'listed': transferListed.toList(),""")
rep("""    offers.clear();
    for (final raw in m['offers'] as List? ?? []) {
      final buyer = getClubById(raw['b']);
      final player = userClub.playerById(raw['p']);
      if (buyer != null && player != null) offers.add(TransferOffer(player, buyer, raw['f']));
    }""", """    deals.clear();
    for (final raw in m['deals'] as List? ?? []) {
      final seller = getClubById(raw['s']), buyer = getClubById(raw['b']);
      final player = seller?.playerById(raw['p']);
      final stage = DealStage.values.asNameMap()[raw['st']];
      if (seller == null || buyer == null || player == null || stage == null) continue;
      deals.add(TransferDeal(
        player: player,
        seller: seller,
        buyer: buyer,
        fee: raw['f'],
        wage: raw['w'] ?? 0,
        years: raw['y'] ?? 3,
        stage: stage,
        dueRound: raw['due'],
        counterFee: raw['c'],
        note: raw['n'] ?? '',
      ));
    }
    transferListed
      ..clear()
      ..addAll(List<String>.from(m['listed'] ?? []));""")

# untranslated messages
rep("""      return 'Transfer oynasi yopiq. $transferWindowLabel.';""", """      return trf('Transfer oynasi yopiq. {0}.', [transferWindowLabel]);""")
rep("""      return 'Haftalik maosh limiti yetarli emas.';""", """      return tr('Haftalik maosh limiti yetarli emas.');""")
rep("""    if (c.remainingWageBudget < wage) return 'Haftalik maosh limiti yetarli emas.';""",
    """    if (c.remainingWageBudget < wage) return tr('Haftalik maosh limiti yetarli emas.');""")
p.write_text(s, encoding='utf8')
print('ok')
