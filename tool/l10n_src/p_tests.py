"""One-off patch: tests for negotiations and line-up protection."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
p = ROOT / 'test/game_rules_test.dart'
s = p.read_text(encoding='utf8')
a = s.index("  test('Negotiation accepts, counters and rejects by asking price', () {")
b = s.index("  });", a) + len("  });")
s = s[:a] + '''  test('Transfers are negotiated over rounds: bid, counter, contract, signing', () {
    final seller = game.allClubs[2];
    final p = seller.bench.firstWhere((p) => !p.mainPosition.isGoalkeeper);
    game.userClub.transferBudget = 1000000000;
    game.userClub.wageBudget = 100000000;
    final ask = game.askingPrice(p, seller);

    // A low bid is rejected – but only when the club answers.
    expect(game.makeBid(p, seller, (ask * 0.5).round()), isNull);
    expect(game.dealFor(p)!.stage, DealStage.clubReview);
    game.resolveDealsNow();
    expect(game.deals.last.stage, DealStage.collapsed);
    expect(game.userClub.squad.contains(p), isFalse);

    // A close bid gets a counter; accepting it opens contract talks.
    game.makeBid(p, seller, (ask * 0.9).round());
    game.resolveDealsNow();
    final deal = game.dealFor(p)!;
    expect(deal.stage, DealStage.clubCountered);
    game.acceptCounter(deal);
    expect(deal.stage, DealStage.contractTalks);
    expect(game.userClub.squad.contains(p), isFalse);

    // A stingy wage is countered, the demanded wage is accepted.
    final demand = game.wageDemand(p, game.userClub, seller);
    expect(game.offerContract(deal, (demand * 0.9).round(), 3), isNull);
    game.resolveDealsNow();
    expect(deal.stage, DealStage.contractTalks);
    expect(game.offerContract(deal, demand, 4), isNull);
    game.resolveDealsNow();
    expect(deal.stage, DealStage.done);
    expect(game.userClub.squad.contains(p), isTrue);
    expect(p.contract.contractYears, 4);
    expect(p.contract.weeklyWage, demand);
  });

  test('Selling: offers wait for an answer, counters and medicals take a round', () {
    final p = game.userClub.squad.firstWhere((p) => !p.mainPosition.isGoalkeeper && !game.userClub.startingLineupIds.contains(p.id));
    final buyer = game.allClubs.firstWhere((c) => c.id != game.userClubId);
    buyer.transferBudget = 1000000000;
    buyer.wageBudget = 100000000;
    game.deals.add(TransferDeal(
      player: p,
      seller: game.userClub,
      buyer: buyer,
      fee: p.marketValue,
      stage: DealStage.offerReceived,
      dueRound: game.currentRound + 3,
    ));
    final d = game.deals.last;
    expect(game.offers, contains(d));
    game.acceptDealOffer(d);
    expect(d.stage, DealStage.medical);
    expect(game.userClub.squad.contains(p), isTrue, reason: 'nothing moves until the next round');
    for (var i = 0; i < 20 && !d.stage.finished; i++) {
      game.resolveDealsNow();
    }
    expect(d.stage.finished, isTrue);
    expect(game.userClub.squad.contains(p), d.stage != DealStage.done);
    game.toggleTransferList(game.userClub.squad.first);
    expect(game.transferListed, contains(game.userClub.squad.first.id));
  });

  test('Quick result keeps the manager’s own line-up', () {
    final c = game.userClub;
    final xi = List.of(c.startingLineupIds), bench = List.of(c.benchIds);
    game.simulateUserFixture(game.nextUserFixture!);
    expect(c.startingLineupIds.toSet(), xi.toSet());
    expect(c.benchIds.where(xi.contains), isEmpty);
    expect(bench.where((id) => c.playerById(id) != null).every(c.benchIds.contains), isTrue);
  });''' + s[b:]
s = s.replace("import 'package:football_top_manager/models/face.dart';",
              "import 'package:football_top_manager/models/face.dart';\nimport 'package:football_top_manager/models/transfer_deal.dart';", 1)
p.write_text(s, encoding='utf8')
print('ok')
